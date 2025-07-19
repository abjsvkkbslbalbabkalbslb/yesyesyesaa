if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
repeat task.wait() until Players.LocalPlayer
local Player = Players.LocalPlayer
repeat task.wait() until Player:FindFirstChild("PlayerGui")

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Random = Random.new()

local IsTeleporting = false
local IsDestroyed = false

local Character, Humanoid, HumanoidRootPart
local Motor6DJoints = {}

local AntiRagdollEnabled = false
local AntiTrapEnabled = false
local SpeedBoostEnabled = false

local RagdollConnection = nil
local SpeedConnection = nil
local TrapConnections = {}

local NormalSpeed = 16
local BoostedSpeed = 35

local function GetCharacter()
    return Player.Character or Player.CharacterAdded:Wait()
end

local function GetR6Motor6Ds(char)
    local joints = {}
    local torso = char:FindFirstChild("Torso")
    if torso then
        joints.RootJoint = torso:FindFirstChild("RootJoint")
        joints.Neck = torso:FindFirstChild("Neck")
        joints.LeftShoulder = torso:FindFirstChild("Left Shoulder")
        joints.RightShoulder = torso:FindFirstChild("Right Shoulder")
        joints.LeftHip = torso:FindFirstChild("Left Hip")
        joints.RightHip = torso:FindFirstChild("Right Hip")
    end
    return joints
end

local function ConvertToR6Motor6D()
    if not Character then return false end
    
    -- Check if already R6
    local torso = Character:FindFirstChild("Torso")
    local head = Character:FindFirstChild("Head")
    local leftArm = Character:FindFirstChild("Left Arm")
    local rightArm = Character:FindFirstChild("Right Arm")
    local leftLeg = Character:FindFirstChild("Left Leg")
    local rightLeg = Character:FindFirstChild("Right Leg")
    
    if torso and head and leftArm and rightArm and leftLeg and rightLeg then
        Motor6DJoints = GetR6Motor6Ds(Character)
        return true
    end
    
    -- Convert R15 to R6-style Motor6Ds if needed
    local humanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return false end
    
    -- Create R6 parts if they don't exist
    if not torso then
        torso = Instance.new("Part")
        torso.Name = "Torso"
        torso.Size = Vector3.new(2, 2, 1)
        torso.BrickColor = BrickColor.new("Bright blue")
        torso.TopSurface = Enum.SurfaceType.Smooth
        torso.BottomSurface = Enum.SurfaceType.Smooth
        torso.Parent = Character
        
        -- Create RootJoint
        local rootJoint = Instance.new("Motor6D")
        rootJoint.Name = "RootJoint"
        rootJoint.Part0 = humanoidRootPart
        rootJoint.Part1 = torso
        rootJoint.C0 = CFrame.new(0, 0, 0)
        rootJoint.C1 = CFrame.new(0, 0, 0)
        rootJoint.Parent = humanoidRootPart
    end
    
    -- Create other R6 parts and joints as needed
    Motor6DJoints = GetR6Motor6Ds(Character)
    return Motor6DJoints.RootJoint ~= nil
end

local function TeleportViaMotor6D(targetCFrame)
    if not Motor6DJoints.RootJoint then return false end
    
    -- Calculate the offset needed
    local currentCFrame = HumanoidRootPart.CFrame
    local offset = targetCFrame * currentCFrame:Inverse()
    
    -- Apply the teleport through Motor6D manipulation
    local rootJoint = Motor6DJoints.RootJoint
    local originalC0 = rootJoint.C0
    
    -- Temporarily modify the joint to achieve teleportation
    rootJoint.C0 = originalC0 * offset
    
    -- Add small random variation to avoid detection
    local randomOffset = Vector3.new(
        Random:NextNumber(-0.001, 0.001),
        Random:NextNumber(-0.001, 0.001),
        Random:NextNumber(-0.001, 0.001)
    )
    
    HumanoidRootPart.CFrame = targetCFrame + randomOffset
    
    -- Reset joint after teleport
    task.wait()
    rootJoint.C0 = originalC0
    
    return true
end

local function AnchorCharacter(char, state)
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.Anchored = state
        end
    end
end

local function HandleRagdoll(char)
    local humanoid = char:WaitForChild("Humanoid", 5)
    if not humanoid then return end
    
    if RagdollConnection then
        RagdollConnection:Disconnect()
    end
    
    RagdollConnection = humanoid.StateChanged:Connect(function(_, newState)
        if AntiRagdollEnabled and (newState == Enum.HumanoidStateType.Physics or 
           newState == Enum.HumanoidStateType.Ragdoll or 
           newState == Enum.HumanoidStateType.FallingDown) then
            AnchorCharacter(char, true)
            task.wait(0.01)
            AnchorCharacter(char, false)
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end)
end

