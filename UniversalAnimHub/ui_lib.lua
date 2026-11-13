-- UniversalAnimHub / ui_lib.lua (модуль; грузится через Loader.lua)
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
local newSearch = Hub.Catalog.newSearch

-- ================= GUI HELPERS =================
local ACCENT = Color3.fromRGB(255, 140, 70)
local BG = Color3.fromRGB(26, 26, 31)
local BAR = Color3.fromRGB(34, 34, 40)
local CARD = Color3.fromRGB(44, 44, 52)
local CARD_HOVER = Color3.fromRGB(54, 54, 64)
local TEXT = Color3.fromRGB(238, 238, 244)
local MUTED = Color3.fromRGB(150, 150, 162)
local DARK_TEXT = Color3.fromRGB(20, 20, 24)

local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function corner(parent, r)
    return new("UICorner", { CornerRadius = UDim.new(0, r) }, parent)
end

local function label(parent, text, size, pos, textSize, color, font, align)
    return new("TextLabel", {
        BackgroundTransparency = 1,
        Text = text,
        Size = size,
        Position = pos,
        TextSize = textSize or 14,
        TextColor3 = color or TEXT,
        Font = font or Enum.Font.GothamSemibold,
        TextXAlignment = align or Enum.TextXAlignment.Left,
    }, parent)
end

local function makeSwitch(parent, pos, state, callback)
    local bg = new("TextButton", {
        Size = UDim2.fromOffset(46, 24),
        Position = pos,
        Text = "",
        AutoButtonColor = false,
        BackgroundColor3 = state and Color3.fromRGB(70, 190, 100) or Color3.fromRGB(70, 70, 82),
    }, parent)
    corner(bg, 12)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(18, 18),
        Position = state and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
    }, bg)
    corner(knob, 9)

    local function set(v)
        TweenService:Create(bg, TweenInfo.new(0.15), {
            BackgroundColor3 = v and Color3.fromRGB(70, 190, 100) or Color3.fromRGB(70, 70, 82),
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = v and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3),
        }):Play()
    end

    bg.MouseButton1Click:Connect(function()
        state = not state
        set(state)
        callback(state)
    end)
    return set
end

