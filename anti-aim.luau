-- Roblox Anti-Aim 小尺寸双页GUI版 (Luau)
-- 核心更新：SpinBot速度拉满【0~80】+ 动画藏头+双页切换+全Anti-Aim功能
-- 小尺寸适配手机/PC小窗 | 仅作编程学习，实战风险自担
local Players: Players = game:GetService("Players")
local RunService: RunService = game:GetService("RunService")
local UserInputService: UserInputService = game:GetService("UserInputService")
local TweenService: TweenService = game:GetService("TweenService")

-- 核心全局变量（Luau强类型注解）
local localPlayer: Player = Players.LocalPlayer
local playerGui: PlayerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
local isMobile: boolean = UserInputService.TouchEnabled
local UIScaleVal: number = if isMobile then 1.1 else 1 -- 小GUI适配放大
local renderStep: RBXScriptSignal = RunService.RenderStepped
local rng: Random = Random.new(tick())
local tweenInfo: TweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local headTween: Tween? = nil -- 藏头动画实例

-- 角色核心对象（重生自动绑定，防失效）
local character: Model? = nil
local humanoid: Humanoid? = nil
local rootPart: BasePart? = nil
local head: BasePart? = nil
local originalHeadCFrame: CFrame? = nil -- 头部原始位置
local targetHeadCFrame: CFrame? = nil -- 藏头目标位置

-- 角色绑定函数
local function bindCharacter(newChar: Model)
    character = newChar
    humanoid = newChar:WaitForChild("Humanoid") :: Humanoid
    rootPart = newChar:WaitForChild("HumanoidRootPart") :: BasePart
    head = newChar:WaitForChild("Head") :: BasePart
    originalHeadCFrame = head.CFrame
    targetHeadCFrame = originalHeadCFrame
    -- 角色死亡清空对象+取消动画
    humanoid.Died:Connect(function()
        rootPart = nil; head = nil; originalHeadCFrame = nil; targetHeadCFrame = nil
        if headTween then headTween:Cancel(); headTween = nil end
    end)
end
if localPlayer.Character then bindCharacter(localPlayer.Character :: Model) end
localPlayer.CharacterAdded:Connect(bindCharacter)

-- Anti-Aim 核心配置【★SpinBot速度改为80（默认+上限）】
local AntiAim = {
    Enabled = false, HeadHide = false, RandomAim = false, AngleMode = false,
    SpinBot = false, Randomize = true, YawOffset = 90.0, PitchOffset = 0.0,
    RandomRange = 90.0, RandomAimSpeed = 0.3, SpinSpeed = 80.0, -- ★SpinBot默认80
    AngleSwitchSpeed = 0.15, CurAngleMode = 3, SpinAngle = 0.0,
    AngleIndex = 1, AngleTick = 0.0, RandomAimTick = 0.0,
    RandomAimYaw = 0.0, RandomAimPitch = 0.0,
    -- 3/5角度预设（抬头→低头往复）
    Angle3 = {60.0, 0.0, -60.0}, Angle5 = {80.0, 40.0, 0.0, -40.0, -80.0}
} :: {
    Enabled: boolean, HeadHide: boolean, RandomAim: boolean, AngleMode: boolean,
    SpinBot: boolean, Randomize: boolean, YawOffset: number, PitchOffset: number,
    RandomRange: number, RandomAimSpeed: number, SpinSpeed: number,
    AngleSwitchSpeed: number, CurAngleMode: number, SpinAngle: number,
    AngleIndex: number, AngleTick: number, RandomAimTick: number,
    RandomAimYaw: number, RandomAimPitch: number,
    Angle3: {number}, Angle5: {number}
}

-- 工具函数（轻量化）
local function deg2rad(deg: number): number return deg * math.pi / 180 end
local function clamp(num: number, min: number, max: number): number return math.max(min, math.min(max, num)) end
local function numFormat(num: number): number return tonumber(string.format("%.1f", num)) or 0.0 end
local function mapValue(num: number, inMin: number, inMax: number, outMin: number, outMax: number): number
    return (num - inMin) * (outMax - outMin) / (inMax - inMin) + outMin
