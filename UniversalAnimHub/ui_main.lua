-- UniversalAnimHub / ui_main.lua (модуль; грузится через Loader.lua)
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
corner(Main, 12)

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

local TopBar = new("Frame", {
    Size = UDim2.new(1, 0, 0, 44),
    BackgroundColor3 = BAR,
    BorderSizePixel = 0,
}, Main)
corner(TopBar, 12)
new("Frame", {
    Size = UDim2.new(1, 0, 0, 12),
    Position = UDim2.new(0, 0, 1, -12),
    BackgroundColor3 = BAR,
    BorderSizePixel = 0,
}, TopBar)

label(TopBar, "Animation Hub  •  Universal", UDim2.new(1, -110, 1, 0), UDim2.fromOffset(16, 0), 16, TEXT, Enum.Font.GothamBold)

local CloseBtn = new("TextButton", {
    Size = UDim2.fromOffset(28, 28),
    Position = UDim2.new(1, -38, 0, 8),
    BackgroundColor3 = Color3.fromRGB(200, 60, 60),
    Text = "X",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 14,
}, TopBar)
corner(CloseBtn, 7)

local GearBtn = new("TextButton", {
    Size = UDim2.fromOffset(28, 28),
    Position = UDim2.new(1, -72, 0, 8),
    BackgroundColor3 = Color3.fromRGB(58, 58, 68),
    Text = "⚙",
    TextColor3 = TEXT,
    Font = Enum.Font.GothamBold,
    TextSize = 16,
}, TopBar)
corner(GearBtn, 7)

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

-- Навигация
local NavBar = new("Frame", {
    Size = UDim2.new(1, 0, 0, 36),
    Position = UDim2.fromOffset(0, 44),
    BackgroundColor3 = Color3.fromRGB(30, 30, 36),
    BorderSizePixel = 0,
}, Main)

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

local function setSection(key)
    currentSection = key
    for k, p in pairs(Pages) do p.Visible = (k == key) end
    for k, b in pairs(NavButtons) do
        b.BackgroundColor3 = (k == key) and ACCENT or Color3.fromRGB(46, 46, 56)
        b.TextColor3 = (k == key) and DARK_TEXT or TEXT
    end
    GearBtn.BackgroundColor3 = (key == "settings") and ACCENT or Color3.fromRGB(58, 58, 68)
    GearBtn.TextColor3 = (key == "settings") and DARK_TEXT or TEXT
    if UI.onShow[key] then UI.onShow[key]() end
end

for i, def in ipairs({ { "packs", "Паки" }, { "builder", "Конструктор" }, { "emotes", "Эмоции" } }) do
    local b = new("TextButton", {
        Size = UDim2.fromOffset(120, 26),
        Position = UDim2.fromOffset(12 + (i - 1) * 128, 5),
        BackgroundColor3 = Color3.fromRGB(46, 46, 56),
        Text = def[2],
        TextColor3 = TEXT,
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

-- Всплывающее уведомление
local Toast = new("TextLabel", {
    Size = UDim2.new(1, -40, 0, 30),
    Position = UDim2.new(0, 20, 1, -42),
    BackgroundColor3 = Color3.fromRGB(14, 14, 18),
    TextColor3 = TEXT,
    Font = Enum.Font.GothamSemibold,
    TextSize = 13,
    TextWrapped = true,
    Visible = false,
    ZIndex = 50,
}, Main)
corner(Toast, 8)
local toastGen = 0
local function toast(text)
    toastGen += 1
    local g = toastGen
    Toast.Text = text
    Toast.Visible = true
    task.delay(4, function()
        if toastGen == g then Toast.Visible = false end
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
ToggleBtn.MouseButton1Click:Connect(function() Main.Visible = not Main.Visible end)

UI.Gui = ScreenGui
UI.setToggleButton = function(v) ToggleBtn.Visible = v and true or false end
UI.Main = Main
UI.Pages = Pages
UI.setSection = setSection
UI.getSection = function() return currentSection end
UI.toast = toast

-- X только прячет окно: анимации продолжают работать. Полная выгрузка — в настройках.
CloseBtn.MouseButton1Click:Connect(function()
    Main.Visible = false
end)
ScreenGui.Destroying:Connect(function()
    Hub.cleanup()
end)
return UI
