-- UniversalAnimHub / binds.lua (модуль; грузится через Loader.lua)
-- Бинды эмоций: одна клавиша = одна эмоция. Хранятся в Settings.EmoteBinds[КлавишаName] = { id, name, prefer }.
local Hub = ...
local UIS = game:GetService("UserInputService")
local connect = Hub.connect
local Settings = Hub.Config.Settings
local Emote = Hub.Emote

local Binds = { capturing = nil, onChange = nil }

-- клавиши, которые нельзя занимать (движение и служебные)
local FORBIDDEN = {
    W = true, A = true, S = true, D = true, Space = true, Escape = true,
    Tab = true, Return = true, Slash = true, Unknown = true,
}

local function notify(msg, kind)
    local ui = Hub.UI
    if ui and ui.toast then pcall(ui.toast, msg, kind) end
end

local function changed()
    if Binds.onChange then pcall(Binds.onChange) end
end

function Binds.get(id)
    id = tostring(id)
    for key, e in pairs(Settings.EmoteBinds) do
        if tostring(e.id) == id then return key end
    end
end

function Binds.clear(id)
    local key = Binds.get(id)
    if key then
        Settings.EmoteBinds[key] = nil
        Hub.Config.save()
    end
end

function Binds.set(key, item)
    Binds.clear(item.id) -- у эмоции только одна клавиша
    Settings.EmoteBinds[key] = {
        id = tostring(item.id),
        name = tostring(item.name or "Emote"),
        prefer = item.prefer and true or false,
    }
    Hub.Config.save()
end

function Binds.cancel()
    if Binds.capturing then
        Binds.capturing = nil
        changed()
    end
end

function Binds.capture(item)
    Binds.capturing = { id = tostring(item.id), name = tostring(item.name or "Emote"), prefer = item.prefer and true or false }
    changed()
    notify("Нажми клавишу для «" .. Binds.capturing.name .. "»  (Esc — отмена, Del — снять бинд)")
end

connect(UIS.InputBegan, function(input, gameProcessed)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

    local cap = Binds.capturing
    if cap then
        Binds.capturing = nil
        local key = input.KeyCode
        local name = key.Name
        if key == Enum.KeyCode.Escape then
            notify("Отменено")
        elseif key == Enum.KeyCode.Delete or key == Enum.KeyCode.Backspace then
            Binds.clear(cap.id)
            notify("Бинд снят: " .. cap.name)
        elseif FORBIDDEN[name] or name == Settings.Bind or name == Settings.EmoteBind then
            notify("Эта клавиша занята: " .. name, "err")
        else
            local prev = Settings.EmoteBinds[name]
            Binds.set(name, cap)
            if prev and tostring(prev.id) ~= cap.id then
                notify(name .. ": «" .. cap.name .. "» (заменил «" .. tostring(prev.name) .. "»)", "ok")
            else
                notify(name .. " → «" .. cap.name .. "»", "ok")
            end
        end
        changed()
        return
    end

    if gameProcessed then return end
    local e = Settings.EmoteBinds[input.KeyCode.Name]
    if e then task.spawn(Emote.play, e.id, e.prefer) end
end)

return Binds
