
-- use 203 for a2, currently using 77 for throttle
local monitoring_channel = 99
local monitoring_channel_threshold = 200
local reset_channel = 99
local reset_press_count = 0
local laps = {}
local last_rec_time = 0
local day_best_time = 100000
local min_lap_time_seconds = 200

local function init_func()
  local switch_value = 0
  local prev_value = 0
  
end

local function to_formatted_number(inp)
  local retVal = tostring(inp)
  if inp < 10 then
    retVal = "0" .. retVal
  end

  return retVal
end

local function format_time(inp)
  --local inp = 623
  local totalseconds = math.floor(inp/100)
  local totalminutes = math.floor(totalseconds/60)
  local curSeconds = math.floor(totalseconds%60)
  local totalMs = inp%100
  
  return to_formatted_number(totalminutes) .. ":" .. to_formatted_number(curSeconds) .. "." .. to_formatted_number(totalMs)
end

local function format_time2(inp)
  --local inp = 623
  local totalseconds = math.floor(inp/100)
  local totalminutes = math.floor(totalseconds/60)
  local curSeconds = math.floor(totalseconds%60)
  return to_formatted_number(totalminutes) .. ":" .. to_formatted_number(curSeconds)
end

local function drawRssi()
  local rssi = getValue(200)
  lcd.drawText(115, 2,"rssi " .. rssi, SMLSIZE)

  -- Tx Voltage
  local txVolts = getValue(189)

  if txVolts < 1 then
    txVolts = 7.2
  end

  --lcd.drawText(2, 2,"Tx", SMLSIZE)
  lcd.drawText(22, 2, txVolts .. "v", SMLSIZE)
  txVolts = txVolts - 6.5
  txVolts = txVolts * 10
  lcd.drawGauge(2, 2, 16, 6, txVolts, 20)
  lcd.drawLine(2, 10, 155, 10, SOLID, 0)
end


local function drawBattery()
  local batt = getValue(216)
  --batt = 11.1
  local battRemaining = 1
  local cellVolt = 0
  if batt > 12.7 then
    -- 4s
    cellVolt = batt/4
  else 
    --3s
    cellVolt = batt/3
  end

  if cellVolt > 3.5 then
    battRemaining = (cellVolt-3.5)*10
  else
    battRemaining = 0
  end

  lcd.drawText(64,52, tostring(batt) .. "v",SMLSIZE)
  lcd.drawGauge(2,50, 60, 10, battRemaining,7)
end

local function drawDayBest()
if day_best_time < 100000 then
  lcd.drawText(92,25,"best " .. format_time(day_best_time),0)
end
end

local function has_reached_threshold()

  local thr = getValue(77)
  if thr < -900 then 
    return false
  end

-- Check S2 (80) min lap time limit
local s2_val = getValue(80)
s2_val = s2_val + 1224
min_lap_time_seconds = s2_val
lcd.drawText(115,55,math.floor(s2_val/100) .. "s", SMLSIZE)

  -- Check which input to read ( read value from SA - 92)
  local input_signal_switch = getValue(92)
  if input_signal_switch > 0 then
    monitoring_channel = 203 -- a2
    monitoring_channel_threshold = 4.5
    lcd.drawText(95,55,"a2", SMLSIZE)
    local signal_val = getValue(monitoring_channel)
    lcd.drawText(80,2, signal_val .. "v", SMLSIZE)
    local rssi = getValue(200)
    return signal_val < monitoring_channel_threshold and rssi > 35
  else
    monitoring_channel = 99
    monitoring_channel_threshold = 200
    lcd.drawText(95,55,"sh", SMLSIZE)
    local signal_val = getValue(monitoring_channel)
    return signal_val > monitoring_channel_threshold
  end
end

local function run_func()
  lcd.lock()
  lcd.clear()

  local reset = getValue(reset_channel)

  --lcd.drawText(1,1,reset,0)

  if reset > 100 then

        -- clear laps and all
    reset_press_count = reset_press_count+1

    if reset_press_count > 300 then
      day_best_time = 100000
      lcd.drawText(60,20,"Best time reset",MIDSIZE)
      return 0
    end
    
    if reset_press_count > 150 then
      laps = {}
      last_rec_time = 0
      lcd.drawText(60,20,"Reset Done",MIDSIZE)
      lcd.drawText(30,35,"keep holding to reset best time",0)
      lcd.drawGauge(60,46, 80, 15, reset_press_count-150,150)
      return 0
    end

    -- draw some ui
    if reset_press_count > 75 then
      lcd.drawText(100,20,"Reset",MIDSIZE)
      lcd.drawGauge(80,42, 80, 15, reset_press_count-75,75)
      return 0
    end

  else
    reset_press_count = 0
  end


  switch_value = getValue(monitoring_channel)

  local cur_time = getTime()

  local diff = cur_time - last_rec_time

    -- draw current time
    if #laps > 0 then
      -- Current lap time
      lcd.drawText(120,12,format_time(diff),0)
      lcd.drawText(80,12,"curr >",0)

      -- Total Time
      local totalTime = cur_time - laps[1]
      lcd.drawText(2,30, "Total " .. format_time2(totalTime),MIDSIZE)
      --lcd.drawText(10,20,"total",0)
    end

  if has_reached_threshold() then
-- ensure atleast min_lap_time_seconds have lapsed since last capture
    if diff > min_lap_time_seconds then
      -- This is a lap, now add to lap time
      laps[#laps+1] = cur_time
      last_rec_time = cur_time

      -- since lap is recorded, play the time
      if #laps > 1 then
        local lastLapTime = laps[#laps]- laps[#laps-1]
        playNumber(lastLapTime/100, 17, 0)
      end
    end
  end

  if #laps > 0 then
    lcd.drawText(2,12,"laps " .. #laps-1,MIDSIZE)
  end

  --lcd.drawRectangle(155,0,80,65)
  lcd.drawLine(155, 0, 155, 65, SOLID, 0)

  local minLap = 1000000
  local i = #laps
  local il = 2
  local bestLap = -1

  while i > 1 do
    if il > 55 then break end
    local lapLength = laps[i]-laps[i-1]
    lcd.drawText(165,il,format_time(lapLength),0)
    
    if lapLength < minLap then 
      minLap = lapLength
      bestLap = il
    end

    if lapLength < day_best_time then
      day_best_time = lapLength
    end

    il = il+10
    i = i-1
  end

  -- draw best lap indicator
  if bestLap > 0 then
    lcd.drawText(158,bestLap,"#",0)
  end

  drawBattery()

  drawDayBest()

  drawRssi()

  return 0
end
return { run=run_func, init=init_func }
