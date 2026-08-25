# Changelog

## Unreleased

- Add an opt-in root LaunchDaemon that watches lid and AppleSmartBattery external-power state.
- Return confirmed closed-battery maintenance wakes to sleep with `pmset sleepnow`.
- After four continuous hours closed on battery, fully shut down at the first wake/check at or after the threshold.
- Reset the continuous timer when the lid opens or external power reconnects.
- Add install, status, and removal commands plus persistent watchdog diagnostics.
- Hide `--near-offline-sleep` from primary help and docs so `--battery-near-offline` is the single clear name for the default battery-first posture.
- Keep `--near-offline-sleep` only as a deprecated compatibility alias that maps to `--battery-near-offline`.

## v0.4.0 - battery near-offline default

- Make `--battery-near-offline` the default mode.
- Preserve `--near-offline-sleep` as a backwards-compatible alias for the new default.
- Keep `--both-aggressive` as an explicit compatibility mode rather than the default.
- Document the project as intentionally battery-first: lid-closed battery sleep should avoid intentional convenience wakes as much as macOS/OCLP allows.
- Keep AC aggressive compatibility in the default because phantom `EC.ACAttach` can route battery sleep through AC wake settings.
- Avoid claiming zero wakes or zero drain; firmware/macOS may still perform unavoidable RTC, hibernate, SMC, battery, or maintenance events.

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
