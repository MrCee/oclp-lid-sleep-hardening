#!/bin/zsh
set -eu

readonly REPO_ROOT="${0:A:h:h}"
readonly MAIN_SCRIPT="$REPO_ROOT/oclp-lid-sleep-hardening.zsh"
readonly WATCHDOG_SCRIPT="$REPO_ROOT/support/oclp-lid-sleep-watchdog.zsh"
readonly WATCHDOG_PLIST="$REPO_ROOT/support/com.mrcee.oclp-lid-sleep-watchdog.plist"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

/bin/zsh -n "$MAIN_SCRIPT"
/bin/zsh -n "$WATCHDOG_SCRIPT"
/usr/bin/plutil -lint "$WATCHDOG_PLIST"

help_output="$("$MAIN_SCRIPT" --help)"
echo "$help_output" | /usr/bin/grep -q -- '--install-lid-watchdog' || fail "install mode missing from help"
echo "$help_output" | /usr/bin/grep -q -- '--lid-watchdog-status' || fail "status mode missing from help"
echo "$help_output" | /usr/bin/grep -q -- '--remove-lid-watchdog' || fail "remove mode missing from help"

status_output="$(/bin/zsh "$WATCHDOG_SCRIPT" --check-once)"
echo "$status_output" | /usr/bin/grep -Eq '^lid=(open|closed|unknown)$' || fail "invalid lid status"
echo "$status_output" | /usr/bin/grep -Eq '^power=(ac|battery|unknown)$' || fail "invalid power status"
echo "$status_output" | /usr/bin/grep -q '^shutdown_after=04:00:00$' || fail "four-hour threshold missing"

plist_label="$(/usr/bin/plutil -extract Label raw -o - "$WATCHDOG_PLIST")"
[[ "$plist_label" == "com.mrcee.oclp-lid-sleep-watchdog" ]] || fail "unexpected LaunchDaemon label"

plist_program="$(/usr/bin/plutil -extract ProgramArguments.0 raw -o - "$WATCHDOG_PLIST")"
[[ "$plist_program" == "/Library/PrivilegedHelperTools/com.mrcee.oclp-lid-sleep-watchdog" ]] || fail "unexpected installed program path"

echo "PASS: syntax, plist, CLI modes, live sensors, and four-hour threshold"
