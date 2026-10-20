-- Execute with texlua tests/regression.lua; mocked Edge SDK, no hub required.
local source = debug.getinfo(1, 'S').source:sub(2)
local root = source:gsub('[/\\]tests[/\\]regression.lua$', '')
package.path = root .. '/src/?.lua;' .. package.path
local epoch = 1000000
os.time = function() return epoch end
local captured
-- Match the SmartThings Edge Lua runtime: tonumber() with NO value is an error,
-- while tonumber(nil) is allowed. TeXLua otherwise hides this regression.
local native_tonumber = tonumber
tonumber = function(...)
  if select('#', ...) == 0 then error("bad argument #1 to 'tonumber' (value expected)") end
  return native_tonumber(...)
end
local function ev(cap, attr, val)
  return {capability = cap, attribute = attr, value = val}
end
local capabilities = {
  presenceSensor = {ID='presenceSensor', presence = {
    present = function() return ev('presenceSensor','presence','present') end,
    not_present = function() return ev('presenceSensor','presence','not present') end}},
  motionSensor = {ID='motionSensor', motion = {
    active = function() return ev('motionSensor','motion','active') end,
    inactive = function() return ev('motionSensor','motion','inactive') end}},
  battery = {ID='battery', battery = function(v) return ev('battery','battery',v) end},
  refresh = {ID='refresh',commands={refresh={NAME='refresh'}}},
  illuminanceMeasurement = {ID='illuminanceMeasurement', illuminance=function(v) return ev('illuminanceMeasurement','illuminance',v) end},
  temperatureMeasurement = {ID='temperatureMeasurement', temperature=function(v) return ev('temperatureMeasurement','temperature',v.value) end},
  relativeHumidityMeasurement = {ID='relativeHumidityMeasurement', humidity=function(v) return ev('relativeHumidityMeasurement','humidity',v) end}
}
capabilities['buildbook37604.type6communication'] = {
 ID='buildbook37604.type6communication',
 linkState=function(v) return ev('buildbook37604.type6communication','linkState',v) end,
 minutesWithoutRx=function(v) return ev('buildbook37604.type6communication','minutesWithoutRx',v) end,
 lastReceived=function(v) return ev('buildbook37604.type6communication','lastReceived',v) end,
 timeoutMinutes=function(v) return ev('buildbook37604.type6communication','timeoutMinutes',v) end
}
capabilities['buildbook37604.driverInformation'] = {
 ID='buildbook37604.driverInformation',
 author=function(v) return ev('buildbook37604.driverInformation','author',v) end,
 driverVersion=function(v) return ev('buildbook37604.driverInformation','driverVersion',v) end
}
local function cluster(id, attrs)
 local a={}
 for n,code in pairs(attrs) do
  a[n]={ID=code,read=function(self,dev) return 'read:' .. id .. ':' .. code end,
    write=function(self,dev,val) return 'write:' .. id .. ':' .. code end}
 end
 return {ID=id,attributes=a}
end
local clusters = {
 TemperatureMeasurement=cluster(0x0402,{MeasuredValue=0}),
 RelativeHumidity=cluster(0x0405,{MeasuredValue=0}),
 IlluminanceMeasurement=cluster(0x0400,{MeasuredValue=0}),
 PowerConfiguration=cluster(0x0001,{BatteryPercentageRemaining=0x0021}),
 OccupancySensing=cluster(0x0406,{Occupancy=0x0000}),
 IASZone=cluster(0x0500,{IASCIEAddress=0x0010,ZoneStatus=0x0002})
}
local log_buffer={}
local logger=setmetatable({}, {__index=function(_, level)
 return function(msg) table.insert(log_buffer, level .. ':' .. tostring(msg)) end
end})
package.preload['st.capabilities']=function() return capabilities end
package.preload['st.zigbee']=function()
 return function(name,tpl)
   captured = tpl
   return {run=function() end}
 end
end
package.preload['st.zigbee.defaults']=function() return {register_for_default_handlers=function() end} end
package.preload['st.zigbee.zcl.clusters']=function() return clusters end
package.preload['st.zigbee.device_management']=function()
 return {build_bind_request=function() return 'bind' end} end
package.preload['st.zigbee.data_types']=function()
 return {IeeeAddress=function(v) return v end,Uint8=function(v) return v end} end
package.preload['log']=function() return logger end
local query_count=0
package.preload['tuya_utils']=function() return {
 TYPE_VALUE='value',TYPE_BOOL='bool',TYPE_ENUM='enum',
 u32=function(n)return n end,u8=function(n)return n end,
 send=function() end,query_all=function() query_count=query_count+1 end}
