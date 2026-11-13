-- UniversalAnimHub / ui_main.lua (модуль; грузится через Loader.lua)
local Hub = ...
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local connect = Hub.connect
local L = Hub.UILib
local ACCENT, BG, BAR, TEXT, MUTED, DARK_TEXT = L.ACCENT, L.BG, L.BAR, L.TEXT, L.MUTED, L.DARK_TEXT
local SUCCESS, DANGER = L.SUCCESS, L.DANGER
local new, corner, label, stroke, tween = L.new, L.corner, L.label, L.stroke, L.tween
local Settings = Hub.Config.Settings

-- ================= GUI PARENT =================
local function getGuiParent()
    local ok, ui = pcall(function() return gethui and gethui() end)
    if ok and ui then return ui end
    local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and cg then return cg end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local GuiParent = getGuiParent()
for _, p in ipairs({ GuiParent, LocalPlayer:FindFirstChild("PlayerGui") }) do
    local old = p and p:FindFirstChild("UniversalAnimHub")
    if old then old:Destroy() end
end

-- ================= ГЛАВНОЕ ОКНО =================
local ScreenGui = new("ScreenGui", {
    Name = "UniversalAnimHub",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, GuiParent)

local Main = new("Frame", {
    Size = UDim2.fromOffset(580, 620),
    Position = UDim2.fromScale(0.5, 0.5),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = BG,
    BorderSizePixel = 0,
    Active = true,
}, ScreenGui)
corner(Main, 14)
stroke(Main, Color3.fromRGB(58, 56, 90), 1)

-- окно подгоняется под маленькие экраны (телефоны)
local Scale = new("UIScale", {}, Main)
local function fitWindow()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    Scale.Scale = math.clamp(math.min((vp.X - 16) / 580, (vp.Y - 16) / 620), 0.5, 1)
end
fitWindow()
do
    local cam = workspace.CurrentCamera
    if cam then connect(cam:GetPropertyChangedSignal("ViewportSize"), fitWindow) end
end

-- ----- верхняя панель -----
local TOP_GRADIENT = ColorSequence.new(Color3.fromRGB(46, 38, 96), BAR)
local TopBar = new("Frame", {
    Size = UDim2.new(1, 0, 0, 44),
    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
    BorderSizePixel = 0,
}, Main)
corner(TopBar, 14)
new("UIGradient", { Color = TOP_GRADIENT, Rotation = 0 }, TopBar)
local TopCover = new("Frame", {
    Size = UDim2.new(1, 0, 0, 14),
    Position = UDim2.new(0, 0, 1, -14),
    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
    BorderSizePixel = 0,
}, TopBar)
new("UIGradient", { Color = TOP_GRADIENT, Rotation = 0 }, TopCover)

local Dot = new("Frame", {
    Size = UDim2.fromOffset(10, 10),
    Position = UDim2.fromOffset(16, 17),
    BackgroundColor3 = ACCENT,
    BorderSizePixel = 0,
}, TopBar)
corner(Dot, 5)
label(TopBar, "Animation Hub", UDim2.fromOffset(130, 44), UDim2.fromOffset(34, 0), 16, TEXT, Enum.Font.GothamBold)
label(TopBar, "Universal  v" .. tostring(Hub.Version or "3"), UDim2.fromOffset(120, 44), UDim2.fromOffset(160, 1), 12, MUTED, Enum.Font.Gotham)

local CloseBtn = new("TextButton", {
    Size = UDim2.fromOffset(28, 28),
    Position = UDim2.new(1, -38, 0, 8),
    BackgroundColor3 = Color3.fromRGB(200, 60, 70),
    Text = "X",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 14,
}, TopBar)
corner(CloseBtn, 8)

local GearBtn = new("TextButton", {
    Size = UDim2.fromOffset(28, 28),
    Position = UDim2.new(1, -72, 0, 8),
    BackgroundColor3 = Color3.fromRGB(58, 56, 82),
    Text = "⚙",
    TextColor3 = TEXT,
    Font = Enum.Font.GothamBold,
    TextSize = 16,
}, TopBar)
corner(GearBtn, 8)

-- Перетаскивание
do
    local dragging, dragStart, startPos
    connect(TopBar.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Main.Position
        end
    end)
    connect(UIS.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    connect(UIS.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- ----- навигация -----
local NavBar = new("Frame", {
    Size = UDim2.new(1, 0, 0, 36),
    Position = UDim2.fromOffset(0, 44),
    BackgroundColor3 = Color3.fromRGB(21, 21, 29),
    BorderSizePixel = 0,
}, Main)
new("Frame", {
    Size = UDim2.new(1, 0, 0, 1),
    Position = UDim2.new(0, 0, 1, -1),
    BackgroundColor3 = Color3.fromRGB(44, 44, 62),
    BorderSizePixel = 0,
}, NavBar)

local PAGE_POS = UDim2.fromOffset(0, 80)
local PAGE_SIZE = UDim2.new(1, 0, 1, -80)
local function newPage(visible)
    return new("Frame", {
        Size = PAGE_SIZE,
        Position = PAGE_POS,
        BackgroundTransparency = 1,
        Visible = visible,
    }, Main)
end

local PacksPage = newPage(true)
local BuilderPage = newPage(false)
local EmotesPage = newPage(false)
local SettingsPage = newPage(false)

local Pages = { packs = PacksPage, builder = BuilderPage, emotes = EmotesPage, settings = SettingsPage }
local NavButtons = {}
local currentSection = "packs"
local UI = { onShow = {} }
Hub.UI = UI

local TAB_IDLE = Color3.fromRGB(36, 36, 52)
local TAB_IDLE_TEXT = Color3.fromRGB(190, 192, 212)
local GEAR_IDLE = Color3.fromRGB(58, 56, 82)

local function setSection(key)
    currentSection = key
    for k, p in pairs(Pages) do p.Visible = (k == key) end
    for k, b in pairs(NavButtons) do
        local on = (k == key)
        tween(b, { BackgroundColor3 = on and ACCENT or TAB_IDLE, TextColor3 = on and DARK_TEXT or TAB_IDLE_TEXT }, 0.15)
    end
    local g = (key == "settings")
    tween(GearBtn, { BackgroundColor3 = g and ACCENT or GEAR_IDLE, TextColor3 = g and DARK_TEXT or TEXT }, 0.15)
    if UI.onShow[key] then UI.onShow[key]() end
end

for i, def in ipairs({ { "packs", "Паки" }, { "builder", "Конструктор" }, { "emotes", "Эмоции" } }) do
    local b = new("TextButton", {
        Size = UDim2.fromOffset(120, 26),
        Position = UDim2.fromOffset(12 + (i - 1) * 128, 5),
        BackgroundColor3 = TAB_IDLE,
        Text = def[2],
        TextColor3 = TAB_IDLE_TEXT,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
    }, NavBar)
    corner(b, 13)
    NavButtons[def[1]] = b
    b.MouseButton1Click:Connect(function() setSection(def[1]) end)
end

GearBtn.MouseButton1Click:Connect(function()
    setSection(currentSection == "settings" and "packs" or "settings")
end)

-- ----- всплывающие уведомления (kind: "ok" / "err" / nil) -----
local TOAST_POS = UDim2.new(0, 20, 1, -46)
local Toast = new("TextLabel", {
    Size = UDim2.new(1, -40, 0, 34),
    Position = TOAST_POS,
    BackgroundColor3 = Color3.fromRGB(12, 12, 18),
    TextColor3 = TEXT,
    Font = Enum.Font.GothamSemibold,
    TextSize = 13,
    TextWrapped = true,
    Visible = false,
    ZIndex = 50,
}, Main)
corner(Toast, 10)
local ToastStroke = stroke(Toast, ACCENT, 1)
local toastGen = 0
local function toast(text, kind)
    toastGen += 1
    local g = toastGen
    Toast.Text = tostring(text)
    ToastStroke.Color = (kind == "err" and DANGER) or (kind == "ok" and SUCCESS) or ACCENT
    Toast.Position = UDim2.new(0, 20, 1, -34)
    Toast.BackgroundTransparency = 1
    Toast.TextTransparency = 1
    ToastStroke.Transparency = 1
    Toast.Visible = true
    tween(Toast, { Position = TOAST_POS, BackgroundTransparency = 0.05, TextTransparency = 0 }, 0.2)
    tween(ToastStroke, { Transparency = 0 }, 0.2)
    task.delay(4, function()
        if toastGen ~= g then return end
        tween(Toast, { BackgroundTransparency = 1, TextTransparency = 1 }, 0.25)
        tween(ToastStroke, { Transparency = 1 }, 0.25)
        task.delay(0.3, function()
            if toastGen == g then Toast.Visible = false end
        end)
    end)
end

-- плавающая кнопка открытия окна (для телефонов, где нет клавиши-бинда)
local ToggleBtn = new("TextButton", {
    Size = UDim2.fromOffset(44, 44),
    Position = UDim2.new(0, 12, 0.5, -22),
    BackgroundColor3 = ACCENT,
    Text = "AH",
    TextColor3 = DARK_TEXT,
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    Visible = Settings.MobileButton == true,
    ZIndex = 60,
}, ScreenGui)
corner(ToggleBtn, 22)
stroke(ToggleBtn, Color3.fromRGB(190, 182, 255), 1, 0.4)
ToggleBtn.MouseButton1Click:Connect(function() Main.Visible = not Main.Visible end)

UI.Gui = ScreenGui
UI.Main = Main
UI.Pages = Pages
UI.setSection = setSection
UI.getSection = function() return currentSection end
UI.toast = toast
UI.setToggleButton = function(v) ToggleBtn.Visible = v and true or false end

-- X только прячет окно: анимации продолжают работать. Полная выгрузка — в настройках.
CloseBtn.MouseButton1Click:Connect(function()
    Main.Visible = false
end)
ScreenGui.Destroying:Connect(function()
    Hub.cleanup()
end)
return UI
