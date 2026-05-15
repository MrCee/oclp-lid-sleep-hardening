#!/bin/zsh
set -u

OUT="$HOME/Desktop/oclp-lid-sleep-hardening-$(date +%Y%m%d-%H%M%S).txt"

{
echo "============================================================"
echo " OCLP / Unsupported Mac Lid Sleep Hardening"
echo "============================================================"
echo "Generated: $(date)"
echo "User: $(whoami)"
echo "Host: $(hostname)"
echo

echo "============================================================"
echo " macOS / Hardware"
echo "============================================================"
sw_vers
echo
system_profiler SPHardwareDataType 2>/dev/null | egrep -i "Model Name|Model Identifier|Processor|Memory|SMC|System Firmware|OS Loader" || true
echo

echo "============================================================"
echo " BEFORE: pmset custom"
echo "============================================================"
pmset -g custom
echo

echo "============================================================"
echo " BEFORE: assertions"
echo "============================================================"
pmset -g assertions
echo

echo "============================================================"
echo " Applying battery-only aggressive lid sleep profile"
echo "============================================================"

# Battery only:
# - Force hibernate/deep sleep behaviour.
# - Do not wait 15/30 minutes/24 hours before standby.
# - Disable wake/network/power-nap behaviours that commonly cause lid-drain.
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
sudo pmset -b lidwake 0
sudo pmset -b tcpkeepalive 0 2>/dev/null || true
sudo pmset -b proximitywake 0 2>/dev/null || true

echo
echo "============================================================"
echo " Applying Bluetooth quiet settings"
echo "============================================================"

sudo defaults write /Library/Preferences/com.apple.Bluetooth BluetoothAutoSeekKeyboard -bool false
sudo defaults write /Library/Preferences/com.apple.Bluetooth BluetoothAutoSeekPointingDevice -bool false
defaults write com.apple.Bluetooth BluetoothAutoSeekKeyboard -bool false
defaults write com.apple.Bluetooth BluetoothAutoSeekPointingDevice -bool false

# Restart bluetoothd lightly. It will respawn.
sudo pkill bluetoothd 2>/dev/null || true
sleep 5

echo
echo "============================================================"
echo " OPTIONAL: Disable AddressBookSourceSync if currently blocking sleep"
echo "============================================================"

ASSERTIONS="$(pmset -g assertions)"

if echo "$ASSERTIONS" | grep -q "AddressBookSourceSync"; then
  echo "AddressBookSourceSync is currently holding or involved in assertions."
  echo "Disabling com.apple.AddressBook.SourceSync for this user session."
  launchctl disable "gui/$UID/com.apple.AddressBook.SourceSync" 2>&1 || true
  launchctl bootout "gui/$UID" /System/Library/LaunchAgents/com.apple.AddressBook.SourceSync.plist 2>&1 || true
else
  echo "AddressBookSourceSync is not currently seen in assertions. Leaving it alone."
fi

sleep 5

echo
echo "============================================================"
echo " AFTER: pmset custom"
echo "============================================================"
pmset -g custom
echo

echo "============================================================"
echo " AFTER: Bluetooth prefs"
echo "============================================================"
echo "--- System Bluetooth prefs ---"
defaults read /Library/Preferences/com.apple.Bluetooth 2>/dev/null || true
echo
echo "--- User Bluetooth prefs ---"
defaults read com.apple.Bluetooth 2>/dev/null || true
echo

echo "============================================================"
echo " AFTER: assertions"
echo "============================================================"
pmset -g assertions
echo

echo "============================================================"
echo " Blocker verdict"
echo "============================================================"

ASSERTIONS="$(pmset -g assertions)"

if echo "$ASSERTIONS" | egrep -q "PreventUserIdleSystemSleep[[:space:]]+1|PreventSystemSleep[[:space:]]+1|NetworkClientActive[[:space:]]+1|Kernel Assertions:.*CPU|preventSleep"; then
  echo "BLOCKED: there is still a visible sleep blocker."
  echo
  echo "$ASSERTIONS" | egrep -i "PreventSystemSleep|PreventUserIdleSystemSleep|NetworkClientActive|Kernel Assertions|preventSleep|pid |No kernel assertions|Assertion status"
else
  echo "CLEAN: no visible user/system/network/kernel sleep blocker detected."
fi

echo
echo "============================================================"
echo " Expected battery profile"
echo "============================================================"
echo "Battery Power should show roughly:"
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
echo
echo "Note: lidwake=0 means opening the lid may not wake the Mac."
echo "Use the power button or keyboard to wake it."
echo
echo "Complete: $(date)"
} 2>&1 | tee "$OUT" | pbcopy

echo
echo "Done."
echo "Report saved to:"
echo "$OUT"
echo "Report copied to clipboard."
