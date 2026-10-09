#!/usr/bin/env bash
set -euo pipefail

if /run/wrappers/bin/sudo \
  --preserve-env=HAO_INSTALLER_LANGUAGE,HAO_INSTALLER_TTY,WAYLAND_DISPLAY,XDG_RUNTIME_DIR,LANG \
  "${HAO_INSTALLER_BIN:?Missing installer executable}"; then
  status=0
else
  status=$?
fi
printf '%s\n' "$status" >"$XDG_RUNTIME_DIR/installer-status"
exit "$status"
