local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "监狱杀戮光环",
    Author = "by User",
    Icon = "crosshair",
    Folder = "JailAura",
    Size = UDim2.new(0, 580, 0, 420),
})

local AuraTab = Window:Tab({ Title = "杀戮光环", Icon = "crosshair" })

AuraTab:Toggle({
    Title = "启用杀戮光环",
    Desc = "开启后自动锁定最近敌人",
    Value = false,
    Callback = function(v) _G.AuraEnabled = v end
})

AuraTab:Slider({
    Title = "锁定范围",
    Desc = "搜索敌人的最大距离",
    Value = { Min = 10, Max = 200, Default = 50 },
    Callback = function(v) _G.AuraRange = v end
})

AuraTab:Slider({
    Title = "平滑度",
    Desc = "越小越柔，越大越硬",
    Value = { Min = 5, Max = 100, Default = 15 },
    Callback = function(v) _G.AuraSmooth = v / 100 end
})

local EspTab = Window:Tab({ Title = "绘制", Icon = "eye" })

EspTab:Toggle({
    Title = "启用绘制",
    Desc = "显示敌人方框、名字、血条",
    Value = false,
    Callback = function(v) _G.EspEnabled = v end
})

_G.AuraEnabled = false
_G.AuraRange = 50
_G.AuraSmooth = 0.15

_G.EspEnabled = false

local MAX_DIST = 5000
local BOX_COLOR_TEAM = Color3.fromRGB(255, 255, 255)
local BOX_COLOR_ENEMY = Color3.fromRGB(0, 150, 255)
local FONT_SIZE = 11

local function IsSameTeam(targetPlr)
    if player.Team and targetPlr.Team then
        if player.Team == targetPlr.Team then return true end
    end
    local myChar = player.Character
    local targetChar = targetPlr.Character
    if not myChar or not targetChar then return false end
    local teamProps = {"Team","Role","Side","Faction","TeamColor","TeamName"}
    for _, prop in ipairs(teamProps) do
        local myVal = myChar:FindFirstChild(prop)
        local targetVal = targetChar:FindFirstChild(prop)
        if myVal and targetVal then
            if myVal:IsA("StringValue") and targetVal:IsA("StringValue") then
                if myVal.Value == targetVal.Value then return true end
            elseif myVal:IsA("IntValue") and targetVal:IsA("IntValue") then
                if myVal.Value == targetVal.Value then return true end
            elseif myVal:IsA("BoolValue") and targetVal:IsA("BoolValue") then
                if myVal.Value == targetVal.Value then return true end
            end
        end
    end
    return false
end

local function IsVisible(targetPart)
    if not targetPart then return false end
    local origin = Camera.CFrame.Position
    local direction = targetPart.Position - origin
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {player.Character}
    local result = Workspace:Raycast(origin, direction, raycastParams)
    if not result then return true end
    return result.Instance:IsDescendantOf(targetPart.Parent)
end

local lockedTarget = nil
local lockedPlayer = nil

local function FindBestTarget()
    local myChar = player.Character
    if not myChar then return nil, nil end
    local myHrp = myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return nil, nil end
    local myPos = myHrp.Position
    local bestDist = math.huge
    local bestTarget, bestPlr = nil, nil
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == player then continue end
        if IsSameTeam(plr) then continue end
        if not plr.Character then continue end
        local char = plr.Character
        local head = char:FindFirstChild("Head")
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if head and humanoid and humanoid.Health > 0 then
            local dist = (head.Position - myPos).Magnitude
            if dist <= _G.AuraRange and IsVisible(head) then
                if dist < bestDist then
                    bestDist = dist
                    bestTarget = head
                    bestPlr = plr
                end
            end
        end
    end
    return bestTarget, bestPlr
end

local function IsTargetValid(target, targetPlr)
    if not target or not targetPlr then return false end
    if not targetPlr.Character or target.Parent ~= targetPlr.Character then return false end
    local hum = targetPlr.Character:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    local myChar = player.Character
    if not myChar then return false end
    local myHrp = myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return false end
    local dist = (target.Position - myHrp.Position).Magnitude
    if dist > _G.AuraRange then return false end
    if not IsVisible(target) then return false end
    return true
end

local ESP = { ScreenGui = nil, PlayerElements = {} }

