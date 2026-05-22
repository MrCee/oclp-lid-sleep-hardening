# Diagnostics

Use `--ec-lid-diagnostic` when the machine still wakes or drains after the default battery near-offline profile has been applied.

```zsh
./oclp-lid-sleep-hardening.zsh --ec-lid-diagnostic
```

## EC phantom power events

These patterns suggest the embedded controller or SMC is reporting AC attach/detach while the Mac may physically be on battery:

```text
Wake from Standby ... due to EC.ACAttach/Maintenance Using BATT
DarkWake from Safe Sleep ... due to EC.ACDetach/Maintenance Using BATT
Wake from Standby ... due to EC.ACAttach/Maintenance Using AC
```

If `AppleSmartBattery` reports `ExternalConnected` as `0`, `No`, or `false` while these events appear, the script reports `EC_POWER_EVENT_SUSPECT`.

When a targeted overnight window shows no new `EC.ACAttach` or `EC.ACDetach` events, treat the default battery near-offline profile as the current baseline and look at remaining wake causes separately.

## Normal maintenance / DarkWake events

These patterns suggest residual macOS maintenance wake behaviour rather than the earlier phantom EC attach/detach problem:

```text
Wake from Standby ... due to RTC/Maintenance Using BATT
MaintenanceWake mDNSResponder:maintenance
DarkWake
HibernateStats hibmode=25 standbydelaylow=0 standbydelayhigh=0
```

The script reports `NORMAL_MAINTENANCE_DARKWAKE_SUSPECT` when recent logs contain RTC/Maintenance or DarkWake-style activity. This does not mean sleep hardening failed. It means macOS or firmware still performed some closed-lid activity that can consume battery even when current assertions and EC attach/detach events are quiet.

The default now targets battery near-offline sleep. Remaining RTC, hibernate, SMC, battery, or maintenance activity may still occur if macOS/firmware forces it. The tool does not guarantee zero drain.

## Lid and input wake events

These patterns suggest lid, ACPI button, keyboard, trackpad, USB input, or user activity involvement:

```text
EC.LidOpen
AppleACPILid
AppleEmbeddedKeyboard
AppleUSBMultitouchDriver
AppleACPIButton
UserActivity
```

The script reports `LID_INPUT_WAKE_SUSPECT` when recent logs contain these entries.

## User-space blockers

Current assertions can block idle sleep even when pmset settings are correct. Examples observed during diagnosis:

```text
PreventUserIdleSystemSleep from Excel
PreventUserIdleSystemSleep from AddressBookSourceSync
PreventUserIdleSystemSleep from cloudd
PreventUserIdleSystemSleep from akd
PreventUserIdleSystemSleep from identityservicesd
```

The script reports `USERSPACE_BLOCKED` when current assertions show `PreventUserIdleSystemSleep 1`, `PreventSystemSleep 1`, or `NetworkClientActive 1`.

## Kernel blockers

Kernel assertions can also prevent sleep. The script reports `KERNEL_BLOCKED` when current assertions include CPU, `IOPMrootDomain`, `preventSleep`, or `pci.hostBridge.preventSleep` patterns.
