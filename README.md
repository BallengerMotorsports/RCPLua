# RCPLua
Lua scripts for the RaceCapturePro

## RCR-to-SmartyCam.lua
This script transmits data from the RaceCapture Pro to the AiM SmartyCam

# Notes & References

https://wiki.autosportlabs.com/AIM_SmartyCam_CAN

```lua
--format is: [CAN Id] = function(data) map_chan(<channel id>, data, <CAN offset>, <CAN length>, <multiplier>, <adder>)
CAN_map = {
[1056] = function(data) map_chan(rpmId, data, 0, 2, 1, 0) map_chan(gearId, data, 4, 2, 1, 0) map_chan_le(tempId, data, 6, 2, 0.1, 0) end,
[1057] = function(data) map_chan(temp1Id, data, 0, 2, 0.1, 0) map_chan(temp2Id, data, 2, 2, 0.1, 0) map_chan(oilTempId, data, 4, 2, 0.1, 0) map_chan_le(oilPresId, data, 6, 2, 0.01, 0) end,
[1058] = function(data) map_chan(ch3Id, data, 0, 2, 0.01, 0) map_chan(tpsId, data, 2, 2, 1, 0) map_chan(ch1Id, data, 4, 2, 1, 0) map_chan(ch2Id, data, 6, 2, 1, 0) end
,
[1059] = function(data) map_chan(ch4Id, data, 0, 2, 1, 0) map_chan(ch5Id, data, 2, 2, 0.01, 0) end,
[1060] = function(data) map_chan(fuellevelId, data, 0, 2, 1, 0) map_chan(fuelPresId, data, 2, 2, 0.1, 0) end
}
```

https://wiki.autosportlabs.com/CAN_Bus_database

Channel | Units | CAN Id | Offset (bytes) | Length (bytes) | Multiplier | Adder | Notes
--- | --- | --- | --- | --- | --- | --- | --- 
RPM | RPM | 1056 | 0 | 2 | 1 | 0 | 
EngineTemp | C | 1056 | 6 | 2 | 0.1 | 0 | 
OilTemp | C | 1057 | 4 | 2 | 0.1 | 0 | 
OilPress | Bar | 1057 | 6 | 2 | 0.01 | 0 | 
TPS | % | 1058 | 2 | 1 | 1 | 0 | 
Fuel | L | 1070 | 0 | 1 | 1 | 0

