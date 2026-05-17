# Changelog

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