local function CreateScreenGui()
    if ESP.ScreenGui then return end
    ESP.ScreenGui = Instance.new("ScreenGui")
    ESP.ScreenGui.Name = "ESP_Draw"
    ESP.ScreenGui.Parent = game:GetService("CoreGui")
    ESP.ScreenGui.ResetOnSpawn = false
    ESP.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
end

local function CreateESPForPlayer(plr)
    if ESP.PlayerElements[plr] then return end
    if not ESP.ScreenGui then return end
    local sg = ESP.ScreenGui
    local elements = {}
    elements.Box = Instance.new("Frame")
    elements.Box.Parent = sg
    elements.Box.BackgroundColor3 = BOX_COLOR_ENEMY
    elements.Box.BackgroundTransparency = 0.75
    elements.Box.BorderSizePixel = 0
    elements.Box.Visible = false
    elements.Box.ZIndex = 10
    elements.Outline = Instance.new("UIStroke")
    elements.Outline.Parent = elements.Box
    elements.Outline.Enabled = true
    elements.Outline.Transparency = 0
    elements.Outline.Color = BOX_COLOR_ENEMY
    elements.Outline.LineJoinMode = Enum.LineJoinMode.Miter
    elements.Outline.Thickness = 1
    elements.Name = Instance.new("TextLabel")
    elements.Name.Parent = sg
    elements.Name.BackgroundTransparency = 1
    elements.Name.TextColor3 = BOX_COLOR_ENEMY
    elements.Name.Font = Enum.Font.Code
    elements.Name.TextSize = FONT_SIZE
    elements.Name.TextStrokeTransparency = 0
    elements.Name.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    elements.Name.RichText = true
    elements.Name.Visible = false
    elements.Name.ZIndex = 11
    elements.Distance = Instance.new("TextLabel")
    elements.Distance.Parent = sg
    elements.Distance.BackgroundTransparency = 1
    elements.Distance.TextColor3 = Color3.fromRGB(255, 255, 255)
    elements.Distance.Font = Enum.Font.Code
    elements.Distance.TextSize = FONT_SIZE
    elements.Distance.TextStrokeTransparency = 0
    elements.Distance.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    elements.Distance.RichText = true
    elements.Distance.Visible = false
    elements.Distance.ZIndex = 11
    elements.BehindHealth = Instance.new("Frame")
    elements.BehindHealth.Parent = sg
    elements.BehindHealth.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    elements.BehindHealth.BackgroundTransparency = 0
    elements.BehindHealth.BorderSizePixel = 0
    elements.BehindHealth.Visible = false
    elements.BehindHealth.ZIndex = 9
    elements.Healthbar = Instance.new("Frame")
    elements.Healthbar.Parent = sg
    elements.Healthbar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    elements.Healthbar.BackgroundTransparency = 0
    elements.Healthbar.BorderSizePixel = 0
    elements.Healthbar.Visible = false
    elements.Healthbar.ZIndex = 10
    elements.HealthText = Instance.new("TextLabel")
    elements.HealthText.Parent = sg
    elements.HealthText.BackgroundTransparency = 1
    elements.HealthText.TextColor3 = Color3.fromRGB(255, 255, 255)
    elements.HealthText.Font = Enum.Font.Code
    elements.HealthText.TextSize = FONT_SIZE
    elements.HealthText.TextStrokeTransparency = 0
    elements.HealthText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    elements.HealthText.Visible = false
    elements.HealthText.ZIndex = 11
    ESP.PlayerElements[plr] = elements
end

local function DestroyESPForPlayer(plr)
    local elements = ESP.PlayerElements[plr]
    if elements then
        for _, v in pairs(elements) do
            if v then pcall(function() v:Destroy() end) end
        end
        ESP.PlayerElements[plr] = nil
    end
end

