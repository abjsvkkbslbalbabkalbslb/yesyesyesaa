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
    self.flingPower = 500
    self.maxDistance = 2000
    self.teleportAttempts = 0
    self.maxAttempts = 3
    self.isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    
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

function FlingTeleportSystem:cleanup()
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
    end
end

function FlingTeleportSystem:createPhysicsObjects()
    self:cleanup()
    
    if not self.humanoidRootPart then return false end
    
    self.bodyVelocity = Instance.new("BodyVelocity")
    self.bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    self.bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    self.bodyVelocity.Parent = self.humanoidRootPart
    
    self.bodyPosition = Instance.new("BodyPosition")
    self.bodyPosition.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    self.bodyPosition.Position = self.humanoidRootPart.Position
    self.bodyPosition.D = 2000
    self.bodyPosition.P = 10000
    self.bodyPosition.Parent = self.humanoidRootPart
    
    self.bodyAngularVelocity = Instance.new("BodyAngularVelocity")
    self.bodyAngularVelocity.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    self.bodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
    self.bodyAngularVelocity.Parent = self.humanoidRootPart
    
    self.antiGravity = Instance.new("BodyPosition")
    self.antiGravity.MaxForce = Vector3.new(0, math.huge, 0)
    self.antiGravity.Position = self.humanoidRootPart.Position
    self.antiGravity.D = 1000
    self.antiGravity.P = 5000
    self.antiGravity.Parent = self.humanoidRootPart
    
    return true
end

function FlingTeleportSystem:validateCharacter()
    return self.character and self.humanoidRootPart and self.humanoidRootPart.Parent and self.humanoid and self.humanoid.Health > 0
end

function FlingTeleportSystem:performFling(targetPosition, callback)
    if not self:validateCharacter() then
        if callback then callback(false, "Character invalid") end
        return
    end
    
    if not self:createPhysicsObjects() then
        if callback then callback(false, "Failed to create physics objects") end
        return
    end
    
    local startPosition = self.humanoidRootPart.Position
    local distance = (targetPosition - startPosition).Magnitude
    
    if distance > self.maxDistance then
        if callback then callback(false, "Distance too far") end
        return
    end
    
    local direction = (targetPosition - startPosition).Unit
    local adjustedTarget = targetPosition + Vector3.new(0, 10, 0)
    
    self.humanoid.PlatformStand = true
    
    local flingVelocity = direction * self.flingPower
    flingVelocity = Vector3.new(flingVelocity.X, math.max(flingVelocity.Y, 50), flingVelocity.Z)
    
    self.bodyVelocity.Velocity = flingVelocity
    self.bodyPosition.Position = adjustedTarget
    self.antiGravity.Position = Vector3.new(adjustedTarget.X, adjustedTarget.Y, adjustedTarget.Z)
    
    local startTime = tick()
    local timeoutDuration = 10
    local minDistance = 50
    
    local heartbeatConnection
    heartbeatConnection = RunService.Heartbeat:Connect(function()
        if not self:validateCharacter() then
            if heartbeatConnection then heartbeatConnection:Disconnect() end
            if callback then callback(false, "Character lost during fling") end
            return
        end
        
        local currentTime = tick()
        local currentDistance = (self.humanoidRootPart.Position - targetPosition).Magnitude
        
        if currentDistance <= minDistance then
            self:stabilizeAtPosition(targetPosition)
            if heartbeatConnection then heartbeatConnection:Disconnect() end
            if callback then callback(true, "Successfully reached target") end
            return
        end
        
        if currentTime - startTime > timeoutDuration then
            self:stabilizeAtPosition(targetPosition)
            if heartbeatConnection then heartbeatConnection:Disconnect() end
            if callback then callback(false, "Timeout reached") end
            return
        end
        
        local timeProgress = (currentTime - startTime) / timeoutDuration
        if timeProgress > 0.3 then
            local lerpedPosition = self.humanoidRootPart.Position:lerp(adjustedTarget, 0.1)
            self.bodyPosition.Position = lerpedPosition
            self.antiGravity.Position = Vector3.new(lerpedPosition.X, lerpedPosition.Y, lerpedPosition.Z)
        end
    end)
    
    table.insert(self.connections, heartbeatConnection)
end

