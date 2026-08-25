# OCLP Lid Sleep Diagnostic & Hardening

Sleep diagnostics and battery-first lid sleep hardening for unsupported Intel MacBooks running macOS through OpenCore Legacy Patcher.

This is not an official OpenCore Legacy Patcher project. It is a practical diagnostic and hardening tool for one class of OCLP lid-closed battery drain problems.

## Purpose

The policy of this project is now battery-first:

When the MacBook is on battery and the lid is closed, it should stay asleep as much as macOS/OCLP allows. The default posture disables intentional convenience wake paths for normal sleep-time networking, Power Nap, proximity, Bluetooth auto-seek, AC-change wake, Wake on LAN, and similar background behaviour.

That means battery lid-closed sleep may behave more like near-offline hibernation. This is intentional.

The pmset profile alone does not promise zero wakes or zero drain. macOS, firmware, SMC, battery management, hibernate, or unavoidable RTC/maintenance events may still happen. The optional lid watchdog addresses that remaining failure mode by returning closed-battery wakes to sleep and shutting down after four continuous hours.

## What This Is For

Use this on older or unsupported MacBooks running macOS through OCLP where lid-closed battery sleep is unreliable.

Common symptoms include:

- Battery drains while the lid is closed
- Repeated `DarkWake` or maintenance wake events
- Wake reasons such as `EC.ACAttach`, `EC.ACDetach`, `EC.LidOpen`, `EC.PME/User`, `UserActivity`, or `XHC1`
- Keyboard, trackpad, lid, ACPI, USB, Bluetooth, or proximity wake evidence
- Current sleep blockers such as `PreventUserIdleSystemSleep`, `PreventSystemSleep`, or `NetworkClientActive`

## Observed Baseline

This project was built around a MacBookPro11,3 running unsupported macOS via OCLP.

The original failure mode included phantom EC/SMC power events:

```text
DarkWake from Safe Sleep due to EC.ACDetach/Maintenance Using BATT
Wake from Standby due to EC.ACAttach/Maintenance Using BATT
Wake from Standby due to EC.ACAttach/Maintenance Using AC
```

Because macOS can route wake behaviour through AC settings after an `EC.ACAttach` event, battery-only hardening was not enough. The tool therefore still applies an AC aggressive compatibility profile in the default mode.

After aggressive battery and AC hardening, the observed overnight pattern improved materially:

- No new `EC.ACAttach` or `EC.ACDetach` events in a targeted 15-hour `pmset` window
- Remaining wakes looked like periodic `RTC/Maintenance` / `DarkWake` behaviour
- The Mac returned to clamshell sleep after those maintenance wakes
- Battery moved from about 100% near lid close to about 92-93% by morning
- Current assertions showed no `PreventSystemSleep`, no `PreventUserIdleSystemSleep`, and no `NetworkClientActive`

The next target is therefore suppressing normal macOS maintenance/convenience wake paths as much as practical while closed on battery.

## Quick Start

```zsh
cd /path/to/oclp-lid-sleep-hardening
chmod +x ./oclp-lid-sleep-hardening.zsh
./oclp-lid-sleep-hardening.zsh --audit-only
./oclp-lid-sleep-hardening.zsh
./oclp-lid-sleep-hardening.zsh --install-lid-watchdog
./oclp-lid-sleep-hardening.zsh --lid-watchdog-status
```

Running the script with no mode now uses:

```zsh
./oclp-lid-sleep-hardening.zsh --battery-near-offline
```

## Modes

| Mode | Purpose |
|---|---|
| `--audit-only` | Write the normal diagnostic report without applying changes. |
| `--battery-near-offline` | Default. Maximize battery lid-closed drain suppression and keep AC aggressive compatibility for phantom EC attach routing. |
| `--battery-aggressive` | Apply the aggressive battery profile only. |
| `--ac-aggressive` | Apply the aggressive AC profile only. |
| `--both-aggressive` | Apply the aggressive battery and AC profiles without the extra battery `networkoversleep` near-offline setting. |
| `--restore-balanced` | Restore safer balanced battery and AC settings. |
| `--ec-lid-diagnostic` | Print focused EC/lid/power diagnostics. |
| `--install-lid-watchdog` | Install and start the root LaunchDaemon that returns closed-battery wakes to sleep, then shuts down after four hours. |
| `--lid-watchdog-status` | Show the installed files, current lid/power/timer readings, service state, and recent logs. |
| `--remove-lid-watchdog` | Stop and remove the watchdog and its active timer state while preserving logs. |
| `--help` | Show usage. |

