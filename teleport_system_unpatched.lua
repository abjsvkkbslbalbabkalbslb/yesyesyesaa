local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local Debris = game:GetService("Debris")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local TeleportSystem = {}
TeleportSystem.__index = TeleportSystem

function TeleportSystem.new()
    local self = setmetatable({}, TeleportSystem)
    
    self.character = nil
    self.humanoidRootPart = nil
    self.humanoid = nil
    self.isActive = false
    self.teleportAmount = 120
    self.random = Random.new()
    self.gui = nil
    self.dragConnection = nil
    self.isDragging = false
    self.dragStart = nil
    self.startPos = nil
    self.isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    self.lastValidPosition = nil
    self.bypassEnabled = true
    self.voidBypassPart = nil
    self.mapBoundsBypass = nil
    self.heartbeatConnection = nil
    self.antiKickEnabled = true
    
    self:initialize()
    return self
end

function TeleportSystem:initialize()
    self:setupAntiCheatBypass()
    self:setupNetworkMonitoring()
    self:setupCharacterConnection()
    self:createGui()
    self:setupInputHandling()
    self:setupVoidProtection()
    self:setupMapBoundsSpoof()
end

function TeleportSystem:setupVoidProtection()
    spawn(function()
        while self.isActive do
            pcall(function()
                if not self.voidBypassPart then
                    self.voidBypassPart = Instance.new("Part")
                    self.voidBypassPart.Name = "VoidBypass_" .. tostring(math.random(10000, 99999))
                    self.voidBypassPart.Anchored = true
                    self.voidBypassPart.CanCollide = false
                    self.voidBypassPart.Transparency = 1
                    self.voidBypassPart.Size = Vector3.new(50000, 1, 50000)
                    self.voidBypassPart.Position = Vector3.new(0, -1000, 0)
                    self.voidBypassPart.Material = Enum.Material.ForceField
                    self.voidBypassPart.Parent = workspace
                    
                    local mesh = Instance.new("SpecialMesh")
                    mesh.MeshType = Enum.MeshType.Brick
                    mesh.Scale = Vector3.new(1, 0.01, 1)
                    mesh.Parent = self.voidBypassPart
                end
                
                if self.voidBypassPart and not self.voidBypassPart.Parent then
                    self.voidBypassPart.Parent = workspace
                end
            end)
            wait(2)
        end
    end)
end

function TeleportSystem:setupMapBoundsSpoof()
    spawn(function()
        while self.isActive do
            pcall(function()
                if self:validateCharacter() then
                    local currentPos = self.humanoidRootPart.Position
                    
                    if math.abs(currentPos.X) > 10000 or math.abs(currentPos.Z) > 10000 or currentPos.Y < -800 then
                        if self.lastValidPosition then
                            local safePos = self.lastValidPosition.Position
                            if safePos.Y > -100 then
                                self.humanoidRootPart.CFrame = CFrame.new(safePos + Vector3.new(0, 5, 0))
                            else
                                self.humanoidRootPart.CFrame = CFrame.new(0, 50, 0)
                            end
                        end
                    end
                    
                    if currentPos.Y > -100 and currentPos.Y < 1000 then
                        self.lastValidPosition = self.humanoidRootPart.CFrame
                    end
                end
            end)
            wait(0.1)
        end
    end)
end

function TeleportSystem:setupAntiCheatBypass()
    spawn(function()
        while self.isActive do
            pcall(function()
                if self:validateCharacter() then
                    local pos = self.humanoidRootPart.Position
                    
                    if pos.Y < -500 and self.lastValidPosition then
                        self.humanoidRootPart.CFrame = self.lastValidPosition
                    end
                    
                    if self.humanoid.Health <= 0 and self.lastValidPosition then
                        wait(0.1)
                        if self:validateCharacter() then
                            self.humanoidRootPart.CFrame = self.lastValidPosition
                        end
                    end
                    
                    self.humanoid.PlatformStand = false
                    
                    if self.humanoid.Sit then
                        self.humanoid.Sit = false
                    end
                end
            end)
            wait(0.05)
        end
    end)
end

function TeleportSystem:setupNetworkMonitoring()
    spawn(function()
        while self.isActive do
            pcall(function()
                local ping = Player:GetNetworkPing() * 1000
                self.teleportAmount = math.clamp(math.floor(ping * 1.2), 60, 200)
            end)
            wait(0.8)
        end
    end)
