local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local clusters = require "st.zigbee.zcl.clusters"
local device_management = require "st.zigbee.device_management"
local log = require "log"
local tuya = require "tuya_utils"

local TemperatureMeasurement = clusters.TemperatureMeasurement
local RelativeHumidity = clusters.RelativeHumidity
local IlluminanceMeasurement = clusters.IlluminanceMeasurement
local PowerConfiguration = clusters.PowerConfiguration
local OccupancySensing = clusters.OccupancySensing

local TUYA_CLUSTER = 0xEF00
local TUYA_REPORT_COMMAND = 0x02
local TUYA_REPORT_COMMAND_ALT = 0x01

local DRIVER_NAME = "C.P Tuya Presence Sensor"
local DRIVER_VERSION = "v1.2.2"
local DRIVER_AUTHOR = "치즈가루"

local driver_info = capabilities["buildbook37604.driverInformation"]
local send_reads
local PROFILE_V122 = "cp-tuya-presence-v122"

local DP = {
  PRESENCE = 1,
  STATIC_SENSITIVITY = 2,
  DETECTION_DISTANCE = 4,
  HUMIDITY = 101,
  FADING_TIME = 102,
  ANTI_INTERFERENCE = 103,
  HUMIDITY_CALIBRATION = 104,
  TEMPERATURE_CALIBRATION = 105,
  ILLUMINANCE = 106,
  ILLUMINANCE_INTERVAL = 107,
  INDICATOR = 108,
  TEMPERATURE_UNIT = 109,
  BATTERY = 110,
  TEMPERATURE = 111,
  MOTION_SENSITIVITY = 123,
}

local function info_metadata()
  return {
    state_change = false,
    visibility = { displayed = false, non_archivable = true, ephemeral = true }
  }
end

local function emit_driver_information(device)
  if driver_info == nil then return end
  if driver_info.author ~= nil then
    device:emit_event(driver_info.author(DRIVER_AUTHOR, info_metadata()))
  end
  if driver_info.driverVersion ~= nil then
    device:emit_event(driver_info.driverVersion(DRIVER_VERSION, info_metadata()))
  end
end

local function clamp(value, min_value, max_value)
  if value < min_value then return min_value end
  if value > max_value then return max_value end
  return value
end

