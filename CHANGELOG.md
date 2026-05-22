# Changelog

## v0.3.0 - near-offline sleep guidance

- Add `--near-offline-sleep` as an explicit opt-in maximum drain suppression posture.
- Keep `--both-aggressive` as the default working baseline for phantom EC attach/detach behaviour.
- Add `NORMAL_MAINTENANCE_DARKWAKE_SUSPECT` verdict wording for residual RTC/Maintenance and DarkWake-style wakes.
- Document that the improved overnight pattern can still include normal macOS maintenance wakes and does not imply zero drain.
- Document trade-offs for Find My, sleep-time networking, Power Nap, wake convenience, slower resume, and reduced sleep-time services.

## v0.2.0 - EC/phantom AC attach aware hardening

- Add AC aggressive hardening because phantom `EC.ACAttach` can appear while physically on battery.
- Add `--audit-only` mode.
- Add `--ec-lid-diagnostic` mode for focused EC/lid/power evidence.
- Add `--restore-balanced` mode.
- Add clearer verdict classification:
  - `CLEAN`
  - `USERSPACE_BLOCKED`
  - `KERNEL_BLOCKED`
  - `EC_POWER_EVENT_SUSPECT`
  - `LID_INPUT_WAKE_SUSPECT`
- Keep `AddressBookSourceSync` quieting conditional on current assertions.

## v0.1.0 - initial hardening script

- Add initial battery-focused OCLP lid sleep hardening script.
- Apply aggressive battery pmset settings.
- Quiet Bluetooth auto-seek behaviour.
- Report pmset, assertions, Bluetooth prefs, and AddressBookSourceSync state.
