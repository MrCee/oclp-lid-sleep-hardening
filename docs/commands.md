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

## Help

```zsh
./oclp-lid-sleep-hardening.zsh --help
```