local function EnforceSpeed(humanoid)
    if SpeedConnection then
        SpeedConnection:Disconnect()
    end
    
    SpeedConnection = RunService.Heartbeat:Connect(function()
        if SpeedBoostEnabled and humanoid and humanoid.WalkSpeed ~= BoostedSpeed then
            humanoid.WalkSpeed = BoostedSpeed
        end
    end)
    
    humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if SpeedBoostEnabled and humanoid.WalkSpeed ~= BoostedSpeed then
            humanoid.WalkSpeed = BoostedSpeed
        end
    end)
end

local function RemoveTrapTouchInterest()
    for _, obj in pairs(game:GetDescendants()) do
        if obj:IsA("TouchTransmitter") and obj.Name == "TouchInterest" then
            local parent = obj.Parent
            if parent and parent:IsA("MeshPart") and parent.Name == "Open" then
                local model = parent:FindFirstAncestorOfClass("Model")
                if model and model.Name == "Trap" then
                    obj:Destroy()
                end
            end
        end
    end
end

local function HandleTrapSpawn(obj)
    if AntiTrapEnabled and obj:IsA("TouchTransmitter") and obj.Name == "TouchInterest" then
        local parent = obj.Parent
        if parent and parent:IsA("MeshPart") and parent.Name == "Open" then
            local model = parent:FindFirstAncestorOfClass("Model")
            if model and model.Name == "Trap" then
                obj:Destroy()
            end
        end
    end
end

local function SetupCharacter()
    Character = GetCharacter()
    Humanoid = Character:WaitForChild("Humanoid")
    HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
    
    -- Convert to R6 Motor6D system
    ConvertToR6Motor6D()
    
    if AntiRagdollEnabled then
        HandleRagdoll(Character)
    end
    
    if SpeedBoostEnabled then
        EnforceSpeed(Humanoid)
    end
    
    Humanoid.Died:Connect(function()
        if not IsDestroyed then
            Player:LoadCharacter()
        end
    end)
    
    task.spawn(function()
        while Humanoid and Humanoid.Health > 0 and not IsDestroyed do
            if HumanoidRootPart.Position.Y < -50 then
                Player:LoadCharacter()
                break
            end
            task.wait(1)
        end
    end)
end

SetupCharacter()

local CharacterConnection = Player.CharacterAdded:Connect(function()
    if not IsDestroyed then
        SetupCharacter()
    end
end)

local TrapConnection = game.DescendantAdded:Connect(HandleTrapSpawn)

-- GUI Creation (same as original)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "R6Motor6DTeleportGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = Player:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 320, 0, 250)
MainFrame.Position = UDim2.new(0, 50, 0, 50)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.BackgroundTransparency = 0.1
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

local Gradient = Instance.new("UIGradient")
Gradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 30)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 20))
}
Gradient.Rotation = 45
Gradient.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -20, 0, 35)
TitleLabel.Position = UDim2.new(0, 10, 0, 5)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "R6 Motor6D Teleporter || V1"
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 18
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextXAlignment = Enum.TextXAlignment.Center
TitleLabel.Parent = MainFrame

local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 25, 0, 25)
CloseButton.Position = UDim2.new(1, -35, 0, 5)
CloseButton.BackgroundColor3 = Color3.fromRGB(255, 85, 85)
CloseButton.Text = "×"
CloseButton.Font = Enum.Font.GothamBold
CloseButton.TextSize = 16
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.Parent = MainFrame

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseButton

-- Dragging functionality (same as original)
local IsDragging = false
local DragInput, DragStart, StartPos

local function UpdateDrag(Input)
    local Delta = Input.Position - DragStart
    MainFrame.Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + Delta.X,
                                   StartPos.Y.Scale, StartPos.Y.Offset + Delta.Y)
end

MainFrame.InputBegan:Connect(function(Input)
    if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
        IsDragging = true
        DragStart = Input.Position
        StartPos = MainFrame.Position

        Input.Changed:Connect(function()
            if Input.UserInputState == Enum.UserInputState.End then
                IsDragging = false
            end
        end)
    end
end)

MainFrame.InputChanged:Connect(function(Input)
    if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch then
        DragInput = Input
    end
end)

UserInputService.InputChanged:Connect(function(Input)
    if Input == DragInput and IsDragging then
        UpdateDrag(Input)
    end
end)

UserInputService.TouchMoved:Connect(function(Touch, GameProcessed)
    if Touch == DragInput and IsDragging then
        UpdateDrag(Touch)
    end
end)

