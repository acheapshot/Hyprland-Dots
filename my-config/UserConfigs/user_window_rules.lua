-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- User window rule overrides (auto-generated).
-- Add your own rules with apply_window_rule({...})
-- Example:
-- apply_window_rule({
--   name = "My Float Rule",
--   match = { class = "^pavucontrol$" },
--   float = true,
--   center = true,
-- })

local user_window_rules_helper = nil
do
  local source = (debug.getinfo(1, "S") or {}).source or ""
  local source_path = source:match("^@(.+)$")
  local source_dir = source_path and source_path:match("^(.*)/[^/]+$") or nil
  local home = os.getenv("HOME") or ""
  local candidate_paths = {
    source_dir and (source_dir .. "/../lua/user_window_rules_helper.lua") or nil,
    home ~= "" and (home .. "/.config/hypr/lua/user_window_rules_helper.lua") or nil,
    home ~= "" and (home .. "/.config/hypr/user_window_rules_helper.lua") or nil,
  }

  local tried_paths = {}
  for _, helper_path in ipairs(candidate_paths) do
    if helper_path then
      table.insert(tried_paths, helper_path)
      local f = io.open(helper_path, "r")
      if f then
        f:close()
        local loaded_ok, loaded_helpers = pcall(dofile, helper_path)
        if loaded_ok and type(loaded_helpers) == "table" and loaded_helpers.apply_window_rule then
          user_window_rules_helper = loaded_helpers
          break
        end
      end
    end
  end

  if not user_window_rules_helper then
    error("Failed to load user_window_rules_helper.lua from: " .. table.concat(tried_paths, ", "))
  end
end
local apply_window_rule = user_window_rules_helper.apply_window_rule

-- Converted from WindowRules.conf
apply_window_rule({
  name = "user-window-windowrule-001",
  match = {
    class = "^(org\\.gnome\\.Evolution)$",
  },
  workspace = 7,
})

apply_window_rule({
  name = "user-window-windowrule-002",
  match = {
    class = "^(?i)steam$",
  },
  workspace = 5,
})

apply_window_rule({
  name = "user-window-windowrule-003",
  match = {
    class = "^(?i)org\\.coolercontrol\\.CoolerControl$",
  },
  workspace = 3,
})

-- Send every game window to workspace 2 on DP-3.
-- Matches the class directly: the shared "games" tag rule has a broken regex.
apply_window_rule({
  name = "user-games-to-dp3-steam",
  match = { class = "^steam_app_[0-9]+$" },
  workspace = 2,
  fullscreen = true,
})

apply_window_rule({
  name = "user-games-to-dp3-gamescope",
  match = { class = "^gamescope$" },
  workspace = 2,
  fullscreen = true,
})

apply_window_rule({
  name = "user-games-to-dp3-proton",
  match = { xdg_tag = "^proton-game$" },
  workspace = 2,
  fullscreen = true,
})

-- Steam's "Launching..." popup: keep it on a hidden special workspace, no focus.
apply_window_rule({
  name = "user-steam-launching-hidden",
  match = { class = "^steam$", title = "^Launching\\.\\.\\.$" },
  workspace = "special:steam-launch silent",
  no_initial_focus = true,
})
