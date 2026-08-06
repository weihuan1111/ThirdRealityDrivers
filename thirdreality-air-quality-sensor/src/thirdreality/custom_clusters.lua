local data_types = require "st.zigbee.data_types"

-- ThirdReality 3RAQ1096Z custom Zigbee clusters
-- CO2:  cluster 0x040D, attribute 0x0000 (MeasuredValue), float value = actual ppm / 1000000
-- TVOC: cluster 0x042E, attribute 0x0100 (MeasuredValue), unit ppb (direct value)

local custom_clusters = {
  -- Carbon Dioxide Concentration Measurement (ZCL cluster 0x040D)
  carbonDioxide = {
    id = 0x040D,
    attributes = {
      measured_value = {
        id = 0x0000,
        value_type = data_types.SinglePrecisionFloat,
      }
    }
  },
  -- TVOC Concentration Measurement (ZCL cluster 0x042E)
  tvoc = {
    id = 0x042E,
    attributes = {
      measured_value = {
        id = 0x0100,
        value_type = data_types.SinglePrecisionFloat,
      }
    }
  }
}

return custom_clusters