end
assert(loadfile(root .. '/src/init.lua'))()
assert(captured, 'Zigbee Driver template must initialize')
local function fake_device(model,manuf,pref)
 local d={model=model, manuf=manuf, preferences=pref or {}, fields={}, latest={}, events={}, timers={}, sent={}, profile=nil}
 function d:get_model() return self.model end
 function d:get_manufacturer() return self.manuf end
 function d:get_field(k) if self.fields[k] == nil then return end; return self.fields[k] end
 function d:set_field(k,v,opts) self.fields[k]=v end
 function d:emit_event(e)
   assert(e and e.capability and e.attribute, 'valid event required')
   self.latest[e.capability .. '.' .. e.attribute] = e.value
   self.events[#self.events + 1] = e
 end
 function d:get_latest_state(c, cap, attr) return self.latest[cap .. '.' .. attr] end
 function d:try_update_metadata(metadata) self.profile=metadata.profile end
 function d:send(req) self.sent[#self.sent + 1]=req end
 function d:get_short_address() return 123 end
 function d:get_endpoint() return 1 end
 d.thread={}
 function d.thread:call_with_delay(sec,fn,name) return {delay=sec,func=fn} end
 function d.thread:call_on_schedule(interval,fn,name)
   local timer={interval=interval,func=fn,name=name,active=true}
   d.timers[#d.timers+1]=timer;return timer
 end
 function d.thread:cancel_timer(timer)timer.active=false end
 function d:tick()for _,t in ipairs(self.timers) do if t.active then t.func() end end end
 return d
end
local function assert_eq(a,b,why)
 if a~=b then error((why or 'mismatch') .. ' expected=' .. tostring(b) .. ' got=' .. tostring(a)) end
end
local hub={environment_info={hub_zigbee_eui='EUI'}}
local mk_type6 = function(p)return fake_device('TS0601','_TZE200_ka8l86iu',p)end
-- TYPE6 watchdog baseline, startup without packets and normal sensing.
local d=mk_type6({type6CommTimeout=60,type6ClearOnTimeout='ON'})
captured.lifecycle_handlers.init(hub,d)
assert_eq(d.profile,'cp-tuya-presence-type6-v128','profile')
assert_eq(d:get_field('type6.health.link_state'),nil,'initial status')
assert_eq(d:get_latest_state('main','buildbook37604.type6communication','linkState'),'checking','initial link status')
assert_eq(d:get_latest_state('main','buildbook37604.driverInformation','author'),'치즈가루','TYPE6 author isolated')
assert_eq(d:get_field('type6.health.monitor_started'),epoch,'monitor baseline')
assert_eq(#d.timers,1,'one periodic timer')
assert_eq(d:get_latest_state('main','buildbook37604.driverInformation','driverVersion'),'v1.3.1','driver version')
-- Profile switching may be asynchronous. Suppress new custom-capability
-- events until SmartThings reports the new TYPE6 profile as applied.
local pending = mk_type6({type6CommTimeout=60})
pending.supports_capability_by_id = function() return false end
captured.lifecycle_handlers.init(hub,pending)
assert_eq(pending:get_latest_state('main','buildbook37604.type6communication','linkState'),nil,'not yet supported')
pending.supports_capability_by_id = function() return true end
pending:tick()
assert_eq(pending:get_latest_state('main','buildbook37604.type6communication','linkState'),'checking','publish after profile applied')
-- Real Edge devices can lack all persisted TYPE6 health fields. Ensure
-- driverSwitched and infoChanged run without nil conversion errors too.
local switched=mk_type6({type6CommTimeout=60,type6ClearOnTimeout='ON',
  type6Indicator='ON',type6AntiInterference='ON'})
captured.lifecycle_handlers.driverSwitched(hub,switched)
assert_eq(switched.profile,'cp-tuya-presence-type6-v128','switched TYPE6 profile unchanged')
assert_eq(switched:get_field('type6.health.monitor_started'),epoch,'switch starts health clock')
local sw_old={type6Indicator='ON',type6AntiInterference='ON'}
captured.lifecycle_handlers.infoChanged(hub,switched,nil,{old_st_store={preferences=sw_old}})
assert_eq(switched:get_field('type6.health.monitor_started'),epoch,'infoChanged keeps clock')
local timers=0 for _,t in ipairs(switched.timers) do if t.active then timers=timers+1 end end
assert_eq(timers,1,'driver switch does not duplicate timers')
-- Absent optional persisted timestamp and probe fields must also be tolerated.
local no_rx=mk_type6({type6CommTimeout=15,type6ClearOnTimeout='OFF'})
captured.lifecycle_handlers.added(hub,no_rx)
assert_eq(no_rx:get_field('type6.health.monitor_started'),epoch,'added starts health clock')
no_rx.fields['type6.health.monitor_started']=nil
no_rx.fields['type6.health.last_rx_saved']=nil
no_rx.fields['type6.health.last_rx']=nil
no_rx:tick()
assert_eq(no_rx:get_field('type6.health.monitor_started'),epoch,'missing clock reinitializes')

local rxdp1=function(dev,val)
 local bytes=string.char(0,1,1,4,0,1,val)
 captured.zigbee_handlers.cluster[0xEF00][0x02](hub,dev,{body={zcl_body={body_bytes=bytes}}})
end
rxdp1(d,1)
assert_eq(d:get_latest_state('main','presenceSensor','presence'),'present','presence detected')
assert_eq(d:get_latest_state('main','motionSensor','motion'),'active','motion mirrors')
assert_eq(d:get_field('type6.health.link_state'),'ok','link recovered')
assert_eq(d:get_field('type6.health.last_rx'),epoch,'RX stored')
-- Expect low rate query only at half timeout after no packet.
epoch=epoch+29*60; d:tick()
assert_eq(query_count,0,'no early queries')
epoch=epoch+60;d:tick();assert_eq(query_count,1,'probes after silence')
epoch=epoch+15*60;d:tick();assert_eq(query_count,2,'spaced query')
epoch=epoch+14*60;d:tick();assert_eq(d:get_field('type6.health.link_state'),'ok','under 60min: still ok')
epoch=epoch+60;d:tick()
assert_eq(d:get_field('type6.health.link_state'),'suspect','timeout status')
assert_eq(d:get_latest_state('main','presenceSensor','presence'),'not present','clear stale presence')
assert_eq(d:get_latest_state('main','motionSensor','motion'),'inactive','clear stale motion')
local n=#d.events
d:tick();assert_eq(#d.events,n,'no repeated events for same status')
assert_eq(d:get_latest_state('main','buildbook37604.type6communication','linkState'),'suspect','suspicion available to API')
assert_eq(d:get_latest_state('main','buildbook37604.driverInformation','author'),'치즈가루','author never includes health')
assert_eq(d:get_latest_state('main','buildbook37604.type6communication','minutesWithoutRx'),60,'silence counter 60 min')
-- A real incoming packet restores normal link; outgoing probes do not.
rxdp1(d,1)
assert_eq(d:get_field('type6.health.link_state'),'ok','real RX recovers')
assert_eq(d:get_latest_state('main','buildbook37604.type6communication','linkState'),'normal','API link state recovers')
assert_eq(d:get_latest_state('main','presenceSensor','presence'),'present','presence recovers')
-- Standard battery cluster also counts as real RX, with standard 0.5% units.
epoch=epoch+10
captured.zigbee_handlers.attr[0x0001][0x0021](hub,d,{value=182},nil)
assert_eq(d:get_latest_state('main','battery','battery'),91,'standard battery conversion')
assert_eq(d:get_field('type6.health.last_rx'),epoch,'battery RX recorded')
-- Timer restart must not leak duplicate schedule tasks.
captured.lifecycle_handlers.init(hub,d)
local live=0 for _,t in ipairs(d.timers) do if t.active then live=live+1 end end
assert_eq(live,1,'watchdog timer count after reinit')
-- Explicit OFF preference must preserve sensor state while still raising suspicion.
local d2=mk_type6({type6CommTimeout=15,type6ClearOnTimeout='OFF'})
captured.lifecycle_handlers.init(hub,d2)
rxdp1(d2,1)
epoch=epoch+15*60;d2:tick()
assert_eq(d2:get_field('type6.health.link_state'),'suspect','suspect despite OFF')
assert_eq(d2:get_latest_state('main','presenceSensor','presence'),'present','OFF means do not reset presence')
-- Legacy variant continues using original profile and no monitoring timers.
local old=fake_device('ZG-204ZX','HOBEIAN')
captured.lifecycle_handlers.init(hub,old)
assert_eq(old.profile,'cp-tuya-presence-v122','legacy profile unchanged')
assert_eq(#old.timers,0,'legacy has no watchdog')
local old_dp1=string.char(0,1,1,4,0,1,1)
captured.zigbee_handlers.cluster[0xEF00][0x02](hub,old,{body={zcl_body={body_bytes=old_dp1}}})
assert_eq(old:get_latest_state('main','presenceSensor','presence'),'present','legacy DP handler still handles presence')
assert_eq(old:get_latest_state('main','buildbook37604.driverInformation','driverVersion'),'v1.3.1','legacy info version')
assert(old:get_latest_state('main','buildbook37604.driverInformation','author')=='치즈가루','legacy author stays unchanged')
-- Removal cleans timer.
captured.lifecycle_handlers.removed(hub,d2)
local live2=0 for _,t in ipairs(d2.timers) do if t.active then live2=live2+1 end end
assert_eq(live2,0,'timer canceled after removal')
print('PASS: TYPE6 init/added/driverSwitched/infoChanged with missing fields, monitor/probe/timeout/recovery/battery, legacy isolation')
