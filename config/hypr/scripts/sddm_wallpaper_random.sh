#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Randomize the SDDM login background before the greeter is shown.
#
# Invoked as root from /usr/share/sddm/scripts/Xsetup, which SDDM runs
# every time the login dialog is about to appear (boot, and again each
# time a session ends back to the greeter). There is no display server,
# no user session, and no sudo prompt available here, so this script must
# be self-contained and must never block or fail the login screen -
# every error path logs and exits 0.
#
# After swapping the image it also rewrites the theme.conf colors so the
# clock, buttons and login fields stay readable. Colors are derived from
# the left 40% of the (center-cropped) image - the area the login form
# covers - and tuned for WCAG contrast rather than just "matching", so a
# bright wallpaper gets dark text and a dark one gets light text, tinted
# with the wallpaper's dominant hue. Very uneven backgrounds also get a
# dim overlay and, in the worst cases, the theme's form background panel.
# Palettes are cached per image (path + mtime + size), so only the first
# login on a new wallpaper pays the ~1s image decode.
#
# Usage:
#   sddm_wallpaper_random.sh            pick random wallpaper + recolor
#   sddm_wallpaper_random.sh --prime    precompute palettes for every
#                                       wallpaper (no theme change)
#   SDDM_WALLPAPER=/path/img.jpg sddm_wallpaper_random.sh
#                                       force a specific image (testing)

set -u

TARGET_USER="acheapshot"
LOG_TAG="sddm_wallpaper_random"

log() {
    logger -t "$LOG_TAG" -- "$1" 2>/dev/null || true
}

USER_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6)"
if [[ -z "$USER_HOME" || ! -d "$USER_HOME" ]]; then
    log "could not resolve home directory for user '$TARGET_USER'"
    exit 0
fi

wallDIR="$USER_HOME/Pictures/wallpapers"
if [[ ! -d "$wallDIR" ]]; then
    log "wallpaper directory not found: $wallDIR"
    exit 0
fi

sddm_themes_dir="/usr/share/sddm/themes"
if [[ ! -d "$sddm_themes_dir" && -d "/run/current-system/sw/share/sddm/themes" ]]; then
    sddm_themes_dir="/run/current-system/sw/share/sddm/themes"
fi
sddm_simple="$sddm_themes_dir/simple_sddm_2"
if [[ ! -d "$sddm_simple/Backgrounds" ]]; then
    log "SDDM theme backgrounds not found: $sddm_simple/Backgrounds"
    exit 0
fi

# Images only: this runs as root with no display/session, so there is no
# reasonable way to extract a frame from a video wallpaper here.
mapfile -d '' WALLPAPERS < <(find -L "$wallDIR" -type f \( \
    -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o \
    -iname "*.bmp" -o -iname "*.tiff" -o -iname "*.webp" \
\) -print0 2>/dev/null)

