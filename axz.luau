local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local head = char:WaitForChild("Head")
local neck = head:WaitForChild("Neck")
local humanoid = char:WaitForChild("Humanoid")

local RemoteEvent = ReplicatedStorage:WaitForChild("HeadPositionEvent")

local isHeadBack = false
local isDragging = false
local dragStartCF = nil
local originalNeckC0 = nil

local hideC0 = CFrame.new(0, 0, -1) * CFrame.Angles(0, math.pi, 0)
local normalC0 = CFrame.new()

local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- 切换开关
local function toggleHead()
    isHeadBack = not isHeadBack
    local target = isHeadBack and hideC0 or normalC0
    RemoteEvent:FireServer(target)
end

-- 电脑按键 H
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == Enum.KeyCode.H then
            toggleHead()
        end
    end
end)

-- 拖动逻辑（电脑+手机通用）
local function startDrag(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and
       input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    isDragging = true
    dragStartCF = neck.C0
    originalNeckC0 = neck.C0
end

local function endDrag(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and
       input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    isDragging = false
    RemoteEvent:FireServer(neck.C0)
end

UserInputService.InputBegan:Connect(startDrag)
UserInputService.InputEnded:Connect(endDrag)

RunService.RenderStepped:Connect(function()
    if not isDragging then return end
    if not char:IsDescendantOf(game) then return end

    local mouseDelta = UserInputService:GetMouseDelta()
    local sensitivity = 0.01

    local dx = mouseDelta.X * sensitivity
    local dy = -mouseDelta.Y * sensitivity

    local newC0 = dragStartCF * CFrame.new(dx, dy, 0)
    neck.C0 = newC0
end)

-- 手机按钮
local screenGui = Instance.new("ScreenGui")
screenGui.Parent = PlayerGui
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local button = Instance.new("TextButton")
button.Name = "HeadToggleButton"
button.Size = UDim2.new(0, 160, 0, 60)
button.Position = UDim2.new(0.8, -80, 0.8, -30)
button.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
button.TextColor3 = Color3.new(1, 1, 1)
button.Text = "藏头/露头 (H)"
button.TextScaled = true
button.Parent = screenGui

button.MouseButton1Click:Connect(toggleHead)
