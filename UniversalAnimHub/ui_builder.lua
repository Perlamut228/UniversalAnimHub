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
local hasCustom = Hub.Packs.hasCustom
local toast = UI.toast
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

-- ================= ПРЕСЕТЫ =================
local PresetsBtn = new("TextButton", {
    Size = UDim2.fromOffset(150, 34),
    Position = UDim2.fromOffset(212, 48 + #SLOTS * 52 + 6),
    BackgroundColor3 = ACCENT,
    Text = "Пресеты",
    TextColor3 = DARK_TEXT,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
}, BuilderPage)
corner(PresetsBtn, 8)

local PresetPanel = new("Frame", {
    Size = UDim2.new(1, -24, 1, -24),
    Position = UDim2.fromOffset(12, 12),
    BackgroundColor3 = Color3.fromRGB(32, 32, 38),
    Visible = false,
    ZIndex = 20,
}, BuilderPage)
corner(PresetPanel, 12)
new("UIStroke", { Color = Color3.fromRGB(70, 70, 82), Thickness = 1 }, PresetPanel)

local PresetTitle = label(PresetPanel, "Пресеты сборок", UDim2.new(1, -60, 0, 30), UDim2.fromOffset(14, 8), 15, TEXT, Enum.Font.GothamBold)
PresetTitle.ZIndex = 21

local PresetClose = new("TextButton", {
    Size = UDim2.fromOffset(28, 28),
    Position = UDim2.new(1, -38, 0, 8),
    BackgroundColor3 = Color3.fromRGB(58, 58, 68),
    Text = "X",
    TextColor3 = TEXT,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    ZIndex = 21,
}, PresetPanel)
corner(PresetClose, 7)

local PresetName = new("TextBox", {
    Size = UDim2.new(1, -190, 0, 34),
    Position = UDim2.fromOffset(14, 46),
    BackgroundColor3 = Color3.fromRGB(46, 46, 56),
    PlaceholderText = "Название пресета...",
    PlaceholderColor3 = MUTED,
    Text = "",
    TextColor3 = TEXT,
    Font = Enum.Font.Gotham,
    TextSize = 14,
    ClearTextOnFocus = false,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 21,
}, PresetPanel)
corner(PresetName, 8)
new("UIPadding", { PaddingLeft = UDim.new(0, 10) }, PresetName)

local PresetSave = new("TextButton", {
    Size = UDim2.fromOffset(150, 34),
    Position = UDim2.new(1, -164, 0, 46),
    BackgroundColor3 = ACCENT,
    Text = "Сохранить сборку",
    TextColor3 = DARK_TEXT,
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    ZIndex = 21,
}, PresetPanel)
corner(PresetSave, 8)

local PresetList = new("ScrollingFrame", {
    Size = UDim2.new(1, -20, 1, -100),
    Position = UDim2.fromOffset(10, 90),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    CanvasSize = UDim2.new(),
    ZIndex = 21,
}, PresetPanel)
local PresetLayout = new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, PresetList)
PresetLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    PresetList.CanvasSize = UDim2.fromOffset(0, PresetLayout.AbsoluteContentSize.Y + 6)
end)

local function copySlots(src)
    local c = {}
    for k, v in pairs(src) do c[k] = v end
    return c
end

local function presetSummary(p)
    local seen, list = {}, {}
    for _, s in ipairs(SLOTS) do
        local v = p[s.key] or "Default"
        if not seen[v] then
            seen[v] = true
            table.insert(list, v)
        end
    end
    return table.concat(list, ", ")
end

local refreshPresets

local function applyPreset(name)
    local p = Settings.Presets[name]
    if not p then return end
    Settings.Slots = copySlots(p)
    saveSettings()
    if hasCustom() then Driver.Apply() else Driver.Reset() end
    updateSelection()
    refreshBuilder()
    PresetPanel.Visible = false
    toast("Пресет применён: " .. name)
end

refreshPresets = function()
    for _, c in ipairs(PresetList:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
    end
    local names = {}
    for n in pairs(Settings.Presets) do table.insert(names, n) end
    table.sort(names)

    if #names == 0 then
        local e = label(PresetList, "Пока пусто. Собери сборку и нажми «Сохранить сборку».", UDim2.new(1, -8, 0, 40), UDim2.new(), 13, MUTED, Enum.Font.Gotham)
        e.ZIndex = 22
        e.TextWrapped = true
        return
    end

    for i, name in ipairs(names) do
        local row = new("Frame", {
            Size = UDim2.new(1, -8, 0, 46),
            BackgroundColor3 = Color3.fromRGB(46, 46, 56),
            LayoutOrder = i,
            ZIndex = 22,
        }, PresetList)
        corner(row, 8)
        local t1 = label(row, name, UDim2.new(1, -160, 0, 20), UDim2.fromOffset(12, 5), 14)
        t1.ZIndex = 23
        local t2 = label(row, presetSummary(Settings.Presets[name]), UDim2.new(1, -160, 0, 16), UDim2.fromOffset(12, 25), 11, MUTED, Enum.Font.Gotham)
        t2.ZIndex = 23

        local apply = new("TextButton", {
            Size = UDim2.fromOffset(90, 30),
            Position = UDim2.new(1, -144, 0, 8),
            BackgroundColor3 = ACCENT,
            Text = "Применить",
            TextColor3 = DARK_TEXT,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            ZIndex = 23,
        }, row)
        corner(apply, 7)
        apply.MouseButton1Click:Connect(function() applyPreset(name) end)

        local del = new("TextButton", {
            Size = UDim2.fromOffset(38, 30),
            Position = UDim2.new(1, -46, 0, 8),
            BackgroundColor3 = Color3.fromRGB(90, 40, 40),
            Text = "✕",
            TextColor3 = TEXT,
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            ZIndex = 23,
        }, row)
        corner(del, 7)
        local armed = false
        del.MouseButton1Click:Connect(function()
            if not armed then
                armed = true
                del.Text = "?"
                del.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
                task.delay(2.5, function()
                    armed = false
                    if del.Parent then
                        del.Text = "✕"
                        del.BackgroundColor3 = Color3.fromRGB(90, 40, 40)
                    end
                end)
                return
            end
            Settings.Presets[name] = nil
            saveSettings()
            refreshPresets()
        end)
    end
end

PresetSave.MouseButton1Click:Connect(function()
    local name = PresetName.Text:gsub("^%s+", ""):gsub("%s+$", "")
    name = name:sub(1, 30)
    if name == "" then
        toast("Введи название пресета")
        return
    end
    if not hasCustom() then
        toast("Сначала выбери анимации в конструкторе")
        return
    end
    Settings.Presets[name] = copySlots(Settings.Slots)
    saveSettings()
    PresetName.Text = ""
    refreshPresets()
    toast("Сохранено: " .. name)
end)

PresetsBtn.MouseButton1Click:Connect(function()
    refreshPresets()
    PresetPanel.Visible = true
end)
PresetClose.MouseButton1Click:Connect(function() PresetPanel.Visible = false end)

UI.refreshBuilder = refreshBuilder
