# 💤 OCLP Lid Sleep Hardening

<p align="left">
  <img alt="License MIT" src="https://img.shields.io/badge/License-MIT-gold?style=for-the-badge">
  <img alt="PRs welcome" src="https://img.shields.io/badge/PRs-welcome-brightgreen?style=for-the-badge">
  <img alt="Platform macOS" src="https://img.shields.io/badge/Platform-macOS-black?style=for-the-badge">
  <img alt="OpenCore Legacy Patcher" src="https://img.shields.io/badge/OpenCore-Legacy%20Patcher-blue?style=for-the-badge">
  <img alt="Target Intel MacBooks" src="https://img.shields.io/badge/Target-Intel%20MacBooks-lightgrey?style=for-the-badge">
</p>

Battery-focused lid sleep hardening for unsupported MacBook installs running via **OpenCore Legacy Patcher**.

This project was created after diagnosing an older MacBook Pro where macOS kept waking, dark-waking, or draining battery after the lid was closed.

The fix is intentionally practical: it applies a stricter battery sleep profile, quietens common wake triggers, and gives you a repeatable audit path for finding apps or Apple background services that are currently blocking sleep.

---

## ✨ What this is for

This is for older or unsupported MacBooks running macOS through OCLP where lid-closed sleep is unreliable.

Common symptoms:

- 🔋 Battery drains while the lid is closed
- 🌙 Repeated `DarkWake` events
- 💻 The Mac wakes shortly after lid close
- 🧲 Wake reasons such as `EC.PME/User`, `EC.LidOpen`, `UserActivity`, or `XHC1`
- ⌨️ Keyboard, trackpad, lid, ACPI, or Bluetooth wake events
- 🧵 App-level blockers such as Excel, Contacts sync, iCloud sync, or Apple account services
- 🛑 `PreventUserIdleSystemSleep` assertions that rotate between apps and system services

This is **not** an official OpenCore Legacy Patcher project.

It is a field-tested hardening script for people who prefer battery preservation over instant wake convenience.

---

## 🧪 Tested scenario

| Item | Value |
|---|---|
| Mac | MacBook Pro 11,3 |
| Install type | Unsupported macOS via OCLP |
| Problem | Lid-closed battery drain / repeated wake |
| Observed blockers during diagnosis | Excel, AddressBookSourceSync, cloudd, akd |
| Observed wake style | EC / lid / user input / embedded controller wake |
| Goal | Force aggressive battery-preserving sleep |

---

## ⚙️ What the script changes

On **battery power**, the script applies an aggressive deep-sleep profile:

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
```

It also disables Bluetooth auto-seek behaviour:

```text
BluetoothAutoSeekKeyboard       false
BluetoothAutoSeekPointingDevice false
```

If `AddressBookSourceSync` is actively holding a sleep assertion when the script runs, the script disables that user LaunchAgent for the current user session.

---

## ⚠️ Important trade-offs

| Change | Trade-off |
|---|---|
| `lidwake=0` | Opening the lid may not wake the Mac automatically. Press the power button or a key. |
| `hibernatemode=25` | Wake may be slower because the Mac favours deeper hibernate-style sleep. |
| `tcpkeepalive=0` | Sleep-time network features such as Find My Mac may not work normally while sleeping. |
| AddressBook SourceSync disable | Contacts source sync may pause until restored. |

This is designed for people who want:

> When I close the lid on battery, preserve battery first. Convenience second.

---

## 🚀 Usage

```zsh
chmod +x ./oclp-lid-sleep-hardening.zsh
./oclp-lid-sleep-hardening.zsh
```

The script writes a report to your Desktop.

---

## 🔍 Quick pre-lid audit

Before closing the lid, check whether anything is currently blocking sleep:

```zsh
pmset -g batt
pmset -g custom | egrep -i "Battery Power|lidwake|hibernatemode|standby|standbydelay|autopoweroff|ttyskeepawake|powernap|womp|acwake|sleep"
pmset -g assertions
```

A clean result should show:

```text
PreventSystemSleep             0
PreventUserIdleSystemSleep     0
NetworkClientActive            0
No kernel assertions.
```

---

## 🧯 Restore AddressBook SourceSync

If `com.apple.AddressBook.SourceSync` was disabled and you want to restore Contacts source sync:

```zsh
launchctl enable "gui/$UID/com.apple.AddressBook.SourceSync" 2>&1 || true
launchctl bootstrap "gui/$UID" /System/Library/LaunchAgents/com.apple.AddressBook.SourceSync.plist 2>&1 || true
```

---

## 🧠 Diagnostic notes

During the original investigation, the following blockers and wake patterns appeared:

```text
Microsoft Excel:
  PreventUserIdleSystemSleep
  com.apple.CFNetwork.StorageDB

AddressBookSourceSync:
  PreventUserIdleSystemSleep
  Address Book Source Sync

cloudd / akd:
  PreventUserIdleSystemSleep
  NSURLSessionTask
  com.apple.CFNetwork.StorageDB

Wake patterns:
  EC.PME/User
  EC.LidOpen
  EC.LidOpen PWRB/Lid Open
  AppleEmbeddedKeyboard
  AppleUSBMultitouchDriver
  AppleACPIButton
  AppleACPILid
```

The script does not pretend every OCLP sleep issue has one universal fix. It gives you a stronger sleep baseline and a repeatable way to see what is blocking sleep right now.

---

## 📜 License

MIT License.

---

## 🙏 Disclaimer

Use at your own risk.

This project is not affiliated with OpenCore Legacy Patcher, Dortania, Apple, or Microsoft.

It changes power-management settings. Read the script before running it.
