----------------------------------------------------------------------------------
-- RCP Uptime Counter, Surge Fuel Filter
-- River City Racing AKA Not Banned Yet
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
debugging_verbosity = 4     -- 0 = off, 1 = fails, 2 = send success/warnings, 3 = packet data/notices, 4 = fully verbose

-- standard fuel collections

filter_address = 0x710      -- hex address for message with fuel data from MXG analog in 3
filter_bit_mask = 0x7FF     -- 0x7FF = 111 1111 1111 (full 11 bit accessible)
surge_fuel_samples = {}           -- where we store surge fuel samples
main_fuel_samples = {}           -- where we store main fuel samples
fuel_total_sample_count = 30      -- number of sample to store
fuel_sample_pointer = 0     -- current index of where to store a sample
main_fuel_msg_offset = 5
surge_fuel_msg_offset = 7   -- according to the documentation RCP claims to index the data array off 1 as the first entry instead of 0 like every other array ever made.


-- placeholders for IMU data
imu_x = 0
imu_y = 0 
imu_z = 0
imu_gsum = 0

-- gsum filtered fuel calculations
surge_fuel_gsum_samples = {}
main_fuel_gsum_samples = {}
fuel_gsum_stability_ceiling = 0.35
fuel_gsum_sequential_stability_floor = 3
fuel_gsum_total_sample_count = 8
fuel_gsum_sample_pointer = 0
fuel_gsum_stable_count = 0
fuel_gsum_count_offset = {}


----------------------------------------------------------------------------------
-- Setup Code
----------------------------------------------------------------------------------
-- Specify the onTick callback frequency
setTickRate(tick_rate)                          

-- addChannel( name, sampleRate, [precision], [min], [max], [units] )
chan_dt = addChannel("DriverTime",    1, 0, 0, 250, "min")   -- create a custom channel for time since powered on in minutes
chan_fa = addChannel("SrgFuelFilt",   1, 0, 0, 100, "%")     -- create a custom channel for filtered surge fuel level
chan_fg = addChannel("SrgFulFltGS",   1, 0, 0, 100, "%")     -- create a custom channel for gsum filtered surge fuel level
chan_ma = addChannel("MnFuelFilt",    1, 0, 0, 100, "%")     -- create a custom channel for filtered main fuel level
chan_mg = addChannel("MnFulFltGS",    1, 0, 0, 100, "%")     -- create a custom channel for gsum filtered main fuel level
chan_ch = addChannel("GSUMChnLen",    1, 0, 0, 100, "#")
-- Initialize CAN
initCAN(can_bus_selection, can_bus_bitrate)     

-- Only look for the message containing surge fuel while scripting
-- setCANfilter(channel, filterId, extended, filter, mask )
setCANfilter(can_bus_selection, 0, ext, 0x710, 0x7FF)

-- default samples to full
for fuel_sample_pointer = 0, (fuel_total_sample_count - 1) do
    surge_fuel_samples[fuel_sample_pointer] = 100
    main_fuel_samples[fuel_sample_pointer] = 100
end
fuel_sample_pointer = 0 -- reset pointer to 0 when done storing values

-- default gsum samples to full

for fuel_gsum_sample_pointer = 0, (fuel_gsum_total_sample_count - 1) do
    surge_fuel_gsum_samples[fuel_gsum_sample_pointer] = 100
    main_fuel_gsum_samples[fuel_gsum_sample_pointer] = 100
end
fuel_gsum_sample_pointer = 0 -- reset pointer to 0 when done storing values


