#!/bin/zsh
set -u

SCRIPT_NAME="${0:t}"
MODE="${1:---both-aggressive}"
OUT="$HOME/Desktop/oclp-lid-sleep-hardening-$(date +%Y%m%d-%H%M%S).txt"

usage() {
  cat <<'EOF'
OCLP lid sleep diagnostic and hardening tool

Usage:
  ./oclp-lid-sleep-hardening.zsh [mode]

Modes:
  --audit-only          Report current sleep state without applying changes.
  --battery-aggressive Apply aggressive battery sleep hardening.
  --ac-aggressive      Apply aggressive AC sleep hardening.
  --both-aggressive    Apply aggressive battery and AC sleep hardening. Default.
  --near-offline-sleep Apply maximum drain suppression for both power profiles.
  --restore-balanced   Restore a safer balanced battery and AC sleep profile.
  --ec-lid-diagnostic  Print focused EC/lid/power diagnostics.
  --help               Show this help.

Default:
  --both-aggressive is the default because EC/SMC phantom AC attach events can
  make macOS use AC wake paths while the machine is physically on battery.

Near-offline sleep:
  --near-offline-sleep is an explicit opt-in posture for cases where EC attach
  events are quiet and remaining drain appears to be normal RTC/Maintenance or
  DarkWake behaviour. It attempts to suppress remaining sleep-time network and
  maintenance wake paths as much as practical, but it does not guarantee zero
  overnight drain.
EOF
}

case "$MODE" in
  --audit-only|--battery-aggressive|--ac-aggressive|--both-aggressive|--near-offline-sleep|--restore-balanced|--ec-lid-diagnostic)
    ;;
  --help|-h)
    usage
    exit 0
    ;;
  *)
    echo "Unknown mode: $MODE" >&2
    echo >&2
    usage >&2
    exit 2
    ;;
esac

run_optional() {
  "$@" 2>/dev/null || true
}

heading() {
  echo
  echo "============================================================"
  echo " $1"
  echo "============================================================"
}

print_context() {
  echo "Generated: $(date)"
  echo "Mode: $MODE"
  echo "User: $(whoami)"
  echo "Host: $(hostname)"
  echo
}

print_hardware() {
  heading "macOS / Hardware"
  sw_vers
  echo
  system_profiler SPHardwareDataType 2>/dev/null | grep -E -i "Model Name|Model Identifier|Processor|Memory|SMC|System Firmware|OS Loader" || true
}

print_pmset_custom() {
  local label="$1"
  heading "$label: pmset custom"
  pmset -g custom
}

print_battery_state() {
  heading "Battery state"
  pmset -g batt
}

print_assertions() {
  local label="$1"
  heading "$label: assertions"
  pmset -g assertions
}

print_scheduled_wakes() {
  heading "Scheduled wakes"
  pmset -g sched
}

print_bluetooth_prefs() {
  heading "Bluetooth prefs"
  echo "--- System Bluetooth prefs ---"
  defaults read /Library/Preferences/com.apple.Bluetooth 2>/dev/null || true
  echo
  echo "--- User Bluetooth prefs ---"
  defaults read com.apple.Bluetooth 2>/dev/null || true
}

print_addressbook_state() {
  heading "AddressBookSourceSync state"
  if pmset -g assertions | grep -q "AddressBookSourceSync"; then
    echo "AddressBookSourceSync is currently seen in assertions."
  else
    echo "AddressBookSourceSync is not currently seen in assertions."
  fi
  echo
  echo "Restore commands if this LaunchAgent was disabled:"
  echo '  launchctl enable "gui/$UID/com.apple.AddressBook.SourceSync" 2>&1 || true'
  echo '  launchctl bootstrap "gui/$UID" /System/Library/LaunchAgents/com.apple.AddressBook.SourceSync.plist 2>&1 || true'
}

apply_battery_aggressive() {
  heading "Applying battery aggressive profile"
  sudo pmset -b lidwake 0
  sudo pmset -b hibernatemode 25
  sudo pmset -b standby 1
  sudo pmset -b standbydelaylow 0
  sudo pmset -b standbydelayhigh 0
  sudo pmset -b autopoweroff 1
  sudo pmset -b autopoweroffdelay 0
  sudo pmset -b ttyskeepawake 0
  sudo pmset -b powernap 0
  sudo pmset -b womp 0
  sudo pmset -b acwake 0
  sudo pmset -b tcpkeepalive 0 2>/dev/null || true
  sudo pmset -b proximitywake 0 2>/dev/null || true
}

