-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

M.dependencies = {'career_career', 'career_modules_insurance', 'career_modules_playerAttributes'}

local starmudtrack = false
local in_race_time = 0



local function payMe(data)
  if data.event == "enter" then
    local label = "Because i figured out the trigger"
    career_modules_payment.pay({ money = { amount = -10000}}, {
        label = label
    })
    local money = career_modules_playerAttributes.getAttribute("money")
    ui_message("Money: " .. money.value, 10)
  end
end

local function displayMessage(message, duration)
  ui_message(message, duration)
end

--green light trigger
local function Greenlight(data)
  if data.event == "enter" then
      --displayMessage("go!", 10)
      --scenetree.findObject('startlight1'):setHidden(false)
      --scenetree.findObject('startlight2'):setHidden(false)
      --scenetree.findObject('startlight3'):setHidden(false)
      --scenetree.findObject('waitlight'):setHidden(false)
      starmudtrack = true
      displayMessage("Off Road Track: Timer Started, GO! " ,10)
  end
end


--yellow light trigger
local function Yellowlight1 (data)
if data.event == "enter" then--turns on yellow light
  --scenetree.findObject('readylight1'):setHidden(false)
  --scenetree.findObject('startlight'):setHidden(true)
  --displayMessage(" Staged, go when ready. " ,10)
 end
-- if data.event == "enter" then--turns off green light
  
-- end
if data.event == "exit" then--turns off yellow light
  --scenetree.findObject('readylight1'):setHidden(true)
  end
end

--yellow light trigger
local function Yellowlight2 (data)
  if data.event == "enter" then--turns on yellow light
    --scenetree.findObject('readylight2'):setHidden(false)
    --scenetree.findObject('startlight'):setHidden(true)
    --displayMessage(" Staged, go when ready. " ,10)
   end
 -- if data.event == "enter" then--turns off green light
    
  -- end
  if data.event == "exit" then--turns off yellow light
    --scenetree.findObject('readylight2'):setHidden(true)
    end
end

--yellow light trigger
local function Yellowlight3 (data)
  if data.event == "enter" then--turns on yellow light
    --scenetree.findObject('readylight3'):setHidden(false)
    --scenetree.findObject('startlight'):setHidden(true)
    displayMessage(" Off Road Track: Staged, go when ready. " ,10)
   end
 -- if data.event == "enter" then--turns off green light
    
  -- end
  if data.event == "exit" then--turns off yellow light
    --scenetree.findObject('readylight3'):setHidden(true)
    end
end


--reset stage
local function resetstage (data)
if data.event == "enter" then
  --scenetree.findObject('startlight1'):setHidden(true)
  --scenetree.findObject('startlight2'):setHidden(true)
  --scenetree.findObject('startlight3'):setHidden(true)
  --scenetree.findObject('waitlight'):setHidden(true)
  --scenetree.findObject('readylight1'):setHidden(true)
  --scenetree.findObject('readylight2'):setHidden(true)
  --scenetree.findObject('readylight3'):setHidden(true)
 starmudtrack = false
  end
end

--Finishline
local function Finishline(data) 
  if data.event == "enter" then
      --scenetree.findObject('startlight1'):setHidden(true)
      --scenetree.findObject('startlight2'):setHidden(true)
     -- scenetree.findObject('startlight3'):setHidden(true)
     -- scenetree.findObject('waitlight'):setHidden(true)
     -- scenetree.findObject('readylight1'):setHidden(true)
      --scenetree.findObject('readylight2'):setHidden(true)
      --scenetree.findObject('readylight3'):setHidden(true)
      displayMessage("Off Road Track: Time: " .. string.format("%.2f", in_race_time),10)
  end
end

local function onUpdate(dtReal, dtSim, dtRaw)
  -- Race time calculation
  if starmudtrack == true then
    in_race_time = in_race_time + dtSim
else
    in_race_time = 0
end
end

--x=playertime y=ideal =z reward

M.displayMessage = displayMessage
M.Finishline = Finishline
M.resetstage = resetstage
M.Greenlight = Greenlight
M.Yellowlight1 = Yellowlight1
M.Yellowlight2 = Yellowlight2
M.Yellowlight3 = Yellowlight3
M.onUpdate = onUpdate

M.payMe = payMe

return M