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
    Value = false,
    Callback = function(v) _G.AuraEnabled = v end
})

AuraTab:Slider({
    Title = "锁定范围",
    Value = { Min = 10, Max = 200, Default = 50 },
    Callback = function(v) _G.AuraRange = v end
})

AuraTab:Slider({
    Title = "平滑度",
    Value = { Min = 5, Max = 100, Default = 15 },
    Callback = function(v) _G.AuraSmooth = v / 100 end
})

AuraTab:Toggle({
    Title = "持续锁定",
    Value = false,
    Callback = function(v) _G.AuraLock = v end
})

AuraTab:Dropdown({
    Title = "优先条件",
    Values = {"距离优先", "血量优先", "视角优先"},
    Value = "距离优先",
    Callback = function(v) _G.AuraPriority = v end
})

local EspTab = Window:Tab({ Title = "绘制", Icon = "eye" })

EspTab:Toggle({
    Title = "启用绘制",
    Value = false,
    Callback = function(v) _G.EspEnabled = v end
})

local BulletTab = Window:Tab({ Title = "子追", Icon = "target" })

BulletTab:Toggle({
    Title = "启用子弹追踪",
    Value = false,
    Callback = function(v) BulletConfig.Enabled = v end
})

BulletTab:Slider({
    Title = "追踪角度范围",
    Value = { Min = 10, Max = 180, Default = 60 },
    Callback = function(v) BulletConfig.FOV = v end
})

BulletTab:Dropdown({
    Title = "优先条件",
    Values = {"FOV优先", "距离优先", "综合评分"},
    Value = "FOV优先",
    Callback = function(v) BulletConfig.Priority = v end
})

BulletTab:Toggle({
    Title = "启用预判",
    Value = false,
    Callback = function(v) BulletConfig.Prediction = v end
})

BulletTab:Slider({
    Title = "预判系数",
    Value = { Min = 5, Max = 50, Default = 15 },
    Callback = function(v) BulletConfig.PredictionFactor = v / 100 end
})

_G.AuraEnabled = false
_G.AuraRange = 50
_G.AuraSmooth = 0.15
_G.AuraLock = false
_G.AuraPriority = "距离优先"

_G.EspEnabled = false

local BulletConfig = {
    Enabled = false,
    FOV = 60,
    Priority = "FOV优先",
    Prediction = false,
    PredictionFactor = 0.15,
}

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

local function FindBestTarget()
    local myChar = player.Character
    if not myChar then return nil end
    local myHrp = myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return nil end
    local myPos = myHrp.Position
    local cameraPos = Camera.CFrame.Position
    local cameraDir = Camera.CFrame.LookVector
    local bestTarget = nil
    local bestScore = math.huge

    if _G.AuraLock and lockedTarget then
        local stillValid = false
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character then
                local char = plr.Character
                local head = char:FindFirstChild("Head")
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if head and humanoid and humanoid.Health > 0 then
                    if head == lockedTarget or (head.Position - lockedTarget.Position).Magnitude < 0.1 then
                        if (head.Position - myPos).Magnitude <= _G.AuraRange and IsVisible(head) then
                            bestTarget = head
                            stillValid = true
                        end
                        break
                    end
                end
            end
        end
        if stillValid then return bestTarget end
        lockedTarget = nil
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character then
            local char = plr.Character
            local head = char:FindFirstChild("Head")
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if head and humanoid and humanoid.Health > 0 then
                if IsSameTeam(plr) then continue end
                local dist = (head.Position - myPos).Magnitude
                if dist <= _G.AuraRange and IsVisible(head) then
                    local score
                    if _G.AuraPriority == "距离优先" then
                        score = dist
                    elseif _G.AuraPriority == "血量优先" then
                        score = humanoid.Health
                    elseif _G.AuraPriority == "视角优先" then
                        local toTarget = (head.Position - cameraPos).Unit
                        local angle = math.deg(math.acos(math.clamp(cameraDir:Dot(toTarget), -1, 1)))
                        score = angle
                    else
                        score = dist
                    end
                    if score < bestScore then
                        bestScore = score
                        bestTarget = head
                    end
                end
            end
        end
    end

    if bestTarget and _G.AuraLock then
        lockedTarget = bestTarget
    end
    return bestTarget
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
                    if onScreen and dist <= MAX_DIST then
                        shouldHide = false
                        local isTeammate = IsSameTeam(plr)
                        local boxColor = isTeammate and BOX_COLOR_TEAM or BOX_COLOR_ENEMY
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