apply_ac_aggressive() {
  heading "Applying AC aggressive profile"
  echo "Reason: recent logs can show phantom EC.ACAttach while physically on battery."
  sudo pmset -c lidwake 0
  sudo pmset -c hibernatemode 25
  sudo pmset -c standby 1
  sudo pmset -c standbydelaylow 0
  sudo pmset -c standbydelayhigh 0
  sudo pmset -c autopoweroff 1
  sudo pmset -c autopoweroffdelay 0
  sudo pmset -c ttyskeepawake 0
  sudo pmset -c powernap 0
  sudo pmset -c womp 0
  sudo pmset -c acwake 0
  sudo pmset -c tcpkeepalive 0 2>/dev/null || true
  sudo pmset -c proximitywake 0 2>/dev/null || true
}

apply_near_offline_sleep() {
  heading "Applying near-offline sleep profile"
  echo "Reason: EC attach/detach appears quiet, but normal RTC/Maintenance or DarkWake events may still drain battery."
  echo "This mode keeps the aggressive baseline and disables additional sleep-time network reachability where supported."
  apply_battery_aggressive
  apply_ac_aggressive
  sudo pmset -a networkoversleep 0 2>/dev/null || true
}

restore_balanced() {
  heading "Restoring balanced battery and AC profiles"
  sudo pmset -b lidwake 1
  sudo pmset -b hibernatemode 3
  sudo pmset -b standby 1
  sudo pmset -b standbydelaylow 900
  sudo pmset -b standbydelayhigh 1800
  sudo pmset -b autopoweroff 1
  sudo pmset -b autopoweroffdelay 3600
  sudo pmset -b ttyskeepawake 0
  sudo pmset -b powernap 0
  sudo pmset -b womp 0
  sudo pmset -b acwake 0

  sudo pmset -c lidwake 1
  sudo pmset -c hibernatemode 3
  sudo pmset -c standby 1
  sudo pmset -c standbydelaylow 900
  sudo pmset -c standbydelayhigh 1800
  sudo pmset -c autopoweroff 1
  sudo pmset -c autopoweroffdelay 3600
  sudo pmset -c ttyskeepawake 0
  sudo pmset -c powernap 0
  sudo pmset -c womp 0
  sudo pmset -c acwake 0
}

apply_bluetooth_quieting() {
  heading "Applying Bluetooth quiet settings"
  sudo defaults write /Library/Preferences/com.apple.Bluetooth BluetoothAutoSeekKeyboard -bool false
  sudo defaults write /Library/Preferences/com.apple.Bluetooth BluetoothAutoSeekPointingDevice -bool false
  defaults write com.apple.Bluetooth BluetoothAutoSeekKeyboard -bool false
  defaults write com.apple.Bluetooth BluetoothAutoSeekPointingDevice -bool false
  run_optional sudo pkill bluetoothd
}

disable_addressbook_if_blocking() {
  heading "Optional AddressBookSourceSync quieting"
  local assertions
  assertions="$(pmset -g assertions)"

  if echo "$assertions" | grep -q "AddressBookSourceSync"; then
    echo "AddressBookSourceSync is currently holding or involved in assertions."
    echo "Disabling com.apple.AddressBook.SourceSync for this user session."
    launchctl disable "gui/$UID/com.apple.AddressBook.SourceSync" 2>&1 || true
    launchctl bootout "gui/$UID" /System/Library/LaunchAgents/com.apple.AddressBook.SourceSync.plist 2>&1 || true
  else
    echo "AddressBookSourceSync is not currently seen in assertions. Leaving it alone."
  fi
}

recent_power_logs() {
  run_optional log show --style syslog --last 24h --predicate 'eventMessage CONTAINS[c] "EC.ACAttach" OR eventMessage CONTAINS[c] "EC.ACDetach" OR eventMessage CONTAINS[c] "EC.LidOpen" OR eventMessage CONTAINS[c] "AppleACPILid" OR eventMessage CONTAINS[c] "AppleACPIButton" OR eventMessage CONTAINS[c] "AppleEmbeddedKeyboard" OR eventMessage CONTAINS[c] "AppleUSBMultitouchDriver" OR eventMessage CONTAINS[c] "UserActivity" OR eventMessage CONTAINS[c] "HibernateStats" OR eventMessage CONTAINS[c] " Wake " OR eventMessage CONTAINS[c] "DarkWake" OR eventMessage CONTAINS[c] "Standby"'
  pmset -g log | grep -E -i "Wake from|DarkWake|Entering Sleep|Sleep|Standby|Maintenance|EC\.ACAttach|EC\.ACDetach|EC\.LidOpen|AppleACPILid|AppleACPIButton|AppleEmbeddedKeyboard|AppleUSBMultitouchDriver|UserActivity|HibernateStats|hibmode|standbydelay" || true
}

