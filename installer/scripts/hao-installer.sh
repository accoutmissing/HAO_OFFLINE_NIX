#!/usr/bin/env bash
set -Eeuo pipefail

STATE_DIR="${HAO_INSTALLER_STATE_DIR:-/run/hao-installer}"
LOG_FILE="$STATE_DIR/install.log"
STATE_FILE="$STATE_DIR/state.json"
CONFIG_SOURCE="${HAO_CONFIG_SOURCE:-/etc/hao-installer/config}"
TTY_PATH="${HAO_INSTALLER_TTY:-/dev/tty}"

CSI=$'\033['
RESET="${CSI}0m"
BOLD="${CSI}1m"
DIM="${CSI}2m"
ACCENT="${CSI}38;5;130m"
WARM="${CSI}38;5;180m"
MUTED="${CSI}38;5;245m"
RED="${CSI}31m"
GREEN="${CSI}32m"
HIDE_CURSOR="${CSI}?25l"
SHOW_CURSOR="${CSI}?25h"
CLEAR="${CSI}2J${CSI}H"

export GUM_CHOOSE_CURSOR_FOREGROUND=1
export GUM_CHOOSE_HEADER_FOREGROUND=180
export GUM_CONFIRM_PROMPT_FOREGROUND=180
export GUM_CONFIRM_SELECTED_FOREGROUND=15
export GUM_CONFIRM_SELECTED_BACKGROUND=130
export GUM_INPUT_CURSOR_FOREGROUND=1
export GUM_INPUT_PROMPT_FOREGROUND=180

INSTALL_STARTED_AT=0
HOST_CONFIG=""
TARGET_DISK=""
TARGET_DISK_LABEL=""
PASSWORD_HASH=""
BOOT_DISK=""
TARGET_DISK_ID=""
TARGET_DISK_SIZE=""
TARGET_DISK_SERIAL=""
TARGET_DISK_WWN=""

tips=(
  "The installer log is saved to /var/log/hao-install.log"
  "Super + Space opens the application launcher"
  "Super + Ctrl + Shift + A opens HAO AI"
  "NixOS generations make system rollbacks straightforward"
  "Your password hash stays outside Git and the Nix store"
  "Switch to tty2 with Ctrl + Alt + F2 for a repair shell"
)

usage() {
  cat <<'EOF'
Usage: hao-installer

Starts the interactive HAO NixOS installer. The current release supports UEFI
full-disk installations only. All existing data on the selected disk is erased.
EOF
}

