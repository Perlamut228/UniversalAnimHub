-- UniversalAnimHub / ui_players.lua (модуль; грузится через Loader.lua)
-- Вкладка «Игроки»: два раздела.
--   «Копирование анимаций» — анимации движения игрока превращаются в пак «Копия: ник».
--   «Синхронизация эмоций» — запустить у себя ту эмоцию, которую сейчас играет игрок.
local Hub = ...
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local connect = Hub.connect
local L = Hub.UILib
local ACCENT, CARD, TEXT, MUTED, DARK_TEXT = L.ACCENT, L.CARD, L.TEXT, L.MUTED, L.DARK_TEXT
local new, corner, label = L.new, L.corner, L.label
local Settings = Hub.Config.Settings
local saveSettings = Hub.Config.save
local UI = Hub.UI
local Page = UI.Pages.players
local Add, findPack = Hub.Packs.Add, Hub.Packs.find
local Sync = Hub.Sync
local toast = UI.toast

-- ================= ЧТЕНИЕ АНИМАЦИЙ ИГРОКА =================
-- 1) живые значения из Animate персонажа (то, что видно на игроке в этой игре);
-- 2) анимации аватара аккаунта (HumanoidDescription по UserId) для недостающих слотов;
-- 3) остальное — стандартные.
local ANIMATE_PATHS = {
    idle1 = { "idle", "Animation1" }, idle2 = { "idle", "Animation2" },
    walk = { "walk", "WalkAnim" }, run = { "run", "RunAnim" }, jump = { "jump", "JumpAnim" },
    climb = { "climb", "ClimbAnim" }, fall = { "fall", "FallAnim" },
    swim = { "swim", "Swim" }, swimidle = { "swimidle", "SwimIdle" },
}
local DESC_PROPS = {
    idle1 = "IdleAnimation", walk = "WalkAnimation", run = "RunAnimation", jump = "JumpAnimation",
    climb = "ClimbAnimation", fall = "FallAnimation", swim = "SwimAnimation",
}
local MAIN_SLOTS = { "idle1", "walk", "run", "jump", "climb", "fall", "swim" }

local function readLive(plr)
    local char = plr.Character
    local animate = char and char:FindFirstChild("Animate")
    if not animate then return {} end
    local ids = {}
    for slot, p in pairs(ANIMATE_PATHS) do
        local folder = animate:FindFirstChild(p[1])
        local a = folder and folder:FindFirstChild(p[2])
        if a and a:IsA("Animation") then
            local id = tostring(a.AnimationId):match("%d+")
            if id and id ~= "0" then ids[slot] = id end
        end
    end
    return ids
end

local function readDescription(plr)
    local ids = {}
    local ok, d = pcall(function() return Players:GetHumanoidDescriptionFromUserId(plr.UserId) end)
    if not ok or not d then return ids end
    for slot, prop in pairs(DESC_PROPS) do
        local okp, v = pcall(function() return d[prop] end)
        v = okp and tonumber(v) or nil
        if v and v > 0 then ids[slot] = string.format("%d", v) end
    end
    pcall(function() d:Destroy() end)
    return ids
end

local function readAnimations(plr)
    local def = findPack("Default").ids
    local live = readLive(plr)
    local desc = readDescription(plr)
    local ids, fromLive, fromDesc = {}, 0, 0
    for slot in pairs(ANIMATE_PATHS) do
        if live[slot] then
            ids[slot] = live[slot]; fromLive += 1
        elseif desc[slot] then
            ids[slot] = desc[slot]; fromDesc += 1
        end
    end
    if not ids.idle2 and ids.idle1 then ids.idle2 = ids.idle1 end
    if fromLive + fromDesc == 0 then
        return nil, "не удалось прочитать анимации (персонаж не загружен или игра их скрывает)"
    end
    for slot in pairs(ANIMATE_PATHS) do
        if not ids[slot] then ids[slot] = def[slot] end
    end
    local allDefault = true
    for _, slot in ipairs(MAIN_SLOTS) do
        if ids[slot] ~= def[slot] then allDefault = false break end
    end
    if allDefault then return nil, "у игрока стандартные анимации Roblox" end
    return ids, (fromLive > 0 and "из персонажа" or "из аккаунта")
end