end
local function getRandomAngle(min: number, max: number): number return numFormat(rng:NextNumber(min, max)) end

-- 藏头动画核心函数（平滑过渡，无瞬移）
local function playHeadTween(targetCFrame: CFrame)
    if not head or not originalHeadCFrame then return end
    if headTween then headTween:Cancel(); headTween = nil end
    headTween = TweenService:Create(head, tweenInfo, {CFrame = targetCFrame})
    headTween:Play()
    headTween.Completed:Connect(function() headTween = nil end)
end

-- ===================== 小尺寸双页紫色GUI（核心功能+藏头定制）=====================
local ScreenGui: ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AntiAim_SmallGUI_Spin80"
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = playerGui

-- 主窗口【小尺寸核心】：适配手机/PC小窗
local MainFrame: Frame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, isMobile and 280 or 260, 0, isMobile and 480 or 450)
MainFrame.Position = UDim2.new(0, isMobile and 15 or 15, 0, isMobile and 15 or 15)
MainFrame.BackgroundColor3 = Color3.fromRGB(90, 20, 130)
MainFrame.BackgroundTransparency = 0.1
MainFrame.BorderColor3 = Color3.fromRGB(200, 120, 255)
MainFrame.BorderSizePixel = 1
MainFrame.ClipsDescendants = true
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

-- 移动端小比例放大
local UIScale: UIScale = Instance.new("UIScale")
UIScale.Scale = UIScaleVal
UIScale.Parent = MainFrame

-- 标题栏+页切按钮【小尺寸适配】
local TitleBar: Frame = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 30)
TitleBar.BackgroundColor3 = Color3.fromRGB(150, 50, 220)
TitleBar.Parent = MainFrame