cleanup() {
  printf '%s' "$SHOW_CURSOR" >"$TTY_PATH" 2>/dev/null || true
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

term_cols() {
  local cols
  cols="$(tput cols 2>/dev/null || true)"
  [[ $cols =~ ^[0-9]+$ ]] || cols=80
  printf '%s\n' "$cols"
}

center() {
  local text="$1" plain width pad
  plain="$(printf '%b' "$text" | sed -E $'s/\x1b\\[[0-9;?]*[A-Za-z]//g')"
  width="$(term_cols)"
  pad=$(((width - ${#plain}) / 2))
  ((pad < 0)) && pad=0
  printf '%*s%b%s\n' "$pad" '' "$text" "$RESET"
}

render_logo() {
  center "${ACCENT}${BOLD}H   H   AAAAA   OOOOO${RESET}"
  center "${ACCENT}${BOLD}H   H   A   A   O   O${RESET}"
  center "${WARM}${BOLD}HHHHH   AAAAA   O   O${RESET}"
  center "${WARM}${BOLD}H   H   A   A   O   O${RESET}"
  center "${WARM}${BOLD}H   H   A   A   OOOOO${RESET}"
  center "${MUTED}N I X O S   I N S T A L L E R${RESET}"
}

screen_header() {
  local title="$1" subtitle="${2:-}"
  printf '%s%s' "$SHOW_CURSOR" "$CLEAR"
  printf '\n'
  render_logo
  printf '\n'
  center "${BOLD}${title}${RESET}"
  [[ -n $subtitle ]] && center "${DIM}${subtitle}${RESET}"
  printf '\n'
}

write_state() {
  local phase="$1" total="$2" title="$3" status="$4"
  jq -n \
    --argjson phase "$phase" \
    --argjson total "$total" \
    --arg title "$title" \
    --arg status "$status" \
    --argjson startedAt "$INSTALL_STARTED_AT" \
    '{phase: $phase, total: $total, title: $title, status: $status, started_at: $startedAt}' \
    >"$STATE_FILE.tmp"
  mv "$STATE_FILE.tmp" "$STATE_FILE"
}

human_duration() {
  local elapsed="$1"
  printf '%dm %02ds' "$((elapsed / 60))" "$((elapsed % 60))"
}

progress_bar() {
  local phase="$1" total="$2" width=36 filled empty
  filled=$((phase * width / total))
  empty=$((width - filled))
  printf '%b[' "$MUTED"
  printf '%b%*s' "$ACCENT" "$filled" '' | tr ' ' '#'
  printf '%b%*s' "$MUTED" "$empty" '' | tr ' ' '-'
  printf '%b]' "$MUTED"
}

render_progress() {
  local phase="$1" total="$2" title="$3" elapsed="$4" frame="$5" tip_index
  tip_index=$((elapsed / 8 % ${#tips[@]}))
  printf '%s%s' "$HIDE_CURSOR" "$CLEAR"
  printf '\n'
  render_logo
  printf '\n'
  center "${BOLD}Installing HAO NixOS${RESET}"
  center "${WARM}${frame}  ${title}${RESET}"
  printf '\n'
  center "$(progress_bar "$phase" "$total")"
  center "${MUTED}Step ${phase}/${total}  |  $(human_duration "$elapsed")${RESET}"
  printf '\n'
  center "${DIM}Tip:${RESET} ${ACCENT}${tips[$tip_index]}${RESET}"
}

persist_log() {
  if mountpoint -q /mnt && [[ -d /mnt/var/log ]]; then
    install -m 0600 -o root -g root "$LOG_FILE" /mnt/var/log/hao-install.log 2>/dev/null || true
    install -m 0600 -o root -g root "$STATE_FILE" /mnt/var/log/hao-install-state.json 2>/dev/null || true
  fi
}

failure_menu() {
  local message="$1" choice
  persist_log

  while true; do
    screen_header "${RED}Installation stopped${RESET}" "$message"
    center "${MUTED}Log: ${LOG_FILE}${RESET}"
    printf '\n'

    choice="$(gum choose \
      --header "Choose a recovery action" \
      "View installation log" \
      "Open repair shell" \
      "Reboot" \
      "Power off")" || choice="Open repair shell"

    case "$choice" in
    "View installation log")
      less "$LOG_FILE" || true
      ;;
    "Open repair shell")
      printf '%s%s' "$SHOW_CURSOR" "$CLEAR"
      echo "Type 'exit' to return to the installer recovery menu."
      bash -l || true
      ;;
    "Reboot")
      systemctl reboot
      ;;
    "Power off")
      systemctl poweroff
      ;;
    esac
  done
}

unexpected_error() {
  local status="$1" line="$2"
  trap - ERR
  printf 'Unexpected installer error at line %s (status %s)\n' "$line" "$status" >>"$LOG_FILE" 2>/dev/null || true
  failure_menu "Unexpected error at line ${line}"
  exit "$status"
}

trap 'unexpected_error "$?" "$LINENO"' ERR

run_phase() {
  local phase="$1" total="$2" title="$3"
  shift 3
  local pid status elapsed=0 frame_index=0 phase_started
  local frames=("|" "/" "-" "+")

  write_state "$phase" "$total" "$title" "running"
  printf '\n[%s/%s] %s\n' "$phase" "$total" "$title" >>"$LOG_FILE"

  "$@" >>"$LOG_FILE" 2>&1 &
  pid=$!
  phase_started="$(date +%s)"

  while kill -0 "$pid" 2>/dev/null; do
    elapsed=$(($(date +%s) - phase_started))
    render_progress "$phase" "$total" "$title" "$elapsed" "${frames[$frame_index]}" >"$TTY_PATH"
    frame_index=$(((frame_index + 1) % ${#frames[@]}))
    sleep 0.5
  done

  set +e
  wait "$pid"
  status=$?
  set -e

  if ((status != 0)); then
    write_state "$phase" "$total" "$title" "failed"
    failure_menu "${title} failed with status ${status}"
    exit "$status"
  fi

  write_state "$phase" "$total" "$title" "complete"
}

resolve_parent_disk() {
  local node="$1" type parent backing source
  node="$(readlink -f "$node" 2>/dev/null || printf '%s' "$node")"

  while [[ -b $node ]]; do
    type="$(lsblk -dnro TYPE "$node" 2>/dev/null || true)"
    if [[ $type == "disk" ]]; then
      printf '%s\n' "$node"
      return 0
    fi
    if [[ $type == "loop" ]]; then
      backing="$(losetup --noheadings --output BACK-FILE "$node" 2>/dev/null | head -n 1)"
      [[ -f $backing ]] || return 1
      source="$(findmnt -rn -o MAJ:MIN --target "$backing" 2>/dev/null || true)"
      [[ -e /sys/dev/block/$source ]] || return 1
      node="/dev/$(basename "$(readlink -f "/sys/dev/block/$source")")"
      continue
    fi
    parent="$(lsblk -dnro PKNAME "$node" 2>/dev/null || true)"
    [[ -n $parent ]] || break
    node="/dev/$parent"
  done

  return 1
}

detect_boot_disk() {
  local iso_device parent boot_disk="" found=0
  while IFS= read -r iso_device; do
    [[ -n $iso_device ]] || continue
    found=1
    parent="$(resolve_parent_disk "$iso_device")" || return 1
    if [[ -n $boot_disk && $parent != "$boot_disk" ]]; then
      return 1
    fi
    boot_disk="$parent"
  done < <(blkid -t LABEL=HAO_INSTALLER -o device 2>/dev/null)
  ((found == 1)) || return 1
  printf '%s\n' "$boot_disk"
}

disk_identity() {
  local device="$1" id
  id="$(lsblk -dnro MAJ:MIN "$device")"
  [[ -n $id ]] || return 1
  printf '%s\n' "$id"
}

preflight() {
  mkdir -p "$STATE_DIR"
  chmod 0700 "$STATE_DIR"
  : >"$LOG_FILE"
  chmod 0600 "$LOG_FILE"

  if ((EUID != 0)); then
    echo "HAO Installer must run as root." >>"$LOG_FILE"
    failure_menu "The installer must run as root"
  fi

  if [[ ! -d /sys/firmware/efi ]]; then
    echo "Legacy BIOS boot detected; UEFI is required." >>"$LOG_FILE"
    failure_menu "UEFI boot is required"
  fi

  if [[ ! -f $CONFIG_SOURCE/flake.nix ]]; then
    echo "Missing installer configuration at $CONFIG_SOURCE" >>"$LOG_FILE"
    failure_menu "The bundled HAO configuration is missing"
  fi

  if ! BOOT_DISK="$(detect_boot_disk)"; then
    echo "Cannot uniquely identify the physical installer disk." >>"$LOG_FILE"
    failure_menu "Cannot safely identify the installer USB disk"
  fi
}

welcome() {
  screen_header "Beautiful, reproducible, agent-ready NixOS" "Keyboard-first setup for HAO_DESKTOP and HAO_OFFLINE"
  center "${WARM}This installer supports UEFI full-disk installation only.${RESET}"
  center "${RED}The selected disk will be completely erased.${RESET}"
  printf '\n'

  if ! gum confirm \
    --default \
    --affirmative "Start Install" \
    --negative "Open Shell" \
    ""; then
    printf '%s%s' "$SHOW_CURSOR" "$CLEAR"
    exec bash -l
  fi
}

configure_network() {
  local connectivity choice
  while true; do
    connectivity="$(nmcli -t -f CONNECTIVITY general 2>/dev/null || true)"
    screen_header "Prepare downloads" "Connect to a LAN, then check GitHub and the Nix cache"
    printf '  LocalSend can receive a Clash config from another device on the same LAN.\n'
    printf '  The ISO includes LocalSend and the Mihomo (Clash) core; no download is needed.\n\n'
    choice="$(gum choose \
      --header "NetworkManager: ${connectivity:-unknown} | Proxy: ${HAO_PROXY_PORT:-off}" \
      "Configure Wi-Fi" \
      "Receive config with LocalSend" \
      "Import and start Clash config" \
      "Check GitHub and Nix cache" \
      "Continue to installation" \
      "Open shell")" || choice="Open shell"

    case "$choice" in
    "Configure Wi-Fi") nmtui-connect || true ;;
    "Receive config with LocalSend") receive_with_localsend ;;
    "Import and start Clash config") import_clash_config ;;
    "Check GitHub and Nix cache") check_downloads ;;
    "Continue to installation")
      if check_downloads; then
        return 0
      fi
      if gum confirm --default=false \
        "Downloads are not reachable. Continue only if everything is cached?"; then
        return 0
      fi
      ;;
    "Open shell")
      printf '%s%s' "$SHOW_CURSOR" "$CLEAR"
      bash -l || true
      ;;
    esac
  done
}

receive_with_localsend() {
  local gui_dir="/run/hao-localsend"
  install -d -m 0700 -o nixos -g users "$gui_dir" /home/nixos/Downloads
  screen_header "LocalSend" "Close the window to return to the installer"
  printf '  Connect both devices to the same LAN; send a Mihomo config.yaml file.\n'
  printf '  Note the saved path shown by LocalSend for the next step.\n\n'
  printf '  Starting the temporary graphical session...\n'
  if ! (
    umask 077
    runuser -u nixos -- env XDG_RUNTIME_DIR="$gui_dir" LIBSEAT_BACKEND=seatd \
      dbus-run-session -- cage -- localsend_app
  ); then
    printf '\n  LocalSend could not open. Use a USB drive and import its config path instead.\n'
  fi
  gum input --prompt "Press Enter to return: " >/dev/null || true
}

import_clash_config() {
  local source_file port proxy_url config_dir="$STATE_DIR/mihomo"
  screen_header "Start Clash proxy" "Import an existing Mihomo-compatible YAML file"
  printf '  Receive it with LocalSend, or mount a USB drive from the repair shell.\n'
  printf '  The imported copy stays under /run, outside the target system.\n\n'
  source_file="$(gum input --placeholder "/home/nixos/Downloads/config.yaml" \
    --prompt "Config file: ")" || return 0
  [[ -n $source_file && -f $source_file ]] || {
    printf '\n  File not found.\n'
    gum input --prompt "Press Enter: " >/dev/null || true
    return 0
  }
  port="$(gum input --value "7890" --prompt "HTTP/mixed port: ")" || return 0
  if [[ ! $port =~ ^[0-9]{1,5}$ ]] || ((10#$port < 1 || 10#$port > 65535)); then
    printf '\n  Invalid port.\n'
    gum input --prompt "Press Enter: " >/dev/null || true
    return 0
  fi
  port="$((10#$port))"
  install -d -m 0700 "$config_dir"
  install -m 0644 /etc/hao-installer/geodata/geoip.dat "$config_dir/geoip.dat"
  install -m 0644 /etc/hao-installer/geodata/geosite.dat "$config_dir/geosite.dat"
  install -m 0600 "$source_file" "$config_dir/config.yaml"
  if ! mihomo -t -d "$config_dir" -f "$config_dir/config.yaml" \
    >"$STATE_DIR/mihomo-test.log" 2>&1; then
    printf '\n  Invalid config. Details: %s/mihomo-test.log\n' "$STATE_DIR"
    gum input --prompt "Press Enter: " >/dev/null || true
    return 0
  fi
  systemctl restart hao-installer-mihomo.service
  proxy_url="http://127.0.0.1:$port"
  if ! curl -fsS --connect-timeout 5 --max-time 25 \
    --proxy "$proxy_url" -o /dev/null https://cache.nixos.org/nix-cache-info; then
    printf '\n  Proxy test failed. Check the config port, selected node and service log.\n'
    printf '  Service log: journalctl -u hao-installer-mihomo\n'
    gum input --prompt "Press Enter: " >/dev/null || true
    return 0
  fi

  # Nix fetches via the daemon, so an installer-shell export alone is not enough.
  install -d -m 0755 /run/systemd/system/nix-daemon.service.d
  printf '[Service]\nEnvironment="http_proxy=%s" "https_proxy=%s" "HTTP_PROXY=%s" "HTTPS_PROXY=%s"\n' \
    "$proxy_url" "$proxy_url" "$proxy_url" "$proxy_url" \
    >/run/systemd/system/nix-daemon.service.d/hao-installer-proxy.conf
  systemctl daemon-reload
  systemctl restart nix-daemon.service
  export http_proxy="$proxy_url" https_proxy="$proxy_url"
  export HTTP_PROXY="$proxy_url" HTTPS_PROXY="$proxy_url"
  HAO_PROXY_PORT="$port"
  printf '\n  Clash is running on 127.0.0.1:%s; Nix downloads use it too.\n' "$port"
  gum input --prompt "Press Enter: " >/dev/null || true
}

check_downloads() {
  local failed=0
  screen_header "Check downloads" "A LAN connection alone may not reach package sources"
  if curl -fsS --connect-timeout 5 --max-time 25 \
    -o /dev/null https://cache.nixos.org/nix-cache-info; then
    printf '  Nix cache: reachable\n'
  else
    printf '  Nix cache: unreachable\n'
    failed=1
  fi
  if curl -fsS --connect-timeout 5 --max-time 25 \
    -o /dev/null https://github.com/; then
    printf '  GitHub: reachable\n'
  else
    printf '  GitHub: unreachable\n'
    failed=1
  fi
  printf '\n'
  gum input --prompt "Press Enter to return: " >/dev/null || true
  ((failed == 0))
}

select_host() {
  local detected choice
  local -a hosts
  detected="HAO_DESKTOP"
  if lspci 2>/dev/null | grep -Eqi 'GTX 1060|Coffee Lake.*Mobile'; then
    detected="HAO_OFFLINE"
  fi

  if [[ $detected == "HAO_OFFLINE" ]]; then
    hosts=("HAO_OFFLINE  - i7-8750H / GTX 1060 laptop" "HAO_DESKTOP  - i5-13600KF / RTX 4070 Super")
  else
    hosts=("HAO_DESKTOP  - i5-13600KF / RTX 4070 Super" "HAO_OFFLINE  - i7-8750H / GTX 1060 laptop")
  fi

  screen_header "Choose this computer" "Detected default: ${detected}"
  choice="$(gum choose \
    --cursor-prefix "> " \
    --selected-prefix "* " \
    --header "Select a hardware profile" \
    "${hosts[@]}")" || exit 130

  HOST_CONFIG="${choice%% *}"
}

select_disk() {
  local choice path size model bytes
  local -a choices=()

  while IFS=$'\t' read -r path bytes size model; do
    [[ -n $path ]] || continue
    [[ $path == "$BOOT_DISK" ]] && continue
    ((bytes >= 68719476736)) || continue
    model="${model:-Unknown model}"
    choices+=("${path}  |  ${size}  |  ${model}")
  done < <(
    lsblk --json --bytes --output PATH,SIZE,MODEL,TYPE,RO |
      jq -r '.blockdevices[]
        | select(.type == "disk" and (.ro == false or .ro == 0))
        | [.path, (.size | tostring),
           (if .size >= 1099511627776 then ((.size / 1099511627776 * 10 | floor) / 10 | tostring) + " TiB"
            else ((.size / 1073741824 * 10 | floor) / 10 | tostring) + " GiB" end),
           (.model // "Unknown model" | gsub("^[ ]+|[ ]+$"; ""))]
        | @tsv'
  )

  if ((${#choices[@]} == 0)); then
    echo "No writable disk of at least 64 GiB was found. Boot disk: ${BOOT_DISK:-unknown}" >>"$LOG_FILE"
    failure_menu "No eligible installation disk was found"
  fi

  screen_header "Choose the installation disk" "The USB installer is hidden automatically"
  choice="$(printf '%s\n' "${choices[@]}" | gum choose --header "All data on the selected disk will be erased")" || exit 130
  TARGET_DISK="${choice%%  |*}"
  TARGET_DISK_LABEL="$choice"
  TARGET_DISK="$(readlink -f "$TARGET_DISK")"
  TARGET_DISK_ID="$(disk_identity "$TARGET_DISK")"
  TARGET_DISK_SIZE="$(lsblk -dnbo SIZE "$TARGET_DISK")"
  TARGET_DISK_SERIAL="$(lsblk -dnro SERIAL "$TARGET_DISK" | xargs)"
  TARGET_DISK_WWN="$(lsblk -dnro WWN "$TARGET_DISK" | xargs)"
  if [[ -z $TARGET_DISK_SERIAL && -z $TARGET_DISK_WWN ]]; then
    echo "Selected disk has no stable serial or WWN: $TARGET_DISK" >>"$LOG_FILE"
    failure_menu "The selected disk has no stable hardware identity"
  fi
}

read_password() {
  local password confirmation

  while true; do
    screen_header "Create the login password" "User: admin (Admin)  |  Password never enters Git or the Nix store"
    password="$(gum input --password --prompt "Password: " --placeholder "At least 8 characters")" || exit 130

    if ((${#password} < 8)); then
      center "${RED}Password must contain at least 8 characters.${RESET}"
      sleep 2
      continue
    fi

    confirmation="$(gum input --password --prompt "Confirm:  " --placeholder "Type it again")" || exit 130
    if [[ $password != "$confirmation" ]]; then
      center "${RED}Passwords do not match.${RESET}"
      sleep 2
      continue
    fi

    PASSWORD_HASH="$(printf '%s\n' "$password" | mkpasswd -m yescrypt -s)"
    unset password confirmation
    [[ $PASSWORD_HASH == \$y\$* ]] && return 0

    echo "mkpasswd did not produce a yescrypt hash" >>"$LOG_FILE"
    failure_menu "Password hashing failed"
  done
}

confirm_summary() {
  local expected typed
  expected="ERASE ${TARGET_DISK##*/}"

  screen_header "Review installation" "Nothing has been changed yet"
  center "${MUTED}Computer${RESET}  ${WARM}${HOST_CONFIG}${RESET}"
  center "${MUTED}User${RESET}      ${WARM}admin (Admin)${RESET}"
  center "${MUTED}Disk${RESET}      ${WARM}${TARGET_DISK_LABEL}${RESET}"
  center "${MUTED}Layout${RESET}    ${WARM}UEFI + Btrfs (@, @home)${RESET}"
  printf '\n'
  center "${RED}${BOLD}Every partition and file on ${TARGET_DISK} will be destroyed.${RESET}"
  center "Type ${BOLD}${expected}${RESET} to authorize the erase."
  printf '\n'

  typed="$(gum input --prompt "> " --placeholder "$expected")" || exit 130
  if [[ $typed != "$expected" ]]; then
    screen_header "Installation cancelled" "The confirmation text did not match; no disk changes were made"
    exec bash -l
  fi
}

verify_target_disk() {
  local type current_boot
  [[ -b $TARGET_DISK ]] || return 1
  type="$(lsblk -dnro TYPE "$TARGET_DISK")"
  [[ $type == "disk" ]] || return 1
  [[ $(disk_identity "$TARGET_DISK") == "$TARGET_DISK_ID" ]] || return 1
  [[ $(lsblk -dnbo SIZE "$TARGET_DISK") == "$TARGET_DISK_SIZE" ]] || return 1
  [[ $(lsblk -dnro SERIAL "$TARGET_DISK" | xargs) == "$TARGET_DISK_SERIAL" ]] || return 1
  [[ $(lsblk -dnro WWN "$TARGET_DISK" | xargs) == "$TARGET_DISK_WWN" ]] || return 1
  current_boot="$(detect_boot_disk)" || return 1
  [[ $current_boot == "$BOOT_DISK" && $TARGET_DISK != "$current_boot" ]] || return 1
}

build_target_before_erase() {
  # This exact configuration is copied to /mnt; hardware files are tracked and
  # never replaced after the disk has been erased.
  nix build --no-link --accept-flake-config --no-write-lock-file \
    "$CONFIG_SOURCE#nixosConfigurations.${HOST_CONFIG}.config.system.build.toplevel"
}

partition_disk() {
  verify_target_disk
  if mountpoint -q /mnt; then
    umount -R /mnt
  fi

  disko \
    --mode destroy,format,mount \
    --yes-wipe-all-disks \
    --argstr device "$TARGET_DISK" \
    "$CONFIG_SOURCE/installer/disko-full-disk.nix"
}

copy_configuration() {
  mkdir -p /mnt/etc/nixos
  cp -a "$CONFIG_SOURCE/." /mnt/etc/nixos/
}

install_password_hash() {
  local target_dir="/mnt/var/lib/hao-secrets" hash_file="$STATE_DIR/password-hash"
  umask 077
  printf '%s\n' "$PASSWORD_HASH" >"$hash_file"
  install -d -m 0700 -o root -g root "$target_dir"
  install -m 0600 -o root -g root "$hash_file" "$target_dir/admin-password-hash"
  rm -f "$hash_file"
  PASSWORD_HASH=""
}

prepare_target_configuration() {
  install_password_hash
}

install_system() {
  nixos-install \
    --no-root-passwd \
    --no-write-lock-file \
    --flake "/mnt/etc/nixos#${HOST_CONFIG}"
}

finish_installation() {
  local elapsed choice
  elapsed=$(($(date +%s) - INSTALL_STARTED_AT))
  write_state 6 6 "Installation complete" "complete"
  persist_log
  sync

  screen_header "${GREEN}HAO NixOS is installed${RESET}" "Completed in $(human_duration "$elapsed")"
  center "${WARM}Remove the USB installer before the computer starts again.${RESET}"
  printf '\n'

  choice="$(gum choose --header "Ready" "Reboot now" "Open shell")" || choice="Open shell"
  case "$choice" in
  "Reboot now") systemctl reboot ;;
  "Open shell")
    printf '%s%s' "$SHOW_CURSOR" "$CLEAR"
    exec bash -l
    ;;
  esac
}

main() {
  [[ ${1:-} == "--help" || ${1:-} == "-h" ]] && {
    usage
    exit 0
  }
  [[ $# == 0 ]] || {
    usage >&2
    exit 2
  }

  preflight
  welcome
  configure_network
  select_host
  select_disk
  read_password
  confirm_summary

  INSTALL_STARTED_AT="$(date +%s)"
  run_phase 1 6 "Building the selected system before erasing" build_target_before_erase
  run_phase 2 6 "Partitioning and formatting ${TARGET_DISK}" partition_disk
  run_phase 3 6 "Copying the HAO configuration" copy_configuration
  run_phase 4 6 "Securing the login password" prepare_target_configuration
  PASSWORD_HASH=""
  run_phase 5 6 "Building and installing NixOS" install_system
  run_phase 6 6 "Syncing files to disk" sync
  finish_installation
}

main "$@"
