# Commands

Run commands from the repository root:

```zsh
cd /path/to/oclp-lid-sleep-hardening
chmod +x ./oclp-lid-sleep-hardening.zsh
```

## Audit only

Reports current pmset settings, assertions, scheduled wakes, Bluetooth prefs, AddressBookSourceSync state, and verdicts without applying changes.

```zsh
./oclp-lid-sleep-hardening.zsh --audit-only
```

## Default battery near-offline

Applies the default battery-first posture. On battery with the lid closed, the goal is to stay asleep as much as macOS/OCLP allows and avoid intentional convenience wakes for network, Power Nap, proximity, Bluetooth auto-seek, AC-change wake, and similar behaviour.

The default also applies the AC aggressive compatibility profile because phantom `EC.ACAttach` can route battery sleep through AC wake settings. It does not guarantee zero wakes or zero drain.

```zsh
./oclp-lid-sleep-hardening.zsh
```

Equivalent explicit invocation:

```zsh
./oclp-lid-sleep-hardening.zsh --battery-near-offline
```

## Both aggressive

Applies aggressive battery and AC profiles without the extra battery `networkoversleep 0` near-offline setting. This is retained as an explicit compatibility mode.

```zsh
./oclp-lid-sleep-hardening.zsh --both-aggressive
```

## Restore balanced

Restores safer battery and AC settings. Use this if aggressive hardening or `hibernatemode 25` causes wake, resume, or usability problems.

```zsh
./oclp-lid-sleep-hardening.zsh --restore-balanced
```

## EC/lid diagnostic

Prints a focused diagnostic report for battery state, battery profile, assertions, scheduled wakes, recent EC/lid/input/user activity events, hibernate stats, sleep/wake entries, and AppleSmartBattery power fields.

```zsh
./oclp-lid-sleep-hardening.zsh --ec-lid-diagnostic
```

## Install the closed-lid battery watchdog

Installs a root LaunchDaemon that performs two actions only when both the lid is closed and AppleSmartBattery reports no external power:

- Return unwanted wakes to sleep with `pmset sleepnow`.
- After four continuous hours, fully shut down on the first wake/check at or after the threshold.

Opening the lid or connecting power resets the four-hour timer. The shutdown terminates applications without waiting for unsaved-document dialogs.

```zsh
./oclp-lid-sleep-hardening.zsh --install-lid-watchdog
```

## Show watchdog status

Shows installed files, live lid and power readings, elapsed/remaining time, LaunchDaemon state, and recent logs. This mode does not change power state.

```zsh
./oclp-lid-sleep-hardening.zsh --lid-watchdog-status
```

## Remove the watchdog

Stops and removes the LaunchDaemon, executable, and active timer state. Diagnostic log files under `/var/log` are preserved.

```zsh
./oclp-lid-sleep-hardening.zsh --remove-lid-watchdog
```

## Help

```zsh
./oclp-lid-sleep-hardening.zsh --help
```