if [[ ${#WALLPAPERS[@]} -eq 0 ]]; then
    log "no image wallpapers found in $wallDIR"
    exit 0
fi

theme_conf="$sddm_simple/theme.conf"
palette_cache="$sddm_simple/Backgrounds/.palette-cache"
# Bump when compute_palette changes so cached palettes are recomputed.
palette_version=3

# Print theme.conf color assignments (Key=#RRGGBB lines) for an image.
compute_palette() {
    local img="$1"
    # Mimic CropBackground=true (fill + center crop) at a small 43:18 size
    # (the 3440x1440 greeter monitor),
    # then let awk split the form region (x < 64 of 160) from the rest.
    timeout 8 magick "$img[0]" -resize '160x67^' -gravity center -extent 160x67 \
        -depth 8 -colorspace sRGB txt:- 2>/dev/null | awk '
    function lin(c) { c /= 255; return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ^ 2.4 }
    function rl(r, g, b) { return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b) }
    function cr(a, b) { return a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05) }
    function hue2(p, q, t) {
        if (t < 0) t += 1; if (t > 1) t -= 1
        if (t < 1/6) return p + (q - p) * 6 * t
        if (t < 1/2) return q
        if (t < 2/3) return p + (q - p) * (2/3 - t) * 6
        return p
    }
    # HSL -> sets globals R G B (0-255)
    function hsl(h, s, l,   q, p) {
        if (s == 0) { R = G = B = l * 255; return }
        q = l < 0.5 ? l * (1 + s) : l + s - l * s; p = 2 * l - q
        R = 255 * hue2(p, q, h + 1/3); G = 255 * hue2(p, q, h); B = 255 * hue2(p, q, h - 1/3)
    }
    function hex() { return sprintf("#%02X%02X%02X", int(R + 0.5), int(G + 0.5), int(B + 0.5)) }
    # Walk lightness away from the background until contrast >= target.
    function pick(h, s, target,   l) {
        if (mode == "light") { for (l = 0.55; l <= 1.0001; l += 0.01) { hsl(h, s, l); if (cr(rl(R, G, B), ref) >= target) return hex() } R = G = B = 255 }
        else                 { for (l = 0.45; l >= -0.0001; l -= 0.01) { hsl(h, s, l); if (cr(rl(R, G, B), ref) >= target) return hex() } R = G = B = 0 }
        return hex()
    }
    /^#/ { next }
    {
        split($1, xy, /[,:]/)
        gsub(/[()]/, "", $2); split($2, c, ",")
        r = c[1]; g = c[2]; b = c[3]
        if (xy[1] < 64) L[n++] = rl(r, g, b)
        # dominant hue: 12 buckets weighted by saturation, ignoring near-gray / extremes
        mx = r > g ? (r > b ? r : b) : (g > b ? g : b); mn = r < g ? (r < b ? r : b) : (g < b ? g : b)
        li = (mx + mn) / 510; d = (mx - mn) / 255
        if (d == 0 || li < 0.12 || li > 0.9) next
        sa = d / (1 - (2 * li - 1 < 0 ? 1 - 2 * li : 2 * li - 1))
        if (sa < 0.2) next
        if (mx == r) hh = ((g - b) / (mx - mn)) % 6; else if (mx == g) hh = (b - r) / (mx - mn) + 2; else hh = (r - g) / (mx - mn) + 4
        hh /= 6; if (hh < 0) hh += 1
        k = int(hh * 12) % 12; W[k] += sa; HS[k] += hh; SS[k] += sa; NN[k]++
    }
    END {
        if (n < 100) exit 1
        asort(L)
        p10 = L[int(n * 0.10) + 1]; p50 = L[int(n * 0.50) + 1]; p90 = L[int(n * 0.90) + 1]
        best = -1; for (k = 0; k < 12; k++) if (W[k] > best) { best = W[k]; bk = k }
        if (best > 0) { H = HS[bk] / NN[bk]; S = SS[bk] / NN[bk]; if (S > 0.75) S = 0.75 } else { H = 0; S = 0 }
        # Light text must beat the bright patches (p90), dark text the dark ones (p10).
        # Bias toward light text: a darkened login screen looks better than a washed-out one.
        if (cr(1, p90) * 1.25 >= cr(0, p10)) { mode = "light"; ref = p90; worst = cr(1, p90) }
        else                          { mode = "dark";  ref = p10; worst = cr(0, p10) }
        hsl(H, S * 0.6, mode == "light" ? 0.10 : 0.92); shade = hex(); shadeL = rl(R, G, B)
        hsl(H, S * 0.6, mode == "light" ? 0.22 : 0.80); shade2 = hex()
        # Weak contrast even for pure white/black: dim the wallpaper toward
        # the shade, then pick colors against the dimmed background.
        dim = worst < 3 ? 0.45 : (worst < 4.5 ? 0.3 : (worst < 7 ? 0.15 : 0))
        ref = ref * (1 - dim) + shadeL * dim
        primary = pick(H, S, 4.5)
        icon    = pick(H, S, 3.0)
        text    = pick(H, S * 0.35, 7.0)
        split("HeaderTextColor DateTextColor TimeTextColor SystemButtonsIconsColor SessionButtonTextColor VirtualKeyboardButtonTextColor HoverSystemButtonsIconsColor HoverSessionButtonTextColor HoverVirtualKeyboardButtonTextColor DropdownSelectedBackgroundColor HighlightBackgroundColor LoginButtonTextColor", a, " ")
        for (i in a) print a[i] "=" primary
        split("UserIconColor PasswordIconColor HoverUserIconColor HoverPasswordIconColor PlaceholderTextColor", a, " ")
        for (i in a) print a[i] "=" icon
        split("LoginFieldTextColor PasswordFieldTextColor DropdownTextColor", a, " ")
        for (i in a) print a[i] "=" text
        split("FormBackgroundColor BackgroundColor DimBackgroundColor LoginFieldBackgroundColor PasswordFieldBackgroundColor LoginButtonBackgroundColor DropdownBackgroundColor HighlightTextColor", a, " ")
        for (i in a) print a[i] "=" shade
        print "HighlightBorderColor=" shade2
        print "WarningColor=" primary
        print "DimBackground=" dim
        # Worst cases also get the translucent theme panel behind the form.
        print "HaveFormBackground=" (worst < 3 ? "true" : "false")
    }'
}

# Cached wrapper around compute_palette.
get_palette() {
    local img="$1" key cache_file tmp
    key="$( { echo "$palette_version"; stat -Lc '%n|%Y|%s' "$img"; } 2>/dev/null | md5sum | cut -d' ' -f1)"
    cache_file="$palette_cache/$key"
    if [[ -s "$cache_file" ]]; then
        cat "$cache_file"
        return 0
    fi
    tmp="$(compute_palette "$img")" || return 1
    [[ -n "$tmp" ]] || return 1
    if mkdir -p "$palette_cache" 2>/dev/null; then
        printf '%s\n' "$tmp" > "$cache_file" 2>/dev/null || true
    fi
    printf '%s\n' "$tmp"
}

# Rewrite only the keys in the palette; leave theme.conf untouched on failure.
apply_palette() {
    local palette="$1" new
    [[ -f "$theme_conf" ]] || { log "theme.conf not found: $theme_conf"; return 1; }
    [[ -f "$theme_conf.orig" ]] || cp -p "$theme_conf" "$theme_conf.orig" 2>/dev/null || true
    new="$(mktemp "$theme_conf.XXXXXX")" || return 1
    if awk 'NR == FNR { i = index($0, "="); if (i) v[substr($0, 1, i - 1)] = substr($0, i + 1); next }
            { i = index($0, "="); k = substr($0, 1, i - 1)
              if (i && (k in v)) print k "=\"" v[k] "\""; else print }' \
            <(printf '%s\n' "$palette") "$theme_conf" > "$new" && [[ -s "$new" ]]; then
        chown --reference="$theme_conf" "$new" 2>/dev/null || true
        chmod --reference="$theme_conf" "$new" 2>/dev/null || true
        mv -f "$new" "$theme_conf" && return 0
    fi
    rm -f "$new"
    return 1
}

if [[ "${1:-}" == "--prime" ]]; then
    count=0
    for img in "${WALLPAPERS[@]}"; do
        get_palette "$img" >/dev/null && count=$((count + 1))
    done
    echo "cached palettes for $count/${#WALLPAPERS[@]} wallpapers in $palette_cache"
    exit 0
fi

if [[ -n "${SDDM_WALLPAPER:-}" && -f "$SDDM_WALLPAPER" ]]; then
    random_wallpaper="$SDDM_WALLPAPER"
else
    random_wallpaper="${WALLPAPERS[$((RANDOM % ${#WALLPAPERS[@]}))]}"
fi

if cp -f "$random_wallpaper" "$sddm_simple/Backgrounds/default" 2>/dev/null; then
    log "set SDDM background to $(basename "$random_wallpaper")"
else
    log "failed to copy '$random_wallpaper' to $sddm_simple/Backgrounds/default"
    exit 0
fi

if palette="$(get_palette "$random_wallpaper")" && [[ -n "$palette" ]]; then
    if apply_palette "$palette"; then
        log "recolored theme.conf for $(basename "$random_wallpaper")"
    else
        log "failed to write colors to $theme_conf"
    fi
else
    log "could not compute palette for $(basename "$random_wallpaper"); keeping previous colors"
fi

exit 0
