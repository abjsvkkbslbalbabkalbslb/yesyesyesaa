local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
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
    self.teleportAmount = 85
    self.voidPosition = CFrame.new(0, -1e6, 0)
    self.random = Random.new()
    self.gui = nil
    self.blurEffect = nil
    self.isDragging = false
    self.dragStart = nil
    self.startPos = nil
    self.pingMonitor = 0
    self.networkStable = true
    
    self:initialize()
    return self
end

function TeleportSystem:initialize()
    self:setupNetworkMonitoring()
    self:setupCharacterConnection()
    self:createGui()
    self:setupInputHandling()
end

function TeleportSystem:setupNetworkMonitoring()
    spawn(function()
        while self.isActive do
            local ping = Player:GetNetworkPing() * 1000
            self.pingMonitor = ping
            
            if ping < 50 then
                self.teleportAmount = 65
                self.networkStable = true
            elseif ping < 100 then
                self.teleportAmount = 85
                self.networkStable = true
            elseif ping < 150 then
                self.teleportAmount = 110
                self.networkStable = true
            elseif ping < 200 then
                self.teleportAmount = 135
                self.networkStable = false
            else
                self.teleportAmount = 160
                self.networkStable = false
            end
            
            wait(0.5)
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
    return self.character and self.humanoidRootPart and self.humanoidRootPart.Parent and self.humanoid and self.humanoid.Health > 0
end

function TeleportSystem:safeWait(duration)
    local startTime = tick()
    while tick() - startTime < duration and self:validateCharacter() do
        RunService.Heartbeat:Wait()
    end
end

function TeleportSystem:adaptiveTeleport(targetCFrame)
    if not self:validateCharacter() or typeof(targetCFrame) ~= "CFrame" then
        return false
    end
    
    local distance = (self.humanoidRootPart.Position - targetCFrame.Position).Magnitude
    local segments = math.ceil(distance / 500)
    
    if segments > 1 then
        return self:segmentedTeleport(targetCFrame, segments)
    else
        return self:standardTeleport(targetCFrame)
    end
end

function TeleportSystem:segmentedTeleport(targetCFrame, segments)
    local startPos = self.humanoidRootPart.Position
    local endPos = targetCFrame.Position
    
    for segment = 1, segments do
        if not self:validateCharacter() then return false end
        
        local progress = segment / segments
        local segmentPos = startPos:Lerp(endPos, progress)
        local segmentCFrame = CFrame.new(segmentPos, targetCFrame.LookVector)
        
        local teleportCount = math.floor(self.teleportAmount / segments)
        if segment == segments then
            teleportCount = self.teleportAmount - (teleportCount * (segments - 1))
        end
        
        for i = 1, teleportCount do
            if not self:validateCharacter() then return false end
            
            local jitter = Vector3.new(
                self.random:NextNumber(-0.002, 0.002),
                self.random:NextNumber(-0.002, 0.002),
                self.random:NextNumber(-0.002, 0.002)
            )
            
            self.humanoidRootPart.CFrame = segmentCFrame + jitter
            
            if not self.networkStable then
                RunService.Heartbeat:Wait()
                RunService.Heartbeat:Wait()
            else
                RunService.Heartbeat:Wait()
            end
        end
        
        if segment < segments then
            self:safeWait(0.02)
        end
    end
    
    return self:finalizePosition(targetCFrame)
end

function TeleportSystem:standardTeleport(targetCFrame)
    local adaptiveAmount = self.teleportAmount
    
    if not self.networkStable then
        adaptiveAmount = adaptiveAmount + math.floor(self.pingMonitor / 10)
    end
    
    for i = 1, adaptiveAmount do
        if not self:validateCharacter() then return false end
        
        local jitter = Vector3.new(
            self.random:NextNumber(-0.002, 0.002),
            self.random:NextNumber(-0.002, 0.002),
            self.random:NextNumber(-0.002, 0.002)
        )
        
        self.humanoidRootPart.CFrame = targetCFrame + jitter
        
        if not self.networkStable and i % 3 == 0 then
            RunService.Heartbeat:Wait()
            RunService.Heartbeat:Wait()
        else
            RunService.Heartbeat:Wait()
        end
    end
    
    return self:finalizePosition(targetCFrame)
end

function TeleportSystem:finalizePosition(targetCFrame)
    if not self:validateCharacter() then return false end
    
    local voidCycles = self.networkStable and 3 or 5
    
    for i = 1, voidCycles do
        if not self:validateCharacter() then return false end
        
        self.humanoidRootPart.CFrame = self.voidPosition
        self:safeWait(0.03)
        
        if not self:validateCharacter() then return false end
        
        self.humanoidRootPart.CFrame = targetCFrame
        self:safeWait(0.03)
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

function TeleportSystem:executeAdaptiveTeleport(targetCFrame, statusLabel, operationType)
    if not self:validateCharacter() then
        self:updateStatus(statusLabel, "Error: Character not found", Color3.fromRGB(255, 80, 80))
        return false
    end
    
    if not targetCFrame then
        self:updateStatus(statusLabel, "Error: Target location not found", Color3.fromRGB(255, 80, 80))
        return false
    end
    
    self:updateStatus(statusLabel, "Executing " .. operationType .. "...", Color3.fromRGB(255, 255, 100))
    
    local success = self:adaptiveTeleport(targetCFrame)
    
    self:safeWait(0.3)
    
    if not self:validateCharacter() then
        self:updateStatus(statusLabel, "Error: Character lost", Color3.fromRGB(255, 80, 80))
        return false
    end
    
    local distance = (self.humanoidRootPart.Position - targetCFrame.Position).Magnitude
    
    if success and distance <= 25 then
        self:updateStatus(statusLabel, operationType .. " Complete!", Color3.fromRGB(0, 255, 100))
        return true
    else
        self:updateStatus(statusLabel, operationType .. " Failed", Color3.fromRGB(255, 80, 80))
        return false
    end
end

function TeleportSystem:teleportToDelivery(statusLabel)
    local deliveryBox = self:findDeliveryBox()
    if not deliveryBox then
        self:updateStatus(statusLabel, "Error: Delivery box not found", Color3.fromRGB(255, 80, 80))
        return
    end
    
    local targetCFrame = deliveryBox.CFrame * CFrame.new(0, -2.5, 0)
    self:executeAdaptiveTeleport(targetCFrame, statusLabel, "Delivery Teleport")
end

function TeleportSystem:teleportToNearestBase(statusLabel)
    local nearestBase = self:findNearestBase()
    if not nearestBase then
        self:updateStatus(statusLabel, "Error: No base found", Color3.fromRGB(255, 80, 80))
        return
    end
    
    local targetCFrame = nearestBase.CFrame * CFrame.new(0, 2, 0)
    self:executeAdaptiveTeleport(targetCFrame, statusLabel, "Base Teleport")
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
    
    local baseSteps = math.max(60, math.floor(distance / 15))
    local adaptiveSteps = self.networkStable and baseSteps or math.floor(baseSteps * 1.3)
    local maxSteps = math.min(adaptiveSteps, 200)
    
    local stepDuration = self.networkStable and 0.006 or 0.009
    
    for i = 1, maxSteps do
        if not self:validateCharacter() then
            self:updateStatus(statusLabel, "Error: Character lost", Color3.fromRGB(255, 80, 80))
            return
        end
        
        local progress = i / maxSteps
        local smoothProgress = progress * progress * (3 - 2 * progress)
        
        local newPosition = startPosition:Lerp(endPosition, smoothProgress)
        local microJitter = Vector3.new(
            self.random:NextNumber(-0.001, 0.001),
            self.random:NextNumber(-0.001, 0.001),
            self.random:NextNumber(-0.001, 0.001)
        )
        
        self.humanoidRootPart.CFrame = CFrame.new(newPosition + microJitter, targetCFrame.LookVector)
        
        self:safeWait(stepDuration)
    end
    
    self:finalizePosition(targetCFrame)
    
    self:safeWait(0.3)
    
    if self:validateCharacter() then
        local finalDistance = (self.humanoidRootPart.Position - targetCFrame.Position).Magnitude
        if finalDistance <= 25 then
            self:updateStatus(statusLabel, "Smooth Teleport Complete!", Color3.fromRGB(0, 255, 100))
        else
            self:updateStatus(statusLabel, "Smooth Teleport Failed", Color3.fromRGB(255, 80, 80))
        end
    else
        self:updateStatus(statusLabel, "Smooth Teleport Failed", Color3.fromRGB(255, 80, 80))
    end
end

function TeleportSystem:updateStatus(statusLabel, message, color)
    statusLabel.Text = message
    statusLabel.TextColor3 = color
    
    TweenService:Create(statusLabel, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
    
    spawn(function()
        wait(2)
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
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    mainFrame.BorderSizePixel = 0
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    mainFrame.ClipsDescendants = true
    
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, 12)
    uiCorner.Parent = mainFrame
    
    local uiStroke = Instance.new("UIStroke")
    uiStroke.Parent = mainFrame
    uiStroke.Color = Color3.fromRGB(60, 140, 255)
    uiStroke.Thickness = 2
    uiStroke.Transparency = 0.6
    
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Parent = mainFrame
    titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    titleBar.BorderSizePixel = 0
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.Active = true
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Parent = titleBar
    titleLabel.BackgroundTransparency = 1
    titleLabel.Size = UDim2.new(1, -60, 1, 0)
    titleLabel.Position = UDim2.new(0, 15, 0, 0)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Text = "⚡ TELEPORT SYSTEM"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 14
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
    closeButton.TextSize = 16
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
    local baseButton = self:createButton(content, "🏠 Teleport to Base", UDim2.new(0.05, 0, 0.25, 0))
    local smoothButton = self:createButton(content, "🌟 Smooth Teleport", UDim2.new(0.05, 0, 0.42, 0))
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Parent = content
    statusLabel.BackgroundTransparency = 1
    statusLabel.Size = UDim2.new(0.9, 0, 0, 30)
    statusLabel.Position = UDim2.new(0.05, 0, 0.65, 0)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    statusLabel.TextSize = 11
    statusLabel.TextTransparency = 1
    statusLabel.Text = ""
    statusLabel.TextWrapped = true
    
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "InfoLabel"
    infoLabel.Parent = content
    infoLabel.BackgroundTransparency = 1
    infoLabel.Size = UDim2.new(0.9, 0, 0, 25)
    infoLabel.Position = UDim2.new(0.05, 0, 0.8, 0)
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
    infoLabel.TextSize = 9
    infoLabel.Text = "Drag title bar to move • Tap P to toggle"
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
        
        local dragConnection
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
            if dragConnection then
                dragConnection:Disconnect()
                dragConnection = nil
            end
        end
        
        dragConnection = UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                updateDrag(input)
            end
        end)
        
        UserInputService.TouchEnded:Connect(function()
            stopDrag()
        end)
    end
    
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            startDrag(input)
        end
    end)
