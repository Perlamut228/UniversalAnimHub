-- UniversalAnimHub / anim.lua (модуль; грузится через Loader.lua)
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

-- ================= ЗАГРУЗКА ТРЕКОВ =================
-- Анимацию можно загрузить напрямую по ID или (для каталожных ассетов) достать настоящий
-- AnimationId через GetObjects. Пробуем оба варианта и запоминаем, какой сработал.
local Own = setmetatable({}, { __mode = "k" }) -- треки, загруженные хабом
local ResolveCache = {}

local function objectsAnimId(id)
    local ok, objs = pcall(function() return game:GetObjects("rbxassetid://" .. id) end)
    if ok and type(objs) == "table" then
        for _, o in ipairs(objs) do
            local a = o:IsA("Animation") and o or o:FindFirstChildWhichIsA("Animation", true)
            if a and a.AnimationId ~= "" then
                local r = a.AnimationId
                pcall(function() o:Destroy() end)
                return r
            end
            pcall(function() o:Destroy() end)
        end
    end
end

local function tryLoad(animator, animId, timeout)
    local a = Instance.new("Animation")
    a.AnimationId = animId
    local ok, tr = pcall(function() return animator:LoadAnimation(a) end)
    if not ok or not tr then return nil end
    local t0 = os.clock()
    while tr.Length == 0 and os.clock() - t0 < timeout do task.wait(0.05) end
    if tr.Length > 0 then Own[tr] = true return tr end
    pcall(function() tr:Destroy() end)
    return nil
end

local function loadTrack(animator, rawId, preferObjects, timeout)
    rawId = tostring(rawId or ""):match("%d+")
    if not rawId then return nil end
    timeout = timeout or 3
    local cached = ResolveCache[rawId]
    if cached then return tryLoad(animator, cached, timeout) end

    local function direct()
        local r = "rbxassetid://" .. rawId
        local tr = tryLoad(animator, r, timeout)
        if tr then ResolveCache[rawId] = r end
        return tr
    end
    local function viaObjects()
        local r = objectsAnimId(rawId)
        if r then
            local tr = tryLoad(animator, r, timeout)
            if tr then ResolveCache[rawId] = r end
            return tr
        end
    end

    if preferObjects then
        return viaObjects() or direct()
    end
    return direct() or viaObjects()
end

-- ================= АВТО-ИСПРАВЛЕНИЕ ПЕРЕПУТАННЫХ АНИМАЦИЙ =================
-- Берём реальное название каждого ассета (например "Popular - Walk") и по нему проверяем слот.
local HEAL_ORDER = { "idle1", "idle2", "walk", "run", "jump", "climb", "fall", "swim", "swimidle" }
local HEAL_TARGET = {
    idle = { "idle1", "idle2" }, walk = { "walk" }, run = { "run" }, jump = { "jump" },
    climb = { "climb" }, fall = { "fall" }, swim = { "swim" }, swimidle = { "swimidle" },
}

local function classifyName(name)
    if type(name) ~= "string" then return nil end
    local s = (name:gsub("(%l)(%u)", "%1 %2")):lower()
    local words = {}
    for w in s:gmatch("%a+") do words[w] = true end
    local swim = words.swim or words.swimming
    if swim and words.idle then return "swimidle" end
    if swim then return "swim" end
    if words.idle then return "idle" end
    if words.climb or words.climbing then return "climb" end
    if words.fall or words.falling then return "fall" end
    if words.jump or words.jumping then return "jump" end
    if words.run or words.running then return "run" end
    if words.walk or words.walking then return "walk" end
    return nil
end

local failedNames = {}
local function nameOf(id)
    local cached = Settings.IdNames[id]
    if cached then return cached end
    if failedNames[id] then return nil end
    local ok, info = pcall(function() return MarketplaceService:GetProductInfo(tonumber(id)) end)
    task.wait(0.12)
    if ok and info and info.Name then
        Settings.IdNames[id] = info.Name
        return info.Name
    end
    failedNames[id] = true
    return nil
end

-- возвращает список изменений (или nil, если менять нечего / данных мало)
local function healPack(pack)
    local byCat, unknown = {}, {}
    for _, slot in ipairs(HEAL_ORDER) do
        local id = pack.ids[slot]
        local c = classifyName(nameOf(id))
        if c then
            byCat[c] = byCat[c] or {}
            table.insert(byCat[c], id)
        else
            unknown[id] = true
        end
    end
    for c, list in pairs(byCat) do
        if (c == "idle" and #list > 2) or (c ~= "idle" and #list > 1) then return nil end
    end

    local new, placed = {}, {}
    for c, slots in pairs(HEAL_TARGET) do
        local list = byCat[c]
        if list then
            for i, slot in ipairs(slots) do
                if list[i] then new[slot] = list[i]; placed[list[i]] = true end
            end
        end
    end
    -- неопознанные ID оставляем на своих местах, если место свободно
    for _, slot in ipairs(HEAL_ORDER) do
        local id = pack.ids[slot]
        if not new[slot] and unknown[id] and not placed[id] then
            new[slot] = id; placed[id] = true
        end
    end
    -- остальное добиваем оставшимися ID
    local leftovers = {}
    for _, slot in ipairs(HEAL_ORDER) do
        local id = pack.ids[slot]
        if not placed[id] then table.insert(leftovers, id); placed[id] = true end
    end
    local li = 1
    for _, slot in ipairs(HEAL_ORDER) do
        if not new[slot] then
            new[slot] = leftovers[li] or pack.ids[slot]
            li += 1
        end
    end

    local changes = {}
    for _, slot in ipairs(HEAL_ORDER) do
        if new[slot] ~= pack.ids[slot] then table.insert(changes, slot) end
    end
    if #changes > 0 then
        pack.ids = new
        Settings.Fixes[pack.name] = new
    end
    return changes
end

return { own = Own, loadTrack = loadTrack, objectsAnimId = objectsAnimId, classifyName = classifyName, nameOf = nameOf, healPack = healPack }
