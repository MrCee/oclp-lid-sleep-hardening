# Commands

Run commands from the repository root:

```zsh
cd /Users/paul/repos/oclp-lid-sleep-hardening
chmod +x ./oclp-lid-sleep-hardening.zsh
```

## Audit only

Reports current pmset settings, assertions, scheduled wakes, Bluetooth prefs, AddressBookSourceSync state, and verdicts without applying changes.

```zsh
./oclp-lid-sleep-hardening.zsh --audit-only
```

## Both aggressive

Applies aggressive battery and AC profiles. This is the default because phantom `EC.ACAttach` can route macOS into AC wake behaviour while the machine is physically on battery.

```zsh
./oclp-lid-sleep-hardening.zsh --both-aggressive
```

Equivalent default invocation:

```zsh
./oclp-lid-sleep-hardening.zsh
```

## Near-offline sleep

Applies the working aggressive battery and AC baseline, then attempts to suppress additional sleep-time network reachability with `networkoversleep 0` where supported. Use this only when EC attach/detach events look quiet and remaining drain appears to be periodic RTC/Maintenance or DarkWake behaviour.

This is opt-in and does not guarantee zero drain. It may reduce Find My, Handoff, iCloud, app refresh, remote reachability, and other sleep-time services.

```zsh
./oclp-lid-sleep-hardening.zsh --near-offline-sleep
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

## Help

```zsh
./oclp-lid-sleep-hardening.zsh --help
```
