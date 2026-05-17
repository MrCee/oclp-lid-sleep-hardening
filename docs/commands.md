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
