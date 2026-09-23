# Changelog

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
