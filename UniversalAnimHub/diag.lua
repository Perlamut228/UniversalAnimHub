-- UniversalAnimHub / diag.lua (модуль; грузится через Loader.lua)
-- Диагностика для настройки «Диагностика (консоль F9)»: что игра делает с предметами и анимациями.
local Hub = ...
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer
local Settings = Hub.Config.Settings
local own = Hub.Anim.own

local function log(msg)
    if Settings.Debug then print("[UAH] " .. tostring(msg)) end
end

local function describeTool(t)
    local anims = {}
    for _, d in ipairs(t:GetDescendants()) do
        if d:IsA("Animation") then
            table.insert(anims, d.Name .. "=" .. tostring(d.AnimationId))
        end
    end
    local attrs = 0
    for _ in pairs(t:GetAttributes()) do attrs += 1 end
    return ("Tool '%s' Handle=%s RequiresHandle=%s CanBeDropped=%s attrs=%d anims=[%s]"):format(
        t.Name, tostring(t:FindFirstChild("Handle") ~= nil), tostring(t.RequiresHandle),
        tostring(t.CanBeDropped), attrs, table.concat(anims, ", "))
end

local conns = {}
local function track(sig, fn) table.insert(conns, sig:Connect(fn)) end
local function clear()
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    conns = {}
end
Hub.onDestroy(clear)

local function watchContainer(container, where)
    track(container.ChildAdded, function(c)
        if Settings.Debug and c:IsA("Tool") then log(where .. ": + " .. describeTool(c)) end
    end)
    track(container.ChildRemoved, function(c)
        if Settings.Debug and c:IsA("Tool") then log(where .. ": - Tool '" .. c.Name .. "'") end
    end)
end

-- снимок текущего состояния (вызывается при включении диагностики)
local function dump()
    local ok, bp = pcall(function() return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack) end)
    log("хотбар Roblox (CoreGui Backpack) включён: " .. tostring(ok and bp or "неизвестно"))
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    for _, pair in ipairs({ { char, "персонаж" }, { backpack, "рюкзак" } }) do
        local c, where = pair[1], pair[2]
        if c then
            for _, t in ipairs(c:GetChildren()) do
                if t:IsA("Tool") then log(where .. ": есть " .. describeTool(t)) end
            end
        end
    end
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if animator then
        for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do
            local a = tr.Animation
            log(("играет: '%s' id=%s priority=%s looped=%s %s"):format(
                tr.Name, a and a.AnimationId or "?", tostring(tr.Priority), tostring(tr.Looped),
                own[tr] and "(хаб)" or "(игра)"))
        end
    end
end

local function attach(char)
    clear()
    task.spawn(function()
        local hum = char:WaitForChild("Humanoid", 10)
        if not hum or LocalPlayer.Character ~= char then return end
        local animator = hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 5)
        if animator then
            track(animator.AnimationPlayed, function(tr)
                if own[tr] or not Settings.Debug then return end
                pcall(function()
                    local a = tr.Animation
                    log(("анимация игры '%s' id=%s priority=%s looped=%s"):format(
                        tr.Name, a and a.AnimationId or "?", tostring(tr.Priority), tostring(tr.Looped)))
                end)
            end)
        end
    end)
    watchContainer(char, "персонаж")
    task.spawn(function()
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack", 10)
        if bp and LocalPlayer.Character == char then watchContainer(bp, "рюкзак") end
    end)
end

Hub.connect(LocalPlayer.CharacterAdded, attach)
if LocalPlayer.Character then attach(LocalPlayer.Character) end

return { dump = dump }
