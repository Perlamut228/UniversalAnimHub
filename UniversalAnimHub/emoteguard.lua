-- UniversalAnimHub / emoteguard.lua (модуль; грузится через Loader.lua)
-- Колесо эмоций Roblox берёт список из HumanoidDescription персонажа. Если список опустел
-- («No Emotes equipped») — возвращаем последний непустой, а если эмоций не было вообще —
-- заполняем колесо избранными эмоциями хаба и стандартными.
local Hub = ...
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Settings = Hub.Config.Settings
local Emote = Hub.Emote

local snapshot -- { emotes = {...}, names = {...} } — последнее состояние с экипированными эмоциями

local function dlog(msg)
    if Settings.Debug then print("[UAH] эмоции: " .. tostring(msg)) end
end

local function getDesc()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    return hum and hum:FindFirstChildOfClass("HumanoidDescription")
end

local function read(desc)
    local okE, emotes = pcall(function() return desc:GetEmotes() end)
    local okQ, equipped = pcall(function() return desc:GetEquippedEmotes() end)
    return (okE and type(emotes) == "table") and emotes or {}, (okQ and type(equipped) == "table") and equipped or {}
end

local function equippedNames(equipped)
    local list = {}
    for _, e in ipairs(equipped) do
        if type(e) == "table" and e.Name then
            table.insert(list, { slot = tonumber(e.Slot) or (#list + 1), name = tostring(e.Name) })
        end
    end
    table.sort(list, function(a, b) return a.slot < b.slot end)
    local names = {}
    for _, e in ipairs(list) do names[#names + 1] = e.name end
    return names
end

local function copyEmotes(emotes)
    local c = {}
    for name, ids in pairs(emotes) do
        if type(ids) == "table" then
            local l = {}
            for _, id in ipairs(ids) do l[#l + 1] = id end
            c[name] = l
        end
    end
    return c
end

-- набор по умолчанию: избранные из каталога + стандартные, максимум 8 слотов колеса
local function defaultSet()
    local emotes, names = {}, {}
    local function add(name, id)
        local clean = tostring(name):gsub("[^%w ]", ""):sub(1, 20)
        local num = tonumber(id)
        if clean == "" or not num or emotes[clean] or #names >= 8 then return end
        emotes[clean] = { num }
        names[#names + 1] = clean
    end
    local favs = {}
    for id, name in pairs(Settings.EmoteFavs) do favs[#favs + 1] = { id = id, name = name } end
    table.sort(favs, function(a, b) return tostring(a.name) < tostring(b.name) end)
    for _, f in ipairs(favs) do add(f.name, f.id) end
    for _, o in ipairs({ { "Wave", "wave" }, { "Point", "point" }, { "Dance", "dance" }, { "Dance2", "dance2" },
        { "Dance3", "dance3" }, { "Laugh", "laugh" }, { "Cheer", "cheer" } }) do
        add(o[1], Emote.Builtin[o[2]])
    end
    return emotes, names
end

local busy = false
local function ensure()
    if busy or Settings.EmoteGuard == false then return end
    local desc = getDesc()
    if not desc then return end
    local emotes, equipped = read(desc)
    local names = equippedNames(equipped)
    if #names > 0 then
        snapshot = { emotes = copyEmotes(emotes), names = names }
        return
    end

    busy = true
    local e, n
    if snapshot then
        e, n = snapshot.emotes, snapshot.names
        dlog("эмоции аватара пропали — восстанавливаю")
    else
        e, n = defaultSet()
        dlog("эмоций нет — заполняю колесо эмоциями хаба")
    end
    if #n > 0 then
        pcall(function() desc:SetEmotes(e) end)
        pcall(function() desc:SetEquippedEmotes(n) end)
    end
    busy = false
end

local alive = true
Hub.onDestroy(function() alive = false end)
task.spawn(function()
    while alive do
        task.wait(2)
        pcall(ensure)
    end
end)

return { ensure = ensure }
