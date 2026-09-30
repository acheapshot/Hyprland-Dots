#!/usr/bin/env python3
"""Generate the cyberpunk wlogout icons.

Writes <name>.svg into this directory and, if rsvg-convert is available,
renders <name>.png / <name>-hover.png into ../icons.

    python3 gen_icons.py
"""
import math
import shutil
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
ICONS = HERE.parent / "icons"
SIZE = 512

NORMAL = {"frame": "#b44cff", "glyph": "#b44cff", "accent": "#ff2a6d", "glow": 5}
HOVER = {"frame": "#ff2a6d", "glyph": "#2e8bff", "accent": "#b44cff", "glow": 8}


def pt(cx, cy, r, deg):
    """Point on a circle, 0 deg = 12 o'clock, clockwise."""
    a = math.radians(deg)
    return cx + r * math.sin(a), cy - r * math.cos(a)


def f(x, y):
    return f"{x:.1f} {y:.1f}"


def chevron(tip, direction, arm=20, spread=40):
    """Open chevron whose vertex is `tip`, pointing along `direction` (deg)."""
    a = f(*pt(*tip, arm, direction + 180 - spread))
    b = f(*pt(*tip, arm, direction + 180 + spread))
    return f"M{a} L{f(*tip)} L{b}"


# Glyphs live in a 256x256 box, roughly inside 72..184.
GLYPHS = {
    "lock": [
        "M100 116 V90 L116 74 H140 L156 90 V116",
        "M84 116 H172 L184 128 V184 L172 196 H84 L72 184 V128 Z",
        "M128 144 V168",
    ],
    "logout": [
        "M148 76 H84 V180 H148",
        "M108 128 H194",
        chevron((194, 128), 90),
    ],
    "suspend": [
        # crescent: outer arc r=56 around (128,128), inner arc cuts it
        "M{a} A56 56 0 1 0 {b} A44 44 0 0 1 {a} Z".format(
            a=f(*pt(118, 138, 56, 20)), b=f(*pt(118, 138, 56, 110))
        ),
        "M170 60 H190 L170 80 H190",
    ],
    "shutdown": [
        "M{a} A56 56 0 1 1 {b}".format(
            a=f(*pt(128, 134, 56, 38)), b=f(*pt(128, 134, 56, -38))
        ),
        "M128 66 V130",
    ],
    "reboot": [
        "M{a} A56 56 0 1 1 {b}".format(
            a=f(*pt(128, 128, 56, 40)), b=f(*pt(128, 128, 56, 0))
        ),
        chevron(pt(128, 128, 56, 0), 90, arm=24, spread=45),
    ],
    "hibernate": (
        [f"M{f(*pt(128, 128, 60, d))} L{f(*pt(128, 128, 60, d + 180))}" for d in (0, 60, 120)]
        + [
            f"M{f(*pt(*pt(128, 128, 38, d), 14, d - 60))} "
            f"L{f(*pt(128, 128, 38, d))} "
            f"L{f(*pt(*pt(128, 128, 38, d), 14, d + 60))}"
            for d in range(0, 360, 60)
        ]
    ),
}

# Chamfered HUD frame + corner brackets + tick marks.
FRAME = [
    "M60 28 H200 L228 56 V196 L196 228 H56 L28 200 V60 Z",
]
ACCENT = [
    "M16 44 V16 H44",
    "M212 240 H240 V212",
    "M96 16 H160",
    "M96 240 H160",
]
TICKS = [f"M{x} 28 V36" for x in (100, 114, 142, 156)] + [
    f"M{x} 220 V228" for x in (100, 114, 142, 156)
]


def svg(name, c):
    def paths(ds, color, width):
        return "".join(
            f'<path d="{d}" stroke="{color}" stroke-width="{width}"/>' for d in ds
        )

    art = (
        paths(FRAME, c["frame"], 4)
        + paths(TICKS, c["frame"], 3)
        + paths(ACCENT, c["accent"], 4)
        + paths(GLYPHS[name], c["glyph"], 10)
    )
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 256 256">
  <defs>
    <filter id="glow" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur stdDeviation="{c['glow']}" result="b"/>
      <feMerge><feMergeNode in="b"/><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  </defs>
  <g fill="none" stroke-linecap="square" stroke-linejoin="miter" filter="url(#glow)">{art}</g>
</svg>
"""


def main():
    rsvg = shutil.which("rsvg-convert")
    ICONS.mkdir(exist_ok=True)
    for name in GLYPHS:
        for suffix, colors in (("", NORMAL), ("-hover", HOVER)):
            src = HERE / f"{name}{suffix}.svg"
            src.write_text(svg(name, colors))
            if rsvg:
                subprocess.run(
                    [rsvg, "-w", str(SIZE), "-h", str(SIZE), "-o", str(ICONS / f"{name}{suffix}.png"), str(src)],
                    check=True,
                )


if __name__ == "__main__":
    main()