end

function TeleportSystem:setupCharacterConnection()
    local function onCharacterAdded(character)
        self.character = character
        self.humanoidRootPart = character:WaitForChild("HumanoidRootPart")
        self.humanoid = character:WaitForChild("Humanoid")
        
        self.humanoid.StateChanged:Connect(function(oldState, newState)
            if newState == Enum.HumanoidStateType.Dead then
                self:handleCharacterDeath()
            end
        end)
        
        self.humanoid.PlatformStand = false
        self.humanoid.Sit = false
        
        spawn(function()
            wait(1)
            if self:validateCharacter() then
                self.lastValidPosition = self.humanoidRootPart.CFrame
            end
        end)
    end
    
    if Player.Character then
        onCharacterAdded(Player.Character)
    end
    
    Player.CharacterAdded:Connect(onCharacterAdded)
end

function TeleportSystem:handleCharacterDeath()
    self.character = nil
    self.humanoidRootPart = nil
    self.humanoid = nil
end

function TeleportSystem:validateCharacter()
    return self.character and self.humanoidRootPart and self.humanoidRootPart.Parent and self.humanoid
end

function TeleportSystem:safeWait(duration)
    local startTime = tick()
    while tick() - startTime < duration and self:validateCharacter() do
        RunService.Heartbeat:Wait()
    end
end

function TeleportSystem:createAdvancedSafetyNet(targetPosition)
    local safetyParts = {}
    
    for i = 1, 5 do
        local safetyPart = Instance.new("Part")
        safetyPart.Name = "SafetyNet_" .. tostring(i)
        safetyPart.Anchored = true
        safetyPart.CanCollide = false
        safetyPart.Transparency = 1
        safetyPart.Size = Vector3.new(100, 2, 100)
        safetyPart.Position = targetPosition + Vector3.new(0, -20 - (i * 10), 0)
        safetyPart.Material = Enum.Material.ForceField
        safetyPart.Parent = workspace
        
        table.insert(safetyParts, safetyPart)
        
        Debris:AddItem(safetyPart, 10)
    end
    
    return safetyParts
end

function TeleportSystem:enhancedTeleport(targetCFrame)
    if not self:validateCharacter() or typeof(targetCFrame) ~= "CFrame" then
        return false
    end
    
    local originalCFrame = self.humanoidRootPart.CFrame
    local distance = (originalCFrame.Position - targetCFrame.Position).Magnitude
    
    self:createAdvancedSafetyNet(targetCFrame.Position)
    
    if distance > 2000 then
        return self:extremeLongDistanceTeleport(targetCFrame)
    elseif distance > 500 then
        return self:ultraLongDistanceTeleport(targetCFrame)
    elseif distance > 100 then
        return self:longDistanceTeleport(targetCFrame)
    else
        return self:standardTeleport(targetCFrame)
    end
end

function TeleportSystem:extremeLongDistanceTeleport(targetCFrame)
    local startPos = self.humanoidRootPart.Position
    local endPos = targetCFrame.Position
    local totalDistance = (startPos - endPos).Magnitude
    
    local segments = math.min(math.ceil(totalDistance / 400), 50)
    
    for i = 1, segments do
        if not self:validateCharacter() then return false end
        
        local progress = i / segments
        local segmentPos = startPos:lerp(endPos, progress)
        local segmentCFrame = CFrame.new(segmentPos, endPos - segmentPos)
        
        local microSteps = math.floor(self.teleportAmount / (segments * 2))
        for j = 1, math.max(microSteps, 8) do
            if not self:validateCharacter() then return false end
            
            local microOffset = Vector3.new(
                self.random:NextNumber(-1, 1),
                self.random:NextNumber(-1, 1),
                self.random:NextNumber(-1, 1)
            )
            
            local tempCFrame = segmentCFrame + microOffset
            
            self.humanoidRootPart.Anchored = true
            self.humanoidRootPart.CFrame = tempCFrame
            self.humanoidRootPart.Anchored = false
            
            RunService.Heartbeat:Wait()
        end
        
        self:safeWait(0.01)
    end
    
    return self:finalizePosition(targetCFrame)
