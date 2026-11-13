-- UniversalAnimHub / ui_quick.lua (модуль; грузится через Loader.lua)
-- Быстрая панель эмоций: открывается клавишей или кнопкой «EM» поверх любой игры,
-- не зависит от меню эмоций самой игры (ММ2 и др.).
local Hub = ...
local UIS = game:GetService("UserInputService")
local connect = Hub.connect
local L = Hub.UILib
local ACCENT, TEXT, MUTED, DARK_TEXT = L.ACCENT, L.TEXT, L.MUTED, L.DARK_TEXT
local new, corner, label = L.new, L.corner, L.label
local Settings = Hub.Config.Settings
local UI = Hub.UI
local Emote = Hub.Emote
local Binds = Hub.Binds

-- имена избранных эмоций нужны для `/e <название>`, даже если вкладку «Эмоции» не открывали
for id, name in pairs(Settings.EmoteFavs) do
    local key = tostring(name or ""):lower()
    if key ~= "" and not Emote.Names[key] then Emote.Names[key] = id end
end

local ORDER = { "wave", "point", "dance", "dance2", "dance3", "laugh", "cheer" }
local TITLES = { wave = "Wave", point = "Point", dance = "Dance", dance2 = "Dance 2", dance3 = "Dance 3", laugh = "Laugh", cheer = "Cheer" }

local Panel = new("Frame", {
    Size = UDim2.fromOffset(384, 260),
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -24),
    BackgroundColor3 = Color3.fromRGB(26, 26, 31),
    Visible = false,
    ZIndex = 40,
    Active = true,
}, UI.Gui)
corner(Panel, 12)
new("UIStroke", { Color = Color3.fromRGB(70, 70, 82), Thickness = 1 }, Panel)

label(Panel, "Быстрые эмоции", UDim2.fromOffset(140, 30), UDim2.fromOffset(14, 8), 15, TEXT, Enum.Font.GothamBold)
label(Panel, "ПКМ = бинд", UDim2.fromOffset(100, 30), UDim2.fromOffset(150, 8), 11, MUTED, Enum.Font.Gotham)

local StopBtn = new("TextButton", {
    Size = UDim2.fromOffset(70, 28),
    Position = UDim2.new(1, -118, 0, 8),
    BackgroundColor3 = Color3.fromRGB(200, 60, 60),
    Text = "Стоп",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 13,
}, Panel)
corner(StopBtn, 7)
StopBtn.MouseButton1Click:Connect(function() Emote.stop(0.2) end)

local CloseBtn = new("TextButton", {
    Size = UDim2.fromOffset(28, 28),
    Position = UDim2.new(1, -38, 0, 8),
    BackgroundColor3 = Color3.fromRGB(58, 58, 68),
    Text = "X",
    TextColor3 = TEXT,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
}, Panel)
corner(CloseBtn, 7)
CloseBtn.MouseButton1Click:Connect(function() Panel.Visible = false end)

local List = new("ScrollingFrame", {
    Size = UDim2.new(1, -16, 1, -52),
    Position = UDim2.fromOffset(8, 44),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    CanvasSize = UDim2.new(),
}, Panel)
local Grid = new("UIGridLayout", {
    CellSize = UDim2.new(0.5, -8, 0, 34),
    CellPadding = UDim2.fromOffset(8, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, List)
connect(Grid:GetPropertyChangedSignal("AbsoluteContentSize"), function()
    List.CanvasSize = UDim2.fromOffset(0, Grid.AbsoluteContentSize.Y + 8)
end)

local buttons = {}

local function refreshActive()
    for _, b in ipairs(buttons) do
        local on = (Emote.id == b.id)
        b.btn.BackgroundColor3 = on and ACCENT or Color3.fromRGB(46, 46, 56)
        b.btn.TextColor3 = on and DARK_TEXT or TEXT
    end
end

local function rebuild()
    for _, b in ipairs(buttons) do b.btn:Destroy() end
    buttons = {}
    local items = {}

    local favs = {}
    for id, name in pairs(Settings.EmoteFavs) do
        table.insert(favs, { id = tostring(id), name = tostring(name) })
    end
    table.sort(favs, function(a, b) return a.name < b.name end)
    for _, f in ipairs(favs) do
        table.insert(items, { id = f.id, raw = f.name, name = "★ " .. f.name, prefer = true })
    end
    for _, k in ipairs(ORDER) do
        table.insert(items, { id = Emote.Builtin[k], raw = TITLES[k], name = TITLES[k], prefer = false })
    end

    for i, it in ipairs(items) do
        local bindKey = Binds.get(it.id)
        local btn = new("TextButton", {
            LayoutOrder = i,
            BackgroundColor3 = Color3.fromRGB(46, 46, 56),
            Text = it.name .. (bindKey and ("  [" .. L.keyLabel(bindKey) .. "]") or ""),
            TextColor3 = TEXT,
            Font = Enum.Font.GothamSemibold,
            TextSize = 13,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, List)
        corner(btn, 8)
        btn.MouseButton1Click:Connect(function()
            task.spawn(Emote.play, it.id, it.prefer)
        end)
        btn.MouseButton2Click:Connect(function()
            Binds.capture({ id = it.id, name = it.raw or it.name, prefer = it.prefer })
        end)
        table.insert(buttons, { btn = btn, id = it.id })
    end
    refreshActive()
end

-- не затираем колбэк вкладки «Эмоции», а дополняем его
local prevOnChange = Emote.onChange
Emote.onChange = function()
    if prevOnChange then pcall(prevOnChange) end
    refreshActive()
end

local prevBindChange = Binds.onChange
Binds.onChange = function()
    if prevBindChange then pcall(prevBindChange) end
    if Panel.Visible then rebuild() end
end

function UI.toggleQuick()
    Panel.Visible = not Panel.Visible
    if Panel.Visible then rebuild() end
end

-- кнопка для телефонов (рядом с «AH»)
local QuickBtn = new("TextButton", {
    Size = UDim2.fromOffset(44, 44),
    Position = UDim2.new(0, 12, 0.5, 30),
    BackgroundColor3 = Color3.fromRGB(58, 58, 68),
    Text = "EM",
    TextColor3 = ACCENT,
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    Visible = Settings.MobileButton == true,
    ZIndex = 60,
}, UI.Gui)
corner(QuickBtn, 22)
QuickBtn.MouseButton1Click:Connect(UI.toggleQuick)

local prevToggle = UI.setToggleButton
UI.setToggleButton = function(v)
    if prevToggle then prevToggle(v) end
    QuickBtn.Visible = v and true or false
end

connect(UIS.InputBegan, function(input, gameProcessed)
    if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local ok, key = pcall(function() return Enum.KeyCode[Settings.EmoteBind] end)
    if ok and key and input.KeyCode == key then UI.toggleQuick() end
end)
