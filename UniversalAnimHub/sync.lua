-- UniversalAnimHub / sync.lua (модуль; грузится через Loader.lua)
-- Синхронизация эмоций: находим эмоцию, которую играет другой игрок, запускаем ту же анимацию у себя
-- через движок эмоций хаба (покупка не нужна) и подгоняем время и скорость под его трек.
local Hub = ...
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local LocalPlayer = Players.LocalPlayer
local connect = Hub.connect
local Settings = Hub.Config.Settings
local Emote = Hub.Emote

local Sync = { range = 60 }

local function notify(msg, kind)
    local ui = Hub.UI
    if ui and ui.toast then pcall(ui.toast, msg, kind) end
end

-- анимации движения и предметов, которые эмоциями не считаются
local LOCO_FOLDERS = { "idle", "walk", "run", "jump", "fall", "climb", "swim", "swimidle", "sit", "toolnone", "toolslash", "toollunge" }
local defaultIds = {}
for _, id in pairs(Hub.Packs.find("Default").ids) do defaultIds[tostring(id)] = true end

local locoCache = setmetatable({}, { __mode = "k" })
local function locomotionIds(animate)
    if not animate then return {} end
    local cached = locoCache[animate]
    if cached then return cached end
    local set = {}
    for _, folderName in ipairs(LOCO_FOLDERS) do
        local f = animate:FindFirstChild(folderName)
        if f then
            for _, d in ipairs(f:GetDescendants()) do
                if d:IsA("Animation") then
                    local id = tostring(d.AnimationId):match("%d+")
                    if id then set[id] = true end
                end
            end
        end
    end
    locoCache[animate] = set
    return set
end

-- Эмоция игрока: { id, track, name } или nil
function Sync.detect(plr)
    local char = plr and plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if not animator then return nil end
    local loco = locomotionIds(char:FindFirstChild("Animate"))
    local ok, tracks = pcall(function() return animator:GetPlayingAnimationTracks() end)
    if not ok then return nil end

    local best, bestW
    for _, tr in ipairs(tracks) do
        local a = tr.Animation
        local id = a and tostring(a.AnimationId):match("%d+")
        if id and not loco[id] and not defaultIds[id] and tr.IsPlaying then
            local w = tr.WeightCurrent
            if w > 0.05 and (not bestW or w > bestW) then best, bestW = tr, w end
        end
    end
    if not best then return nil end
    return { id = tostring(best.Animation.AnimationId):match("%d+"), track = best, name = best.Name }
end

function Sync.distance(plr)
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if myRoot and root then return (root.Position - myRoot.Position).Magnitude end
end

-- название анимации (асинхронно, с кэшем)
local names, asked = {}, {}
function Sync.nameOf(id)
    if names[id] then return names[id] end
    if not asked[id] then
        asked[id] = true
        task.spawn(function()
            local ok, info = pcall(function() return MarketplaceService:GetProductInfo(tonumber(id), Enum.InfoType.Asset) end)
            if ok and type(info) == "table" and info.Name then names[id] = info.Name end
        end)
    end
    return nil
end

local function align(mine, theirs)
    pcall(function()
        local len = mine.Length
        if not len or len <= 0 then return end
        local t = theirs.TimePosition
        if mine.Looped then t = t % len else t = math.min(t, len - 0.05) end
        mine.TimePosition = t
        local sp = theirs.Speed
        if sp and sp > 0 then mine:AdjustSpeed(sp) end
    end)
end

local function drift(mine, theirs)
    local ok, d = pcall(function()
        local len = mine.Length
        local t = theirs.TimePosition
        if mine.Looped and len > 0 then t = t % len end
        local diff = math.abs(mine.TimePosition - t)
        if mine.Looped and len > 0 then diff = math.min(diff, len - diff) end
        return diff
    end)
    return ok and d or 0
end

-- true — запущено, false + причина — не вышло
function Sync.sync(plr)
    local d = Sync.detect(plr)
    if not d then return false, "у игрока сейчас нет эмоции" end
    task.spawn(function()
        local tr = Emote.play(d.id, false, true) -- грузит анимацию напрямую или через GetObjects
        if not tr then
            notify("Не удалось загрузить эмоцию игрока", "err")
            return
        end
        align(tr, d.track)
        -- пока обе эмоции играют, подтягиваем время при расхождении
        local gen = Emote.gen
        while Emote.gen == gen and Emote.track == tr and d.track.IsPlaying do
            task.wait(0.5)
            if Emote.gen ~= gen or Emote.track ~= tr then break end
            if drift(tr, d.track) > 0.2 then align(tr, d.track) end
        end
    end)
    return true
end

-- ближайший игрок в радиусе, у которого сейчас играет эмоция
function Sync.nearest()
    local best, bestDist
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local dist = Sync.distance(plr)
            if dist and dist <= Sync.range and (not bestDist or dist < bestDist) and Sync.detect(plr) then
                best, bestDist = plr, dist
            end
        end
    end
    return best, bestDist
end

function Sync.syncNearest()
    local plr, dist = Sync.nearest()
    if not plr then
        notify("Рядом (до " .. Sync.range .. " м) никто не танцует", "err")
        return
    end
    local ok, err = Sync.sync(plr)
    if ok then
        notify("Синхронизация с " .. plr.DisplayName .. " (" .. math.floor(dist) .. " м)", "ok")
    else
        notify(tostring(err), "err")
    end
end

connect(UIS.InputBegan, function(input, gameProcessed)
    if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local ok, key = pcall(function() return Enum.KeyCode[Settings.SyncBind] end)
    if ok and key and input.KeyCode == key then Sync.syncNearest() end
end)

return Sync