The script writes a report to your Desktop. Normal report modes also copy the report to the clipboard.

`--near-offline-sleep` is retained only as a deprecated compatibility alias for `--battery-near-offline`. New usage and documentation should use `--battery-near-offline`.

## Closed-Lid Battery Watchdog

The optional watchdog handles the residual maintenance-wake problem that pmset preferences cannot prevent on this OCLP machine.

Its policy is deliberately narrow:

1. It samples `AppleClamshellState` and the AppleSmartBattery `ExternalConnected` property every five seconds while the Mac is awake.
2. When both readings confirm lid closed and battery power, it starts a persistent elapsed-time marker and runs `pmset sleepnow`.
3. Each later unwanted wake with the same conditions is immediately returned to sleep.
4. At the first wake or check after four continuous hours, it runs `shutdown -h now` instead of returning to sleep.
5. Opening the lid or connecting external power clears the timer.

The four-hour shutdown does not create a new RTC wake merely to meet an exact deadline. If the Mac is fully asleep at four hours, shutdown occurs on the first subsequent wake. On the diagnosed machine, periodic maintenance wakes provide that opportunity.

Install and inspect it explicitly:

```zsh
./oclp-lid-sleep-hardening.zsh --install-lid-watchdog
./oclp-lid-sleep-hardening.zsh --lid-watchdog-status
```

Remove it with:

```zsh
./oclp-lid-sleep-hardening.zsh --remove-lid-watchdog
```

The watchdog never shuts down merely because the Mac is on battery: both battery power and a closed lid must be confirmed. Nevertheless, the four-hour shutdown terminates applications without waiting for unsaved-document dialogs. Save work before closing the lid on battery. A full shutdown cannot restore the exact in-memory session; before the threshold, mode 25 hibernation remains resumable in the normal way.

## Default Battery Near-Offline Posture

The default mode is designed for this rule:

When on battery and closed, do not intentionally wake for convenience behaviour.

For Battery Power, the default applies roughly:

```text
lidwake              0
hibernatemode        25
standby              1
standbydelayhigh     0
standbydelaylow      0
autopoweroff         1
autopoweroffdelay    0
ttyskeepawake        0
powernap             0
womp                 0
acwake               0
tcpkeepalive         0 where supported
proximitywake        0 where supported
networkoversleep     0 where supported
```

It also disables Bluetooth auto-seek behaviour:

```text
BluetoothAutoSeekKeyboard       false
BluetoothAutoSeekPointingDevice false
```

If `AddressBookSourceSync` is actively seen in current assertions when a hardening mode runs, the script disables that user LaunchAgent for the current user session. It does not blindly disable it during audit-only runs or when it is not currently involved.

## AC Behaviour

The default also applies the aggressive AC compatibility profile:

```text
lidwake              0
hibernatemode        25
standby              1
standbydelayhigh     0
standbydelaylow      0
autopoweroff         1
autopoweroffdelay    0
ttyskeepawake        0
powernap             0
womp                 0
acwake               0
tcpkeepalive         0 where supported
proximitywake        0 where supported
```

This is retained because the observed OCLP failure mode included phantom `EC.ACAttach` events while physically on battery. In that state macOS may consult AC wake settings even though the user thinks the machine is sleeping on battery.

The default does not add the extra battery near-offline `networkoversleep` setting to AC. AC is still hardened, but the project policy is primarily about stopping lid-closed battery drain.

## Trade-Offs

