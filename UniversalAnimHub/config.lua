-- UniversalAnimHub / config.lua (модуль; грузится через Loader.lua)
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

-- ================= НАСТРОЙКИ =================
local FILE = "UniversalAnimHub.json"
local DEFAULT_BIND = "RightControl"
local Settings = {
    Bind = DEFAULT_BIND,
    AutoReapply = true,
    FixTool = true,          -- фиксировать позу удержания предмета
    EmoteStopOnMove = true,  -- эмоция сбивается при ходьбе
    Debug = false,           -- диагностика в консоль (F9)
    EmoteBind = "B",         -- клавиша быстрой панели эмоций
    AnimSpeed = 1,           -- множитель скорости анимаций пака
    EmoteSpeed = 1,          -- множитель скорости эмоций
    MobileButton = UIS.TouchEnabled, -- плавающая кнопка открытия окна
    ForeignBoostAll = false, -- агрессивно: поднимать ВСЕ чужие анимации, кроме ходьбы/бега/стойки
    ForeignBoost = true,     -- анимации самой игры (эмоции, удары предметом) поверх пака
    Favorites = {},          -- избранные паки
    Slots = {},              -- slot -> имя пака (конструктор)
    EmoteFavs = {},          -- id эмоции -> имя
    Imported = {},           -- имя -> ids (паки из онлайн-каталога)
    IdNames = {},            -- кэш названий ассетов
    Fixes = {},              -- исправленные ids паков
    HealDone = {},           -- какие паки уже проверены
    Presets = {},            -- именованные сборки конструктора
}

pcall(function()
    if isfile and isfile(FILE) then
        local data = HttpService:JSONDecode(readfile(FILE))
        for k, v in pairs(data) do Settings[k] = v end
    end
end)
for _, k in ipairs({ "Favorites", "Slots", "EmoteFavs", "Imported", "IdNames", "Fixes", "HealDone", "Presets" }) do
    if type(Settings[k]) ~= "table" then Settings[k] = {} end
end

Settings.AnimSpeed = math.clamp(tonumber(Settings.AnimSpeed) or 1, 0.25, 3)
Settings.EmoteSpeed = math.clamp(tonumber(Settings.EmoteSpeed) or 1, 0.25, 3)
Settings.MobileButton = Settings.MobileButton == true
if type(Settings.EmoteBind) ~= "string" then Settings.EmoteBind = "B" end

local function saveSettings()
    pcall(function()
        if writefile then writefile(FILE, HttpService:JSONEncode(Settings)) end
    end)
end

local function getBindKey()
    local ok, key = pcall(function() return Enum.KeyCode[Settings.Bind] end)
    if ok and key then return key end
    return Enum.KeyCode.RightControl
end

-- ================= СЛОТЫ КОНСТРУКТОРА =================
local SLOTS = {
    { key = "idle",  label = "Стойка (Idle)" },
    { key = "walk",  label = "Ходьба (Walk)" },
    { key = "run",   label = "Бег (Run)" },
    { key = "jump",  label = "Прыжок (Jump)" },
    { key = "climb", label = "Лазание (Climb)" },
    { key = "fall",  label = "Падение (Fall)" },
    { key = "swim",  label = "Плавание (Swim)" },
}

return { Settings = Settings, save = saveSettings, getBindKey = getBindKey, SLOTS = SLOTS, DEFAULT_BIND = DEFAULT_BIND, FILE = FILE }
