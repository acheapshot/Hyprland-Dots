-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- User animations overrides (auto-generated).
-- This file is intentionally split from other user overrides.
-- Add only user-specific Lua overrides here.
-- Example:
-- hl.config({ general = { gaps_in = 4, gaps_out = 8 } })

-- Source reference from UserAnimations.conf (hyprlang):
-- animations {
-- enabled = yes
-- bezier = myBezier, 0.05, 0.9, 0.1, 1.05
-- bezier = linear, 0.0, 0.0, 1.0, 1.0
-- bezier = wind, 0.05, 0.9, 0.1, 1.05
-- bezier = winIn, 0.1, 1.1, 0.1, 1.1
-- bezier = winOut, 0.3, -0.3, 0, 1
-- bezier = slow, 0, 0.85, 0.3, 1
-- bezier = overshot, 0.7, 0.6, 0.1, 1.1
-- bezier = bounce, 1.1, 1.6, 0.1, 0.85
-- bezier = sligshot, 1, -1, 0.15, 1.25
-- bezier = nice, 0, 6.9, 0.5, -4.20
-- animation = windowsIn, 1, 5, slow, popin
-- animation = windowsOut, 1, 5, winOut, popin
-- animation = windowsMove, 1, 5, wind, slide
-- animation = border, 1, 10, linear
-- animation = borderangle, 1, 180, linear, loop #used by rainbow borders and rotating colors
-- animation = fade, 1, 5, overshot
-- animation = workspaces, 1, 5, wind
-- animation = windows, 1, 5, bounce, popin
-- }

-- Ported by hand from the block above (the migration script left it as a comment only).
hl.config({
  animations = {
    enabled = true,
  },
})
hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.curve("linear", { type = "bezier", points = { { 0.0, 0.0 }, { 1.0, 1.0 } } })
hl.curve("wind", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.curve("winIn", { type = "bezier", points = { { 0.1, 1.1 }, { 0.1, 1.1 } } })
hl.curve("winOut", { type = "bezier", points = { { 0.3, -0.3 }, { 0, 1 } } })
hl.curve("slow", { type = "bezier", points = { { 0, 0.85 }, { 0.3, 1 } } })
hl.curve("overshot", { type = "bezier", points = { { 0.7, 0.6 }, { 0.1, 1.1 } } })
hl.curve("bounce", { type = "bezier", points = { { 1.1, 1.6 }, { 0.1, 0.85 } } })
hl.curve("sligshot", { type = "bezier", points = { { 1, -1 }, { 0.15, 1.25 } } })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 5, bezier = "slow", style = "popin" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 5, bezier = "winOut", style = "popin" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5, bezier = "wind", style = "slide" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "linear" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 100, bezier = "linear", style = "loop" }) -- was 180 in hyprlang; Lua caps speed at 100
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "overshot" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "wind" })
hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "bounce", style = "popin" })
