-- UniversalAnimHub / startup.lua (модуль; грузится через Loader.lua)
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

local UI = Hub.UI
local Settings = Hub.Config.Settings
local saveSettings = Hub.Config.save
local SLOTS = Hub.Config.SLOTS
local Packs = Hub.Packs.list
local hasCustom = Hub.Packs.hasCustom
local Driver = Hub.Driver
local healPack = Hub.Anim.healPack
local toast = UI.toast
local ScreenGui = UI.Gui

UI.setSection("packs")

-- Применить сохранённую сборку при запуске
if hasCustom() then
    task.spawn(function()
        task.wait(0.5)
        Driver.Apply()
    end)
end

-- ================= ФОНОВАЯ ПРОВЕРКА ПАКОВ (перепутанные анимации) =================
task.spawn(function()
    task.wait(2)
    for _, pack in ipairs(Packs) do
        if not ScreenGui.Parent then return end
        if not pack.imported and pack.name ~= "Default" and not Settings.HealDone[pack.name] then
            local changes = healPack(pack)
            if changes ~= nil then Settings.HealDone[pack.name] = true end
            if changes and #changes > 0 then
                toast("Исправлен пак " .. pack.name .. ": " .. table.concat(changes, ", "))
                for _, s in ipairs(SLOTS) do
                    if Settings.Slots[s.key] == pack.name then
                        Driver.Apply()
                        break
                    end
                end
            end
            saveSettings()
        end
    end
end)

