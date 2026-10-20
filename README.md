# C.P Tuya Presence Sensor v1.3.1

- Supports existing ZG-204ZX (HOBEIAN) 3 devices and TYPE6 (TS0601 / `_TZE200_ka8l86iu`) 2 devices.
- Retains existing packageKey, channel, hub, fingerprints, capability, profiles, and all sensor settings.
- Manufacturer/author field: `치즈가루` only; TYPE6 communication status remains a separate custom capability.

## Install / update (SmartThings CLI 2.1.2)

1. Extract this ZIP to a **fresh directory**.
2. Run `SETUP-AND-INSTALL.cmd`. It runs the official `smartthings edge:drivers:package` update command directly.
3. Confirm the displayed driver version `v1.3.1` on SmartThings and check `logcat` for device errors.

The prior v1.3.0 attempt **already registered** `buildbook37604.type6communication` and its presentation. This build does not create, delete, or read those resources through PowerShell. The installer deliberately has no PowerShell dependency and does not parse JSON.

**Do not remove/re-pair devices or delete routines.** This update is specific to the user's existing account and is **not** an initial capability-creation installer for a new SmartThings account.

## System Monitor

`monitor/type6_monitor_adapter.py` and `monitor/type6_monitor_adapter.js` expose SmartThings communication states for integration. They are **not yet installed into the production System Monitor**; an operational System Monitor source ZIP is required to complete that integration.
