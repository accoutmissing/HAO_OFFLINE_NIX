#!/usr/bin/env bash

set -euo pipefail

if [[ -z ${NIRI_SOCKET:-} ]]; then
  exec hao-agent "$@"
fi

windows_json="$(niri msg --json windows 2>/dev/null || printf '[]\n')"
window_id="$(jq -r '[.[] | select(.app_id == "hao-ai")][0].id // empty' <<<"${windows_json}")"

if [[ -n ${window_id} ]]; then
  is_focused="$(jq -r --argjson id "${window_id}" '.[] | select(.id == $id) | .is_focused' <<<"${windows_json}")"

  if [[ ${is_focused} == "true" ]]; then
    exec niri msg action focus-workspace-previous
  fi

  exec niri msg action focus-window --id "${window_id}"
fi

work_dir="${HAO_AI_WORKSPACE:-${HOME}/Work}"
if [[ ! -d ${work_dir} ]]; then
  work_dir="${HOME}"
fi

exec kitty \
  --class hao-ai \
  --title "HAO AI" \
  --directory "${work_dir}" \
  hao-agent "$@"
