local BASE_URL = "https://raw.githubusercontent.com/Perlamut228/UniversalAnimHub/main/UniversalAnimHub/"
local LOCAL_DIR = "UniversalAnimHub"

-- порядок важен: модуль может использовать только то, что загружено раньше
local MODULES = {
    { "config", "Config" },
    { "packs", "Packs" },
    { "anim", "Anim" },
    { "emote", "Emote" },
    { "driver", "Driver" },
    { "catalog", "Catalog" },
    { "ui_lib", "UILib" },
    { "ui_main", "UI" },
    { "ui_packs" },
    { "ui_builder" },
    { "ui_emotes" },
    { "ui_settings" },
    { "startup" },
}

local env = (getgenv and getgenv()) or _G
if env.__UniversalAnimHub then
    pcall(env.__UniversalAnimHub.destroy) -- повторный запуск: убираем старую копию
end

local Hub = { Connections = {}, Destroyers = {}, Version = "3.0" }

function Hub.connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(Hub.Connections, c)
    return c
end

function Hub.onDestroy(fn)
    table.insert(Hub.Destroyers, fn)
end

local cleaned = false
function Hub.cleanup()
    if cleaned then return end
    cleaned = true
    for _, fn in ipairs(Hub.Destroyers) do pcall(fn) end
    for _, c in ipairs(Hub.Connections) do pcall(function() c:Disconnect() end) end
end

function Hub.destroy()
    if Hub.Emote then pcall(Hub.Emote.stop, 0) end
    if Hub.Driver then pcall(Hub.Driver.stop) end
    local ui = Hub.UI
    if ui and ui.Gui and ui.Gui.Parent then
        ui.Gui:Destroy() -- Destroying -> Hub.cleanup()
    else
        Hub.cleanup()
    end
end

local function fetch(name)
    local file = name .. ".lua"
    if isfile and readfile then
        local path = LOCAL_DIR .. "/" .. file
        local okf, exists = pcall(isfile, path)
        if okf and exists then return readfile(path), "local" end
    end
    local ok, res = pcall(function() return game:HttpGet(BASE_URL .. file) end)
    if ok and type(res) == "string" and #res > 0 then return res, "remote" end
    error("не удалось загрузить модуль " .. name .. ": " .. tostring(res), 0)
end

-- все модули скачиваются параллельно, выполняются потом строго по порядку
local Sources = {}
local function prefetch()
    local pending = #MODULES
    for _, m in ipairs(MODULES) do
        task.spawn(function()
            local ok, res = pcall(fetch, m[1])
            Sources[m[1]] = { ok = ok, res = res }
            pending -= 1
        end)
    end
    local t0 = os.clock()
    while pending > 0 do
        if os.clock() - t0 > 30 then error("таймаут загрузки модулей", 0) end
        task.wait()
    end
end

local function loadModule(name, key)
    local entry = Sources[name]
    if not entry or not entry.ok then error(tostring(entry and entry.res or ("нет модуля " .. name)), 0) end
    local src = entry.res
    local fn, err = loadstring(src, "=" .. name)
    if not fn then error(name .. ": " .. tostring(err), 0) end
    local result = fn(Hub)
    if key then Hub[key] = result end
    return result
end

env.__UniversalAnimHub = { destroy = Hub.destroy }

local ok, err = pcall(function()
    prefetch()
    for _, m in ipairs(MODULES) do
        loadModule(m[1], m[2])
    end
end)

if not ok then
    warn("[UniversalAnimHub] ошибка загрузки: " .. tostring(err))
    pcall(Hub.destroy)
    env.__UniversalAnimHub = nil
end

return Hub