----------------------------------------------------------------------------------
-- 1Hz tick callback function 
----------------------------------------------------------------------------------
function onTick()
    -- update how long we've been on
    power_on_time = power_on_time + 1

    -- update the channel we have created
    setChannel(chan_dt, math.floor(power_on_time / 60))

    -- calculate the high and low bytes of the power on time
    power_on_high_byte = math.floor(power_on_time / 256)
    power_on_low_byte = power_on_time % 256


    -- look for a CAN message with the CAN ID we need
    id, ext_rx, data = rxCAN(can_bus_selection, 100) --100ms timeout
    if id == filter_address then
        if fuel_sample_pointer >= fuel_total_sample_count then
            fuel_sample_pointer = 0
        end
        -- according to the documentation RCP claims to index the data array off 1 
        -- as the first entry instead of 0 like every other array ever made.
        new_fuel_value = (data[main_fuel_msg_offset] + (data[main_fuel_msg_offset + 1] * 256)) / 100
        main_fuel_samples[fuel_sample_pointer] = new_fuel_value

        new_fuel_value = (data[surge_fuel_msg_offset] + (data[surge_fuel_msg_offset + 1] * 256)) / 100
        surge_fuel_samples[fuel_sample_pointer] = new_fuel_value

        -- sample IMU for gsum calculation data
        imu_x = math.abs(getImu(0))  -- read the x accel value
        imu_y = math.abs(getImu(1))  -- read the y accel value
        imu_z = 0 -- math.abs(getImu(2)) -- can optionally include the Z axis in the gsum calculation (set to 0 to remove)

        -- calculate gsum
        imu_gsum = math.sqrt(imu_x * imu_x + imu_y * imu_y + imu_z * imu_z)

        if(imu_gsum < fuel_gsum_stability_ceiling) then
            -- if we are stable increment the stable counter
            fuel_gsum_stable_count = fuel_gsum_stable_count + 1
            if(fuel_gsum_stable_count > 255) then
                fuel_gsum_stable_count = 255
            end

            setChannel(chan_ch, fuel_gsum_stable_count)
            -- chan_ch
            -- if we are stable passed the threshold value store a filtered value
            if(fuel_gsum_stable_count > fuel_gsum_sequential_stability_floor) then
                -- store our latest reading
                main_fuel_gsum_samples[fuel_gsum_sample_pointer] = main_fuel_samples[fuel_sample_pointer]
                surge_fuel_gsum_samples[fuel_gsum_sample_pointer] = surge_fuel_samples[fuel_sample_pointer]

                -- increment our gsum storage pointer or reset it to 0 if necessary
                fuel_gsum_sample_pointer = fuel_gsum_sample_pointer + 1
                if(fuel_gsum_sample_pointer >= fuel_gsum_total_sample_count) then
                    fuel_gsum_sample_pointer = 0
                end
            end
        else
            -- if we are NOT stable reset the stable counter
            fuel_gsum_stable_count = 0
        end

        fuel_sample_pointer = fuel_sample_pointer + 1
    end

    -- calculate surge fuel average. reset totals
    main_fuel_total = 0
    surge_fuel_total = 0
    gsum_main_fuel_total = 0
    gsum_surge_fuel_total = 0

    -- calculate sums 
    for i = 0, (fuel_total_sample_count - 1) do
        main_fuel_total = main_fuel_total + main_fuel_samples[i]
        surge_fuel_total = surge_fuel_total + surge_fuel_samples[i]
    end

    for i = 0, (fuel_gsum_total_sample_count - 1) do
        gsum_main_fuel_total = gsum_main_fuel_total + main_fuel_gsum_samples[i]
        gsum_surge_fuel_total = gsum_surge_fuel_total + surge_fuel_gsum_samples[i]
    end

    -- calculate averages
    main_fuel_average = main_fuel_total / fuel_total_sample_count
    gsum_main_fuel_average = gsum_main_fuel_total / fuel_gsum_total_sample_count
    surge_fuel_average = surge_fuel_total / fuel_total_sample_count
    gsum_surge_fuel_average = gsum_surge_fuel_total / fuel_gsum_total_sample_count

    -- limit averages
    surge_fuel_average = limit(surge_fuel_average, 0, 100)
    main_fuel_average = limit(main_fuel_average, 0, 100)
    gsum_surge_fuel_average = limit(gsum_surge_fuel_average, 0, 100)
    gsum_main_fuel_average = limit(gsum_main_fuel_average, 0, 100)

    -- set channel values
    setChannel(chan_fa, math.floor(surge_fuel_average))
    setChannel(chan_fg, math.floor(gsum_surge_fuel_average))
    setChannel(chan_ma, math.floor(main_fuel_average))
    setChannel(chan_mg, math.floor(gsum_main_fuel_average))

    -- build a message
    data_1792 = {power_on_low_byte, power_on_high_byte, surge_fuel_average, gsum_surge_fuel_average, main_fuel_average, gsum_main_fuel_average, fuel_gsum_stable_count, 0}

    -- send the CAN message
    send_CAN_message(can_bus_selection, power_on_message_id, ext, data_1792,  timeout)
end


function limit(val_in, min_val, max_val)
    if val_in < min_val then return min_val end
    if val_in > max_val then return max_val end
    return val_in
end
----------------------------------------------------------------------------------
-- generic CAN transmission function we can repurpose as needed.
----------------------------------------------------------------------------------
function send_CAN_message(can_channel, message_id, extended_frame, message_data, transmit_timeout)
    for key,value in pairs(message_data) do
       message_data[key] = math.floor(value)
    end

    response = txCAN(can_channel, message_id, extended_frame, message_data, transmit_timeout)

end
