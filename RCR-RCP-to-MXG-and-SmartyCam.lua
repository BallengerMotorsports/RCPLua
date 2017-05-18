-- Functioning CAN messaging from RCP to AiM SmartyCam.
-- TPS, Brake Pressure (PSI), RPM functional in this revision
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
-- Message 1056
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
--
-- RPM                      = (High Byte * 256 + Low byte)
-- Engine Temp
-- Gear
-- Engine Temp
--
-- Byte Offsets
--
-- 0 = RPM low byte
-- 1 = RPM high byte
-- 2 = Speed low byte (10ths of KPH)
-- 3 = Speed high byte (10ths of KPH)
-- 4 = Gear low byte
-- 5 = Gear high byte (probably unused)
-- 6 = Engine temp low byte
-- 7 = Engine temp high byte
--
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
-- Message 1058
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
-- Brake Pressure in Bar    =   (High Byte * 256 + Low byte ) / 100
-- TPS                      =   (High Byte * 256 + Low byte )
-- Brake position           =   (High Byte * 256 + Low byte )
-- Cluth position           =   (High Byte * 256 + Low byte )
--
-- Bar to PSI = Bar / 14.504
-- PSI to BAR = PSI * 0.0689476
--
-- Byte Offsets
--
-- 0 = brake pressure low byte
-- 1 = brake pressure high byte
-- 2 = TPS low byte (0% =0, 100% = 100)
-- 3 = TPS high byte (unused)
-- 4 = Brake position low byte
-- 5 = Brake position high byte
-- 6 = Clutch position low byte
-- 7 = Clutch position high byte

debugging_verbosity = 1                   -- 0 = off, 1 = fails, 2 = send sucess, 3 = packet data, 4 = fully verbose

tick_rate           = 200                 -- Update frequency in Hz.  Moved from 30Hz to 150Hz while testing message dropouts at SmartyCam
smartycam_channel   = 0                   -- CAN smartycam_channel on the RCP. Either 0 or 1, depending on CAN bus chosen.
ext                 = 0                   -- CAN ID is extended (0=11 bit, 1=29 bit)
timeout             = 10                  -- Milliseconds to attempt to send CAN message for
bitrate             = 1000000             -- CAN bitrate (SmartyCam=1megabit)
gear_tick_update    = 3                   -- Start at this number and tick down to 0. Upon hitting 0 calculateGear again
gear_tick_count     = 3                   -- Current tick approaching 0
current_gear        = 0                   -- The most recent gear that's been detected
mph_to_kph          = 1.60934             -- Set this to 1 if speed already in kph, set to 1.60934 if in MPH
counter             = 0                   -- CAN message sequence counter

mxg_channel         = 1                   -- MXG CAN channel (0 or 1)
mxg_tick_update     = 10                  -- How many ticks to update MXG data (ie 200hz tick rate, 10 tick count = 20hz)
mxg_tick_count      = mxg_tick_update     -- tick down to 0, once at 0 perform update to the MXG
mxg_bitrate         = 1000000             -- CAN bitrate (SmartyCam = 1megabit)

conv_psi_to_bar     = 0.0689476

-- Init
initCAN(smartycam_channel, bitrate)    -- Initialize CAN
initCAN(mxg_channel, mxg_bitrate)
setTickRate(tick_rate)       -- Specify the onTick callback frequency

function onTick()
    counter = counter + 1

    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    -- Check if we need to update the MXG dash
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    mxg_tick_count = mxg_tick_count - 1
    if (mxg_tick_count <= 0) then
        mxg_tick_count = mxg_tick_update
        update_mxg_dash()
    end

    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    -- Check if we need to sample the gear again
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    gear_tick_count = gear_tick_count - 1
    if (gear_tick_count <= 0) then
        calculateGear()
        current_gear = getChannel("Gear")
        gear_tick_count = gear_tick_update
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    -- sample inputs
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    tps_value                = getAnalog(0)
    brake_pressure_value     = getAnalog(2)
    rpm_value                = getTimerRpm(0)
    speed_value              = getGpsSpeed()

    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    -- override inputs (for testing) comment these out with a --
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    -- set engine to 750 RPM
    -- rpm_value                = 750
    -- set speed to doc brown's specifications
    -- speed_value              = 88

    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    -- perform conversions
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    brake_pressure_value     = brake_pressure_value * 0.0689476         -- convert brake pressure to bar
    brake_pressure_value     = math.floor(brake_pressure_value * 100)   -- convert 1 = 1 bar to 1 = 0.01 bar

    brake_pressure_high_byte = math.floor(brake_pressure_value / 256)
    brake_pressure_low_byte  = brake_pressure_value % 256 

    rpm_high_byte            = math.floor(rpm_value / 256)
    rpm_low_byte             = rpm_value % 256

    speed_tenths_of_kph      = math.floor(speed_value * mph_to_kph * 10)

    speed_high_byte          = math.floor(speed_tenths_of_kph / 256)
    speed_low_byte           = speed_tenths_of_kph % 256

    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    -- override conversions (for testing) comment these out with a --
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    -- speed_low_byte = 255
    -- speed_high_byte = 0

    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    -- Compile message data
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    data_1056 = { rpm_low_byte,            rpm_high_byte,            speed_low_byte, speed_high_byte, current_gear, 0,0,0}
    data_1058 = { brake_pressure_low_byte, brake_pressure_high_byte, tps_value, 0, 0,            0,0,0}

    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    -- Transmit messages
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    send_CAN_message(smartycam_channel, 1056, ext, data_1056, timeout)
    send_CAN_message(smartycam_channel, 1058, ext, data_1058, timeout)

    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    -- Enable Logging - Log above 10mph, stop logging below 10mph.
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    if getGpsSpeed() > 10 then
        startLogging()
    else
        stopLogging()
    end
