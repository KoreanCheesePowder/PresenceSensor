# C.P Tuya Presence Sensor v1.1.6

Target: HOBEIAN ZG-204ZX

This build keeps the v1.1.4 UI and settings structure and adds read-only diagnostics for the sensor's current Tuya settings.

On startup, configure, and manual refresh the driver sends Tuya EF00 DataQuery (0x03). If the device returns the values, logcat prints them with `ZG204ZX SETTINGS`, including:
- static sensitivity (DP 2)
- detection distance (DP 4)
- fading time (DP 102)
- anti-interference (DP 103)
- humidity calibration (DP 104)
- temperature calibration (DP 105)
- illuminance interval (DP 107)
- indicator (DP 108)
- temperature unit (DP 109)
- motion sensitivity (DP 123)

No settings are written by the query itself.
