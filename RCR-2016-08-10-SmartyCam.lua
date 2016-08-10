-- Functioning CAN messaging from RCP to AiM SmartyCam.
-- TPS, Brake Pressure (PSI), RPM functional in this revision

tick_rate = 150      -- Update frequency in Hz.  Moved from 30Hz to 150Hz while testing message dropouts at SmartyCam
channel = 0          -- CAN channel on the RCP. Either 0 or 1, depending on CAN bus chosen.
ext = 0              -- CAN ID is extended (0=11 bit, 1=29 bit)
timeout = 100        -- Milliseconds to attempt to send CAN message for
bitrate = 1000000    -- CAN bitrate (SmartyCam = 1megabit)

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
    tps_value = getAnalog(0)
    brake_pressure_value = getAnalog(2)
    rpm_value = getTimerRpm(0)

    -- perform conversions
    brake_pressure_value = brake_pressure_value * 0.0689476         -- convert brake pressure to bar
    brake_pressure_value = math.floor(brake_pressure_value * 100)   -- convert 1 = 1 bar to 1 = 0.01 bar


    brake_pressure_high_byte = math.floor(brake_pressure_value / 256)
    brake_pressure_low_byte = brake_pressure_value % 256 -- - (brake_pressure_high_byte * 256)

    rpm_high_byte = math.floor(rpm_value / 256)
    rpm_low_byte = rpm_value % 256

    -- print brake_pressure_high_byte + " " + brake_pressure_low_byte

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
	
	--Log above 10mph, stop logging below 10mph. 
	
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