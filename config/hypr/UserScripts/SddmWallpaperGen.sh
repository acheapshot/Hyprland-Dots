#!/usr/bin/env bash
# Generate a login wallpaper with ComfyUI (SDXL) for the SDDM random picker.
# Saves to ~/Pictures/wallpapers/ai-login, which sddm_wallpaper_random.sh already searches.
# Starts ComfyUI if it is not running and stops it again afterwards.
# Skipped in game mode or when the GPU is short on free VRAM. Keeps the newest $KEEP images.
#
# Usage:
#   SddmWallpaperGen.sh              random theme
#   SddmWallpaperGen.sh "<prompt>"   custom positive prompt

HOST="127.0.0.1:8188"
CKPT="sd_xl_base_1.0.safetensors"
OUT_DIR="$HOME/Pictures/wallpapers/ai-login"
KEEP=40
MIN_FREE_MIB=6000
WIDTH=1536
HEIGHT=640
FINAL_W=3440
FINAL_H=1440

STYLE="wide cinematic landscape, highly detailed, dramatic lighting, no text"
THEMES=(
    "neon cyberpunk city at night, rain, glowing signs, magenta and cyan"
    "synthwave sunset over a chrome grid, retro futuristic"
    "misty mountains at dawn, soft pastel sky, serene"
    "deep space nebula, swirling purple and teal gas clouds, stars"
    "futuristic megacity skyline above the clouds, golden hour"
    "bioluminescent forest, glowing mushrooms, fog, dark blue"
    "lonely lighthouse on a cliff, stormy ocean, moody sky"
    "abstract flowing liquid glass, iridescent gradients, dark background"
    "japanese mountain village in the snow at night, warm lanterns"
    "desert dunes under a giant ringed planet, twilight"
)
NEGATIVE="text, watermark, logo, signature, people, face, blurry, low quality, oversaturated, frame, border"

notif() { notify-send -e -u low "SDDM wallpaper:" "$1" 2>/dev/null || true; }

# Game mode turns animations off
anim=$(hyprctl getoption animations:enabled -j 2>/dev/null | jq -r '.bool' 2>/dev/null)
if [[ "$anim" == "false" ]]; then
    echo "game mode is on, skipping"
    exit 0
fi

free=$(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits 2>/dev/null | head -n1)
if [[ -z "$free" || "$free" -lt "$MIN_FREE_MIB" ]]; then
    echo "not enough free VRAM (${free:-unknown} MiB), skipping"
    exit 0
fi

mkdir -p "$OUT_DIR"

started_pid=""
cleanup() {
    [[ -n "$started_pid" ]] && kill "$started_pid" 2>/dev/null
}
trap cleanup EXIT

if ! curl -sf "http://$HOST/system_stats" >/dev/null; then
    "$HOME/.local/bin/comfyui" >/dev/null 2>&1 &
    started_pid=$!
    for _ in $(seq 1 90); do
        curl -sf "http://$HOST/system_stats" >/dev/null && break
        sleep 1
    done
    if ! curl -sf "http://$HOST/system_stats" >/dev/null; then
        echo "ComfyUI did not start" >&2
        exit 1
    fi
fi

theme="${1:-${THEMES[RANDOM % ${#THEMES[@]}]}}"
seed=$(( (RANDOM << 30) ^ (RANDOM << 15) ^ RANDOM ))

workflow=$(jq -n \
    --arg ckpt "$CKPT" --arg pos "$theme, $STYLE" --arg neg "$NEGATIVE" \
    --argjson seed "$seed" --argjson w "$WIDTH" --argjson h "$HEIGHT" \
    --argjson fw "$FINAL_W" --argjson fh "$FINAL_H" '{
  "1": {class_type: "CheckpointLoaderSimple", inputs: {ckpt_name: $ckpt}},
  "2": {class_type: "CLIPTextEncode", inputs: {text: $pos, clip: ["1", 1]}},
  "3": {class_type: "CLIPTextEncode", inputs: {text: $neg, clip: ["1", 1]}},
  "4": {class_type: "EmptyLatentImage", inputs: {width: $w, height: $h, batch_size: 1}},
  "5": {class_type: "KSampler", inputs: {model: ["1", 0], positive: ["2", 0], negative: ["3", 0],
        latent_image: ["4", 0], seed: $seed, steps: 28, cfg: 7, sampler_name: "dpmpp_2m",
        scheduler: "karras", denoise: 1}},
  "6": {class_type: "LatentUpscaleBy", inputs: {samples: ["5", 0], upscale_method: "nearest-exact", scale_by: 1.5}},
  "7": {class_type: "KSampler", inputs: {model: ["1", 0], positive: ["2", 0], negative: ["3", 0],
        latent_image: ["6", 0], seed: $seed, steps: 20, cfg: 7, sampler_name: "dpmpp_2m",
        scheduler: "karras", denoise: 0.45}},
  "8": {class_type: "VAEDecode", inputs: {samples: ["7", 0], vae: ["1", 2]}},
  "9": {class_type: "ImageScale", inputs: {image: ["8", 0], upscale_method: "lanczos",
        width: $fw, height: $fh, crop: "center"}},
  "10": {class_type: "PreviewImage", inputs: {images: ["9", 0]}}
}')

pid=$(curl -sf -H 'Content-Type: application/json' -d "{\"prompt\": $workflow}" "http://$HOST/prompt" | jq -r '.prompt_id // empty')
if [[ -z "$pid" ]]; then
    echo "ComfyUI rejected the workflow" >&2
    notif "generation failed"
    exit 1
fi

img=""
for _ in $(seq 1 300); do
    img=$(curl -sf "http://$HOST/history/$pid" | jq -c --arg id "$pid" '.[$id].outputs["10"].images[0] // empty')
    [[ -n "$img" ]] && break
    sleep 2
done
if [[ -z "$img" ]]; then
    echo "timed out waiting for the image" >&2
    exit 1
fi

out="$OUT_DIR/ai-$(date +%Y%m%d-%H%M%S).png"
curl -sfG "http://$HOST/view" \
    --data-urlencode "filename=$(jq -r .filename <<<"$img")" \
    --data-urlencode "subfolder=$(jq -r .subfolder <<<"$img")" \
    --data-urlencode "type=$(jq -r .type <<<"$img")" -o "$out" || {
    echo "could not download the image" >&2
    rm -f "$out"
    exit 1
}
echo "$out"

# Prune the oldest beyond $KEEP
mapfile -t old < <(ls -1t "$OUT_DIR"/ai-*.png 2>/dev/null | tail -n +$((KEEP + 1)))
[[ ${#old[@]} -gt 0 ]] && rm -f -- "${old[@]}"
notif "new login wallpaper: ${out##*/}"
