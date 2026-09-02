#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hao"
MARKER="$STATE_DIR/first-login-v1"
FORCE=0

if [[ ${1:-} == "--force" ]]; then
  FORCE=1
elif [[ $# -gt 0 ]]; then
  echo "Usage: hao-welcome [--force]" >&2
  exit 2
fi

if [[ -e $MARKER && $FORCE -eq 0 ]]; then
  exit 0
fi

mkdir -p "$STATE_DIR"

# Noctalia may start a few seconds after graphical-session.target. Only mark the
# welcome as complete after the notification service has accepted a message.
delivered=0
for _ in $(seq 1 60); do
  if notify-send \
    --app-name "HAO" \
    --icon computer-symbolic \
    --urgency normal \
    "Welcome to HAO NixOS" \
    "Press Super + Space to open apps, settings and system controls."; then
    delivered=1
    break
  fi
  sleep 1
done

((delivered == 1)) || exit 1

notify-send \
  --app-name "HAO" \
  --icon input-keyboard-symbolic \
  "Essential shortcuts" \
  "Super + Return opens the terminal. Super + Shift + / shows all key bindings." || true

notify-send \
  --app-name "HAO AI" \
  --icon utilities-terminal \
  "Your native AI workspace is ready" \
  "Press Super + Ctrl + Shift + A to choose Codex, Claude Code or OpenCode." || true

touch "$MARKER"
