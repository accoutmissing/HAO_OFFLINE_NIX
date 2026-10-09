#!/usr/bin/env bash
set -Eeuo pipefail

STATE_DIR="${HAO_INSTALLER_STATE_DIR:-/run/hao-installer}"
LOG_FILE="$STATE_DIR/install.log"
STATE_FILE="$STATE_DIR/state.json"
CONFIG_SOURCE="${HAO_CONFIG_SOURCE:-/etc/hao-installer/config}"
BUNDLE_DIR="${HAO_INSTALLER_BUNDLE_DIR:-/etc/hao-installer}"
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
ACTIVE_PHASE_PID=""
HOST_CONFIG=""
TARGET_DISK=""
TARGET_DISK_LABEL=""
PASSWORD_HASH=""
BOOT_DISK=""
TARGET_DISK_ID=""
TARGET_DISK_SIZE=""
TARGET_DISK_SERIAL=""
TARGET_DISK_WWN=""
PREBUILT_SYSTEM=""
SELECTED_CACHES=""
NIX_OPTIONS=(--option connect-timeout 5 --option download-attempts 2)

tips=(
  "The installer log is saved to /var/log/hao-install.log"
  "Super + Space opens the application launcher"
  "Super + Ctrl + Shift + A opens HAO AI"
  "NixOS generations make system rollbacks straightforward"
  "Your password hash stays outside Git and the Nix store"
  "Switch to tty2 with Ctrl + Alt + F2 for a repair shell"
)
if [[ ${HAO_INSTALLER_LANGUAGE:-en} == zh ]]; then
  tips=(
    "安装日志保存到 /var/log/hao-install.log"
    "Win + 空格：打开软件启动器"
    "Win + Ctrl + Shift + A：打开 HAO AI"
    "系统更新后仍可从启动菜单回到旧版本"
    "密码哈希只保存在本机的私有目录"
    "Ctrl + Alt + F2：切换到维修终端"
  )
fi

msg() {
  if [[ ${HAO_INSTALLER_LANGUAGE:-en} == zh ]]; then
    printf '%s' "$2"
  else
    printf '%s' "$1"
  fi
}

pause() {
  gum input --prompt "$(msg 'Press Enter to return: ' '按回车返回：')" >/dev/null || true
}

