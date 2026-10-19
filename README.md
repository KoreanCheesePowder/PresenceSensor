# C.P Tuya Presence Sensor v1.2.4

SmartThings Edge driver supporting **two independent device variants**:

- **HOBEIAN / ZG-204ZX**: original v1.2.2 profile, environmental readings and settings are preserved unchanged.
- **_TZE200_ka8l86iu / TS0601**: TYPE6 / ZG-204ZP-type battery mmWave sensor; presence, standard motion (mirrors presence), battery, refresh and its own settings.

The packageKey is unchanged (`cheesepowder.tuya-presence-test`), so v1.2.4 updates the previously installed driver rather than creating a new one. Existing device registration and routines should not need to be deleted.

TYPE6 detects presence from Tuya EF00 DP1 and IAS Zone (0x0500); battery is read from DP121 or standard Power Configuration. TYPE6 settings use DP2 / 4 / 102 / 107 / 122 / 123. The original model retains its own DP101-111 mapping.

**TYPE6 motion note:** the `motionSensor` state follows the same detected/not-detected signal as the presenceSensor. It is not a separate classification of active movement vs. still presence.

**Test status:** Device/DP fingerprints were verified against publicly documented deployments, and ZIP/YAML/Lua regression checks run locally. On-hub operation and the device's actual datapoint reports require a live user test.

Detailed installation and functional checks: `docs/INSTALL-TYPE6.txt`.
