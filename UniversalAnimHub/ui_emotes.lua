-- UniversalAnimHub / ui_emotes.lua (модуль; грузится через Loader.lua)
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
local EmotesPage = UI.Pages.emotes
local Emote = Hub.Emote
local Binds = Hub.Binds
local playEmote, stopEmote = Emote.play, Emote.stop
local BuiltinEmotes, EmoteNames = Emote.Builtin, Emote.Names
local EmoteOnShow

-- ================= СТРАНИЦА: ЭМОЦИИ =================
local EmoteSearch = new("TextBox", {
    Size = UDim2.new(1, -24, 0, 32),
    Position = UDim2.fromOffset(12, 10),
    BackgroundColor3 = Color3.fromRGB(38, 38, 46),
    PlaceholderText = "Поиск эмоций в каталоге Roblox...",
    PlaceholderColor3 = MUTED,
    Text = "",
    TextColor3 = TEXT,
    Font = Enum.Font.Gotham,
    TextSize = 14,
    ClearTextOnFocus = false,
    TextXAlignment = Enum.TextXAlignment.Left,
}, EmotesPage)
corner(EmoteSearch, 8)
new("UIPadding", { PaddingLeft = UDim.new(0, 10) }, EmoteSearch)

local EmoteTab = "catalog"
local EmoteTabButtons = {}
do
    local ex = 12
    for _, def in ipairs({ { "catalog", "Каталог", 84 }, { "fav", "Избранное", 92 }, { "std", "Стандартные", 110 }, { "binds", "Бинды", 78 } }) do
        local b = new("TextButton", {
            Size = UDim2.fromOffset(def[3], 26),
            Position = UDim2.fromOffset(ex, 50),
            BackgroundColor3 = Color3.fromRGB(46, 46, 56),
            Text = def[2],
            TextColor3 = TEXT,
            Font = Enum.Font.GothamSemibold,
            TextSize = 13,
        }, EmotesPage)
        corner(b, 13)
        EmoteTabButtons[def[1]] = b
        ex = ex + def[3] + 8
    end
end

local EmoteStopBtn = new("TextButton", {
    Size = UDim2.fromOffset(96, 26),
    Position = UDim2.new(1, -108, 0, 50),
    BackgroundColor3 = Color3.fromRGB(200, 60, 60),
    Text = "■ Стоп",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 13,
}, EmotesPage)
corner(EmoteStopBtn, 13)
EmoteStopBtn.MouseButton1Click:Connect(function() stopEmote(0.2) end)

local EmoteBrowser
local function emoteItem(id, name)
    local key = tostring(name or ""):lower()
    if key ~= "" then EmoteNames[key] = id end
    return {
        id = id, name = name,
        thumb = "rbxthumb://type=Asset&id=" .. id .. "&w=150&h=150",
    }
end

EmoteBrowser = makeBrowser(EmotesPage, UDim2.fromOffset(12, 84), UDim2.new(1, -24, 1, -90), "emote", {
    makeItem = emoteItem,
    onClick = function(item)
        if item.builtin then
            playEmote(item.id, false)
        else
            task.spawn(playEmote, item.id, true)
        end
    end,
    onStar = function(item)
        if Settings.EmoteFavs[item.id] then
            Settings.EmoteFavs[item.id] = nil
        else
            Settings.EmoteFavs[item.id] = item.name or "Emote"
        end
        saveSettings()
        if EmoteTab == "fav" then EmoteOnShow() end
    end,
    isFav = function(item) return Settings.EmoteFavs[item.id] ~= nil end,
    isActive = function(item) return Emote.id == item.id end,
    onBind = function(item)
        local cap = Binds.capturing
        if cap and cap.id == tostring(item.id) then
            Binds.cancel()
        else
            Binds.capture({ id = item.id, name = item.name, prefer = not item.builtin })
        end
    end,
    getBind = function(item) return Binds.get(item.id) end,
    isCapturing = function(item)
        local cap = Binds.capturing
        return cap ~= nil and cap.id == tostring(item.id)
    end,
})
EmoteBrowser.frame.Visible = true
Emote.onChange = function() EmoteBrowser:refreshActive() end
Binds.onChange = function()
    EmoteBrowser:refreshBinds()
    if EmoteTab == "binds" then EmoteOnShow() end
end

local function emoteStaticList()
    local q = string.lower(EmoteSearch.Text)
    local list = {}
    if EmoteTab == "std" then
        local order = { "wave", "point", "dance", "dance2", "dance3", "laugh", "cheer" }
        local titles = { wave = "Wave", point = "Point", dance = "Dance", dance2 = "Dance 2", dance3 = "Dance 3", laugh = "Laugh", cheer = "Cheer" }
        for _, k in ipairs(order) do
            table.insert(list, { id = BuiltinEmotes[k], name = titles[k], builtin = true, icon = "💃" })
        end
    elseif EmoteTab == "binds" then
        local keys = {}
        for k in pairs(Settings.EmoteBinds) do table.insert(keys, k) end
        table.sort(keys)
        for _, k in ipairs(keys) do
            local e = Settings.EmoteBinds[k]
            if e.prefer then
                table.insert(list, emoteItem(e.id, e.name))
            else
                table.insert(list, { id = e.id, name = e.name, builtin = true, icon = "💃" })
            end
        end
    else
        for id, name in pairs(Settings.EmoteFavs) do
            table.insert(list, emoteItem(id, name))
        end
        table.sort(list, function(a, b) return tostring(a.name) < tostring(b.name) end)
    end
    if q ~= "" then
        local filtered = {}
        for _, it in ipairs(list) do
            if string.find(string.lower(tostring(it.name)), q, 1, true) then table.insert(filtered, it) end
        end
        list = filtered
    end
    return list
end

EmoteOnShow = function()
    if EmoteTab == "catalog" then
        if not EmoteBrowser.started or EmoteBrowser.static then
            EmoteBrowser:search(EmoteSearch.Text)
        end
    else
        EmoteBrowser:showStatic(emoteStaticList(),
            (EmoteTab == "fav" and "В избранном пока пусто — нажми ☆ на эмоции")
            or (EmoteTab == "binds" and "Биндов пока нет. Нажми «Бинд» на карточке эмоции, затем клавишу")
            or "Ничего не найдено")
    end
end

local function updateEmoteTabs()
    for key, b in pairs(EmoteTabButtons) do
        b.BackgroundColor3 = (key == EmoteTab) and ACCENT or Color3.fromRGB(46, 46, 56)
        b.TextColor3 = (key == EmoteTab) and DARK_TEXT or TEXT
    end
    EmoteSearch.PlaceholderText = (EmoteTab == "catalog") and "Поиск эмоций в каталоге Roblox..." or "Фильтр по названию..."
end

for key, b in pairs(EmoteTabButtons) do
    b.MouseButton1Click:Connect(function()
        EmoteTab = key
        updateEmoteTabs()
        EmoteOnShow()
    end)
end
updateEmoteTabs()

local emoteSearchTick = 0
connect(EmoteSearch:GetPropertyChangedSignal("Text"), function()
    emoteSearchTick += 1
    local t = emoteSearchTick
    task.delay(EmoteTab == "catalog" and 0.8 or 0.2, function()
        if t == emoteSearchTick and UI.getSection() == "emotes" then
            if EmoteTab == "catalog" then
                EmoteBrowser:search(EmoteSearch.Text)
            else
                EmoteOnShow()
            end
        end
    end)
end)

UI.onShow.emotes = EmoteOnShow