| Change | Trade-off |
|---|---|
| `lidwake=0` | Opening the lid may not wake the Mac automatically. Press the power button or a key. |
| `hibernatemode=25` | Wake may be slower because the Mac favours deeper hibernate-style sleep. Some OCLP machines may not behave well with this mode. |
| `powernap=0` | Background mail, iCloud, Photos, app refresh, and other Power Nap-style maintenance should be reduced while sleeping. |
| `tcpkeepalive=0` | Find My Mac, remote reachability, and some iCloud/Handoff behaviour may not work normally while sleeping. |
| `networkoversleep=0` | Battery near-offline mode further reduces sleep-time network reachability where supported. |
| `womp=0` | Wake on LAN is disabled. |
| `acwake=0` | AC attach/detach should not intentionally wake the Mac. |
| `proximitywake=0` | Nearby-device convenience wake is reduced where supported. |
| Bluetooth auto-seek disabled | Bluetooth keyboard/mouse discovery convenience may be reduced. |
| AddressBook SourceSync disable | Contacts source sync may pause until restored if it was actively blocking sleep. |
| Lid watchdog | Closed-battery maintenance wakes are forced back to sleep, which intentionally prevents remote access and background work. |
| Four-hour watchdog shutdown | Applications are terminated without unsaved-document dialogs, and the exact hibernated session cannot be restored afterward. |

Use `--restore-balanced` if the near-offline posture causes unacceptable wake, resume, or usability problems.

## Diagnostics

Use the focused diagnostic when the machine still drains or wakes unexpectedly:

```zsh
./oclp-lid-sleep-hardening.zsh --ec-lid-diagnostic
```

The report classifies current state as one or more of:

| Verdict | Meaning |
|---|---|
| `CLEAN` | No current user-space/kernel blockers or recent EC/lid/input/maintenance wake suspects detected. |
| `USERSPACE_BLOCKED` | Current assertions show `PreventUserIdleSystemSleep`, `PreventSystemSleep`, or `NetworkClientActive`. |
| `KERNEL_BLOCKED` | Current assertions show kernel sleep blockers such as CPU, IOPMrootDomain, or preventSleep. |
| `EC_POWER_EVENT_SUSPECT` | Recent logs show `EC.ACAttach` or `EC.ACDetach`. |
| `LID_INPUT_WAKE_SUSPECT` | Recent logs show lid, ACPI button, keyboard, trackpad, or `UserActivity` wake evidence. |
| `NORMAL_MAINTENANCE_DARKWAKE_SUSPECT` | Recent logs show RTC/Maintenance or DarkWake-style activity that can still drain battery even when EC attach/detach and current blockers are quiet. |

Residual events like these may still happen:

```text
Wake from Standby due to RTC/Maintenance Using BATT
MaintenanceWake mDNSResponder:maintenance
HibernateStats hibmode=25 standbydelaylow=0 standbydelayhigh=0
```

Those events do not necessarily mean the hardening failed. They mean macOS or firmware still performed some sleep-time activity.

## Restore AddressBook SourceSync

If `com.apple.AddressBook.SourceSync` was disabled and you want to restore Contacts source sync:

```zsh
launchctl enable "gui/$UID/com.apple.AddressBook.SourceSync" 2>&1 || true
launchctl bootstrap "gui/$UID" /System/Library/LaunchAgents/com.apple.AddressBook.SourceSync.plist 2>&1 || true
```

## Changelog Summary

### Current

- Adds an opt-in closed-lid battery watchdog LaunchDaemon.
- Forces residual closed-battery wakes back to sleep and shuts down at the first wake/check after four continuous hours.
- Resets the shutdown timer whenever the lid opens or external power reconnects.
- Hides `--near-offline-sleep` from primary mode documentation; it remains only as a deprecated compatibility alias for `--battery-near-offline`.

### v0.4.0

- Makes battery near-offline sleep the default.
- Introduces `--battery-near-offline` as the clear default mode name.
- Keeps AC aggressive compatibility because phantom EC attach can route battery sleep through AC wake settings.
- Documents the project as intentionally battery-first.

### v0.3.0

- Added `--near-offline-sleep`.
- Added `NORMAL_MAINTENANCE_DARKWAKE_SUSPECT`.
- Documented residual RTC/Maintenance and DarkWake behaviour.

### v0.2.0

- Added AC aggressive hardening for phantom `EC.ACAttach`.
- Added `--audit-only`, `--ec-lid-diagnostic`, and `--restore-balanced`.

## Disclaimer

Use at your own risk.

This project is not affiliated with OpenCore Legacy Patcher, Dortania, Apple, or Microsoft.

It changes power-management settings. Read the script before running it.
