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
local own = Hub.Anim.own
local classifyName = Hub.Anim.classifyName

local function dlog(msg, noToast)
    if not Settings.Debug then return end
    print("[UAH] " .. tostring(msg))
    local ui = Hub.UI
    if not noToast and ui and ui.toast then pcall(ui.toast, "UAH: " .. tostring(msg)) end
end

local function describe(v)
    local ty = typeof(v)
    if ty == "Instance" then
        local ok, id = pcall(function() return v.AnimationId end)
        return "Instance:" .. v.ClassName .. (ok and (" " .. tostring(id)) or "")
    end
    return ty .. ":" .. tostring(v)
end

-- ================= ПРИМЕНЕНИЕ АНИМАЦИЙ (драйвер) =================
-- Мы отключаем родной Animate и сами проигрываем анимации по состояниям Humanoid.
-- Заодно берём на себя то, что делал Animate: поза предмета в руке и встроенные эмоции.
local Driver = { gen = 0, conns = {}, tracks = {}, active = false, char = nil, animate = nil, sig = nil }

local LOOPED = {
    idle1 = true, idle2 = true, walk = true, run = true, climb = true,
    fall = true, swim = true, swimidle = true,
}
local TOOL_IDS = { toolnone = "507768375", toolslash = "522635514", toollunge = "522638767" }

local function stopDriver()
    Driver.gen += 1
    Driver.active = false
    Driver.char, Driver.animate, Driver.sig = nil, nil, nil
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

