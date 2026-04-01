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
local clusters = require "st.zigbee.zcl.clusters"

KEEN_PRESSURE_ATTRIBUTE = 0x0000

local AnalogInput = clusters.AnalogInput

local function pressure_report_handler(driver, device, value, zb_rx)
  local kPa = math.floor(value.value / 10)
  device:emit_event(capabilities.atmosphericPressureMeasurement.atmosphericPressure({value = kPa, unit = "kPa"}))
end

local function round(num)
  local mult = 10
  return math.floor(num * mult + 0.5) / mult
end

local function dirty_level_handler(driver, device, value, zb_rx)
  local level_value = value.value
  level_value = round(level_value)
  local level_val = math.tointeger(level_value)
  device:emit_component_event(device.profile.components["dirty-level"], capabilities.level.level(level_val))
end

local added_handler = function(self, device)
  device:send(AnalogInput.attributes.PresentValue:read(device))
end

local do_refresh = function(self, device)
  device:refresh()
  device:send(AnalogInput.attributes.PresentValue:read(device))
end

local zigbee_driver = {
  supported_capabilities = {
    capabilities.battery,
    capabilities.atmosphericPressureMeasurement,
    capabilities.level,
    capabilities.refresh
  },
  lifecycle_handlers = {
    added = added_handler
  },
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh,
    }
  },
  zigbee_handlers = {
    attr = {
      [clusters.PressureMeasurement.ID] = {
        [KEEN_PRESSURE_ATTRIBUTE] = pressure_report_handler
      },
      [AnalogInput.ID] = {
        [AnalogInput.attributes.PresentValue.ID] = dirty_level_handler
      },
    }
  }
}

defaults.register_for_default_handlers(zigbee_driver, zigbee_driver.supported_capabilities)
local driver = ZigbeeDriver("thirdreality-air-pressure-sensor", zigbee_driver)
driver:run()
