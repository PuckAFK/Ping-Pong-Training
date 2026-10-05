

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local PLACE_ID = 137737622318848
if game.PlaceId ~= PLACE_ID then
    return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local VirtualUser = game:GetService("VirtualUser")

local VirtualInputManager
pcall(function()
    VirtualInputManager = game:GetService("VirtualInputManager")
end)

local LocalPlayer = Players.LocalPlayer

local ExecutorName, ExecutorVersion = "Unknown", ""
do
    local identify = type(identifyexecutor) == "function" and identifyexecutor
        or (type(getexecutorname) == "function" and getexecutorname)
    if identify then
        local ok, a, b = pcall(identify)
        if ok then
            ExecutorName = tostring(a or "Unknown")
            ExecutorVersion = tostring(b or "")
        end
    end
end
local IS_SOLARA = string.find(string.lower(ExecutorName), "solara", 1, true) ~= nil

-- Re-execution cleanup for this game's PuckUI only.
do
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local oldGui = playerGui and playerGui:FindFirstChild("PuckAFK_PPT_UI")
    if oldGui then
        pcall(function() oldGui:Destroy() end)
    end
end

local RemoteFolder = ReplicatedStorage:WaitForChild("Net", 30)
if not RemoteFolder then
    error("Ping Pong Training remotes did not load")
end

-- Resolve remotes straight from ReplicatedStorage.Net. This is intentionally
-- independent from the game's Modules.Net wrapper because lower-compatibility
-- executors can differ in how injected ModuleScript requires are handled.
local Net = {}
local function indexRemote(object)
    if object then
        Net[object.Name] = object
    end
end
for _, object in ipairs(RemoteFolder:GetChildren()) do
    indexRemote(object)
end
RemoteFolder.ChildAdded:Connect(indexRemote)

local Modules = ReplicatedStorage:FindFirstChild("Modules")
local function tryRequireModule(name)
    if not Modules then
        return nil
    end
    local object = Modules:FindFirstChild(name) or Modules:WaitForChild(name, 8)
    if not object then
        return nil
    end
    local ok, result = pcall(require, object)
    if not ok then
        return nil
    end
    return result
end