local function UpdateESP()
    local camera = workspace.CurrentCamera
    if not camera then return end
    for plr, elements in pairs(ESP.PlayerElements) do
        pcall(function()
            local shouldHide = true
            if _G.EspEnabled and plr and plr.Character then
                local char = plr.Character
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local hum = char:FindFirstChildOfClass("Humanoid")
                local head = char:FindFirstChild("Head")
                if hrp and hum and hum.Health > 0 then
                    local pos, onScreen = camera:WorldToScreenPoint(hrp.Position)
                    local dist = (camera.CFrame.Position - hrp.Position).Magnitude
                    if onScreen and dist <= MAX_DIST and not IsSameTeam(plr) then
                        shouldHide = false
                        local boxColor = BOX_COLOR_ENEMY
                        local size = hrp.Size.Y
                        local scaleFactor = (size * camera.ViewportSize.Y) / (pos.Z * 2)
                        local w = 3 * scaleFactor
                        local h = 4.5 * scaleFactor
                        local fadeTrans = math.clamp(dist / MAX_DIST, 0, 0.85)
                        elements.Box.Position = UDim2.new(0, pos.X - w/2, 0, pos.Y - h/2)
                        elements.Box.Size = UDim2.new(0, w, 0, h)
                        elements.Box.Visible = true
                        elements.Box.BackgroundTransparency = 0.75 + fadeTrans * 0.15
                        elements.Box.BackgroundColor3 = boxColor
                        elements.Outline.Enabled = true
                        elements.Outline.Transparency = fadeTrans
                        elements.Outline.Color = boxColor
                        elements.Name.Text = plr.Name .. string.format(" [%dm]", math.floor(dist))
                        elements.Name.Position = UDim2.new(0, pos.X, 0, pos.Y - h/2 - 9)
                        elements.Name.TextColor3 = boxColor
                        elements.Name.TextTransparency = fadeTrans
                        elements.Name.TextStrokeTransparency = fadeTrans
                        elements.Name.Visible = true
                        elements.Distance.Visible = false
                        local healthRatio = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                        local barW = 2.5
                        local barX = pos.X - w/2 - 6
                        elements.BehindHealth.Position = UDim2.new(0, barX, 0, pos.Y - h/2)
                        elements.BehindHealth.Size = UDim2.new(0, barW, 0, h)
                        elements.BehindHealth.BackgroundTransparency = fadeTrans
                        elements.BehindHealth.Visible = true
                        elements.Healthbar.Position = UDim2.new(0, barX, 0, pos.Y - h/2 + h * (1 - healthRatio))
                        elements.Healthbar.Size = UDim2.new(0, barW, 0, h * healthRatio)
                        elements.Healthbar.BackgroundTransparency = fadeTrans
                        elements.Healthbar.Visible = true
                        local healthPercent = math.floor(healthRatio * 100)
                        elements.HealthText.Position = UDim2.new(0, barX, 0, pos.Y - h/2 + h * (1 - healthPercent/100) + 3)
                        elements.HealthText.Text = tostring(healthPercent) .. "%"
                        elements.HealthText.TextTransparency = fadeTrans
                        elements.HealthText.TextStrokeTransparency = fadeTrans
                        elements.HealthText.Visible = (hum.Health < hum.MaxHealth)
                    end
                end
            end
            if shouldHide then
                elements.Box.Visible = false
                elements.Outline.Enabled = false
                elements.Name.Visible = false
                elements.Distance.Visible = false
                elements.BehindHealth.Visible = false
                elements.Healthbar.Visible = false
                elements.HealthText.Visible = false
            end
        end)
    end
    for plr, _ in pairs(ESP.PlayerElements) do
        if not Players:FindFirstChild(plr.Name) then
            DestroyESPForPlayer(plr)
        end
    end
end

local function InitEvents()
    Players.PlayerAdded:Connect(function(plr)
        if plr == player then return end
        CreateESPForPlayer(plr)
        plr.CharacterAdded:Connect(function()
            task.wait(0.1)
            if not ESP.PlayerElements[plr] then
                CreateESPForPlayer(plr)
            end
        end)
    end)
    Players.PlayerRemoving:Connect(function(plr)
        DestroyESPForPlayer(plr)
    end)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            CreateESPForPlayer(plr)
            plr.CharacterAdded:Connect(function()
                task.wait(0.1)
                if not ESP.PlayerElements[plr] then
                    CreateESPForPlayer(plr)
                end
            end)
        end
    end
end

CreateScreenGui()
InitEvents()

RunService.RenderStepped:Connect(function()
    if _G.AuraEnabled then
        if not IsTargetValid(lockedTarget, lockedPlayer) then
            lockedTarget, lockedPlayer = FindBestTarget()
        end
        if lockedTarget then
            local camPos = Camera.CFrame.Position
            local targetLook = (lockedTarget.Position - camPos).Unit
            local currentLook = Camera.CFrame.LookVector
            local smoothedLook = currentLook:Lerp(targetLook, _G.AuraSmooth)
            Camera.CFrame = CFrame.new(camPos, camPos + smoothedLook)
        end
    else
        lockedTarget, lockedPlayer = nil, nil
    end
    UpdateESP()
end)