local function isActionPriority(p)
    return p == Enum.AnimationPriority.Action or p == Enum.AnimationPriority.Action2
        or p == Enum.AnimationPriority.Action3 or p == Enum.AnimationPriority.Action4
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
    local defaults = findPack("Default").ids
    local function loadInto(name, id, setup)
        task.spawn(function()
            local tr = loadTrack(animator, id, false, 3)
            -- повтор через GetObjects, затем запасной стандартный слот (иначе слот молча пустой)
            if not tr and Driver.gen == gen then tr = loadTrack(animator, id, true, 4) end
            if not tr and Driver.gen == gen and defaults[name] and defaults[name] ~= tostring(id) then
                tr = loadTrack(animator, defaults[name], false, 3)
                if tr then dlog("слот '" .. name .. "' не загрузился, взят стандартный", true) end
            end
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
        if current and speed then current:AdjustSpeed(speed * (Settings.AnimSpeed or 1)) end
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
    local holdYield, toolSince, toolSeen = false, 0, false
    local lastScan, foreignCached = 0, false
    local function toolStep()
        local hold = tracks.toolnone
        local tool = char:FindFirstChildOfClass("Tool")
        if tool and not toolSeen then
            toolSeen = true
            toolSince = os.clock()
        elseif not tool then
            toolSeen = false
        end
        local want = Settings.FixTool and tool ~= nil and tool:FindFirstChild("Handle") ~= nil and hum.Health > 0
        if want then
            -- Если игра сама играет анимацию предмета (удар, своя поза) — уступаем ей,
            -- иначе наша поза удержания перекрывает её и предмет "стоит как вкопанный".
            -- скан чужих треков 10 раз в секунду, а не каждый кадр
            local now = os.clock()
            if now - lastScan > 0.1 then
                lastScan = now
                local f = false
                for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
                    if not own[t] and t.IsPlaying and isActionPriority(t.Priority) then
                        f = true
                        break
                    end
                end
                foreignCached = f
            end
            local foreign = foreignCached
            if foreign ~= holdYield then
                holdYield = foreign
                if hold and hold.IsPlaying then hold:AdjustWeight(foreign and 0.001 or 1, 0.1) end
            end
            if hold and not hold.IsPlaying then hold:Play(0.15, holdYield and 0.001 or 1) end
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
        else
            holdYield = false
            foreignCached = false
            if hold and hold.IsPlaying then hold:Stop(0.15) end
        end
    end

    -- Анимации самой игры (эмоции, удары предметом) не должны перекрываться паком:
    -- если у трека низкий приоритет, поднимаем его выше анимаций пака.
    table.insert(Driver.conns, animator.AnimationPlayed:Connect(function(tr)
        if own[tr] then return end
        if not Settings.ForeignBoost then return end
        pcall(function()
            local p = tr.Priority
            if p == Enum.AnimationPriority.Core or p == Enum.AnimationPriority.Idle or p == Enum.AnimationPriority.Movement then
                -- «агрессивный» режим: зацикленные эмоции игры тоже поднимаем, если по названию это не ходьба/бег/стойка
                local aggressive = Settings.ForeignBoostAll and classifyName(tr.Name) == nil
                if (not tr.Looped) or aggressive or (toolSeen and os.clock() - toolSince < 1.5) then
                    tr.Priority = Enum.AnimationPriority.Action2
                end
            end
        end)
    end))

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

-- Эмоции, экипированные на аватаре (HumanoidDescription)
local function findDescEmote(hum, name)
    local desc = hum and hum:FindFirstChildOfClass("HumanoidDescription")
    if not desc then return nil end
    local ok, emotes = pcall(function() return desc:GetEmotes() end)
    if not ok or type(emotes) ~= "table" then return nil end
    local lname = tostring(name):lower()
    for n, list in pairs(emotes) do
        if tostring(n):lower() == lname and type(list) == "table" and list[1] then
            return tostring(list[1])
        end
    end
end

-- Встроенные эмоции (колесо эмоций, панель «Игровые эмоции», Humanoid:PlayEmote) — раньше обслуживал Animate.
-- Возвращаем (true, трек), как это делал родной скрипт.
local function hookPlayEmote(char)
    local animate = char:FindFirstChild("Animate")
    if not animate then
        dlog("Animate не найден — PlayEmote не подключён")
        return
    end
    task.spawn(function()
        local pe = animate:FindFirstChild("PlayEmote") or animate:WaitForChild("PlayEmote", 5)
        if not (pe and pe:IsA("BindableFunction")) then
            dlog("PlayEmote не найден внутри Animate")
            return
        end
        local okSet, errSet = pcall(function()
            pe.OnInvoke = function(emote)
                local ok, track = pcall(function()
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    local ty = typeof(emote)
                    if ty == "string" then
                        local lower = emote:lower()
                        local id = BuiltinEmotes[emote] or BuiltinEmotes[lower]
                        local prefer = false
                        if not id and emote:match("^%d+$") then id = emote; prefer = true end
                        if not id then id = EmoteNames[lower]; prefer = true end
                        if not id then id = findDescEmote(hum, emote); prefer = true end
                        if id then return playEmote(id, prefer, true) end
                    elseif ty == "number" then
                        return playEmote(emote, true, true)
                    elseif ty == "Instance" and emote:IsA("Animation") then
                        return playEmote(emote.AnimationId, false, true)
                    elseif ty == "table" and emote.AnimationId then
                        return playEmote(emote.AnimationId, false, true)
                    end
                    return nil
                end)
                dlog("PlayEmote(" .. describe(emote) .. ") -> " .. tostring(ok and track ~= nil))
                if ok and track then return true, track end
                return false
            end
        end)
        dlog(okSet and "PlayEmote подключён" or ("не удалось подключить PlayEmote: " .. tostring(errSet)))
    end)
end

local touchedAnimate, charConn

local function signature(ids)
    local keys = {}
    for k in pairs(ids) do keys[#keys + 1] = k end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. tostring(ids[k]) end
    return table.concat(parts, ";")
end

-- Идемпотентно: если персонаж, сборка и Animate те же — ничего не перезапускаем
-- (раньше при каждом респавне драйвер перезагружал все треки 4-5 раз подряд).
local function ApplySlots(force)
    if not hasCustom() then return end
    local animate, char = getAnimate()
    if not char then return end
    if not char:FindFirstChildOfClass("Humanoid") then return end

    local ids = buildIds()
    local sig = signature(ids)
    if not force and Driver.active and Driver.char == char and Driver.sig == sig
        and Driver.animate == animate and (animate == nil or animate.Disabled) then
        return
    end

    if animate then
        pcall(function() animate.Disabled = true end)
        touchedAnimate = animate
    end
    startDriver(ids, char)
    Driver.char, Driver.sig, Driver.animate = char, sig, animate
    hookPlayEmote(char)

    -- если игра включит Animate обратно — выключаем снова
    if animate then
        table.insert(Driver.conns, animate:GetPropertyChangedSignal("Disabled"):Connect(function()
            if not animate.Disabled then
                dlog("игра включила Animate — выключаю снова", true)
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

-- Полная остановка: возвращаем родной Animate (раньше после выгрузки хаба персонаж оставался без анимаций)
local function shutdown()
    stopDriver()
    if charConn then pcall(function() charConn:Disconnect() end) charConn = nil end
    local a = touchedAnimate
    touchedAnimate = nil
    if a then pcall(function() a.Disabled = false end) end
end
Hub.onDestroy(shutdown)

local function onCharacter(char)
    stopEmote(0)
    stopDriver()
    if charConn then pcall(function() charConn:Disconnect() end) charConn = nil end
    if not Settings.AutoReapply then return end

    char:WaitForChild("Humanoid", 10)
    char:WaitForChild("Animate", 10)
    task.wait(0.3)
    if LocalPlayer.Character ~= char then return end
    ApplySlots()

    -- Если игра заменит/пересоздаст Animate — применяем заново
    charConn = char.ChildAdded:Connect(function(child)
        if child.Name == "Animate" then
            task.wait(0.3)
            if LocalPlayer.Character == char then ApplySlots() end
        end
    end)

    -- Подстраховка после загрузки внешности; вызовы дешёвые, т.к. ApplySlots идемпотентен
    for _, delay in ipairs({ 1, 2.5, 5 }) do
        task.delay(delay, function()
            if LocalPlayer.Character == char then ApplySlots() end
        end)
    end
end

connect(LocalPlayer.CharacterAdded, onCharacter)
if LocalPlayer.Character then task.spawn(onCharacter, LocalPlayer.Character) end

-- /e dance, /e wave и т.д. (+ эмоции аватара и эмоции из каталога, которые ты уже видел в списке)
connect(LocalPlayer.Chatted, function(msg)
    local m = tostring(msg):lower()
    local name = m:match("^/e%s+(.-)%s*$") or m:match("^/emote%s+(.-)%s*$")
    if not name or name == "" then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if BuiltinEmotes[name] then
        if Driver.active then task.spawn(playEmote, BuiltinEmotes[name], false, true) end
    elseif EmoteNames[name] then
        task.spawn(playEmote, EmoteNames[name], true)
    elseif Driver.active then
        local id = findDescEmote(hum, name)
        if id then task.spawn(playEmote, id, true, true) end
    end
end)

return { Apply = ApplySlots, ApplyPack = ApplyPack, Reset = ResetAnimations, stop = shutdown, state = Driver }