end

function TeleportSystem:ultraLongDistanceTeleport(targetCFrame)
    local startPos = self.humanoidRootPart.Position
    local endPos = targetCFrame.Position
    local totalDistance = (startPos - endPos).Magnitude
    
    local segments = math.min(math.ceil(totalDistance / 200), 30)
    
    for i = 1, segments do
        if not self:validateCharacter() then return false end
        
        local progress = i / segments
        local segmentPos = startPos:lerp(endPos, progress)
        local segmentCFrame = CFrame.new(segmentPos, endPos - segmentPos)
        
        local microSteps = math.floor(self.teleportAmount / segments)
        for j = 1, math.max(microSteps, 10) do
            if not self:validateCharacter() then return false end
            
            local microOffset = Vector3.new(
                self.random:NextNumber(-0.7, 0.7),
                self.random:NextNumber(-0.7, 0.7),
                self.random:NextNumber(-0.7, 0.7)
            )
            
            local tempCFrame = segmentCFrame + microOffset
            
            self.humanoidRootPart.Anchored = true
            self.humanoidRootPart.CFrame = tempCFrame
            self.humanoidRootPart.Anchored = false
            
            RunService.Heartbeat:Wait()
        end
        
        self:safeWait(0.015)
    end
    
    return self:finalizePosition(targetCFrame)
end

function TeleportSystem:longDistanceTeleport(targetCFrame)
    local startPos = self.humanoidRootPart.Position
    local endPos = targetCFrame.Position
    local distance = (startPos - endPos).Magnitude
    
    local steps = math.min(math.ceil(distance / 50), 20)
    
    for i = 1, steps do
        if not self:validateCharacter() then return false end
        
        local progress = i / steps
        local intermediatePos = startPos:lerp(endPos, progress)
        local intermediateCFrame = CFrame.new(intermediatePos, endPos - intermediatePos)
        
        local stepAmount = math.floor(self.teleportAmount / steps)
        for j = 1, math.max(stepAmount, 15) do
            if not self:validateCharacter() then return false end
            
            local offset = Vector3.new(
                self.random:NextNumber(-0.5, 0.5),
                self.random:NextNumber(-0.5, 0.5),
                self.random:NextNumber(-0.5, 0.5)
            )
            
            self.humanoidRootPart.Anchored = true
            self.humanoidRootPart.CFrame = intermediateCFrame + offset
            self.humanoidRootPart.Anchored = false
            
            RunService.Heartbeat:Wait()
        end
        
        self:safeWait(0.008)
    end
    
    return self:finalizePosition(targetCFrame)
end

function TeleportSystem:standardTeleport(targetCFrame)
    for i = 1, self.teleportAmount do
        if not self:validateCharacter() then return false end
        
        local offset = Vector3.new(
            self.random:NextNumber(-0.2, 0.2),
            self.random:NextNumber(-0.2, 0.2),
            self.random:NextNumber(-0.2, 0.2)
        )
        
        self.humanoidRootPart.Anchored = true
        self.humanoidRootPart.CFrame = targetCFrame + offset
        self.humanoidRootPart.Anchored = false
        
        RunService.Heartbeat:Wait()
    end
    
    return self:finalizePosition(targetCFrame)
end

