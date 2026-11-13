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
-- страница прокручивается: настроек стало больше, чем помещается в окно
local SettingsPage = new("ScrollingFrame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    CanvasSize = UDim2.fromOffset(0, 660),
}, UI.Pages.settings)
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

local function settingRow(y, title, subtitle, key, onChange)
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
        if onChange then onChange(v) end
    end)
end

local function stepperRow(y, title, subtitle, key, minV, maxV, step, onChange)
    local row = new("Frame", {
        Size = UDim2.new(1, -24, 0, 56),
        Position = UDim2.fromOffset(12, y),
        BackgroundColor3 = Color3.fromRGB(38, 38, 46),
    }, SettingsPage)
    corner(row, 10)
    label(row, title, UDim2.new(1, -170, 0, 20), UDim2.fromOffset(14, 8), 14)
    label(row, subtitle, UDim2.new(1, -170, 0, 18), UDim2.fromOffset(14, 29), 11, MUTED, Enum.Font.Gotham)
    local val = new("TextLabel", {
        Size = UDim2.fromOffset(56, 30),
        Position = UDim2.new(1, -106, 0, 13),
        BackgroundTransparency = 1,
        TextColor3 = ACCENT,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        Text = "",
    }, row)
    local function show() val.Text = string.format("%.2fx", tonumber(Settings[key]) or 1) end
    show()
    local function bump(dir)
        local v = math.floor(((tonumber(Settings[key]) or 1) + dir * step) * 100 + 0.5) / 100
        Settings[key] = math.clamp(v, minV, maxV)
        show()
        saveSettings()
        if onChange then onChange(Settings[key]) end
    end
    local function stepBtn(x, text, dir)
        local b = new("TextButton", {
            Size = UDim2.fromOffset(30, 30),
            Position = UDim2.new(1, x, 0, 13),
            BackgroundColor3 = Color3.fromRGB(58, 58, 70),
            Text = text,
            TextColor3 = TEXT,
            Font = Enum.Font.GothamBold,
            TextSize = 16,
        }, row)
        corner(b, 8)
        b.MouseButton1Click:Connect(function() bump(dir) end)
    end
    stepBtn(-142, "-", -1)
    stepBtn(-44, "+", 1)
end

settingRow(168, "Фиксировать предмет в руке", "Нож и другие предметы держатся в позе удержания, а не за анимацией", "FixTool")
settingRow(228, "Эмоция сбивается при движении", "Ходьба, прыжок, лазание и плавание останавливают эмоцию", "EmoteStopOnMove")
settingRow(288, "Анимации игры поверх пака", "Эмоции и удары предметом самой игры (ММ2 и др.) не перекрываются паком", "ForeignBoost")
settingRow(348, "Диагностика (консоль F9)", "Пишет в консоль вызовы эмоций и чужие анимации — для поиска проблем", "Debug")
settingRow(408, "Кнопка «AH» на экране", "Открывает и закрывает окно касанием (для телефона)", "MobileButton", function(v)
    if UI.setToggleButton then UI.setToggleButton(v) end
end)
stepperRow(468, "Скорость анимаций пака", "Множитель для ходьбы, бега, стойки и т.д.", "AnimSpeed", 0.25, 3, 0.25)
stepperRow(528, "Скорость эмоций", "Применяется сразу, в том числе к играющей эмоции", "EmoteSpeed", 0.25, 3, 0.25, function(v)
    local t = Hub.Emote and Hub.Emote.track
    if t then pcall(function() t:AdjustSpeed(v) end) end
end)

local UnloadBtn = new("TextButton", {
    Size = UDim2.fromOffset(230, 34),
    Position = UDim2.fromOffset(12, 600),
    BackgroundColor3 = Color3.fromRGB(90, 40, 40),
    Text = "Выгрузить хаб полностью",
    TextColor3 = TEXT,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
}, SettingsPage)
corner(UnloadBtn, 8)
do
    local armed = false
    UnloadBtn.MouseButton1Click:Connect(function()
        if not armed then
            armed = true
            UnloadBtn.Text = "Нажми ещё раз для выгрузки"
            UnloadBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
            task.delay(2.5, function()
                armed = false
                if UnloadBtn.Parent then
                    UnloadBtn.Text = "Выгрузить хаб полностью"
                    UnloadBtn.BackgroundColor3 = Color3.fromRGB(90, 40, 40)
                end
            end)
            return
        end
        task.spawn(Hub.destroy) -- вернёт родной Animate и уберёт окно
    end)
end

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