-- ================= БРАУЗЕР КАРТОЧЕК (каталог эмоций / онлайн-паки) =================
local function makeBrowser(parent, pos, size, kind, opts)
    local B = { kind = kind, cards = {}, pages = nil, token = 0, busy = false, started = false, static = false }

    B.frame = new("Frame", {
        Size = size, Position = pos, BackgroundTransparency = 1, Visible = false,
    }, parent)

    B.scroll = new("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Color3.fromRGB(100, 100, 115),
        CanvasSize = UDim2.new(),
    }, B.frame)
    local grid = new("UIGridLayout", {
        CellSize = UDim2.fromOffset(130, 150),
        CellPadding = UDim2.fromOffset(8, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, B.scroll)
    grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        B.scroll.CanvasSize = UDim2.fromOffset(0, grid.AbsoluteContentSize.Y + 8)
    end)

    B.status = new("TextLabel", {
        Size = UDim2.new(1, -20, 0, 40),
        Position = UDim2.new(0, 10, 0, 20),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = MUTED,
        Font = Enum.Font.GothamSemibold,
        TextSize = 14,
        TextWrapped = true,
        ZIndex = 5,
    }, B.frame)

    B.moreBtn = new("TextButton", {
        Text = "Ещё ▼",
        BackgroundColor3 = Color3.fromRGB(46, 46, 56),
        TextColor3 = TEXT,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        LayoutOrder = 1000000,
        Visible = false,
    }, B.scroll)
    corner(B.moreBtn, 10)

    function B:setStatus(text)
        self.status.Text = text or ""
        self.status.Visible = (text ~= nil and text ~= "")
    end

    function B:clear()
        for _, c in ipairs(self.cards) do c.frame:Destroy() end
        self.cards = {}
        self.moreBtn.Visible = false
    end

    function B:refreshActive()
        for _, c in ipairs(self.cards) do
            c.stroke.Enabled = (opts.isActive and opts.isActive(c.item)) or false
        end
    end

    function B:refreshStars()
        if not opts.isFav then return end
        for _, c in ipairs(self.cards) do
            if c.star then
                local fav = opts.isFav(c.item)
                c.star.Text = fav and "★" or "☆"
                c.star.TextColor3 = fav and Color3.fromRGB(255, 205, 70) or TEXT
            end
        end
    end

    function B:addItem(item)
        local card = new("TextButton", {
            Text = "",
            AutoButtonColor = false,
            BackgroundColor3 = CARD,
            LayoutOrder = #self.cards + 1,
            ClipsDescendants = true,
        }, self.scroll)
        corner(card, 10)
        local stroke = new("UIStroke", { Color = ACCENT, Thickness = 2, Enabled = false }, card)

        if item.thumb then
            new("ImageLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -16, 1, -56),
                Position = UDim2.fromOffset(8, 6),
                Image = item.thumb,
                ScaleType = Enum.ScaleType.Fit,
            }, card)
        else
            new("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, -56),
                Position = UDim2.fromOffset(0, 6),
                Text = item.icon or "💃",
                TextSize = 44,
                TextColor3 = TEXT,
                Font = Enum.Font.GothamBold,
            }, card)
        end

        new("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -12, 0, 42),
            Position = UDim2.new(0, 6, 1, -44),
            Text = item.name or "?",
            TextColor3 = TEXT,
            Font = Enum.Font.GothamSemibold,
            TextSize = 12,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            ZIndex = 2,
        }, card)

        local star
        if opts.onStar then
            star = new("TextButton", {
                Size = UDim2.fromOffset(24, 24),
                Position = UDim2.new(1, -28, 0, 4),
                BackgroundColor3 = Color3.fromRGB(30, 30, 36),
                Text = "☆",
                TextColor3 = TEXT,
                Font = Enum.Font.GothamBold,
                TextSize = 15,
                ZIndex = 4,
            }, card)
            corner(star, 7)
            star.MouseButton1Click:Connect(function()
                opts.onStar(item)
                self:refreshStars()
            end)
        end

        card.MouseButton1Click:Connect(function() opts.onClick(item) end)
        card.MouseEnter:Connect(function() card.BackgroundColor3 = CARD_HOVER end)
        card.MouseLeave:Connect(function() card.BackgroundColor3 = CARD end)

        table.insert(self.cards, { frame = card, item = item, stroke = stroke, star = star })
    end

    function B:addItems(list)
        for _, it in ipairs(list) do self:addItem(it) end
        self:refreshStars()
        self:refreshActive()
    end

    function B:consume(tok)
        local pages = self.pages
        local ok, list = pcall(function() return pages:GetCurrentPage() end)
        if tok ~= self.token then return end
        if not ok or type(list) ~= "table" then
            self:setStatus("Не удалось прочитать страницу каталога")
            return
        end
        local items = {}
        for _, it in ipairs(list) do
            local id = tostring(it.Id)
            local item = opts.makeItem(id, it.Name, it)
            if item then table.insert(items, item) end
        end
        self:addItems(items)
        local finished = false
        pcall(function() finished = pages.IsFinished end)
        self.moreBtn.Visible = not finished and #self.cards > 0
        if #self.cards == 0 then
            self:setStatus("Ничего не найдено")
        else
            self:setStatus("")
        end
    end

    function B:search(keyword)
        self.static = false
        self.started = true
        self.token += 1
        local tok = self.token
        self:clear()
        self:setStatus("Загрузка каталога…")
        task.spawn(function()
            local pages, err = newSearch(kind, keyword)
            if tok ~= self.token then return end
            if not pages then
                self:setStatus("Каталог недоступен (AvatarEditorService): " .. tostring(err))
                return
            end
            self.pages = pages
            self:consume(tok)
        end)
    end

    function B:loadMore()
        if self.busy or not self.pages or self.static then return end
        self.busy = true
        self.moreBtn.Text = "Загрузка…"
        local tok = self.token
        task.spawn(function()
            local pages = self.pages
            local ok = pcall(function() pages:AdvanceToNextPageAsync() end)
            self.busy = false
            self.moreBtn.Text = "Ещё ▼"
            if tok ~= self.token then return end
            if ok then
                self:consume(tok)
            else
                self.moreBtn.Visible = false
            end
        end)
    end
    B.moreBtn.MouseButton1Click:Connect(function() B:loadMore() end)

    function B:showStatic(list, emptyText)
        self.static = true
        self.token += 1
        self.pages = nil
        self:clear()
        if #list == 0 then
            self:setStatus(emptyText or "Пусто")
        else
            self:setStatus("")
            self:addItems(list)
        end
    end

    return B
end

return { ACCENT = ACCENT, BG = BG, BAR = BAR, CARD = CARD, CARD_HOVER = CARD_HOVER, TEXT = TEXT, MUTED = MUTED, DARK_TEXT = DARK_TEXT,
    new = new, corner = corner, label = label, makeSwitch = makeSwitch, makeBrowser = makeBrowser }
