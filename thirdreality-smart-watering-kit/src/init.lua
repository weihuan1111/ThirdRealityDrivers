-- Copyright 2022 SmartThings
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local battery_defaults = require "st.zigbee.defaults.battery_defaults"
local constants = require "st.zigbee.constants"
local configurationMap = require "configurations"
local TemperatureMeasurement = (require "st.zigbee.zcl.clusters").TemperatureMeasurement

local temperature_measurement_defaults = {
  MIN_TEMP = "MIN_TEMP",
  MAX_TEMP = "MAX_TEMP"
}

local temperature_measurement_min_max_attr_handler = function(minOrMax)
  return function(driver, device, value, zb_rx)
    local raw_temp = value.value
    local celc_temp = raw_temp / 100.0
    local temp_scale = "C"

    device:set_field(string.format("%s", minOrMax), celc_temp)

    local min = device:get_field(temperature_measurement_defaults.MIN_TEMP)
    local max = device:get_field(temperature_measurement_defaults.MAX_TEMP)

    if min ~= nil and max ~= nil then
      if min < max then
        device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.temperatureMeasurement.temperatureRange({ value = { minimum = min, maximum = max }, unit = temp_scale }))
        device:set_field(temperature_measurement_defaults.MIN_TEMP, nil)
        device:set_field(temperature_measurement_defaults.MAX_TEMP, nil)
      else
        device.log.warn_with({hub_logs = true}, string.format("Device reported a min temperature %d that is not lower than the reported max temperature %d", min, max))
      end
    end
  end
end

local function device_init(driver, device)
  local configuration = configurationMap.get_device_configuration(device)

  if configuration then
    for _, config in ipairs(configuration) do
      if config.use_battery_linear_voltage_handling then
        battery_defaults.build_linear_voltage_init(config.minV, config.maxV)(driver, device)
      elseif config.use_battery_voltage_table and config.battery_voltage_table then
        battery_defaults.enable_battery_voltage_table(device, config.battery_voltage_table)
      elseif (config.cluster) then
        device:add_configured_attribute(config)
        device:add_monitored_attribute(config)
      end
    end
  end
end

local function added_handler(self, device)
  device:send(TemperatureMeasurement.attributes.MaxMeasuredValue:read(device))
  device:send(TemperatureMeasurement.attributes.MinMeasuredValue:read(device))
end

local zigbee_water_driver_template = {
  supported_capabilities = {
    capabilities.waterSensor,
    capabilities.switch,
    capabilities.temperatureAlarm,
    capabilities.temperatureMeasurement,
    capabilities.battery,
  },
  zigbee_handlers = {
    attr = {
      [TemperatureMeasurement.ID] = {
        [TemperatureMeasurement.attributes.MinMeasuredValue.ID] = temperature_measurement_min_max_attr_handler(temperature_measurement_defaults.MIN_TEMP),
        [TemperatureMeasurement.attributes.MaxMeasuredValue.ID] = temperature_measurement_min_max_attr_handler(temperature_measurement_defaults.MAX_TEMP),
      }
    }
  },
  lifecycle_handlers = {
    init = device_init,
    added = added_handler
  },
  ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE,
  sub_drivers = {
    require("zigbee-water-freeze"),
    require("thirdreality")
  },
}

defaults.register_for_default_handlers(zigbee_water_driver_template, zigbee_water_driver_template.supported_capabilities)
local zigbee_water_driver = ZigbeeDriver("thirdreality-smart-watering-kit", zigbee_water_driver_template)
zigbee_water_driver:run()
