-- Luau 语法 | CFrame Desync 全平台适配 | XYZ输入+快捷控制+位置监控
-- 服务依赖 & 类型注解
local RunService: RunService = game:GetService("RunService")
local Players: Players = game:GetService("Players")
local UserInputService: UserInputService = game:GetService("UserInputService")
local TweenService: TweenService = game:GetService("TweenService")

-- 设备判定 & 全局配置 (Mobile/PC 双端适配)
local isMobile: boolean = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local CONFIG = {
    UI_SCALE = isMobile and 1.5 or 1.0,    -- 移动端UI放大
    STEP_SIZE = 1,                        -- XYZ快捷按钮步长（每次±1，可自定义）
    SMOOTH_SPEED = isMobile and 5 or 6,   -- 平滑偏移速度
    POS_REFRESH = 1,                      -- 位置刷新频率(秒)
    HOTKEY = Enum.KeyCode.D,              -- PC快捷键(Ctrl+D)
    PANEL_W = isMobile and 320 or 310,    -- 面板宽度
    PANEL_H = isMobile and 360 or 350,    -- 面板高度
}

-- 玩家/角色核心变量
local player: Player = Players.LocalPlayer
local character: Model = player.Character or player.CharacterAdded:Wait()
local rootPart: BasePart = character:WaitForChild("HumanoidRootPart") :: BasePart
local humanoid: Humanoid = character:WaitForChild("Humanoid") :: Humanoid

-- Desync 核心状态
local desyncState = {
    Enabled = false,
    Offsets = {X = 0, Y = 0, Z = 0},
    dragging = false,
    touchId = nil,
    lastPosRefresh = 0,
    tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad)
}

-- 渲染部件缓存
local renderParts: {BasePart} = {}
local partOriginalOffsets: {[BasePart]: CFrame} = {}

-- ======================================
-- 1. GUI创建 | XYZ输入框+快捷按钮+位置显示
-- ======================================
local screenGui: ScreenGui = Instance.new("ScreenGui")
screenGui.Name = "DesyncController_XYZ"
screenGui.Parent = player.PlayerGui

-- 全局UI缩放（移动端核心适配）
local uiScale: UIScale = Instance.new("UIScale")
uiScale.Scale = CONFIG.UI_SCALE
uiScale.Parent = screenGui

-- 主面板
local mainFrame: Frame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, CONFIG.PANEL_W, 0, CONFIG.PANEL_H)
mainFrame.Position = UDim2.new(0, isMobile and 20 or 80, 0, isMobile and 60 or 80)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
mainFrame.BackgroundTransparency = 0.05
mainFrame.BorderColor3 = Color3.fromRGB(0, 210, 255)
mainFrame.BorderSizePixel = 2
mainFrame.Active = true
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

-- 圆角装饰
local mainCorner: UICorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = mainFrame

-- 标题栏（拖动区域）
local titleBar: Frame = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, isMobile and 48 or 38)
titleBar.BackgroundColor3 = Color3.fromRGB(0, 210, 255)
titleBar.Parent = mainFrame

local titleText: TextLabel = Instance.new("TextLabel")
titleText.Size = UDim2.new(0.8, 0, 1, 0)
titleText.Position = UDim2.new(0, 10, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "Desync XYZ控制器 | 双端适配"
titleText.TextColor3 = Color3.new(1,1,1)
titleText.TextScaled = true
titleText.Font = Enum.Font.SourceSansBold
titleText.Parent = titleBar

-- 运行状态
local statusText: TextLabel = Instance.new("TextLabel")
statusText.Size = UDim2.new(0.2, 0, 1, 0)
statusText.Position = UDim2.new(0.8, 0, 0, 0)
statusText.BackgroundTransparency = 1
statusText.Text = "关闭"
statusText.TextColor3 = Color3.fromRGB(255, 60, 60)
statusText.TextScaled = true
statusText.Font = Enum.Font.SourceSansBold
statusText.Parent = titleBar

-- 一键启停按钮
local toggleBtn: TextButton = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0.9, 0, 0, isMobile and 48 or 38)
toggleBtn.Position = UDim2.new(0.05, 0, 0, isMobile and 55 or 45)
toggleBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
toggleBtn.Text = isMobile and "开启Desync" or "开启Desync [Ctrl+D]"
toggleBtn.TextColor3 = Color3.new(1,1,1)
toggleBtn.TextScaled = true
toggleBtn.Font = Enum.Font.SourceSansBold
toggleBtn.Parent = mainFrame
local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 8)
btnCorner.Parent = toggleBtn

