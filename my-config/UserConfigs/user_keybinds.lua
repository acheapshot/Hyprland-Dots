-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- User keybind overrides (auto-generated).
-- Add, override, or rebind keybinds with bind("MODS", "KEY", fn, opts) and unbind("MODS", "KEY").
--
-- 1. ADDING A NEW KEYBIND (combo not used by default):
--    bind("SUPER", "Z", exec_cmd("ghostty"), { description = "Launch Ghostty" })
--    bind("SUPER SHIFT", "V", exec_cmd("pavucontrol"), { description = "Audio Control" })
--
-- 2. OVERRIDING AN EXISTING COMBO WITH A DIFFERENT APP/COMMAND:
--    unbind("SUPER", "Return")
--    bind("SUPER", "Return", exec_cmd("ghostty"), { description = "Launch Ghostty" })
--
-- 3. REBINDING AN ACTION TO A NEW KEY COMBINATION:
--    unbind("SUPER", "E")
--    unbind("SUPER", "F")
--    bind("SUPER", "F", exec_cmd("$HOME/.config/hypr/scripts/LaunchFileManager.sh '$files' '$term'"), { description = "File manager" })
--    bind("SUPER", "E", exec_cmd("emacsclient -c -a 'emacs'"), { description = "Launch Emacs" })
--
-- 4. REBINDING DISPATCHERS (e.g. killactive, workspace):
--    unbind("SUPER", "Q")
--    bind("SUPER", "Q", dispatch("killactive"), { description = "Close active window" })
--
-- 5. BIND OPTIONS (locked, repeating):
--    bind("CTRL ALT", "bracketright", exec_cmd("$HOME/.config/hypr/scripts/Brightness.sh --inc"), { description = "Brightness up", repeating = true })
--    bind("", "XF86AudioMute", exec_cmd("$HOME/.config/hypr/scripts/Volume.sh --toggle"), { description = "Mute audio", locked = true })
--
-- Helper functions live in ${XDG_CONFIG_HOME:-$HOME/.config}/hypr/lua/user_keybinds_helper.lua so they can be updated separately.
local user_keybinds_helper = nil
do
  local source = (debug.getinfo(1, "S") or {}).source or ""
  local source_path = source:match("^@(.+)$")
  local source_dir = source_path and source_path:match("^(.*)/[^/]+$") or nil
  local home = os.getenv("HOME") or ""
  local candidate_paths = {
    source_dir and (source_dir .. "/../lua/user_keybinds_helper.lua") or nil,
    home ~= "" and (home .. "/.config/hypr/lua/user_keybinds_helper.lua") or nil,
    home ~= "" and (home .. "/.config/hypr/user_keybinds_helper.lua") or nil,
  }

  local tried_paths = {}
  for _, helper_path in ipairs(candidate_paths) do
    if helper_path then
      table.insert(tried_paths, helper_path)
      local f = io.open(helper_path, "r")
      if f then
        f:close()
        local loaded_ok, loaded_helpers = pcall(dofile, helper_path)
        if loaded_ok and type(loaded_helpers) == "table" and loaded_helpers.bind then
          user_keybinds_helper = loaded_helpers
          break
        end
      end
    end
  end

  if not user_keybinds_helper then
    error("Failed to load user_keybinds_helper.lua from: " .. table.concat(tried_paths, ", "))
  end
end
local exec_cmd = user_keybinds_helper.exec_cmd
local dispatch = user_keybinds_helper.dispatch
local bind = user_keybinds_helper.bind
local unbind = user_keybinds_helper.unbind

-- Converted from UserKeybinds.conf
bind("SUPER SHIFT", "T", exec_cmd("$HOME/.config/theming/theme-set.sh"), { description = "Theme preset switcher" })

-- =============================================================================
-- DISPLAY LAYOUTS
-- =============================================================================
-- SUPER+ALT+D opens the layout menu for the monitor set in front of you.
-- SUPER+ALT+W applies a layout named Work directly, which is also the fallback
-- for when rofi will not start. Both combos were free: SUPER+ALT+H and
-- SUPER+ALT+P are taken by "horizontal scroll right" and the KB-passthrough
-- submap.
bind(
  "SUPER ALT",
  "D",
  exec_cmd("$HOME/.config/hypr/scripts/DisplayProfileMenu.sh"),
  { description = "Display layouts: menu for this monitor set" }
)
bind(
  "SUPER ALT",
  "W",
  -- A bare layout name is the controller's "apply this layout" verb, passed
  -- after -- so a name that looks like an option stays data. Create a layout
  -- called Work (menu -> Edit parameters) and this key applies it.
  exec_cmd("$HOME/.config/hypr/scripts/DisplayProfile.sh -- Work"),
  { description = "Display layouts: apply the layout named Work" }
)