# Keep action IDs independent of translated labels.
menu() {
  local header="$1" choice index
  shift
  local -a pairs=("$@") labels=()
  for ((index = 1; index < ${#pairs[@]}; index += 2)); do
    labels+=("${pairs[$index]}")
  done
  choice="$(gum choose --header "$header" "${labels[@]}")" || return 130
  for ((index = 1; index < ${#pairs[@]}; index += 2)); do
    if [[ $choice == "${pairs[$index]}" ]]; then
      printf '%s\n' "${pairs[$((index - 1))]}"
      return 0
    fi
  done
  return 1
}

usage() {
  cat <<'EOF'
Usage: hao-installer [--recover]

Starts the interactive HAO NixOS installer. The current release supports UEFI
full-disk installations only. All existing data on the selected disk is erased.
EOF
}

cleanup() {
  if [[ -n $ACTIVE_PHASE_PID ]]; then
    # Each phase owns a process group. Closing the graphical terminal or
    # interrupting the TUI must stop its downloads/partitioning descendants.
    kill -TERM -- "-$ACTIVE_PHASE_PID" 2>/dev/null || true
    wait "$ACTIVE_PHASE_PID" 2>/dev/null || true
    ACTIVE_PHASE_PID=""
  fi
  if ((INSTALL_STARTED_AT > 0)); then persist_log; fi
  printf '%s' "$SHOW_CURSOR" >"$TTY_PATH" 2>/dev/null || true
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

term_cols() {
  local cols
  cols="$(tput cols 2>/dev/null || true)"
  [[ $cols =~ ^[0-9]+$ ]] || cols=80
  printf '%s\n' "$cols"
}

center() {
  local text="$1" plain width content_width pad
  plain="$(printf '%b' "$text" | sed -E $'s/\x1b\\[[0-9;?]*[A-Za-z]//g')"
  width="$(term_cols)"
  content_width="$(printf '%s\n' "$plain" | wc -L)"
  pad=$(((width - content_width) / 2))
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
  center "${BOLD}$(msg 'Installing HAO NixOS' '正在安装 HAO NixOS')${RESET}"
  center "${WARM}${frame}  ${title}${RESET}"
  printf '\n'
  center "$(progress_bar "$phase" "$total")"
  center "${MUTED}$(msg 'Step' '步骤') ${phase}/${total}  |  $(human_duration "$elapsed")${RESET}"
  printf '\n'
  center "${DIM}$(msg 'Tip:' '提示：')${RESET} ${ACCENT}${tips[$tip_index]}${RESET}"
}

persist_log() {
  if mountpoint -q /mnt && [[ -d /mnt/var/log ]]; then
    install -m 0600 -o root -g root "$LOG_FILE" /mnt/var/log/hao-install.log 2>/dev/null || true
    install -m 0600 -o root -g root "$STATE_FILE" /mnt/var/log/hao-install-state.json 2>/dev/null || true
  fi
}

failure_menu() {
  local message="$1" retry_allowed="${2:-false}" choice
  local -a actions
  persist_log

  while true; do
    screen_header "${RED}$(msg 'Installation stopped' '安装已暂停')${RESET}" "$message"
    center "${MUTED}Log: ${LOG_FILE}${RESET}"
    printf '\n'

    actions=()
    if [[ $retry_allowed == true ]]; then
      actions+=(retry "$(msg 'Retry this step' '重试当前步骤')")
      if [[ -z $PREBUILT_SYSTEM ]]; then
        actions+=(network "$(msg 'Fix network, then retry' '调整网络后重试')")
      fi
    fi
    actions+=(log "$(msg 'View installation log' '查看安装日志')"
    shell "$(msg 'Open repair shell' '打开维修终端')"
    reboot "$(msg 'Reboot' '重启电脑')"
    poweroff "$(msg 'Power off' '关机')")
    choice="$(menu "$(msg 'Choose a recovery action' '选择处理方式')" "${actions[@]}")" || choice=shell

    case "$choice" in
    retry) return 0 ;;
    network)
      configure_network
      return 0
      ;;
    log)
      less "$LOG_FILE" || true
      ;;
    shell)
      printf '%s%s' "$SHOW_CURSOR" "$CLEAR"
      echo "Type 'exit' to return to the installer recovery menu."
      bash -l || true
      ;;
    reboot)
      systemctl reboot
      ;;
    poweroff)
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
  local pid status elapsed=0 frame_index=0 phase_started retryable=false
  local frames=("|" "/" "-" "+")
  case "${1:-}" in
  build_target_before_erase | install_system) retryable=true ;;
  esac

  while true; do
    write_state "$phase" "$total" "$title" "running"
    printf '\n[%s/%s] %s\n' "$phase" "$total" "$title" >>"$LOG_FILE"

    # Background failures must return to the foreground recovery UI. Keep
    # errexit enabled so a failed safety check cannot continue to disk writes.
    set -m
    (
      trap - EXIT ERR
      "$@"
    ) </dev/null >>"$LOG_FILE" 2>&1 &
    pid=$!
    set +m
    ACTIVE_PHASE_PID="$pid"
    phase_started="$(date +%s)"

    while kill -0 "$pid" 2>/dev/null; do
      elapsed=$(($(date +%s) - phase_started))
      render_progress "$phase" "$total" "$title" "$elapsed" "${frames[$frame_index]}" >"$TTY_PATH"
      frame_index=$(((frame_index + 1) % ${#frames[@]}))
      sleep 0.5
    done

    if wait "$pid"; then
      status=0
    else
      status=$?
    fi
    ACTIVE_PHASE_PID=""

    if ((status != 0)); then
      write_state "$phase" "$total" "$title" "failed"
      failure_menu "${title} $(msg 'failed with status' '失败，状态码') ${status}" "$retryable"
      [[ $retryable == true ]] && continue
      exit "$status"
    fi

    write_state "$phase" "$total" "$title" "complete"
    break
  done
}

resolve_parent_disk() {
  local node="$1" type parent backing source
  node="$(readlink -f "$node" 2>/dev/null || printf '%s' "$node")"

  while [[ -b $node ]]; do
    type="$(lsblk -dnro TYPE "$node" 2>/dev/null || true)"
    if [[ $type == "disk" || $type == "rom" ]]; then
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
    failure_menu "$(msg 'The installer must run as root' '请以管理员权限运行安装器')"
  fi

  if [[ ! -d /sys/firmware/efi ]]; then
    echo "Legacy BIOS boot detected; UEFI is required." >>"$LOG_FILE"
    failure_menu "$(msg 'UEFI boot is required' '请重启并选择 UEFI 模式的 U 盘启动项')"
  fi

  if [[ ! -f $CONFIG_SOURCE/flake.nix ]]; then
    echo "Missing installer configuration at $CONFIG_SOURCE" >>"$LOG_FILE"
    failure_menu "$(msg 'The bundled HAO configuration is missing' '镜像缺少系统配置，请重新下载并校验')"
  fi

  if ! BOOT_DISK="$(detect_boot_disk)"; then
    echo "Cannot uniquely identify the physical installer disk." >>"$LOG_FILE"
    failure_menu "$(msg 'Cannot safely identify the installer USB disk' '无法确认安装介质，为保护数据已停止')"
  fi
}

welcome() {
  screen_header "$(msg 'Install HAO NixOS' '安装 HAO NixOS')" "$(msg 'Arrow keys to choose; Enter to continue' '方向键选择，回车继续')"
  center "${WARM}$(msg 'UEFI full-disk installation only.' '适用于 UEFI 整盘安装。')${RESET}"
  center "${RED}$(msg 'The selected disk will be completely erased.' '所选硬盘会被全部清空，请先备份。')${RESET}"
  printf '\n'

  if ! gum confirm \
    --default \
    --affirmative "$(msg 'Start Install' '开始安装')" \
    --negative "$(msg 'Open Shell' '打开维修终端')" \
    ""; then
    printf '%s%s' "$SHOW_CURSOR" "$CLEAR"
    exec bash -l
  fi
}

probe_caches() {
  local index pid url priority proxy_url="${1:-}"
  local -a request_options=() pids=() urls=(
    "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
    "https://mirrors.ustc.edu.cn/nix-channels/store"
    "https://cache.nixos.org"
    "https://nix-community.cachix.org"
    "https://noctalia.cachix.org"
  )
  [[ -z $proxy_url ]] || request_options=(--proxy "$proxy_url" --noproxy "")
  install -d -m 0700 "$STATE_DIR/network"
  # Run bounded checks together instead of making a failed source delay every
  # download. An HTTP success page alone is not a valid Nix cache response.
  for index in "${!urls[@]}"; do
    rm -f "$STATE_DIR/network/$index.ok"
    (
      if curl -fsSL --connect-timeout 3 --max-time 5 \
        --retry 1 --retry-connrefused --retry-delay 1 --retry-max-time 8 \
        "${request_options[@]}" \
        "${urls[$index]}/nix-cache-info" >"$STATE_DIR/network/$index.info" \
        2>"$STATE_DIR/network/$index.error" &&
        grep -qx 'StoreDir: /nix/store' "$STATE_DIR/network/$index.info"; then
        : >"$STATE_DIR/network/$index.ok"
      fi
    ) &
    pids+=("$!")
  done
  for pid in "${pids[@]}"; do wait "$pid" || true; done
  SELECTED_CACHES=""
  for index in "${!urls[@]}"; do
    [[ -f $STATE_DIR/network/$index.ok ]] || continue
    url="${urls[$index]}"
    priority=$((10 + index * 10))
    SELECTED_CACHES+="${SELECTED_CACHES:+ }${url}?priority=${priority}"
  done
  NIX_OPTIONS=(--option connect-timeout 5 --option download-attempts 2)
  if [[ -n $SELECTED_CACHES ]]; then
    NIX_OPTIONS+=(--option substituters "$SELECTED_CACHES" --option extra-substituters "")
    return 0
  fi
  return 1
}

configure_network() {
  local connectivity choice
  [[ -n $PREBUILT_SYSTEM ]] && return 0
  screen_header "$(msg 'Checking downloads' '正在检查下载源')" \
    "$(msg 'Checking China mirrors and official backups' '检测国内镜像与官方后备源，请稍候')"
  if probe_caches; then return 0; fi
  while true; do
    connectivity="$(nmcli -t -f CONNECTIVITY general 2>/dev/null || true)"
    screen_header "$(msg 'Connect to the internet' '连接网络')" \
      "$(msg 'Use Ethernet, Wi-Fi or a phone hotspot' '优先插网线，也可使用 Wi-Fi 或手机热点')"
    choice="$(menu "$(msg 'Network' '网络状态')：${connectivity:-unknown}" \
      check "$(msg 'Check downloads and continue' '检查下载源并继续')" \
      wifi "$(msg 'Connect to Wi-Fi' '连接 Wi-Fi')" \
      proxy "$(msg 'Use a proxy on another device' '使用局域网设备的代理')" \
      receive "$(msg 'Receive config with LocalSend' '从手机或电脑接收代理配置')" \
      import "$(msg 'Import and start Clash config' '导入代理配置并启用')" \
      direct "$(msg 'Turn off the temporary proxy' '关闭临时代理')" \
      cached "$(msg 'Continue with cached packages' '使用已缓存的软件继续')" \
      shell "$(msg 'Open shell' '打开维修终端')")" || choice=shell
    case "$choice" in
    wifi) nmtui-connect || true ;;
    receive)
      receive_with_localsend
      continue
      ;;
    import) import_clash_config ;;
    proxy) configure_lan_proxy ;;
    direct) disable_proxy ;;
    cached)
      if gum confirm --default=false "$(msg 'Continue only if all required packages are already cached?' '确认所需软件都已缓存？构建失败不会清盘。')"; then
        return 0
      fi
      continue
      ;;
    shell)
      printf '%s%s' "$SHOW_CURSOR" "$CLEAR"
      bash -l || true
      continue
      ;;
    esac
    screen_header "$(msg 'Checking downloads' '正在检查下载源')"
    if probe_caches; then return 0; fi
    printf '\n  %s\n' "$(msg 'No usable cache found. Check the connection or proxy.' '暂未找到可用下载源，请检查联网或代理。')"
    pause
  done
}

