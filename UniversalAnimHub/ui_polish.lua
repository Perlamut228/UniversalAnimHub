-- UniversalAnimHub / ui_polish.lua (модуль; грузится через Loader.lua)
-- Общий слой «живости»: подсветка при наведении и нажатии для всех кнопок интерфейса,
-- включая те, что создаются позже (карточки, пресеты, выбор пака).
local Hub = ...
local TweenService = game:GetService("TweenService")
local UI = Hub.UI
local Gui = UI.Gui

local function tw(obj, t, props)
    pcall(function()
        TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
    end)
end

local function polish(btn)
    if not btn.Parent or btn:GetAttribute("UAHPolished") then return end
    btn:SetAttribute("UAHPolished", true)
    if btn:FindFirstChildOfClass("Frame") then return end -- переключатели со своей анимацией

    btn.AutoButtonColor = false
    local ov = Instance.new("Frame")
    ov.Name = "UAHHover"
    ov.BackgroundColor3 = Color3.new(1, 1, 1)
    ov.BackgroundTransparency = 1
    ov.BorderSizePixel = 0
    ov.Size = UDim2.fromScale(1, 1)
    ov.Active = false
    ov.ZIndex = btn.ZIndex
    local c = btn:FindFirstChildOfClass("UICorner")
    if c then
        local oc = Instance.new("UICorner")
        oc.CornerRadius = c.CornerRadius
        oc.Parent = ov
    end
    ov.Parent = btn

    btn.MouseEnter:Connect(function() tw(ov, 0.12, { BackgroundTransparency = 0.92 }) end)
    btn.MouseLeave:Connect(function() tw(ov, 0.12, { BackgroundTransparency = 1 }) end)
    btn.MouseButton1Down:Connect(function() tw(ov, 0.06, { BackgroundTransparency = 0.82 }) end)
    btn.MouseButton1Up:Connect(function() tw(ov, 0.1, { BackgroundTransparency = 0.92 }) end)
end

for _, d in ipairs(Gui:GetDescendants()) do
    if d:IsA("TextButton") then polish(d) end
end
Hub.connect(Gui.DescendantAdded, function(d)
    if d:IsA("TextButton") then task.defer(polish, d) end
end)