local Title: TextLabel = Instance.new("TextLabel")
Title.Size = UDim2.new(0.55, 0, 1, 0)
Title.Position = UDim2.new(0.02, 0, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Anti-Aim | Spin80"
Title.TextColor3 = Color3.new(1,1,1)
Title.Font = Enum.Font.GothamBold
Title.TextScaled = true
Title.Parent = TitleBar

-- 页切按钮（功能/藏头）
local Page1Btn: TextButton = Instance.new("TextButton")
Page1Btn.Size = UDim2.new(0.2, 0, 0.7, 0)
Page1Btn.Position = UDim2.new(0.6, 0, 0.15, 0)
Page1Btn.BackgroundColor3 = Color3.fromRGB(60, 220, 60)
Page1Btn.Text = "功能"
Page1Btn.TextColor3 = Color3.new(1,1,1)
Page1Btn.Font = Enum.Font.GothamBold
Page1Btn.TextScaled = true
Page1Btn.Parent = TitleBar
Instance.new("UICorner", Page1Btn).CornerRadius = UDim.new(0.3, 0)

local Page2Btn: TextButton = Instance.new("TextButton")
Page2Btn.Size = UDim2.new(0.2, 0, 0.7, 0)
Page2Btn.Position = UDim2.new(0.82, 0, 0.15, 0)
Page2Btn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
Page2Btn.Text = "藏头"
Page2Btn.TextColor3 = Color3.new(1,1,1)
Page2Btn.Font = Enum.Font.GothamBold
Page2Btn.TextScaled = true
Page2Btn.Parent = TitleBar
Instance.new("UICorner", Page2Btn).CornerRadius = UDim.new(0.3, 0)

-- 双页容器
local PageContainer: Frame = Instance.new("Frame")
PageContainer.Size = UDim2.new(1, 0, 1, -30)
PageContainer.Position = UDim2.new(0, 0, 0, 30)
PageContainer.BackgroundTransparency = 1
PageContainer.ClipsDescendants = true
PageContainer.Parent = MainFrame

local Page1: Frame = Instance.new("Frame") -- 功能页（核心控制）
Page1.Size = UDim2.new(1, 0, 1, 0)
Page1.Position = UDim2.new(0, 0, 0, 0)
Page1.BackgroundTransparency = 1
Page1.Parent = PageContainer

local Page2: Frame = Instance.new("Frame") -- 藏头页（定制定位）
Page2.Size = UDim2.new(1, 0, 1, 0)
Page2.Position = UDim2.new(1, 0, 0, 0)
Page2.BackgroundTransparency = 1
Page2.Parent = PageContainer

-- 页面切换逻辑
local function switchPage(toPage: Frame)
    Page1.Position = UDim2.new(1, 0, 0, 0)
    Page2.Position = UDim2.new(1, 0, 0, 0)
    toPage.Position = UDim2.new(0, 0, 0, 0)
    -- 按钮样式同步
    Page1Btn.BackgroundColor3 = toPage == Page1 and Color3.fromRGB(60, 220, 60) or Color3.fromRGB(220, 60, 60)
    Page2Btn.BackgroundColor3 = toPage == Page2 and Color3.fromRGB(60, 220, 60) or Color3.fromRGB(220, 60, 60)
end
Page1Btn.MouseButton1Click:Connect(function() switchPage(Page1) end)
Page2Btn.MouseButton1Click:Connect(function() switchPage(Page2) end)
switchPage(Page1) -- 默认显示功能页

-- ============== 通用GUI创建函数（小尺寸适配） ==============
-- 创建小尺寸开关按钮
local function createToggleButton(parent: GuiObject, posY: number, textOff: string, textOn: string, key: string): TextButton
    local btn: TextButton = Instance.new("TextButton")
    btn.Size = UDim2.new(0.95, 0, 0, 28)
    btn.Position = UDim2.new(0.025, 0, 0, posY)
    btn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
    btn.Text = textOff
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.Gotham
    btn.TextScaled = true
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0.2, 0)
    -- 按钮切换逻辑
    btn.MouseButton1Click:Connect(function()
        local isOn = btn.BackgroundColor3 == Color3.fromRGB(60, 220, 60)
        btn.BackgroundColor3 = isOn and Color3.fromRGB(220, 60, 60) or Color3.fromRGB(60, 220, 60)
        btn.Text = isOn and textOff or textOn
        AntiAim[key] = not isOn
        -- 藏头开关：触发平滑动画
        if key == "HeadHide" and head and targetHeadCFrame and originalHeadCFrame then
            playHeadTween(AntiAim.HeadHide and targetHeadCFrame or originalHeadCFrame)
        end
        -- 3/5角度模式切换
        if key == "CurAngleMode" then
            AntiAim.CurAngleMode = AntiAim.CurAngleMode == 3 and 5 or 3
            btn.Text = AntiAim.CurAngleMode == 3 and "3角度" or "5角度"
        end
    end)
    return btn
end

-- 创建小尺寸标签
local function createLabel(parent: GuiObject, posY: number, text: string): TextLabel
    local label: TextLabel = Instance.new("TextLabel")
    label.Size = UDim2.new(0.95, 0, 0, 16)
    label.Position = UDim2.new(0.025, 0, 0, posY)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.Font = Enum.Font.Gotham
    label.TextSize = isMobile and 10 or 9
    label.Parent = parent
    return label
end

-- 创建小尺寸滑条+输入框容器
local function createSliderInputContainer(parent: GuiObject, posY: number): Frame
    local container: Frame = Instance.new("Frame")
    container.Size = UDim2.new(0.95, 0, 0, 30)
    container.Position = UDim2.new(0.025, 0, 0, posY)
    container.BackgroundTransparency = 1
    container.Parent = parent
    return container
end

-- 创建小尺寸滑条
local function createSlider(parent: GuiObject, posX: number, min: number, max: number, default: number): Frame
    local slider: Frame = Instance.new("Frame")
    slider.Size = UDim2.new(0.6, 0, 0, 10)
    slider.Position = UDim2.new(posX, 0, 0.5, -5)
    slider.BackgroundColor3 = Color3.fromRGB(70, 15, 100)
    slider.BorderColor3 = Color3.fromRGB(200, 120, 255)
    slider.Parent = parent
    Instance.new("UICorner", slider).CornerRadius = UDim.new(0.5, 0)

    local handle: Frame = Instance.new("Frame")
    handle.Size = UDim2.new(0, 15, 0, 15)
    handle.Position = UDim2.new(mapValue(default, min, max, 0, 100)/100, -7.5, 0.5, -7.5)
    handle.BackgroundColor3 = Color3.fromRGB(150, 50, 220)
    handle.BorderSizePixel = 0
    handle.Parent = slider
    Instance.new("UICorner", handle).CornerRadius = UDim.new(1, 0)

    slider:SetAttribute("Min", min)
    slider:SetAttribute("Max", max)
    slider:SetAttribute("Value", default)
    return slider
