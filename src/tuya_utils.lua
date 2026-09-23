-- Tuya EF00 command helper.
-- Based on the SmartThings Community tuya-zigbee utility pattern (Apache-2.0).
local zcl_messages = require "st.zigbee.zcl"
local messages = require "st.zigbee.messages"
local data_types = require "st.zigbee.data_types"
local zb_const = require "st.zigbee.constants"
local generic_body = require "st.zigbee.generic_body"

local M = {}
local TUYA_CLUSTER = 0xEF00
local packet_id = 0

M.TYPE_BOOL = "\x01"
M.TYPE_VALUE = "\x02"
M.TYPE_ENUM = "\x04"

local function next_packet_id()
  packet_id = (packet_id + 1) % 65536
  return packet_id
end

function M.u32(value)
  value = math.floor(tonumber(value) or 0)
  if value < 0 then value = 0x100000000 + value end
  return string.pack(">I4", value)
end

function M.u8(value)
  return string.char(math.floor(tonumber(value) or 0) % 256)
end

function M.send(device, dp, dp_type, dp_data)
  local zclh = zcl_messages.ZclHeader({cmd = data_types.ZCLCommandId(0x00)})
  zclh.frame_ctrl:set_cluster_specific()
  zclh.frame_ctrl:set_disable_default_response()

  local addrh = messages.AddressHeader(
    zb_const.HUB.ADDR,
    zb_const.HUB.ENDPOINT,
    device:get_short_address(),
    device:get_endpoint(TUYA_CLUSTER),
    zb_const.HA_PROFILE_ID,
    TUYA_CLUSTER
  )

  local payload = generic_body.GenericBody(
    string.pack(">I2", next_packet_id()) ..
    string.char(dp) ..
    dp_type ..
    string.pack(">I2", #dp_data) ..
    dp_data
  )

  local body = zcl_messages.ZclMessageBody({zcl_header = zclh, zcl_body = payload})
  device:send(messages.ZigbeeMessageTx({address_header = addrh, body = body}))
end

function M.query_all(device)
  local zclh = zcl_messages.ZclHeader({cmd = data_types.ZCLCommandId(0x03)})
  zclh.frame_ctrl:set_cluster_specific()
  zclh.frame_ctrl:set_disable_default_response()

  local addrh = messages.AddressHeader(
    zb_const.HUB.ADDR,
    zb_const.HUB.ENDPOINT,
    device:get_short_address(),
    device:get_endpoint(TUYA_CLUSTER),
    zb_const.HA_PROFILE_ID,
    TUYA_CLUSTER
  )

  local body = zcl_messages.ZclMessageBody({
    zcl_header = zclh,
    zcl_body = generic_body.GenericBody("")
  })
  device:send(messages.ZigbeeMessageTx({address_header = addrh, body = body}))
end

return M
