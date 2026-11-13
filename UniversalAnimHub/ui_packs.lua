-- UniversalAnimHub / ui_packs.lua (модуль; грузится через Loader.lua)
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
local PacksPage = UI.Pages.packs
local toast = UI.toast
local Packs = Hub.Packs.list
local Add, findPack = Hub.Packs.Add, Hub.Packs.find
local currentSelected = Hub.Packs.currentSelected
local Driver = Hub.Driver
local packFromBundle = Hub.Catalog.packFromBundle

-- ================= СТРАНИЦА: ПАКИ =================
label(PacksPage, "Применять после возрождения", UDim2.new(1, -90, 0, 24), UDim2.fromOffset(14, 10), 14)
makeSwitch(PacksPage, UDim2.new(1, -62, 0, 10), Settings.AutoReapply, function(v)
    Settings.AutoReapply = v
    saveSettings()
end)

local SearchBox = new("TextBox", {
    Size = UDim2.new(1, -140, 0, 32),
    Position = UDim2.fromOffset(12, 46),
    BackgroundColor3 = Color3.fromRGB(38, 38, 46),
    PlaceholderText = "Поиск по названию или ID...",
    PlaceholderColor3 = MUTED,
    Text = "",
    TextColor3 = TEXT,
    Font = Enum.Font.Gotham,
    TextSize = 14,
    ClearTextOnFocus = false,
    TextXAlignment = Enum.TextXAlignment.Left,
}, PacksPage)
corner(SearchBox, 8)
new("UIPadding", { PaddingLeft = UDim.new(0, 10) }, SearchBox)

local ResetBtn = new("TextButton", {
    Size = UDim2.fromOffset(112, 32),
    Position = UDim2.new(1, -124, 0, 46),
    BackgroundColor3 = Color3.fromRGB(46, 46, 56),
    Text = "Сбросить",
    TextColor3 = TEXT,
    Font = Enum.Font.GothamSemibold,
    TextSize = 14,
}, PacksPage)
corner(ResetBtn, 8)

local Tabs = {}
local CurrentTab = "all"
local tabDefs = {
    { "all", "Все", 54 },
    { "fav", "Избранное", 92 },
    { "removed", "Удалённые", 92 },
    { "online", "Онлайн-каталог", 124 },
}
local tx = 12
for _, def in ipairs(tabDefs) do
    local b = new("TextButton", {
        Size = UDim2.fromOffset(def[3], 26),
        Position = UDim2.fromOffset(tx, 86),
        BackgroundColor3 = Color3.fromRGB(46, 46, 56),
        Text = def[2],
        TextColor3 = TEXT,
        Font = Enum.Font.GothamSemibold,
        TextSize = 13,
    }, PacksPage)
    corner(b, 13)
    Tabs[def[1]] = b
    tx = tx + def[3] + 8
end

local Scroll = new("ScrollingFrame", {
    Size = UDim2.new(1, -24, 1, -126),
    Position = UDim2.fromOffset(12, 120),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Color3.fromRGB(100, 100, 115),
    CanvasSize = UDim2.new(),
}, PacksPage)

