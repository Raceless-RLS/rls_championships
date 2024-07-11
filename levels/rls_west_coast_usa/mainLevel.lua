-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local M = {}

M.dependencies = {'career_career', 'career_modules_insurance', 'career_saveSystem'}

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
local currCheckpoint = nil
local mHotlap = nil
local mAltRoute = nil
local leaderboardFile = 'career/leaderboard.json'
local leaderboard = {}
local splitTimes = {}

-- Function to check if career mode is active
local function isCareerModeActive()
    return career_career.isActive()
end

-- Function to read the leaderboard from the file
local function loadLeaderboard()
    local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
    local file = savePath .. '/' .. leaderboardFile
    local file = io.open(file, "r")
    if file then
        local content = file:read("*a")
        leaderboard = jsonDecode(content) or {}
        file:close()
    else
        leaderboard = {} -- Initialize as empty if file does not exist
    end
end

-- Function to save the leaderboard to the file in all autosave folders
local function saveLeaderboard()
    local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
    print("saveSlot: " .. saveSlot)
    print("savePath: " .. savePath)
    
    -- Extract the base path by removing the current autosave folder
    local basePath = savePath:match("(.*/)")
    
    -- Define the paths for all three autosave folders
    local autosavePaths = {
        basePath .. "autosave1/" .. leaderboardFile,
        basePath .. "autosave2/" .. leaderboardFile,
        basePath .. "autosave3/" .. leaderboardFile
    }
    
    -- Save the leaderboard to each autosave folder
    for _, filePath in ipairs(autosavePaths) do
        local file = io.open(filePath, "w")
        if file then
            file:write(jsonEncode(leaderboard))
            file:close()
            print("Saved leaderboard to: " .. filePath)
        else
            print("Error: Unable to open leaderboard file for writing: " .. filePath)
        end
    end
end

local function formatTime(seconds)
    local sign = seconds < 0 and "-" or ""
    seconds = math.abs(seconds)
    
    local minutes = math.floor(seconds / 60)
    local remainingSeconds = seconds % 60
    local wholeSeconds = math.floor(remainingSeconds)
    local hundredths = math.floor((remainingSeconds - wholeSeconds) * 100)
    
    return string.format("%s%02d:%02d:%02d", sign, minutes, wholeSeconds, hundredths)
