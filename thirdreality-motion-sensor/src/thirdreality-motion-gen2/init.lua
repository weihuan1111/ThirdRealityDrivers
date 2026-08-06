local capabilities = require "st.capabilities"
local cluster_base = require "st.zigbee.cluster_base"
local data_types = require "st.zigbee.data_types"
local zcl_clusters = require "st.zigbee.zcl.clusters"

local sensitivityLevel = capabilities["appleheart46609.pirSensitivity"]
local IASZone = zcl_clusters.IASZone

local PRIVATE_CLUSTER_ID = 0xFF01
local SENSITIVITY_ATTR_ID = 0x0004
local COOLDOWN_ATTR_ID = 0x0005
local MOTION_LED_ATTR_ID = 0x0006

--- Handle IAS Zone status (motion + tamper)
local function zone_status_handler(driver, device, zone_status, zb_rx)
  if zone_status:is_alarm1_set() then
    device:emit_event(capabilities.motionSensor.motion.active())
  else
    device:emit_event(capabilities.motionSensor.motion.inactive())
  end
  if zone_status:is_tamper_set() then
    device:emit_event(capabilities.tamperAlert.tamper.detected())
  else
    device:emit_event(capabilities.tamperAlert.tamper.clear())
  end
end

local function ias_zone_status_change_handler(driver, device, zb_rx)
  zone_status_handler(driver, device, zb_rx.body.zcl_body.zone_status, zb_rx)
end

--- Handle sensitivity level report from device
local function sensitivity_attr_handler(driver, device, value, zb_rx)
  local level = value.value
  if level >= 1 and level <= 5 then
    device:emit_event(sensitivityLevel.sensitivityLevel(level))
  end
end

--- Handle setSensitivityLevel command from App
local function set_sensitivity_handler(driver, device, command)
  local level = command.args.level
  device:send(cluster_base.write_attribute(device, data_types.ClusterId(PRIVATE_CLUSTER_ID),
    data_types.AttributeId(SENSITIVITY_ATTR_ID), data_types.Uint8(level)))
  device:emit_event(sensitivityLevel.sensitivityLevel(level))
end

--- Handle cooldown time and motion LED preference changes
local function info_changed(driver, device, event, args)
  if args.old_st_store.preferences.cooldownTime ~= device.preferences.cooldownTime then
    local cooldown = device.preferences.cooldownTime or 30
    device:send(cluster_base.write_attribute(device, data_types.ClusterId(PRIVATE_CLUSTER_ID),
      data_types.AttributeId(COOLDOWN_ATTR_ID), data_types.Uint16(cooldown)))
  end
  if args.old_st_store.preferences.motionLED ~= device.preferences.motionLED then
    local led_enabled = device.preferences.motionLED
    if led_enabled == nil then led_enabled = true end
    device:send(cluster_base.write_attribute(device, data_types.ClusterId(PRIVATE_CLUSTER_ID),
      data_types.AttributeId(MOTION_LED_ATTR_ID), data_types.Boolean(led_enabled)))
  end
end

--- Refresh handler
local function do_refresh(driver, device)
  device:refresh()
  device:send(cluster_base.read_attribute(device, data_types.ClusterId(PRIVATE_CLUSTER_ID),
    data_types.AttributeId(SENSITIVITY_ATTR_ID)))
end

--- Read sensitivity level on device added
local function device_added(driver, device)
  device:send(cluster_base.read_attribute(device, data_types.ClusterId(PRIVATE_CLUSTER_ID),
    data_types.AttributeId(SENSITIVITY_ATTR_ID)))
end

local thirdreality_motion_gen2 = {
  NAME = "ThirdReality Smart Motion Sensor Gen2",
  lifecycle_handlers = {
    added = device_added,
    infoChanged = info_changed
  },
  zigbee_handlers = {
    attr = {
      [PRIVATE_CLUSTER_ID] = {
        [SENSITIVITY_ATTR_ID] = sensitivity_attr_handler
      },
      [IASZone.ID] = {
        [IASZone.attributes.ZoneStatus.ID] = zone_status_handler
      }
    },
    cluster = {
      [IASZone.ID] = {
        [IASZone.client.commands.ZoneStatusChangeNotification.ID] = ias_zone_status_change_handler
      }
    }
  },
  capability_handlers = {
    [sensitivityLevel.ID] = {
      [sensitivityLevel.commands.setSensitivityLevel.NAME] = set_sensitivity_handler
    },
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh
    }
  },
  can_handle = function(opts, driver, device, ...)
    return device:get_manufacturer() == "Third Reality, Inc" and device:get_model() == "3RMS26Z"
  end
}

return thirdreality_motion_gen2