end

-- 创建小尺寸输入框
local function createInputBox(parent: GuiObject, posX: number, default: number): TextBox
    local input: TextBox = Instance.new("TextBox")
    input.Size = UDim2.new(0.28, 0, 0, 20)
    input.Position = UDim2.new(posX, 0, 0.5, -10)
    input.BackgroundColor3 = Color3.fromRGB(70, 15, 100)
    input.BorderColor3 = Color3.fromRGB(200, 120, 255)
    input.Text = tostring(default)
    input.TextColor3 = Color3.new(1,1,1)
    input.Font = Enum.Font.Gotham
    input.TextSize = isMobile and 9 or 8
    input.ClearTextOnFocus = false
    input.Parent = parent
    Instance.new("UICorner", input).CornerRadius = UDim.new(0.2, 0)
    return input
end

-- 滑条+输入框双向联动（实时同步参数）
local function syncSliderInput(slider: Frame, input: TextBox, min: number, max: number, key: string)
    local function updateFromSlider()
        local val: number = mapValue(slider.AbsolutePosition.X - slider.Parent.AbsolutePosition.X, 0, slider.AbsoluteSize.X, min, max)
        val = clamp(numFormat(val), min, max)
        slider:SetAttribute("Value", val)
        input.Text = tostring(val)
        AntiAim[key] = val
    end
    -- 滑条拖动更新
    slider.InputBegan:Connect(function(inputObj)
        if inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch then
            inputObj.Changed:Connect(function()
                if inputObj.UserInputState == Enum.UserInputState.End then return end
                updateFromSlider()
            end)
        end
    end)
    -- 输入框填写更新
    input.FocusLost:Connect(function()
        local val: number = clamp(numFormat(tonumber(input.Text) or 0), min, max)
        input.Text = tostring(val)
        slider:SetAttribute("Value", val)
        slider.Handle.Position = UDim2.new(mapValue(val, min, max, 0, 100)/100, -7.5, 0.5, -7.5)
        AntiAim[key] = val
    end)
end

-- ============== 第一页：核心功能页（★SpinBot速度0~80） ==============
-- 开关按钮（紧凑排列）
createToggleButton(Page1, 10, "总开关 | 关", "总开关 | 开", "Enabled")
createToggleButton(Page1, 45, "随机转向 | 关", "随机转向 | 开", "RandomAim")
createToggleButton(Page1, 80, "3/5角度 | 关", "3/5角度 | 开", "AngleMode")
local AngleSwitchBtn = createToggleButton(Page1, 115, "3角度", "5角度", "CurAngleMode")
createToggleButton(Page1, 150, "SpinBot | 关", "SpinBot | 开", "SpinBot")
createToggleButton(Page1, 185, "基础随机 | 关", "基础随机 | 开", "Randomize")
createToggleButton(Page1, 220, "藏头功能 | 关", "藏头功能 | 开", "HeadHide")

-- 数值调节区【★SpinBot速度改为0~80】
createLabel(Page1, 255, "随机切换速度 [0.1~2]")
local randomAimSpeedContainer = createSliderInputContainer(Page1, 275)
local randomAimSpeedSlider = createSlider(randomAimSpeedContainer, 0, 0.1, 2, AntiAim.RandomAimSpeed)
local randomAimSpeedInput = createInputBox(randomAimSpeedContainer, 0.65, AntiAim.RandomAimSpeed)
syncSliderInput(randomAimSpeedSlider, randomAimSpeedInput, 0.1, 2, "RandomAimSpeed")

