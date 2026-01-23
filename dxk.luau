--!strict
-- Desync AI | Luau 纯脚本版
-- Void: 服务器视角传至虚空，客户端立即回位 | 全 Desync 方法支持

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
assert(LocalPlayer, "LocalPlayer not found")

-- 类型定义
type DesyncMethod = "Normal" | "TempleHook" | "FakeRoot" | "NoClipDesync" | "VoidDesync" | "NetworkOwnership"
type RespawnMode = "Fast Respawn" | "No Respawn"

-- 配置
local CONFIG = {
	Methods = {"Normal", "TempleHook", "FakeRoot", "NoClipDesync", "VoidDesync", "NetworkOwnership"} :: {DesyncMethod},
	CurrentMethod = "Normal" :: DesyncMethod,
	RespawnMode = "Fast Respawn" :: RespawnMode,
	VoidY = -10000 :: number,
	VoidReturnDelay = 0 :: number
}

-- 状态变量
local isActive = false
local isVoid = false
local FakeChar: Model? = nil
local RealChar: Model? = nil
local Humanoid: Humanoid? = nil
local heartbeatConn: RBXScriptConnection? = nil
local damageBlockConn: RBXScriptConnection? = nil
local originalPosition: Vector3? = nil
local originalCFrame: CFrame? = nil

-- 清理资源
local function Cleanup()
	if FakeChar then FakeChar:Destroy() end
	if heartbeatConn then heartbeatConn:Disconnect() end
	if damageBlockConn then damageBlockConn:Disconnect() end
	isActive = false
	if updateGUI then updateGUI() end
end

-- 通用伤害远程拦截
local function BlockDamageRemotes()
	damageBlockConn = RunService.Heartbeat:Connect(function()
		for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
			if (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) and not v.OriginalFireServer then
				local name = v.Name:lower()
				if name:find("damage") or name:find("hit") or name:find("hurt") or name:find("kill") then
					v.OriginalFireServer = v.FireServer
					v.FireServer = function(self: RemoteEvent, ...)
						local args = {...}
						for _, a in ipairs(args) do
							if a == RealChar or a == Humanoid then return end
						end
						return v.OriginalFireServer(self, ...)
					end
					if v:IsA("RemoteFunction") then
						v.OriginalInvokeServer = v.InvokeServer
						v.InvokeServer = function(self: RemoteFunction, ...)
							local args = {...}
							for _, a in ipairs(args) do
								if a == RealChar or a == Humanoid then return nil end
							end
							return v.OriginalInvokeServer(self, ...)
						end
					end
				end
			end
		end
	end)
end

-- ==============================================
-- Desync 方法实现
-- ==============================================

-- 1. Normal（标准假人同步）
local function Method_Normal()
	RealChar = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	Humanoid = RealChar:WaitForChild("Humanoid") :: Humanoid
	originalPosition = RealChar.PrimaryPart.Position

	FakeChar = RealChar:Clone()
	FakeChar.Name = LocalPlayer.Name .. "_Fake"
	FakeChar.Parent = Workspace

	for _, v in ipairs(FakeChar:GetDescendants()) do
		if v:IsA("BasePart") then
			v.Anchored = true
			v.CanCollide = false
		elseif v:IsA("Script") or v:IsA("LocalScript") then
			v:Destroy()
		elseif v:IsA("Humanoid") then
			v:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
			v.Health = v.MaxHealth
		end
	end

	for _, v in ipairs(RealChar:GetDescendants()) do
		if v:IsA("BasePart") then
			v.Transparency = 1
			v.CanCollide = false
		elseif v:IsA("Decal") then
			v.Transparency = 1
		end
	end

	Humanoid.MaxHealth = math.huge
	Humanoid.Health = math.huge
	Humanoid.HealthChanged:Connect(function(h)
		if h < Humanoid.MaxHealth then Humanoid.Health = Humanoid.MaxHealth end
	end)

	heartbeatConn = RunService.Heartbeat:Connect(function()
		if FakeChar and FakeChar.PrimaryPart and RealChar and RealChar.PrimaryPart then
			FakeChar:SetPrimaryPartCFrame(RealChar.PrimaryPart.CFrame)
		end
	end)
end

