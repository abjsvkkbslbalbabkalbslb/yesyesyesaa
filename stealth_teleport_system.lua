local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local StealthTeleportSystem = {}
StealthTeleportSystem.__index = StealthTeleportSystem

function StealthTeleportSystem.new()
    local self = setmetatable({}, StealthTeleportSystem)
    
    self.character = nil
    self.humanoidRootPart = nil
    self.humanoid = nil
    self.isActive = false
    self.gui = nil
    self.connections = {}
    self.isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    self.isNoClipping = false
    self.originalCollisionValues = {}
    self.bypassMethods = {
        "cframe_micro",
        "velocity_burst",
        "network_owner",
        "heartbeat_step",
        "physics_bypass"
    }
    
    self:initialize()
    return self
end

function StealthTeleportSystem:initialize()
    self:setupCharacter()
    self:createGui()
    self:setupInputs()
end

function StealthTeleportSystem:setupCharacter()
    local function onCharacterAdded(character)
        self.character = character
        self.humanoidRootPart = character:WaitForChild("HumanoidRootPart")
        self.humanoid = character:WaitForChild("Humanoid")
        
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

function StealthTeleportSystem:storeOriginalCollisionValues()
    if not self.character then return end
    
    for _, part in pairs(self.character:GetChildren()) do
        if part:IsA("BasePart") then
            self.originalCollisionValues[part] = part.CanCollide
        end
    end
end

