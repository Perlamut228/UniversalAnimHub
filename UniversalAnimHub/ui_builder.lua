-- UniversalAnimHub / ui_builder.lua (модуль; грузится через Loader.lua)
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
local BuilderPage = UI.Pages.builder
local Packs = Hub.Packs.list
local Driver = Hub.Driver
local refreshBuilder
local function updateSelection() if UI.updateSelection then UI.updateSelection() end end

-- ================= СТРАНИЦА: КОНСТРУКТОР =================
label(BuilderPage, "Выбери пак для каждой анимации отдельно (как в Roblox). Применяется сразу.", UDim2.new(1, -24, 0, 34), UDim2.fromOffset(14, 8), 13, MUTED, Enum.Font.Gotham)

local SlotButtons = {}
local Picker, PickerList, PickerTitle
local openPicker

for i, s in ipairs(SLOTS) do
    local row = new("Frame", {
        Size = UDim2.new(1, -24, 0, 44),
        Position = UDim2.fromOffset(12, 48 + (i - 1) * 52),
        BackgroundColor3 = Color3.fromRGB(38, 38, 46),
    }, BuilderPage)
    corner(row, 10)
    label(row, s.label, UDim2.new(0.4, 0, 1, 0), UDim2.fromOffset(14, 0), 14)
    local btn = new("TextButton", {
        Size = UDim2.new(0.55, -10, 0, 32),
        Position = UDim2.new(0.45, 0, 0, 6),
        BackgroundColor3 = Color3.fromRGB(58, 58, 70),
        Text = "",
        TextColor3 = ACCENT,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
    }, row)
    corner(btn, 8)
    SlotButtons[s.key] = btn
    btn.MouseButton1Click:Connect(function() openPicker(s) end)
end

local BuilderReset = new("TextButton", {
    Size = UDim2.fromOffset(190, 34),
    Position = UDim2.fromOffset(12, 48 + #SLOTS * 52 + 6),
    BackgroundColor3 = Color3.fromRGB(46, 46, 56),
    Text = "Сбросить сборку",
    TextColor3 = TEXT,
    Font = Enum.Font.GothamSemibold,
    TextSize = 14,
}, BuilderPage)
corner(BuilderReset, 8)
BuilderReset.MouseButton1Click:Connect(function()
    Driver.Reset()
    updateSelection()
    refreshBuilder()
    saveSettings()
end)

refreshBuilder = function()
    for _, s in ipairs(SLOTS) do
        SlotButtons[s.key].Text = (Settings.Slots[s.key] or "Default") .. "  ▼"
    end
end
refreshBuilder()

-- Выбор пака для слота
Picker = new("Frame", {
    Size = UDim2.new(1, -24, 1, -24),
    Position = UDim2.fromOffset(12, 12),
    BackgroundColor3 = Color3.fromRGB(32, 32, 38),
    Visible = false,
    ZIndex = 20,
}, BuilderPage)
corner(Picker, 12)
new("UIStroke", { Color = Color3.fromRGB(70, 70, 82), Thickness = 1 }, Picker)

PickerTitle = label(Picker, "", UDim2.new(1, -60, 0, 30), UDim2.fromOffset(14, 8), 15, TEXT, Enum.Font.GothamBold)
PickerTitle.ZIndex = 21

local PickerClose = new("TextButton", {
    Size = UDim2.fromOffset(28, 28),
    Position = UDim2.new(1, -38, 0, 8),
    BackgroundColor3 = Color3.fromRGB(58, 58, 68),
    Text = "X",
    TextColor3 = TEXT,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    ZIndex = 21,
}, Picker)
corner(PickerClose, 7)
PickerClose.MouseButton1Click:Connect(function() Picker.Visible = false end)

PickerList = new("ScrollingFrame", {
    Size = UDim2.new(1, -20, 1, -52),
    Position = UDim2.fromOffset(10, 44),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    CanvasSize = UDim2.new(),
    ZIndex = 21,
}, Picker)
local PickerLayout = new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, PickerList)
PickerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    PickerList.CanvasSize = UDim2.fromOffset(0, PickerLayout.AbsoluteContentSize.Y + 6)
end)

openPicker = function(slot)
    for _, c in ipairs(PickerList:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    PickerTitle.Text = "Пак для: " .. slot.label
    local cur = Settings.Slots[slot.key] or "Default"
    for i, pack in ipairs(Packs) do
        local b = new("TextButton", {
            Size = UDim2.new(1, -8, 0, 34),
            LayoutOrder = i,
            BackgroundColor3 = (pack.name == cur) and ACCENT or Color3.fromRGB(46, 46, 56),
            Text = pack.name .. (pack.removed and (pack.imported and "  (онлайн)" or "  (удалён)") or ""),
            TextColor3 = (pack.name == cur) and DARK_TEXT or TEXT,
            Font = Enum.Font.GothamSemibold,
            TextSize = 14,
            ZIndex = 22,
        }, PickerList)
        corner(b, 8)
        b.MouseButton1Click:Connect(function()
            Settings.Slots[slot.key] = pack.name
            Picker.Visible = false
            saveSettings()
            Driver.Apply()
            updateSelection()
            refreshBuilder()
        end)
    end
    Picker.Visible = true
end

UI.refreshBuilder = refreshBuilder
