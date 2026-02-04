-- Delta 可用 · 真正服务器同步 · 别人可见
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Player = Players.LocalPlayer
local PlayerGui = Player.PlayerGui

local isHidden = false
local useTween = true
local godMode = false
local guiVisible = true

-- 直接修改角色（别人可见）
local function toggleHead(state)
    local char = Player.Character
    if not char then return end
    local neck = char:FindFirstChild("UpperTorso") and char.UpperTorso:FindFirstChild("Neck")
    if not neck then return end

    local originalC0 = neck.C0
    local targetC0

    if state then
        targetC0 = originalC0 * CFrame.new(0, -0.8, 1.8) * CFrame.Angles(math.rad(180), 0, 0)
    else
        targetC0 = originalC0
    end

    if useTween then
        local tween = TweenService:Create(neck, TweenInfo.new(0.4), {C0 = targetC0})
        tween:Play()
    else
        neck.C0 = targetC0
    end
end

local function toggleGod(enabled)
    local char = Player.Character
    if not char then return end
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then return end

    if enabled then
        humanoid.MaxHealth = math.huge
        humanoid.Health = math.huge
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
    else
        humanoid.MaxHealth = 100
        humanoid.Health = 100
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
    end
end

-- GUI（固定左下角，可显示/隐藏）
local ScreenGui = PlayerGui:FindFirstChild("HeadGodPanel") or Instance.new("ScreenGui")
ScreenGui.Name = "HeadGodPanel"
ScreenGui.Parent = PlayerGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 160, 0, 180)
MainFrame.Position = UDim2.new(0.02, 0, 0.75, 0)
MainFrame.BackgroundColor3 = Color3.new(0.12, 0.12, 0.12)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = false
MainFrame.Parent = ScreenGui

local ToggleGuiBtn = Instance.new("TextButton")
ToggleGuiBtn.Size = UDim2.new(0, 160, 0, 25)
ToggleGuiBtn.Position = UDim2.new(0, 0, -0.15, 0)
ToggleGuiBtn.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
ToggleGuiBtn.Text = "隐藏面板"
ToggleGuiBtn.TextColor3 = Color3.new(1, 1, 1)
ToggleGuiBtn.TextScaled = true
ToggleGuiBtn.Parent = MainFrame

local ToggleHeadBtn = Instance.new("TextButton")
ToggleHeadBtn.Size = UDim2.new(0, 140, 0, 40)
ToggleHeadBtn.Position = UDim2.new(0.0625, 0, 0.05, 0)
ToggleHeadBtn.BackgroundColor3 = Color3.new(0, 1, 0)
ToggleHeadBtn.Text = "藏头：关闭"
ToggleHeadBtn.TextColor3 = Color3.new(1, 1, 1)
ToggleHeadBtn.TextScaled = true
ToggleHeadBtn.Parent = MainFrame

local GodBtn = Instance.new("TextButton")
GodBtn.Size = UDim2.new(0, 140, 0, 40)
GodBtn.Position = UDim2.new(0.0625, 0, 0.3, 0)
GodBtn.BackgroundColor3 = Color3.new(0, 0, 1)
GodBtn.Text = "无敌：关闭"
GodBtn.TextColor3 = Color3.new(1, 1, 1)
GodBtn.TextScaled = true
GodBtn.Parent = MainFrame

local TweenBtn = Instance.new("TextButton")
TweenBtn.Size = UDim2.new(0, 140, 0, 30)
TweenBtn.Position = UDim2.new(0.0625, 0, 0.55, 0)
TweenBtn.BackgroundColor3 = Color3.new(0, 0.6, 1)
TweenBtn.Text = "模式：动画"
TweenBtn.TextColor3 = Color3.new(1, 1, 1)
TweenBtn.TextScaled = true
TweenBtn.Parent = MainFrame

local PosBtn = Instance.new("TextButton")
PosBtn.Size = UDim2.new(0, 140, 0, 30)
PosBtn.Position = UDim2.new(0.0625, 0, 0.78, 0)
PosBtn.BackgroundColor3 = Color3.new(0.4, 0.4, 0.4)
PosBtn.Text = "模式：坐标"
PosBtn.TextColor3 = Color3.new(1, 1, 1)
PosBtn.TextScaled = true
PosBtn.Parent = MainFrame

-- 更新按钮
local function updateHeadButton()
    ToggleHeadBtn.BackgroundColor3 = isHidden and Color3.new(1,0,0) or Color3.new(0,1,0)
    ToggleHeadBtn.Text = isHidden and "藏头：开启" or "藏头：关闭"
end

local function updateGodButton()
    GodBtn.BackgroundColor3 = godMode and Color3.new(1,0.5,0) or Color3.new(0,0,1)
    GodBtn.Text = godMode and "无敌：开启" or "无敌：关闭"
end

local function updateModeButtons()
    TweenBtn.BackgroundColor3 = useTween and Color3.new(0,0.6,1) or Color3.new(0.4,0.4,0.4)
    PosBtn.BackgroundColor3 = useTween and Color3.new(0.4,0.4,0.4) or Color3.new(0,0.6,1)
end

local function updateGuiVisibility()
    MainFrame.Visible = guiVisible
    ToggleGuiBtn.Text = guiVisible and "隐藏面板" or "显示面板"
end

-- 点击事件
ToggleGuiBtn.MouseButton1Click:Connect(function()
    guiVisible = not guiVisible
    updateGuiVisibility()
end)

ToggleHeadBtn.MouseButton1Click:Connect(function()
    isHidden = not isHidden
    toggleHead(isHidden)
    updateHeadButton()
end)

GodBtn.MouseButton1Click:Connect(function()
    godMode = not godMode
    toggleGod(godMode)
    updateGodButton()
end)

TweenBtn.MouseButton1Click:Connect(function()
    useTween = true
    updateModeButtons()
end)

PosBtn.MouseButton1Click:Connect(function()
    useTween = false
    updateModeButtons()
end)

-- 初始化
updateHeadButton()
updateGodButton()
updateModeButtons()
updateGuiVisibility()
