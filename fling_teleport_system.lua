local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local FlingTeleportSystem = {}
FlingTeleportSystem.__index = FlingTeleportSystem

function FlingTeleportSystem.new()
    local self = setmetatable({}, FlingTeleportSystem)
    
    self.character = nil
    self.humanoidRootPart = nil
    self.humanoid = nil
    self.isActive = false
    self.bodyVelocity = nil
    self.bodyPosition = nil
    self.bodyAngularVelocity = nil
    self.antiGravity = nil
    self.gui = nil
    self.connections = {}
    self.flingPower = 1500 -- Increased from 500
    self.maxDistance = 3000 -- Increased from 2000
    self.teleportAttempts = 0
    self.maxAttempts = 5 -- Increased from 3
    self.isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    self.isNoClipping = false
    self.originalCollisionValues = {}
    
    self:initialize()
    return self
end

function FlingTeleportSystem:initialize()
    self:setupCharacter()
    self:createGui()
    self:setupInputs()
end

function FlingTeleportSystem:setupCharacter()
    local function onCharacterAdded(character)
        self.character = character
        self.humanoidRootPart = character:WaitForChild("HumanoidRootPart")
        self.humanoid = character:WaitForChild("Humanoid")
        
        -- Store original collision values
        self:storeOriginalCollisionValues()
        
        self.humanoid.StateChanged:Connect(function(oldState, newState)
            if newState == Enum.HumanoidStateType.Dead then
                self:cleanup()
            end
        end)
    end
    
    if Player.Character then
        onCharacterAdded(Player.Character)
    end
    
    Player.CharacterAdded:Connect(onCharacterAdded)
end

function FlingTeleportSystem:storeOriginalCollisionValues()
    if not self.character then return end
    
    for _, part in pairs(self.character:GetChildren()) do
        if part:IsA("BasePart") then
            self.originalCollisionValues[part] = part.CanCollide
        end
    end
end

