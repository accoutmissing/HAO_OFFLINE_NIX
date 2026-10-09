#!/usr/bin/env bash
set -euo pipefail

installer_script="${1:?Missing installer source}"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
export HAO_INSTALLER_STATE_DIR="$test_root/state" HAO_INSTALLER_TTY="$test_root/tty"
export HAO_INSTALLER_BUNDLE_DIR="$test_root/bundle"
mkdir -p "$HAO_INSTALLER_STATE_DIR" "$test_root/system/bin" "$HAO_INSTALLER_BUNDLE_DIR"
touch "$HAO_INSTALLER_BUNDLE_DIR/partition-disk"
chmod +x "$HAO_INSTALLER_BUNDLE_DIR/partition-disk"
touch "$test_root/system/bin/switch-to-configuration"
chmod +x "$test_root/system/bin/switch-to-configuration"
# shellcheck disable=SC1090
source "$installer_script"
trap 'rm -rf "$test_root"' EXIT
trap - ERR

# These mocks emulate failure responses, never contact a real cache and never
# execute disk or installation commands on the test machine.
# shellcheck disable=SC2329
curl() {
  local url="${*: -1}"
  case "$network_case:$url" in
  mirrors-down:*tuna* | mirrors-down:*ustc*) return 22 ;;
  html-page:*tuna*)
    printf '<html>Not a cache</html>\n'
    return 0
    ;;
  all-down:*) return 7 ;;
  esac
  printf 'StoreDir: /nix/store\nPriority: 40\n'
}

network_case=all-up
probe_caches
[[ $SELECTED_CACHES == *tuna*priority=10*ustc*priority=20*cache.nixos.org* ]]
printf 'PASS: domestic cache preference and official backup\n'
network_case=mirrors-down
probe_caches
[[ $SELECTED_CACHES != *tuna* && $SELECTED_CACHES != *ustc* && $SELECTED_CACHES == *cache.nixos.org* ]]
printf 'PASS: unavailable mirrors do not block official downloads\n'
network_case=html-page
probe_caches
[[ $SELECTED_CACHES != *tuna* && $SELECTED_CACHES == *ustc* ]]
printf 'PASS: an HTTP 200 error page is rejected\n'
network_case=all-down
if probe_caches; then exit 1; fi
[[ -z $SELECTED_CACHES ]]
printf 'PASS: no usable cache is reported as a failure\n'

for proxy_url in http://192.168.1.10:7890 http://localhost:1 http://proxy.lan:65535; do
  valid_proxy_url "$proxy_url"
done
for proxy_url in 'http://localhost:0' 'http://localhost:65536' 'http://user:pass@proxy:7890' \
  'http://proxy:7890/path' $'http://proxy:7890\nEnvironment="bad"'; do
  if valid_proxy_url "$proxy_url"; then exit 1; fi
done
printf 'PASS: proxy ports and environment-injection boundaries\n'

# shellcheck disable=SC2329
nix() {
  printf '%s\n' "$*" >>"$test_root/nix-calls"
  case "$1" in
  build) ln -sfn "$test_root/system" "$STATE_DIR/target-system" ;;
  path-info) printf '%s 1000\n' "$test_root/system" ;;
  *) return 1 ;;
  esac
}
# shellcheck disable=SC2329
nix-store() {
  case "$1" in
  --query) printf '%s\n' "$test_root/system" ;;
  --check-validity) [[ $2 == "$test_root/system" ]] ;;
  *) return 1 ;;
  esac
}
# shellcheck disable=SC2329
nixos-install() { printf '%s\n' "$@" >"$test_root/install-args"; }
# Variables read by the sourced installer callbacks.
# shellcheck disable=SC2034
TARGET_DISK_SIZE=68719476736
# shellcheck disable=SC2034
HOST_CONFIG=HAO_DESKTOP
build_target_before_erase
grep -q '^build --out-link ' "$test_root/nix-calls"
install_system
grep -qx -- '--system' "$test_root/install-args"
grep -qx "$test_root/system" "$test_root/install-args"
if grep -qx -- '--flake' "$test_root/install-args"; then exit 1; fi
printf 'PASS: installation uses the exact system prepared before erasing\n'

: >"$test_root/nix-calls"
# shellcheck disable=SC2034
PREBUILT_SYSTEM="$test_root/system"
build_target_before_erase
if grep -q '^build ' "$test_root/nix-calls"; then exit 1; fi
configure_network
printf 'PASS: an offline bundle skips both download and build\n'
