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

After applying the aggressive battery and AC profiles, the same machine showed a materially improved overnight result: no new `EC.ACAttach` or `EC.ACDetach` events appeared in a targeted 15-hour `pmset` window, the remaining wakes looked like periodic `RTC/Maintenance` / `DarkWake` behaviour, and the battery moved from roughly 100% near lid close to roughly 92-93% by morning. That remaining drain is treated as normal-ish macOS maintenance behaviour, not the earlier phantom EC attach/detach failure mode.

---

## ⚙️ Modes

```zsh
chmod +x ./oclp-lid-sleep-hardening.zsh
./oclp-lid-sleep-hardening.zsh --audit-only
./oclp-lid-sleep-hardening.zsh --both-aggressive
./oclp-lid-sleep-hardening.zsh --near-offline-sleep
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
| `--near-offline-sleep` | Apply the working aggressive baseline and add maximum practical sleep-time network/maintenance suppression. |
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

This is the current working baseline. It is intentionally still the default via `--both-aggressive`, because the original failure pattern was a phantom EC/SMC AC attach/detach path that could make battery-only hardening insufficient.

It also disables Bluetooth auto-seek behaviour in hardening modes:

```text
BluetoothAutoSeekKeyboard       false
BluetoothAutoSeekPointingDevice false
```

If `AddressBookSourceSync` is actively seen in current assertions when a hardening mode runs, the script disables that user LaunchAgent for the current user session. It does not blindly disable it during audit-only runs or when it is not currently involved.

---

## 📴 Near-offline sleep

Use `--near-offline-sleep` only after the EC attach/detach problem looks quiet and the remaining drain appears to be normal macOS maintenance / DarkWake behaviour.

```zsh
./oclp-lid-sleep-hardening.zsh --near-offline-sleep
```

This mode does not replace the working baseline. It reapplies both aggressive battery and AC profiles, keeps Bluetooth/AddressBook quieting behaviour, and additionally attempts to disable sleep-time network reachability with:

```text
networkoversleep     0 where supported
```

The goal is maximum practical drain suppression, closer to a near-offline sleep posture. It attempts to reduce sleep-time network and maintenance wake paths as much as macOS exposes through `pmset`. It does not promise zero overnight drain, and it cannot guarantee that macOS will never perform RTC, maintenance, or DarkWake activity.

This mode is deliberately opt-in because it can make the sleeping Mac less reachable and less serviceful while closed.

---

## ⚠️ Important trade-offs

| Change | Trade-off |
|---|---|
| `lidwake=0` | Opening the lid may not wake the Mac automatically. Press the power button or a key. |
| `hibernatemode=25` | Wake may be slower because the Mac favours deeper hibernate-style sleep. Some OCLP machines may not behave well with this mode. |
| `tcpkeepalive=0` | Sleep-time network features such as Find My Mac, remote reachability, and some iCloud/Handoff behaviour may not work normally while sleeping. |
| `networkoversleep=0` | Near-offline mode further reduces sleep-time network reachability where supported. This can reduce maintenance wakes but may also reduce sleep-time services. |
| `powernap=0` | Background mail, iCloud, Photos, app refresh, and other Power Nap-style maintenance should be reduced while sleeping. |
| `womp=0` / `acwake=0` / `proximitywake=0` | Network, AC-change, and nearby-device wake paths are reduced where supported. Convenience wake behaviour may be worse. |
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
| `NORMAL_MAINTENANCE_DARKWAKE_SUSPECT` | Recent logs show RTC/Maintenance or DarkWake-style activity that can still drain battery even when EC attach/detach and current blockers are quiet. |

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

After the aggressive baseline improved the EC attach/detach issue, remaining observed closed-lid wakes looked more like:

```text
Wake from Standby due to RTC/Maintenance Using BATT
MaintenanceWake mDNSResponder:maintenance
HibernateStats hibmode=25 standbydelaylow=0 standbydelayhigh=0
```

Those events can still consume battery. `--near-offline-sleep` is the opt-in posture for trying to reduce that remaining activity as much as practical.

---

## 📦 What changed in v0.3.0

- Adds `--near-offline-sleep` for explicit maximum practical drain suppression after EC attach/detach is quiet.
- Adds `NORMAL_MAINTENANCE_DARKWAKE_SUSPECT` verdict wording for RTC/Maintenance and DarkWake-style residual drain.
- Documents the current aggressive battery+AC profile as the working baseline.
- Documents trade-offs around Find My, network wake, Power Nap, wake convenience, slower resume, and reduced sleep-time services.

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