function TeleportSystem:finalizePosition(targetCFrame)
    if not self:validateCharacter() then return false end
    
    local alternatePositions = {
        targetCFrame,
        targetCFrame * CFrame.new(0, 8, 0),
        targetCFrame * CFrame.new(0, -8, 0),
        targetCFrame * CFrame.new(3, 0, 0),
        targetCFrame * CFrame.new(-3, 0, 0),
        targetCFrame * CFrame.new(0, 0, 3),
        targetCFrame * CFrame.new(0, 0, -3)
    }
    
    for attempt = 1, 12 do
        if not self:validateCharacter() then return false end
        
        local usePosition = alternatePositions[((attempt - 1) % #alternatePositions) + 1]
        
        self.humanoidRootPart.Anchored = true
        self.humanoidRootPart.CFrame = usePosition
        self.humanoidRootPart.Anchored = false
        
        self:safeWait(0.02)
        
        if self:validateCharacter() then
            self.lastValidPosition = self.humanoidRootPart.CFrame
        end
    end
    
    return true
end

function TeleportSystem:findDeliveryBox()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    
    for _, plot in pairs(plots:GetChildren()) do
        local plotSign = plot:FindFirstChild("PlotSign")
        if plotSign then
            local yourBase = plotSign:FindFirstChild("YourBase")
            if yourBase and yourBase.Enabled then
                local deliveryHitbox = plot:FindFirstChild("DeliveryHitbox")
                if deliveryHitbox then
                    return deliveryHitbox
                end
            end
        end
    end
    
    return nil
end

function TeleportSystem:findNearestBase()
    local plotsFolder = workspace:FindFirstChild("Plots")
    if not plotsFolder or not self:validateCharacter() then return nil end
    
    local closestPodium = nil
    local shortestDistance = math.huge
    
    for _, plot in pairs(plotsFolder:GetChildren()) do
        local plotSign = plot:FindFirstChild("PlotSign")
        if plotSign then
            local surfaceGui = plotSign:FindFirstChild("SurfaceGui")
            if surfaceGui then
                local frame = surfaceGui:FindFirstChild("Frame")
                if frame then
                    local textLabel = frame:FindFirstChild("TextLabel")
                    if textLabel and textLabel.ContentText ~= "Empty Base" then
                        local yourBase = plotSign:FindFirstChild("YourBase")
                        if yourBase and not yourBase.Enabled then
                            local podiums = plot:FindFirstChild("AnimalPodiums")
                            if podiums then
                                for _, podium in pairs(podiums:GetChildren()) do
                                    if podium:IsA("Model") then
                                        local base = podium:FindFirstChild("Base")
                                        if base then
                                            local spawn = base:FindFirstChild("Spawn")
                                            if spawn then
                                                local distance = (spawn.Position - self.humanoidRootPart.Position).Magnitude
                                                if distance < shortestDistance then
                                                    shortestDistance = distance
                                                    closestPodium = spawn
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    return closestPodium
end

function TeleportSystem:executeAdvancedTeleport(targetCFrame, statusLabel, operationType)
    if not self:validateCharacter() then
        self:updateStatus(statusLabel, "Error: Character not found", Color3.fromRGB(255, 80, 80))
        return false
    end
    
    if not targetCFrame then
        self:updateStatus(statusLabel, "Error: Target location not found", Color3.fromRGB(255, 80, 80))
        return false
    end
    
    self:updateStatus(statusLabel, "Initiating " .. operationType .. "...", Color3.fromRGB(255, 255, 100))
    
    local originalPosition = self.humanoidRootPart.Position
    local success = self:enhancedTeleport(targetCFrame)
    
    self:safeWait(0.3)
    
    if not self:validateCharacter() then
        self:updateStatus(statusLabel, "Error: Character lost during teleport", Color3.fromRGB(255, 80, 80))
        return false
    end
    
    local distance = (self.humanoidRootPart.Position - targetCFrame.Position).Magnitude
    
    if success and distance <= 500 then
        self:updateStatus(statusLabel, operationType .. " Successful!", Color3.fromRGB(0, 255, 100))
        return true
    else
        self:updateStatus(statusLabel, string.format("%s Failed: Distance %.0f", operationType, distance), Color3.fromRGB(255, 80, 80))
        return false
    end
end

function TeleportSystem:teleportToDelivery(statusLabel)
    local deliveryBox = self:findDeliveryBox()
    if not deliveryBox then
        self:updateStatus(statusLabel, "Error: Delivery box not found", Color3.fromRGB(255, 80, 80))
        return
    end
    
    local targetCFrame = deliveryBox.CFrame * CFrame.new(0, -3, 0)
    self:executeAdvancedTeleport(targetCFrame, statusLabel, "Delivery Teleport")
end

function TeleportSystem:teleportToNearestBase(statusLabel)
    local nearestBase = self:findNearestBase()
    if not nearestBase then
        self:updateStatus(statusLabel, "Error: No valid base found", Color3.fromRGB(255, 80, 80))
        return
    end
    
    local targetCFrame = nearestBase.CFrame * CFrame.new(0, 2, 0)
    self:executeAdvancedTeleport(targetCFrame, statusLabel, "Base Teleport")
end

function TeleportSystem:smoothTeleport(statusLabel)
    local deliveryBox = self:findDeliveryBox()
    if not deliveryBox then
        self:updateStatus(statusLabel, "Error: Delivery box not found", Color3.fromRGB(255, 80, 80))
        return
    end
    
    if not self:validateCharacter() then
        self:updateStatus(statusLabel, "Error: Character not found", Color3.fromRGB(255, 80, 80))
        return
    end
    
    local targetCFrame = deliveryBox.CFrame * CFrame.new(0, -2, 0)
    local startPosition = self.humanoidRootPart.Position
    local endPosition = targetCFrame.Position
    local distance = (startPosition - endPosition).Magnitude
    
    self:updateStatus(statusLabel, "Executing smooth teleport...", Color3.fromRGB(255, 255, 100))
    
    local steps = math.min(math.max(40, math.floor(distance / 20)), 150)
    local stepDuration = math.max(0.005, 0.8 / steps)
    
    for i = 1, steps do
        if not self:validateCharacter() then
            self:updateStatus(statusLabel, "Error: Character lost during smooth teleport", Color3.fromRGB(255, 80, 80))
            return
        end
        
        local progress = i / steps
        local smoothProgress = progress * progress * (3 - 2 * progress)
        
        local newPosition = startPosition:lerp(endPosition, smoothProgress)
        local jitter = Vector3.new(
            self.random:NextNumber(-0.3, 0.3),
            self.random:NextNumber(-0.3, 0.3),
            self.random:NextNumber(-0.3, 0.3)
        )
        
        self.humanoidRootPart.Anchored = true
        self.humanoidRootPart.CFrame = CFrame.new(newPosition + jitter, endPosition - newPosition)
        self.humanoidRootPart.Anchored = false
        
        self:safeWait(stepDuration)
    end
    
    self:finalizePosition(targetCFrame)
    
    self:safeWait(0.3)
    
    if self:validateCharacter() then
        local finalDistance = (self.humanoidRootPart.Position - targetCFrame.Position).Magnitude
        if finalDistance <= 500 then
            self:updateStatus(statusLabel, "Smooth Teleport Successful!", Color3.fromRGB(0, 255, 100))
        else
            self:updateStatus(statusLabel, string.format("Smooth Teleport Failed: Distance %.0f", finalDistance), Color3.fromRGB(255, 80, 80))
        end
    else
        self:updateStatus(statusLabel, "Smooth Teleport Failed: Character error", Color3.fromRGB(255, 80, 80))
    end
end

function TeleportSystem:updateStatus(statusLabel, message, color)
    statusLabel.Text = message
    statusLabel.TextColor3 = color
    
    TweenService:Create(statusLabel, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
    
    spawn(function()
        wait(3)
        TweenService:Create(statusLabel, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
    end)
end

function TeleportSystem:createGui()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "TeleportGui"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = 999
    screenGui.Parent = PlayerGui
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Parent = screenGui
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    mainFrame.BorderSizePixel = 0
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    mainFrame.ClipsDescendants = true
    
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, 15)
    uiCorner.Parent = mainFrame
    
    local uiStroke = Instance.new("UIStroke")
    uiStroke.Parent = mainFrame
    uiStroke.Color = Color3.fromRGB(0, 255, 127)
    uiStroke.Thickness = 2
    uiStroke.Transparency = 0.3
    
    local uiGradient = Instance.new("UIGradient")
    uiGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 20, 25)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 15))
    })
    uiGradient.Rotation = 45
    uiGradient.Parent = mainFrame
    
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Parent = mainFrame
    titleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    titleBar.BorderSizePixel = 0
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.Active = true
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 15)
    titleCorner.Parent = titleBar
    
    local titleGradient = Instance.new("UIGradient")
    titleGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 35)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 25))
    })
    titleGradient.Rotation = 90
    titleGradient.Parent = titleBar
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Parent = titleBar
    titleLabel.BackgroundTransparency = 1
    titleLabel.Size = UDim2.new(1, -70, 1, 0)
    titleLabel.Position = UDim2.new(0, 15, 0, 0)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Text = "⚡ TELEPORT SYSTEM - UNPATCHED V2"
    titleLabel.TextColor3 = Color3.fromRGB(0, 255, 127)
    titleLabel.TextSize = self.isMobile and 12 or 14
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Parent = titleBar
    closeButton.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    closeButton.BorderSizePixel = 0
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -35, 0, 5)
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Text = "×"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextSize = self.isMobile and 16 or 18
    closeButton.AutoButtonColor = false
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 15)
    closeCorner.Parent = closeButton
    
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Parent = mainFrame
    content.BackgroundTransparency = 1
    content.Position = UDim2.new(0, 0, 0, 40)
    content.Size = UDim2.new(1, 0, 1, -40)
    
    local deliveryButton = self:createButton(content, "📦 Teleport to Delivery", UDim2.new(0.05, 0, 0.08, 0))
    local baseButton = self:createButton(content, "🏠 Teleport to Base", UDim2.new(0.05, 0, 0.28, 0))
    local smoothButton = self:createButton(content, "🌟 Smooth Teleport", UDim2.new(0.05, 0, 0.48, 0))
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Parent = content
    statusLabel.BackgroundTransparency = 1
    statusLabel.Size = UDim2.new(0.9, 0, 0, 30)
    statusLabel.Position = UDim2.new(0.05, 0, 0.72, 0)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    statusLabel.TextSize = self.isMobile and 11 or 12
    statusLabel.TextTransparency = 1
    statusLabel.Text = ""
    statusLabel.TextWrapped = true
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "InfoLabel"
    infoLabel.Parent = content
    infoLabel.BackgroundTransparency = 1
    infoLabel.Size = UDim2.new(0.9, 0, 0, 25)
    infoLabel.Position = UDim2.new(0.05, 0, 0.85, 0)
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
    infoLabel.TextSize = self.isMobile and 9 or 10
    infoLabel.Text = self.isMobile and "Drag title bar to move â€¢ Tap P to toggle" or "Drag title bar to move â€¢ Press P to toggle"
    infoLabel.TextWrapped = true
    
    self.gui = screenGui
    self.isActive = true
    
    self:setupDragFunctionality(titleBar, mainFrame)
    self:setupButtonEvents(deliveryButton, baseButton, smoothButton, closeButton, statusLabel)
    self:animateGuiOpen(mainFrame)
