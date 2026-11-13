-- UniversalAnimHub / emote.lua (модуль; грузится через Loader.lua)
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
local Settings = Hub.Config.Settings
local loadTrack = Hub.Anim.loadTrack

-- ================= ЭМОЦИИ (движок) =================
local BuiltinEmotes = {
    wave = "507770239", point = "507770453", dance = "507771019", dance2 = "507776043",
    dance3 = "507777268", laugh = "507770818", cheer = "507770677",
}
local EmoteNames = {} -- имя (нижний регистр) -> id, заполняется из каталога

local Emote = { track = nil, id = nil, conn = nil, gen = 0, onChange = nil }

local function stopEmote(fade)
    Emote.gen += 1
    if Emote.conn then pcall(function() Emote.conn:Disconnect() end) Emote.conn = nil end
    local t = Emote.track
    Emote.track = nil
    if t then
        pcall(function() t:Stop(fade or 0.2) end)
        task.delay(0.6, function() pcall(function() t:Destroy() end) end)
    end
    Emote.id = nil
    if Emote.onChange then pcall(Emote.onChange) end
end

local function playEmote(rawId, preferObjects, noToggle)
    local id = tostring(rawId or ""):match("%d+")
    if not id then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = hum
    end

    local same = (Emote.id == id)
    stopEmote(0.2)
    if same and not noToggle then return end -- повторный клик = стоп

    local gen = Emote.gen
    Emote.id = id
    if Emote.onChange then pcall(Emote.onChange) end

    local tr = loadTrack(animator, id, preferObjects, 4)
    if Emote.gen ~= gen then
        if tr then pcall(function() tr:Destroy() end) end
        return
    end
    if not tr then
        Emote.id = nil
        if Emote.onChange then pcall(Emote.onChange) end
        return
    end

    tr.Priority = Enum.AnimationPriority.Action4
    tr:Play(0.2)
    Emote.track = tr
    local startT = os.clock()

    Emote.conn = RunService.Heartbeat:Connect(function()
        if Emote.gen ~= gen then return end
        if not hum.Parent or hum.Health <= 0 then stopEmote(0.1) return end
        local st = hum:GetState()
        if st == Enum.HumanoidStateType.Jumping
            or st == Enum.HumanoidStateType.Freefall
            or st == Enum.HumanoidStateType.Climbing
            or st == Enum.HumanoidStateType.Swimming
            or st == Enum.HumanoidStateType.Dead then
            stopEmote(0.15)
            return
        end
        if Settings.EmoteStopOnMove and hum.MoveDirection.Magnitude > 0.1 then
            stopEmote(0.15)
            return
        end
        -- одноразовая эмоция закончилась
        if os.clock() - startT > 0.5 and not tr.IsPlaying then
            stopEmote(0)
        end
    end)
    return tr
end
Emote.play = playEmote

Emote.stop = stopEmote
Emote.Builtin = BuiltinEmotes
Emote.Names = EmoteNames
return Emote