-- 位置显示标题
local posTitle: TextLabel = Instance.new("TextLabel")
posTitle.Size = UDim2.new(0.9, 0, 0, isMobile and 30 or 25)
posTitle.Position = UDim2.new(0.05, 0, 0, isMobile and 110 or 90)
posTitle.BackgroundTransparency = 1
posTitle.Text = "位置监控 [服务端/本地]"
posTitle.TextColor3 = Color3.fromRGB(0, 210, 255)
posTitle.TextScaled = true
posTitle.Font = Enum.Font.SourceSansBold
posTitle.Parent = mainFrame

-- 服务端真实位置
local serverPosText: TextLabel = Instance.new("TextLabel")
serverPosText.Size = UDim2.new(0.9, 0, 0, isMobile and 28 or 24)
serverPosText.Position = UDim2.new(0.05, 0, 0, isMobile and 145 or 120)
serverPosText.BackgroundTransparency = 1
serverPosText.Text = "服务端：X=0.0 Y=0.0 Z=0.0"
serverPosText.TextColor3 = Color3.new(1,1,1)
serverPosText.TextScaled = true
serverPosText.Font = Enum.Font.SourceSans
serverPosText.Parent = mainFrame

-- 本地Desync位置
local localPosText: TextLabel = Instance.new("TextLabel")
localPosText.Size = UDim2.new(0.9, 0, 0, isMobile and 28 or 24)
localPosText.Position = UDim2.new(0.05, 0, 0, isMobile and 178 or 148)
localPosText.BackgroundTransparency = 1
localPosText.Text = "本地：X=0.0 Y=0.0 Z=0.0"
localPosText.TextColor3 = Color3.fromRGB(0, 210, 255)
localPosText.TextScaled = true
localPosText.Font = Enum.Font.SourceSans
localPosText.Parent = mainFrame

-- XYZ控制标题
local xyzTitle: TextLabel = Instance.new("TextLabel")
xyzTitle.Size = UDim2.new(0.9, 0, 0, isMobile and 30 or 25)
xyzTitle.Position = UDim2.new(0.05, 0, 0, isMobile and 215 or 180)
xyzTitle.BackgroundTransparency = 1
xyzTitle.Text = "XYZ偏移调节 [步长:"..CONFIG.STEP_SIZE.."]"
xyzTitle.TextColor3 = Color3.fromRGB(0, 210, 255)
xyzTitle.TextScaled = true
xyzTitle.Font = Enum.Font.SourceSansBold
xyzTitle.Parent = mainFrame

