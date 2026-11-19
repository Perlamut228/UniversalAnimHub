-- UniversalAnimHub / emoteguard.lua (модуль; грузится через Loader.lua)
-- Колесо эмоций Roblox берёт список из HumanoidDescription персонажа.
--  * Защита: если список пуст («No Emotes equipped»), возвращаем настоящие эмоции аккаунта
--    (последнее непустое состояние или Players:GetHumanoidDescriptionFromUserId).
--  * Заполнение (настройка «Заполнять колесо эмоциями хаба»): избранные эмоции из каталога и
--    стандартные добавляются в СВОБОДНЫЕ слоты колеса (всего 8), эмоции аккаунта остаются на месте.
local Hub = ...
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Settings = Hub.Config.Settings
local Emote = Hub.Emote

local snapshot  -- { emotes, names } — последнее состояние с экипированными эмоциями
local account   -- кэш эмоций аккаунта: таблица, false (нет/ошибка) или nil (ещё не пробовали)
local accountTriedAt = 0

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

-- эмоции аккаунта игрока с серверов Roblox (не зависят от того, что сделала игра с персонажем)
local function fetchAccount()
    if account then return account end
    if account == false and os.clock() - accountTriedAt < 60 then return nil end
    accountTriedAt = os.clock()
    local ok, d = pcall(function() return Players:GetHumanoidDescriptionFromUserId(LocalPlayer.UserId) end)
    if ok and d then
        local emotes, equipped = read(d)
        local names = equippedNames(equipped)
        pcall(function() d:Destroy() end)
        if #names > 0 then
            account = { emotes = copyEmotes(emotes), names = names }
            dlog("загрузил эмоции аккаунта: " .. #names .. " в колесе")
            return account
        end
        dlog("у аккаунта нет экипированных эмоций")
    else
        dlog("не удалось получить эмоции аккаунта: " .. tostring(d))
    end
    account = false
    return nil
end

-- необязательный набор хаба: избранные из каталога + стандартные, максимум 8 слотов
local function hubSet()
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

local hubAdded = {} -- имена эмоций, добавленных хабом (чтобы отличать от настоящих)

local function sameList(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

local busy = false
local function ensure()
    local guard = Settings.EmoteGuard ~= false
    local fill = Settings.EmoteFill == true
    if busy or not (guard or fill) then return end
    local desc = getDesc()
    if not desc then return end

    local emotes, equipped = read(desc)
    local names = equippedNames(equipped)

    -- настоящие эмоции = то, что в колесе сейчас, без добавленного хабом
    local realNames, realEmotes = {}, {}
    for _, n in ipairs(names) do
        if not hubAdded[n] then
            realNames[#realNames + 1] = n
            realEmotes[n] = emotes[n]
        end
    end

    busy = true
    local baseEmotes, baseNames = realEmotes, realNames
    if #realNames > 0 then
        snapshot = { emotes = copyEmotes(realEmotes), names = realNames }
    elseif guard then
        if snapshot then
            baseEmotes, baseNames = snapshot.emotes, snapshot.names
        else
            local acc = fetchAccount() -- может ждать ответа сервера
            if acc then baseEmotes, baseNames = acc.emotes, acc.names end
        end
    end

    -- целевой набор: настоящие эмоции + (если включено) эмоции хаба в свободные слоты
    local targetEmotes, targetNames, added = copyEmotes(baseEmotes), {}, {}
    for _, n in ipairs(baseNames) do targetNames[#targetNames + 1] = n end
    if fill then
        local he, hn = hubSet()
        for _, n in ipairs(hn) do
            if #targetNames >= 8 then break end
            if not targetEmotes[n] then
                targetEmotes[n] = he[n]
                targetNames[#targetNames + 1] = n
                added[n] = true
            end
        end
        if #targetNames >= 8 and #hn > 0 and next(added) == nil then
            dlog("колесо заполнено (8/8) эмоциями аккаунта — для эмоций хаба нет свободных слотов")
        end
    end

    desc = getDesc() -- за время ожидания персонаж мог смениться
    if desc and not sameList(names, targetNames) then
        pcall(function() desc:SetEmotes(targetEmotes) end)
        pcall(function() desc:SetEquippedEmotes(targetNames) end)
        dlog("обновил колесо: " .. #targetNames .. " эм. (хаб добавил: " .. (function()
            local c = 0 for _ in pairs(added) do c += 1 end return c end)() .. ")")
    end
    hubAdded = added
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