function FlingTeleportSystem:enableNoClip()
    if not self.character or self.isNoClipping then return end
    
    self.isNoClipping = true
    
    for _, part in pairs(self.character:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.CanCollide = false
        end
    end
    
    -- Create a connection to maintain noclip
    local noClipConnection
    noClipConnection = RunService.Stepped:Connect(function()
        if not self.isNoClipping then
            noClipConnection:Disconnect()
            return
        end
        
        for _, part in pairs(self.character:GetChildren()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = false
            end
        end
    end)
    
    table.insert(self.connections, noClipConnection)
end

function FlingTeleportSystem:disableNoClip()
    if not self.character or not self.isNoClipping then return end
    
    self.isNoClipping = false
    
    -- Restore original collision values
    for part, originalValue in pairs(self.originalCollisionValues) do
        if part and part.Parent then
            part.CanCollide = originalValue
        end
    end
end

function FlingTeleportSystem:cleanup()
    self:disableNoClip()
    
    if self.bodyVelocity then
        self.bodyVelocity:Destroy()
        self.bodyVelocity = nil
    end
    if self.bodyPosition then
        self.bodyPosition:Destroy()
        self.bodyPosition = nil
    end
    if self.bodyAngularVelocity then
        self.bodyAngularVelocity:Destroy()
        self.bodyAngularVelocity = nil
    end
    if self.antiGravity then
        self.antiGravity:Destroy()
        self.antiGravity = nil
    end
    
    for _, connection in pairs(self.connections) do
        if connection then
            connection:Disconnect()
        end
    end
    self.connections = {}
    
    if self.humanoid then
        self.humanoid.PlatformStand = false
        self.humanoid.Sit = false
    end
end

function FlingTeleportSystem:createPhysicsObjects()
    self:cleanup()
    
    if not self.humanoidRootPart then return false end
    
    -- Enhanced BodyVelocity with higher force
    self.bodyVelocity = Instance.new("BodyVelocity")
    self.bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    self.bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    self.bodyVelocity.Parent = self.humanoidRootPart
    
    -- Enhanced BodyPosition with better settings
    self.bodyPosition = Instance.new("BodyPosition")
    self.bodyPosition.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    self.bodyPosition.Position = self.humanoidRootPart.Position
    self.bodyPosition.D = 5000 -- Increased damping
    self.bodyPosition.P = 50000 -- Increased power
    self.bodyPosition.Parent = self.humanoidRootPart
    
    -- Enhanced BodyAngularVelocity
    self.bodyAngularVelocity = Instance.new("BodyAngularVelocity")
    self.bodyAngularVelocity.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    self.bodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
    self.bodyAngularVelocity.Parent = self.humanoidRootPart
    
    -- Enhanced Anti-gravity
    self.antiGravity = Instance.new("BodyPosition")
    self.antiGravity.MaxForce = Vector3.new(0, math.huge, 0)
    self.antiGravity.Position = self.humanoidRootPart.Position
    self.antiGravity.D = 2000
    self.antiGravity.P = 10000
    self.antiGravity.Parent = self.humanoidRootPart
    
    return true
end

function FlingTeleportSystem:validateCharacter()
    return self.character and self.humanoidRootPart and self.humanoidRootPart.Parent and self.humanoid and self.humanoid.Health > 0
end

function FlingTeleportSystem:performAdvancedFling(targetPosition, callback)
    if not self:validateCharacter() then
        if callback then callback(false, "Character invalid") end
        return
    end
    
    if not self:createPhysicsObjects() then
        if callback then callback(false, "Failed to create physics objects") end
        return
    end
    
    -- Enable noclip for wall bypassing
    self:enableNoClip()
    
    local startPosition = self.humanoidRootPart.Position
    local distance = (targetPosition - startPosition).Magnitude
    
    if distance > self.maxDistance then
        if callback then callback(false, "Distance too far") end
        return
    end
    
    local direction = (targetPosition - startPosition).Unit
    local adjustedTarget = targetPosition + Vector3.new(0, 15, 0) -- Higher offset
    
    -- Disable character physics
    self.humanoid.PlatformStand = true
    self.humanoid.Sit = false
    
    -- Calculate enhanced fling velocity
    local baseFlingVelocity = direction * self.flingPower
    local heightBoost = math.max(100, distance * 0.1) -- Dynamic height boost
    local flingVelocity = Vector3.new(baseFlingVelocity.X, heightBoost, baseFlingVelocity.Z)
    
    -- Apply initial fling
    self.bodyVelocity.Velocity = flingVelocity
    self.bodyPosition.Position = adjustedTarget
    self.antiGravity.Position = adjustedTarget
    
    local startTime = tick()
    local timeoutDuration = 8 -- Reduced timeout for faster response
    local minDistance = 30 -- Reduced minimum distance
    local phase = 1 -- 1 = fling, 2 = guide, 3 = land
    
    local heartbeatConnection
    heartbeatConnection = RunService.Heartbeat:Connect(function()
        if not self:validateCharacter() then
            if heartbeatConnection then heartbeatConnection:Disconnect() end
            self:disableNoClip()
            if callback then callback(false, "Character lost during fling") end
            return
        end
        
        local currentTime = tick()
        local currentDistance = (self.humanoidRootPart.Position - targetPosition).Magnitude
        local timeProgress = (currentTime - startTime) / timeoutDuration
        
        -- Phase 1: Initial fling (first 20% of time)
        if phase == 1 and timeProgress > 0.2 then
            phase = 2
            -- Reduce velocity and start guiding
            self.bodyVelocity.Velocity = self.bodyVelocity.Velocity * 0.5
        end
        
        -- Phase 2: Guided approach (20-70% of time)
        if phase == 2 and timeProgress > 0.7 then
            phase = 3
            -- Start landing procedure
            self.bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        end
        
        -- Phase 3: Landing (final 30% of time)
        if phase == 3 then
            local lerpedPosition = self.humanoidRootPart.Position:lerp(adjustedTarget, 0.3)
            self.bodyPosition.Position = lerpedPosition
            self.antiGravity.Position = lerpedPosition
        end
        
        -- Success condition
        if currentDistance <= minDistance then
            self:advancedStabilize(targetPosition)
            if heartbeatConnection then heartbeatConnection:Disconnect() end
            if callback then callback(true, "Successfully reached target") end
            return
        end
        
        -- Timeout condition
        if currentTime - startTime > timeoutDuration then
            self:advancedStabilize(targetPosition)
            if heartbeatConnection then heartbeatConnection:Disconnect() end
            if callback then callback(false, "Timeout reached") end
            return
        end
        
        -- Continuous guidance for phases 2 and 3
        if phase >= 2 then
            local guidanceForce = (adjustedTarget - self.humanoidRootPart.Position).Unit * (self.flingPower * 0.3)
            self.bodyVelocity.Velocity = self.bodyVelocity.Velocity:lerp(guidanceForce, 0.1)
        end
    end)
    
    table.insert(self.connections, heartbeatConnection)
end

function FlingTeleportSystem:advancedStabilize(targetPosition)
    if not self:validateCharacter() then return end
    
    local finalPosition = targetPosition + Vector3.new(0, 3, 0)
    
    -- Immediate velocity stop
    if self.bodyVelocity then
        self.bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    end
    
    -- Strong position lock
    if self.bodyPosition then
        self.bodyPosition.Position = finalPosition
        self.bodyPosition.D = 10000
        self.bodyPosition.P = 100000
    end
    
    if self.antiGravity then
        self.antiGravity.Position = finalPosition
    end
    
    -- Stop rotation
    if self.bodyAngularVelocity then
        self.bodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
    end
    
    -- Cleanup after stabilization
    spawn(function()
        wait(1.5) -- Reduced wait time
        self:disableNoClip()
        self.humanoid.PlatformStand = false
        wait(0.5)
        self:cleanup()
    end)
end

function FlingTeleportSystem:findDeliveryBox()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    
    for _, plot in pairs(plots:GetChildren()) do
        if plot:IsA("Model") then
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
    end
    
    return nil
end

function FlingTeleportSystem:findNearestBase()
    local plotsFolder = workspace:FindFirstChild("Plots")
    if not plotsFolder or not self:validateCharacter() then return nil end
    
    local closestBase = nil
    local shortestDistance = math.huge
    
    for _, plot in pairs(plotsFolder:GetChildren()) do
        if plot:IsA("Model") then
            local plotSign = plot:FindFirstChild("PlotSign")
            if plotSign then
                local yourBase = plotSign:FindFirstChild("YourBase")
                if yourBase and not yourBase.Enabled then
                    local animalPodiums = plot:FindFirstChild("AnimalPodiums")
                    if animalPodiums then
                        for _, podium in pairs(animalPodiums:GetChildren()) do
                            if podium:IsA("Model") then
                                local base = podium:FindFirstChild("Base")
                                if base then
                                    local spawn = base:FindFirstChild("Spawn")
                                    if spawn then
                                        local distance = (spawn.Position - self.humanoidRootPart.Position).Magnitude
                                        if distance < shortestDistance then
                                            shortestDistance = distance
                                            closestBase = spawn
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
    
    return closestBase
end

function FlingTeleportSystem:teleportToDelivery(statusLabel)
    self:updateStatus(statusLabel, "🔍 Locating delivery box...", Color3.fromRGB(255, 255, 0))
    
    local deliveryBox = self:findDeliveryBox()
    if not deliveryBox then
        self:updateStatus(statusLabel, "❌ Delivery box not found", Color3.fromRGB(255, 80, 80))
        return
    end
    
    self:updateStatus(statusLabel, "🚀 Launching to delivery (NoClip ON)...", Color3.fromRGB(0, 255, 255))
    
    self:performAdvancedFling(deliveryBox.Position, function(success, message)
        if success then
            self:updateStatus(statusLabel, "✅ Delivery teleport successful!", Color3.fromRGB(0, 255, 0))
        else
            self:updateStatus(statusLabel, "❌ Delivery failed: " .. message, Color3.fromRGB(255, 80, 80))
        end
    end)
end

function FlingTeleportSystem:teleportToNearestBase(statusLabel)
    self:updateStatus(statusLabel, "🔍 Scanning for nearest base...", Color3.fromRGB(255, 255, 0))
    
    local nearestBase = self:findNearestBase()
    if not nearestBase then
        self:updateStatus(statusLabel, "❌ No accessible base found", Color3.fromRGB(255, 80, 80))
        return
    end
    
    self:updateStatus(statusLabel, "🚀 Launching to base (NoClip ON)...", Color3.fromRGB(0, 255, 255))
    
    self:performAdvancedFling(nearestBase.Position, function(success, message)
        if success then
            self:updateStatus(statusLabel, "✅ Base teleport successful!", Color3.fromRGB(0, 255, 0))
        else
            self:updateStatus(statusLabel, "❌ Base failed: " .. message, Color3.fromRGB(255, 80, 80))
        end
    end)
end

function FlingTeleportSystem:instantTeleport(targetPosition, statusLabel)
    self:updateStatus(statusLabel, "⚡ Instant teleport initiated...", Color3.fromRGB(255, 255, 0))
    
    if not self:validateCharacter() then
        self:updateStatus(statusLabel, "❌ Character invalid", Color3.fromRGB(255, 80, 80))
        return
    end
    
    -- Enable noclip temporarily
    self:enableNoClip()
    
    -- Direct teleport
    self.humanoidRootPart.CFrame = CFrame.new(targetPosition + Vector3.new(0, 5, 0))
    
    -- Disable noclip after a short delay
    spawn(function()
        wait(1)
        self:disableNoClip()
        self:updateStatus(statusLabel, "✅ Instant teleport successful!", Color3.fromRGB(0, 255, 0))
    end)
end

function FlingTeleportSystem:updateStatus(statusLabel, message, color)
    statusLabel.Text = message
    statusLabel.TextColor3 = color
    statusLabel.TextTransparency = 0
    
    spawn(function()
        wait(4) -- Increased display time
        TweenService:Create(statusLabel, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
    end)
end

function FlingTeleportSystem:setupInputs()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.P then
            if self.gui then
                self.gui.Enabled = not self.gui.Enabled
            end
        elseif input.KeyCode == Enum.KeyCode.N then
            -- Manual noclip toggle
            if self.isNoClipping then
                self:disableNoClip()
            else
                self:enableNoClip()
            end
        end
    end)
end

function FlingTeleportSystem:createGui()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "FlingTeleportGui"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = PlayerGui
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Parent = screenGui
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    mainFrame.BorderSizePixel = 0
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.Size = self.isMobile and UDim2.new(0, 320, 0, 300) or UDim2.new(0, 380, 0, 280)
    
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, 15)
    uiCorner.Parent = mainFrame
    
    local uiStroke = Instance.new("UIStroke")
    uiStroke.Parent = mainFrame
    uiStroke.Color = Color3.fromRGB(0, 200, 255)
    uiStroke.Thickness = 3
    
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Parent = mainFrame
    titleBar.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    titleBar.BorderSizePixel = 0
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 15)
    titleCorner.Parent = titleBar
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Parent = titleBar
    titleLabel.BackgroundTransparency = 1
    titleLabel.Size = UDim2.new(1, -70, 1, 0)
    titleLabel.Position = UDim2.new(0, 15, 0, 0)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Text = "⚡ ADVANCED FLING SYSTEM"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = self.isMobile and 13 or 15
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local closeButton = Instance.new("TextButton")
    closeButton.Parent = titleBar
    closeButton.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    closeButton.BorderSizePixel = 0
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -35, 0, 5)
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Text = "×"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextSize = 18
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 15)
    closeCorner.Parent = closeButton
    
    local content = Instance.new("Frame")
    content.Parent = mainFrame
    content.BackgroundTransparency = 1
    content.Position = UDim2.new(0, 0, 0, 40)
    content.Size = UDim2.new(1, 0, 1, -40)
    
    local deliveryButton = self:createButton(content, "📦 Fling to Delivery", UDim2.new(0.05, 0, 0.08, 0), Color3.fromRGB(0, 200, 100))
    local baseButton = self:createButton(content, "🏠 Fling to Base", UDim2.new(0.05, 0, 0.28, 0), Color3.fromRGB(0, 150, 255))
    local instantDeliveryButton = self:createButton(content, "⚡ Instant Delivery", UDim2.new(0.05, 0, 0.48, 0), Color3.fromRGB(255, 150, 0))
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Parent = content
    statusLabel.BackgroundTransparency = 1
    statusLabel.Size = UDim2.new(0.9, 0, 0, 35)
    statusLabel.Position = UDim2.new(0.05, 0, 0.7, 0)
    statusLabel.Font = Enum.Font.GothamSemibold
    statusLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    statusLabel.TextSize = self.isMobile and 11 or 13
    statusLabel.TextTransparency = 1
    statusLabel.Text = ""
    statusLabel.TextWrapped = true
    
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Parent = content
    infoLabel.BackgroundTransparency = 1
    infoLabel.Size = UDim2.new(0.9, 0, 0, 25)
    infoLabel.Position = UDim2.new(0.05, 0, 0.85, 0)
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
    infoLabel.TextSize = self.isMobile and 9 or 11
    infoLabel.Text = "P = Toggle GUI â€¢ N = NoClip â€¢ Enhanced bypassing"
    infoLabel.TextWrapped = true
    
    self.gui = screenGui
    self.isActive = true
    
    self:setupButtonEvents(deliveryButton, baseButton, instantDeliveryButton, closeButton, statusLabel)
    self:setupDragFunctionality(titleBar, mainFrame)
