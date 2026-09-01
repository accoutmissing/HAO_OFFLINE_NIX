#!/usr/bin/env bash

set -euo pipefail

readonly supported_agents=(codex claude opencode)
readonly config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/hao-ai"
readonly default_file="${config_dir}/default-agent"

usage() {
  cat <<'EOF'
用法：
  hao-agent                 启动默认 Agent
  hao-agent --pick          图形选择 Agent 后启动
  hao-agent --set NAME      设置默认 Agent
  hao-agent --current       显示默认 Agent
  hao-agent --list          列出可用 Agent
  hao-agent [Agent 参数...] 将参数传给默认 Agent

支持的 Agent：codex、claude、opencode
EOF
}

is_supported() {
  local candidate="${1:-}"
  local agent

  for agent in "${supported_agents[@]}"; do
    if [[ ${candidate} == "${agent}" ]]; then
      return 0
    fi
  done

  return 1
}

read_default() {
  local configured="codex"

  if [[ -r ${default_file} ]]; then
    IFS= read -r configured <"${default_file}" || true
  fi

  if ! is_supported "${configured}"; then
    configured="codex"
  fi

  printf '%s\n' "${configured}"
}

set_default() {
  local selected="${1:-}"

  if ! is_supported "${selected}"; then
    printf '不支持的 Agent：%s\n' "${selected:-<空>}" >&2
    usage >&2
    exit 2
  fi

  install -d -m 700 "${config_dir}"
  printf '%s\n' "${selected}" >"${default_file}"
  chmod 600 "${default_file}"
  printf '默认 Agent 已设为 %s\n' "${selected}"
}

pick_agent() {
  local selected

  selected="$(printf '%s\n' "${supported_agents[@]}" | fuzzel --dmenu --prompt='AI Agent > ')"
  if [[ -z ${selected} ]]; then
    exit 0
  fi

  if ! is_supported "${selected}"; then
    printf '无效选择：%s\n' "${selected}" >&2
    exit 2
  fi

  printf '%s\n' "${selected}"
}

selected_agent=""

case "${1:-}" in
--set)
  set_default "${2:-}"
  exit 0
  ;;
--current)
  read_default
  exit 0
  ;;
--list)
  printf '%s\n' "${supported_agents[@]}"
  exit 0
  ;;
--pick)
  shift
  selected_agent="$(pick_agent)"
  if [[ -z ${selected_agent} ]]; then
    exit 0
  fi
  ;;
--help | -h)
  usage
  exit 0
  ;;
esac

if [[ -z ${selected_agent} ]]; then
  selected_agent="$(read_default)"
fi

if ! command -v "${selected_agent}" >/dev/null 2>&1; then
  printf 'Agent 未安装或不在 PATH 中：%s\n' "${selected_agent}" >&2
  exit 127
fi

if [[ ${PWD} == "${HOME}" && -d "${HOME}/Work" ]]; then
  cd "${HOME}/Work"
fi

exec "${selected_agent}" "$@"