print_recent_power_logs() {
  heading "Recent EC/lid/input/user activity events"
  recent_power_logs | grep -E -i "EC\.ACAttach|EC\.ACDetach|EC\.LidOpen|AppleACPILid|AppleACPIButton|AppleEmbeddedKeyboard|AppleUSBMultitouchDriver|UserActivity" || true

  heading "Recent HibernateStats"
  recent_power_logs | grep -E -i "HibernateStats|hibmode|standbydelay" || true

  heading "Recent sleep/wake entries"
  pmset -g log | grep -E -i "Wake from|DarkWake|Entering Sleep|Sleep|Standby|Maintenance|EC\.ACAttach|EC\.ACDetach|EC\.LidOpen|AppleACPILid|AppleACPIButton|AppleEmbeddedKeyboard|AppleUSBMultitouchDriver|UserActivity" | tail -80 || true
}

print_smart_battery_fields() {
  heading "AppleSmartBattery power fields"
  ioreg -r -c AppleSmartBattery 2>/dev/null | grep -E '"ExternalConnected"|"IsCharging"|"Amperage"|"Voltage"' || true
}

external_connected_value() {
  ioreg -r -c AppleSmartBattery 2>/dev/null | awk -F'= ' '/"ExternalConnected"/ {print $2; exit}' | tr -d ' '
}

print_ec_warning_if_needed() {
  heading "EC phantom AC warning"
  local external_connected
  local events
  external_connected="$(external_connected_value)"
  events="$(recent_power_logs | grep -E -i "EC\.ACAttach|EC\.ACDetach" || true)"

  if [[ "$external_connected" == "No" || "$external_connected" == "0" || "$external_connected" == "false" ]]; then
    if [[ -n "$events" ]]; then
      echo "WARNING: EC.ACAttach or EC.ACDetach appears in recent logs while ExternalConnected is $external_connected."
      echo "This suggests a phantom EC/SMC power event and can route macOS into AC wake behaviour."
    else
      echo "No recent EC.ACAttach/EC.ACDetach events found while ExternalConnected is $external_connected."
    fi
  else
    echo "ExternalConnected is $external_connected. Phantom AC warning applies only when it is 0/No/false."
  fi
}

print_expected_profiles() {
  heading "Expected aggressive profiles"
  echo "Battery Power and AC Power should show roughly:"
  echo "  lidwake              0"
  echo "  hibernatemode        25"
  echo "  standby              1"
  echo "  standbydelayhigh     0"
  echo "  standbydelaylow      0"
  echo "  autopoweroff         1"
  echo "  autopoweroffdelay    0"
  echo "  ttyskeepawake        0"
  echo "  powernap             0"
  echo "  womp                 0"
  echo "  acwake               0"
  echo "  tcpkeepalive         0 where supported"
  echo "  proximitywake        0 where supported"
  echo
  echo "Note: lidwake=0 means opening the lid may not wake the Mac."
  echo "Use the power button or keyboard to wake it."
}

print_expected_near_offline_profile() {
  print_expected_profiles
  heading "Additional near-offline expectations"
  echo "Battery Power and AC Power should also show where supported:"
  echo "  networkoversleep     0"
  echo
  echo "This mode cannot cancel every macOS RTC/Maintenance wake."
  echo "It is intended to reduce sleep-time networking and maintenance paths as much as practical."
}