function FlingTeleportSystem:stabilizeAtPosition(targetPosition)
    if not self:validateCharacter() then return end
    
    local finalPosition = targetPosition + Vector3.new(0, 5, 0)
    
    if self.bodyVelocity then
        self.bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    end
    
    if self.bodyPosition then
        self.bodyPosition.Position = finalPosition
        self.bodyPosition.D = 5000
        self.bodyPosition.P = 50000
    end
    
    if self.antiGravity then
        self.antiGravity.Position = Vector3.new(finalPosition.X, finalPosition.Y, finalPosition.Z)
    end
    
    if self.bodyAngularVelocity then
        self.bodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
    end
    
    spawn(function()
        wait(2)
        self.humanoid.PlatformStand = false
        wait(1)
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
    self:updateStatus(statusLabel, "Searching for delivery box...", Color3.fromRGB(255, 255, 0))
    
    local deliveryBox = self:findDeliveryBox()
    if not deliveryBox then
        self:updateStatus(statusLabel, "Delivery box not found", Color3.fromRGB(255, 80, 80))
        return
    end
    
    self:updateStatus(statusLabel, "Initiating fling to delivery...", Color3.fromRGB(0, 255, 255))
    
    self:performFling(deliveryBox.Position, function(success, message)
        if success then
            self:updateStatus(statusLabel, "Delivery teleport successful!", Color3.fromRGB(0, 255, 0))
        else
            self:updateStatus(statusLabel, "Delivery teleport failed: " .. message, Color3.fromRGB(255, 80, 80))
        end
    end)
end

function FlingTeleportSystem:teleportToNearestBase(statusLabel)
    self:updateStatus(statusLabel, "Searching for nearest base...", Color3.fromRGB(255, 255, 0))
    
    local nearestBase = self:findNearestBase()
    if not nearestBase then
        self:updateStatus(statusLabel, "No accessible base found", Color3.fromRGB(255, 80, 80))
        return
    end
    
    self:updateStatus(statusLabel, "Initiating fling to base...", Color3.fromRGB(0, 255, 255))
    
    self:performFling(nearestBase.Position, function(success, message)
        if success then
            self:updateStatus(statusLabel, "Base teleport successful!", Color3.fromRGB(0, 255, 0))
        else
            self:updateStatus(statusLabel, "Base teleport failed: " .. message, Color3.fromRGB(255, 80, 80))
        end
    end)
end

function FlingTeleportSystem:updateStatus(statusLabel, message, color)
    statusLabel.Text = message
    statusLabel.TextColor3 = color
    statusLabel.TextTransparency = 0
    
    spawn(function()
        wait(3)
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
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    mainFrame.BorderSizePixel = 0
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.Size = self.isMobile and UDim2.new(0, 300, 0, 250) or UDim2.new(0, 350, 0, 220)
    
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, 12)
    uiCorner.Parent = mainFrame
    
    local uiStroke = Instance.new("UIStroke")
    uiStroke.Parent = mainFrame
    uiStroke.Color = Color3.fromRGB(0, 150, 255)
    uiStroke.Thickness = 2
    
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Parent = mainFrame
    titleBar.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    titleBar.BorderSizePixel = 0
    titleBar.Size = UDim2.new(1, 0, 0, 35)
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Parent = titleBar
    titleLabel.BackgroundTransparency = 1
    titleLabel.Size = UDim2.new(1, -60, 1, 0)
    titleLabel.Position = UDim2.new(0, 10, 0, 0)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Text = "🚀 FLING TELEPORT"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
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
    
    local deliveryButton = self:createButton(content, "📦 Fling to Delivery", UDim2.new(0.05, 0, 0.1, 0))
    local baseButton = self:createButton(content, "🏠 Fling to Base", UDim2.new(0.05, 0, 0.35, 0))
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Parent = content
    statusLabel.BackgroundTransparency = 1
    statusLabel.Size = UDim2.new(0.9, 0, 0, 30)
    statusLabel.Position = UDim2.new(0.05, 0, 0.65, 0)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    statusLabel.TextSize = self.isMobile and 10 or 12
    statusLabel.TextTransparency = 1
    statusLabel.Text = ""
    statusLabel.TextWrapped = true
    
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Parent = content
    infoLabel.BackgroundTransparency = 1
    infoLabel.Size = UDim2.new(0.9, 0, 0, 20)
    infoLabel.Position = UDim2.new(0.05, 0, 0.85, 0)
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
    infoLabel.TextSize = self.isMobile and 8 or 10
    infoLabel.Text = "Press P to toggle • Enhanced fling system"
    infoLabel.TextWrapped = true
    
    self.gui = screenGui
    self.isActive = true
    
    self:setupButtonEvents(deliveryButton, baseButton, closeButton, statusLabel)
    self:setupDragFunctionality(titleBar, mainFrame)
end

function FlingTeleportSystem:createButton(parent, text, position)
    local button = Instance.new("TextButton")
    button.Parent = parent
    button.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
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
    
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(0, 170, 255)}):Play()
    end)
    
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(0, 150, 255)}):Play()
    end)
    
    return button
end

function FlingTeleportSystem:setupButtonEvents(deliveryButton, baseButton, closeButton, statusLabel)
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
