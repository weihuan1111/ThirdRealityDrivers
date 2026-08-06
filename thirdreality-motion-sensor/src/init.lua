local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"

local sensitivityLevel = capabilities["appleheart46609.pirSensitivity"]

local zigbee_motion_driver = {
  supported_capabilities = {
    capabilities.motionSensor,
    capabilities.battery,
    capabilities.illuminanceMeasurement,
    capabilities.tamperAlert,
    sensitivityLevel,
  },
  sub_drivers = {
    require("thirdreality-motion-gen2"),
  }
}

defaults.register_for_default_handlers(zigbee_motion_driver, zigbee_motion_driver.supported_capabilities)
local driver = ZigbeeDriver("thirdreality-motion-sensor", zigbee_motion_driver)
driver:run()