-- 2. TempleHook（神庙钩子）
local function Method_TempleHook()
	RealChar = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	Humanoid = RealChar:WaitForChild("Humanoid") :: Humanoid
	originalCFrame = RealChar.PrimaryPart.CFrame

	for _, v in ipairs(RealChar:GetDescendants()) do
		if v:IsA("BasePart") then
			v:SetNetworkOwner(nil)
			v.Transparency = 1
			v.CanCollide = false
		elseif v:IsA("Decal") then
			v.Transparency = 1
		end
	end

	FakeChar = Instance.new("Model")
	FakeChar.Name = LocalPlayer.Name .. "_Fake"
	FakeChar.Parent = Workspace

	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 2, 2)
	hrp.Anchored = true
	hrp.CanCollide = false
	hrp.Transparency = 1
	hrp.CFrame = originalCFrame
	hrp.Parent = FakeChar

	local fakeHum = Instance.new("Humanoid")
	fakeHum.Parent = FakeChar
	FakeChar.PrimaryPart = hrp

	heartbeatConn = RunService.Heartbeat:Connect(function()
		if FakeChar and FakeChar.PrimaryPart then
			FakeChar:SetPrimaryPartCFrame(originalCFrame)
		end
	end)
end

-- 3. FakeRoot（假根节点）
local function Method_FakeRoot()
	RealChar = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	Humanoid = RealChar:WaitForChild("Humanoid") :: Humanoid
	local realHRP = RealChar:WaitForChild("HumanoidRootPart") :: BasePart
	originalCFrame = realHRP.CFrame

	FakeChar = Instance.new("Model")
	FakeChar.Name = LocalPlayer.Name .. "_Fake"
	FakeChar.Parent = Workspace

	local fakeHRP = realHRP:Clone()
	fakeHRP.Name = "HumanoidRootPart"
	fakeHRP.Anchored = true
	fakeHRP.CanCollide = false
	fakeHRP.Parent = FakeChar

	local fakeHum = Instance.new("Humanoid")
	fakeHum.Parent = FakeChar
	FakeChar.PrimaryPart = fakeHRP

	realHRP.Transparency = 1
	realHRP.CanCollide = false
	realHRP.CanTouch = false

	for _, v in ipairs(RealChar:GetChildren()) do
		if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
			v.Transparency = 1
			v.CanCollide = false
		end
	end

	heartbeatConn = RunService.Heartbeat:Connect(function()
		if FakeChar and FakeChar.PrimaryPart then
			FakeChar:SetPrimaryPartCFrame(originalCFrame)
		end
	end)
end

-- 4. NoClipDesync（无碰撞+假人占位）
local function Method_NoClipDesync()
	RealChar = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	Humanoid = RealChar:WaitForChild("Humanoid") :: Humanoid
	originalPosition = RealChar.PrimaryPart.Position

	FakeChar = RealChar:Clone()
	FakeChar.Name = LocalPlayer.Name .. "_Fake"
	FakeChar.Parent = Workspace

	for _, v in ipairs(FakeChar:GetDescendants()) do
		if v:IsA("BasePart") then
			v.Anchored = true
			v.CanCollide = false
		elseif v:IsA("Script") or v:IsA("LocalScript") then
			v:Destroy()
		end
	end

	for _, v in ipairs(RealChar:GetDescendants()) do
		if v:IsA("BasePart") then
			v.CanCollide = false
			v.CanTouch = false
			v.CanQuery = false
		end
	end

	Humanoid.MaxHealth = math.huge
	Humanoid.Health = math.huge

	heartbeatConn = RunService.Heartbeat:Connect(function()
		if FakeChar and FakeChar.PrimaryPart then
			FakeChar:SetPrimaryPartCFrame(CFrame.new(originalPosition))
		end
	end)
end

-- 5. VoidDesync（直接虚空传送+假人）
local function Method_VoidDesync()
	RealChar = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	Humanoid = RealChar:WaitForChild("Humanoid") :: Humanoid
	originalPosition = RealChar.PrimaryPart.Position

	FakeChar = RealChar:Clone()
	FakeChar.Name = LocalPlayer.Name .. "_Fake"
	FakeChar.Parent = Workspace

	for _, v in ipairs(FakeChar:GetDescendants()) do
		if v:IsA("BasePart") then
			v.Anchored = true
			v.CanCollide = false
		elseif v:IsA("Script") or v:IsA("LocalScript") then
			v:Destroy()
		end
	end

	RealChar:SetPrimaryPartCFrame(CFrame.new(originalPosition.X, CONFIG.VoidY, originalPosition.Z))
	for _, v in ipairs(RealChar:GetDescendants()) do
		if v:IsA("BasePart") then
			v.Transparency = 1
			v.CanCollide = false
		elseif v:IsA("Decal") then
			v.Transparency = 1
		end
	end

	Humanoid.MaxHealth = math.huge
	Humanoid.Health = math.huge

	heartbeatConn = RunService.Heartbeat:Connect(function()
		if FakeChar and FakeChar.PrimaryPart then
			FakeChar:SetPrimaryPartCFrame(CFrame.new(originalPosition))
		end
	end)
