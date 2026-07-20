local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ==================== WindUI ====================
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "监狱杀戮光环",
    Author = "by User",
    Icon = "crosshair",
    Folder = "JailAura",
    Size = UDim2.new(0, 580, 0, 420),
})

-- ========== Tab: 杀戮光环 ==========
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

AuraTab:Toggle({
    Title = "队伍检测",
    Desc = "跳过队友，只锁定敌人",
    Value = true,
    Callback = function(v) _G.AuraTeamCheck = v end
})

AuraTab:Toggle({
    Title = "可见性检测",
    Desc = "只锁定视野内可见的敌人",
    Value = true,
    Callback = function(v) _G.AuraVisCheck = v end
})

-- ========== Tab: 绘制 ==========
local EspTab = Window:Tab({ Title = "绘制", Icon = "eye" })

EspTab:Toggle({
    Title = "启用绘制",
    Desc = "总开关",
    Value = false,
    Callback = function(v) _G.EspEnabled = v end
})

EspTab:Toggle({
    Title = "方框",
    Desc = "敌人方框透视",
    Value = true,
    Callback = function(v) _G.EspBox = v end
})

EspTab:Toggle({
    Title = "线条",
    Desc = "从屏幕中心到敌人的连线",
    Value = true,
    Callback = function(v) _G.EspLine = v end
})

EspTab:Toggle({
    Title = "血量",
    Desc = "显示敌人血量文字",
    Value = true,
    Callback = function(v) _G.EspHealth = v end
})

EspTab:Toggle({
    Title = "距离",
    Desc = "显示与敌人的距离",
    Value = false,
    Callback = function(v) _G.EspDist = v end
})

EspTab:Slider({
    Title = "绘制范围",
    Desc = "超过此距离不绘制",
    Value = { Min = 50, Max = 1000, Default = 500 },
    Callback = function(v) _G.EspRange = v end
})

-- ==================== 默认值 ====================
_G.AuraEnabled = false
_G.AuraRange = 50
_G.AuraSmooth = 0.15
_G.AuraTeamCheck = true
_G.AuraVisCheck = true

_G.EspEnabled = false
_G.EspBox = true
_G.EspLine = true
_G.EspHealth = true
_G.EspDist = false
_G.EspRange = 500

-- ==================== 队伍检测 ====================
local function IsSameTeam(targetPlr)
    if _G.AuraTeamCheck == false then return false end
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

-- ==================== 可见性检测 ====================
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

-- ==================== 杀戮光环核心 ====================
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
            if dist <= _G.AuraRange then
                if (not _G.AuraVisCheck) or IsVisible(head) then
                    if dist < bestDist then
                        bestDist = dist
                        bestTarget = head
                        bestPlr = plr
                    end
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
    if _G.AuraVisCheck and not IsVisible(target) then return false end
    return true
end

-- ==================== 绘制核心 ====================
local Drawing = Drawing or {}
local EspObjects = {} -- [Player] = {box, line, healthText, distText}

local function GetEspColor(plr)
    if plr.Team and player.Team and plr.Team == player.Team then
        return Color3.fromRGB(0, 255, 0)
    end
    return Color3.fromRGB(255, 50, 50)
end

local function CreateEsp(plr)
    local box = Drawing.new("Square")
    box.Visible = false
    box.Thickness = 1.5
    box.Filled = false
    box.Color = GetEspColor(plr)

    local line = Drawing.new("Line")
    line.Visible = false
    line.Thickness = 1
    line.Color = GetEspColor(plr)

    local healthText = Drawing.new("Text")
    healthText.Visible = false
    healthText.Size = 13
    healthText.Center = true
    healthText.Outline = true
    healthText.Color = Color3.fromRGB(255, 255, 255)

    local distText = Drawing.new("Text")
    distText.Visible = false
    distText.Size = 13
    distText.Center = true
    distText.Outline = true
    distText.Color = Color3.fromRGB(200, 200, 200)

    EspObjects[plr] = {box = box, line = line, healthText = healthText, distText = distText}
end

local function RemoveEsp(plr)
    local obj = EspObjects[plr]
    if obj then
        for _, d in pairs(obj) do d:Remove() end
        EspObjects[plr] = nil
    end
end

for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= player then CreateEsp(plr) end
end
Players.PlayerAdded:Connect(function(plr) if plr ~= player then CreateEsp(plr) end end)
Players.PlayerRemoving:Connect(RemoveEsp)

-- ==================== 主循环 ====================
RunService.RenderStepped:Connect(function()
    -- ===== 杀戮光环 =====
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

    -- ===== 绘制 =====
    local myChar = player.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myPos = myHrp and myHrp.Position or Vector3.zero

    for plr, obj in pairs(EspObjects) do
        local char = plr.Character
        local head = char and char:FindFirstChild("Head")
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        local shouldShow = _G.EspEnabled and char and head and humanoid and humanoid.Health > 0
        if shouldShow then
            local dist = (head.Position - myPos).Magnitude
            shouldShow = dist <= _G.EspRange and not IsSameTeam(plr)
        end

        if shouldShow then
            local pos, onScreen = Camera:WorldToViewportPoint(head.Position)
            if onScreen then
                local size = 3000 / pos.Z
                size = math.clamp(size, 20, 150)

                -- 方框
                if _G.EspBox then
                    obj.box.Visible = true
                    obj.box.Size = Vector2.new(size, size * 1.4)
                    obj.box.Position = Vector2.new(pos.X - size / 2, pos.Y - size * 0.7)
                    obj.box.Color = GetEspColor(plr)
                else
                    obj.box.Visible = false
                end

                -- 线条
                if _G.EspLine then
                    obj.line.Visible = true
                    obj.line.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    obj.line.To = Vector2.new(pos.X, pos.Y)
                    obj.line.Color = GetEspColor(plr)
                else
                    obj.line.Visible = false
                end

                -- 血量
                if _G.EspHealth then
                    obj.healthText.Visible = true
                    obj.healthText.Position = Vector2.new(pos.X, pos.Y - size * 0.7 - 15)
                    obj.healthText.Text = math.floor(humanoid.Health) .. "/" .. math.floor(humanoid.MaxHealth)
                else
                    obj.healthText.Visible = false
                end

                -- 距离
                if _G.EspDist then
                    obj.distText.Visible = true
                    obj.distText.Position = Vector2.new(pos.X, pos.Y + size * 0.7 + 2)
                    obj.distText.Text = string.format("%.0fm", dist)
                else
                    obj.distText.Visible = false
                end
            else
                for _, d in pairs(obj) do d.Visible = false end
            end
        else
            for _, d in pairs(obj) do d.Visible = false end
        end
    end
end)
