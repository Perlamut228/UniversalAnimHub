-- UniversalAnimHub / driver.lua (модуль; грузится через Loader.lua)
local Hub = ...
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local AES = game:GetService("AvatarEditorService")
local LocalPlayer = Players.LocalPlayer
local connect = Hub.connect
local Settings = Hub.Config.Settings
local SLOTS = Hub.Config.SLOTS
local findPack, hasCustom, buildIds = Hub.Packs.find, Hub.Packs.hasCustom, Hub.Packs.buildIds
local loadTrack = Hub.Anim.loadTrack
local playEmote, stopEmote = Hub.Emote.play, Hub.Emote.stop
local BuiltinEmotes, EmoteNames = Hub.Emote.Builtin, Hub.Emote.Names

-- ================= ПРИМЕНЕНИЕ АНИМАЦИЙ (драйвер) =================
-- Мы отключаем родной Animate и сами проигрываем анимации по состояниям Humanoid.
-- Заодно берём на себя то, что делал Animate: поза предмета в руке и встроенные эмоции.
local Driver = { gen = 0, conns = {}, tracks = {}, active = false }

local LOOPED = {
    idle1 = true, idle2 = true, walk = true, run = true, climb = true,
    fall = true, swim = true, swimidle = true,
}
local TOOL_IDS = { toolnone = "507768375", toolslash = "522635514", toollunge = "522638767" }

local function stopDriver()
    Driver.gen += 1
    Driver.active = false
    for _, c in ipairs(Driver.conns) do
        pcall(function() c:Disconnect() end)
    end
    for _, t in pairs(Driver.tracks) do
        pcall(function() t:Stop(0) t:Destroy() end)
    end
    Driver.conns, Driver.tracks = {}, {}
end

local function getAnimate()
    local char = LocalPlayer.Character
    if not char then return nil, nil end
    return char:FindFirstChild("Animate"), char
end

local function startDriver(ids, char)
    stopDriver()

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = hum
    end
    local gen = Driver.gen
    Driver.active = true

    -- гасим всё, что уже играет (оригинальный пак / старый Animate)
    for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
        pcall(function() t:Stop(0) end)
    end

    -- грузим треки пака и инструмента (асинхронно, не тормозим игру)
    local tracks = Driver.tracks
    local function loadInto(name, id, setup)
        task.spawn(function()
            local tr = loadTrack(animator, id, false, 3)
            if Driver.gen ~= gen then
                if tr then pcall(function() tr:Destroy() end) end
                return
            end
            if tr then
                if setup then setup(tr) end
                tracks[name] = tr
            end
        end)
    end
    for name, id in pairs(ids) do
        loadInto(name, id, function(tr)
            if LOOPED[name] then tr.Looped = true end
        end)
    end
    -- Приоритет выше, чем у паков (у них Movement/Action) — иначе рука с предметом
    -- повторяет анимацию пака вместо позы удержания.
    loadInto("toolnone", TOOL_IDS.toolnone, function(tr)
        tr.Looped = true
        tr.Priority = Enum.AnimationPriority.Action2
    end)
    loadInto("toolslash", TOOL_IDS.toolslash, function(tr) tr.Priority = Enum.AnimationPriority.Action3 end)
    loadInto("toollunge", TOOL_IDS.toollunge, function(tr) tr.Priority = Enum.AnimationPriority.Action3 end)

    local current, currentName
    local function play(name, speed)
        local tr = tracks[name]
        if currentName ~= name or (tr and current ~= tr) then
            if current then current:Stop(0.2) end
            currentName = name
            current = tr
            if current then current:Play(0.2) end
        end
        if current and speed then current:AdjustSpeed(speed) end
    end
    local function stopAll()
        if current then current:Stop(0.2) end
        current, currentName = nil, nil
    end

    local jumpT = 0
    local idleChoice, idleUntil = "idle1", 0
    local function pickIdle()
        idleChoice = (tracks.idle2 and math.random() < 0.15) and "idle2" or "idle1"
        idleUntil = os.clock() + math.random(8, 16)
    end

    -- Поза предмета в руке (то, что раньше делал родной Animate)
    local function toolStep()
        local hold = tracks.toolnone
        local tool = char:FindFirstChildOfClass("Tool")
        local want = Settings.FixTool and tool ~= nil and tool:FindFirstChild("Handle") ~= nil and hum.Health > 0
        if want then
            if hold and not hold.IsPlaying then hold:Play(0.15) end
            local sv = tool:FindFirstChild("toolanim")
            if sv and sv:IsA("StringValue") then
                local v = sv.Value
                sv.Parent = nil
                if v == "Slash" and tracks.toolslash then
                    tracks.toolslash:Play(0)
                elseif v == "Lunge" and tracks.toollunge then
                    tracks.toollunge:Play(0)
                end
            end
        elseif hold and hold.IsPlaying then
            hold:Stop(0.15)
        end
    end

    table.insert(Driver.conns, hum.Jumping:Connect(function(active)
        if active then jumpT = os.clock() end
    end))

    table.insert(Driver.conns, RunService.Heartbeat:Connect(function()
        if Driver.gen ~= gen or not hum.Parent then return end

        toolStep()

        local state = hum:GetState()
        local root = hum.RootPart
        local vel = root and root.AssemblyLinearVelocity or Vector3.zero
        local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude

        if state == Enum.HumanoidStateType.Dead
            or state == Enum.HumanoidStateType.FallingDown
            or state == Enum.HumanoidStateType.Ragdoll
            or state == Enum.HumanoidStateType.GettingUp
            or state == Enum.HumanoidStateType.Physics
            or state == Enum.HumanoidStateType.PlatformStanding
            or state == Enum.HumanoidStateType.Seated then
            stopAll()
        elseif state == Enum.HumanoidStateType.Climbing then
            play("climb", vel.Y / 5)
        elseif state == Enum.HumanoidStateType.Jumping
            or (state == Enum.HumanoidStateType.Freefall and os.clock() - jumpT < 0.31) then
            play("jump", 1)
        elseif state == Enum.HumanoidStateType.Freefall then
            play("fall", 1)
        elseif state == Enum.HumanoidStateType.Swimming then
            play(speed > 1 and "swim" or "swimidle", 1)
        elseif speed > 0.75 and hum.MoveDirection.Magnitude > 0 then
            if speed > 22 then
                play("run", speed / 22)
            else
                play("walk", speed / 14.5)
            end
        else
            if (currentName ~= "idle1" and currentName ~= "idle2") or os.clock() > idleUntil then
                pickIdle()
            end
            play(tracks[idleChoice] and idleChoice or "idle1", 1)
        end
    end))
