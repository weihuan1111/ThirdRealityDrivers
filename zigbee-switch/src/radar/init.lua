local device_management = require "st.zigbee.device_management"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
local OccupancySensing = zcl_clusters.OccupancySensing

local function occupancy_attr_handler(driver, device, occupancy, zb_rx)
  device:emit_event(
      occupancy.value == 1 and capabilities.motionSensor.motion.active() or capabilities.motionSensor.motion.inactive())
end

local added_handler = function(self, device)
    device:send(OccupancySensing.attributes.Occupancy:read(device))
end

local thirdreality_device_handler = {
    NAME = "ThirdReality Presence Color Night Light",
    lifecycle_handlers = {
        added = added_handler
    },
    zigbee_handlers = {
        attr = {
            [OccupancySensing.ID] = {
                [OccupancySensing.attributes.Occupancy.ID] = occupancy_attr_handler
            }
        }
    },
    can_handle = function(opts, driver, device, ...)
      return device:get_manufacturer() == "Third Reality, Inc" and device:get_model() == "3RPL01084Z"
    end
}

return thirdreality_device_handler
