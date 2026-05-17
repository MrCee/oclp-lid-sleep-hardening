# 💤 OCLP Lid Sleep Diagnostic & Hardening

<p align="left">
  <img alt="License MIT" src="https://img.shields.io/badge/License-MIT-gold?style=for-the-badge">
  <img alt="PRs welcome" src="https://img.shields.io/badge/PRs-welcome-brightgreen?style=for-the-badge">
  <img alt="Platform macOS" src="https://img.shields.io/badge/Platform-macOS-black?style=for-the-badge">
  <img alt="OpenCore Legacy Patcher" src="https://img.shields.io/badge/OpenCore-Legacy%20Patcher-blue?style=for-the-badge">
  <img alt="Target Intel MacBooks" src="https://img.shields.io/badge/Target-Intel%20MacBooks-lightgrey?style=for-the-badge">
</p>

Sleep diagnostics and optional hardening for unsupported MacBook installs running via **OpenCore Legacy Patcher**.

This project was created after diagnosing an older MacBook Pro where macOS kept waking, dark-waking, or draining battery after the lid was closed. It is not a universal fix. It gives you a repeatable report, a focused EC/lid diagnostic mode, and conservative hardening modes you can apply or restore.

This is **not** an official OpenCore Legacy Patcher project.

---

## ✨ What this is for

This is for older or unsupported MacBooks running macOS through OCLP where lid-closed sleep is unreliable.

Common symptoms:

- 🔋 Battery drains while the lid is closed
- 🌙 Repeated `DarkWake` events
- 💻 The Mac wakes shortly after lid close
- 🧲 Wake reasons such as `EC.ACAttach`, `EC.ACDetach`, `EC.LidOpen`, `EC.PME/User`, `UserActivity`, or `XHC1`
- ⌨️ Keyboard, trackpad, lid, ACPI, USB, or Bluetooth wake events
- 🧵 App-level blockers such as Excel, Contacts sync, iCloud sync, or Apple account services
- 🛑 `PreventUserIdleSystemSleep` assertions that rotate between apps and system services

---

## 🧪 Observed scenario

| Item | Value |
|---|---|
| Mac | MacBook Pro 11,3 |
| Install type | Unsupported macOS via OCLP |
| Problem | Lid-closed battery drain / repeated wake |
| Observed blockers during diagnosis | Excel, AddressBookSourceSync, cloudd, akd, identityservicesd |
| Observed wake style | Phantom EC/SMC AC attach/detach, lid/input/user activity wake |
| Goal | Diagnose the wake path and optionally harden both battery and AC profiles |

On this MacBookPro11,3, the battery pmset profile was correctly applied, including `lidwake 0`, `hibernatemode 25`, immediate standby delays, and disabled network wake options. The machine still woke while physically on battery.

The important log pattern was phantom power-state activity:

```text
DarkWake from Safe Sleep due to EC.ACDetach/Maintenance Using BATT
Wake from Standby due to EC.ACAttach/Maintenance Using BATT
Wake from Standby due to EC.ACAttach/Maintenance Using AC
```

Because macOS may route wake behaviour through AC paths after an `EC.ACAttach` event, hardening only the battery profile may not be enough on this machine.

---

## ⚙️ Modes

```zsh
chmod +x ./oclp-lid-sleep-hardening.zsh
./oclp-lid-sleep-hardening.zsh --audit-only
./oclp-lid-sleep-hardening.zsh --both-aggressive
./oclp-lid-sleep-hardening.zsh --restore-balanced
./oclp-lid-sleep-hardening.zsh --ec-lid-diagnostic
```

Default mode is `--both-aggressive`.

Available modes:

| Mode | Purpose |
|---|---|
| `--audit-only` | Write the normal report without applying changes. |
| `--battery-aggressive` | Harden the battery profile and apply Bluetooth/AddressBook quieting. |
| `--ac-aggressive` | Harden the AC profile and apply Bluetooth/AddressBook quieting. |
| `--both-aggressive` | Harden both battery and AC profiles. This is the default. |
| `--restore-balanced` | Restore a safer balanced battery and AC profile. |
| `--ec-lid-diagnostic` | Print focused EC/lid/power evidence, recent hibernate stats, and battery external-power fields. |
| `--help` | Show usage. |