local ZoneConfig = tryRequireModule("ZoneConfig") or {
    GetByName = function(name) return name and {name = name} or nil end,
    GetHighestUnlocked = function(unlocked)
        return type(unlocked) == "table" and unlocked[#unlocked] or "City"
    end,
    GetNextLocked = function() return nil end,
}
local UpgradeConfig = tryRequireModule("UpgradeConfig") or {
    GetNextCost = function() return nil end,
}
local PaddleConfig = tryRequireModule("PaddleConfig") or {
    StarterPaddle = "Classic",
    OwnedFromProgress = function() return {} end,
    GetEffectiveMult = function() return 1 end,
    GetNextPurchasable = function() return nil end,
    GetPrice = function() return nil end,
}
local EggConfig = tryRequireModule("EggConfig") or {
    GetPriceTable = function() return nil end,
}
local ChallengeConfig = tryRequireModule("ChallengeConfig") or {
    PromptName = "ChallengePrompt",
    ModelName = "Challenge",
    Get = function() return nil end,
}
local WeatherConfig = tryRequireModule("WeatherConfig") or {
    ChargeCap = function() return 100 end,
    Current = function() return nil end,
}

local ENV = (type(getgenv) == "function" and getgenv()) or _G
if ENV.__PUCKAFK_PING_PONG_TRAINING and type(ENV.__PUCKAFK_PING_PONG_TRAINING.Stop) == "function" then
    pcall(ENV.__PUCKAFK_PING_PONG_TRAINING.Stop)
    task.wait(0.15)
end

local Runtime = {
    Alive = true,
    Master = false,
    Busy = false,
    Training = false,
    Serving = false,
    ChallengeActive = false,
    LastChallengeAttempt = 0,
    LastHatch = 0,
    LastFusion = 0,
    LastRewards = 0,
    LastSpend = 0,
    LastWorld = 0,
    LastRebirth = 0,
    LastStatus = "Ready",
    Phase = "Unknown",
    LastPhaseChange = 0,
    LastRebirthPoll = 0,
    LastMaintenanceTick = 0,
    NativeServeStarts = 0,
    NativeServeFailures = 0,
    Connections = {},
    Shots = 0,
    ServeRejects = 0,
    Cycles = 0,
    Hatches = 0,
    Fusions = 0,
    RebirthsDone = 0,
    RebirthSignalSeq = 0,
    LastRebirthSignal = nil,
    ServeRejectStreak = 0,
    Errors = 0,
    ExecutorName = ExecutorName,
    ExecutorVersion = ExecutorVersion,
    IsSolara = IS_SOLARA,
    RaceMode = nil,
    RaceTimeRemaining = nil,
    RaceSyncAt = 0,
    TrainingAutoState = nil,
    TrainingAutoSeq = 0,
    ServerAutoShootEnabled = false,
    DirectServeOnly = IS_SOLARA,
    DirectTrainingFallbacks = 0,
    NativeAutoShootOwned = false,
    NativeAutoShootStartedAt = 0,
    LocalPlayerFiredSeq = 0,
    LastLocalPlayerFiredAt = 0,
    LastNativeInputMethod = "none",
    SolaraInputClicks = 0,
    SolaraInputFailures = 0,
}
ENV.__PUCKAFK_PING_PONG_TRAINING = Runtime

local Settings = {
    SmartAutofarm = false,
    TurboMode = true,
    AutoServe = true,
    ForceDirectServe = false,
    RebirthCheckInterval = 0.65,
    ShotsPerCycle = 1,
    ShotLandingSlack = 0.04,
    ServeReadyDelay = 0.18,
    ServeRecovery = 0.45,
    MaintenanceEvery = 3,
    AutoWorlds = true,
    AutoPaddles = true,
    AutoUpgrades = true,
    UpgradeSpendPercent = 18,
    SaveForWorldAtPercent = 35,
    AutoRebirth = true,
    RebirthReservePercent = 100,
    RebirthWorldReservePercent = 100,
    RebirthChainMax = 4,
    AutoHatch = true,
    HatchInterval = 25,
    HatchSpendPercent = 6,
    AutoEquipBest = true,
    AutoFusion = true,
    FusionInterval = 20,
    AutoChallenge = false,
    ChallengeClicksPerTick = 2,
    AutoRewards = true,
    AutoPotions = true,
    AutoSpins = true,
    AutoCodes = true,
    AntiIdle = true,
}

local function addConnection(connection)
    Runtime.Connections[#Runtime.Connections + 1] = connection
    return connection
end

local function dlog(...)
end

local StatusLabel
local function setStatus(text)
    Runtime.LastStatus = tostring(text or "")
    if StatusLabel and StatusLabel.Set then
        pcall(StatusLabel.Set, StatusLabel, "Status: " .. Runtime.LastStatus)
    end
end

local function safeFire(remote, ...)
    if not remote then
        return false, "missing remote"
    end
    local args = table.pack(...)
    local ok, err = pcall(function()
        remote:FireServer(table.unpack(args, 1, args.n))
    end)
    if not ok then
        Runtime.Errors = Runtime.Errors + 1
        dlog("Fire failed", remote.Name or "?", err)
    end
    return ok, err
end

local function safeInvoke(remote, ...)
    if not remote then
        return false, "missing remote"
    end
    local args = table.pack(...)
    local packed = table.pack(pcall(function()
        return remote:InvokeServer(table.unpack(args, 1, args.n))
    end))
    local ok = packed[1]
    if not ok then
        Runtime.Errors = Runtime.Errors + 1
        dlog("Invoke failed", remote.Name or "?", packed[2])
        return false, packed[2]
    end
    return true, table.unpack(packed, 2, packed.n)
end

-- Compatibility state mirrors. These use ordinary RemoteEvent listeners and
-- therefore do not depend on executor-only signal introspection.
if Net.Race_StateSync and Net.Race_StateSync:IsA("RemoteEvent") then
    addConnection(Net.Race_StateSync.OnClientEvent:Connect(function(payload)
        if type(payload) == "table" then
            Runtime.RaceMode = tostring(payload.mode or Runtime.RaceMode or "")
            Runtime.RaceTimeRemaining = tonumber(payload.timeRemaining)
            Runtime.RaceSyncAt = os.clock()
        end
    end))
end

if Net.Training_AutoState and Net.Training_AutoState:IsA("RemoteEvent") then
    addConnection(Net.Training_AutoState.OnClientEvent:Connect(function(payload)
        if type(payload) == "table" then
            Runtime.TrainingAutoState = payload
            Runtime.TrainingAutoSeq = (Runtime.TrainingAutoSeq or 0) + 1
        end
    end))
end

if Net.Training_Start and Net.Training_Start:IsA("RemoteEvent") then
    addConnection(Net.Training_Start.OnClientEvent:Connect(function()
        Runtime.Training = true
        pcall(function() LocalPlayer:SetAttribute("IsTrainMode", true) end)
    end))
end

-- Server-confirmed local firing signal. This is the most reliable way to know
-- that Solara actually activated the game's own FiringClient. It avoids relying
-- on private/local flags that can differ between executor environments.
if Net.PlayerFired and Net.PlayerFired:IsA("RemoteEvent") then
    addConnection(Net.PlayerFired.OnClientEvent:Connect(function(payload)
        if type(payload) == "table" and tonumber(payload.userId) == LocalPlayer.UserId then
            Runtime.LocalPlayerFiredSeq = (Runtime.LocalPlayerFiredSeq or 0) + 1
            Runtime.LastLocalPlayerFiredAt = os.clock()
            Runtime.NativeAutoShootOwned = true
            Runtime.ServeRejectStreak = 0
        end
    end))
end

-- Rebirth confirmation channel. The stock UI uses this same event, so listening
-- here does not interfere with the game's own RebirthUI.
if Net.RebirthResult and Net.RebirthResult.OnClientEvent then
    addConnection(Net.RebirthResult.OnClientEvent:Connect(function(success, snapshot, reason)
        Runtime.RebirthSignalSeq = (Runtime.RebirthSignalSeq or 0) + 1
        Runtime.LastRebirthSignal = {
            success = success == true,
            snapshot = snapshot,
            reason = reason,
            at = os.clock(),
        }
    end))
end

local function waitAlive(seconds)
    local deadline = os.clock() + math.max(0, tonumber(seconds) or 0)
    while Runtime.Alive and os.clock() < deadline do
        task.wait(math.min(Settings.TurboMode and 0.025 or 0.075, deadline - os.clock()))
    end
    return Runtime.Alive
end

-- Big-number helpers ---------------------------------------------------------
local SUFFIX_E = {
    [""] = 0,
    K = 3,
    M = 6,
    B = 9,
    T = 12,
    Qa = 15,
    Qi = 18,
    Sx = 21,
    Sp = 24,
    Oc = 27,
    No = 30,
    Dc = 33,
    Ud = 36,
    Dd = 39,
    Td = 42,
    Qtd = 45,
    Qid = 48,
    Sxd = 51,
    Spd = 54,
    Ocd = 57,
    Nvd = 60,
    V = 63,
}

local function normalizeBN(m, e)
    m = tonumber(m) or 0
    e = tonumber(e) or 0
    if m <= 0 then
        return {m = 0, e = 0}
    end
    while m >= 10 do
        m = m / 10
        e = e + 1
    end
    while m < 1 do
        m = m * 10
        e = e - 1
    end
    return {m = m, e = e}
end

local function toBN(value)
    if typeof(value) == "table" and value.m ~= nil and value.e ~= nil then
        return normalizeBN(value.m, value.e)
    end
    if typeof(value) == "number" then
        if value <= 0 then
            return {m = 0, e = 0}
        end
        local e = math.floor(math.log10(value))
        return normalizeBN(value / (10 ^ e), e)
    end
    local text = tostring(value or "0")
    text = text:gsub(",", ""):gsub("%s+", "")
    local numberText, suffix = text:match("^([%+%-]?[%d%.]+)([%a]*)$")
    if not numberText then
        return {m = 0, e = 0}
    end
    local number = tonumber(numberText) or 0
    if number <= 0 then
        return {m = 0, e = 0}
    end
    local suffixE = SUFFIX_E[suffix]
    if suffixE == nil then
        suffixE = SUFFIX_E[suffix:sub(1, 1):upper() .. suffix:sub(2)] or 0
    end
    local e = math.floor(math.log10(number))
    return normalizeBN(number / (10 ^ e), e + suffixE)
end

local function bnLog(a)
    a = toBN(a)
    if a.m <= 0 then
        return -math.huge
    end
    return math.log10(a.m) + a.e
end

local function bnGE(a, b)
    local la = bnLog(a)
    local lb = bnLog(b)
    return la >= lb - 1e-9
end

local function bnScale(a, factor)
    a = toBN(a)
    factor = tonumber(factor) or 0
    if a.m <= 0 or factor <= 0 then
        return {m = 0, e = 0}
    end
    return normalizeBN(a.m * factor, a.e)
end

local function bnFormat(a)
    a = toBN(a)
    if a.m <= 0 then
        return "0"
    end
    if a.e < 3 then
        local n = a.m * (10 ^ a.e)
        return tostring(math.floor(n + 0.5))
    end
    local suffixByE = {}
    for suffix, e in pairs(SUFFIX_E) do
        suffixByE[e] = suffix
    end
    local grouped = math.floor(a.e / 3) * 3
    local suffix = suffixByE[grouped]
    if suffix then
        local shown = a.m * (10 ^ (a.e - grouped))
        return ("%.2f%s"):format(shown, suffix):gsub("%.?0+([A-Za-z])", "%1")
    end
    return ("%.2fe%d"):format(a.m, a.e)
end

local function getLeaderstat(names)
    local stats = LocalPlayer:FindFirstChild("leaderstats")
    if not stats then
        return nil
    end
    for _, name in ipairs(names) do
        local v = stats:FindFirstChild(name)
        if v then
            return v.Value
        end
    end
    return nil
end

local function currentCoins()
    return toBN(getLeaderstat({"Coins 💰", "Coins", "Money 💰", "Money"}) or 0)
end

local function currentPower()
    return toBN(getLeaderstat({"Power ⚡", "Power", "Strength ⚡", "Strength"}) or 0)
end

local function getProfile()
    local ok, profile = safeInvoke(Net.RequestProfileData)
    if ok and typeof(profile) == "table" then
        return profile
    end
    return {}
end

local function currentWorld(profile)
    local attr = LocalPlayer:GetAttribute("CurrentZone")
    if typeof(attr) == "string" and ZoneConfig.GetByName(attr) then
        return attr
    end
    profile = profile or getProfile()
    local highest = ZoneConfig.GetHighestUnlocked(profile.ZonesUnlocked or {"City"})
    if typeof(highest) == "table" then
        return highest.name or highest.Name or "City"
    end
    if typeof(highest) == "string" then
        return highest
    end
    return "City"
end

-- Game-state helpers ---------------------------------------------------------
local function getAutoShootButton()
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local main = playerGui and playerGui:FindFirstChild("Main")
    local right = main and main:FindFirstChild("right")
    return right and right:FindFirstChild("AutoShootBtn")
end

local function getButtonScreenCenter(button)
    if not button or not button:IsA("GuiButton") then
        return nil
    end
    local size = button.AbsoluteSize
    if size.X < 2 or size.Y < 2 then
        return nil
    end

    -- GetMouseLocation / injected mouse coordinates include the top-left GUI inset
    -- while GuiObject.AbsolutePosition does not. Add the inset so the click lands
    -- on the visible button on current Roblox clients.
    local inset = Vector2.new(0, 0)
    pcall(function()
        local topLeft = GuiService:GetGuiInset()
        if typeof(topLeft) == "Vector2" then
            inset = topLeft
        end
    end)

    return button.AbsolutePosition + (size / 2) + inset
end

local function buttonActuallyVisible(button)
    if not button or not button.Parent then
        return false
    end
    local node = button
    while node do
        if node:IsA("GuiObject") and node.Visible == false then
            return false
        end
        if node:IsA("ScreenGui") and node.Enabled == false then
            return false
        end
        node = node.Parent
    end
    return button.AbsoluteSize.X >= 2 and button.AbsoluteSize.Y >= 2
end

local function withIdentity(identity, callback)
    local getId = type(getthreadidentity) == "function" and getthreadidentity
        or (type(getidentity) == "function" and getidentity)
    local setId = type(setthreadidentity) == "function" and setthreadidentity
        or (type(setidentity) == "function" and setidentity)
    local previous
    if getId then
        pcall(function() previous = getId() end)
    end
    if setId then
        pcall(setId, identity)
    end
    local ok, a, b = pcall(callback)
    if setId and previous ~= nil then
        pcall(setId, previous)
    end
    return ok, a, b
end

local function clickGuiButtonWithInput(button)
    if not buttonActuallyVisible(button) then
        return false, "button not visible"
    end
    local center = getButtonScreenCenter(button)
    if not center then
        return false, "button has no screen center"
    end
    local x = math.floor(center.X + 0.5)
    local y = math.floor(center.Y + 0.5)

    local function trySolaraMouse()
        local moveAbs = type(mousemoveabs) == "function" and mousemoveabs or nil
        local click = type(mouse1click) == "function" and mouse1click or nil
        local press = type(mouse1press) == "function" and mouse1press or nil
        local release = type(mouse1release) == "function" and mouse1release or nil
        if not moveAbs or not (click or (press and release)) then
            return false
        end

        if type(isrbxactive) == "function" then
            local okActive, active = pcall(isrbxactive)
            if okActive and not active then
                return false
            end
        end

        local oldPos
        pcall(function() oldPos = UserInputService:GetMouseLocation() end)
        local ok = pcall(function()
            moveAbs(x, y)
            task.wait(0.05)
            if click then
                click()
            else
                press()
                task.wait(0.05)
                release()
            end
            task.wait(0.05)
            if typeof(oldPos) == "Vector2" then
                moveAbs(math.floor(oldPos.X + 0.5), math.floor(oldPos.Y + 0.5))
            end
        end)
        if ok then
            Runtime.LastNativeInputMethod = "SolaraMouse"
            Runtime.SolaraInputClicks = (Runtime.SolaraInputClicks or 0) + 1
            return true
        end
        return false
    end

    local function tryVirtualInputManager()
        if not VirtualInputManager then
            return false
        end
        local ok = withIdentity(8, function()
            VirtualInputManager:SendMouseMoveEvent(x, y, game)
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
        end)
        if ok then
            Runtime.LastNativeInputMethod = "VirtualInputManager"
            Runtime.SolaraInputClicks = (Runtime.SolaraInputClicks or 0) + 1
            return true
        end
        return false
    end

    -- On Solara, use its documented real mouse input first while Roblox is focused.
    -- This most closely reproduces a human click on AutoShootBtn and therefore lets
    -- the game's own FiringClient create all private state. VIM is the AFK fallback.
    if IS_SOLARA then
        if trySolaraMouse() then
            return true
        end
        if tryVirtualInputManager() then
            return true
        end
    else
        if tryVirtualInputManager() then
            return true
        end
        if trySolaraMouse() then
            return true
        end
    end

    Runtime.SolaraInputFailures = (Runtime.SolaraInputFailures or 0) + 1
    return false, "no compatible input method"
end

local function pressGuiButton(button)
    if not button then
        return false
    end

    -- Rich executors can invoke the callback signal directly.
    if type(firesignal) == "function" then
        local ok = pcall(function()
            firesignal(button.MouseButton1Up)
        end)
        if ok then
            Runtime.LastNativeInputMethod = "firesignal"
            return true
        end
    end
    if type(getconnections) == "function" then
        local ok, connections = pcall(getconnections, button.MouseButton1Up)
        if ok and type(connections) == "table" then
            local fired = false
            for _, connection in ipairs(connections) do
                if connection and type(connection.Function) == "function" then
                    local success = pcall(connection.Function)
                    fired = success or fired
                elseif connection and type(connection.Fire) == "function" then
                    local success = pcall(function() connection:Fire() end)
                    fired = success or fired
                end
            end
            if fired then
                Runtime.LastNativeInputMethod = "getconnections"
                return true
            end
        end
    end

    -- Solara and other lower-UNC executors: click the REAL game button with input.
    local ok, reason = clickGuiButtonWithInput(button)
    if not ok then
        dlog("Native button input failed", tostring(reason))
    end
    return ok
end

local function stopBuiltInAutoShoot()
    local localActive = LocalPlayer:GetAttribute("AutoShootActive") == true
    local serverActive = Runtime.ServerAutoShootEnabled == true
    local nativeOwned = Runtime.NativeAutoShootOwned == true

    if not localActive and not serverActive and not nativeOwned then
        return true
    end

    -- If we started the game's native Auto Shoot, stop it through the same real
    -- button path so FiringClient's private boolean is toggled too. Merely sending
    -- AutoShootState=false does not necessarily stop the client's internal loop.
    if nativeOwned or localActive then
        local button = getAutoShootButton()
        if button then
            pressGuiButton(button)
            waitAlive(0.12)
        end
    end

    safeFire(Net.AutoShootState, false)
    Runtime.ServerAutoShootEnabled = false
    Runtime.NativeAutoShootOwned = false
    Runtime.NativeAutoShootStartedAt = 0
    pcall(function()
        LocalPlayer:SetAttribute("AutoShootActive", false)
    end)
    return true
end

local function stopTraining()
    if Runtime.Training or LocalPlayer:GetAttribute("AutoTrainActive") == true or LocalPlayer:GetAttribute("IsTrainMode") == true then
        safeFire(Net.Training_SetAuto, false)
        safeFire(Net.Training_Cancel)
        Runtime.Training = false

        -- Do not race RequestShot against the server still clearing train mode.
        local timeout = Settings.TurboMode and 1.0 or 1.5
        local untilTime = os.clock() + timeout
        while Runtime.Alive and os.clock() < untilTime do
            if LocalPlayer:GetAttribute("IsTrainMode") ~= true and LocalPlayer:GetAttribute("AutoTrainActive") ~= true then
                break
            end
            task.wait(Settings.TurboMode and 0.035 or 0.06)
        end
    end
end

local function findTrainingTargetCFrame(targetName)
    if type(targetName) ~= "string" or targetName == "" then
        return nil
    end

    local object = Workspace:FindFirstChild(targetName, true)
    if not object then
        return nil
    end
    if object:IsA("BasePart") then
        return object.CFrame
    elseif object:IsA("Model") then
        local ok, pivot = pcall(object.GetPivot, object)
        if ok then return pivot end
    elseif object:IsA("Attachment") then
        return object.WorldCFrame
    end

    local part = object:FindFirstChildWhichIsA("BasePart", true)
    return part and part.CFrame or nil
end

local function directTrainingStartFromAutoState()
    local state = Runtime.TrainingAutoState
    if type(state) ~= "table" or state.active ~= true then
        return false
    end
    local targetName = state.targetName
    local targetCFrame = findTrainingTargetCFrame(targetName)
    if not targetName or not targetCFrame or not Net.Training_RequestStart then
        return false
    end

    local ok = safeFire(Net.Training_RequestStart, targetName, targetCFrame)
    if ok then
        Runtime.DirectTrainingFallbacks = (Runtime.DirectTrainingFallbacks or 0) + 1
        dlog("Direct training fallback", targetName)
    end
    return ok
end

local function startBestTraining()
    if Runtime.ChallengeActive then
        return false
    end

    stopBuiltInAutoShoot()

    -- A normal client shot owns the firing state until it finishes. Never try to
    -- start training through it; wait for the exact client attribute instead.
    local shotDeadline = os.clock() + 8
    while Runtime.Alive and LocalPlayer:GetAttribute("ShotInFlight") == true and os.clock() < shotDeadline do
        task.wait(0.05)
    end

    safeFire(Net.Training_SetAuto, true)
    Runtime.Training = true

    -- Training_SetAuto is a two-step flow: the server returns the best target via
    -- Training_AutoState, then TrainingAutoClient sends Training_RequestStart.
    -- v1.1.0 could stop again before this handshake settled on slower servers.
    local startedAt = os.clock()
    local deadline = startedAt + (Settings.TurboMode and 2.0 or 2.6)
    local resent = false
    local directTried = false
    while Runtime.Alive and os.clock() < deadline do
        if LocalPlayer:GetAttribute("IsTrainMode") == true then
            Runtime.Training = true
            return true
        end
        local elapsed = os.clock() - startedAt
        if not resent and elapsed >= 0.55 then
            resent = true
            safeFire(Net.Training_SetAuto, true)
        end
        if not directTried and elapsed >= 0.75 then
            directTried = directTrainingStartFromAutoState()
        end
        task.wait(0.04)
    end

    Runtime.Training = LocalPlayer:GetAttribute("IsTrainMode") == true
    if not Runtime.Training then
        dlog("Training handshake did not enter IsTrainMode; continuing safely")
    end
    return Runtime.Training
end

local function smartTrainingBurst(seconds)
    seconds = math.max(Settings.TurboMode and 0.75 or 1.0, tonumber(seconds) or 2.5)
    setStatus(("Starting best-table training (%.2fs burst)"):format(seconds))

    if not startBestTraining() then
        setStatus("Training start delayed - recovering")
        stopTraining()
        return false
    end

    -- Count the burst only after the server has actually entered train mode.
    setStatus(("Training best table for %.2fs"):format(seconds))
    local endAt = os.clock() + seconds
    while Runtime.Alive and Settings.SmartAutofarm and os.clock() < endAt do
        if Runtime.ChallengeActive or LocalPlayer:GetAttribute("IsTrainMode") ~= true then
            break
        end
        task.wait(Settings.TurboMode and 0.05 or 0.1)
    end
    stopTraining()
    return true
end

local function isRacePhase()
    -- Prefer the server's Race_StateSync payload when we have seen one recently.
    -- The stock client attribute remains a fallback for late execution / missed sync.
    local mode = Runtime.RaceMode
    if type(mode) == "string" and mode ~= "" then
        local lowered = string.lower(mode)
        if lowered == "race" then
            return true
        elseif lowered == "intermission" or lowered == "train" or lowered == "training" then
            return false
        end
    end
    return LocalPlayer:GetAttribute("RaceIntermission") ~= true
end

local function phaseName()
    return isRacePhase() and "Race" or "Train"
end

local function moveToFiringLine()
    local track = Workspace:FindFirstChild("Track")
    local line = track and track:FindFirstChild("CautionLine")
    if not line then
        line = Workspace:FindFirstChild("CautionLine", true)
    end
    if not line or not line:IsA("BasePart") then
        dlog("Serve preparation failed", "CautionLine missing")
        return false
    end

    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root or humanoid.Health <= 0 then
        dlog("Serve preparation failed", "character/root missing")
        return false
    end

    local position = Vector3.new(line.Position.X, root.Position.Y, line.Position.Z)
    root.CFrame = CFrame.lookAt(position, position + line.CFrame.LookVector)
    humanoid:Move(Vector3.new(0, 0, 0), false)

    -- The stock moveToCautionLine() calls its private setCanShoot(true, true).
    -- Mirroring the public attribute makes our direct fallback agree with the UI.
    pcall(function()
        LocalPlayer:SetAttribute("CanShoot", true)
    end)
    return true
end

local function ensureNativeAutoShoot()
    if not Settings.AutoServe or not Runtime.Alive or Runtime.ChallengeActive then
        return false
    end
    if not isRacePhase() then
        return false
    end
    if Settings.ForceDirectServe then
        return false
    end

    -- Once the native loop has been confirmed from PlayerFired, keep it alive for
    -- the Race phase. If it becomes silent for too long, re-arm it automatically.
    if Runtime.NativeAutoShootOwned then
        local reference = math.max(
            tonumber(Runtime.LastLocalPlayerFiredAt) or 0,
            tonumber(Runtime.NativeAutoShootStartedAt) or 0
        )
        if reference > 0 and os.clock() - reference < 12 then
            return true
        end
        dlog("Native Auto Serve watchdog", "no local PlayerFired for 12s; re-arming")
        Runtime.NativeAutoShootOwned = false
    end

    stopTraining()
    if not moveToFiringLine() then
        Runtime.NativeServeFailures = Runtime.NativeServeFailures + 1
        return false
    end
    waitAlive(math.max(IS_SOLARA and 0.20 or 0.10, tonumber(Settings.ServeReadyDelay) or 0.18))

    local button = getAutoShootButton()
    if not button then
        Runtime.NativeServeFailures = Runtime.NativeServeFailures + 1
        dlog("Native Auto Serve unavailable", "AutoShootBtn missing")
        return false
    end

    -- Race UI can become visible a few frames after Race_StateSync. Wait for a real
    -- clickable rectangle instead of firing into a hidden button and falling back.
    local visibleDeadline = os.clock() + 1.5
    while Runtime.Alive and isRacePhase() and os.clock() < visibleDeadline and not buttonActuallyVisible(button) do
        task.wait(0.05)
    end

    local beforeSeq = Runtime.LocalPlayerFiredSeq or 0
    local beforeAt = Runtime.LastLocalPlayerFiredAt or 0
    if pressGuiButton(button) then
        Runtime.NativeAutoShootStartedAt = os.clock()
        local deadline = os.clock() + (IS_SOLARA and 3.0 or 1.8)
        while Runtime.Alive and os.clock() < deadline do
            if not isRacePhase() then
                return false
            end
            if (Runtime.LocalPlayerFiredSeq or 0) > beforeSeq
                or (Runtime.LastLocalPlayerFiredAt or 0) > beforeAt
                or LocalPlayer:GetAttribute("AutoShootActive") == true then
                Runtime.NativeAutoShootOwned = true
                Runtime.NativeServeStarts = Runtime.NativeServeStarts + 1
                Runtime.ServeRejectStreak = 0
                dlog("Native Auto Serve confirmed", "method=" .. tostring(Runtime.LastNativeInputMethod))
                return true
            end
            task.wait(0.05)
        end
    end

    Runtime.NativeServeFailures = Runtime.NativeServeFailures + 1
    dlog("Native Auto Serve not confirmed", "method=" .. tostring(Runtime.LastNativeInputMethod), "falling back to direct RequestShot")
    return false
end

local function setServerAutoShootState(enabled)
    enabled = enabled == true
    if Runtime.ServerAutoShootEnabled == enabled then
        return true
    end
    local ok = safeFire(Net.AutoShootState, enabled)
    if ok then
        Runtime.ServerAutoShootEnabled = enabled
        if Settings.ForceDirectServe then
            pcall(function() LocalPlayer:SetAttribute("AutoShootActive", enabled) end)
        end
        dlog("Server AutoShootState", tostring(enabled))
    end
    return ok
end

local function prepareDirectServe()
    if Runtime.ChallengeActive or not isRacePhase() then
        return false
    end
    stopTraining()

    local shotDeadline = os.clock() + 8
    while Runtime.Alive and LocalPlayer:GetAttribute("ShotInFlight") == true and os.clock() < shotDeadline do
        if not isRacePhase() then
            return false
        end
        task.wait(0.05)
    end
    if LocalPlayer:GetAttribute("ShotInFlight") == true or not isRacePhase() then
        return false
    end

    if not moveToFiringLine() then
        return false
    end
    return waitAlive(math.max(0.10, tonumber(Settings.ServeReadyDelay) or 0.18))
end

local function performMaxShot()
    -- This is only a fallback for executors that cannot fire the native Auto Shoot
    -- GUI callback. Native Auto Shoot is preferred because it runs the real serve
    -- animation, local firing state, RequestShot, BallLanded and AutoNext chain.
    if not prepareDirectServe() then
        return false
    end

    -- The stock Auto Shoot button sends AutoShootState=true before it starts the
    -- firing loop. Solara cannot invoke that GUI callback via firesignal or
    -- getconnections, so mirror the server-visible state explicitly.
    if not setServerAutoShootState(true) then
        Runtime.ServeRejects = Runtime.ServeRejects + 1
        return false
    end
    waitAlive(IS_SOLARA and 0.12 or 0.06)

    local charge = 100
    local okCap, cap = pcall(WeatherConfig.ChargeCap)
    if okCap and tonumber(cap) then
        charge = math.max(1, tonumber(cap))
    end
    setStatus(("Race | direct fallback serve at %d%%"):format(charge))

    local ok, shot = safeInvoke(Net.RequestShot, charge)
    if not ok or typeof(shot) ~= "table" or shot.shotId == nil then
        Runtime.ServeRejects = Runtime.ServeRejects + 1
        Runtime.ServeRejectStreak = Runtime.ServeRejectStreak + 1
        dlog("Direct serve rejected", "charge=" .. tostring(charge), "streak=" .. tostring(Runtime.ServeRejectStreak))
        if Runtime.ServeRejectStreak % 2 == 0 then
            Runtime.ServerAutoShootEnabled = false
            setServerAutoShootState(true)
        end
        task.wait(math.min(1.35, 0.40 + Runtime.ServeRejectStreak * 0.16))
        return false
    end

    Runtime.ServeRejectStreak = 0
    Runtime.Serving = true
    pcall(function() LocalPlayer:SetAttribute("ShotInFlight", true) end)
    local flightTime = math.max(0.05, tonumber(shot.flightTime) or 0.15)
    if not waitAlive(flightTime + math.max(0.03, tonumber(Settings.ShotLandingSlack) or 0.04)) then
        Runtime.Serving = false
        return false
    end

    local landed = safeFire(Net.BallLanded, shot.shotId)
    Runtime.Serving = false
    pcall(function() LocalPlayer:SetAttribute("ShotInFlight", false) end)
    if landed then
        Runtime.Shots = Runtime.Shots + 1
        dlog("Direct fallback serve landed", "id=" .. tostring(shot.shotId), "flight=" .. string.format("%.2f", flightTime))
        waitAlive(math.max(0.35, tonumber(Settings.ServeRecovery) or 0.45))
    end
    return landed
end

local function performServeBurst(count, requireSmartEnabled, skipNativeAttempt)
    if not Settings.AutoServe or Runtime.ChallengeActive or not isRacePhase() then
        return 0
    end
    if requireSmartEnabled == nil then
        requireSmartEnabled = true
    end

    -- First choice: turn on the game's own Auto Shoot once and leave it running for
    -- the whole Race phase. This is both more reliable and faster overall than
    -- repeatedly toggling train/serve state around every shot. The master loop can
    -- set skipNativeAttempt after it already tried native once, preventing a second
    -- click from accidentally toggling the real Auto Shoot back OFF.
    if not skipNativeAttempt and ensureNativeAutoShoot() then
        return 1
    end

    count = math.max(1, math.floor(tonumber(count) or 1))
    local completed = 0
    for _ = 1, count do
        if not Runtime.Alive or (requireSmartEnabled and not Settings.SmartAutofarm) or not Settings.AutoServe or not isRacePhase() then
            break
        end
        if performMaxShot() then
            completed = completed + 1
        else
            task.wait(Settings.TurboMode and 0.4 or 0.65)
        end
    end
    return completed
end

-- World progression ----------------------------------------------------------
local function tryEnterWorld(name)
    if not name then
        return false
    end
    local ok, result = safeInvoke(Net.ZoneRequest, {action = "enter", zoneName = name})
    if ok and (typeof(result) ~= "table" or result.success ~= false) then
        pcall(function()
            LocalPlayer:SetAttribute("CurrentZone", name)
        end)
        return true
    end
    return false
end

local function tryWorldProgression()
    if not Settings.AutoWorlds then
        return false
    end
    local profile = getProfile()
    local unlocked = profile.ZonesUnlocked or {"City"}
    local highest = ZoneConfig.GetHighestUnlocked(unlocked)
    local highestName = typeof(highest) == "table" and (highest.name or highest.Name) or highest
    highestName = highestName or "City"

    local changed = false
    local nextZone = ZoneConfig.GetNextLocked(unlocked)
    if nextZone then
        local nextName = nextZone.name or nextZone.Name
        local price = nextZone.price or nextZone.Price or nextZone.cost or nextZone.Cost
        if nextName and price and bnGE(currentCoins(), price) then
            setStatus("Unlocking world: " .. nextName)
            local ok, result = safeInvoke(Net.ZoneRequest, {action = "unlock", zoneName = nextName})
            if ok and typeof(result) == "table" and result.success == true then
                changed = true
                dlog("World unlocked", nextName)
                task.wait(Settings.TurboMode and 0.08 or 0.25)
                tryEnterWorld(nextName)
                task.wait(Settings.TurboMode and 0.12 or 0.35)
                profile = getProfile()
                unlocked = profile.ZonesUnlocked or unlocked
                highest = ZoneConfig.GetHighestUnlocked(unlocked)
                highestName = typeof(highest) == "table" and (highest.name or highest.Name) or highestName
            end
        end
    end

    if LocalPlayer:GetAttribute("CurrentZone") ~= highestName then
        setStatus("Entering best world: " .. tostring(highestName))
        if tryEnterWorld(highestName) then
            changed = true
            task.wait(Settings.TurboMode and 0.08 or 0.3)
        end
    end
    return changed
end

local function nearNextWorld(profile)
    profile = profile or getProfile()
    local nextZone = ZoneConfig.GetNextLocked(profile.ZonesUnlocked or {"City"})
    if not nextZone then
        return false, nil
    end
    local price = nextZone.price or nextZone.Price or nextZone.cost or nextZone.Cost
    if not price then
        return false, nextZone
    end
    local threshold = bnScale(price, math.clamp(Settings.SaveForWorldAtPercent / 100, 0.05, 0.95))
    return bnGE(currentCoins(), threshold), nextZone
end

-- Upgrades -------------------------------------------------------------------
local UPGRADE_PRIORITY = {"Power", "Coins", "Luck", "Storage", "Walkspeed"}

local function tryUpgrades(maxBuys)
    if not Settings.AutoUpgrades then
        return 0
    end
    maxBuys = math.max(1, tonumber(maxBuys) or 5)
    local bought = 0
    for _ = 1, maxBuys do
        if not Runtime.Alive then
            break
        end
        local profile = getProfile()
        local tiers = profile.Upgrades or {}
        local saving = nearNextWorld(profile)
        local coins = currentCoins()
        local budgetFraction = math.clamp(Settings.UpgradeSpendPercent / 100, 0.01, 1)
        local budget = bnScale(coins, budgetFraction)
        local selected = nil

        for _, category in ipairs(UPGRADE_PRIORITY) do
            local tier = tonumber(tiers[category]) or 0
            local cost = UpgradeConfig.GetNextCost(category, tier)
            if cost and bnGE(coins, cost) and bnGE(budget, cost) then
                -- When a new world is close, only buy direct output upgrades.
                if not saving or category == "Power" or category == "Coins" then
                    selected = category
                    break
                end
            end
        end
        if not selected then
            break
        end

        setStatus("Buying upgrade: " .. selected)
        local ok, success = safeInvoke(Net.RequestUpgrade, selected)
        if not ok or success ~= true then
            break
        end
        bought = bought + 1
        dlog("Upgrade bought", selected)
        task.wait(Settings.TurboMode and 0.035 or 0.12)
    end
    return bought
end

-- Paddles --------------------------------------------------------------------
local function bestOwnedPaddle(profile)
    profile = profile or getProfile()
    local owned = PaddleConfig.OwnedFromProgress(profile.PaddleProgress or {}, profile.PaddleSpecials or {})
    local bestName = PaddleConfig.StarterPaddle or "Classic"
    local bestValue = -math.huge
    for _, name in ipairs(owned) do
        local ok, value = pcall(PaddleConfig.GetEffectiveMult, name, owned)
        value = ok and tonumber(value) or 0
        if value > bestValue then
            bestValue = value
            bestName = name
        end
    end
    return bestName, bestValue
end

local function equipBestPaddle(profile)
    local bestName = bestOwnedPaddle(profile)
    if bestName then
        local current = profile and profile.Equipped and profile.Equipped.Paddle
        if current ~= bestName then
            safeInvoke(Net.Shop_Request, {action = "equip", paddleName = bestName})
            dlog("Equipped paddle", bestName)
        end
    end
end

local function tryPaddles(maxBuys)
    if not Settings.AutoPaddles then
        return 0
    end
    maxBuys = math.max(1, tonumber(maxBuys) or 6)
    local bought = 0
    for _ = 1, maxBuys do
        if not Runtime.Alive then
            break
        end
        local profile = getProfile()
        local world = currentWorld(profile)
        local nextPaddle = PaddleConfig.GetNextPurchasable(world, profile.PaddleProgress or {})
        if not nextPaddle then
            equipBestPaddle(profile)
            break
        end
        local name = nextPaddle.name or nextPaddle.Name
        local cost = nextPaddle.price or (name and PaddleConfig.GetPrice(name))
        local coins = currentCoins()
        local saving = nearNextWorld(profile)
        local allowed = bnScale(coins, saving and 0.08 or 0.28)
        if not name or not cost or not bnGE(coins, cost) or not bnGE(allowed, cost) then
            equipBestPaddle(profile)
            break
        end
        setStatus("Buying paddle: " .. name)
        local ok, result = safeInvoke(Net.Shop_Request, {action = "purchase", paddleName = name})
        if not ok or (typeof(result) == "table" and result.success == false) or result == false then
            break
        end
        bought = bought + 1
        dlog("Paddle bought", name)
        task.wait(Settings.TurboMode and 0.04 or 0.12)
    end
    equipBestPaddle(getProfile())
    return bought
end

-- Rebirth --------------------------------------------------------------------
local function holdRebirthForNearWorld(profile)
    profile = profile or getProfile()
    local nextZone = ZoneConfig.GetNextLocked(profile.ZonesUnlocked or {"City"})
    if not nextZone then
        return false
    end
    local price = nextZone.price or nextZone.Price or nextZone.cost or nextZone.Cost
    if not price then
        return false
    end
    -- Only hold a rebirth if the next world can be bought RIGHT NOW. The master
    -- loop always tries world progression before rebirth, so this is just a guard
    -- against spending the exact unlock money between those two calls.
    return bnGE(currentCoins(), price)
end

local function tryRebirth()
    if not Settings.AutoRebirth then
        return false
    end

    local ok, data = safeInvoke(Net.GetRebirthData)
    if not ok or typeof(data) ~= "table" then
        return false
    end

    local cost = toBN({m = data.costM or 0, e = data.costE or 0})
    local coins = toBN({m = data.coinsM or 0, e = data.coinsE or 0})
    if coins.m <= 0 then
        coins = currentCoins()
    end

    -- Trust the game's snapshot when available, but also compare the exact BN
    -- values so a missing/stale canAfford flag can never block a valid rebirth.
    local affordable = data.canAfford == true or bnGE(coins, cost)
    if not affordable then
        return false
    end

    -- World unlock wins only when we are genuinely close. v1.1.0's 22% coin
    -- reserve was far too conservative and caused the screenshot's affordable
    -- rebirth to be skipped.
    local profile = getProfile()
    if holdRebirthForNearWorld(profile) then
        dlog("Rebirth held", "close to next world")
        return false
    end

    stopTraining()
    local before = tonumber(data.rebirths) or tonumber(LocalPlayer:GetAttribute("Rebirths")) or 0
    local signalBefore = Runtime.RebirthSignalSeq or 0
    setStatus(("Rebirthing immediately (%d -> %d)"):format(before, before + 1))

    if not safeFire(Net.RequestRebirth) then
        return false
    end

    -- Wait for the actual RebirthResult/attribute instead of using a blind fixed
    -- delay. Success normally arrives in only a few frames.
    local deadline = os.clock() + (Settings.TurboMode and 1.1 or 1.6)
    while Runtime.Alive and os.clock() < deadline do
        local now = tonumber(LocalPlayer:GetAttribute("Rebirths"))
        if now and now > before then
            Runtime.LastRebirth = os.clock()
            Runtime.RebirthsDone = Runtime.RebirthsDone + 1
            dlog("Rebirth successful", tostring(before) .. " -> " .. tostring(now))
            return true
        end
        if (Runtime.RebirthSignalSeq or 0) > signalBefore and Runtime.LastRebirthSignal then
            local result = Runtime.LastRebirthSignal
            if result.success == true then
                Runtime.LastRebirth = os.clock()
                Runtime.RebirthsDone = Runtime.RebirthsDone + 1
                dlog("Rebirth successful", "server result")
                return true
            end
            if result.reason == "poor" then
                return false
            end
            if result.reason == "throttled" then
                task.wait(0.25)
                return false
            end
        end
        task.wait(0.04)
    end

    -- Final snapshot fallback in case the client event was unavailable.
    local ok2, after = safeInvoke(Net.GetRebirthData)
    if ok2 and typeof(after) == "table" and (tonumber(after.rebirths) or 0) > before then
        Runtime.LastRebirth = os.clock()
        Runtime.RebirthsDone = Runtime.RebirthsDone + 1
        dlog("Rebirth successful", "snapshot confirmation")
        return true
    end
    dlog("Rebirth request did not confirm")
    return false
end

local function tryRebirthChain(maxCount)
    if not Settings.AutoRebirth then
        return 0
    end
    maxCount = math.max(1, math.floor(tonumber(maxCount) or Settings.RebirthChainMax or 4))
    local done = 0
    for _ = 1, maxCount do
        if not Runtime.Alive or Runtime.ChallengeActive then
            break
        end
        if not tryRebirth() then
            break
        end
        done = done + 1
        -- Enough for the new cost/coins snapshot to settle without the old long wait.
        task.wait(Settings.TurboMode and 0.12 or 0.25)
    end
    return done
end

-- Pets / eggs ----------------------------------------------------------------
local WORLD_EGGS = {
    City = {"BasicEgg", "CityEgg", "NightlifeEgg"},
    Garden = {"FlowerEgg", "FarmEgg", "ZenEgg"},
    Candyland = {"GummyEgg", "BabyEgg", "ChocoCakeEgg"},
    Space = {"WingedEgg", "GalaxyEgg", "MartianEgg"},
    Tundra = {"SnowflakeEgg", "SnowmanEgg", "IcecrownEgg"},
    Cove = {"MermaidEgg", "OceanEgg", "CoralEgg"},
    Dino = {"DinoEgg", "AmberEgg", "ExtinctionEgg"},
    Dune = {"OasisEgg", "SunstoneEgg", "MirageEgg"},
    Halloween = {"PumpkinEgg", "HauntedEgg", "EclipseEgg"},
}

local function eggPrice(name)
    local ok, price = pcall(EggConfig.GetPriceTable, name)
    if ok and price then
        return toBN(price)
    end
    local raw = EggConfig[name]
    if typeof(raw) == "table" then
        return toBN(raw.price or raw.Price or 0)
    end
    return {m = 0, e = 0}
end

local function findEggObject(name)
    for _, object in ipairs(Workspace:GetDescendants()) do
        if object.Name == name and (object:IsA("Model") or object:IsA("BasePart")) then
            return object
        end
    end
    return nil
end

local function rootPart()
    local character = LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function pivotOf(object)
    if not object then
        return nil
    end
    if object:IsA("BasePart") then
        return object.CFrame
    end
    if object:IsA("Model") then
        local ok, cf = pcall(object.GetPivot, object)
        if ok then
            return cf
        end
    end
    local part = object:FindFirstChildWhichIsA("BasePart", true)
    return part and part.CFrame or nil
end

local function resolvedPets()
    local ok, data = safeInvoke(Net.RequestResolvedPets)
    if ok and typeof(data) == "table" then
        return data
    end
    return nil
end

local function petScore(pet)
    if typeof(pet) ~= "table" then
        return -math.huge
    end
    local percent = tonumber(pet.percent)
    if percent and percent > 0 then
        -- Percent pets are endgame/special and should outrank ordinary multipliers.
        return 1e15 + percent
    end
    local mult = tonumber(pet.mult) or 0
    if pet.variant == "Rainbow" then
        mult = mult + 1e-6
    elseif pet.variant == "Gold" then
        mult = mult + 1e-7
    end
    return mult
end

local function equipBestPets()
    if not Settings.AutoEquipBest then
        return false
    end
    local snapshot = resolvedPets()
    if not snapshot or typeof(snapshot.pets) ~= "table" then
        return false
    end
    local list = {}
    for uuid, pet in pairs(snapshot.pets) do
        if typeof(pet) == "table" then
            pet.__uuid = pet.uuid or uuid
            list[#list + 1] = pet
        end
    end
    table.sort(list, function(a, b)
        return petScore(a) > petScore(b)
    end)
    local maxEquipped = math.max(1, tonumber(snapshot.maxEquipped) or 3)
    safeInvoke(Net.UnequipAllPets)
    for i = 1, math.min(maxEquipped, #list) do
        local uuid = list[i].__uuid
        if uuid then
            safeInvoke(Net.EquipPet, uuid)
            task.wait(0.04)
        end
    end
    dlog("Equipped best pets", math.min(maxEquipped, #list))
    return true
end

local function fuseFiveOfKind()
    if not Settings.AutoFusion then
        return 0
    end
    local fused = 0
    local snapshot = resolvedPets()
    if not snapshot or typeof(snapshot.pets) ~= "table" then
        return 0
    end

    -- Unequip first because the fusion server rejects equipped pets.
    safeInvoke(Net.UnequipAllPets)
    task.wait(0.1)

    local function makeGroups(data)
        local groups = {}
        for uuid, pet in pairs(data.pets or {}) do
            if typeof(pet) == "table" and pet.locked ~= true then
                local variant = pet.variant or "Normal"
                if variant == "Normal" or variant == "Gold" then
                    local id = tostring(pet.id or pet.name or pet.displayName or "unknown")
                    local key = id .. "|" .. variant
                    groups[key] = groups[key] or {}
                    groups[key][#groups[key] + 1] = pet.uuid or uuid
                end
            end
        end
        return groups
    end

    for pass = 1, 20 do
        if not Runtime.Alive or fused >= 20 then
            break
        end
        snapshot = resolvedPets()
        if not snapshot then
            break
        end
        local groups = makeGroups(snapshot)
        local chosen = nil
        for _, uuids in pairs(groups) do
            if #uuids >= 5 then
                chosen = {uuids[1], uuids[2], uuids[3], uuids[4], uuids[5]}
                break
            end
        end
        if not chosen then
            break
        end
        setStatus("Fusing 5 pets at guaranteed success")
        local ok, result = safeInvoke(Net.FusionRequest, chosen)
        if not ok or result == false or (typeof(result) == "table" and result.success == false) then
            break
        end
        fused = fused + 1
        Runtime.Fusions = Runtime.Fusions + 1
        task.wait(0.18)
    end

    equipBestPets()
    return fused
end

local function chooseBestAffordableEgg()
    local profile = getProfile()
    local world = currentWorld(profile)
    local candidates = WORLD_EGGS[world] or WORLD_EGGS.City
    local coins = currentCoins()
    local snapshot = resolvedPets()
    local petCount = 0
    local maxEquipped = 3
    if snapshot then
        maxEquipped = tonumber(snapshot.maxEquipped) or 3
        if typeof(snapshot.pets) == "table" then
            for _ in pairs(snapshot.pets) do
                petCount = petCount + 1
            end
        end
    end
    local budgetFraction = math.clamp(Settings.HatchSpendPercent / 100, 0.01, 1)
    if petCount < maxEquipped then
        budgetFraction = math.max(budgetFraction, 0.5)
    end
    local budget = bnScale(coins, budgetFraction)
    local selected = nil
    for _, egg in ipairs(candidates) do
        local price = eggPrice(egg)
        if price.m > 0 and bnGE(coins, price) and bnGE(budget, price) then
            selected = egg
        end
    end
    return selected
end

local function hatchEgg(name)
    if not name then
        return false
    end
    stopTraining()
    local eggObject = findEggObject(name)
    local root = rootPart()
    local oldCFrame = root and root.CFrame or nil
    local eggCF = pivotOf(eggObject)

    if root and eggCF then
        pcall(function()
            root.CFrame = eggCF * CFrame.new(0, 2.5, -4)
        end)
        task.wait(0.12)
    end

    setStatus("Hatching: " .. name)
    local fired = safeFire(Net.HatchEgg, name, 1, {})
    if fired then
        task.wait(0.12)
        safeFire(Net.HatchAnimationDone)
        Runtime.Hatches = Runtime.Hatches + 1
    end

    if root and oldCFrame then
        pcall(function()
            root.CFrame = oldCFrame
        end)
    end
    return fired
end

local function tryPets()
    if Settings.AutoHatch and os.clock() - Runtime.LastHatch >= Settings.HatchInterval then
        local egg = chooseBestAffordableEgg()
        if egg then
            hatchEgg(egg)
        end
        Runtime.LastHatch = os.clock()
    end
    if Settings.AutoFusion and os.clock() - Runtime.LastFusion >= Settings.FusionInterval then
        fuseFiveOfKind()
        Runtime.LastFusion = os.clock()
    elseif Settings.AutoEquipBest then
        equipBestPets()
    end
end

-- Rewards --------------------------------------------------------------------
local OFFICIAL_CODES = {"rally", "potions", "lotsofspins"}
local EXTRA_CURRENT_CODES = {"1MVisits", "community"}
local TIME_REWARD_SECONDS = {180, 420, 660, 960, 1440, 2100, 2760, 3600, 7200}

local function redeemCodes()
    if not Settings.AutoCodes then
        return
    end
    for _, code in ipairs(OFFICIAL_CODES) do
        safeFire(Net.redeemCode, code)
        task.wait(0.12)
    end
    for _, code in ipairs(EXTRA_CURRENT_CODES) do
        safeFire(Net.redeemCode, code)
        task.wait(0.12)
    end
    dlog("Codes attempted")
end

local function claimDailyReward()
    local ok, state = safeInvoke(Net.GetDailyRewardState)
    if not ok or typeof(state) ~= "table" then
        return
    end
    local last = tonumber(state.lastClaimTime) or 0
    local now = tonumber(state.serverTime) or os.time()
    if last == 0 or now - last >= 86400 then
        safeFire(Net.ClaimDailyReward)
        dlog("Daily reward claim attempted")
    end
end

local function claimTimeRewards()
    local ok, snapshot = safeInvoke(Net.RequestTimeRewards)
    if not ok or typeof(snapshot) ~= "table" then
        return
    end
    local elapsed = tonumber(snapshot.elapsed) or 0
    local claimed = {}
    if typeof(snapshot.claimed) == "table" then
        for _, index in ipairs(snapshot.claimed) do
            claimed[tonumber(index)] = true
        end
    end
    for i, threshold in ipairs(TIME_REWARD_SECONDS) do
        if elapsed >= threshold and not claimed[i] then
            safeFire(Net.claimTimeReward, i, true)
            task.wait(0.08)
        end
    end
end

local function claimGroupReward()
    local ok, state = safeInvoke(Net.GroupReward_Request, {action = "state"})
    if ok and typeof(state) == "table" and state.claimed ~= true then
        safeInvoke(Net.GroupReward_Request, {action = "claim"})
    end
end

local function claimQuestReward()
    -- Server validates playtime/eligibility; harmless when not ready.
    safeInvoke(Net.ClaimQuestReward)
end

local function claimDailyChest()
    local ok, state = safeInvoke(Net.GetDailyChestCooldown)
    if not ok or typeof(state) ~= "table" then
        return
    end
    local remaining = tonumber(state.remaining) or math.huge
    if remaining > 0 then
        return
    end
    local zoneConstants = Workspace:FindFirstChild("ZoneConstants")
    local chest = zoneConstants and zoneConstants:FindFirstChild("DailyChest")
    local touch = chest and chest:FindFirstChild("Touch", true)
    local root = rootPart()
    if not touch or not root or not touch:IsA("BasePart") then
        return
    end
    if type(firetouchinterest) == "function" then
        pcall(firetouchinterest, root, touch, 0)
        task.wait(0.05)
        pcall(firetouchinterest, root, touch, 1)
    else
        local old = root.CFrame
        pcall(function()
            root.CFrame = touch.CFrame
        end)
        task.wait(0.15)
        pcall(function()
            root.CFrame = old
        end)
    end
end

local function usePotions()
    if not Settings.AutoPotions then
        return
    end
    local profile = getProfile()
    local potions = profile.Potions or profile.potions
    if typeof(potions) ~= "table" then
        return
    end
    for _, kind in ipairs({"Power", "Coins", "Luck"}) do
        local data = potions[kind]
        if typeof(data) == "table" then
            local count = tonumber(data.count) or 0
            local active = data.active == true or (tonumber(data.remaining) or 0) > 0
            if count > 0 and not active then
                safeFire(Net.UsePotion, kind)
                task.wait(0.08)
            end
        end
    end
end

local function spinAvailable()
    if not Settings.AutoSpins then
        return false
    end
    local spins = tonumber(LocalPlayer:GetAttribute("Spins")) or 0
    if spins > 0 then
        safeFire(Net.RequestSpin, nil)
        return true
    end
    return false
end

local function claimAllRewards()
    if not Settings.AutoRewards then
        return
    end
    claimDailyReward()
    claimTimeRewards()
    claimGroupReward()
    claimQuestReward()
    claimDailyChest()
    usePotions()
end

-- Challenge ------------------------------------------------------------------
local function findChallengeCFrame()
    for _, object in ipairs(Workspace:GetDescendants()) do
        if object:IsA("ProximityPrompt") and object.Name == ChallengeConfig.PromptName then
            local parent = object.Parent
            if parent and parent:IsA("BasePart") then
                return parent.CFrame
            end
        end
    end
    local model = Workspace:FindFirstChild(ChallengeConfig.ModelName, true)
    return pivotOf(model)
end

local function challengePowerReady()
    local world = currentWorld()
    local challenger = ChallengeConfig.Get(world)
    if not challenger or not challenger.power then
        return false
    end
    return bnGE(currentPower(), challenger.power)
end

local function tryStartChallenge()
    if not Settings.AutoChallenge or Runtime.ChallengeActive then
        return false
    end
    if os.clock() - Runtime.LastChallengeAttempt < 8 then
        return false
    end
    if not challengePowerReady() then
        return false
    end
    local cf = findChallengeCFrame()
    if not cf then
        return false
    end
    Runtime.LastChallengeAttempt = os.clock()
    stopTraining()
    setStatus("Starting world challenge")
    safeFire(Net.Challenge_RequestStart, cf)
    return true
end

if Net.Challenge_Start then
    addConnection(Net.Challenge_Start.OnClientEvent:Connect(function()
        Runtime.ChallengeActive = true
        setStatus("Challenge active - 20 CPS")
    end))
end
if Net.Challenge_End then
    addConnection(Net.Challenge_End.OnClientEvent:Connect(function()
        Runtime.ChallengeActive = false
        setStatus("Challenge complete")
    end))
end
if Net.Challenge_Cancel then
    addConnection(Net.Challenge_Cancel.OnClientEvent:Connect(function()
        Runtime.ChallengeActive = false
    end))
end

-- Coin rain: confirming is the game's normal client acknowledgement.
if Net.CoinRainStart then
    addConnection(Net.CoinRainStart.OnClientEvent:Connect(function()
        if Settings.AutoRewards then
            safeFire(Net.CoinRainConfirm)
            dlog("Coin rain confirmed")
        end
    end))
end

-- UI -------------------------------------------------------------------------
local PuckUI
local PUCKUI_URL = "https://raw.githubusercontent.com/PuckAFK/Puck-Loader/refs/heads/main/ui/PuckUI.lua"
local function fetchText(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" and #body > 100 then
        return body
    end

    local requestFn = type(request) == "function" and request
        or (type(http_request) == "function" and http_request)
        or (type(httprequest) == "function" and httprequest)
    if requestFn then
        local reqOk, response = pcall(requestFn, {Url = url, Method = "GET"})
        if reqOk and type(response) == "table" then
            local candidate = response.Body or response.body
            if type(candidate) == "string" and #candidate > 100 then
                return candidate
            end
        end
    end
    return nil
end

local uiOk, uiResult = pcall(function()
    local source = fetchText(PUCKUI_URL)
    assert(type(source) == "string", "failed to download PuckUI")
    local chunk, compileErr = loadstring(source, "PuckUI")
    assert(type(chunk) == "function", compileErr or "PuckUI compile failed")
    return chunk()
end)
if uiOk and type(uiResult) == "table" then
    PuckUI = uiResult
else
end

local function makeToggle(tab, name, key, default)
    Settings[key] = default
    return tab:CreateToggle({
        Name = name,
        CurrentValue = default,
        Flag = "PPT_" .. key,
        Callback = function(value)
            Settings[key] = value == true
            if key == "SmartAutofarm" then
                Runtime.Master = Settings[key]
                if not Settings[key] then
                    stopTraining()
                    stopBuiltInAutoShoot()
                    setStatus("Paused")
                else
                    Runtime.Phase = "Unknown"
                    setStatus("Smart Autofarm enabled - syncing phase")
                end
            elseif key == "AutoServe" and not Settings[key] then
                stopBuiltInAutoShoot()
            end
        end,
    })
end

if PuckUI then
    local Window = PuckUI:CreateWindow({
        Name = "PuckAFK | Ping Pong Training",
        GuiName = "PuckAFK_PPT_UI",
        Width = 550,
        Height = 590,
        ConfigId = "PingPongTraining_v1_1_5_CleanSolara",
        Configs = {DefaultProfile = "default", AutoSave = true, AutoLoad = true},
    })

    local FarmTab = Window:CreateTab("Farm")
    FarmTab:CreateSection("Smart Autofarm")
    StatusLabel = FarmTab:CreateLabel("Status: Ready")
    makeToggle(FarmTab, "Smart Autofarm", "SmartAutofarm", false)
    makeToggle(FarmTab, "Turbo Mode", "TurboMode", true)
    makeToggle(FarmTab, "Auto Serve", "AutoServe", true)
    FarmTab:CreateParagraph({
        Title = "Phase-Aware Route",
        Content = "Automatically trains during Train and serves throughout Race, then repeats the cycle while handling progression in the background.",
        Height = 90,
    })
    FarmTab:CreateSlider({
        Name = "Rebirth Check Interval",
        Range = {0.25, 3},
        Increment = 0.05,
        CurrentValue = Settings.RebirthCheckInterval,
        Suffix = "s",
        Flag = "PPT_RebirthCheckInterval",
        Callback = function(v) Settings.RebirthCheckInterval = math.max(0.25, tonumber(v) or 0.65) end,
    })
    FarmTab:CreateSlider({
        Name = "Fallback Direct Serves",
        Range = {1, 3},
        Increment = 1,
        CurrentValue = Settings.ShotsPerCycle,
        Flag = "PPT_FallbackServes",
        Callback = function(v) Settings.ShotsPerCycle = math.max(1, math.floor(tonumber(v) or 1)) end,
    })
    FarmTab:CreateSlider({
        Name = "Maintenance Interval",
        Range = {1, 8},
        Increment = 1,
        CurrentValue = Settings.MaintenanceEvery,
        Suffix = "s",
        Flag = "PPT_MaintenanceSeconds",
        Callback = function(v) Settings.MaintenanceEvery = math.max(1, math.floor(tonumber(v) or 3)) end,
    })
    local ProgressTab = Window:CreateTab("Progression")
    ProgressTab:CreateSection("World & Economy")
    makeToggle(ProgressTab, "Auto Unlock + Enter Best World", "AutoWorlds", true)
    makeToggle(ProgressTab, "Auto Buy Best Paddles", "AutoPaddles", true)
    makeToggle(ProgressTab, "Auto ROI Upgrades", "AutoUpgrades", true)
    makeToggle(ProgressTab, "Fast Auto Rebirth When Affordable", "AutoRebirth", true)
    ProgressTab:CreateSlider({
        Name = "Upgrade Spend Budget",
        Range = {5, 60},
        Increment = 1,
        CurrentValue = Settings.UpgradeSpendPercent,
        Suffix = "%",
        Flag = "PPT_UpgradeSpendPercent",
        Callback = function(v) Settings.UpgradeSpendPercent = tonumber(v) or 18 end,
    })
    ProgressTab:CreateSlider({
        Name = "Start Saving For Next World At",
        Range = {10, 80},
        Increment = 5,
        CurrentValue = Settings.SaveForWorldAtPercent,
        Suffix = "%",
        Flag = "PPT_SaveForWorldAtPercent",
        Callback = function(v) Settings.SaveForWorldAtPercent = tonumber(v) or 35 end,
    })
    ProgressTab:CreateParagraph({
        Title = "Rebirth Priority",
        Content = "Rebirth is checked every ~0.65s during Train. It is only held when the next world is already affordable, so the world is unlocked first. Rebirth is intentionally paused during Race because it resets Power.",
        Height = 72,
    })
    ProgressTab:CreateButton({Name = "Progress Now", Callback = function()
        task.spawn(function()
            tryWorldProgression()
            tryRebirthChain(Settings.RebirthChainMax)
            tryUpgrades(8)
            tryPaddles(8)
            tryWorldProgression()
            tryRebirthChain(Settings.RebirthChainMax)
        end)
    end})
    ProgressTab:CreateButton({Name = "Rebirth Now (Chain Affordable)", Callback = function()
        task.spawn(function()
            if Runtime.Busy then return end
            Runtime.Busy = true
            tryWorldProgression()
            local count = tryRebirthChain(Settings.RebirthChainMax)
            setStatus(("Manual rebirth check complete | %d rebirth(s)"):format(count))
            Runtime.Busy = false
        end)
    end})

    local PetsTab = Window:CreateTab("Pets")
    PetsTab:CreateSection("Pet Progression")
    makeToggle(PetsTab, "Auto Hatch Best Affordable Egg", "AutoHatch", true)
    makeToggle(PetsTab, "Auto Equip Best Pets", "AutoEquipBest", true)
    makeToggle(PetsTab, "Auto Fuse 5 -> Gold/Rainbow", "AutoFusion", true)
    PetsTab:CreateSlider({
        Name = "Egg Spend Budget",
        Range = {1, 35},
        Increment = 1,
        CurrentValue = Settings.HatchSpendPercent,
        Suffix = "%",
        Flag = "PPT_HatchSpendPercent",
        Callback = function(v) Settings.HatchSpendPercent = tonumber(v) or 6 end,
    })
    PetsTab:CreateSlider({
        Name = "Hatch Interval",
        Range = {5, 120},
        Increment = 5,
        CurrentValue = Settings.HatchInterval,
        Suffix = "s",
        Flag = "PPT_HatchInterval",
        Callback = function(v) Settings.HatchInterval = tonumber(v) or 25 end,
    })
    PetsTab:CreateButton({Name = "Equip Best Now", Callback = function() task.spawn(equipBestPets) end})
    PetsTab:CreateButton({Name = "Fuse All Guaranteed Sets Now", Callback = function() task.spawn(fuseFiveOfKind) end})

    local ExtrasTab = Window:CreateTab("Extras")
    ExtrasTab:CreateSection("Challenge")
    makeToggle(ExtrasTab, "Auto Challenge When Power Is Ready", "AutoChallenge", false)
    ExtrasTab:CreateParagraph({
        Title = "Safe Challenge Rate",
        Content = "Uses 2 clicks every 0.1s (20 CPS), below the game's 25 CPS server limit, and only starts when your current Power meets the world recommendation.",
        Height = 65,
    })
    ExtrasTab:CreateSection("Free Rewards")
    makeToggle(ExtrasTab, "Auto Claim Rewards", "AutoRewards", true)
    makeToggle(ExtrasTab, "Auto Use Potions", "AutoPotions", true)
    makeToggle(ExtrasTab, "Auto Use Free Spins", "AutoSpins", true)
    makeToggle(ExtrasTab, "Auto Redeem Current Codes", "AutoCodes", true)
    ExtrasTab:CreateButton({Name = "Claim Everything Now", Callback = function()
        task.spawn(function()
            redeemCodes()
            claimAllRewards()
        end)
    end})

    Window:CreateTab("Settings")

    PuckUI:Notify({
        Title = "Ping Pong Training",
        Content = "Smart Autofarm ready.",
        Duration = 3,
    })
end

if not PuckUI then
    -- Last-resort UI made only from ordinary Roblox instances. This keeps the
    -- script usable even if an executor temporarily blocks GitHub/HttpGet.
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 8)
    if playerGui then
        local old = playerGui:FindFirstChild("PuckAFK_PPT_Fallback")
        if old then old:Destroy() end
        local gui = Instance.new("ScreenGui")
        gui.Name = "PuckAFK_PPT_Fallback"
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 10000
        gui.Parent = playerGui

        local frame = Instance.new("Frame")
        frame.Size = UDim2.fromOffset(310, 154)
        frame.Position = UDim2.fromOffset(24, 120)
        frame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
        frame.BorderColor3 = Color3.fromRGB(55, 55, 55)
        frame.Parent = gui

        local title = Instance.new("TextLabel")
        title.BackgroundTransparency = 1
        title.Size = UDim2.new(1, -16, 0, 30)
        title.Position = UDim2.fromOffset(8, 4)
        title.Font = Enum.Font.Code
        title.TextSize = 15
        title.TextColor3 = Color3.fromRGB(235, 235, 235)
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Text = "PuckAFK | Ping Pong Training"
        title.Parent = frame

        local status = Instance.new("TextLabel")
        status.BackgroundTransparency = 1
        status.Size = UDim2.new(1, -16, 0, 40)
        status.Position = UDim2.fromOffset(8, 34)
        status.Font = Enum.Font.Code
        status.TextSize = 12
        status.TextColor3 = Color3.fromRGB(170, 170, 170)
        status.TextWrapped = true
        status.TextXAlignment = Enum.TextXAlignment.Left
        status.Text = "Ready"
        status.Parent = frame
        StatusLabel = {Set = function(_, value) status.Text = tostring(value) end}

        local toggle = Instance.new("TextButton")
        toggle.Size = UDim2.fromOffset(286, 32)
        toggle.Position = UDim2.fromOffset(12, 82)
        toggle.Font = Enum.Font.Code
        toggle.TextSize = 14
        toggle.TextColor3 = Color3.fromRGB(240, 240, 240)
        toggle.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
        toggle.Text = "Smart Autofarm: OFF"
        toggle.Parent = frame
        toggle.MouseButton1Click:Connect(function()
            Settings.SmartAutofarm = not Settings.SmartAutofarm
            Runtime.Master = Settings.SmartAutofarm
            Runtime.Phase = "Unknown"
            toggle.Text = "Smart Autofarm: " .. (Settings.SmartAutofarm and "ON" or "OFF")
            if not Settings.SmartAutofarm then
                stopTraining()
                stopBuiltInAutoShoot()
            end
        end)

        local rebirth = Instance.new("TextButton")
        rebirth.Size = UDim2.fromOffset(286, 26)
        rebirth.Position = UDim2.fromOffset(12, 120)
        rebirth.Font = Enum.Font.Code
        rebirth.TextSize = 12
        rebirth.TextColor3 = Color3.fromRGB(220, 220, 220)
        rebirth.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
        rebirth.Text = "Rebirth Now"
        rebirth.Parent = frame
        rebirth.MouseButton1Click:Connect(function() task.spawn(function() tryRebirthChain(Settings.RebirthChainMax) end) end)
    end
end

-- Background workers ---------------------------------------------------------
if Settings.AntiIdle then
    addConnection(LocalPlayer.Idled:Connect(function()
        if Settings.AntiIdle then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(0, 0))
            end)
        end
    end))
end

-- Challenge click worker.
task.spawn(function()
    while Runtime.Alive do
        if Settings.AutoChallenge and Runtime.ChallengeActive then
            safeFire(Net.Challenge_Click, math.clamp(math.floor(Settings.ChallengeClicksPerTick), 1, 2))
            task.wait(0.1)
        else
            task.wait(0.2)
        end
    end
end)

-- Free spin worker.
task.spawn(function()
    while Runtime.Alive do
        if Settings.AutoRewards and Settings.AutoSpins and spinAvailable() then
            task.wait(0.8)
        else
            task.wait(1.5)
        end
    end
end)

-- Reward worker.
task.spawn(function()
    task.wait(1)
    if Settings.AutoCodes then
        redeemCodes()
    end
    while Runtime.Alive do
        if Settings.AutoRewards and os.clock() - Runtime.LastRewards >= 25 then
            claimAllRewards()
            Runtime.LastRewards = os.clock()
        end
        task.wait(2)
    end
end)

-- Master smart farm.
-- IMPORTANT: the game itself has two mutually-exclusive phases:
--   RaceIntermission=true  -> TRAIN (FiringClient refuses shots)
--   RaceIntermission=false -> RACE  (Training should stop; serving is allowed)
-- The old burst loop fought this state machine. This controller follows it.
task.spawn(function()
    while Runtime.Alive do
        if not Settings.SmartAutofarm then
            Runtime.Phase = "Paused"
            task.wait(0.2)
        elseif Runtime.Busy or Runtime.ChallengeActive then
            task.wait(0.1)
        else
            Runtime.Busy = true
            local ok, err = pcall(function()
                Runtime.Cycles = Runtime.Cycles + 1
                local now = os.clock()
                local phase = phaseName()
                local changed = Runtime.Phase ~= phase
                if changed then
                    Runtime.Phase = phase
                    Runtime.LastPhaseChange = now
                    dlog("Phase change", phase)
                end

                if phase == "Race" then
                    -- Never try to train during Race. Keep native Auto Shoot alive for
                    -- the entire phase; do NOT toggle it between individual shots.
                    stopTraining()

                    if Settings.AutoServe then
                        local native = ensureNativeAutoShoot()
                        if native then
                            setStatus("Race | Native Auto Serve running continuously")
                        else
                            -- Native input could not be confirmed. Keep direct serving as
                            -- a last-resort fallback instead of making it Solara's primary path.
                            performServeBurst(Settings.ShotsPerCycle, true, true)
                            setStatus(IS_SOLARA and "Race | Solara native failed; direct fallback" or "Race | Direct serve fallback")
                        end
                    else
                        stopBuiltInAutoShoot()
                        setStatus("Race | Auto Serve disabled")
                    end

                    -- World unlocks are safe and high value, but don't run rebirths
                    -- during Race because rebirth resets Power and would ruin shots.
                    if changed or now - (Runtime.LastMaintenanceTick or 0) >= math.max(1, Settings.MaintenanceEvery) then
                        Runtime.LastMaintenanceTick = now
                        tryWorldProgression()
                    end
                else
                    -- TRAIN phase: the game's FiringClient refuses RequestShot here.
                    -- Shut Auto Shoot down once, then train continuously instead of
                    -- wasting time on train -> rejected serve -> train cycles.
                    if changed or LocalPlayer:GetAttribute("AutoShootActive") == true then
                        stopBuiltInAutoShoot()
                    end

                    if changed then
                        tryWorldProgression()
                        local rebirths = tryRebirthChain(Settings.RebirthChainMax)
                        if rebirths > 0 then
                            dlog("Train phase opening rebirth chain", rebirths)
                        end
                        tryWorldProgression()
                        tryUpgrades(Settings.TurboMode and 7 or 5)
                        tryPaddles(Settings.TurboMode and 7 or 5)
                    end

                    -- Hot-path rebirth polling. If a rebirth succeeds, immediately
                    -- restart best-table Auto Train so virtually no Train time is lost.
                    local rebirthInterval = math.max(0.25, tonumber(Settings.RebirthCheckInterval) or 0.65)
                    if now - (Runtime.LastRebirthPoll or 0) >= rebirthInterval then
                        Runtime.LastRebirthPoll = now
                        tryWorldProgression()
                        local rebirths = tryRebirthChain(Settings.RebirthChainMax)
                        if rebirths > 0 then
                            tryWorldProgression()
                        end
                    end

                    local trainOn = LocalPlayer:GetAttribute("IsTrainMode") == true
                    local autoTrainOn = LocalPlayer:GetAttribute("AutoTrainActive") == true
                    if not trainOn or not autoTrainOn then
                        startBestTraining()
                    end
                    setStatus("Train | Best-table Auto Training continuously")

                    -- Stagger slower progression so it cannot starve training.
                    if now - (Runtime.LastMaintenanceTick or 0) >= math.max(1, tonumber(Settings.MaintenanceEvery) or 3) then
                        Runtime.LastMaintenanceTick = now
                        tryWorldProgression()
                        tryUpgrades(Settings.TurboMode and 5 or 4)
                        tryPaddles(Settings.TurboMode and 5 or 4)
                        tryPets()
                        tryStartChallenge()
                    end
                end
            end)
            Runtime.Busy = false
            if not ok then
                Runtime.Errors = Runtime.Errors + 1
                setStatus("Recovered from phase-controller error")
                task.wait(Settings.TurboMode and 0.2 or 0.5)
            else
                task.wait(Settings.TurboMode and 0.10 or 0.20)
            end
        end
    end
end)

function Runtime.Stop()
    if not Runtime.Alive then
        return
    end
    Runtime.Alive = false
    Settings.SmartAutofarm = false
    Runtime.Master = false
    pcall(stopTraining)
    pcall(stopBuiltInAutoShoot)
    Runtime.Serving = false
    pcall(function() safeFire(Net.AutoShootState, false) end)
    if Runtime.ChallengeActive then
        pcall(function() safeFire(Net.Challenge_Cancel) end)
    end
    for _, connection in ipairs(Runtime.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    Runtime.Connections = {}
    dlog("Stopped")
end

setStatus("Ready - enable Smart Autofarm")
dlog("Loaded v1.1.5 Clean Solara Build", "Executor=" .. tostring(ExecutorName), "PuckUI=" .. tostring(PuckUI ~= nil))