-- ======================================
-- 通用函数：创建XYZ轴控制组（输入框+±按钮）
-- ======================================
local function createXYZControl(axis: string, posY: number): TextBox
    -- 轴标签
    local label: TextLabel = Instance.new("TextLabel")
    label.Size = UDim2.new(0.2, 0, 0, isMobile and 35 or 30)
    label.Position = UDim2.new(0.05, 0, 0, posY)
    label.BackgroundTransparency = 1
    label.Text = axis..":"
    label.TextColor3 = Color3.new(1,1,1)
    label.TextScaled = true
    label.Font = Enum.Font.SourceSansBold
    label.Parent = mainFrame

    -- 减号按钮
    local minusBtn: TextButton = Instance.new("TextButton")
    minusBtn.Size = UDim2.new(0.12, 0, 0, isMobile and 35 or 30)
    minusBtn.Position = UDim2.new(0.28, 0, 0, posY)
    minusBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    minusBtn.Text = "-"
    minusBtn.TextColor3 = Color3.new(1,1,1)
    minusBtn.TextScaled = true
    minusBtn.Font = Enum.Font.SourceSansBold
    minusBtn.Parent = mainFrame
    local mCorner = Instance.new("UICorner")
    mCorner.CornerRadius = UDim.new(0, 6)
    mCorner.Parent = minusBtn

    -- 输入框
    local input: TextBox = Instance.new("TextBox")
    input.Size = UDim2.new(0.28, 0, 0, isMobile and 35 or 30)
    input.Position = UDim2.new(0.43, 0, 0, posY)
    input.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    input.BorderColor3 = Color3.fromRGB(0, 210, 255)
    input.Text = "0"
    input.TextColor3 = Color3.new(1,1,1)
    input.TextScaled = true
    input.ClearTextOnFocus = false
    input.Parent = mainFrame
    local iCorner = Instance.new("UICorner")
    iCorner.CornerRadius = UDim.new(0, 6)
    iCorner.Parent = input

    -- 加号按钮
    local plusBtn: TextButton = Instance.new("TextButton")
    plusBtn.Size = UDim2.new(0.12, 0, 0, isMobile and 35 or 30)
    plusBtn.Position = UDim2.new(0.74, 0, 0, posY)
    plusBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    plusBtn.Text = "+"
    plusBtn.TextColor3 = Color3.new(1,1,1)
    plusBtn.TextScaled = true
    plusBtn.Font = Enum.Font.SourceSansBold
    plusBtn.Parent = mainFrame
    local pCorner = Instance.new("UICorner")
    pCorner.CornerRadius = UDim.new(0, 6)
    pCorner.Parent = plusBtn

    -- 按钮事件：±步长
    minusBtn.MouseButton1Click:Connect(function()
        desyncState.Offsets[axis] -= CONFIG.STEP_SIZE
        input.Text = tostring(desyncState.Offsets[axis])
    end)
    plusBtn.MouseButton1Click:Connect(function()
        desyncState.Offsets[axis] += CONFIG.STEP_SIZE
        input.Text = tostring(desyncState.Offsets[axis])
    end)

    -- 输入框事件：实时生效，数字校验
    input.Changed:Connect(function(prop)
        if prop == "Text" then
            local num: number = tonumber(input.Text) or 0
            desyncState.Offsets[axis] = num
            input.Text = tostring(num)
        end
    end)

    -- 触摸高亮（移动端适配）
    local function btnHover(btn: TextButton)
        btn.MouseEnter:Connect(function() TweenService:Create(btn, desyncState.tweenInfo, {BackgroundColor3 = Color3.fromRGB(80,80,80)}):Play() end)
        btn.MouseLeave:Connect(function() TweenService:Create(btn, desyncState.tweenInfo, {BackgroundColor3 = Color3.fromRGB(60,60,60)}):Play() end)
    end
    btnHover(minusBtn)
    btnHover(plusBtn)

    return input
end

-- 创建X/Y/Z控制组
local xInput = createXYZControl("X", isMobile and 250 or 210)
local yInput = createXYZControl("Y", isMobile and 290 or 245)
local zInput = createXYZControl("Z", isMobile and 330 or 280)

-- ======================================
-- 2. 核心功能函数
-- ======================================
-- 初始化渲染部件，缓存原始偏移
local function initRenderParts(char: Model)
    renderParts = {}
    partOriginalOffsets = {}
    rootPart = char:WaitForChild("HumanoidRootPart") :: BasePart
    humanoid = char:WaitForChild("Humanoid") :: Humanoid
    for _, part: Instance in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part ~= rootPart and part:IsDescendantOf(char) then
            table.insert(renderParts, part :: BasePart)
            partOriginalOffsets[part :: BasePart] = rootPart.CFrame:ToObjectSpace(part.CFrame)
        end
    end
end
initRenderParts(character)

-- 刷新位置显示
local function refreshPosDisplay(dt: number)
    desyncState.lastPosRefresh += dt
    if desyncState.lastPosRefresh >= CONFIG.POS_REFRESH and rootPart then
        local serverPos: Vector3 = rootPart.Position
        -- 服务端位置
        serverPosText.Text = string.format("服务端：X=%.1f Y=%.1f Z=%.1f", serverPos.X, serverPos.Y, serverPos.Z)
        -- 本地Desync位置
        local localPos: Vector3 = serverPos + Vector3.new(desyncState.Offsets.X, desyncState.Offsets.Y, desyncState.Offsets.Z)
        localPosText.Text = string.format("本地：X=%.1f Y=%.1f Z=%.1f", localPos.X, localPos.Y, localPos.Z)
        desyncState.lastPosRefresh = 0
    end
end

-- Desync核心更新：平滑偏移
local function updateDesync(dt: number)
    if not desyncState.Enabled or humanoid.Health <= 0 or not rootPart then return end
    refreshPosDisplay(dt)
    -- 实时补全新部件
    if #renderParts ~= #character:GetDescendants() then initRenderParts(character) end
    -- 计算偏移CFrame
    local offsetCF: CFrame = CFrame.new(desyncState.Offsets.X, desyncState.Offsets.Y, desyncState.Offsets.Z)
    -- 平滑更新部件
    for _, part: BasePart in ipairs(renderParts) do
        if part and part:IsDescendantOf(character) then
            local originalOffset: CFrame = partOriginalOffsets[part] or rootPart.CFrame:ToObjectSpace(part.CFrame)
            local targetCF: CFrame = rootPart.CFrame * offsetCF * originalOffset
            part.CFrame = part.CFrame:Lerp(targetCF, dt * CONFIG.SMOOTH_SPEED)
        end
    end
