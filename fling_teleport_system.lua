local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

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
    self.flingPower = 16
    self.random = Random.new()
    self.gui = nil
    self.dragConnection = nil
    self.isDragging = false
    self.dragStart = nil
    self.startPos = nil
    self.isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    self.lastValidPosition = nil
    self.bodyVelocity = nil
    self.bodyPosition = nil
    self.activeConnections = {}
    
    self:initialize()
    return self
end

function FlingTeleportSystem:initialize()
    self:setupCharacterConnection()
    self:createGui()
    self:setupInputHandling()
    self:setupNetworkAdaptation()
end

function FlingTeleportSystem:setupNetworkAdaptation()
    spawn(function()
        while self.isActive do
            pcall(function()
                local ping = Player:GetNetworkPing() * 1000
                self.flingPower = math.clamp(16 + (ping / 50), 16, 50)
            end)
            wait(1)
        end
    end)
end

function FlingTeleportSystem:setupCharacterConnection()
    local function onCharacterAdded(character)
        self.character = character
        self.humanoidRootPart = character:WaitForChild("HumanoidRootPart")
        self.humanoid = character:WaitForChild("Humanoid")
        
        self.humanoid.StateChanged:Connect(function(oldState, newState)
            if newState == Enum.HumanoidStateType.Dead then
                self:handleCharacterDeath()
            end
        end)
        
        spawn(function()
            wait(1)
            if self:validateCharacter() then
                self.lastValidPosition = self.humanoidRootPart.Position
            end
        end)
    end
    
    if Player.Character then
        onCharacterAdded(Player.Character)
    end
    
    Player.CharacterAdded:Connect(onCharacterAdded)
end

function FlingTeleportSystem:handleCharacterDeath()
    self:clearFlingObjects()
    self.character = nil
    self.humanoidRootPart = nil
    self.humanoid = nil
end

function FlingTeleportSystem:validateCharacter()
    return self.character and self.humanoidRootPart and self.humanoidRootPart.Parent and self.humanoid
end

