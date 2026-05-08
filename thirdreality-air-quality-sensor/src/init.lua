-- Copyright 2025 SmartThings
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

local ZigbeeDriver = require "st.zigbee"
local capabilities = require "st.capabilities"
local defaults = require "st.zigbee.defaults"

local thirdreality_air_quality_template = {
  supported_capabilities = {
    capabilities.temperatureMeasurement,
    capabilities.relativeHumidityMeasurement,
    capabilities.carbonDioxideMeasurement,
    capabilities.tvocMeasurement,
  },
  sub_drivers = { require("thirdreality") }
}

defaults.register_for_default_handlers(thirdreality_air_quality_template, thirdreality_air_quality_template.supported_capabilities)
local driver = ZigbeeDriver("thirdreality-air-quality-sensor", thirdreality_air_quality_template)
driver:run()