-- Input boxes and buttons (same styling as original)
local function CreateInputBox(PlaceholderText, Position)
    local InputBox = Instance.new("TextBox")
    InputBox.Size = UDim2.new(0, 90, 0, 30)
    InputBox.Position = Position
    InputBox.PlaceholderText = PlaceholderText
    InputBox.Text = ""
    InputBox.ClearTextOnFocus = false
    InputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    InputBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    InputBox.Font = Enum.Font.Gotham
    InputBox.TextSize = 14
    InputBox.BackgroundTransparency = 0.2
    InputBox.Parent = MainFrame
    
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 6)
    Corner.Parent = InputBox
    
    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(60, 60, 60)
    Stroke.Thickness = 1
    Stroke.Parent = InputBox
    
    InputBox.Focused:Connect(function()
        Stroke.Color = Color3.fromRGB(70, 130, 250)
    end)
    
    InputBox.FocusLost:Connect(function()
        Stroke.Color = Color3.fromRGB(60, 60, 60)
    end)
    
    return InputBox
end

local InputX = CreateInputBox("X", UDim2.new(0, 15, 0, 50))
local InputY = CreateInputBox("Y", UDim2.new(0, 115, 0, 50))
local InputZ = CreateInputBox("Z", UDim2.new(0, 215, 0, 50))

local function CreateButton(Text, Position, Size, Color, TextColor)
    local Button = Instance.new("TextButton")
    Button.Size = Size
    Button.Position = Position
    Button.Text = Text
    Button.BackgroundColor3 = Color
    Button.TextColor3 = TextColor or Color3.fromRGB(255, 255, 255)
    Button.Font = Enum.Font.GothamBold
    Button.TextSize = 14
    Button.Parent = MainFrame
    
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Button
    
    local Gradient = Instance.new("UIGradient")
    Gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color),
        ColorSequenceKeypoint.new(1, Color3.new(Color.R * 0.8, Color.G * 0.8, Color.B * 0.8))
    }
    Gradient.Rotation = 90
    Gradient.Parent = Button
    
    Button.MouseEnter:Connect(function()
        local Tween = TweenService:Create(Button, TweenInfo.new(0.2), {BackgroundTransparency = 0.1})
        Tween:Play()
    end)
    
    Button.MouseLeave:Connect(function()
        local Tween = TweenService:Create(Button, TweenInfo.new(0.2), {BackgroundTransparency = 0})
        Tween:Play()
    end)
    
    return Button
end

local function CreateToggle(Text, Position, Size, Color, Callback)
    local Toggle = Instance.new("TextButton")
    Toggle.Size = Size
    Toggle.Position = Position
    Toggle.Text = Text .. ": OFF"
    Toggle.BackgroundColor3 = Color
    Toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    Toggle.Font = Enum.Font.GothamBold
    Toggle.TextSize = 12
    Toggle.Parent = MainFrame
    
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Toggle
    
    local ToggleState = false
    
    Toggle.MouseButton1Click:Connect(function()
        ToggleState = not ToggleState
        Toggle.Text = Text .. ": " .. (ToggleState and "ON" or "OFF")
        Toggle.BackgroundColor3 = ToggleState and Color3.fromRGB(85, 170, 85) or Color
        
        if Callback then
            Callback(ToggleState)
        end
    end)
    
    return Toggle
end

local SetCurrentButton = CreateButton("Set Current", UDim2.new(0, 15, 0, 90), UDim2.new(0, 140, 0, 30), Color3.fromRGB(60, 60, 60))
local TeleportButton = CreateButton("Motor6D TP", UDim2.new(0, 165, 0, 90), UDim2.new(0, 140, 0, 30), Color3.fromRGB(70, 130, 250))
local SmoothTeleportButton = CreateButton("Smooth Motor6D", UDim2.new(0, 15, 0, 130), UDim2.new(0, 140, 0, 30), Color3.fromRGB(130, 70, 250))

local AntiRagdollToggle = CreateToggle("Anti Ragdoll", UDim2.new(0, 165, 0, 130), UDim2.new(0, 140, 0, 30), Color3.fromRGB(255, 140, 0), function(state)
    AntiRagdollEnabled = state
    if state and Character then
        HandleRagdoll(Character)
    elseif RagdollConnection then
        RagdollConnection:Disconnect()
        RagdollConnection = nil
    end
end)

local AntiTrapToggle = CreateToggle("Anti Trap", UDim2.new(0, 15, 0, 170), UDim2.new(0, 140, 0, 30), Color3.fromRGB(255, 85, 85), function(state)
    AntiTrapEnabled = state
    if state then
        RemoveTrapTouchInterest()
    end
end)

local SpeedBoostToggle = CreateToggle("Speed Boost", UDim2.new(0, 165, 0, 170), UDim2.new(0, 140, 0, 30), Color3.fromRGB(85, 255, 127), function(state)
    SpeedBoostEnabled = state
    if Character and Humanoid then
        if state then
            EnforceSpeed(Humanoid)
        else
            if SpeedConnection then
                SpeedConnection:Disconnect()
                SpeedConnection = nil
            end
            Humanoid.WalkSpeed = NormalSpeed
        end
    end
end)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -20, 0, 30)
StatusLabel.Position = UDim2.new(0, 10, 0, 210)
StatusLabel.Text = ""
StatusLabel.BackgroundTransparency = 1
StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 12
StatusLabel.TextWrapped = true
StatusLabel.TextXAlignment = Enum.TextXAlignment.Center
StatusLabel.Parent = MainFrame

