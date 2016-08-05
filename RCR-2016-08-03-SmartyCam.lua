-- Functioning CAN messaging from RCP to AiM SmartyCam.
-- TPS, Brake Pressure (PSI), RPM functional in this revision

tick_rate = 30          -- Update frequency in Hz
channel   = 0           -- CAN channel on the RCP. Either 0 or 1.
ext       = 0           -- CAN ID is extended (0=11 bit, 1=29 bit)
timeout   = 100         -- Milliseconds to attempt to send CAN message for
bitrate   = 1000000     -- CAN bitrate (SmartyCam = 1megabit)

-- Init
initCAN(channel, bitrate)    -- Initialize CAN
setTickRate(tick_rate)       -- Specify the onTick callback frequency

function onTick() 
    -- Message 1056
    --
    -- RPM                      = (High Byte * 256 + Low byte)
    -- ??
    -- Gear
    -- Engine Temp
    --

    -- Message 1058
    -- 
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
    
    -- sample inputs
    tps_value            = getAnalog(0)
    brake_pressure_value = getAnalog(2)
    rpm_value            = getTimerRpm(0)

    -- perform conversions
    brake_pressure_value     = brake_pressure_value * 0.0689476         -- convert brake pressure to bar
    brake_pressure_value     = math.floor(brake_pressure_value * 100)   -- convert 1 = 1 bar to 1 = 0.01 bar

    brake_pressure_high_byte = math.floor(brake_pressure_value / 256)
    brake_pressure_low_byte  = brake_pressure_value % 256 

    rpm_high_byte            = math.floor(rpm_value / 256)
    rpm_low_byte             = rpm_value % 256

    data_1056 = { rpm_low_byte, rpm_high_byte, 0,0,0,0,0,0}
    response = txCAN(channel, 1056, ext, data_1056, timeout)
    if response ~= 1 then
        println "ID 1056: Transmission failed"
    end

    data_1058 = { brake_pressure_low_byte, brake_pressure_high_byte, tps_value, 0, 0, 0, 0, 0}
    response = txCAN(channel, 1058, ext, data_1058, timeout)
    if response ~= 1 then
        println "ID 1058: Transmission failed"
    end
end
