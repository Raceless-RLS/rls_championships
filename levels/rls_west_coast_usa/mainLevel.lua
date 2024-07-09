-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local M = {}

M.dependencies = {'career_career', 'career_modules_insurance', 'career_modules_playerAttributes'}

-- This is used to track if the timer is active
local timerActive = false

-- This is used to track the active race
local mActiveRace

-- This is used to track if the race is staged
local staged = nil

-- This is used to track the time in the race
local in_race_time = 0

local speedUnit = 2.2369362920544
local speedThreshold = 5
local checkInterval = 0.1  -- Interval in seconds to check the speed
local cancelLoop = false

-- Simple sleep function using os.clock
local function sleep(seconds)
    local start = os.clock()
    while os.clock() - start < seconds do
        -- Busy-wait loop
    end
end

local function displayMessage(message, duration)
    ui_message(message, duration)
end

local function raceReward(x, y, z)
    -- The raceReward function calculates the reward based on the time taken to complete the race.
    -- If the actual time is greater than the ideal time, the reward (y) is reduced proportionally.
    -- If the actual time is less than or equal to the ideal time, the reward (y) is increased exponentially.
    --
    -- Parameters:
    --   x (number): Ideal time for the race.
    --   y (number): Base reward for the race.
    --   z (number, optional): Actual time taken to complete the race. Defaults to in_race_time.
    --
    -- Returns:
    --   number: Calculated reward based on the time taken.
    z = z or in_race_time
    if z == 0 then
        return 0
    end
    local ratio = x / in_race_time
    if ratio < 1 then
        return math.floor(ratio * y * 100) / 100
    else
        return math.floor((math.pow(ratio, (1 + (y / 500)))) * y * 100) / 100
    end
end

-- This table stores the best time and reward for each race.
-- The best time is the ideal time for the race.
-- The reward is the potential reward for the race.
-- The label is the name of the race.
local races = {
    mudDrag = {
        bestTime = 7,
        reward = 4500,
        label = "Mud Track"
    },
    rockcrawls = {
        bestTime = 25,
        reward = 10000,
        label = "Left Rock Crawl"
    },
    rockcrawlm = {
        bestTime = 35,
        reward = 15000,
        label = "Middle Rock Crawl"
    },
    rockcrawll = {
        bestTime = 45,
        reward = 20000,
        label = "Right Rock Crawl"
    },
    hillclimbl = {
        bestTime = 20,
        reward = 10000,
        label = "Left Hill Climb"
    },
    hillclimbm = {
        bestTime = 15,
        reward = 7500,
        label = "Middle Hill Climb"
    },
    hillclimbr = {
        bestTime = 10,
        reward = 5000,
        label = "Right Hill Climb"
    },
    bnyHill = {
        bestTime = 60,
        reward = 15000,
        label = "Bunny Hill Climb"
    },
    testTrack = {
        bestTime = 5.5,
        reward = 1000,
        label = "Test Track"
    }
}

local function printTable(t, indent)
    -- This function prints all parts of a table with labels.
    -- It recursively prints nested tables with indentation.
    --
    -- Parameters:
    --   t (table): The table to print.
    --   indent (number, optional): The current level of indentation. Defaults to 0.
    indent = indent or 0
    local indentStr = string.rep("  ", indent)

    for k, v in pairs(t) do
        if type(v) == "table" then
            print(indentStr .. tostring(k) .. ":")
            printTable(v, indent + 1)
        else
            print(indentStr .. tostring(k) .. ": " .. tostring(v))
        end
    end
end

local function getActivityName(data)
    -- This helper function extracts the race name from the trigger's data.
    -- It expects the triggerName to follow the format "raceName_type".
    -- If the extracted race name is not found in the 'races' table,
    -- it defaults to "testTrack".
    --
    -- Parameters:
    --   data (table): The data containing the triggerName.
    --
    -- Returns:
    --   string: The race name if found in the 'races' table, otherwise "testTrack".
    local name = data.triggerName:match("([^_]+)")
    if not races[name] then
        name = "testTrack"
    end
    return name
end