end

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
        bestTime = 9,
        reward = 2000,
        label = "Mud Track"
    },
    drag = {
        bestTime = 11,
        reward = 1500,
        label = "Drag Strip",
        displaySpeed = true
    },
    rockcrawls = {
        bestTime = 60,
        reward = 10000,
        label = "Left Rock Crawl"
    },
    rockcrawlm = {
        bestTime = 80,
        reward = 12500,
        label = "Middle Rock Crawl"
    },
    rockcrawll = {
        bestTime = 75,
        reward = 15000,
        label = "Right Rock Crawl"
    },
    hillclimbl = {
        bestTime = 20,
        reward = 7500,
        label = "Left Hill Climb"
    },
    hillclimbm = {
        bestTime = 15,
        reward = 5000,
        label = "Middle Hill Climb"
    },
    hillclimbr = {
        bestTime = 15,
        reward = 2500,
        label = "Right Hill Climb"
    },
    bnyHill = {
        bestTime = 30,
        reward = 3000,
        label = "Bunny Hill Climb"
    },
    track = {
        bestTime = 140,
        reward = 3000,
        label = "Track",
        checkpoints = 18,
        hotlap = 125,
        altRoute = {
            bestTime = 110,
            reward = 2000,
            label = "Short Track",
            checkpoints = 14,
            hotlap = 95,
            altCheckpoints = {0, 1, 2, 3, 4, 5, 6, 7, 12, 13, 14, 15, 16, 17},
            altInfo = "Continue Left for Standard Track\nHair Pin Right for Short Track"
        }
    },
    dirtCircuit = {
        bestTime = 65,
        reward = 2000,
        checkpoints = 10,
        hotlap = 55,
        label = "Dirt Circuit"
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

local function getActivityType(data)
    -- This helper function extracts the activity type from the trigger's data.
    -- It expects the triggerName to follow the format "raceName_type".
    -- If the extracted activity type is not found, it returns nil.
    --
    -- Parameters:
    --   data (table): The data containing the triggerName.
    --
    -- Returns:
    --   string: The activity type if found, otherwise nil.
    local activityType = data.triggerName:match("_[^_]+$")
    if activityType then
        activityType = activityType:sub(2) -- Remove the leading underscore
    end
    return activityType
end

local function isNewBestTime(raceName, in_race_time, isHotlap, isAltRoute)
    if not leaderboard[raceName] then
        return true
    end

    local currentBest
    if isAltRoute then
        if isHotlap then
            currentBest = leaderboard[raceName].altRoute and leaderboard[raceName].altRoute.hotlapTime
        else
            currentBest = leaderboard[raceName].altRoute and leaderboard[raceName].altRoute.bestTime
        end
    else
        if isHotlap then
            currentBest = leaderboard[raceName].hotlapTime
        else
            currentBest = leaderboard[raceName].bestTime
        end
    end

    return not currentBest or in_race_time < currentBest
end

local function getOldTime(raceName, isHotlap, isAltRoute)
    if not leaderboard[raceName] then
        return nil
    end

    if isAltRoute then
        if not leaderboard[raceName].altRoute then
            return nil
        end
        return isHotlap and leaderboard[raceName].altRoute.hotlapTime or leaderboard[raceName].altRoute.bestTime
    else
        return isHotlap and leaderboard[raceName].hotlapTime or leaderboard[raceName].bestTime
    end
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
    if be:getPlayerVehicleID(0) ~= data.subjectID then
        return
    end
    if mActiveRace == nil then
        return 0
    end
    local raceName = getActivityName(data)
    if not isCareerModeActive() then
        local message = string.format("%s\nTime: %s", races[raceName].label, formatTime(in_race_time))
        displayMessage(message, 10)
        return 0
    end
    if data.event == "enter" and raceName == mActiveRace then
        mActiveRace = nil
        local label = races[raceName].label .. " Event reward"
        local time = races[raceName].bestTime
        local reward = races[raceName].reward
        if mHotlap == raceName then
            time = races[raceName].hotlap
        end
        if mAltRoute then
            time = races[raceName].altRoute.bestTime
            reward = races[raceName].altRoute.reward
            if mHotlap == raceName then
                time = races[raceName].altRoute.hotlap
            end
        end
        local reward = raceReward(time, reward)
        if reward <= 0 then
            return 0
        end
        -- Save the best time to the leaderboard
        loadLeaderboard()
        local newBestTime = isNewBestTime(raceName, in_race_time, mHotlap == raceName, mAltRoute)
        if newBestTime then
            if not leaderboard[raceName] then
                leaderboard[raceName] = {}
            end
            if mAltRoute then
                if not leaderboard[raceName].altRoute then
                    leaderboard[raceName].altRoute = {}
                end

                if mHotlap == raceName then
                    leaderboard[raceName].altRoute.hotlapTime = in_race_time
                    leaderboard[raceName].altRoute.hotlapTimesplitTimes = splitTimes
                else
                    leaderboard[raceName].altRoute.bestTime = in_race_time
                    leaderboard[raceName].altRoute.splitTimes = splitTimes
                end
            else
                if mHotlap == raceName then
                    leaderboard[raceName].hotlapTime = in_race_time
                    leaderboard[raceName].hotlapTimesplitTimes = splitTimes
                else
                    leaderboard[raceName].bestTime = in_race_time   
                    leaderboard[raceName].splitTimes = splitTimes
                end
            end
        else 
            print("No new best time for" .. raceName)
            reward = reward / 2
        end
        career_modules_payment.pay({
            money = {
                amount = -reward
            }
        }, {
            label = label
        })
        local oldTime = getOldTime(raceName, mHotlap == raceName, mAltRoute) or in_race_time
        local newBestTimeMessage = newBestTime and "Congratulations! New Best Time!\n" or ""
        local raceLabel = races[raceName].label
        if mAltRoute then
            raceLabel = raceLabel .. " (Alternative Route)"
        end
        if mHotlap == raceName then
            raceLabel = raceLabel .. " (Hotlap)"
        end
        local timeMessage = string.format("New Time: %s\nOld Time: %s", formatTime(in_race_time), formatTime(oldTime))
        local rewardMessage = string.format("Reward: $%.2f", reward)
        if races[raceName].hotlap then
            local hotlapMessage = string.format("Hotlap Started\n", races[raceName].hotlap)
            if mAltRoute then
                hotlapMessage = hotlapMessage .. string.format("Target: %s", formatTime(races[raceName].altRoute.hotlap))
            end
        end
        
        local message = newBestTimeMessage .. raceLabel .. "\n" .. timeMessage .. "\n" .. rewardMessage
        if races[raceName].displaySpeed then
            local speedMessage = string.format("Speed: %.2f Mph", math.abs(be:getObjectVelocityXYZ(data.subjectID) * speedUnit))
            message = message .. "\n" .. speedMessage
        end
        displayMessage(message, 10)
        print("leaderboard:")
        printTable(leaderboard)
        saveLeaderboard()
        career_saveSystem.saveCurrent()
        return reward
    end
end

local function getOldSplitTime(raceName, currentCheckpointIndex, isHotlap, isAltRoute, in_race_time)
    if not leaderboard[raceName] then
        return in_race_time
    end

    local splitTimes
    if isAltRoute then
        if isHotlap then
            splitTimes = leaderboard[raceName].altRoute and leaderboard[raceName].altRoute.hotlapSplitTimes
        else
            splitTimes = leaderboard[raceName].altRoute and leaderboard[raceName].altRoute.splitTimes
        end
    else
        if isHotlap then
            splitTimes = leaderboard[raceName].hotlapSplitTimes
        else
            splitTimes = leaderboard[raceName].splitTimes
        end
    end

    if not splitTimes or not splitTimes[currentCheckpointIndex + 1] then
        return in_race_time
    end

    return splitTimes[currentCheckpointIndex + 1]
end

local function checkpoint(data)
    if data.event == "exit" then
        return
    end
    printTable(data)
    local raceName = getActivityName(data)
    local activityType = getActivityType(data)
    local check = tonumber(activityType:match("%d+")) or 0
    local alt = activityType:match("alt") and true or false
    print(check, alt)
    
    if mActiveRace == raceName then
        if currCheckpoint == nil then
            if check == 0 then
                currCheckpoint = -1
                if alt then
                    mAltRoute = true
                else
                    mAltRoute = false
                end
            else 
                local message = string.format("Checkpoint %d/%d reached\nTime: %s\nYou must complete this race in the designated order.",
                    check, races[raceName].checkpoints, formatTime(in_race_time))
                displayMessage(message, 10)
            end
            print(currCheckpoint)
        end
        
        local nextCheckpoint
        local totalCheckpoints
        local currentCheckpointIndex

        if mAltRoute then
            local altCheckpoints = races[raceName].altRoute.altCheckpoints
            totalCheckpoints = #altCheckpoints
            -- Find the current index in the altCheckpoints array
            for i, cp in ipairs(altCheckpoints) do
                if cp == currCheckpoint then
                    currentCheckpointIndex = i
                    break
                end
            end
            -- If currentCheckpointIndex is nil, set it to 0 (start of the altCheckpoints array)
            currentCheckpointIndex = currentCheckpointIndex or 0
            nextCheckpoint = altCheckpoints[currentCheckpointIndex + 1]
        else
            totalCheckpoints = races[raceName].checkpoints
            currentCheckpointIndex = currCheckpoint + 1
            nextCheckpoint = currentCheckpointIndex
        end
        
        if check == nextCheckpoint then
            currCheckpoint = check
            splitTimes[currentCheckpointIndex + 1] = in_race_time
            local oldsplit = getOldSplitTime(raceName, currentCheckpointIndex, mHotlap == raceName, mAltRoute)
            local message = string.format("Checkpoint %d/%d reached\nTime: %s\n%s",
            currentCheckpointIndex + 1, totalCheckpoints, formatTime(in_race_time), formatTime((oldsplit and in_race_time - oldsplit) or 0))
            displayMessage(message, 7)
        else
            local missedCheckpoints
            if mAltRoute then
                local altCheckpoints = races[raceName].altRoute.altCheckpoints
                local expectedIndex = nil
                for i, cp in ipairs(altCheckpoints) do
                    if cp == nextCheckpoint then
                        expectedIndex = i
                        break
                    end
                end
                local actualIndex = nil
                for i, cp in ipairs(altCheckpoints) do
                    if cp == check then
                        actualIndex = i
                        break
                    end
                end
                missedCheckpoints = actualIndex and expectedIndex and (actualIndex - expectedIndex) or 0
            else
                missedCheckpoints = check - nextCheckpoint
            end
            
            if missedCheckpoints > 0 then
                local message = string.format(
                    "You missed %d checkpoint(s). Turn around and go back to checkpoint %d.", missedCheckpoints,
                    nextCheckpoint)
                displayMessage(message, 10)
            end
        end
    else
        return
    end
end

local function exitCheckpoint(data)
    if be:getPlayerVehicleID(0) ~= data.subjectID then
        return
    end
    if data.event == "exit" and mActiveRace then
        mActiveRace = nil
        timerActive = false
        mAltRoute = nil
        mHotlap = nil
        currCheckpoint = nil
        splitTimes = {}
        displayMessage("You exited the race zone, Race cancelled", 3)
    end
end

local function routeInfo(data)
    if be:getPlayerVehicleID(0) ~= data.subjectID then
        return
    end
    local raceName = getActivityName(data)
    if races[raceName].altRoute and mActiveRace == raceName then
        displayMessage(races[raceName].altRoute.altInfo, 10)
    end
end

local function manageZone(data)
    -- This function manages the race zone using a BeamNgTrigger.
    -- The trigger should cover the entire race as a bounding box.
    -- The trigger must be named in the format of "raceName_identifier".
    --
    -- Parameters:
    --   data (table): The data containing the event information.
    if be:getPlayerVehicleID(0) ~= data.subjectID then
        return
    end
    local raceName = getActivityName(data)
    if data.event == "exit" then
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
    if be:getPlayerVehicleID(0) ~= data.subjectID then
        return
    end
    local raceName = getActivityName(data)
    local Greenlight = scenetree.findObject(raceName .. '_Green')
    local Yellowlight = scenetree.findObject(raceName .. '_Yellow')
    if currCheckpoint then
        if currCheckpoint + 1 == races[raceName].checkpoints then
            timerActive = false
            local reward = payoutRace(data)
            currCheckpoint = nil
            splitTimes = {}
            mActiveRace = raceName
            in_race_time = 0
            timerActive = true
            if races[raceName].hotlap then
                mHotlap = raceName
            end
            return
        end
    end

    if data.event == "enter" and staged == raceName then
        timerActive = true
        in_race_time = 0
        mActiveRace = raceName
        displayMessage(races[raceName].label .. " Timer Started, GO! ", 2)
        if Greenlight then
            Greenlight:setHidden(false)
        end
        if Yellowlight then
            Yellowlight:setHidden(true)
        end
    end
end

local function displayStagedMessage(race, times)
    local message = string.format(
        "Staged for %s.\nYour Best Time: %s\nTarget Time: %s\nPotential Reward: $%.2f",
        race.label,
        formatTime(times.bestTime or 0),
        formatTime(race.bestTime or 0),
        race.reward or 0
    )
    
    if race.hotlap then
        message = message .. string.format("\nHotlap: Your Best: %s | Target: %s | Reward: $%.2f",
            formatTime(times.hotlapTime or 0),
            formatTime(race.hotlap or 0),
            race.reward or 0
        )
    end

    if race.altRoute then
        message = message .. "\n\nAlternative Route:"
        if times.altRoute then
            message = message .. string.format(" Your Best: %s", formatTime(times.altRoute.bestTime or 0))
        end
        message = message .. string.format(" | Target: %s | Reward: $%.2f",
            formatTime(race.altRoute.bestTime or 0),
            race.altRoute.reward or 0
        )
        
        if race.altRoute.hotlap then
            message = message .. string.format("\nAlt Route Hotlap: Your Best: %s | Target: %s | Reward: $%.2f",
                formatTime((times.altRoute and times.altRoute.hotlapTime) or 0),
                formatTime(race.altRoute.hotlap or 0),
                race.altRoute.reward or 0
            )
        end
    end

    message = message .. "\n\n**Note: All rewards are cut by 50% if they are below your best time.**"
    displayMessage(message, 10)
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
    if be:getPlayerVehicleID(0) ~= data.subjectID then
        return
    end
    local raceName = getActivityName(data)
    local yellowLight = scenetree.findObject(raceName .. '_Yellow')
    
    if data.event == "enter" then
        if math.abs(be:getObjectVelocityXYZ(data.subjectID)) * speedUnit > 5 then
            local message = "You are too fast to stage.\n" .. "Please back up and slow down to stage."
            displayMessage(message, 2)
            staged = nil
            return
        end
        loadLeaderboard()
        print("After load Leaderboard:")
        printTable(leaderboard)
        staged = raceName
        local race = races[raceName]
        if not leaderboard[raceName] then
            leaderboard[raceName] = {}
        end
        displayStagedMessage(race, leaderboard[raceName])
        
        if yellowLight then
            yellowLight:setHidden(false)
        end
    elseif data.event == "exit" then
        staged = nil
        if yellowLight then
            yellowLight:setHidden(true)
        end
    end
end

-- Finishline
local function Finishline(data)
    -- This function handles the finish line trigger using a BeamNgTrigger.
    -- The trigger should be after the finish line.
    -- The trigger must be named in the fsormat of "raceName_identifier".
    --
    -- Parameters:
    --   data (table): The data containing the event information.
    if be:getPlayerVehicleID(0) ~= data.subjectID then
        return
    end
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
M.checkpoint = checkpoint
M.loadLeaderboard = loadLeaderboard
M.saveLeaderboard = saveLeaderboard
M.isCareerModeActive = isCareerModeActive
M.exitCheckpoint = exitCheckpoint
M.routeInfo = routeInfo

return M