end

function TeleportSystem:createButton(parent, text, position)
    local button = Instance.new("TextButton")
    button.Parent = parent
    button.BackgroundColor3 = Color3.fromRGB(50, 130, 255)
    button.BorderSizePixel = 0
    button.Position = position
    button.Size = UDim2.new(0.9, 0, 0, 40)
    button.Font = Enum.Font.GothamSemibold
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 13
    button.AutoButtonColor = false
    
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 8)
    buttonCorner.Parent = button
    
    local buttonStroke = Instance.new("UIStroke")
    buttonStroke.Parent = button
    buttonStroke.Color = Color3.fromRGB(30, 100, 220)
    buttonStroke.Thickness = 1
    buttonStroke.Transparency = 0.4
    
    return button
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
        self:destroy()
    end)
end

function TeleportSystem:animateGuiOpen(frame)
    local targetSize = UDim2.new(0, 300, 0, 250)
    
    TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = targetSize
    }):Play()
    
    spawn(function()
        wait(0.1)
        for i, child in pairs(frame:GetDescendants()) do
            if child:IsA("TextLabel") or child:IsA("TextButton") then
                spawn(function()
                    wait(i * 0.01)
                    child.TextTransparency = 1
                    TweenService:Create(child, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
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
                    TweenService:Create(mainFrame, TweenInfo.new(0.2), {
                        Size = UDim2.new(0, 0, 0, 0)
                    }):Play()
                    
                    spawn(function()
                        wait(0.2)
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
    
    if self.gui then
        local mainFrame = self.gui.MainFrame
        
        TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0)
        }):Play()
        
        for _, child in pairs(mainFrame:GetDescendants()) do
            if child:IsA("TextLabel") or child:IsA("TextButton") then
                TweenService:Create(child, TweenInfo.new(0.1), {TextTransparency = 1}):Play()
            end
        end
        
        Debris:AddItem(self.gui, 0.4)
    end
end

local teleportSystem = TeleportSystem.new()