end

function TeleportSystem:setupDragFunctionality(titleBar, mainFrame)
    local function startDrag(input)
        if self.isDragging then return end
        
        self.isDragging = true
        self.dragStart = input.Position
        self.startPos = mainFrame.Position
        
        local function updateDrag(input)
            if not self.isDragging then return end
            
            local delta = input.Position - self.dragStart
            local newPosition = UDim2.new(
                self.startPos.X.Scale,
                self.startPos.X.Offset + delta.X,
                self.startPos.Y.Scale,
                self.startPos.Y.Offset + delta.Y
            )
            
            mainFrame.Position = newPosition
        end
        
        local function stopDrag()
            self.isDragging = false
            if self.dragConnection then
                self.dragConnection:Disconnect()
                self.dragConnection = nil
            end
        end
        
        self.dragConnection = UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                updateDrag(input)
            end
        end)
        
        if self.isMobile then
            UserInputService.TouchEnded:Connect(stopDrag)
        else
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    stopDrag()
                end
            end)
        end
    end
    
    if self.isMobile then
        titleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                startDrag(input)
            end
        end)
    else
        titleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                startDrag(input)
            end
        end)
    end
end

function TeleportSystem:createButton(parent, text, position)
    local button = Instance.new("TextButton")
    button.Parent = parent
    button.BackgroundColor3 = Color3.fromRGB(40, 120, 255)
    button.BorderSizePixel = 0
    button.Position = position
    button.Size = UDim2.new(0.9, 0, 0, self.isMobile and 45 or 40)
    button.Font = Enum.Font.GothamSemibold
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = self.isMobile and 13 or 14
    button.AutoButtonColor = false
    
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 10)
    buttonCorner.Parent = button
    
    local buttonStroke = Instance.new("UIStroke")
    buttonStroke.Parent = button
    buttonStroke.Color = Color3.fromRGB(20, 80, 200)
    buttonStroke.Thickness = 1
    buttonStroke.Transparency = 0.5
    
    local buttonGradient = Instance.new("UIGradient")
    buttonGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 130, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 100, 235))
    })
    buttonGradient.Rotation = 90
    buttonGradient.Parent = button
    
    self:addButtonAnimation(button, buttonStroke, buttonGradient)
    
    return button
