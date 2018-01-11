----------------------------------------------------------------------------------
-- RCP Uptime Counter, Surge Fuel Filter
-- River City Racing AKA Not Banned Yet
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
-- Setup variables
----------------------------------------------------------------------------------
tick_rate = 1               -- Increment/transmity frequency in Hz
timeout = 20                -- Timeout to wait for transmit in milliseconds
can_bus_selection = 1       -- 0 or 1 for Bus 1, Bus 2
can_bus_bitrate = 500000    -- Define bus rate at 500kbps 
power_on_time = 0           -- How long we've been on
power_on_message_id = 1792  -- define the message as 0x700 (1792 decimal)
ext = 0                     -- flag if CAN ID is standard or extended (0=11 bit, 1=29 bit extended)
debugging_verbosity = 3     -- 0 = off, 1 = fails, 2 = send sucess, 3 = packet data, 4 = fully verbose
filter_address = 0x710      -- hex address for message with fuel data from MXG analog in 3
filter_bit_mask = 0x7FF     -- 0x7FF = 111 1111 1111 (full 11 bit accessible)
fuel_samples = {}           -- where we store fuel samples
fuel_sample_count = 30      -- number of sample to store
fuel_sample_pointer = 0     -- current index of where to store a sample
fuel_msg_offset = 7         -- according to the documentation RCP claims to index the data array off 1 as the first entry instead of 0 like every other array ever made.


----------------------------------------------------------------------------------
-- Setup Code
----------------------------------------------------------------------------------
-- Specify the onTick callback frequency
setTickRate(tick_rate)                          

-- addChannel( name, sampleRate, [precision], [min], [max], [units] )
addChannel("DriverTime", 1, 0, 0, 250, "min")   -- create a custom channel for time since powered on in minutes
addChannel("SrgFuelFilt", 1, 0, 0, 100, "%")   -- create a custom channel for filtered surge fuel level

-- Initialize CAN
initCAN(can_bus_selection, can_bus_bitrate)     

-- Only look for the message containing surge fuel while scripting
-- setCANfilter(channel, filterId, extended, filter, mask )
setCANfilter(can_bus_selection, 0, ext, 0x710, 0x7FF)

-- default samples to full
for fuel_sample_pointer = 0, (fuel_sample_count - 1)
    fuel_samples[fuel_sample_pointer] = 100
end
fuel_sample_pointer = 0 -- reset pointer to 0 when done storing values

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


    -- look for a CAN message with the CAN ID we need
    id, ext, data = rxCAN(can_bus_selection, 100) --100ms timeout
    if id == filter_address then
        if fuel_sample_pointer >= fuel_sample_count then
            fuel_sample_pointer = 0
        end
        -- according to the documentation RCP claims to index the data array off 1 
        -- as the first entry instead of 0 like every other array ever made.
        fuel_samples[fuel_sample_pointer] = (data[fuel_msg_offset] + (data[fuel_msg_offset + 1] * 256)) / 100

        fuel_sample_pointer = fuel_sample_pointer + 1
    end

    -- calculate surge fuel average
    surge_fuel_total = 0
    for i = 0, (fuel_sample_count - 1)
        surge_fuel_total = surge_fuel_total + fuel_samples[i]
    end
    surge_fuel_average = surge_fuel_total / fuel_sample_count
    -- set bounds as 0 and 100
    if(surge_fuel_average > 100) surge_fuel_average = 100
    if(surge_fuel_average < 0) surge_fuel_average = 0
    setChannel("SrgFuelFilt", math.floor(surge_fuel_average))


    -- build a message
    data_1792 = {power_on_low_byte, power_on_high_byte, surge_fuel_average, 0, 0, 0, 0, 0}

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
