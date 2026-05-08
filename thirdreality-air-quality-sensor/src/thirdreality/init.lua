local clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
local custom_clusters = require "thirdreality/custom_clusters"
local cluster_base = require "st.zigbee.cluster_base"
local data_types = require "st.zigbee.data_types"

local RelativeHumidity = clusters.RelativeHumidity
local TemperatureMeasurement = clusters.TemperatureMeasurement

local THIRDREALITY_CO2_CLUSTER = 0x040D
local THIRDREALITY_TVOC_CLUSTER = 0x042E
local THIRDREALITY_ATTR = 0x0000

-- Map VOC value to air quality health concern
-- 0-100: excellent (good)
-- 100-200: good
-- 200-300: light pollution (moderate)
-- 300-400: medium pollution (slightlyUnhealthy)
-- 400-500: heavy pollution (unhealthy)
local function voc_to_air_quality_health(voc_value)
  if voc_value <= 100 then
    return "good"
  elseif voc_value <= 200 then
    return "moderate"
  elseif voc_value <= 300 then
    return "slightlyUnhealthy"
  elseif voc_value <= 400 then
    return "unhealthy"
  else
    return "veryUnhealthy"
  end
end

local THIRDREALITY_FINGERPRINTS = {
  { mfr = "Third Reality, Inc", model = "3RAQ1096Z" }
}

local function can_handle_thirdreality_sensor(opts, driver, device)
  for _, fingerprint in ipairs(THIRDREALITY_FINGERPRINTS) do
    if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
      return true
    end
  end
  return false
end

local function do_refresh(driver, device)
  device:send(TemperatureMeasurement.attributes.MeasuredValue:read(device))
  device:send(RelativeHumidity.attributes.MeasuredValue:read(device))
  device:send(cluster_base.read_attribute(device, data_types.ClusterId(custom_clusters.carbonDioxide.id), data_types.AttributeId(custom_clusters.carbonDioxide.attributes.measured_value.id)))
  device:send(cluster_base.read_attribute(device, data_types.ClusterId(custom_clusters.tvoc.id), data_types.AttributeId(custom_clusters.tvoc.attributes.measured_value.id)))
end

local function co2_attr_handler(driver, device, value, zb_rx)
  local ppm = value.value * 1000000
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.carbonDioxideMeasurement.carbonDioxide({ value = ppm, unit = "ppm" }))
end

local function tvoc_attr_handler(driver, device, value, zb_rx)
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.tvocMeasurement.tvocLevel({ value = value.value, unit = "ppb" }))
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.airQualityHealthConcern.airQualityHealthConcern({ value = voc_to_air_quality_health(value.value) }))
end

local function added_handler(self, device)
  device:emit_event(capabilities.airQualityHealthConcern.airQualityHealthConcern({ value = voc_to_air_quality_health(0) }))
  do_refresh(self, device)
end

local thirdreality_sensor = {
  NAME = "ThirdReality Air Quality Sensor",
  lifecycle_handlers = {
    added = added_handler
  },
  zigbee_handlers = {
    attr = {
      [THIRDREALITY_CO2_CLUSTER] = {
        [THIRDREALITY_ATTR] = co2_attr_handler
      },
      [THIRDREALITY_TVOC_CLUSTER] = {
        [THIRDREALITY_ATTR] = tvoc_attr_handler
      }
    }
  },
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh
    }
  },
  can_handle = can_handle_thirdreality_sensor
}

return thirdreality_sensor
