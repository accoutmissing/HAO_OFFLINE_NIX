#!/usr/bin/env bash
set -euo pipefail

installer_script="${1:-$(cd "$(dirname "$0")/.." && pwd)/installer/scripts/hao-installer.sh}"

# These callbacks are invoked by run_phase in the sourced installer.
# shellcheck disable=SC2329
if [[ -n ${HAO_INSTALLER_TEST_CASE:-} ]]; then
  export HAO_INSTALLER_STATE_DIR="${2:?Missing test directory}"
  export HAO_INSTALLER_TTY="$HAO_INSTALLER_STATE_DIR/tty"
  # Source definitions only; no preflight, installation or disk commands run.
  # shellcheck disable=SC1090
  source "$installer_script"
  printf '%s\n' "$BASHPID" >"$STATE_DIR/foreground-pid"
  : >"$LOG_FILE"

  write_state() { printf '%s\n' "$4" >>"$STATE_DIR/phases"; }
  render_progress() { :; }
  failure_menu() {
    printf '%s\n' "$BASHPID" >>"$STATE_DIR/recovery-pids"
    printf '%s\n' "$1" >>"$STATE_DIR/recovery-messages"
  }
  successful_phase() { printf 'Phase output\n'; }
  failed_phase() { return 42; }
  failed_safety_check() {
    false
    printf 'A disk write would have happened\n' >"$STATE_DIR/unsafe-action"
  }
  install_system() {
    if [[ ! -f $STATE_DIR/first-attempt ]]; then
      touch "$STATE_DIR/first-attempt"
      return 42
    fi
    printf 'Phase output\n'
  }
  slow_phase() {
    printf '%s\n' "$BASHPID" >"$STATE_DIR/phase-pid"
    bash -c 'sleep 3; printf "A write after cancellation\n" > "$1/unsafe-action"' _ "$STATE_DIR"
  }

  case "$HAO_INSTALLER_TEST_CASE" in
  success) run_phase 1 1 "Test phase" successful_phase ;;
  failure) run_phase 1 1 "Test phase" failed_phase ;;
  safety-check) run_phase 1 1 "Test phase" failed_safety_check ;;
  retry-safe) run_phase 1 1 "Test phase" install_system ;;
  interruption) run_phase 1 1 "Test phase" slow_phase ;;
  *) exit 2 ;;
  esac
  exit 0
fi

test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

run_case() {
  local name="$1" expected_status="$2" directory="$test_root/$1" status
  mkdir -p "$directory"
  if HAO_INSTALLER_TEST_CASE="$name" bash "$0" "$installer_script" "$directory"; then
    status=0
  else
    status=$?
  fi
  if [[ $status -ne $expected_status ]]; then
    printf '%s: expected exit %s, got %s\n' "$name" "$expected_status" "$status" >&2
    return 1
  fi
  grep -qx running "$directory/phases"
  if [[ $expected_status -eq 0 ]]; then
    grep -qx complete "$directory/phases"
    grep -qx 'Phase output' "$directory/install.log"
    if [[ $name == retry-safe ]]; then
      [[ $(cat "$directory/recovery-pids") == "$(cat "$directory/foreground-pid")" ]]
      [[ $(grep -c '^running$' "$directory/phases") == 2 ]]
      grep -qx failed "$directory/phases"
    else
      [[ ! -e $directory/recovery-pids ]]
    fi
  else
    grep -qx failed "$directory/phases"
    [[ $(cat "$directory/recovery-pids") == "$(cat "$directory/foreground-pid")" ]]
    grep -qx "Test phase failed with status $expected_status" "$directory/recovery-messages"
    [[ ! -e $directory/unsafe-action ]]
  fi
  printf 'PASS: %s\n' "$name"
}

run_case success 0
run_case failure 42
run_case safety-check 1
run_case retry-safe 0

directory="$test_root/interruption"
mkdir -p "$directory"
HAO_INSTALLER_TEST_CASE=interruption bash "$0" "$installer_script" "$directory" &
runner_pid=$!
for ((attempt = 0; attempt < 100; attempt++)); do
  [[ -f $directory/phase-pid ]] && break
  sleep 0.05
done
[[ -f $directory/phase-pid ]]
kill -TERM "$runner_pid"
if wait "$runner_pid"; then exit 1; else [[ $? == 143 ]]; fi
sleep 3.2
[[ ! -e $directory/unsafe-action ]]
if kill -0 "$(cat "$directory/phase-pid")" 2>/dev/null; then exit 1; fi
printf 'PASS: interruption stops the phase and its descendants\n'
