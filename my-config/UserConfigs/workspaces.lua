-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- User workspace rules for Lua workflow.
-- PersistWorkspaceLayout.sh writes workspace layout rules into this file.
-- Keep custom hl.workspace_rule(...) entries here so upgrades preserve them.
-- Converted by hand from the pre-Lua workspaces.conf / WorkSpaceRules.conf
-- (the migration script dropped 3,6-10 and default:true).
hl.workspace_rule({ workspace = "1", monitor = "DP-2", layout = "master", default = true })
hl.workspace_rule({ workspace = "2", monitor = "DP-3", layout = "master", default = true })
hl.workspace_rule({ workspace = "3", monitor = "DP-2", layout = "master"})
hl.workspace_rule({ workspace = "4", monitor = "DP-3", layout = "master" })
hl.workspace_rule({ workspace = "5", monitor = "DP-2", layout = "master" })
hl.workspace_rule({ workspace = "6", monitor = "DP-3", layout = "master"})
hl.workspace_rule({ workspace = "7", monitor = "DP-2", layout = "master"})
hl.workspace_rule({ workspace = "8", monitor = "DP-3", layout = "master"})
hl.workspace_rule({ workspace = "9", monitor = "DP-2", layout = "master"})
hl.workspace_rule({ workspace = "10", monitor = "DP-3", layout = "master"})
hl.workspace_rule({ workspace = "11", monitor = "HEADLESS-1", layout = "scrolling" })