local Grid = new("UIGridLayout", {
    CellSize = UDim2.fromOffset(172, 150),
    CellPadding = UDim2.fromOffset(8, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, Scroll)

connect(Grid:GetPropertyChangedSignal("AbsoluteContentSize"), function()
    Scroll.CanvasSize = UDim2.fromOffset(0, Grid.AbsoluteContentSize.Y + 8)
end)

-- ================= ПРЕВЬЮ =================
local Template

local function getTemplate()
    if Template then return Template end
    local ok, rig = pcall(function()
        return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
    end)
    if not ok or not rig then
        rig = nil
        local char = LocalPlayer.Character
        if char then
            char.Archivable = true
            rig = char:Clone()
            if rig then
                for _, d in ipairs(rig:GetDescendants()) do
                    if d:IsA("LuaSourceContainer") then d:Destroy() end
                end
            end
        end
    end
    Template = rig
    return rig
end

local function buildPreview(card, pack)
    local tpl = getTemplate()
    if not tpl then return end

    local vp = new("ViewportFrame", {
        Size = UDim2.new(1, 0, 1, -40),
        BackgroundTransparency = 1,
        Ambient = Color3.fromRGB(170, 170, 185),
        LightColor = Color3.fromRGB(255, 255, 255),
        LightDirection = Vector3.new(-0.3, -0.5, 1),
    }, card)

    local rig = tpl:Clone()
    rig.Parent = vp
    local root = rig:FindFirstChild("HumanoidRootPart")
    if root then root.Anchored = true end
    rig:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(-18), 0))

    local cam = new("Camera", {
        FieldOfView = 35,
        CFrame = CFrame.lookAt(Vector3.new(0, -0.1, -10.5), Vector3.new(0, -0.1, 0)),
    }, vp)
    vp.CurrentCamera = cam

    local hum = rig:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator") or new("Animator", {}, hum)

    local anim = new("Animation", { AnimationId = "rbxassetid://" .. pack.ids.idle1 })
    local okLoad, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not okLoad or not track then return end

    track.Looped = true
    track:Play()
    task.spawn(function()
        local waited = 0
        while track.Length == 0 and waited < 4 do
            waited = waited + task.wait(0.1)
        end
        pcall(function()
            track.TimePosition = track.Length * 0.3
            track:AdjustSpeed(0)
        end)
    end)

    card.MouseEnter:Connect(function() pcall(function() track:AdjustSpeed(1) end) end)
    card.MouseLeave:Connect(function() pcall(function() track:AdjustSpeed(0) end) end)
end

-- ================= КАРТОЧКИ ПАКОВ =================
local Cards = {}

local function updateSelection()
    local sel = currentSelected()
    for _, c in ipairs(Cards) do
        c.stroke.Enabled = (sel == c.pack.name)
    end
end

local function updateStar(c)
    local fav = Settings.Favorites[c.pack.name]
    c.star.Text = fav and "★" or "☆"
    c.star.TextColor3 = fav and Color3.fromRGB(255, 205, 70) or TEXT
end

local PackBrowser -- онлайн-каталог паков (создаётся ниже)

local function refreshList()
    local q = string.lower(SearchBox.Text)
    for _, c in ipairs(Cards) do
        local show = true
        if CurrentTab == "fav" and not Settings.Favorites[c.pack.name] then show = false end
        if CurrentTab == "removed" and not c.pack.removed then show = false end
        if show and q ~= "" then
            local match = string.find(string.lower(c.pack.name), q, 1, true) ~= nil
            if not match then
                for _, id in pairs(c.pack.ids) do
                    if string.find(id, q, 1, true) then match = true break end
                end
            end
            show = match
        end
        c.frame.Visible = show
    end
end

local function updateTabs()
    for key, b in pairs(Tabs) do
        if key == CurrentTab then
            b.BackgroundColor3 = ACCENT
            b.TextColor3 = DARK_TEXT
        else
            b.BackgroundColor3 = Color3.fromRGB(46, 46, 56)
            b.TextColor3 = TEXT
        end
    end
end

local function selectPack(pack)
    Driver.ApplyPack(pack)
    updateSelection()
    if UI.refreshBuilder then UI.refreshBuilder() end
    saveSettings()
end