end

function calculateGear()  -- tick rate on this can be greatly reduced from function onTick, 10hz is adequate
    local gear1 = 3.321
    local gear2 = 1.902
    local gear3 = 1.308
    local gear4 = 1.000
    local gear5 = 0.759
    local finalDrive = 4.083
    local tireDia = 25.03
    local gearErr = 0.1
    local rpmSpeedRatio = 0
    local gearPos = 0

    local speed = getGpsSpeed()
    local rpm = getTimerRpm(0)

    gearId = addChannel("Gear",5,0,0,5)

    if speed > 10 then
        rpmSpeedRatio = (rpm/speed)/(finalDrive*1056/(tireDia*3.14159))

        if ((gear1 - rpmSpeedRatio)^2) < (gearErr^2) then gearPos = 1 end
        if ((gear2 - rpmSpeedRatio)^2) < (gearErr^2) then gearPos = 2 end
        if ((gear3 - rpmSpeedRatio)^2) < (gearErr^2) then gearPos = 3 end
        if ((gear4 - rpmSpeedRatio)^2) < (gearErr^2) then gearPos = 4 end
        if ((gear5 - rpmSpeedRatio)^2) < (gearErr^2) then gearPos = 5 end

    else
        gearPos = 0
    end
    setChannel(gearId, gearPos)
end

function update_mxg_dash()
    
    -- ID CHANNEL NAME SHORT NAME BYTE HIGH BYTE LOW MULT DIV OFFSET SIGN SENSOR LOW RANGE HIGH RANGE
    
    -- Message 5F0 (1520)
    -- 5F0 ECU_RPM RPM 1 0 1 1 0 0 RPM 0 65535
    -- 5F0 ECU_TPS TPS 3 2 1 65 0 0 %x10 0,0 100,8
    -- 5F0 ECU_PPS PPS 5 4 1 65 0 0 %x10 0,0 100,8
    -- 5F0 ECU_VEH_SPD VSDP 7 6 1 10 0 0 km/hx10 0,0 655,3

    -- Message 5F8 (1528)
    -- 5F8 ECU_STEER_POS STAG 1 0 1 3 0 1 DEGx10 -1.092,7 1092,8
    -- 5F8 ECU_STEER_SPD STSP 3 2 1 1 0 1 DEGsX10 -3.276,8 3276,7
    -- 5F8 ECU_BRK_P BRKP 5 4 1 43 0 0 barx10 0,0 152,4
    -- 5F8 ECU_CLUCH_P CLUP 7 6 1 43 0 0 barx10 0,0 152,4

    -- Sample values
    tps_value                = getAnalog(0)
    brake_pressure_value     = getAnalog(2)
    steering_value           = getAnalog(3)
    rpm_value                = getTimerRpm(0)

    -- override values for testing

    -- scaling test values
    -- rpm_value = counter % 7000
    -- tps_value = counter % 100
    -- brake_pressure_value = counter / 5 % 900
    
    -- static test values
    -- rpm_value = 4250
    -- tps_value = 100
    -- brake_pressure_value = 430
    -- steering_value = -170

    -- Dump verbose messages
    debug_message(4, ("MXG TPS Value = " .. tps_value))
    debug_message(4, ("MXG RPM Value = " .. rpm_value))
    debug_message(4, ("MXG Brake Pressure Value = " .. brake_pressure_value))
    debug_message(4, ("MXG Steering Value = " .. steering_value))


    -- calcluate bytes
    -- RPM 0-FF FF = 0 - 65535 (raw)
    rpm_high_byte = math.floor(rpm_value / 256)
    rpm_low_byte = rpm_value % 256

    --  value appears to be 0-65000 = 0-100%
    tps_value = tps_value * 650
    tps_high_byte = math.floor(tps_value / 256)
    tps_low_byte = tps_value % 256 

    -- Brake pressure
    -- convert to bar then tenth of bar then divisor of 43
    brake_pressure_value = brake_pressure_value * conv_psi_to_bar * 10 * 43
    brake_pressure_high_byte = math.floor(brake_pressure_value / 256)
    brake_pressure_low_byte  = brake_pressure_value % 256 

    -- Steering
    -- degrees * 10 with a divisor of 3 and signed
    steering_value = steering_value * 10 * 3
    -- if negative subtract (add the negative) from 65535 (FFFFh - value = signed negative bytes)
    if(steering_value < 0) then
        steering_value = 65535 + steering_value
    end
    steering_high_byte = math.floor(steering_value / 256)
    steering_low_byte  = steering_value % 256 

    -- build messages
    data_1520 = {rpm_low_byte, rpm_high_byte,    tps_low_byte,tps_high_byte,     0,0,    0,0}
    data_1528 = {steering_low_byte,steering_high_byte,     0,0,     brake_pressure_low_byte,brake_pressure_high_byte,    0,0}

    -- transmit messages
    send_CAN_message(mxg_channel, 1520, ext, data_1520, timeout)
    send_CAN_message(mxg_channel, 1528, ext, data_1528, timeout)
end

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
        debug_message(1, ("Bus " .. can_channel .. " ID " .. message_id .. " [" .. counter .. "]: Transmission failed. response =" .. response))
    else
        debug_message(2, ("Bus " .. can_channel .. " ID " .. message_id .. " [" .. counter .. "]: Sent"))
    end
end

function debug_message(debug_message_level, debug_msg)
    if(debugging_verbosity >= debug_message_level) then println(debug_msg) end
end