function StealthTeleportSystem:enableStealthNoClip()
    if not self.character or self.isNoClipping then return end
    
    self.isNoClipping = true
    
    -- Method 1: Disable collision gradually
    spawn(function()
        for _, part in pairs(self.character:GetChildren()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = false
            end
            wait(0.01) -- Small delay to avoid detection
        end
    end)
    
    -- Method 2: Continuous collision bypass
    local noClipConnection
    noClipConnection = RunService.Heartbeat:Connect(function()
        if not self.isNoClipping then
            noClipConnection:Disconnect()
            return
        end
        
        pcall(function()
            for _, part in pairs(self.character:GetChildren()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = false
                end
            end
        end)
    end)
    
    table.insert(self.connections, noClipConnection)
end

function StealthTeleportSystem:disableStealthNoClip()
    if not self.character or not self.isNoClipping then return end
    
    self.isNoClipping = false
    
    -- Restore collision gradually
    spawn(function()
        for part, originalValue in pairs(self.originalCollisionValues) do
            if part and part.Parent then
                part.CanCollide = originalValue
                wait(0.01)
            end
        end
    end)
end

function StealthTeleportSystem:cleanup()
    self:disableStealthNoClip()
    
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

function StealthTeleportSystem:validateCharacter()
    return self.character and self.humanoidRootPart and self.humanoidRootPart.Parent and self.humanoid and self.humanoid.Health > 0
end

-- Method 1: Micro CFrame Teleportation
function StealthTeleportSystem:microCFrameTeleport(targetPosition, callback)
    if not self:validateCharacter() then
        if callback then callback(false, "Character invalid") end
        return
    end
    
    local startPosition = self.humanoidRootPart.Position
    local distance = (targetPosition - startPosition).Magnitude
    local steps = math.ceil(distance / 8) -- 8 studs per step
    
    self:enableStealthNoClip()
    
    local currentStep = 0
    local stepConnection
    
    stepConnection = RunService.Heartbeat:Connect(function()
        if not self:validateCharacter() then
            stepConnection:Disconnect()
            self:disableStealthNoClip()
            if callback then callback(false, "Character lost") end
            return
        end
        
        currentStep = currentStep + 1
        local progress = currentStep / steps
        
        if progress >= 1 then
            self.humanoidRootPart.CFrame = CFrame.new(targetPosition + Vector3.new(0, 3, 0))
            stepConnection:Disconnect()
            self:disableStealthNoClip()
            if callback then callback(true, "Micro teleport successful") end
            return
        end
        
        local newPosition = startPosition:lerp(targetPosition, progress)
        self.humanoidRootPart.CFrame = CFrame.new(newPosition)
        
        wait(0.03) -- Small delay between steps
    end)
    
    table.insert(self.connections, stepConnection)
end

-- Method 2: Velocity Burst Teleportation
function StealthTeleportSystem:velocityBurstTeleport(targetPosition, callback)
    if not self:validateCharacter() then
        if callback then callback(false, "Character invalid") end
        return
    end
    
    self:enableStealthNoClip()
    
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    bodyVelocity.Parent = self.humanoidRootPart
    
    local direction = (targetPosition - self.humanoidRootPart.Position).Unit
    local burstPower = 200
    
    -- Multiple small bursts
    local burstCount = 0
    local maxBursts = 10
    
    local burstConnection
    burstConnection = RunService.Heartbeat:Connect(function()
        if not self:validateCharacter() then
            burstConnection:Disconnect()
            if bodyVelocity then bodyVelocity:Destroy() end
            self:disableStealthNoClip()
            if callback then callback(false, "Character lost") end
            return
        end
        
        burstCount = burstCount + 1
        
        if burstCount >= maxBursts then
            bodyVelocity.Velocity = Vector3.new(0, 0, 0)
            burstConnection:Disconnect()
            
            spawn(function()
                wait(0.5)
                if bodyVelocity then bodyVelocity:Destroy() end
                self:disableStealthNoClip()
                if callback then callback(true, "Velocity burst successful") end
            end)
            return
        end
        
        local currentDistance = (self.humanoidRootPart.Position - targetPosition).Magnitude
        if currentDistance < 20 then
            bodyVelocity.Velocity = Vector3.new(0, 0, 0)
            burstConnection:Disconnect()
            
            spawn(function()
                wait(0.5)
                if bodyVelocity then bodyVelocity:Destroy() end
                self:disableStealthNoClip()
                if callback then callback(true, "Velocity burst successful") end
            end)
            return
        end
        
        -- Apply burst
        bodyVelocity.Velocity = direction * burstPower
        wait(0.1)
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        wait(0.05)
    end)
    
    table.insert(self.connections, burstConnection)
end

-- Method 3: Network Owner Manipulation
function StealthTeleportSystem:networkOwnerTeleport(targetPosition, callback)
    if not self:validateCharacter() then
        if callback then callback(false, "Character invalid") end
        return
    end
    
    self:enableStealthNoClip()
    
    -- Try to set network owner to nil (server)
    pcall(function()
        self.humanoidRootPart:SetNetworkOwner(nil)
    end)
    
    -- Wait a bit then teleport
    spawn(function()
        wait(0.2)
        
        if self:validateCharacter() then
            self.humanoidRootPart.CFrame = CFrame.new(targetPosition + Vector3.new(0, 3, 0))
            
            wait(0.5)
            
            -- Try to set network owner back to player
            pcall(function()
                self.humanoidRootPart:SetNetworkOwner(Player)
            end)
            
            self:disableStealthNoClip()
            if callback then callback(true, "Network owner teleport successful") end
        else
            self:disableStealthNoClip()
            if callback then callback(false, "Character lost") end
        end
    end)
end

-- Method 4: Heartbeat Step Teleportation
function StealthTeleportSystem:heartbeatStepTeleport(targetPosition, callback)
    if not self:validateCharacter() then
        if callback then callback(false, "Character invalid") end
        return
    end
    
    self:enableStealthNoClip()
    
    local startPosition = self.humanoidRootPart.Position
    local totalDistance = (targetPosition - startPosition).Magnitude
    local stepSize = 15
    local steps = math.ceil(totalDistance / stepSize)
    local currentStep = 0
    
    local stepConnection
    stepConnection = RunService.Stepped:Connect(function()
        if not self:validateCharacter() then
            stepConnection:Disconnect()
            self:disableStealthNoClip()
            if callback then callback(false, "Character lost") end
            return
        end
        
        currentStep = currentStep + 1
        local progress = currentStep / steps
        
        if progress >= 1 then
            self.humanoidRootPart.CFrame = CFrame.new(targetPosition + Vector3.new(0, 3, 0))
            stepConnection:Disconnect()
            self:disableStealthNoClip()
            if callback then callback(true, "Heartbeat step successful") end
            return
        end
        
        local newPosition = startPosition:lerp(targetPosition, progress)
        self.humanoidRootPart.CFrame = CFrame.new(newPosition)
    end)
    
    table.insert(self.connections, stepConnection)
end

-- Method 5: Physics Bypass Teleportation
function StealthTeleportSystem:physicsBypassTeleport(targetPosition, callback)
    if not self:validateCharacter() then
        if callback then callback(false, "Character invalid") end
        return
    end
    
    self:enableStealthNoClip()
    
    -- Disable physics temporarily
    local originalCanCollide = self.humanoidRootPart.CanCollide
    local originalAnchored = self.humanoidRootPart.Anchored
    
    self.humanoidRootPart.CanCollide = false
    self.humanoidRootPart.Anchored = true
    
    -- Teleport
    self.humanoidRootPart.CFrame = CFrame.new(targetPosition + Vector3.new(0, 3, 0))
    
    -- Restore physics after delay
    spawn(function()
        wait(0.5)
        if self:validateCharacter() then
            self.humanoidRootPart.CanCollide = originalCanCollide
            self.humanoidRootPart.Anchored = originalAnchored
            self:disableStealthNoClip()
            if callback then callback(true, "Physics bypass successful") end
        else
            self:disableStealthNoClip()
            if callback then callback(false, "Character lost") end
        end
    end)
end

-- Smart teleport that tries multiple methods
function StealthTeleportSystem:smartTeleport(targetPosition, statusLabel, methodIndex)
    methodIndex = methodIndex or 1
    
    if methodIndex > #self.bypassMethods then
        self:updateStatus(statusLabel, "❌ All methods failed", Color3.fromRGB(255, 80, 80))
        return
    end
    
    local method = self.bypassMethods[methodIndex]
    self:updateStatus(statusLabel, "🔄 Trying method " .. methodIndex .. "...", Color3.fromRGB(255, 255, 0))
    
    local teleportFunction = nil
    
    if method == "cframe_micro" then
        teleportFunction = self.microCFrameTeleport
    elseif method == "velocity_burst" then
        teleportFunction = self.velocityBurstTeleport
    elseif method == "network_owner" then
        teleportFunction = self.networkOwnerTeleport
    elseif method == "heartbeat_step" then
        teleportFunction = self.heartbeatStepTeleport
    elseif method == "physics_bypass" then
        teleportFunction = self.physicsBypassTeleport
    end
    
    if teleportFunction then
        teleportFunction(self, targetPosition, function(success, message)
            if success then
                self:updateStatus(statusLabel, "✅ Success with method " .. methodIndex, Color3.fromRGB(0, 255, 0))
            else
                spawn(function()
                    wait(1)
                    self:smartTeleport(targetPosition, statusLabel, methodIndex + 1)
                end)
            end
        end)
    else
        self:smartTeleport(targetPosition, statusLabel, methodIndex + 1)
    end
end

function StealthTeleportSystem:findDeliveryBox()
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

function StealthTeleportSystem:findNearestBase()
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

function StealthTeleportSystem:teleportToDelivery(statusLabel)
    self:updateStatus(statusLabel, "🔍 Locating delivery box...", Color3.fromRGB(255, 255, 0))
    
    local deliveryBox = self:findDeliveryBox()
    if not deliveryBox then
        self:updateStatus(statusLabel, "❌ Delivery box not found", Color3.fromRGB(255, 80, 80))
        return
    end
    
    self:updateStatus(statusLabel, "🚀 Initiating stealth teleport...", Color3.fromRGB(0, 255, 255))
    self:smartTeleport(deliveryBox.Position, statusLabel)
end

function StealthTeleportSystem:teleportToNearestBase(statusLabel)
    self:updateStatus(statusLabel, "🔍 Scanning for nearest base...", Color3.fromRGB(255, 255, 0))
    
    local nearestBase = self:findNearestBase()
    if not nearestBase then
        self:updateStatus(statusLabel, "❌ No accessible base found", Color3.fromRGB(255, 80, 80))
        return
    end
    
    self:updateStatus(statusLabel, "🚀 Initiating stealth teleport...", Color3.fromRGB(0, 255, 255))
    self:smartTeleport(nearestBase.Position, statusLabel)
end

function StealthTeleportSystem:updateStatus(statusLabel, message, color)
    statusLabel.Text = message
    statusLabel.TextColor3 = color
    statusLabel.TextTransparency = 0
    
    spawn(function()
        wait(5)
        TweenService:Create(statusLabel, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
    end)
end

function StealthTeleportSystem:setupInputs()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.P then
            if self.gui then
                self.gui.Enabled = not self.gui.Enabled
            end
        elseif input.KeyCode == Enum.KeyCode.N then
            if self.isNoClipping then
                self:disableStealthNoClip()
            else
                self:enableStealthNoClip()
            end
        end
    end)
end

function StealthTeleportSystem:createGui()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "StealthTeleportGui"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = PlayerGui
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Parent = screenGui
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    mainFrame.BorderSizePixel = 0
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.Size = self.isMobile and UDim2.new(0, 320, 0, 280) or UDim2.new(0, 380, 0, 260)
    
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, 12)
    uiCorner.Parent = mainFrame
    
    local uiStroke = Instance.new("UIStroke")
    uiStroke.Parent = mainFrame
    uiStroke.Color = Color3.fromRGB(100, 255, 100)
    uiStroke.Thickness = 2
    
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Parent = mainFrame
    titleBar.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
    titleBar.BorderSizePixel = 0
    titleBar.Size = UDim2.new(1, 0, 0, 35)
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Parent = titleBar
    titleLabel.BackgroundTransparency = 1
    titleLabel.Size = UDim2.new(1, -60, 1, 0)
    titleLabel.Position = UDim2.new(0, 15, 0, 0)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Text = "🥷 STEALTH TELEPORT SYSTEM"
    titleLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
    titleLabel.TextSize = self.isMobile and 12 or 14
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local closeButton = Instance.new("TextButton")
    closeButton.Parent = titleBar
    closeButton.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    closeButton.BorderSizePixel = 0
    closeButton.Size = UDim2.new(0, 25, 0, 25)
    closeButton.Position = UDim2.new(1, -30, 0, 5)
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Text = "×"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextSize = 16
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 12)
    closeCorner.Parent = closeButton
    
    local content = Instance.new("Frame")
    content.Parent = mainFrame
    content.BackgroundTransparency = 1
    content.Position = UDim2.new(0, 0, 0, 35)
    content.Size = UDim2.new(1, 0, 1, -35)
    
    local deliveryButton = self:createButton(content, "📦 Stealth to Delivery", UDim2.new(0.05, 0, 0.1, 0), Color3.fromRGB(0, 180, 120))
    local baseButton = self:createButton(content, "🏠 Stealth to Base", UDim2.new(0.05, 0, 0.32, 0), Color3.fromRGB(0, 120, 255))
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Parent = content
    statusLabel.BackgroundTransparency = 1
    statusLabel.Size = UDim2.new(0.9, 0, 0, 40)
    statusLabel.Position = UDim2.new(0.05, 0, 0.6, 0)
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
    infoLabel.Position = UDim2.new(0.05, 0, 0.8, 0)
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
    infoLabel.TextSize = self.isMobile and 9 or 11
    infoLabel.Text = "P = Toggle GUI • N = NoClip • Multi-method bypass"
    infoLabel.TextWrapped = true
    
    self.gui = screenGui
    self.isActive = true
    
    self:setupButtonEvents(deliveryButton, baseButton, closeButton, statusLabel)
    self:setupDragFunctionality(titleBar, mainFrame)