The script writes a report to your Desktop. Normal report modes also copy the report to the clipboard.

---

## 🛠️ What aggressive hardening changes

On **battery** and/or **AC**, depending on the selected mode:

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

It also disables Bluetooth auto-seek behaviour in hardening modes:

```text
BluetoothAutoSeekKeyboard       false
BluetoothAutoSeekPointingDevice false
```

If `AddressBookSourceSync` is actively seen in current assertions when a hardening mode runs, the script disables that user LaunchAgent for the current user session. It does not blindly disable it during audit-only runs or when it is not currently involved.

---

## ⚠️ Important trade-offs

| Change | Trade-off |
|---|---|
| `lidwake=0` | Opening the lid may not wake the Mac automatically. Press the power button or a key. |
| `hibernatemode=25` | Wake may be slower because the Mac favours deeper hibernate-style sleep. Some OCLP machines may not behave well with this mode. |
| `tcpkeepalive=0` | Sleep-time network features such as Find My Mac may not work normally while sleeping. |
| AC aggressive profile | Useful when phantom `EC.ACAttach` is observed on battery, but less convenient for normal plugged-in behaviour. |
| AddressBook SourceSync disable | Contacts source sync may pause until restored. |

Use `--restore-balanced` if `hibernatemode 25` or the aggressive profile causes wake, resume, or usability problems.

---

## 🔍 Verdicts

The report classifies the current state as one or more of:

| Verdict | Meaning |
|---|---|
| `CLEAN` | No current user-space/kernel blockers or recent EC/lid/input wake suspects detected. |
| `USERSPACE_BLOCKED` | Current assertions show `PreventUserIdleSystemSleep`, `PreventSystemSleep`, or `NetworkClientActive`. |
| `KERNEL_BLOCKED` | Current assertions show kernel sleep blockers such as CPU, IOPMrootDomain, or preventSleep. |
| `EC_POWER_EVENT_SUSPECT` | Recent logs show `EC.ACAttach` or `EC.ACDetach`. |
| `LID_INPUT_WAKE_SUSPECT` | Recent logs show lid, ACPI button, keyboard, trackpad, or `UserActivity` wake evidence. |

---

## 🧯 Restore AddressBook SourceSync

If `com.apple.AddressBook.SourceSync` was disabled and you want to restore Contacts source sync:

```zsh
launchctl enable "gui/$UID/com.apple.AddressBook.SourceSync" 2>&1 || true
launchctl bootstrap "gui/$UID" /System/Library/LaunchAgents/com.apple.AddressBook.SourceSync.plist 2>&1 || true
```

---

## 🧠 Diagnostic notes

Dortania/OpenCore sleep guidance notes that macOS lid wake detection can be broken and may require disabling lid wake with `pmset lidwake 0`. Dortania instant-wake guidance also discusses wake behaviour when USB or power states change while sleeping, which matches the observed `EC.ACAttach` / `EC.ACDetach` style evidence.

Observed user-space blockers included:

```text
Microsoft Excel:
  PreventUserIdleSystemSleep
  com.apple.CFNetwork.StorageDB

AddressBookSourceSync:
  PreventUserIdleSystemSleep
  Address Book Source Sync

cloudd / akd / identityservicesd:
  PreventUserIdleSystemSleep
  NSURLSessionTask
  IDSPeerIDLookup
  com.apple.CFNetwork.StorageDB
```

Observed wake patterns included:

```text
EC.ACAttach
EC.ACDetach
EC.LidOpen
AppleEmbeddedKeyboard
AppleUSBMultitouchDriver
AppleACPIButton
AppleACPILid
UserActivity
```

---

## 📦 What changed in v0.2.0

- Adds AC aggressive profile because phantom AC attach can happen on battery.
- Adds audit-only mode.
- Adds EC/lid diagnostic mode.
- Adds restore-balanced mode.
- Adds clearer verdict classification.

---

## 📜 License

MIT License.

---

## 🙏 Disclaimer

Use at your own risk.

This project is not affiliated with OpenCore Legacy Patcher, Dortania, Apple, or Microsoft.

It changes power-management settings. Read the script before running it.
