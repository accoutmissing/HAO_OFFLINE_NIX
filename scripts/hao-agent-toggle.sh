#!/usr/bin/env bash

set -euo pipefail

readonly window_app_id="hao-ai"
readonly session_name="hao-ai"

config_home="${XDG_CONFIG_HOME:-${HOME}/.config}"
readonly tmux_conf="${config_home}/tmux/hao-ai.conf"

work_dir="${HAO_AI_WORKSPACE:-${HOME}/Work}"
if [[ ! -d ${work_dir} ]]; then
  work_dir="${HOME}"
fi

# 启动（或附着已有的）tmux 会话：收起面板不会杀掉 agent，下次呼出恢复原会话。
launch() {
  local tmux_args=()
  if [[ -f ${tmux_conf} ]]; then
    tmux_args=(-f "${tmux_conf}")
  fi

  exec kitty \
    --class "${window_app_id}" \
    --title "HAO AI" \
    --override background='#070722' \
    --override foreground='#f3edf7' \
    --override cursor='#fff59b' \
    --override selection_background='#21215f' \
    --override window_padding_width=0 \
    --override remember_window_size=no \
    --override confirm_os_window_close=0 \
    --directory "${work_dir}" \
    tmux "${tmux_args[@]}" new-session -A -s "${session_name}" hao-agent "$@"
}

if [[ -z ${NIRI_SOCKET:-} ]]; then
  launch "$@"
fi

windows_json="$(niri msg --json windows 2>/dev/null || printf '[]\n')"
window_id="$(jq -r --arg app "${window_app_id}" '[.[] | select(.app_id == $app)][0].id // empty' <<<"${windows_json}")"

if [[ -n ${window_id} ]]; then
  is_focused="$(jq -r --argjson id "${window_id}" '.[] | select(.id == $id) | .is_focused' <<<"${windows_json}")"

  if [[ ${is_focused} == "true" ]]; then
    # 收起：关掉窗口即可，agent 继续跑在 tmux 会话里
    exec niri msg action close-window --id "${window_id}"
  fi

  # 面板存在但没聚焦：直接聚焦
  exec niri msg action focus-window --id "${window_id}"
fi

launch "$@"