end

-- Встроенные эмоции (колесо эмоций, Humanoid:PlayEmote) — раньше обслуживал Animate
local function hookPlayEmote(char)
    local animate = char:FindFirstChild("Animate")
    local pe = animate and animate:FindFirstChild("PlayEmote")
    if pe and pe:IsA("BindableFunction") then
        pcall(function()
            pe.OnInvoke = function(emote)
                if typeof(emote) == "string" then
                    local id = BuiltinEmotes[emote]
                    if id then
                        task.spawn(playEmote, id, false)
                        return true
                    end
                elseif typeof(emote) == "Instance" and emote:IsA("Animation") then
                    task.spawn(playEmote, emote.AnimationId, false)
                    return true
                end
                return false
            end
        end)
    end
end

local function ApplySlots()
    if not hasCustom() then return end
    local animate, char = getAnimate()
    if not char then return end

    if animate then
        pcall(function() animate.Disabled = true end)
    end
    startDriver(buildIds(), char)
    hookPlayEmote(char)

    -- если игра включит Animate обратно — выключаем снова
    if animate then
        table.insert(Driver.conns, animate:GetPropertyChangedSignal("Disabled"):Connect(function()
            if not animate.Disabled then
                animate.Disabled = true
            end
        end))
    end
end

local function ApplyPack(pack)
    for _, s in ipairs(SLOTS) do Settings.Slots[s.key] = pack.name end
    ApplySlots()
end

local function ResetAnimations()
    Settings.Slots = {}
    stopDriver()
    local animate = getAnimate()
    if not animate then return end
    -- включение скрипта заново запускает его с нуля, он снова читает оригинальные ID
    pcall(function() animate.Disabled = false end)
end

local function onCharacter(char)
    stopEmote(0)
    stopDriver()
    if not Settings.AutoReapply then return end

    char:WaitForChild("Humanoid", 10)
    char:WaitForChild("Animate", 10)
    task.wait(0.3)
    ApplySlots()

    -- Если игра заменит/пересоздаст Animate — применяем заново
    connect(char.ChildAdded, function(child)
        if child.Name == "Animate" then
            task.wait(0.3)
            ApplySlots()
        end
    end)

    -- Подстраховка: после загрузки внешности Roblox может ещё раз выставить свои анимации
    for _, delay in ipairs({ 1, 2.5, 5 }) do
        task.delay(delay, function()
            if LocalPlayer.Character == char then ApplySlots() end
        end)
    end
end

connect(LocalPlayer.CharacterAdded, onCharacter)

-- /e dance, /e wave и т.д. (+ любые эмоции из каталога, которые ты уже видел в списке)
connect(LocalPlayer.Chatted, function(msg)
    local m = tostring(msg):lower()
    local name = m:match("^/e%s+(.-)%s*$") or m:match("^/emote%s+(.-)%s*$")
    if not name or name == "" then return end
    if BuiltinEmotes[name] then
        if Driver.active then task.spawn(playEmote, BuiltinEmotes[name], false) end
    elseif EmoteNames[name] then
        task.spawn(playEmote, EmoteNames[name], true)
    end
end)

return { Apply = ApplySlots, ApplyPack = ApplyPack, Reset = ResetAnimations, stop = stopDriver, state = Driver }
