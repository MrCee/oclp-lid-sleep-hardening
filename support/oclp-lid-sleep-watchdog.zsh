#!/bin/zsh
set -u

readonly LABEL="com.mrcee.oclp-lid-sleep-watchdog"
readonly POLL_SECONDS=5
readonly SHUTDOWN_AFTER_SECONDS=14400
readonly STATE_FILE="/var/run/${LABEL}.closed-on-battery-since"

MODE="--monitor"

usage() {
  cat <<'EOF'
OCLP closed-lid battery sleep watchdog

Usage:
  oclp-lid-sleep-watchdog [--monitor|--check-once|--help]

Modes:
  --monitor     Watch continuously. This is the LaunchDaemon mode.
  --check-once Print the current lid, power, and timer state without changing it.
  --help        Show this help.
EOF
}

case "${1:---monitor}" in
  --monitor|--check-once)
    MODE="${1:---monitor}"
    ;;
  --help|-h)
    usage
    exit 0
    ;;
  *)
    echo "Unknown mode: $1" >&2
    usage >&2
    exit 2
    ;;
esac

log_message() {
  local message="$1"
  echo "$(date '+%Y-%m-%d %H:%M:%S%z') $message"
  /usr/bin/logger -t "$LABEL" -- "$message" 2>/dev/null || true
}

read_lid_state() {
  local value
  value="$(/usr/sbin/ioreg -r -c IOPMrootDomain -d 1 2>/dev/null | /usr/bin/awk -F'= ' '/"AppleClamshellState"/ {print $2; exit}' | /usr/bin/tr -d ' ')"

  case "$value" in
    Yes|yes|true|1)
      echo "closed"
      ;;
    No|no|false|0)
      echo "open"
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

read_power_source() {
  local external_connected
  local pmset_summary

  external_connected="$(/usr/sbin/ioreg -r -c AppleSmartBattery -d 1 2>/dev/null | /usr/bin/awk -F'= ' '/"ExternalConnected"/ {print $2; exit}' | /usr/bin/tr -d ' ')"

  case "$external_connected" in
    Yes|yes|true|1)
      echo "ac"
      return
      ;;
    No|no|false|0)
      echo "battery"
      return
      ;;
  esac

  pmset_summary="$(/usr/bin/pmset -g batt 2>/dev/null | /usr/bin/head -1)"
  case "$pmset_summary" in
    *"Battery Power"*)
      echo "battery"
      ;;
    *"AC Power"*)
      echo "ac"
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

read_closed_since() {
  local value=""

  if [[ -r "$STATE_FILE" ]]; then
    value="$(<"$STATE_FILE")"
  fi

  if [[ "$value" == <-> ]]; then
    echo "$value"
  fi
}

write_closed_since() {
  local value="$1"
  echo "$value" >| "$STATE_FILE"
  /bin/chmod 0644 "$STATE_FILE" 2>/dev/null || true
}

clear_closed_since() {
  /bin/rm -f "$STATE_FILE"
}

format_duration() {
  local total_seconds="$1"
  local hours=$((total_seconds / 3600))
  local minutes=$(((total_seconds % 3600) / 60))
  local seconds=$((total_seconds % 60))
  printf '%02d:%02d:%02d' "$hours" "$minutes" "$seconds"
}

print_status() {
  local lid_state
  local power_source
  local closed_since
  local now
  local elapsed=0
  local remaining="$SHUTDOWN_AFTER_SECONDS"

  lid_state="$(read_lid_state)"
  power_source="$(read_power_source)"
  closed_since="$(read_closed_since)"
  now="$(date +%s)"

  if [[ -n "$closed_since" && "$now" -ge "$closed_since" ]]; then
    elapsed=$((now - closed_since))
    remaining=$((SHUTDOWN_AFTER_SECONDS - elapsed))
    (( remaining < 0 )) && remaining=0
  fi

  echo "lid=$lid_state"
  echo "power=$power_source"
  echo "closed_on_battery_since=${closed_since:-not-tracking}"
  echo "closed_on_battery_elapsed=$(format_duration "$elapsed")"
  echo "shutdown_after=$(format_duration "$SHUTDOWN_AFTER_SECONDS")"
  echo "shutdown_remaining=$(format_duration "$remaining")"
}

if [[ "$MODE" == "--check-once" ]]; then
  print_status
  exit 0
fi

if [[ "$(/usr/bin/id -u)" -ne 0 ]]; then
  echo "$LABEL must run as root." >&2
  exit 1
fi

log_message "Watchdog started: closed+battery wakes will be returned to sleep; shutdown threshold is 4 hours."

closed_battery_samples=0

while true; do
  lid_state="$(read_lid_state)"
  power_source="$(read_power_source)"

  if [[ "$lid_state" != "closed" || "$power_source" != "battery" ]]; then
    closed_battery_samples=0
    if [[ -e "$STATE_FILE" ]]; then
      clear_closed_since
      log_message "Closed-on-battery timer reset: lid=$lid_state power=$power_source."
    fi
    /bin/sleep "$POLL_SECONDS"
    continue
  fi

  closed_battery_samples=$((closed_battery_samples + 1))
  if (( closed_battery_samples < 2 )); then
    /bin/sleep "$POLL_SECONDS"
    continue
  fi

  now="$(date +%s)"
  closed_since="$(read_closed_since)"
  if [[ -z "$closed_since" ]]; then
    closed_since="$now"
    write_closed_since "$closed_since"
    log_message "Tracking continuous closed-on-battery time."
  fi

  elapsed=$((now - closed_since))
  if (( elapsed >= SHUTDOWN_AFTER_SECONDS )); then
    /bin/sleep 2
    if [[ "$(read_lid_state)" != "closed" || "$(read_power_source)" != "battery" ]]; then
      continue
    fi
    log_message "Closed on battery for $(format_duration "$elapsed"); initiating full shutdown and terminating applications."
    /bin/sync
    /sbin/shutdown -h now
    exit 0
  fi

  log_message "Closed on battery for $(format_duration "$elapsed"); forcing this wake back to sleep."
  sleep_request_started="$(date +%s)"
  if ! /usr/bin/pmset sleepnow; then
    log_message "pmset sleepnow failed; retrying after ${POLL_SECONDS}s."
    /bin/sleep "$POLL_SECONDS"
    continue
  fi

  sleep_request_elapsed=$(($(date +%s) - sleep_request_started))
  if (( sleep_request_elapsed < POLL_SECONDS )); then
    /bin/sleep $((POLL_SECONDS - sleep_request_elapsed))
  fi
done