local copying = false
local function copyFrom(plr)
    if copying then return end
    copying = true
    toast("Читаю анимации " .. plr.DisplayName .. "…")
    task.spawn(function()
        local ok, ids, info = pcall(readAnimations, plr)
        copying = false
        if not ok then
            toast("Ошибка чтения: " .. tostring(ids), "err")
            return
        end
        if not ids then
            toast("Не получилось: " .. tostring(info), "err")
            return
        end
        local name = "Копия: " .. plr.Name
        local pack = findPack(name)
        if pack then
            pack.ids = ids
            Settings.Imported[name] = ids
        else
            pack = Add(name, true, ids.idle1, ids.idle2, ids.walk, ids.run, ids.jump, ids.climb, ids.fall, ids.swim, ids.swimidle, true)
            pack.copied = true
            Settings.Imported[name] = ids
            if UI.addPackCard then UI.addPackCard(pack) end
        end
        UI.selectPack(pack)
        if UI.refreshList then UI.refreshList() end
        saveSettings()
        toast("Скопировано " .. info .. ": " .. plr.DisplayName .. " (пак «" .. name .. "»)", "ok")
    end)
end

-- ================= ИНТЕРФЕЙС =================
local section = "copy" -- "copy" | "sync"
local SectionButtons = {}
do
    local x = 12
    for _, def in ipairs({ { "copy", "Копирование анимаций", 190 }, { "sync", "Синхронизация эмоций", 190 } }) do
        local b = new("TextButton", {
            Size = UDim2.fromOffset(def[3], 26),
            Position = UDim2.fromOffset(x, 8),
            BackgroundColor3 = Color3.fromRGB(36, 36, 52),
            Text = def[2],
            TextColor3 = TEXT,
            Font = Enum.Font.GothamSemibold,
            TextSize = 13,
        }, Page)
        corner(b, 13)
        SectionButtons[def[1]] = b
        x = x + def[3] + 8
    end
end

local Hint = label(Page, "", UDim2.new(1, -28, 0, 30), UDim2.fromOffset(14, 38), 12, MUTED, Enum.Font.Gotham)
Hint.TextWrapped = true
Hint.TextYAlignment = Enum.TextYAlignment.Top

local Search = new("TextBox", {
    Size = UDim2.new(1, -24, 0, 32),
    Position = UDim2.fromOffset(12, 70),
    BackgroundColor3 = Color3.fromRGB(38, 38, 46),
    PlaceholderText = "Поиск по нику...",
    PlaceholderColor3 = MUTED,
    Text = "",
    TextColor3 = TEXT,
    Font = Enum.Font.Gotham,
    TextSize = 14,
    ClearTextOnFocus = false,
    TextXAlignment = Enum.TextXAlignment.Left,
}, Page)
corner(Search, 8)
new("UIPadding", { PaddingLeft = UDim.new(0, 10) }, Search)

local List = new("ScrollingFrame", {
    Size = UDim2.new(1, -24, 1, -116),
    Position = UDim2.fromOffset(12, 110),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Color3.fromRGB(100, 100, 125),
    CanvasSize = UDim2.new(),
}, Page)
local Layout = new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, List)
connect(Layout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
    List.CanvasSize = UDim2.fromOffset(0, Layout.AbsoluteContentSize.Y + 8)
end)

local syncRows = {} -- plr -> { sub, btn, baseText }

local function buildRow(plr, order)
    local isSync = (section == "sync")
    local row = new("Frame", {
        Size = UDim2.new(1, -8, 0, 64),
        BackgroundColor3 = CARD,
        LayoutOrder = order,
    }, List)
    corner(row, 12)
    local img = new("ImageLabel", {
        Size = UDim2.fromOffset(48, 48),
        Position = UDim2.fromOffset(10, 8),
        BackgroundColor3 = Color3.fromRGB(24, 24, 32),
        Image = "rbxthumb://type=AvatarHeadShot&id=" .. plr.UserId .. "&w=150&h=150",
        ScaleType = Enum.ScaleType.Fit,
    }, row)
    corner(img, 24)
    local btnW = isSync and 146 or 112
    local nameLbl = label(row, plr.DisplayName, UDim2.new(1, -(btnW + 88), 0, 22), UDim2.fromOffset(68, 10), 15, TEXT, Enum.Font.GothamBold)
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
    local subLbl = label(row, "@" .. plr.Name, UDim2.new(1, -(btnW + 88), 0, 18), UDim2.fromOffset(68, 34), 12, MUTED, Enum.Font.Gotham)
    subLbl.TextTruncate = Enum.TextTruncate.AtEnd
    local btn = new("TextButton", {
        Size = UDim2.fromOffset(btnW, 34),
        Position = UDim2.new(1, -(btnW + 12), 0, 15),
        BackgroundColor3 = ACCENT,
        Text = isSync and "Синхронизировать" or "Копировать",
        TextColor3 = DARK_TEXT,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
    }, row)
    corner(btn, 9)
    if isSync then
        syncRows[plr] = { sub = subLbl, btn = btn }
        btn.MouseButton1Click:Connect(function()
            local ok, err = Sync.sync(plr)
            if ok then
                toast("Синхронизация с " .. plr.DisplayName, "ok")
            else
                toast(tostring(err), "err")
            end
        end)
    else
        btn.MouseButton1Click:Connect(function() copyFrom(plr) end)
    end
