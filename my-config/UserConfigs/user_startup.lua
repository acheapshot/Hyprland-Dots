-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- User startup overrides (auto-generated).
-- Add commands with exec_once("your command")
-- Example:
-- exec_once("${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserScripts/MyStartup.sh")

local user_startup_helper = nil
do
  local source = (debug.getinfo(1, "S") or {}).source or ""
  local source_path = source:match("^@(.+)$")
  local source_dir = source_path and source_path:match("^(.*)/[^/]+$") or nil
  local home = os.getenv("HOME") or ""
  local candidate_paths = {
    source_dir and (source_dir .. "/../lua/user_startup_helper.lua") or nil,
    home ~= "" and (home .. "/.config/hypr/lua/user_startup_helper.lua") or nil,
    home ~= "" and (home .. "/.config/hypr/user_startup_helper.lua") or nil,
  }

  local tried_paths = {}
  for _, helper_path in ipairs(candidate_paths) do
    if helper_path then
      table.insert(tried_paths, helper_path)
      local f = io.open(helper_path, "r")
      if f then
        f:close()
        local loaded_ok, loaded_helpers = pcall(dofile, helper_path)
        if loaded_ok and type(loaded_helpers) == "table" and loaded_helpers.exec_once then
          user_startup_helper = loaded_helpers
          break
        end
      end
    end
  end

  if not user_startup_helper then
    error("Failed to load user_startup_helper.lua from: " .. table.concat(tried_paths, ", "))
  end
end
local exec_once = user_startup_helper.exec_once

-- Converted from Startup_Apps.conf
local startup_commands = {
  -- Monitor management: one watcher per session. It reconciles the
  -- saved layout on login and after every monitor event, and it is the
  -- only thing that calls DisplayProfile.sh.
  "$HOME/.config/hypr/scripts/MonitorWatcher.sh",
  "~/.config/hypr/UserScripts/GameModeHook.sh start-openrgb",
  "~/.config/hypr/UserConfigs/Scripts/start-keyring.sh",
  "~/.config/hypr/UserScripts/GameModeHook.sh start-whisper",
  "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP && systemctl --user restart sunshine.service",
  -- Steam runs as a user service; start it here, not at boot (lingering), so it has a display
  "systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP && systemctl --user start steam.service",
  "tether-gtk --tray",
  -- Carried over from the pre-Lua configs/Startup_Apps.conf
  "1password --silent",
  -- Electron creates its tray icon once; waybar (the tray host) starts later, so wait for the watcher
  "i=0; while [ $i -lt 150 ] && ! busctl --user status org.kde.StatusNotifierWatcher >/dev/null 2>&1; do i=$((i+1)); sleep 0.2; done; exec claude-desktop --startup",
  -- Tray applet; its AutoConnect plugin reconnects the Bose speaker at login
  "blueman-applet",
}

local function run_startup_commands()
  for _, cmd in ipairs(startup_commands) do
    exec_once(cmd)
  end
end

if hl and hl.on then
  hl.on("hyprland.start", run_startup_commands)
else
  run_startup_commands()
end