end

function TeleportSystem:addButtonAnimation(button, stroke, gradient)
    local originalColors = {
        ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 130, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 100, 235))
    }
    
    local hoverColors = {
        ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 150, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 120, 255))
    }
    
    button.MouseEnter:Connect(function()
        TweenService:Create(stroke, TweenInfo.new(0.2), {
            Transparency = 0.2
        }):Play()
        gradient.Color = ColorSequence.new(hoverColors)
    end)
    
    button.MouseLeave:Connect(function()
        TweenService:Create(stroke, TweenInfo.new(0.2), {
            Transparency = 0.5
        }):Play()
        gradient.Color = ColorSequence.new(originalColors)
    end)
    
    button.MouseButton1Down:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.1), {
            Size = UDim2.new(0.9, 0, 0, (self.isMobile and 45 or 40) - 2)
        }):Play()
    end)
    
    button.MouseButton1Up:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.1), {
            Size = UDim2.new(0.9, 0, 0, self.isMobile and 45 or 40)
        }):Play()
    end)
end

function TeleportSystem:setupButtonEvents(deliveryButton, baseButton, smoothButton, closeButton, statusLabel)
    deliveryButton.MouseButton1Click:Connect(function()
        spawn(function()
            self:teleportToDelivery(statusLabel)
        end)
    end)
    
    baseButton.MouseButton1Click:Connect(function()
        spawn(function()
            self:teleportToNearestBase(statusLabel)
        end)
    end)
    
    smoothButton.MouseButton1Click:Connect(function()
        spawn(function()
            self:smoothTeleport(statusLabel)
        end)
    end)
    
    closeButton.MouseButton1Click:Connect(function()
        TweenService:Create(closeButton, TweenInfo.new(0.1), {
            BackgroundColor3 = Color3.fromRGB(200, 80, 80)
        }):Play()
        wait(0.1)
        self:destroy()
    end)