-- ★SpinBot速度调节：0~80（默认80）
createLabel(Page1, 310, "SpinBot速度 [0~80]")
local spinSpeedContainer = createSliderInputContainer(Page1, 330)
local spinSpeedSlider = createSlider(spinSpeedContainer, 0, 0, 80, AntiAim.SpinSpeed)
local spinSpeedInput = createInputBox(spinSpeedContainer, 0.65, AntiAim.SpinSpeed)
syncSliderInput(spinSpeedSlider, spinSpeedInput, 0, 80, "SpinSpeed")

createLabel(Page1, 365, "水平偏移 [-180~180°]")
local yawContainer = createSliderInputContainer(Page1, 385)
local yawSlider = createSlider(yawContainer, 0, -180, 180, AntiAim.YawOffset)
local yawInput = createInputBox(yawContainer, 0.65, AntiAim.YawOffset)
syncSliderInput(yawSlider, yawInput, -180, 180, "YawOffset")

createLabel(Page1, 420, "垂直偏移 [-180~180°]")
local pitchContainer = createSliderInputContainer(Page1, 440)
local pitchSlider = createSlider(pitchContainer, 0, -180, 180, AntiAim.PitchOffset)
local pitchInput = createInputBox(pitchContainer, 0.65, AntiAim.PitchOffset)
syncSliderInput(pitchSlider, pitchInput, -180, 180, "PitchOffset")

-- ============== 第二页：藏头定制页（小尺寸+动画适配） ==============
-- 藏头预览容器（小尺寸）
local HeadPreviewContainer: Frame = Instance.new("Frame")
HeadPreviewContainer.Size = UDim2.new(0.95, 0, 0, 70)
HeadPreviewContainer.Position = UDim2.new(0.025, 0, 0, 20)
HeadPreviewContainer.BackgroundColor3 = Color3.fromRGB(70, 15, 100)
HeadPreviewContainer.BackgroundTransparency = 0.2
HeadPreviewContainer.Parent = Page2
Instance.new("UICorner", HeadPreviewContainer).CornerRadius = UDim.new(0.2, 0)
Instance.new("UIStroke", HeadPreviewContainer).Color3 = Color3.fromRGB(200, 120, 255)
Instance.new("UIStroke", HeadPreviewContainer).Thickness = 1

-- 小尺寸Noob小人预览（点击定位头部）
local noob: Frame = Instance.new("Frame")
noob.Size = UDim2.new(0, 40, 0, 60)
noob.Position = UDim2.new(0.5, -20, 0.5, -30)
noob.BackgroundTransparency = 1
noob.Name = "NoobPreview"
noob.Parent = HeadPreviewContainer

-- Noob身体
local body: Frame = Instance.new("Frame")
body.Size = UDim2.new(0, 20, 0, 35)
body.Position = UDim2.new(0.5, -10, 0.2, 0)
body.BackgroundColor3 = Color3.fromRGB(255, 200, 100)
body.Name = "Body"
Instance.new("UICorner", body).CornerRadius = UDim.new(0.1, 0)
body.Parent = noob

-- Noob头部（预览，跟随点击移动）
local headPreview: Frame = Instance.new("Frame")
headPreview.Size = UDim2.new(0, 20, 0, 20)
headPreview.Position = UDim2.new(0.5, -10, 0, 0)
headPreview.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
headPreview.Name = "Head"
Instance.new("UICorner", headPreview).CornerRadius = UDim.new(1, 0)
headPreview.Parent = noob

-- Noob点击定位逻辑（同步实际角色头部目标位置）
noob.InputBegan:Connect(function(inputObj)
    if not (inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch) then return end
    if not head or not rootPart then return end
    local clickPos: Vector2 = inputObj.Position
    local relPos: Vector2 = noob:GuiInverseTransformPoint(clickPos)
    -- 预览头部跟随点击
    headPreview.Position = UDim2.new(0, relPos.X - 10, 0, relPos.Y - 10)
    -- 计算实际角色头部偏移（适配比例）
    local offsetX = (relPos.X - 20) / 5
    local offsetY = (relPos.Y - 30) / 5
    local offsetZ = 0
    targetHeadCFrame = rootPart.CFrame * CFrame.new(offsetX, offsetY, offsetZ)
end)