valid_proxy_url() {
  local url="$1" port
  [[ $url =~ ^http://[a-zA-Z0-9][a-zA-Z0-9.-]*:([0-9]{1,5})$ ]] || return 1
  port="${BASH_REMATCH[1]}"
  ((10#$port >= 1 && 10#$port <= 65535))
}

apply_proxy() {
  local proxy_url="$1"
  valid_proxy_url "$proxy_url" || return 1
  install -d -m 0755 /run/systemd/system/nix-daemon.service.d
  printf '[Service]\nEnvironment="http_proxy=%s" "https_proxy=%s" "HTTP_PROXY=%s" "HTTPS_PROXY=%s"\n' \
    "$proxy_url" "$proxy_url" "$proxy_url" "$proxy_url" \
    >/run/systemd/system/nix-daemon.service.d/hao-installer-proxy.conf
  systemctl daemon-reload
  systemctl restart nix-daemon.service
  export http_proxy="$proxy_url" https_proxy="$proxy_url"
  export HTTP_PROXY="$proxy_url" HTTPS_PROXY="$proxy_url"
}

disable_proxy() {
  rm -f /run/systemd/system/nix-daemon.service.d/hao-installer-proxy.conf
  unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
  systemctl daemon-reload
  systemctl restart nix-daemon.service
  systemctl stop hao-installer-mihomo.service || true
}

configure_lan_proxy() {
  local proxy_url
  screen_header "$(msg 'Use another device as a proxy' '使用另一台设备的代理')"
  printf '  %s\n\n' "$(msg 'Enable LAN access there and use its IP and HTTP/mixed port.' '在对方设备允许局域网连接，填写其 IP 与 HTTP/mixed 端口。')"
  proxy_url="$(gum input --prompt "$(msg 'Proxy: ' '代理地址：')" --placeholder 'http://192.168.1.10:7890')" || return 0
  if ! valid_proxy_url "$proxy_url"; then
    printf '\n  %s\n' "$(msg 'Use http://host:port, without credentials or a path.' '地址格式为 http://IP或主机名:端口，不含账号或路径。')"
    pause
    return 0
  fi
  apply_proxy "$proxy_url"
}

receive_with_localsend() {
  local gui_dir="/run/hao-localsend"
  install -d -m 0700 -o nixos -g users "$gui_dir" /home/nixos/Downloads
  screen_header "LocalSend" "$(msg 'Close the window to return to the installer' '发送配置文件后关闭窗口，即可继续安装')"
  printf '  %s\n\n' "$(msg 'Use the same LAN and send a complete Mihomo YAML config.' '两台设备接入同一局域网，发送完整的 Mihomo YAML 配置。')"
  if ! (
    umask 077
    if [[ -n ${WAYLAND_DISPLAY:-} ]]; then
      runuser -u nixos -- env XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
        dbus-run-session -- localsend_app
    else
      runuser -u nixos -- env XDG_RUNTIME_DIR="$gui_dir" LIBSEAT_BACKEND=seatd \
        dbus-run-session -- cage -- localsend_app
    fi
  ); then
    printf '\n  %s\n' "$(msg 'LocalSend could not open; import a config from a USB drive instead.' 'LocalSend 无法打开，请改从 U 盘导入配置文件。')"
  fi
  pause
}

import_clash_config() {
  local source_file port proxy_url default_file config_dir="$STATE_DIR/mihomo"
  screen_header "$(msg 'Start Clash proxy' '导入代理配置')" "$(msg 'Use a complete Mihomo-compatible YAML file' '使用包含可用节点的 Mihomo 配置文件')"
  printf '  %s\n\n' "$(msg 'Use a file received with LocalSend or copied from a USB drive.' '选择通过 LocalSend 收到或从 U 盘复制的配置文件。')"
  default_file="$(find /home/nixos/Downloads -maxdepth 2 -type f \( -iname '*.yaml' -o -iname '*.yml' \) -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 1 | cut -d ' ' -f 2- || true)"
  source_file="$(gum input --value "$default_file" --placeholder "/home/nixos/Downloads/config.yaml" \
    --prompt "$(msg 'Config file: ' '配置文件：')")" || return 0
  [[ -n $source_file && -f $source_file ]] || {
    printf '\n  %s\n' "$(msg 'File not found.' '未找到文件，请检查路径。')"
    pause
    return 0
  }
  # Read the config's listening port instead of making the user find it.
  port="$(yq -r '.["mixed-port"] // .port // 0' "$source_file" 2>/dev/null || true)"
  if [[ ! $port =~ ^[0-9]{1,5}$ ]] || ((10#$port < 1 || 10#$port > 65535)); then
    printf '\n  %s\n' "$(msg 'No valid HTTP/mixed port in the config.' '配置没有有效的 HTTP/mixed 代理端口。')"
    pause
    return 0
  fi
  port="$((10#$port))"
  install -d -m 0700 "$config_dir"
  install -m 0644 /etc/hao-installer/geodata/geoip.dat "$config_dir/geoip.dat"
  install -m 0644 /etc/hao-installer/geodata/geosite.dat "$config_dir/geosite.dat"
  install -m 0600 "$source_file" "$config_dir/config.yaml"
  if ! mihomo -t -d "$config_dir" -f "$config_dir/config.yaml" \
    >"$STATE_DIR/mihomo-test.log" 2>&1; then
    printf '\n  %s\n' "$(msg 'Invalid config; see mihomo-test.log in the log folder.' '配置检查失败，可在日志目录查看 mihomo-test.log。')"
    pause
    return 0
  fi
  systemctl restart hao-installer-mihomo.service
  proxy_url="http://127.0.0.1:$port"
  screen_header "$(msg 'Checking the proxy' '正在检测代理')"
  if ! probe_caches "$proxy_url"; then
    printf '\n  %s\n' "$(msg 'The proxy cannot reach a usable cache. Check its nodes and configuration.' '代理无法访问可用下载源，请检查配置及节点。')"
    pause
    return 0
  fi

  # Nix fetches via the daemon; a shell export alone is not enough.
  apply_proxy "$proxy_url"
  printf '\n  %s\n' "$(msg 'The temporary proxy is ready for installation downloads.' '临时代理已启用，可用于安装下载。')"
  pause
}

select_host() {
  local detected choice
  local -a hosts
  if [[ -f $BUNDLE_DIR/offline-host || -f $BUNDLE_DIR/offline-system ]]; then
    HOST_CONFIG="$(cat "$BUNDLE_DIR/offline-host")"
    PREBUILT_SYSTEM="$(cat "$BUNDLE_DIR/offline-system")"
    if [[ $HOST_CONFIG != HAO_DESKTOP && $HOST_CONFIG != HAO_OFFLINE ]] ||
      [[ ! $PREBUILT_SYSTEM =~ ^/nix/store/[a-z0-9]{32}-[a-zA-Z0-9._+-]+$ ]] ||
      [[ ! -x $PREBUILT_SYSTEM/bin/switch-to-configuration ]]; then
      failure_menu "$(msg 'The offline system bundle is incomplete' '离线镜像中的系统不完整，请重新校验镜像')"
    fi
    screen_header "$(msg 'Offline installation' '离线安装')" "$HOST_CONFIG"
    center "$(msg 'The system is bundled; no network download is needed.' '系统已预装在镜像中，安装时无需联网下载。')"
    gum confirm --affirmative "$(msg 'Continue' '继续')" --negative "$(msg 'Cancel' '取消')" \
      "$(msg 'Use the hardware profile shown above?' '请确认镜像对应你的机型。')" || exit 130
    return 0
  fi
  detected="HAO_DESKTOP"
  if lspci 2>/dev/null | grep -Eqi 'GTX 1060|Coffee Lake.*Mobile'; then
    detected="HAO_OFFLINE"
  fi

  if [[ $detected == "HAO_OFFLINE" ]]; then
    hosts=("HAO_OFFLINE  - i7-8750H / GTX 1060 laptop" "HAO_DESKTOP  - i5-13600KF / RTX 4070 Super")
  else
    hosts=("HAO_DESKTOP  - i5-13600KF / RTX 4070 Super" "HAO_OFFLINE  - i7-8750H / GTX 1060 laptop")
  fi

  screen_header "$(msg 'Choose this computer' '选择机型')" "$(msg 'Recommended profile' '建议机型')：${detected}"
  choice="$(gum choose \
    --cursor-prefix "> " \
    --selected-prefix "* " \
    --header "$(msg 'Choose the matching CPU and graphics card' '按处理器与显卡选择对应机型')" \
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

  screen_header "$(msg 'Choose the installation disk' '选择安装硬盘')" "$(msg 'The installer USB is hidden automatically' '已自动隐藏安装 U 盘')"
  choice="$(printf '%s\n' "${choices[@]}" | gum choose --header "$(msg 'All data on the selected disk will be erased' '请核对容量和型号：这块硬盘会被全部清空')")" || exit 130
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
    screen_header "$(msg 'Create the login password' '设置登录密码')" "$(msg 'Login user: admin (Admin)' '登录用户名：admin（Admin）')"
    password="$(gum input --password --prompt "$(msg 'Password: ' '密码：')" --placeholder "$(msg 'At least 8 characters' '至少 8 个字符，输入时不显示明文')")" || exit 130

    if ((${#password} < 8)); then
      center "${RED}$(msg 'Password must contain at least 8 characters.' '密码至少需要 8 个字符。')${RESET}"
      sleep 2
      continue
    fi

    confirmation="$(gum input --password --prompt "$(msg 'Confirm: ' '再次输入：')" --placeholder "$(msg 'Type it again' '再次输入同一个密码')")" || exit 130
    if [[ $password != "$confirmation" ]]; then
      center "${RED}$(msg 'Passwords do not match.' '两次密码不同，请重新输入。')${RESET}"
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

  screen_header "$(msg 'Review installation' '确认安装')" "$(msg 'Nothing has been changed yet' '目前尚未修改硬盘')"
  center "${MUTED}$(msg 'Computer' '机型')${RESET}  ${WARM}${HOST_CONFIG}${RESET}"
  center "${MUTED}$(msg 'User' '用户')${RESET}      ${WARM}admin (Admin)${RESET}"
  center "${MUTED}$(msg 'Disk' '硬盘')${RESET}      ${WARM}${TARGET_DISK_LABEL}${RESET}"
  center "${MUTED}$(msg 'Layout' '布局')${RESET}    ${WARM}UEFI + Btrfs (@, @home)${RESET}"
  center "${MUTED}$(msg 'Install from' '安装来源')${RESET}  ${WARM}$(if [[ -n $PREBUILT_SYSTEM ]]; then msg 'Offline ISO' '离线镜像'; else msg 'Online download' '联网下载'; fi)${RESET}"
  printf '\n'
  center "${RED}${BOLD}${TARGET_DISK}：$(msg 'All partitions and files will be erased.' '所有分区和文件都会被清空。')${RESET}"
  center "$(msg 'Type this text to confirm:' '请准确输入以下文字确认：') ${BOLD}${expected}${RESET}"
  printf '\n'

  typed="$(gum input --prompt "> " --placeholder "$expected")" || exit 130
  if [[ $typed != "$expected" ]]; then
    screen_header "$(msg 'Installation cancelled' '已取消安装')" "$(msg 'Confirmation did not match; the disk was not changed' '确认文字不匹配，硬盘未作修改')"
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
  [[ -x $BUNDLE_DIR/partition-disk ]] || {
    printf 'The bundled partition tool is missing.\n' >&2
    return 1
  }
  # This exact configuration is copied to /mnt; hardware files are tracked and
  # never replaced after the disk has been erased.
  if [[ -n $PREBUILT_SYSTEM ]]; then
    local -a store_paths
    nix-store --query --requisites "$PREBUILT_SYSTEM" >"$STATE_DIR/store-paths"
    mapfile -t store_paths <"$STATE_DIR/store-paths"
    ((${#store_paths[@]} > 0)) || return 1
    nix-store --check-validity "${store_paths[@]}"
    ln -sfn "$PREBUILT_SYSTEM" "$STATE_DIR/target-system"
  else
    nix build --out-link "$STATE_DIR/target-system" --accept-flake-config --no-write-lock-file \
      "${NIX_OPTIONS[@]}" \
      "$CONFIG_SOURCE#nixosConfigurations.${HOST_CONFIG}.config.system.build.toplevel"
  fi
  local closure_size
  closure_size="$(nix path-info --closure-size "$(readlink -f "$STATE_DIR/target-system")" | awk '{print $2}')"
  [[ $closure_size =~ ^[0-9]+$ ]] || return 1
  if ((closure_size + 8589934592 > TARGET_DISK_SIZE)); then
    printf 'Target disk is too small for the system plus 8 GiB free space.\n' >&2
    return 1
  fi
}

partition_disk() {
  verify_target_disk
  if mountpoint -q /mnt; then
    umount -R /mnt
  fi

  "$BUNDLE_DIR/partition-disk" "$TARGET_DISK"
}

copy_configuration() {
  mkdir -p /mnt/etc/nixos
  # Sources on the ISO are read-only store files; the installed configuration
  # must be editable for future updates.
  cp -r --no-preserve=mode,ownership "$CONFIG_SOURCE/." /mnt/etc/nixos/
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
  # Keep the Wi-Fi connection entered in the live ISO for the first boot.
  # Its credentials stay in root-only files outside Git and the Nix store.
  local connection
  if [[ -d /etc/NetworkManager/system-connections ]]; then
    install -d -m 0700 -o root -g root /mnt/etc/NetworkManager/system-connections
    while IFS= read -r -d '' connection; do
      install -m 0600 -o root -g root "$connection" \
        "/mnt/etc/NetworkManager/system-connections/$(basename "$connection")"
    done < <(find /etc/NetworkManager/system-connections -maxdepth 1 -type f -name '*.nmconnection' -print0)
  fi
}

install_system() {
  local system_path
  system_path="$(readlink -f "$STATE_DIR/target-system")"
  [[ -x $system_path/bin/switch-to-configuration ]] || return 1
  # Install the exact system verified BEFORE erasing. Do not evaluate the
  # flake a second time or depend on GitHub after partitioning.
  nixos-install \
    --no-root-passwd \
    --no-channel-copy \
    "${NIX_OPTIONS[@]}" \
    --system "$system_path"
}

finish_installation() {
  local elapsed choice
  elapsed=$(($(date +%s) - INSTALL_STARTED_AT))
  write_state 6 6 "Installation complete" "complete"
  persist_log
  sync

  screen_header "${GREEN}$(msg 'HAO NixOS is installed' 'HAO NixOS 安装完成')${RESET}" "$(msg 'Time used' '用时')：$(human_duration "$elapsed")"
  center "${WARM}$(msg 'Remove the USB installer before the computer starts again.' '重启时拔出安装 U 盘，使用 admin 和刚才的密码登录。')${RESET}"
  printf '\n'

  choice="$(menu "$(msg 'Ready' '下一步')" reboot "$(msg 'Reboot now' '立即重启')" shell "$(msg 'Open shell' '打开终端')")" || choice=shell
  case "$choice" in
  reboot) systemctl reboot ;;
  shell)
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
  if [[ $# == 1 && $1 == --recover ]]; then
    install -d -m 0700 "$STATE_DIR"
    touch "$LOG_FILE"
    chmod 0600 "$LOG_FILE"
    failure_menu "$(msg 'The previous installation session ended. Check the log before continuing.' '上次安装会话已结束，请先检查日志和磁盘状态。')"
    exit 1
  fi
  [[ $# == 0 ]] || {
    usage >&2
    exit 2
  }

  preflight
  welcome
  select_host
  configure_network
  select_disk
  read_password
  confirm_summary

  INSTALL_STARTED_AT="$(date +%s)"
  run_phase 1 6 "$(msg 'Preparing the system before erasing' '准备系统，完成后才会清盘')" build_target_before_erase
  run_phase 2 6 "$(msg 'Partitioning and formatting' '分区与格式化') ${TARGET_DISK}" partition_disk
  run_phase 3 6 "$(msg 'Copying the HAO configuration' '保存系统配置')" copy_configuration
  run_phase 4 6 "$(msg 'Securing the login password' '保存登录密码')" prepare_target_configuration
  PASSWORD_HASH=""
  run_phase 5 6 "$(msg 'Installing the prepared system' '安装已准备好的系统')" install_system
  run_phase 6 6 "$(msg 'Syncing files to disk' '完成磁盘写入')" sync
  finish_installation
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