end

function TeleportSystem:animateGuiOpen(frame)
    TweenService:Create(self.blurEffect, TweenInfo.new(0.4), {Size = 8}):Play()
    
    local targetSize = self.isMobile and UDim2.new(0, 320, 0, 280) or UDim2.new(0, 380, 0, 260)
    
    TweenService:Create(frame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = targetSize
    }):Play()
    
    spawn(function()
        wait(0.2)
        for i, child in pairs(frame:GetDescendants()) do
            if child:IsA("TextLabel") or child:IsA("TextButton") then
                spawn(function()
                    wait(i * 0.02)
                    child.TextTransparency = 1
                    TweenService:Create(child, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
                end)
            end
        end
    end)
end

function TeleportSystem:setupInputHandling()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.P then
            if self.gui and self.gui.Parent then
                local mainFrame = self.gui.MainFrame
                local isVisible = mainFrame.Visible
                
                if isVisible then
                    TweenService:Create(mainFrame, TweenInfo.new(0.3), {
                        Size = UDim2.new(0, 0, 0, 0)
                    }):Play()
                    TweenService:Create(self.blurEffect, TweenInfo.new(0.3), {Size = 0}):Play()
                    
                    spawn(function()
                        wait(0.3)
                        mainFrame.Visible = false
                    end)
                else
                    mainFrame.Visible = true
                    self:animateGuiOpen(mainFrame)
                end
            end
        end
    end)
end

function TeleportSystem:destroy()
    self.isActive = false
    
    if self.dragConnection then
        self.dragConnection:Disconnect()
        self.dragConnection = nil
    end
    
    if self.blurEffect then
        TweenService:Create(self.blurEffect, TweenInfo.new(0.3), {Size = 0}):Play()
        Debris:AddItem(self.blurEffect, 0.5)
    end
    
    if self.gui then
        local mainFrame = self.gui.MainFrame
        
        TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0),
            Rotation = 45
        }):Play()
        
        for _, child in pairs(mainFrame:GetDescendants()) do
            if child:IsA("TextLabel") or child:IsA("TextButton") then
                TweenService:Create(child, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
            end
        end
        
        Debris:AddItem(self.gui, 0.5)
    end
end

local teleportSystem = TeleportSystem.new()