end

function StealthTeleportSystem:createButton(parent, text, position, color)
    local button = Instance.new("TextButton")
    button.Parent = parent
    button.BackgroundColor3 = color or Color3.fromRGB(0, 150, 255)
    button.BorderSizePixel = 0
    button.Position = position
    button.Size = UDim2.new(0.9, 0, 0, self.isMobile and 40 or 35)
    button.Font = Enum.Font.GothamSemibold
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = self.isMobile and 12 or 14
    button.AutoButtonColor = false
    
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 8)
    buttonCorner.Parent = button
    
    local originalColor = button.BackgroundColor3
    
    button.MouseEnter:Connect(function()
        local brighterColor = Color3.fromRGB(
            math.min(255, originalColor.R * 255 + 20),
            math.min(255, originalColor.G * 255 + 20),
            math.min(255, originalColor.B * 255 + 20)
        )
        TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = brighterColor}):Play()
    end)
    
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = originalColor}):Play()
    end)
    
    return button
end

function StealthTeleportSystem:setupButtonEvents(deliveryButton, baseButton, closeButton, statusLabel)
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
    
    closeButton.MouseButton1Click:Connect(function()
        self:destroy()
    end)
end

function StealthTeleportSystem:setupDragFunctionality(titleBar, mainFrame)
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

function StealthTeleportSystem:destroy()
    self.isActive = false
    self:cleanup()
    
    if self.gui then
        self.gui:Destroy()
    end
end

local stealthSystem = StealthTeleportSystem.new()