function FlingTeleportSystem:clearFlingObjects()
    if self.bodyVelocity then
        self.bodyVelocity:Destroy()
        self.bodyVelocity = nil
    end
    if self.bodyPosition then
        self.bodyPosition:Destroy()
        self.bodyPosition = nil
    end
    
    for _, connection in pairs(self.activeConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    self.activeConnections = {}
end

function FlingTeleportSystem:createFlingObjects()
    self:clearFlingObjects()
    
    if not self:validateCharacter() then return false end
    
    self.bodyVelocity = Instance.new("BodyVelocity")
    self.bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    self.bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    self.bodyVelocity.Parent = self.humanoidRootPart
    
    self.bodyPosition = Instance.new("BodyPosition")
    self.bodyPosition.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    self.bodyPosition.Position = self.humanoidRootPart.Position
    self.bodyPosition.D = 5000
    self.bodyPosition.P = 50000
    self.bodyPosition.Parent = self.humanoidRootPart
    
    return true
end

function FlingTeleportSystem:flingToPosition(targetPosition)
    if not self:validateCharacter() then return false end
    
    local startPosition = self.humanoidRootPart.Position
    local direction = (targetPosition - startPosition).Unit
    local distance = (targetPosition - startPosition).Magnitude
    
    if not self:createFlingObjects() then return false end
    
    local flingForce = direction * self.flingPower * math.min(distance / 100, 10)
    
    self.humanoid.PlatformStand = true
    self.bodyVelocity.Velocity = flingForce
    
    local connection
    connection = RunService.Heartbeat:Connect(function()
        if not self:validateCharacter() or not self.bodyVelocity then
            if connection then connection:Disconnect() end
            return
        end
        
        local currentDistance = (self.humanoidRootPart.Position - targetPosition).Magnitude
        
        if currentDistance < 50 or (self.humanoidRootPart.Position - startPosition).Magnitude > distance * 1.5 then
            self.humanoid.PlatformStand = false
            self.bodyVelocity.Velocity = Vector3.new(0, 0, 0)
            self.bodyPosition.Position = targetPosition
            
            spawn(function()
                wait(0.5)
                self:clearFlingObjects()
            end)
            
            if connection then connection:Disconnect() end
        end
    end)
    
    table.insert(self.activeConnections, connection)
    
    return true
end

function FlingTeleportSystem:enhancedFlingTeleport(targetPosition)
    if not self:validateCharacter() then return false end
    
    local startPosition = self.humanoidRootPart.Position
    local distance = (startPosition - targetPosition).Magnitude
    
    if distance > 2000 then
        return self:segmentedFlingTeleport(targetPosition, 5)
    elseif distance > 500 then
        return self:segmentedFlingTeleport(targetPosition, 3)
    else
        return self:directFlingTeleport(targetPosition)
    end
end

function FlingTeleportSystem:segmentedFlingTeleport(targetPosition, segments)
    if not self:validateCharacter() then return false end
    
    local startPosition = self.humanoidRootPart.Position
    local segmentDistance = (targetPosition - startPosition).Magnitude / segments
    
    for i = 1, segments do
        if not self:validateCharacter() then return false end
        
        local progress = i / segments
        local segmentTarget = startPosition:lerp(targetPosition, progress)
        
        local jitter = Vector3.new(
            self.random:NextNumber(-5, 5),
            self.random:NextNumber(-2, 2),
            self.random:NextNumber(-5, 5)
        )
        
        segmentTarget = segmentTarget + jitter
        
        local success = self:flingToPosition(segmentTarget)
        if not success then return false end
        
        local timeout = 0
        while self:validateCharacter() and (self.humanoidRootPart.Position - segmentTarget).Magnitude > 100 and timeout < 50 do
            wait(0.1)
            timeout = timeout + 1
        end
        
        wait(0.2)
    end
    
    return self:flingToPosition(targetPosition)
end

function FlingTeleportSystem:directFlingTeleport(targetPosition)
    return self:flingToPosition(targetPosition)
end

function FlingTeleportSystem:smoothFlingTeleport(targetPosition)
    if not self:validateCharacter() then return false end
    
    local startPosition = self.humanoidRootPart.Position
    local distance = (startPosition - targetPosition).Magnitude
    local steps = math.min(math.max(20, math.floor(distance / 50)), 100)
    
    for i = 1, steps do
        if not self:validateCharacter() then return false end
        
        local progress = i / steps
        local smoothProgress = progress * progress * (3 - 2 * progress)
        local intermediatePosition = startPosition:lerp(targetPosition, smoothProgress)
        
        local jitter = Vector3.new(
            self.random:NextNumber(-1, 1),
            self.random:NextNumber(-0.5, 0.5),
            self.random:NextNumber(-1, 1)
        )
        
        intermediatePosition = intermediatePosition + jitter
        
        if not self:createFlingObjects() then return false end
        
        self.bodyPosition.Position = intermediatePosition
        self.bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        
        wait(0.05)
    end
    
    return self:flingToPosition(targetPosition)
end

function FlingTeleportSystem:findDeliveryBox()
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

function FlingTeleportSystem:findNearestBase()
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

function FlingTeleportSystem:executeFlingTeleport(target, statusLabel, operationType, method)
    if not self:validateCharacter() then
        self:updateStatus(statusLabel, "Error: Character not found", Color3.fromRGB(255, 80, 80))
        return false
    end
    
    if not target then
        self:updateStatus(statusLabel, "Error: Target location not found", Color3.fromRGB(255, 80, 80))
        return false
    end
    
    local targetPosition = target.Position + Vector3.new(0, 5, 0)
    
    self:updateStatus(statusLabel, "Initiating " .. operationType .. "...", Color3.fromRGB(255, 255, 100))
    
    local success = false
    if method == "enhanced" then
        success = self:enhancedFlingTeleport(targetPosition)
    elseif method == "smooth" then
        success = self:smoothFlingTeleport(targetPosition)
    else
        success = self:directFlingTeleport(targetPosition)
    end
    
    spawn(function()
        wait(2)
        
        if not self:validateCharacter() then
            self:updateStatus(statusLabel, "Error: Character lost during teleport", Color3.fromRGB(255, 80, 80))
            return
        end
        
        local finalDistance = (self.humanoidRootPart.Position - targetPosition).Magnitude
        
        if success and finalDistance <= 100 then
            self:updateStatus(statusLabel, operationType .. " Successful!", Color3.fromRGB(0, 255, 100))
            self.lastValidPosition = self.humanoidRootPart.Position
        else
            self:updateStatus(statusLabel, string.format("%s Failed: Distance %.0f", operationType, finalDistance), Color3.fromRGB(255, 80, 80))
        end
    end)
    
    return success
end

function FlingTeleportSystem:teleportToDelivery(statusLabel)
    local deliveryBox = self:findDeliveryBox()
    self:executeFlingTeleport(deliveryBox, statusLabel, "Delivery Fling", "enhanced")
end

function FlingTeleportSystem:teleportToNearestBase(statusLabel)
    local nearestBase = self:findNearestBase()
    self:executeFlingTeleport(nearestBase, statusLabel, "Base Fling", "enhanced")
end

function FlingTeleportSystem:smoothTeleport(statusLabel)
    local deliveryBox = self:findDeliveryBox()
    self:executeFlingTeleport(deliveryBox, statusLabel, "Smooth Fling", "smooth")
end

function FlingTeleportSystem:updateStatus(statusLabel, message, color)
    statusLabel.Text = message
    statusLabel.TextColor3 = color
    
    TweenService:Create(statusLabel, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
    
    spawn(function()
        wait(3)
        TweenService:Create(statusLabel, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
    end)
end

function FlingTeleportSystem:setupInputHandling()
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
    uiStroke.Color = Color3.fromRGB(255, 100, 0)
    uiStroke.Thickness = 2
    uiStroke.Transparency = 0.3
    
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
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Parent = titleBar
    titleLabel.BackgroundTransparency = 1
    titleLabel.Size = UDim2.new(1, -70, 1, 0)
    titleLabel.Position = UDim2.new(0, 15, 0, 0)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Text = "🚀 FLING TELEPORT SYSTEM"
    titleLabel.TextColor3 = Color3.fromRGB(255, 100, 0)
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
    
    local deliveryButton = self:createButton(content, "📦 Fling to Delivery", UDim2.new(0.05, 0, 0.08, 0))
    local baseButton = self:createButton(content, "🏠 Fling to Base", UDim2.new(0.05, 0, 0.28, 0))
    local smoothButton = self:createButton(content, "🌟 Smooth Fling", UDim2.new(0.05, 0, 0.48, 0))
    
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
    infoLabel.Text = self.isMobile and "Drag title bar to move • Tap P to toggle" or "Drag title bar to move • Press P to toggle"
    infoLabel.TextWrapped = true
    
    self.gui = screenGui
    self.isActive = true
    
    self:setupDragFunctionality(titleBar, mainFrame)
    self:setupButtonEvents(deliveryButton, baseButton, smoothButton, closeButton, statusLabel)
    self:animateGuiOpen(mainFrame)
end

function FlingTeleportSystem:setupDragFunctionality(titleBar, mainFrame)
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

function FlingTeleportSystem:createButton(parent, text, position)
    local button = Instance.new("TextButton")
    button.Parent = parent
    button.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
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
    buttonStroke.Color = Color3.fromRGB(200, 100, 0)
    buttonStroke.Thickness = 1
    buttonStroke.Transparency = 0.5
    
    self:addButtonAnimation(button, buttonStroke)
    
    return button
end

function FlingTeleportSystem:addButtonAnimation(button, stroke)
    button.MouseEnter:Connect(function()
        TweenService:Create(stroke, TweenInfo.new(0.2), {
            Transparency = 0.2
        }):Play()
        TweenService:Create(button, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(255, 160, 20)
        }):Play()
    end)
    
    button.MouseLeave:Connect(function()
        TweenService:Create(stroke, TweenInfo.new(0.2), {
            Transparency = 0.5
        }):Play()
        TweenService:Create(button, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(255, 140, 0)
        }):Play()
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

function FlingTeleportSystem:setupButtonEvents(deliveryButton, baseButton, smoothButton, closeButton, statusLabel)
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
        self:destroy()
    end)
end

function FlingTeleportSystem:animateGuiOpen(frame)
    local targetSize = self.isMobile and UDim2.new(0, 320, 0, 280) or UDim2.new(0, 380, 0, 260)
    
    TweenService:Create(frame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = targetSize
    }):Play()
end

function FlingTeleportSystem:destroy()
    self.isActive = false
    self:clearFlingObjects()
    
    if self.gui then
        self.gui:Destroy()
    end
    
    if self.dragConnection then
        self.dragConnection:Disconnect()
    end
    
    for _, connection in pairs(self.activeConnections) do
        if connection then
            connection:Disconnect()
        end
    end
end

local flingSystem = FlingTeleportSystem.new()