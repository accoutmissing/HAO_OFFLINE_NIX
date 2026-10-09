#!/usr/bin/env bash
set -euo pipefail

# A Wayland terminal can display Chinese; the Linux VT cannot display CJK.
# The compositor and file receiver stay under the live ISO's nixos user.
gui_dir="/run/hao-installer-gui"
install -d -m 0700 -o nixos -g users "$gui_dir"
rm -f "$gui_dir/installer-status"
# DRM devices can appear after multi-user services start. Give udev a bounded
# chance to finish loading the display driver before opening the compositor.
udevadm settle --timeout=15 || true
for _ in $(seq 1 50); do
  compgen -G '/dev/dri/card*' >/dev/null && break
  sleep 0.1
done
if runuser -u nixos -- env \
  XDG_RUNTIME_DIR="$gui_dir" LIBSEAT_BACKEND=seatd LANG=zh_CN.UTF-8 \
  HAO_INSTALLER_LANGUAGE=zh HAO_INSTALLER_TTY=/dev/tty \
  dbus-run-session -- cage -s -- kitty \
  --config /etc/hao-installer/kitty.conf --start-as=fullscreen \
  hao-installer-terminal; then
  # Cage can return success even when its child failed to start.
  if [[ -f $gui_dir/installer-status ]] && [[ $(cat "$gui_dir/installer-status") == 0 ]]; then
    exit 0
  fi
fi

printf '\nGraphical setup could not start. Continuing in text mode.\n'
export HAO_INSTALLER_LANGUAGE=en LANG=en_US.UTF-8
export HAO_INSTALLER_TTY=/dev/tty1
if [[ -s /run/hao-installer/state.json ]]; then
  # An interrupted installation may already have formatted the target.
  # Preserve its log and open recovery instead of starting another erase.
  exec "${HAO_INSTALLER_BIN}" --recover
fi
exec "${HAO_INSTALLER_BIN}"