end

function FlingTeleportSystem:createButton(parent, text, position, color)
    local button = Instance.new("TextButton")
    button.Parent = parent
    button.BackgroundColor3 = color or Color3.fromRGB(0, 150, 255)
    button.BorderSizePixel = 0
    button.Position = position
    button.Size = UDim2.new(0.9, 0, 0, self.isMobile and 45 or 40)
    button.Font = Enum.Font.GothamSemibold
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = self.isMobile and 13 or 15
    button.AutoButtonColor = false
    
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 10)
    buttonCorner.Parent = button
    
    local originalColor = button.BackgroundColor3
    
    button.MouseEnter:Connect(function()
        local brighterColor = Color3.fromRGB(
            math.min(255, originalColor.R * 255 + 30),
            math.min(255, originalColor.G * 255 + 30),
            math.min(255, originalColor.B * 255 + 30)
        )
        TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = brighterColor}):Play()
    end)
    
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = originalColor}):Play()
    end)
    
    return button
end

function FlingTeleportSystem:setupButtonEvents(deliveryButton, baseButton, instantButton, closeButton, statusLabel)
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
    
    instantButton.MouseButton1Click:Connect(function()
        spawn(function()
            local deliveryBox = self:findDeliveryBox()
            if deliveryBox then
                self:instantTeleport(deliveryBox.Position, statusLabel)
            else
                self:updateStatus(statusLabel, "âŒ Delivery box not found", Color3.fromRGB(255, 80, 80))
            end
        end)
    end)
    
    closeButton.MouseButton1Click:Connect(function()
        self:destroy()
    end)
end

function FlingTeleportSystem:setupDragFunctionality(titleBar, mainFrame)
    local isDragging = false
    local dragStart = nil
    local startPos = nil
    
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            
            local connection
            connection = UserInputService.InputChanged:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                    if isDragging then
                        local delta = input.Position - dragStart
                        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
                    end
                end
            end)
            
            local function stopDrag()
                isDragging = false
                connection:Disconnect()
            end
            
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
    end)
end

function FlingTeleportSystem:destroy()
    self.isActive = false
    self:cleanup()
    
    if self.gui then
        self.gui:Destroy()
    end
end

local flingSystem = FlingTeleportSystem.new()
