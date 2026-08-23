#!/usr/bin/env bash

output="${WAYBAR_OUTPUT_NAME:-}"

if [[ -n "$output" ]]; then
	hyprctl monitors -j | jq -r --arg output "$output" '
		.[] | select(.name == $output) | .activeWorkspace.name
	'
else
	hyprctl activeworkspace -j | jq -r '.name'
fi