end

-- 切换Desync状态
local function toggleDesync()
    desyncState.Enabled = not desyncState.Enabled
    if desyncState.Enabled then
        -- 开启
        toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 220, 60)
        toggleBtn.Text = isMobile and "关闭Desync" or "关闭Desync [Ctrl+D]"
        statusText.Text = "开启"
        statusText.TextColor3 = Color3.fromRGB(60, 220, 60)
    else
        -- 关闭：恢复原始位置
        toggleBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
        toggleBtn.Text = isMobile and "开启Desync" or "开启Desync [Ctrl+D]"
        statusText.Text = "关闭"
        statusText.TextColor3 = Color3.fromRGB(255, 60, 60)
        for _, part: BasePart in ipairs(renderParts) do
            if part and partOriginalOffsets[part] and rootPart then
                part.CFrame = rootPart.CFrame * partOriginalOffsets[part]
            end
        end
    end
end

-- ======================================
-- 3. 交互事件 | 双端适配（触摸/鼠标/快捷键）
-- ======================================
-- 启停按钮事件
toggleBtn.MouseButton1Click:Connect(toggleDesync)
toggleBtn.MouseEnter:Connect(function() TweenService:Create(toggleBtn, desyncState.tweenInfo, {BackgroundTransparency = 0.1}):Play() end)
toggleBtn.MouseLeave:Connect(function() TweenService:Create(toggleBtn, desyncState.tweenInfo, {BackgroundTransparency = 0}):Play() end)

-- PC快捷键：Ctrl+D
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
    if not gameProcessed and input.KeyCode == CONFIG.HOTKEY then
        local ctrlDown: boolean = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
        if ctrlDown then toggleDesync() end
    end
end)

-- 面板拖动：鼠标+触摸（双端）
local function startDrag(inputPos: Vector2)
    desyncState.dragging = true
    local guiPos: UDim2 = mainFrame.Position
    desyncState.dragStart = inputPos
    desyncState.guiStart = guiPos
end
local function doDrag(inputPos: Vector2)
    if desyncState.dragging and desyncState.dragStart and desyncState.guiStart then
        local delta: Vector2 = inputPos - desyncState.dragStart
        mainFrame.Position = UDim2.new(
            desyncState.guiStart.X.Scale, desyncState.guiStart.X.Offset + delta.X,
            desyncState.guiStart.Y.Scale, desyncState.guiStart.Y.Offset + delta.Y
        )
    end
end
local function endDrag()
    desyncState.dragging = false
    desyncState.touchId = nil
end

-- 鼠标拖动
titleBar.InputBegan:Connect(function(input: InputObject)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then startDrag(input.Position) end
end)
UserInputService.InputChanged:Connect(function(input: InputObject)
    if input.UserInputType == Enum.UserInputType.MouseMovement then doDrag(input.Position) end
end)
UserInputService.InputEnded:Connect(function(input: InputObject)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then endDrag() end
end)

-- 移动端触摸拖动
UserInputService.TouchStarted:Connect(function(touch: InputObject, gameProcessed: boolean)
    if not gameProcessed and not desyncState.touchId and titleBar:IsAncestorOf(touch.Target) then
        desyncState.touchId = touch.TouchId
        startDrag(touch.Position)
    end
end)
UserInputService.TouchMoved:Connect(function(touch: InputObject, gameProcessed: boolean)
    if not gameProcessed and touch.TouchId == desyncState.touchId then
        doDrag(touch.Position)
    end
end)
UserInputService.TouchEnded:Connect(function(touch: InputObject)
    if touch.TouchId == desyncState.touchId then endDrag() end
end)

-- ======================================
-- 4. 实时更新 + 角色重生绑定
-- ======================================
-- Heartbeat驱动（抗检测，双端性能适配）
RunService.Heartbeat:Connect(updateDesync)

-- 角色重生：保留状态，无缝衔接
player.CharacterAdded:Connect(function(newChar: Model)
    character = newChar
    newChar:WaitForChild("HumanoidRootPart")
    newChar:WaitForChild("Humanoid")
    initRenderParts(newChar)
    -- 重生后保持开启状态
    if desyncState.Enabled then
        statusText.Text = "开启"
        statusText.TextColor3 = Color3.fromRGB(60, 220, 60)
    end
end)
