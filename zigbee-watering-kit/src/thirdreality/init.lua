local clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
local IASZone = clusters.IASZone
local ZONE_STATUS_ATTR = IASZone.attributes.ZoneStatus

local cluster_base = require "st.zigbee.cluster_base"
local data_types = require "st.zigbee.data_types"
local FrameCtrl = require "st.zigbee.zcl.frame_ctrl"

local THIRDREALITY_WATERING_CLUSTER = 0xFFF2
local WATERING_TIME = 0x0000
local WATERING_INTERVAL = 0x0001
local W_TIME = "watering-time"
local W_INTERVAL = "watering-interval"
local CENTRALITE_MFG = 0x1407


local function device_added(driver, device)
    device:emit_event(capabilities.hardwareFault.hardwareFault.clear())
    device:emit_component_event(device.profile.components[W_TIME], capabilities.fanSpeed.fanSpeed(0))
    device:emit_component_event(device.profile.components[W_INTERVAL], capabilities.fanSpeed.fanSpeed(0))
end

local generate_event_from_zone_status = function(driver, device, zone_status, zb_rx)
    local event
    if zone_status:is_alarm1_set() then
      event = capabilities.hardwareFault.hardwareFault.detected()
    else
      event = capabilities.hardwareFault.hardwareFault.clear()
    end
    if event ~= nil then
      device:emit_event(event)
    end
end

local ias_zone_status_attr_handler = function(driver, device, zone_status, zb_rx)
    generate_event_from_zone_status(driver, device, zone_status, zb_rx)
end

local ias_zone_status_change_handler = function(driver, device, zb_rx)
    generate_event_from_zone_status(driver, device, zb_rx.body.zcl_body.zone_status, zb_rx)
end

local function custom_write_attribute(device, cluster, attribute, data_type, value, mfg_code)
    local data = data_types.validate_or_build_type(value, data_type)
    local message = cluster_base.write_attribute(device, data_types.ClusterId(cluster), attribute, data)
    if mfg_code ~= nil then
      message.body.zcl_header.frame_ctrl:set_mfg_specific()
      message.body.zcl_header.mfg_code = data_types.validate_or_build_type(mfg_code, data_types.Uint16, "mfg_code")
    else
      message.body.zcl_header.frame_ctrl = FrameCtrl(0x10)
    end
    return message
end

local function custom_read_attribute(device, attribute, mfg_code)
    local message = cluster_base.read_attribute(device, data_types.ClusterId(THIRDREALITY_WATERING_CLUSTER), attribute)
    if mfg_code ~= nil then
      message.body.zcl_header.frame_ctrl:set_mfg_specific()
      message.body.zcl_header.mfg_code = data_types.validate_or_build_type(mfg_code, data_types.Uint16, "mfg_code")
    end
    return message
end


local function set_watering_time(device, speed)
    local watering_time = speed
    device:send(custom_write_attribute(device, THIRDREALITY_WATERING_CLUSTER, WATERING_TIME,
          data_types.Uint16, watering_time, nil))
end

local function set_watering_interval(device, interval)
    device:send(custom_write_attribute(device, THIRDREALITY_WATERING_CLUSTER, WATERING_INTERVAL,
          data_types.Uint8, interval, nil))
end

local function fan_speed_handler(driver, device, command)
    if command.component == W_TIME then
        set_watering_time(device, command.args.speed)
    elseif command.component == W_INTERVAL then
        set_watering_interval(device, command.args.speed)
    end
end

local function watering_attribute_handler(driver, device, zb_rx)
    local attr_record = zb_rx.body.zcl_body.attr_records[1]
    local attr_id = attr_record.attr_id
    local value

    if attr_record.data_type.value == data_types.Uint16.ID then
        value = attr_record.data.value
    elseif attr_record.data_type.value == data_types.Uint8.ID then
        value = attr_record.data.value
    end

    if attr_id == WATERING_TIME then
        device:emit_component_event(device.profile.components[W_TIME], capabilities.fanSpeed.fanSpeed(value))
    elseif attr_id == WATERING_INTERVAL then
        device:emit_component_event(device.profile.components[W_INTERVAL], capabilities.fanSpeed.fanSpeed(value))
    end
end

local thirdreality_device_handler = {
    NAME = "ThirdReality Smart Watering Kit",
    zigbee_handlers = {
        attr = {
            [IASZone.ID] = {
                [ZONE_STATUS_ATTR.ID] = ias_zone_status_attr_handler
            },
            [THIRDREALITY_WATERING_CLUSTER] = {
                [WATERING_TIME] = watering_attribute_handler,
                [WATERING_INTERVAL] = watering_attribute_handler
            }
        },
        cluster = {
            [IASZone.ID] = {
              [IASZone.client.commands.ZoneStatusChangeNotification.ID] = ias_zone_status_change_handler
            }
        }
    },
    capability_handlers = {
        [capabilities.fanSpeed.ID] = {
          [capabilities.fanSpeed.commands.setFanSpeed.NAME] = fan_speed_handler
        }
    },
    lifecycle_handlers = {
        added = device_added
    },
    can_handle = function(opts, driver, device, ...)
      return device:get_manufacturer() == "Third Reality, Inc" and device:get_model() == "3RWK0148Z"
    end
}

return thirdreality_device_handler