local function createPackCard(pack, order)
    local card = new("TextButton", {
        Name = pack.name,
        Text = "",
        AutoButtonColor = false,
        BackgroundColor3 = CARD,
        LayoutOrder = order,
        ClipsDescendants = true,
    }, Scroll)
    corner(card, 10)
    local stroke = new("UIStroke", { Color = ACCENT, Thickness = 2, Enabled = false }, card)

    new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -16, 0, 36),
        Position = UDim2.new(0, 8, 1, -38),
        Text = pack.name .. ((pack.removed or pack.name == "Default") and "" or " Pack"),
        TextColor3 = TEXT,
        Font = Enum.Font.GothamSemibold,
        TextSize = 13,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 2,
    }, card)

    if pack.removed then
        local badge = new("TextLabel", {
            Size = UDim2.fromOffset(64, 18),
            Position = UDim2.fromOffset(8, 8),
            BackgroundColor3 = pack.imported and Color3.fromRGB(50, 90, 130) or Color3.fromRGB(120, 50, 50),
            Text = pack.imported and "Онлайн" or "Удалён",
            TextColor3 = Color3.new(1, 1, 1),
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            ZIndex = 3,
        }, card)
        corner(badge, 9)
    end

    local star = new("TextButton", {
        Size = UDim2.fromOffset(26, 26),
        Position = UDim2.new(1, -32, 0, 6),
        BackgroundColor3 = Color3.fromRGB(30, 30, 36),
        Text = "☆",
        TextColor3 = TEXT,
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        ZIndex = 4,
    }, card)
    corner(star, 7)

    local entry = { frame = card, pack = pack, stroke = stroke, star = star }
    table.insert(Cards, entry)
    updateStar(entry)

    star.MouseButton1Click:Connect(function()
        if Settings.Favorites[pack.name] then
            Settings.Favorites[pack.name] = nil
        else
            Settings.Favorites[pack.name] = true
        end
        updateStar(entry)
        saveSettings()
        if CurrentTab == "fav" then refreshList() end
    end)

    card.MouseButton1Click:Connect(function() selectPack(pack) end)
    card.MouseEnter:Connect(function() card.BackgroundColor3 = CARD_HOVER end)
    card.MouseLeave:Connect(function() card.BackgroundColor3 = CARD end)

    task.spawn(function() pcall(buildPreview, card, pack) end)
    return entry
end

task.spawn(function()
    for i, pack in ipairs(Packs) do
        if not UI.Gui.Parent then return end
        createPackCard(pack, i)
        task.wait() -- превью строим по очереди, чтобы не лагало
    end
    updateSelection()
    refreshList()
end)

-- ================= ОНЛАЙН-КАТАЛОГ ПАКОВ =================
local importing = false
local function importPack(item)
    if importing then return end
    local existing = findPack(item.name)
    if existing then
        selectPack(existing)
        toast("Применён: " .. item.name)
        return
    end
    importing = true
    toast("Загружаю набор «" .. tostring(item.name) .. "»…")
    task.spawn(function()
        local ids, err = packFromBundle(item.id)
        importing = false
        if not ids then
            toast("Не получилось: " .. tostring(err))
            return
        end
        local pack = Add(item.name, true, ids.idle1, ids.idle2, ids.walk, ids.run, ids.jump, ids.climb, ids.fall, ids.swim, ids.swimidle, true)
        Settings.Imported[item.name] = ids
        createPackCard(pack, 10000 + #Packs)
        selectPack(pack)
        refreshList()
        toast("Добавлен и применён: " .. item.name)
    end)
end

PackBrowser = makeBrowser(PacksPage, UDim2.fromOffset(12, 120), UDim2.new(1, -24, 1, -126), "pack", {
    makeItem = function(id, name)
        return {
            id = id, name = name,
            thumb = "rbxthumb://type=BundleThumbnail&id=" .. id .. "&w=150&h=150",
        }
    end,
    onClick = importPack,
})

local function setPacksTab(key)
    CurrentTab = key
    updateTabs()
    local online = (key == "online")
    Scroll.Visible = not online
    PackBrowser.frame.Visible = online
    SearchBox.PlaceholderText = online and "Поиск паков в каталоге Roblox..." or "Поиск по названию или ID..."
    if online then
        if not PackBrowser.started then PackBrowser:search(SearchBox.Text) end
    else
        refreshList()
    end
end

for key, b in pairs(Tabs) do
    b.MouseButton1Click:Connect(function() setPacksTab(key) end)
end

local packSearchTick = 0
connect(SearchBox:GetPropertyChangedSignal("Text"), function()
    if CurrentTab == "online" then
        packSearchTick += 1
        local t = packSearchTick
        task.delay(0.8, function()
            if t == packSearchTick and CurrentTab == "online" then
                PackBrowser:search(SearchBox.Text)
            end
        end)
    else
        refreshList()
    end
end)

ResetBtn.MouseButton1Click:Connect(function()
    Driver.Reset()
    updateSelection()
    if UI.refreshBuilder then UI.refreshBuilder() end
    saveSettings()
end)

updateTabs()
updateSelection()
refreshList()

UI.updateSelection = updateSelection
UI.refreshList = refreshList
UI.selectPack = selectPack
Hub.onDestroy(function()
    if Template then pcall(function() Template:Destroy() end) end
end)