end

-- 6. NetworkOwnership（网络所有权劫持）
local function Method_NetworkOwnership()
	RealChar = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	Humanoid = RealChar:WaitForChild("Humanoid") :: Humanoid
	originalPosition = RealChar.PrimaryPart.Position

	FakeChar = RealChar:Clone()
	FakeChar.Name = LocalPlayer.Name .. "_Fake"
	FakeChar.Parent = Workspace

	for _, v in ipairs(FakeChar:GetDescendants()) do
		if v:IsA("BasePart") then
			v.Anchored = true
			v.CanCollide = false
			v:SetNetworkOwner(LocalPlayer)
		elseif v:IsA("Script") or v:IsA("LocalScript") then
			v:Destroy()
		end
	end

	for _, v in ipairs(RealChar:GetDescendants()) do
		if v:IsA("BasePart") then
			v:SetNetworkOwner(nil)
			v.Transparency = 1
			v.CanCollide = false
		elseif v:IsA("Decal") then
			v.Transparency = 1
		end
	end

	Humanoid.MaxHealth = math.huge
	Humanoid.Health = math.huge

	heartbeatConn = RunService.Heartbeat:Connect(function()
		if FakeChar and FakeChar.PrimaryPart and RealChar and RealChar.PrimaryPart then
			FakeChar:SetPrimaryPartCFrame(RealChar.PrimaryPart.CFrame)
		end
	end)
end

-- 方法映射
local MethodMap = {
	Normal = Method_Normal,
	TempleHook = Method_TempleHook,
	FakeRoot = Method_FakeRoot,
	NoClipDesync = Method_NoClipDesync,
	VoidDesync = Method_VoidDesync,
	NetworkOwnership = Method_NetworkOwnership
}

-- 初始化 Desync
local function InitDesync()
	if isActive then return end
	isActive = true
	updateGUI()

	RealChar = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	Humanoid = RealChar:WaitForChild("Humanoid") :: Humanoid

	local func = MethodMap[CONFIG.CurrentMethod]
	if func then func() end

	BlockDamageRemotes()

	if CONFIG.RespawnMode == "Fast Respawn" then
		Humanoid.Died:Connect(function()
			task.wait(0.1)
			LocalPlayer:LoadCharacter()
		end)
	end

	print("✅ Desync 激活：" .. CONFIG.CurrentMethod)
end

-- 开关 Desync
local function ToggleDesync()
	if isActive then
		Cleanup()
	else
		InitDesync()
	end
end

-- 切换重生模式
local function ToggleRespawnMode(mode: RespawnMode)
	CONFIG.RespawnMode = mode
	updateGUI()
	if isActive then
		Cleanup()
		task.wait(0.5)
		InitDesync()
	end
end

-- 切换 Desync 方法
local function SetMethod(method: DesyncMethod)
	CONFIG.CurrentMethod = method
	updateGUI()
	if isActive then
		Cleanup()
		task.wait(0.5)
		InitDesync()
	end
end

-- ==============================================
-- Void 核心逻辑（服务器视角传虚空 + 客户端回位）
-- ==============================================
local function ToggleVoid()
	isVoid = not isVoid
	if not RealChar or not RealChar.PrimaryPart then return end

	if isVoid then
		originalPosition = RealChar.PrimaryPart.Position
		-- 服务器视角：传至虚空
		RealChar:SetPrimaryPartCFrame(CFrame.new(originalPosition.X, CONFIG.VoidY, originalPosition.Z))
		-- 客户端视角：延迟后回位
		task.wait(CONFIG.VoidReturnDelay)
		RealChar:SetPrimaryPartCFrame(CFrame.new(originalPosition))
		-- 完全隐藏
		for _, v in ipairs(RealChar:GetDescendants()) do
			if v:IsA("BasePart") then v.Transparency = 1 end
			if v:IsA("Decal") then v.Transparency = 1 end
		end
		print("✅ Void 激活：服务器视角在虚空，客户端已回位")
	else
		-- 恢复可见
		for _, v in ipairs(RealChar:GetDescendants()) do
			if v:IsA("BasePart") then v.Transparency = 0 end
			if v:IsA("Decal") then v.Transparency = 0 end
		end
		print("❌ Void 关闭：恢复正常可见")
	end
	updateGUI()