local BulletFOV_Circle = Drawing.new("Circle")
BulletFOV_Circle.Visible = false
BulletFOV_Circle.Radius = 60
BulletFOV_Circle.Color = Color3.fromRGB(255, 255, 255)
BulletFOV_Circle.Thickness = 1
BulletFOV_Circle.Transparency = 1
BulletFOV_Circle.Filled = false
BulletFOV_Circle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    BulletFOV_Circle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end)

local BulletTargetText = Drawing.new("Text")
BulletTargetText.Visible = false
BulletTargetText.Size = 13
BulletTargetText.Color = Color3.fromRGB(255, 255, 255)
BulletTargetText.Outline = true
BulletTargetText.OutlineColor = Color3.fromRGB(0, 0, 0)
BulletTargetText.Center = false
BulletTargetText.Font = Drawing.Fonts.UI

local function getClosestHead()
    local bestHead = nil
    local bestScore = math.huge
    local cameraDirection = Camera.CFrame.LookVector
    local cameraPos = Camera.CFrame.Position
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character then
            local char = plr.Character
            local head = char:FindFirstChild("Head")
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            local forcefield = char:FindFirstChild("ForceField")
            if head and humanoid and not forcefield and humanoid.Health > 0 then
                local targetPos = head.Position
                if BulletConfig.Prediction then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local velocity = hrp.Velocity
                        targetPos = head.Position + velocity * BulletConfig.PredictionFactor
                    end
                end
                local directionToHead = (targetPos - cameraPos).Unit
                local angle = math.deg(math.acos(math.clamp(cameraDirection:Dot(directionToHead), -1, 1)))
                if angle <= BulletConfig.FOV then
                    local worldDist = (targetPos - cameraPos).Magnitude
                    local score
                    if BulletConfig.Priority == "FOV优先" then
                        score = angle
                    elseif BulletConfig.Priority == "距离优先" then
                        score = worldDist
                    elseif BulletConfig.Priority == "综合评分" then
                        score = angle * 0.7 + worldDist * 0.3
                    else
                        score = angle
                    end
                    if score < bestScore then
                        bestScore = score
                        bestHead = head
                    end
                end
            end
        end
    end
    return bestHead
end

local oldHook
pcall(function()
    oldHook = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        if BulletConfig.Enabled and (method == "Raycast" or method == "FindPartOnRay") and not checkcaller() and self == Workspace then
            local origin, direction
            if method == "Raycast" then
                origin = args[1]
                direction = args[2]
            else
                local ray = args[1]
                if typeof(ray) == "Ray" then
                    origin = ray.Origin
                    direction = ray.Direction
                end
            end
            if origin and direction then
                local closestHead = getClosestHead()
                if closestHead then
                    local targetPos = closestHead.Position
                    if BulletConfig.Prediction then
                        local char = closestHead.Parent
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            targetPos = closestHead.Position + hrp.Velocity * BulletConfig.PredictionFactor
                        end
                    end
                    return {
                        Instance = closestHead,
                        Position = targetPos,
                        Normal = (targetPos - origin).Unit,
                        Material = Enum.Material.Plastic
                    }
                end
            end
        end
        return oldHook(self, ...)
    end)
end)

RunService.RenderStepped:Connect(function()
    if _G.AuraEnabled then
        local target = FindBestTarget()
        if target then
            local camPos = Camera.CFrame.Position
            local targetLook = (target.Position - camPos).Unit
            local currentLook = Camera.CFrame.LookVector
            local smoothedLook = currentLook:Lerp(targetLook, _G.AuraSmooth)
            Camera.CFrame = CFrame.new(camPos, camPos + smoothedLook)
        end
    else
        lockedTarget = nil
    end

    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    BulletFOV_Circle.Visible = BulletConfig.Enabled
    BulletFOV_Circle.Radius = BulletConfig.FOV
    BulletFOV_Circle.Position = screenCenter
    if BulletConfig.Enabled then
        local closestHead = getClosestHead()
        if closestHead and closestHead.Parent then
            local targetPlayer = Players:GetPlayerFromCharacter(closestHead.Parent)
            if targetPlayer then
                BulletTargetText.Text = "追踪: " .. targetPlayer.Name
                BulletTargetText.Visible = true
                BulletTargetText.Position = Vector2.new(Camera.ViewportSize.X / 2 + BulletConfig.FOV + 10, Camera.ViewportSize.Y / 2 - 6)
            else
                BulletTargetText.Visible = false
            end
        else
            BulletTargetText.Visible = false
        end
    else
        BulletTargetText.Visible = false
    end

    UpdateESP()
end)
