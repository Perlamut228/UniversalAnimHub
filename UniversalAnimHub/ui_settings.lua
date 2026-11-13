-- UniversalAnimHub / ui_settings.lua (модуль; грузится через Loader.lua)
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
local L = Hub.UILib
local ACCENT, BG, BAR, CARD, CARD_HOVER, TEXT, MUTED, DARK_TEXT = L.ACCENT, L.BG, L.BAR, L.CARD, L.CARD_HOVER, L.TEXT, L.MUTED, L.DARK_TEXT
local new, corner, label, makeSwitch, makeBrowser = L.new, L.corner, L.label, L.makeSwitch, L.makeBrowser
local Settings = Hub.Config.Settings
local saveSettings = Hub.Config.save
local SLOTS = Hub.Config.SLOTS
local UI = Hub.UI
local SettingsPage = UI.Pages.settings
local Main = UI.Main
local DEFAULT_BIND, getBindKey = Hub.Config.DEFAULT_BIND, Hub.Config.getBindKey

-- ================= СТРАНИЦА: НАСТРОЙКИ =================
label(SettingsPage, "Настройки", UDim2.new(1, -24, 0, 28), UDim2.fromOffset(14, 12), 18, TEXT, Enum.Font.GothamBold)

local BindRow = new("Frame", {
    Size = UDim2.new(1, -24, 0, 56),
    Position = UDim2.fromOffset(12, 52),
    BackgroundColor3 = Color3.fromRGB(38, 38, 46),
}, SettingsPage)
corner(BindRow, 10)

label(BindRow, "Клавиша открытия / закрытия окна", UDim2.new(1, -190, 0, 20), UDim2.fromOffset(14, 8), 14)
label(BindRow, "Нажми «Изменить», затем нужную клавишу (Esc — отмена)", UDim2.new(1, -190, 0, 18), UDim2.fromOffset(14, 29), 11, MUTED, Enum.Font.Gotham)

local BindBtn = new("TextButton", {
    Size = UDim2.fromOffset(150, 34),
    Position = UDim2.new(1, -162, 0, 11),
    BackgroundColor3 = Color3.fromRGB(58, 58, 70),
    Text = Settings.Bind,
    TextColor3 = ACCENT,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
}, BindRow)
corner(BindBtn, 8)

local ChangeBtn = new("TextButton", {
    Size = UDim2.fromOffset(150, 34),
    Position = UDim2.fromOffset(12, 118),
    BackgroundColor3 = ACCENT,
    Text = "Изменить бинд",
    TextColor3 = DARK_TEXT,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
}, SettingsPage)
corner(ChangeBtn, 8)

local DefaultBtn = new("TextButton", {
    Size = UDim2.fromOffset(190, 34),
    Position = UDim2.fromOffset(172, 118),
    BackgroundColor3 = Color3.fromRGB(46, 46, 56),
    Text = "Сбросить на " .. DEFAULT_BIND,
    TextColor3 = TEXT,
    Font = Enum.Font.GothamSemibold,
    TextSize = 14,
}, SettingsPage)
corner(DefaultBtn, 8)

local function settingRow(y, title, subtitle, key)
    local row = new("Frame", {
        Size = UDim2.new(1, -24, 0, 56),
        Position = UDim2.fromOffset(12, y),
        BackgroundColor3 = Color3.fromRGB(38, 38, 46),
    }, SettingsPage)
    corner(row, 10)
    label(row, title, UDim2.new(1, -90, 0, 20), UDim2.fromOffset(14, 8), 14)
    label(row, subtitle, UDim2.new(1, -90, 0, 18), UDim2.fromOffset(14, 29), 11, MUTED, Enum.Font.Gotham)
    makeSwitch(row, UDim2.new(1, -60, 0, 16), Settings[key], function(v)
        Settings[key] = v
        saveSettings()
    end)
end
settingRow(168, "Фиксировать предмет в руке", "Нож и другие предметы держатся в позе удержания, а не за анимацией", "FixTool")
settingRow(232, "Эмоция сбивается при движении", "Ходьба, прыжок, лазание и плавание останавливают эмоцию", "EmoteStopOnMove")
settingRow(360, "Диагностика (консоль F9)", "Пишет в консоль вызовы эмоций и чужие анимации — для поиска проблем", "Debug")
settingRow(296, "Анимации игры поверх пака", "Эмоции и удары предметом самой игры (ММ2 и др.) не перекрываются паком", "ForeignBoost")

local Capturing = false

local function startCapture()
    Capturing = true
    BindBtn.Text = "Нажми клавишу..."
    BindBtn.TextColor3 = TEXT
end

ChangeBtn.MouseButton1Click:Connect(startCapture)
BindBtn.MouseButton1Click:Connect(startCapture)

DefaultBtn.MouseButton1Click:Connect(function()
    Capturing = false
    Settings.Bind = DEFAULT_BIND
    BindBtn.Text = Settings.Bind
    BindBtn.TextColor3 = ACCENT
    saveSettings()
end)

-- Глобальный обработчик клавиш (захват бинда + переключение окна)
connect(UIS.InputBegan, function(input, gameProcessed)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

    if Capturing then
        Capturing = false
        if input.KeyCode ~= Enum.KeyCode.Escape and input.KeyCode ~= Enum.KeyCode.Unknown then
            Settings.Bind = input.KeyCode.Name
            saveSettings()
        end
        BindBtn.Text = Settings.Bind
        BindBtn.TextColor3 = ACCENT
        return
    end

    if not gameProcessed and input.KeyCode == getBindKey() then
        Main.Visible = not Main.Visible
    end
end)