end

-- ==============================================
-- GUI 创建
-- ==============================================
local function CreateGUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DesyncAI_VoidServer"
	gui.Parent = game:GetService("CoreGui")

	local mainFrame = Instance.new("Frame")
	mainFrame.Size = UDim2.new(0, 360, 0, 300)
	mainFrame.Position = UDim2.new(0.05, 0, 0.1, 0)
	mainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	mainFrame.BorderColor3 = Color3.fromRGB(0, 120, 0)
	mainFrame.BorderSizePixel = 2
	mainFrame.Active = true
	mainFrame.Draggable = true
	mainFrame.Parent = gui

	-- 标题栏
	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 30)
	titleBar.BackgroundColor3 = Color3.fromRGB(0, 80, 0)
	titleBar.Parent = mainFrame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -10, 1, 0)
	titleLabel.Position = UDim2.new(0, 5, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "★ Desync AI | Void Server"
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextSize = 14
	titleLabel.Font = Enum.Font.SourceSansBold
	titleLabel.Parent = titleBar

	-- 开关按钮
	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Size = UDim2.new(0.55, 0, 0, 40)
	toggleBtn.Position = UDim2.new(0, 10, 0, 40)
	toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
	toggleBtn.BorderSizePixel = 0
	toggleBtn.Text = "DESYNC: OFF"
	toggleBtn.TextColor3 = Color3.new(1, 1, 1)
	toggleBtn.TextSize = 16
	toggleBtn.Font = Enum.Font.SourceSansBold
	toggleBtn.Parent = mainFrame

	-- Void 按钮
	local voidBtn = Instance.new("TextButton")
	voidBtn.Size = UDim2.new(0.2, 0, 0, 40)
	voidBtn.Position = UDim2.new(0.6, 0, 0, 40)
	voidBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	voidBtn.BorderSizePixel = 0
	voidBtn.Text = "VOID"
	voidBtn.TextColor3 = Color3.new(1, 1, 1)
	voidBtn.TextSize = 16
	voidBtn.Font = Enum.Font.SourceSansBold
	voidBtn.Parent = mainFrame

	-- 方法选择
	local methodLabel = Instance.new("TextLabel")
	methodLabel.Size = UDim2.new(0, 80, 0, 25)
	methodLabel.Position = UDim2.new(0, 10, 0, 90)
	methodLabel.BackgroundTransparency = 1
	methodLabel.Text = "Method:"
	methodLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
	methodLabel.TextSize = 12
	methodLabel.Parent = mainFrame

	local methodDropdown = Instance.new("TextButton")
	methodDropdown.Size = UDim2.new(0.65, 0, 0, 25)
	methodDropdown.Position = UDim2.new(0.25, 0, 0, 90)
	methodDropdown.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	methodDropdown.BorderColor3 = Color3.fromRGB(60, 60, 60)
	methodDropdown.BorderSizePixel = 1
	methodDropdown.Text = CONFIG.CurrentMethod
	methodDropdown.TextColor3 = Color3.new(1, 1, 1)
	methodDropdown.TextSize = 12
	methodDropdown.Parent = mainFrame

	local methodList = Instance.new("Frame")
	methodList.Size = UDim2.new(0.65, 0, 0, #CONFIG.Methods * 25)
	methodList.Position = UDim2.new(0.25, 0, 0, 115)
	methodList.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	methodList.BorderColor3 = Color3.fromRGB(60, 60, 60)
	methodList.BorderSizePixel = 1
	methodList.Visible = false
	methodList.ClipsDescendants = true
	methodList.Parent = mainFrame

	for i, m in ipairs(CONFIG.Methods) do
		local item = Instance.new("TextButton")
		item.Size = UDim2.new(1, 0, 0, 25)
		item.Position = UDim2.new(0, 0, 0, (i - 1) * 25)
		item.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		item.BorderSizePixel = 0
		item.Text = m
		item.TextColor3 = Color3.new(1, 1, 1)
		item.TextSize = 12
		item.Parent = methodList

		item.MouseButton1Click:Connect(function()
			SetMethod(m)
			methodList.Visible = false
		end)
	end

	methodDropdown.MouseButton1Click:Connect(function()
		methodList.Visible = not methodList.Visible
	end)

	-- 状态标签
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, -20, 0, 20)
	statusLabel.Position = UDim2.new(0, 10, 0, 130)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "Status: Idle"
	statusLabel.TextColor3 = Color3.new(0.7, 0.7, 0.7)
	statusLabel.TextSize = 12
	statusLabel.Parent = mainFrame

	local voidStatus = Instance.new("TextLabel")
	voidStatus.Size = UDim2.new(1, -20, 0, 20)
	voidStatus.Position = UDim2.new(0, 10, 0, 150)
	voidStatus.BackgroundTransparency = 1
	voidStatus.Text = "Void: OFF"
	voidStatus.TextColor3 = Color3.new(0.7, 0.7, 0.7)
	voidStatus.TextSize = 12
	voidStatus.Parent = mainFrame

	-- 重生模式
	local respawnLabel = Instance.new("TextLabel")
	respawnLabel.Size = UDim2.new(1, -20, 0, 20)
	respawnLabel.Position = UDim2.new(0, 10, 0, 180)
	respawnLabel.BackgroundTransparency = 1
	respawnLabel.Text = "Respawn:"
	respawnLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
	respawnLabel.TextSize = 12
	respawnLabel.Parent = mainFrame

	local fastBtn = Instance.new("TextButton")
	fastBtn.Size = UDim2.new(0.45, 0, 0, 30)
	fastBtn.Position = UDim2.new(0, 10, 0, 205)
	fastBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
	fastBtn.BorderSizePixel = 0
	fastBtn.Text = "Fast Respawn"
	fastBtn.TextColor3 = Color3.new(1, 1, 1)
	fastBtn.TextSize = 14
	fastBtn.Parent = mainFrame

	local noBtn = Instance.new("TextButton")
	noBtn.Size = UDim2.new(0.45, 0, 0, 30)
	noBtn.Position = UDim2.new(0.5, 0, 0, 205)
	noBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	noBtn.BorderSizePixel = 0
	noBtn.Text = "No Respawn"
	noBtn.TextColor3 = Color3.new(1, 1, 1)
	noBtn.TextSize = 14
	noBtn.Parent = mainFrame

	-- Humanoid 状态
	local humLabel = Instance.new("TextLabel")
	humLabel.Size = UDim2.new(1, -20, 0, 20)
	humLabel.Position = UDim2.new(0, 10, 0, 245)
	humLabel.BackgroundTransparency = 1
	humLabel.Text = "Humanoid: Found"
	humLabel.TextColor3 = Color3.new(0, 1, 0)
	humLabel.TextSize = 12
	humLabel.Parent = mainFrame

	-- 更新 GUI 状态
	function updateGUI()
		toggleBtn.Text = isActive and "DESYNC: ON" or "DESYNC: OFF"
		toggleBtn.BackgroundColor3 = isActive and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(0, 120, 0)
		statusLabel.Text = isActive and "Status: Active" or "Status: Idle"
		statusLabel.TextColor3 = isActive and Color3.new(0, 1, 0) or Color3.new(0.7, 0.7, 0.7)
		voidStatus.Text = isVoid and "Void: ON" or "Void: OFF"
		voidStatus.TextColor3 = isVoid and Color3.new(0, 1, 0) or Color3.new(0.7, 0.7, 0.7)
		methodDropdown.Text = CONFIG.CurrentMethod
		fastBtn.BackgroundColor3 = CONFIG.RespawnMode == "Fast Respawn" and Color3.fromRGB(0, 120, 0) or Color3.fromRGB(50, 50, 50)
		noBtn.BackgroundColor3 = CONFIG.RespawnMode == "No Respawn" and Color3.fromRGB(0, 120, 0) or Color3.fromRGB(50, 50, 50)
	end

	-- 按钮事件
	toggleBtn.MouseButton1Click:Connect(ToggleDesync)
	voidBtn.MouseButton1Click:Connect(ToggleVoid)
	fastBtn.MouseButton1Click:Connect(function() ToggleRespawnMode("Fast Respawn") end)
	noBtn.MouseButton1Click:Connect(function() ToggleRespawnMode("No Respawn") end)

	-- 角色重生重连
	LocalPlayer.CharacterAdded:Connect(function(newChar)
		if isActive then
			Cleanup()
			task.wait(0.5)
			InitDesync()
		end
	end)

	updateGUI()
	print("✅ Desync AI (Void Server) 加载完成")
end

-- 启动
CreateGUI()