end

local EmptyLbl = label(List, "", UDim2.new(1, -8, 0, 40), UDim2.new(), 13, MUTED, Enum.Font.GothamSemibold)
EmptyLbl.TextWrapped = true
EmptyLbl.Visible = false

local function updateHint()
    if section == "copy" then
        Hint.Text = "Выбери игрока и скопируй его анимации: появится пак «Копия: ник», он сразу применится."
    else
        local key = L.keyLabel(Settings.SyncBind or "J")
        Hint.Text = "Если игрок танцует, нажми «Синхронизировать»: эмоция запустится у тебя (даже не купленная) в такт с ним. "
            .. "Бинд: " .. key .. " — синхронизация с ближайшим танцующим игроком."
    end
end

local function updateSectionButtons()
    for key, b in pairs(SectionButtons) do
        b.BackgroundColor3 = (key == section) and ACCENT or Color3.fromRGB(36, 36, 52)
        b.TextColor3 = (key == section) and DARK_TEXT or TEXT
    end
end

local function rebuild()
    for _, c in ipairs(List:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    syncRows = {}
    updateHint()
    updateSectionButtons()
    local q = string.lower(Search.Text)
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Parent == Players then
            local hay = string.lower(plr.Name .. " " .. plr.DisplayName)
            if q == "" or string.find(hay, q, 1, true) then table.insert(list, plr) end
        end
    end
    if section == "sync" then
        table.sort(list, function(a, b)
            return (Sync.distance(a) or math.huge) < (Sync.distance(b) or math.huge)
        end)
    else
        table.sort(list, function(a, b) return string.lower(a.DisplayName) < string.lower(b.DisplayName) end)
    end
    for i, plr in ipairs(list) do buildRow(plr, i) end
    EmptyLbl.Visible = (#list == 0)
    EmptyLbl.Text = (q ~= "") and "Никого не найдено" or "На сервере больше никого нет"
end

for key, b in pairs(SectionButtons) do
    b.MouseButton1Click:Connect(function()
        section = key
        rebuild()
    end)
end

-- раз в секунду обновляем, кто сейчас танцует и на каком расстоянии
local function updateSync()
    for plr, r in pairs(syncRows) do
        if plr.Parent == Players and r.sub.Parent then
            local d = Sync.detect(plr)
            local dist = Sync.distance(plr)
            local text = "@" .. plr.Name .. (dist and (" · " .. math.floor(dist) .. " м") or "")
            if d then
                text = text .. " · играет: " .. tostring(Sync.nameOf(d.id) or d.name)
            else
                text = text .. " · не танцует"
            end
            r.sub.Text = text
            r.btn.BackgroundColor3 = d and ACCENT or Color3.fromRGB(58, 58, 70)
            r.btn.TextColor3 = d and DARK_TEXT or MUTED
        end
    end
end

local alive = true
Hub.onDestroy(function() alive = false end)
task.spawn(function()
    while alive do
        task.wait(1)
        if UI.getSection() == "players" and section == "sync" then pcall(updateSync) end
    end
end)

local tick = 0
connect(Search:GetPropertyChangedSignal("Text"), function()
    tick += 1
    local t = tick
    task.delay(0.2, function()
        if t == tick and UI.getSection() == "players" then rebuild() end
    end)
end)

local function refreshIfVisible()
    task.delay(0.15, function()
        if UI.getSection() == "players" then rebuild() end
    end)
end
connect(Players.PlayerAdded, refreshIfVisible)
connect(Players.PlayerRemoving, refreshIfVisible)

UI.onShow.players = rebuild