print_verdict() {
  heading "Blocker verdict"
  local assertions
  local logs
  local found=0
  assertions="$(pmset -g assertions)"
  logs="$(recent_power_logs)"

  if echo "$assertions" | grep -E -q "PreventUserIdleSystemSleep[[:space:]]+1|PreventSystemSleep[[:space:]]+1|NetworkClientActive[[:space:]]+1"; then
    echo "USERSPACE_BLOCKED: current assertions show a user-space sleep blocker."
    echo "$assertions" | grep -E -i "PreventSystemSleep|PreventUserIdleSystemSleep|NetworkClientActive|pid |Assertion status" || true
    echo
    found=1
  fi

  if echo "$assertions" | grep -E -q "Kernel Assertions:.*CPU|Kernel Assertions:.*IOPMrootDomain|preventSleep|pci\.hostBridge\.preventSleep"; then
    echo "KERNEL_BLOCKED: current assertions show a kernel sleep blocker."
    echo "$assertions" | grep -E -i "Kernel Assertions|CPU|IOPMrootDomain|preventSleep|pci\.hostBridge\.preventSleep|No kernel assertions" || true
    echo
    found=1
  fi

  if echo "$logs" | grep -E -q "EC\.ACAttach|EC\.ACDetach"; then
    echo "EC_POWER_EVENT_SUSPECT: recent logs show EC.ACAttach or EC.ACDetach."
    echo "$logs" | grep -E -i "EC\.ACAttach|EC\.ACDetach" | tail -20 || true
    echo
    found=1
  fi

  if echo "$logs" | grep -E -q "EC\.LidOpen|AppleACPILid|AppleEmbeddedKeyboard|AppleUSBMultitouchDriver|AppleACPIButton|UserActivity"; then
    echo "LID_INPUT_WAKE_SUSPECT: recent logs show lid, ACPI button, keyboard, trackpad, or UserActivity wake evidence."
    echo "$logs" | grep -E -i "EC\.LidOpen|AppleACPILid|AppleEmbeddedKeyboard|AppleUSBMultitouchDriver|AppleACPIButton|UserActivity" | tail -20 || true
    echo
    found=1
  fi

  if echo "$logs" | grep -E -q "RTC/Maintenance|MaintenanceWake|DarkWake|mDNSResponder:maintenance"; then
    echo "NORMAL_MAINTENANCE_DARKWAKE_SUSPECT: recent logs show RTC/Maintenance or DarkWake-style activity."
    echo "$logs" | grep -E -i "RTC/Maintenance|MaintenanceWake|DarkWake|mDNSResponder:maintenance" | tail -20 || true
    echo "This can still consume battery even when EC attach/detach and current sleep blockers are quiet."
    echo
    found=1
  fi

  if [[ "$found" -eq 0 ]]; then
    echo "CLEAN: no current user-space/kernel blockers or recent EC/lid/input wake suspects detected."
  fi
}

run_audit_sections() {
  print_battery_state
  print_pmset_custom "CURRENT"
  print_assertions "CURRENT"
  print_scheduled_wakes
  print_bluetooth_prefs
  print_addressbook_state
  print_verdict
}

run_ec_lid_diagnostic() {
  {
    heading "OCLP / Unsupported Mac EC Lid Sleep Diagnostic"
    print_context
    print_hardware
    print_battery_state
    heading "Battery profile only"
    pmset -g custom | awk '/Battery Power/{show=1} /AC Power/{show=0} show {print}'
    print_assertions "CURRENT"
    print_scheduled_wakes
    print_recent_power_logs
    print_smart_battery_fields
    print_ec_warning_if_needed
    print_verdict
    echo
    echo "Complete: $(date)"
  } 2>&1 | tee "$OUT"

  echo
  echo "Done."
  echo "Report saved to:"
  echo "$OUT"
}

run_report() {
  {
    heading "OCLP / Unsupported Mac Lid Sleep Diagnostic & Hardening"
    print_context
    print_hardware
    print_pmset_custom "BEFORE"
    print_assertions "BEFORE"
    print_scheduled_wakes

    case "$MODE" in
      --audit-only)
        heading "Audit-only mode"
        echo "No hardening changes applied."
        ;;
      --battery-aggressive)
        apply_battery_aggressive
        apply_bluetooth_quieting
        disable_addressbook_if_blocking
        ;;
      --ac-aggressive)
        apply_ac_aggressive
        apply_bluetooth_quieting
        disable_addressbook_if_blocking
        ;;
      --both-aggressive)
        apply_battery_aggressive
        apply_ac_aggressive
        apply_bluetooth_quieting
        disable_addressbook_if_blocking
        ;;
      --near-offline-sleep)
        apply_near_offline_sleep
        apply_bluetooth_quieting
        disable_addressbook_if_blocking
        ;;
      --restore-balanced)
        restore_balanced
        ;;
    esac

    sleep 2
    print_pmset_custom "AFTER"
    print_bluetooth_prefs
    print_assertions "AFTER"
    print_scheduled_wakes
    print_addressbook_state
    print_verdict

    if [[ "$MODE" == "--near-offline-sleep" ]]; then
      print_expected_near_offline_profile
    elif [[ "$MODE" == "--battery-aggressive" || "$MODE" == "--ac-aggressive" || "$MODE" == "--both-aggressive" ]]; then
      print_expected_profiles
    fi

    echo
    echo "Complete: $(date)"
  } 2>&1 | tee "$OUT" | pbcopy

  echo
  echo "Done."
  echo "Report saved to:"
  echo "$OUT"
  echo "Report copied to clipboard."
}

if [[ "$MODE" == "--ec-lid-diagnostic" ]]; then
  run_ec_lid_diagnostic
else
  run_report
fi
