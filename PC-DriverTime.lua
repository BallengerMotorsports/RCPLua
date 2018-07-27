----------------------------------------------------------------------------------
-- Podium Connect Uptime Counter
-- River City Racing AKA Not Banned Yet
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
-- Setup variables
----------------------------------------------------------------------------------
tick_rate = 1               -- Increment/transmity frequency in Hz
timeout = 20                -- Timeout to wait for transmit in milliseconds
can_bus_selection = 0       -- 0 or 1 for Bus 1, Bus 2
can_bus_bitrate = 500000    -- Define bus rate at 500kbps 
power_on_time = 0           -- How long we've been on
power_on_message_id = 1792  -- define the message as 0x700 (1792 decimal)
ext = 0                     -- flag if CAN ID is standard or extended (0=11 bit, 1=29 bit extended)
debugging_verbosity = 3     -- 0 = off, 1 = fails, 2 = send sucess, 3 = packet data, 4 = fully verbose

----------------------------------------------------------------------------------
-- Setup Code
----------------------------------------------------------------------------------
initCAN(can_bus_selection, can_bus_bitrate)     -- Initialize CAN
setTickRate(tick_rate)                          -- Specify the onTick callback frequency

-- addChannel( name, sampleRate, [precision], [min], [max], [units] )
addChannel("DriverTime", 1, 0, 0, 250, "min")   -- create a custom channel for time since powered on in minutes


----------------------------------------------------------------------------------
-- 1Hz tick callback function 
----------------------------------------------------------------------------------
function onTick()
    -- update how long we've been on
    power_on_time = power_on_time + 1

    -- update the channel we have created
    setChannel("DriverTime", math.floor(power_on_time / 60))

    -- calculate the high and low bytes of the power on time
    power_on_high_byte = math.floor(power_on_time / 256)
    power_on_low_byte = power_on_time % 256

    -- build a message
    data_1792 = {power_on_low_byte, power_on_high_byte, 0, 0, 0, 0, 0, 0}

    -- send the CAN message
    send_CAN_message(can_bus_selection, power_on_message_id, ext, data_1792,  timeout)
end

----------------------------------------------------------------------------------
-- debug message
----------------------------------------------------------------------------------
function debug_message(debug_message_level, debug_msg)
    if(debugging_verbosity >= debug_message_level) then println(debug_msg) end
end

----------------------------------------------------------------------------------
-- generic CAN transmission with debug_message logging built in
----------------------------------------------------------------------------------
function send_CAN_message(can_channel, message_id, extended_frame, message_data, transmit_timeout)
    -- Dump packet and correct values to be integers (noticed we were feeding decimals into routine prior)
    debug_message(3, ("Begin message data. Chan =" .. can_channel .. ", ID = " .. message_id))
    for key,value in pairs(message_data) do
        message_data[key] = math.floor(value)
        debug_message(3, (key .. ":" .. message_data[key]))
    end
    debug_message(3, ("End message data."))

    response = txCAN(can_channel, message_id, extended_frame, message_data, transmit_timeout)
    if response ~= 1 then
        debug_message(1, ("Bus " .. can_channel .. " ID " .. message_id .. " [" .. power_on_time .. "]: Transmission failed. response =" .. response))
    else
        debug_message(2, ("Bus " .. can_channel .. " ID " .. message_id .. " [" .. power_on_time .. "]: Sent"))
    end
end