local function payoutRace(data)
    -- This function handles the payout for a race.
    -- It calculates the reward based on the race's best time and the actual time taken.
    -- If the reward is greater than 0, it processes the payment and displays a message.
    --
    -- Parameters:
    --   data (table): The data containing the event information.
    --
    -- Returns:
    --   number: The calculated reward for the race.
    if mActiveRace == nil then
        return 0
    end
    local raceName = getActivityName(data)
    if data.event == "enter" and raceName == mActiveRace then
        mActiveRace = nil
        local label = races[raceName].label .. " Event reward"
        local reward = raceReward(races[raceName].bestTime, races[raceName].reward)
        if reward <= 0 then
            return 0
        end
        career_modules_payment.pay({
            money = {
                amount = -reward
            }
        }, {
            label = label
        })
        -- local money = career_modules_playerAttributes.getAttribute("money")
        local message = string.format("%s\nTime: %.2f seconds\nReward: $%.2f", races[raceName].label, in_race_time,
            reward)
        displayMessage(message, 10)
        return reward
    end
end

local function manageZone(data)
    -- This function manages the race zone using a BeamNgTrigger.
    -- The trigger should cover the entire race as a bounding box.
    -- The trigger must be named in the format of "raceName_identifier".
    --
    -- Parameters:
    --   data (table): The data containing the event information.
    local raceName = getActivityName(data)
    if data.event == "enter" then
        if staged == raceName then
            mActiveRace = raceName
            staged = nil
        end
    else
        if mActiveRace == raceName then
            mActiveRace = nil
            timerActive = false
            displayMessage("You exited the race zone, Race cancelled", 2)
        end
    end
end

-- green light trigger
local function Greenlight(data)
    -- This function handles the green light trigger using a BeamNgTrigger.
    -- The trigger should start at the line after the staging section.
    -- The trigger must be named in the format of "raceName_identifier".
    --
    -- Parameters:
    --   data (table): The data containing the event information.
    local raceName = getActivityName(data)
    local Greenlight = scenetree.findObject(raceName .. '_Green')
    local Yellowlight = scenetree.findObject(raceName .. '_Yellow')
    
    if data.event == "enter" and staged == raceName then
        timerActive = true
        in_race_time = 0
        displayMessage(races[raceName].label .. " Timer Started, GO! ", 2)
        if Greenlight then  
            Greenlight:setHidden(false)
        end
        if Yellowlight then
            Yellowlight:setHidden(true)
        end
    end
end

-- yellow light trigger
local function Yellowlight(data)
    -- This function handles the yellow light trigger using a BeamNgTrigger.
    -- The trigger should be before the starting line where people sit and wait for staging.
    -- The trigger must be named in the format of "raceName_identifier".
    --
    -- Parameters:
    --   data (table): The data containing the event information.
    printTable(data)
    local raceName = getActivityName(data)
    local yellowLight = scenetree.findObject(raceName .. '_Yellow')

    if data.event == "enter" then
        staged = raceName
        local race = races[raceName]
        local message = string.format("Staged for %s.\nBest Time: %.2f seconds\nPotential Reward: $%.2f", race.label, race.bestTime, race.reward)
        displayMessage(message, 10)
        if yellowLight then
            yellowLight:setHidden(false)
        end
    elseif data.event == "exit" then
        if yellowLight then
            yellowLight:setHidden(true)
        end
    end
end

-- Finishline
local function Finishline(data)
    -- This function handles the finish line trigger using a BeamNgTrigger.
    -- The trigger should be after the finish line.
    -- The trigger must be named in the format of "raceName_identifier".
    --
    -- Parameters:
    --   data (table): The data containing the event information.
    print(mActiveRace)
    local raceName = getActivityName(data)
    local Greenlight = scenetree.findObject(raceName .. '_Green')
    local Yellowlight = scenetree.findObject(raceName .. '_Yellow')
    if data.event == "enter" and mActiveRace == raceName then
        timerActive = false
        local reward = payoutRace(data)
    else
        if Yellowlight then
            Yellowlight:setHidden(true)
        end
        if Greenlight then
            Greenlight:setHidden(true)
        end
    end
end

local function onUpdate(dtReal, dtSim, dtRaw)
    -- This function updates the race time.
    -- It increments the in_race_time if the timer is active.
    --
    -- Parameters:
    --   dtReal (number): Real delta time.
    --   dtSim (number): Simulated delta time.
    --   dtRaw (number): Raw delta time.
    if timerActive == true then
        in_race_time = in_race_time + dtSim
    else
        in_race_time = 0
    end
end

M.displayMessage = displayMessage
M.Finishline = Finishline
M.Greenlight = Greenlight
M.Yellowlight = Yellowlight

M.onUpdate = onUpdate

M.payoutRace = payoutRace
M.raceReward = raceReward
M.manageZone = manageZone

return M