-- UniversalAnimHub / catalog.lua (модуль; грузится через Loader.lua)
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
local findPack = Hub.Packs.find
local classifyName, objectsAnimId = Hub.Anim.classifyName, Hub.Anim.objectsAnimId

-- ================= КАТАЛОГ ROBLOX =================
local function newSearch(kind, keyword)
    local ok, res = pcall(function()
        local p = CatalogSearchParams.new()
        p.SearchKeyword = keyword or ""
        if kind == "emote" then
            p.AssetTypes = { Enum.AvatarAssetType.EmoteAnimation }
        else
            p.BundleTypes = { Enum.BundleType.Animations }
        end
        p.IncludeOffSale = true
        p.Limit = 30
        pcall(function() p.SortType = Enum.CatalogSortType.MostFavorited end)
        return AES:SearchCatalog(p)
    end)
    if ok then return res end
    return nil, tostring(res)
end

local function getBundleItems(bundleId)
    local items
    pcall(function()
        local d = AES:GetItemDetails(tonumber(bundleId), Enum.AvatarItemType.Bundle)
        local b = d and (d.BundledItems or d.bundledItems)
        if type(b) == "table" then
            items = {}
            for _, it in ipairs(b) do
                table.insert(items, {
                    id = tostring(it.Id or it.id),
                    name = it.Name or it.name,
                    type = it.Type or it.type,
                })
            end
        end
    end)
    if items and #items > 0 then return items end

    -- запасной путь: публичный API каталога через функцию запросов эксплойта
    local req = (typeof(syn) == "table" and syn.request) or http_request or request
        or (typeof(http) == "table" and http.request) or (typeof(fluxus) == "table" and fluxus.request)
    if req then
        local ok, res = pcall(function()
            return req({ Url = "https://catalog.roblox.com/v1/bundles/details?bundleIds=" .. tostring(bundleId), Method = "GET" })
        end)
        if ok and res and res.Body then
            local ok2, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
            local b = ok2 and data and data[1] and data[1].items
            if type(b) == "table" then
                items = {}
                for _, it in ipairs(b) do
                    table.insert(items, { id = tostring(it.id), name = it.name, type = it.type })
                end
                if #items > 0 then return items end
            end
        end
    end
    return nil, "не удалось получить состав набора"
end

local function packFromBundle(bundleId)
    local items, err = getBundleItems(bundleId)
    if not items then return nil, err end

    local byCat = {}
    for _, it in ipairs(items) do
        if it.type == nil or tostring(it.type) == "Asset" then
            local c = classifyName(it.name)
            if c and it.id then
                byCat[c] = byCat[c] or {}
                table.insert(byCat[c], it.id)
            end
        end
    end
    if not (byCat.walk or byCat.run or byCat.idle) then
        return nil, "в наборе нет анимаций движения"
    end

    local def = findPack("Default").ids
    local function real(id)
        local r = objectsAnimId(id)
        return (r and tostring(r):match("%d+")) or id
    end
    local map = {
        idle1 = { "idle", 1 }, idle2 = { "idle", 2 }, walk = { "walk", 1 }, run = { "run", 1 },
        jump = { "jump", 1 }, climb = { "climb", 1 }, fall = { "fall", 1 },
        swim = { "swim", 1 }, swimidle = { "swimidle", 1 },
    }
    local ids = {}
    for slot, m in pairs(map) do
        local list = byCat[m[1]]
        local id = list and list[m[2]]
        ids[slot] = id and real(id) or def[slot]
    end
    if byCat.idle and not byCat.idle[2] then ids.idle2 = ids.idle1 end
    if not byCat.run and byCat.walk then ids.run = ids.walk end
    return ids
end

return { newSearch = newSearch, getBundleItems = getBundleItems, packFromBundle = packFromBundle }
