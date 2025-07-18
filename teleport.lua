if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
repeat task.wait() until Players.LocalPlayer
local Player = Players.LocalPlayer
repeat task.wait() until Player:FindFirstChild("PlayerGui")

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Random = Random.new()

local TpAmount
local VoidPosition = CFrame.new(0, -3.4028234663852886e+38, 0)
local IsTeleporting = false
local IsDestroyed = false

local Character, Humanoid, HumanoidRootPart

local function GetCharacter()
    return Player.Character or Player.CharacterAdded:Wait()
end

local function SetupCharacter()
    Character = GetCharacter()
    Humanoid = Character:WaitForChild("Humanoid")
    HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
    
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

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "EnhancedTeleportGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = Player:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 320, 0, 180)
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
TitleLabel.Text = "Ash's Teleporter || V2"
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 20
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

local SetCurrentButton = CreateButton("Set Current", UDim2.new(0, 15, 0, 90), UDim2.new(0, 140, 0, 30), Color3.fromRGB(60, 60, 60))
local TeleportButton = CreateButton("Teleport", UDim2.new(0, 165, 0, 90), UDim2.new(0, 140, 0, 30), Color3.fromRGB(70, 130, 250))
local SmoothTeleportButton = CreateButton("Smooth Teleport", UDim2.new(0, 15, 0, 130), UDim2.new(0, 140, 0, 30), Color3.fromRGB(130, 70, 250))

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(0, 140, 0, 30)
StatusLabel.Position = UDim2.new(0, 165, 0, 130)
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

task.spawn(function()
    while not IsDestroyed do
        local Ping = Player:GetNetworkPing() * 1000
        TpAmount = math.clamp(math.floor(Ping * 0.8), 10, 150)
        RunService.Heartbeat:Wait()
    end
end)

local function InstantTeleport(Position)
    if not IsTeleporting and not IsDestroyed then
        IsTeleporting = true
        if typeof(Position) == "CFrame" then
            HumanoidRootPart.CFrame = Position + Vector3.new(
                Random:NextNumber(-0.0001, 0.0001),
                Random:NextNumber(-0.0001, 0.0001),
                Random:NextNumber(-0.0001, 0.0001)
            )
            RunService.Heartbeat:Wait()
            IsTeleporting = false
        end
    end
end

local function TeleportToCoordinates(Coordinates)
    if not (Coordinates and #Coordinates == 3) then return false end
    local TargetPosition = Vector3.new(Coordinates[1], Coordinates[2], Coordinates[3])
    local TargetCFrame = CFrame.new(TargetPosition)
    local StableTime = 3
    local StableStart = nil
    local Timeout = 10
    local StartTime = os.clock()

    while not IsDestroyed do
        for i = 1, (TpAmount or 70) do
            InstantTeleport(TargetCFrame)
        end
        for _ = 1, 2 do
            InstantTeleport(VoidPosition)
        end
        for i = 1, math.floor((TpAmount or 70) / 16) do
            InstantTeleport(TargetCFrame)
        end

        local Distance = (HumanoidRootPart.Position - TargetPosition).Magnitude

        if Distance <= 30 then
            if not StableStart then StableStart = os.clock() end
            if os.clock() - StableStart >= StableTime then
                return true
            end
        else
            StableStart = nil
        end

        if os.clock() - StartTime > Timeout then
            return false
        end

        task.wait(0.1)
    end
    return false
end

local function SmoothTeleportToCoordinates(Coordinates)
    if not (Coordinates and #Coordinates == 3) then return false end
    local TargetPosition = Vector3.new(Coordinates[1], Coordinates[2], Coordinates[3])
    local CurrentPosition = HumanoidRootPart.Position
    local Distance = (TargetPosition - CurrentPosition).Magnitude
    local Steps = math.ceil(Distance / 50)
    
    for i = 1, Steps do
        if IsDestroyed then return false end
        local Progress = i / Steps
        local IntermediatePosition = CurrentPosition:lerp(TargetPosition, Progress)
        local IntermediateCFrame = CFrame.new(IntermediatePosition)
        
        for j = 1, math.floor((TpAmount or 70) / 4) do
            InstantTeleport(IntermediateCFrame)
        end
        
        task.wait(0.05)
    end
    
    return TeleportToCoordinates(Coordinates)
end

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
        ShowStatus("Teleporting...", Color3.fromRGB(200, 200, 255))
        task.spawn(function()
            local Success = TeleportToCoordinates({X, Y, Z})
            if Success then
                ShowStatus("Teleport Successful!", Color3.fromRGB(100, 255, 100))
            else
                ShowStatus("Teleport Failed", Color3.fromRGB(255, 100, 100))
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
        ShowStatus("Smooth Teleporting...", Color3.fromRGB(200, 150, 255))
        task.spawn(function()
            local Success = SmoothTeleportToCoordinates({X, Y, Z})
            if Success then
                ShowStatus("Smooth Teleport Done!", Color3.fromRGB(150, 100, 255))
            else
                ShowStatus("Smooth Teleport Failed", Color3.fromRGB(255, 100, 100))
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
    ScreenGui:Destroy()
end)

print("Made by @ash27z")