local function ShowStatus(Text, Color)
    StatusLabel.Text = Text
    StatusLabel.TextColor3 = Color
    task.delay(3, function()
        if StatusLabel.Text == Text then
            StatusLabel.Text = ""
        end
    end)
end

-- New Motor6D-based teleport functions
local function Motor6DTeleportToCoordinates(Coordinates)
    if not (Coordinates and #Coordinates == 3) then return false end
    local TargetPosition = Vector3.new(Coordinates[1], Coordinates[2], Coordinates[3])
    local TargetCFrame = CFrame.new(TargetPosition)
    
    if not Motor6DJoints.RootJoint then
        ShowStatus("Motor6D not found!", Color3.fromRGB(255, 100, 100))
        return false
    end
    
    -- Perform Motor6D teleport
    for i = 1, 5 do -- Multiple attempts for stability
        TeleportViaMotor6D(TargetCFrame)
        task.wait(0.05)
    end
    
    local Distance = (HumanoidRootPart.Position - TargetPosition).Magnitude
    return Distance <= 50
end

local function SmoothMotor6DTeleport(Coordinates)
    if not (Coordinates and #Coordinates == 3) then return false end
    local TargetPosition = Vector3.new(Coordinates[1], Coordinates[2], Coordinates[3])
    local CurrentPosition = HumanoidRootPart.Position
    local Distance = (TargetPosition - CurrentPosition).Magnitude
    local Steps = math.ceil(Distance / 30)
    
    for i = 1, Steps do
        if IsDestroyed then return false end
        local Progress = i / Steps
        local IntermediatePosition = CurrentPosition:lerp(TargetPosition, Progress)
        local IntermediateCFrame = CFrame.new(IntermediatePosition)
        
        TeleportViaMotor6D(IntermediateCFrame)
        task.wait(0.1)
    end
    
    return Motor6DTeleportToCoordinates(Coordinates)
end

-- Button connections
SetCurrentButton.MouseButton1Click:Connect(function()
    if IsDestroyed then return end
    local Position = HumanoidRootPart.Position
    InputX.Text = tostring(math.floor(Position.X))
    InputY.Text = tostring(math.floor(Position.Y))
    InputZ.Text = tostring(math.floor(Position.Z))
    ShowStatus("Position Set", Color3.fromRGB(100, 255, 100))
end)

TeleportButton.MouseButton1Click:Connect(function()
    if IsDestroyed then return end
    local X = tonumber(InputX.Text)
    local Y = tonumber(InputY.Text)
    local Z = tonumber(InputZ.Text)
    
    if X and Y and Z then
        ShowStatus("Motor6D Teleporting...", Color3.fromRGB(200, 200, 255))
        task.spawn(function()
            local Success = Motor6DTeleportToCoordinates({X, Y, Z})
            if Success then
                ShowStatus("Motor6D TP Success!", Color3.fromRGB(100, 255, 100))
            else
                ShowStatus("Motor6D TP Failed", Color3.fromRGB(255, 100, 100))
            end
        end)
    else
        ShowStatus("Invalid Coordinates", Color3.fromRGB(255, 200, 100))
    end
end)

SmoothTeleportButton.MouseButton1Click:Connect(function()
    if IsDestroyed then return end
    local X = tonumber(InputX.Text)
    local Y = tonumber(InputY.Text)
    local Z = tonumber(InputZ.Text)
    
    if X and Y and Z then
        ShowStatus("Smooth Motor6D TP...", Color3.fromRGB(200, 150, 255))
        task.spawn(function()
            local Success = SmoothMotor6DTeleport({X, Y, Z})
            if Success then
                ShowStatus("Smooth Motor6D Done!", Color3.fromRGB(150, 100, 255))
            else
                ShowStatus("Smooth Motor6D Failed", Color3.fromRGB(255, 100, 100))
            end
        end)
    else
        ShowStatus("Invalid Coordinates", Color3.fromRGB(255, 200, 100))
    end
end)

CloseButton.MouseButton1Click:Connect(function()
    IsDestroyed = true
    if CharacterConnection then
        CharacterConnection:Disconnect()
    end
    if RagdollConnection then
        RagdollConnection:Disconnect()
    end
    if SpeedConnection then
        SpeedConnection:Disconnect()
    end
    if TrapConnection then
        TrapConnection:Disconnect()
    end
    ScreenGui:Destroy()
end)

print("R6 Motor6D Teleporter loaded - Made by @ash27z")
