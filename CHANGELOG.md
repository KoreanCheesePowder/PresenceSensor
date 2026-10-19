# Changelog

## v1.2.4
- Fixed fatal driver startup crash at `init.lua:606` when the hub SDK has no `IASZone.commands.server` table.
- Registered IAS Zone status/enroll handlers using standard command IDs (`0x00`, `0x01`) independent of SDK layout.
- Made ZoneEnrollResponse lookup safe across Edge SDK layouts, with a nonfatal fallback to EF00 reporting.
- Updated IAS Zone status notifications to read both common SmartThings payload layouts.
- Kept the original ZG-204ZX v1.2.2 profile, environmental data handling and settings unchanged.
- Maintained separate TYPE6-only profile, capabilities and Tuya DP mapping; no device re-pairing required.


## v1.2.3
- Added exact fingerprint `_TZE200_ka8l86iu / TS0601` (TYPE6).
- Added isolated TYPE6 profile (presence, motion, battery, refresh, driver info; six device settings).
- Added TYPE6 Tuya EF00 DP mapping, IAS Zone 0x0500 enrollment and status notifications.
- Kept HOBEIAN ZG-204ZX profile, DP map and settings flow unchanged.
- Updated installer messages to v1.2.3.
- TYPE6 motion capability mirrors its presence signal (not independent movement discrimination).


## v1.2.2
- Restored v1.1.7 profile/preferences structure to recover Settings persistence.
- Restored buildbook37604.driverInformation so the driver version appears again.
- New profile cp-tuya-presence-v122.
- Corrected only LED indicator DP108 mapping to 0=OFF / 1=ON.
- Kept anti-interference mapping and all presence/environment packet handling unchanged.

# v1.1.7
- Added a new immutable profile `cp-tuya-presence-v117` so embedded preferences are created fresh by SmartThings.
- Removed the invalid top-level `deviceConfig` UI block from the new profile; SmartThings now generates the default Edge presentation from capabilities.
- Added one-time migration of the existing device to the v1.1.7 profile.
- Kept legacy `cp-tuya-presence-v114` in the package for package-update compatibility.
- No changes to Tuya DP mapping or presence/environment parsing.