local function bytes_to_hex(body)
  if type(body) ~= "string" then return tostring(body) end
  local out = {}
  for i = 1, #body do
    out[#out + 1] = string.format("%02X", string.byte(body, i))
  end
  return table.concat(out, " ")
end

local function parse_unsigned_be(body, first, length)
  if type(body) ~= "string" or length <= 0 then return nil end
  if #body < first + length - 1 then return nil end
  local value = 0
  for i = first, first + length - 1 do
    value = value * 256 + string.byte(body, i)
  end
  return value
end

local function signed32(value)
  if value ~= nil and value >= 0x80000000 then return value - 0x100000000 end
  return value
end

local function write_value(device, dp, value, label)
  log.info(string.format("TUYA SET %s dp=0x%02X value=%s", label, dp, tostring(value)))
  tuya.send(device, dp, tuya.TYPE_VALUE, tuya.u32(value))
end

local function write_bool_inverted(device, dp, on, label)
  -- Keep the existing mapping for anti-interference: 0=ON, 1=OFF.
  local raw = on and 0 or 1
  log.info(string.format("TUYA SET %s dp=0x%02X value=%s raw=%d", label, dp, tostring(on), raw))
  tuya.send(device, dp, tuya.TYPE_BOOL, tuya.u8(raw))
end

local function write_bool_direct(device, dp, on, label)
  -- ZG-204ZX indicator DP108 observed mapping: 0=OFF, 1=ON.
  local raw = on and 1 or 0
  log.info(string.format("TUYA SET %s dp=0x%02X value=%s raw=%d", label, dp, tostring(on), raw))
  tuya.send(device, dp, tuya.TYPE_BOOL, tuya.u8(raw))
end

local function write_enum(device, dp, value, label)
  log.info(string.format("TUYA SET %s dp=0x%02X value=%s", label, dp, tostring(value)))
  tuya.send(device, dp, tuya.TYPE_ENUM, tuya.u8(value))
end

local function log_and_apply_tuya_dp(device, dp, dp_type, data_len, value, raw_segment)
  log.info(string.format(
    "TUYA EF00 DP dp=%s (%s) type=%s len=%d value=%s raw=%s",
    dp and string.format("0x%02X", dp) or "n/a",
    dp and tostring(dp) or "n/a",
    dp_type and string.format("0x%02X", dp_type) or "n/a",
    data_len or 0, tostring(value), raw_segment or ""))

  if dp == DP.PRESENCE and value ~= nil then
    local active = value ~= 0
    device:emit_event(active and capabilities.presenceSensor.presence.present() or capabilities.presenceSensor.presence.not_present())
    log.info(string.format("Presence=%s", active and "present" or "not present"))
    if active then
      device.thread:call_with_delay(0.5, function() send_reads(device) end)
    end

  elseif dp == DP.ILLUMINANCE and value ~= nil then
    local lux = clamp(value, 0, 1000000)
    device:emit_event(capabilities.illuminanceMeasurement.illuminance(lux))
    log.info(string.format("Illuminance=%d lux", lux))

  elseif dp == DP.TEMPERATURE and value ~= nil then
    local temperature = signed32(value) / 10.0
    device:emit_event(capabilities.temperatureMeasurement.temperature({value = temperature, unit = "C"}))
    log.info(string.format("Temperature DP=%.1f C", temperature))

  elseif dp == DP.HUMIDITY and value ~= nil then
    local humidity = clamp(value, 0, 100)
    device:emit_event(capabilities.relativeHumidityMeasurement.humidity(math.floor(humidity + 0.5)))
    log.info(string.format("Humidity DP=%d %%", humidity))

  elseif dp == DP.BATTERY and value ~= nil then
    local battery = clamp(value, 0, 100)
    device:emit_event(capabilities.battery.battery(battery))
    log.info(string.format("Battery=%d %%", battery))

  elseif dp == DP.TEMPERATURE_CALIBRATION and value ~= nil then
    log.info(string.format("ZG204ZX SETTINGS temperatureCalibration=%.1f C", signed32(value) / 10.0))
  elseif dp == DP.HUMIDITY_CALIBRATION and value ~= nil then
    log.info(string.format("ZG204ZX SETTINGS humidityCalibration=%d %%", signed32(value)))
  elseif dp == DP.FADING_TIME and value ~= nil then
    log.info(string.format("ZG204ZX SETTINGS fadingTime=%d s", value))
  elseif dp == DP.ILLUMINANCE_INTERVAL and value ~= nil then
    log.info(string.format("ZG204ZX SETTINGS illuminanceInterval=%d min", value))
  elseif dp == DP.DETECTION_DISTANCE and value ~= nil then
    log.info(string.format("ZG204ZX SETTINGS detectionDistance=%.2f m", value / 100.0))
  elseif dp == DP.MOTION_SENSITIVITY and value ~= nil then
    log.info(string.format("ZG204ZX SETTINGS motionSensitivity=%d", value))
  elseif dp == DP.STATIC_SENSITIVITY and value ~= nil then
    log.info(string.format("ZG204ZX SETTINGS staticSensitivity=%d", value))
  elseif dp == DP.INDICATOR and value ~= nil then
    log.info(string.format("ZG204ZX SETTINGS indicatorRaw=%d (%s)", value, value == 1 and "ON" or "OFF"))
  elseif dp == DP.ANTI_INTERFERENCE and value ~= nil then
    log.info(string.format("ZG204ZX SETTINGS antiInterferenceRaw=%d (%s)", value, value == 0 and "ON" or "OFF"))
  elseif dp == DP.TEMPERATURE_UNIT and value ~= nil then
    log.info(string.format("ZG204ZX SETTINGS temperatureUnit=%s", value == 1 and "F" or "C"))
  end
end

local function tuya_ef00_handler(driver, device, zb_rx)
  local zcl_body = zb_rx.body and zb_rx.body.zcl_body
  local body = zcl_body and zcl_body.body_bytes

  if type(body) ~= "string" then
    log.info(string.format("TUYA EF00 RX raw=%s", tostring(zcl_body)))
    return
  end

  log.info(string.format("TUYA EF00 RX payload=%s", bytes_to_hex(body)))

  -- Tuya response/report payload: 2-byte transaction id followed by one or
  -- more datapoint segments [dp][type][len_hi][len_lo][data...].
  local pos = 3
  local parsed = 0
  while pos + 3 <= #body do
    local dp = string.byte(body, pos)
    local dp_type = string.byte(body, pos + 1)
    local data_len = string.byte(body, pos + 2) * 256 + string.byte(body, pos + 3)
    local data_first = pos + 4
    local data_last = data_first + data_len - 1

    if data_len < 0 or data_last > #body then
      log.warn(string.format(
        "TUYA EF00 malformed segment at pos=%d dp=0x%02X len=%d payload=%s",
        pos, dp or 0, data_len, bytes_to_hex(body)))
      break
    end

    local value = data_len > 0 and parse_unsigned_be(body, data_first, data_len) or nil
    local raw_segment = bytes_to_hex(string.sub(body, pos, data_last))
    log_and_apply_tuya_dp(device, dp, dp_type, data_len, value, raw_segment)
    parsed = parsed + 1
    pos = data_last + 1
  end

  if parsed == 0 then
    log.warn(string.format("TUYA EF00 no datapoint segment parsed payload=%s", bytes_to_hex(body)))
  elseif pos <= #body then
    log.warn(string.format("TUYA EF00 trailing bytes=%s", bytes_to_hex(string.sub(body, pos))))
  end
end

local function temperature_handler(driver, device, value, zb_rx)
  local temperature = value.value / 100.0
  log.info(string.format("Temperature RX raw=%s value=%.2f C", tostring(value.value), temperature))
  device:emit_event(capabilities.temperatureMeasurement.temperature({value = temperature, unit = "C"}))
end

local function humidity_handler(driver, device, value, zb_rx)
  local humidity = clamp(value.value / 100.0, 0, 100)
  log.info(string.format("Humidity RX raw=%s value=%.2f %%", tostring(value.value), humidity))
  device:emit_event(capabilities.relativeHumidityMeasurement.humidity(math.floor(humidity + 0.5)))
end

local function illuminance_handler(driver, device, value, zb_rx)
  local raw = value.value
  local lux = 0
  if raw ~= 0 and raw ~= 0xFFFF then
    lux = math.floor((10 ^ ((raw - 1) / 10000)) + 0.5)
  end
  log.info(string.format("Illuminance RX raw=%s value=%d lux", tostring(raw), lux))
  device:emit_event(capabilities.illuminanceMeasurement.illuminance(lux))
end

local function occupancy_handler(driver, device, value, zb_rx)
  local raw = value.value or 0
  local active = (raw & 0x01) ~= 0
  device:emit_event(active and capabilities.presenceSensor.presence.present() or capabilities.presenceSensor.presence.not_present())
  log.info(string.format("Occupancy sync raw=%s -> %s", tostring(raw), active and "present" or "not present"))
end

local function query_tuya_settings(device)
  log.info("ZG204ZX SETTINGS QUERY: Tuya EF00 DataQuery 0x03")
  tuya.query_all(device)
end

send_reads = function(device)
  if OccupancySensing and OccupancySensing.attributes.Occupancy then
    device:send(OccupancySensing.attributes.Occupancy:read(device))
  end
  device:send(TemperatureMeasurement.attributes.MeasuredValue:read(device))
  device:send(RelativeHumidity.attributes.MeasuredValue:read(device))
  device:send(IlluminanceMeasurement.attributes.MeasuredValue:read(device))
  if PowerConfiguration and PowerConfiguration.attributes.BatteryPercentageRemaining then
    device:send(PowerConfiguration.attributes.BatteryPercentageRemaining:read(device))
  end
end

local function bind_standard_clusters(driver, device)
  if not (driver.environment_info and driver.environment_info.hub_zigbee_eui) then return end
  device:send(device_management.build_bind_request(device, TemperatureMeasurement.ID, driver.environment_info.hub_zigbee_eui))
  device:send(device_management.build_bind_request(device, RelativeHumidity.ID, driver.environment_info.hub_zigbee_eui))
  device:send(device_management.build_bind_request(device, IlluminanceMeasurement.ID, driver.environment_info.hub_zigbee_eui))
  if PowerConfiguration then
    device:send(device_management.build_bind_request(device, PowerConfiguration.ID, driver.environment_info.hub_zigbee_eui))
  end
end


local function added_handler(driver, device)
  device:emit_event(capabilities.presenceSensor.presence.not_present())
  emit_driver_information(device)
  bind_standard_clusters(driver, device)
  device.thread:call_with_delay(1, function() send_reads(device) end)
  device.thread:call_with_delay(2, function() query_tuya_settings(device) end)
end

local function init_handler(driver, device)
  log.info("Ensuring device profile is " .. PROFILE_V122)
  device:try_update_metadata({profile = PROFILE_V122})
  emit_driver_information(device)
  device.thread:call_with_delay(0.5, function() send_reads(device) end)
  device.thread:call_with_delay(1.5, function() query_tuya_settings(device) end)
end

local function do_configure_handler(driver, device)
  bind_standard_clusters(driver, device)
  send_reads(device)
  device.thread:call_with_delay(1, function() query_tuya_settings(device) end)
  emit_driver_information(device)
end

local function changed(old, new)
  return new ~= nil and tostring(old) ~= tostring(new)
end

local function info_changed_handler(driver, device, event, args)
  log.info("SmartThings Settings infoChanged received")
  local old = {}
  if args and args.old_st_store and args.old_st_store.preferences then
    old = args.old_st_store.preferences
  end
  local p = device.preferences or {}

  if changed(old.zgTemperatureUnit, p.zgTemperatureUnit) then
    log.info(string.format("SETTINGS changed zgTemperatureUnit: %s -> %s", tostring(old.zgTemperatureUnit), tostring(p.zgTemperatureUnit)))
    write_enum(device, DP.TEMPERATURE_UNIT, p.zgTemperatureUnit == "F" and 1 or 0, "temperatureUnit")
  end
  if changed(old.zgTemperatureCalibration, p.zgTemperatureCalibration) then
    log.info(string.format("SETTINGS changed zgTemperatureCalibration: %s -> %s", tostring(old.zgTemperatureCalibration), tostring(p.zgTemperatureCalibration)))
    write_value(device, DP.TEMPERATURE_CALIBRATION, math.floor((tonumber(p.zgTemperatureCalibration) or 0) * 10 + ((tonumber(p.zgTemperatureCalibration) or 0) >= 0 and 0.5 or -0.5)), "temperatureCalibration")
  end
  if changed(old.zgHumidityCalibration, p.zgHumidityCalibration) then
    log.info(string.format("SETTINGS changed zgHumidityCalibration: %s -> %s", tostring(old.zgHumidityCalibration), tostring(p.zgHumidityCalibration)))
    write_value(device, DP.HUMIDITY_CALIBRATION, tonumber(p.zgHumidityCalibration) or 0, "humidityCalibration")
  end
  if changed(old.zgFadingTime, p.zgFadingTime) then
    log.info(string.format("SETTINGS changed zgFadingTime: %s -> %s", tostring(old.zgFadingTime), tostring(p.zgFadingTime)))
    write_value(device, DP.FADING_TIME, tonumber(p.zgFadingTime) or 0, "fadingTime")
  end
  if changed(old.zgIndicator, p.zgIndicator) then
    log.info(string.format("SETTINGS changed zgIndicator: %s -> %s", tostring(old.zgIndicator), tostring(p.zgIndicator)))
    write_bool_direct(device, DP.INDICATOR, p.zgIndicator == "ON", "indicator")
  end
  if changed(old.zgIlluminanceInterval, p.zgIlluminanceInterval) then
    log.info(string.format("SETTINGS changed zgIlluminanceInterval: %s -> %s", tostring(old.zgIlluminanceInterval), tostring(p.zgIlluminanceInterval)))
    write_value(device, DP.ILLUMINANCE_INTERVAL, tonumber(p.zgIlluminanceInterval) or 1, "illuminanceInterval")
  end
  if changed(old.zgDetectionDistance, p.zgDetectionDistance) then
    log.info(string.format("SETTINGS changed zgDetectionDistance: %s -> %s", tostring(old.zgDetectionDistance), tostring(p.zgDetectionDistance)))
    write_value(device, DP.DETECTION_DISTANCE, math.floor((tonumber(p.zgDetectionDistance) or 0) * 100 + 0.5), "detectionDistance")
  end
  if changed(old.zgMotionSensitivity, p.zgMotionSensitivity) then
    log.info(string.format("SETTINGS changed zgMotionSensitivity: %s -> %s", tostring(old.zgMotionSensitivity), tostring(p.zgMotionSensitivity)))
    write_value(device, DP.MOTION_SENSITIVITY, tonumber(p.zgMotionSensitivity) or 0, "motionSensitivity")
  end
  if changed(old.zgStaticSensitivity, p.zgStaticSensitivity) then
    log.info(string.format("SETTINGS changed zgStaticSensitivity: %s -> %s", tostring(old.zgStaticSensitivity), tostring(p.zgStaticSensitivity)))
    write_value(device, DP.STATIC_SENSITIVITY, tonumber(p.zgStaticSensitivity) or 0, "staticSensitivity")
  end
  if changed(old.zgAntiInterference, p.zgAntiInterference) then
    log.info(string.format("SETTINGS changed zgAntiInterference: %s -> %s", tostring(old.zgAntiInterference), tostring(p.zgAntiInterference)))
    write_bool_inverted(device, DP.ANTI_INTERFERENCE, p.zgAntiInterference == "ON", "antiInterference")
  end

  emit_driver_information(device)
end

local function refresh_handler(driver, device, command)
  log.info("Manual refresh requested")
  send_reads(device)
  device.thread:call_with_delay(0.8, function() query_tuya_settings(device) end)
  emit_driver_information(device)
end

local driver_template = {
  health_check = false,
  supported_capabilities = {
    capabilities.presenceSensor,
    capabilities.illuminanceMeasurement,
    capabilities.temperatureMeasurement,
    capabilities.relativeHumidityMeasurement,
    capabilities.battery,
    capabilities.refresh,
    driver_info
  },
  lifecycle_handlers = {
    added = added_handler,
    init = init_handler,
    doConfigure = do_configure_handler,
    infoChanged = info_changed_handler
  },
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = refresh_handler
    }
  },
  zigbee_handlers = {
    attr = {
      [TemperatureMeasurement.ID] = {
        [TemperatureMeasurement.attributes.MeasuredValue.ID] = temperature_handler
      },
      [RelativeHumidity.ID] = {
        [RelativeHumidity.attributes.MeasuredValue.ID] = humidity_handler
      },
      [IlluminanceMeasurement.ID] = {
        [IlluminanceMeasurement.attributes.MeasuredValue.ID] = illuminance_handler
      },
      [OccupancySensing.ID] = {
        [OccupancySensing.attributes.Occupancy.ID] = occupancy_handler
      }
    },
    cluster = {
      [TUYA_CLUSTER] = {
        [TUYA_REPORT_COMMAND] = tuya_ef00_handler,
        [TUYA_REPORT_COMMAND_ALT] = tuya_ef00_handler
      }
    }
  }
}

defaults.register_for_default_handlers(driver_template, {
  capabilities.illuminanceMeasurement,
  capabilities.temperatureMeasurement,
  capabilities.relativeHumidityMeasurement,
  capabilities.battery
})

local driver = ZigbeeDriver(DRIVER_NAME, driver_template)
driver:run()