-- 应用藏头位置按钮
local ApplyHeadBtn = createToggleButton(Page2, 100, "应用藏头位置", "已应用藏头", "HeadHideApplied")
ApplyHeadBtn.MouseButton1Click:Connect(function()
    if not head or not targetHeadCFrame then return end
    -- 点击应用立即更新藏头目标位置并播放动画
    playHeadTween(targetHeadCFrame)
    AntiAim.HeadHideApplied = true
end)

-- 恢复头部原始位置按钮
local ResetHeadBtn = createToggleButton(Page2, 135, "恢复头部原始位置", "已恢复", "HeadHideApplied")
ResetHeadBtn.MouseButton1Click:Connect(function()
    if not head or not originalHeadCFrame then return end
    -- 恢复原始位置并播放动画
    playHeadTween(originalHeadCFrame)
    targetHeadCFrame = originalHeadCFrame
    headPreview.Position = UDim2.new(0.5, -10, 0, 0)
    AntiAim.HeadHideApplied = false
    AntiAim.HeadHide = false
end)

-- 额外提示标签
createLabel(Page2, 170, "提示：点击小人定位头部，应用后生效")
createLabel(Page2, 190, "开启藏头功能后，平滑动画过渡")

-- ===================== 核心逻辑：所有Anti-Aim功能执行 ======================
renderStep:Connect(function(deltaTime: number)
    -- 前置校验：总开关关闭/角色无效/死亡，直接返回
    if not AntiAim.Enabled or not character or not rootPart or not humanoid or humanoid.Health <= 0 then
        return
    end

    local finalYaw: number = AntiAim.YawOffset  -- 最终水平角度
    local finalPitch: number = AntiAim.PitchOffset-- 最终垂直角度（低头/抬头）
    local angles: {number} = AntiAim.CurAngleMode == 3 and AntiAim.Angle3 or AntiAim.Angle5

    -- 功能优先级：随机转向 > 3/5角度 > SpinBot（★SpinBot速度80）
    if AntiAim.RandomAim then
        -- 随机方向转向：无规律±180°
        AntiAim.RandomAimTick += deltaTime
        if AntiAim.RandomAimTick >= AntiAim.RandomAimSpeed then
            AntiAim.RandomAimYaw = getRandomAngle(-180, 180)
            AntiAim.RandomAimPitch = getRandomAngle(-180, 180)
            AntiAim.RandomAimTick = 0.0
        end
        finalYaw = AntiAim.RandomAimYaw
        finalPitch = AntiAim.RandomAimPitch
    elseif AntiAim.AngleMode then
        -- 3/5角度摆动：抬头→低头往复
        AntiAim.AngleTick += deltaTime
        if AntiAim.AngleTick >= AntiAim.AngleSwitchSpeed then
            AntiAim.AngleIndex = AntiAim.AngleIndex + 1
            if AntiAim.AngleIndex > #angles then AntiAim.AngleIndex = 1 end
            AntiAim.AngleTick = 0.0
        end
        finalPitch = angles[AntiAim.AngleIndex]
    elseif AntiAim.SpinBot then
        -- ★SpinBot旋转：速度80，快速旋转
        AntiAim.SpinAngle += AntiAim.SpinSpeed * deltaTime * 30
        if AntiAim.SpinAngle >= 360 then AntiAim.SpinAngle = 0 end
        finalYaw = AntiAim.SpinAngle
    end

    -- 基础随机偏移（0~90°）：叠加所有模式
    if AntiAim.Randomize then
        finalYaw += getRandomAngle(-AntiAim.RandomRange, AntiAim.RandomRange)
        finalPitch += getRandomAngle(-AntiAim.RandomRange, AntiAim.RandomRange)
        finalYaw = clamp(finalYaw, -180, 180)
        finalPitch = clamp(finalPitch, -180, 180)
    end

    -- 修改角色根部件朝向（核心：仅旋转，保留位置）
    rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.fromOrientation(
        deg2rad(finalPitch), -- 垂直：低头/抬头
        deg2rad(finalYaw),   -- 水平：旋转/偏移
        0                   -- 滚转：0，避免角色歪扭
    )
end)
