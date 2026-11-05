--[[ SMOOTH.DEV v10
     Insert = menu | RightShift = unload ]]

local Players  = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS      = game:GetService("UserInputService")
local Tween    = game:GetService("TweenService")
local VIM      = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")
local SoundSvc = game:GetService("SoundService")
local WS       = workspace

local LP = Players.LocalPlayer
local Camera = WS.CurrentCamera
WS:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	if WS.CurrentCamera then Camera = WS.CurrentCamera end
end)

if getgenv().V and type(getgenv().V) == "table" and getgenv().V.Unload then
	pcall(getgenv().V.Unload)
end

local EXCLUDE = Enum.RaycastFilterType.Exclude or Enum.RaycastFilterType.Blacklist

local C = {
	ink   = Color3.fromRGB(6, 7, 10),
	shell = Color3.fromRGB(11, 12, 16),
	card  = Color3.fromRGB(17, 19, 24),
	cardHi= Color3.fromRGB(24, 28, 35),
	line  = Color3.fromRGB(30, 35, 43),
	text  = Color3.fromRGB(233, 240, 249),
	sub   = Color3.fromRGB(112, 124, 140),
	accent= Color3.fromRGB(0, 214, 255),
	accent2=Color3.fromRGB(38, 108, 255),
	ok    = Color3.fromRGB(0, 255, 145),
	bad   = Color3.fromRGB(255, 78, 108),
}

local T_FAST   = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local T_SMOOTH = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local T_SPRING = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local T_CIRC   = TweenInfo.new(0.3, Enum.EasingStyle.Circ, Enum.EasingDirection.Out)

local S = {
	Aimbot = {
		on = false, key = Enum.KeyCode.E, fov = 110, smooth = 0.28, pred = 0.14,
		team = true, part = "Head", maxd = 1200, vis = false, instant = false,
		autofire = false, firedelay = 0.08, trigger = false, ignoreknock = true,
	},
	Silent = { on = false, key = Enum.KeyCode.Q, fov = 160, team = true, maxd = 1200, vis = false },
	ESP = {
		on = true, box = true, name = true, hp = true, dist = true, chams = false,
		tracer = false, team = false, maxd = 900, fovcircle = true, fill = false,
	},
	Char = { speed = false, sv = 60, jump = false, jv = 95, fly = false, noclip = false,
	         scale = false, scalev = 1, freeze = false },
	Cam = { free = false, freespd = 60, orbit = false, orbitr = 16, orbitspd = 60 },
	HB = { on = false, size = 6 },
	Troll = { spin = false, spinspd = 220, ragdoll = false, rainbow = false, rain = false,
	          shake = false, shakei = 1.2, fog = false, ghost = false, follow = false,
	          aura = false, trail = false, party = false, afk = false, sit = false },
}

local DEFAULTS = {
	Aimbot = { on = false, key = Enum.KeyCode.E, fov = 110, smooth = 0.28, pred = 0.14,
	           team = true, part = "Head", maxd = 1200, vis = false, instant = false,
	           autofire = false, firedelay = 0.08, trigger = false, ignoreknock = true },
	Silent = { on = false, key = Enum.KeyCode.Q, fov = 160, team = true, maxd = 1200, vis = false },
	ESP = { on = true, box = true, name = true, hp = true, dist = true, chams = false,
	        tracer = false, team = false, maxd = 900, fovcircle = true, fill = false },
	Char = { speed = false, sv = 60, jump = false, jv = 95, fly = false, noclip = false,
	         scale = false, scalev = 1, freeze = false },
	Cam = { free = false, freespd = 60, orbit = false, orbitr = 16, orbitspd = 60 },
	HB = { on = false, size = 6 },
	Troll = { spin = false, spinspd = 220, ragdoll = false, rainbow = false, rain = false,
	          shake = false, shakei = 1.2, fog = false, ghost = false, follow = false,
	          aura = false, trail = false, party = false, afk = false, sit = false },
}

local conns, esp, objs, hbStore, refreshers, cards, tabs = {}, {}, {}, {}, {}, {}, {}
local dead = false
local function track(c) conns[#conns + 1] = c return c end

-- ================= rig =================
local function getHum(c)
	if not c then return nil end
	return c:FindFirstChildOfClass("Humanoid") or c:FindFirstChildWhichIsA("Humanoid")
end

local function getRoot(c)
	if not c then return nil end
	local h = getHum(c)
	if h and h.RootPart then return h.RootPart end
	if c.PrimaryPart and c.PrimaryPart:IsA("BasePart") then return c.PrimaryPart end
	for _, n in ipairs({ "HumanoidRootPart", "UpperTorso", "Torso", "Head" }) do
		local p = c:FindFirstChild(n)
		if p and p:IsA("BasePart") then return p end
	end
	return c:FindFirstChildWhichIsA("BasePart")
end

local function alive(p)
	if not p then return nil end
	local c = p.Character
	if not c or not c.Parent then return nil end
	local h = getHum(c)
	local r = getRoot(c)
	if not h or not r or h.Health <= 0 then return nil end
	return c, h, r
end

local AIMORDER = { "Head", "UpperTorso", "Torso", "HumanoidRootPart" }

local function partOf(c)
	if not c then return nil end
	local mode = S.Aimbot.part
	if mode == "Random" then
		local l = {}
		for _, n in ipairs(AIMORDER) do
			local q = c:FindFirstChild(n)
			if q and q:IsA("BasePart") then l[#l + 1] = q end
		end
		if #l == 0 then return getRoot(c) end
		return l[math.random(1, #l)]
	end
	if mode == "Nearest" then
		local ctr = Camera.ViewportSize / 2
		local best, bd = nil, math.huge
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
				local sp = Camera:WorldToViewportPoint(d.Position)
				if sp.Z > 0 then
					local m = (Vector2.new(sp.X, sp.Y) - ctr).Magnitude
					if m < bd then bd = m best = d end
				end
			end
		end
		return best or getRoot(c)
	end
	local p = c:FindFirstChild(mode)
	if p and p:IsA("BasePart") then return p end
	for _, n in ipairs(AIMORDER) do
		local q = c:FindFirstChild(n)
		if q and q:IsA("BasePart") then return q end
	end
	return getRoot(c)
end

local function visible(part)
	if not part then return false end
	local rp = RaycastParams.new()
	rp.FilterType = EXCLUDE
	local fl = {}
	if LP.Character then fl[#fl + 1] = LP.Character end
	local tc = part:FindFirstAncestorOfClass("Model")
	if tc then fl[#fl + 1] = tc end
	rp.FilterDescendantsInstances = fl
	local ok, res = pcall(function()
		return WS:Raycast(Camera.CFrame.Position, part.Position - Camera.CFrame.Position, rp)
	end)
	if not ok then return true end
	return res == nil
end

local function target(cfg)
	local best, bd = nil, cfg.fov
	local ctr = Camera.ViewportSize / 2
	local camPos = Camera.CFrame.Position
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP then
			local c, h, r = alive(p)
			if r and not (cfg.team and LP.Team ~= nil and p.Team == LP.Team) then
				if not (S.Aimbot.ignoreknock and h.PlatformStand) then
					if (r.Position - camPos).Magnitude <= cfg.maxd then
						local pt = partOf(c)
						if pt and (not cfg.vis or visible(pt)) then
							local sp = Camera:WorldToViewportPoint(pt.Position)
							if sp.Z > 0 then
								local d = (Vector2.new(sp.X, sp.Y) - ctr).Magnitude
								if d < bd then bd = d best = p end
							end
						end
					end
				end
			end
		end
	end
	return best
end

local function aimPoint(p)
	local c, h, r = alive(p)
	if not r then return nil end
	local pt = partOf(c)
	if not pt then return nil end
	local ping = 0
	pcall(function() ping = LP:GetNetworkPing() or 0 end)
	local v = r.AssemblyLinearVelocity or r.Velocity or Vector3.zero
	return pt.Position + v * (ping * S.Aimbot.pred)
end

local lastFire = 0
local function fire()
	if os.clock() - lastFire < S.Aimbot.firedelay then return end
	lastFire = os.clock()
	if mouse1click then pcall(mouse1click)
	else pcall(function() VIM:ClickButton1(Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)) end) end
end

local function applyAim(p, instant)
	local pos = p and aimPoint(p)
	if not pos then return false end
	local sp = Camera:WorldToViewportPoint(pos)
	if sp.Z <= 0 then return false end
	local vp = Camera.ViewportSize
	local dx = sp.X - vp.X / 2
	local dy = sp.Y - vp.Y / 2
	if instant then
		if mousemoverel then pcall(mousemoverel, dx, dy)
		else Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, pos) end
		return true
	end
	if math.abs(dx) > 1 or math.abs(dy) > 1 then
		local k = S.Aimbot.smooth
		if mousemoverel then pcall(mousemoverel, dx * k, dy * k)
		else Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(Camera.CFrame.Position, pos), math.clamp(k, 0.02, 1)) end
	end
	return true
end

-- ================= shell =================
local function new(cls, props, par)
	local o = Instance.new(cls)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = par
	return o
end
local function round(o, r) new("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
local function grad(o, c1, c2, rot)
	local g = new("UIGradient", { Color = ColorSequence.new(c1, c2) }, o)
	if rot then g.Rotation = rot end
	return g
end

local clickSound
local function playClick()
	if not clickSound then
		clickSound = Instance.new("Sound")
		clickSound.SoundId = "rbxassetid://131961136"
		clickSound.Volume = 0.15
		clickSound.PlaybackSpeed = 3.6
		clickSound.Parent = SoundSvc
	end
	pcall(function()
		clickSound:Stop()
		clickSound.TimePosition = 0
		clickSound:Play()
	end)
end

local function press(o)
	local s = o:FindFirstChildOfClass("UIScale") or new("UIScale", {}, o)
	Tween:Create(s, T_FAST, { Scale = 0.972 }):Play()
	task.delay(0.07, function()
		if s.Parent then Tween:Create(s, T_SPRING, { Scale = 1 }):Play() end
	end)
end

local gui = Instance.new("ScreenGui")
gui.Name = "SmoothDev"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2147483647
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local expected
local function foreground()
	if syn and syn.protect_gui then pcall(syn.protect_gui, gui) end
	if type(gethui) == "function" then
		local ok, hui = pcall(gethui)
		if ok and hui then expected = hui gui.Parent = hui return end
	end
	if pcall(function() gui.Parent = game:GetService("CoreGui") end) then
		expected = game:GetService("CoreGui") return
	end
	expected = LP:WaitForChild("PlayerGui")
	gui.Parent = expected
end
foreground()

local espLayer = new("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 4,
}, gui)

local wm = new("Frame", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12),
	Size = UDim2.fromOffset(112, 22), BackgroundColor3 = C.ink,
	BackgroundTransparency = 0.15, BorderSizePixel = 0, ZIndex = 60,
}, gui)
round(wm, 6)
new("UIStroke", { Color = C.accent, Transparency = 0.6, Thickness = 1 }, wm)
new("TextLabel", {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
	Text = "SMOOTH.DEV", TextColor3 = C.accent,
	Font = Enum.Font.GothamBlack, TextSize = 11, ZIndex = 61,
}, wm)

-- ================= ESP =================
local function killESP(p)
	local e = esp[p]
	if e then
		if e.root then e.root:Destroy() end
		if e.hl then e.hl:Destroy() end
		esp[p] = nil
	end
end

local function makeESP()
	local root = new("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 5, Visible = false }, espLayer)
	local e = { root = root, corners = {} }

	e.box = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 6 }, root)
	e.stroke = new("UIStroke", { Color = C.accent, Thickness = 1, Transparency = 0.35 }, e.box)
	e.fillFrame = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.accent, BackgroundTransparency = 0.88, BorderSizePixel = 0, ZIndex = 5 }, root)

	for i = 1, 8 do
		e.corners[i] = new("Frame", { BackgroundColor3 = C.accent, BorderSizePixel = 0, ZIndex = 7 }, root)
	end

	e.hpBg = new("Frame", {
		Size = UDim2.new(0, 3, 1, 0), Position = UDim2.fromOffset(-6, 0),
		BackgroundColor3 = Color3.fromRGB(20, 22, 28), BorderSizePixel = 0, ZIndex = 7,
	}, root)
	e.hp = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.ok, BorderSizePixel = 0, ZIndex = 8 }, e.hpBg)

	e.tracer = new("Frame", {
		BackgroundColor3 = C.accent, BorderSizePixel = 0, ZIndex = 3,
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(1, 1), Visible = false,
	}, espLayer)

	e.name = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 13), Position = UDim2.fromOffset(0, -15),
		BackgroundTransparency = 1, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.2,
		Font = Enum.Font.GothamBold, TextSize = 11, ZIndex = 8,
	}, root)

	e.dist = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 1, 2),
		BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(190, 200, 215), TextStrokeTransparency = 0.35,
		Font = Enum.Font.Gotham, TextSize = 10, ZIndex = 8,
	}, root)

	return e
end

local function setCorner(e, w, h, L)
	local c = e.corners
	c[1].Position = UDim2.fromOffset(0, 0)          c[1].Size = UDim2.fromOffset(L, 1)
	c[2].Position = UDim2.fromOffset(0, 0)          c[2].Size = UDim2.fromOffset(1, L)
	c[3].Position = UDim2.fromOffset(w - L, 0)      c[3].Size = UDim2.fromOffset(L, 1)
	c[4].Position = UDim2.fromOffset(w - 1, 0)      c[4].Size = UDim2.fromOffset(1, L)
	c[5].Position = UDim2.fromOffset(0, h - 1)      c[5].Size = UDim2.fromOffset(L, 1)
	c[6].Position = UDim2.fromOffset(0, h - L)      c[6].Size = UDim2.fromOffset(1, L)
	c[7].Position = UDim2.fromOffset(w - L, h - 1)  c[7].Size = UDim2.fromOffset(L, 1)
	c[8].Position = UDim2.fromOffset(w - 1, h - L)  c[8].Size = UDim2.fromOffset(1, L)
end

local function drawESP(p)
	if not S.ESP.on then return false end
	local c, h, r = alive(p)
	if not r then return false end
	if S.ESP.team and LP.Team ~= nil and p.Team == LP.Team then return false end
	local dist = (r.Position - Camera.CFrame.Position).Magnitude
	if dist > S.ESP.maxd then return false end

	local ok, bbCF, sz = pcall(function()
		local cf, s = c:GetBoundingBox()
		return cf, s
	end)
	if not ok or not sz then
		local e0 = esp[p]
		if e0 then e0.root.Visible = false end
		return true
	end

	local hx, hy, hz = sz.X / 2, sz.Y / 2, sz.Z / 2
	local minx, maxx, miny, maxy = math.huge, -math.huge, math.huge, -math.huge
	local n = 0
	for _, sx in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			for _, sz2 in ipairs({ -1, 1 }) do
				local wp = (bbCF * CFrame.new(sx * hx, sy * hy, sz2 * hz)).Position
				local sp = Camera:WorldToViewportPoint(wp)
				if sp.Z > 0 then
					n = n + 1
					if sp.X < minx then minx = sp.X end
					if sp.X > maxx then maxx = sp.X end
					if sp.Y < miny then miny = sp.Y end
					if sp.Y > maxy then maxy = sp.Y end
				end
			end
		end
	end

	local e = esp[p]
	if n < 4 then
		if e then e.root.Visible = false end
		return true
	end
	if not e then
		e = makeESP()
		esp[p] = e
	end

	local w = math.max(maxx - minx, 22)
	local hgt = math.max(maxy - miny, 34)
	local x = minx - (w - (maxx - minx)) / 2
	local y = miny - (hgt - (maxy - miny)) / 2

	e.root.Visible = true
	e.root.Position = UDim2.fromOffset(x, y)
	e.root.Size = UDim2.fromOffset(w, hgt)

	setCorner(e, w, hgt, math.clamp(w * 0.22, 4, 12))

	e.box.Visible = S.ESP.box
	e.fillFrame.Visible = S.ESP.fill and S.ESP.box
	e.stroke.Transparency = S.ESP.box and 0.35 or 1
	for _, v in ipairs(e.corners) do v.Visible = S.ESP.box end

	e.name.Text = p.Name
	e.name.Visible = S.ESP.name
	e.dist.Text = math.floor(dist) .. "m"
	e.dist.Visible = S.ESP.dist

	e.hpBg.Visible = S.ESP.hp
	local a = math.clamp(h.Health / math.max(h.MaxHealth, 1), 0, 1)
	e.hp.Size = UDim2.fromScale(1, a)
	e.hp.Position = UDim2.new(0, 0, 1 - a, 0)
	e.hp.BackgroundColor3 = Color3.fromRGB(255 * (1 - a), 255 * a, 60)

	if S.ESP.tracer then
		local vp = Camera.ViewportSize
		local from = Vector2.new(vp.X / 2, vp.Y)
		local to = Vector2.new(x + w / 2, y + hgt)
		local d = to - from
		local mid = (from + to) / 2
		e.tracer.Visible = true
		e.tracer.Position = UDim2.fromOffset(mid.X, mid.Y)
		e.tracer.Size = UDim2.fromOffset(math.max(d.Magnitude, 1), 1)
		e.tracer.Rotation = math.deg(math.atan2(d.Y, d.X))
	else
		e.tracer.Visible = false
	end

	if S.ESP.chams then
		if not e.hl or not e.hl.Parent then
			if e.hl then e.hl:Destroy() end
			local hl = Instance.new("Highlight")
			hl.FillColor = C.accent
			hl.FillTransparency = 0.6
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			hl.Parent = c
			e.hl = hl
		elseif e.hl.Adornee ~= c then
			e.hl.Adornee = c
		end
	elseif e.hl then
		e.hl:Destroy()
		e.hl = nil
	end
	return true
end

-- ================= hitbox =================
local function restoreHB(p)
	local e = hbStore[p]
	if e and e.part then
		pcall(function() if e.part.Parent then e.part.Size = e.size end end)
	end
	hbStore[p] = nil
end

local function applyHB(p)
	local c = p.Character
	if not c then restoreHB(p) return end
	local head = c:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then head = getRoot(c) end
	if not head then return end
	local e = hbStore[p]
	if not e or e.part ~= head then
		restoreHB(p)
		hbStore[p] = { part = head, size = head.Size }
		e = hbStore[p]
	end
	local s = S.HB.size
	if (e.part.Size - Vector3.new(s, s, s)).Magnitude > 0.05 then
		pcall(function() e.part.Size = Vector3.new(s, s, s) end)
	end
end

-- ================= gyro =================
local spinAngle = 0

local function ensureGyro()
	local _, _, r = alive(LP)
	if not r then return nil end
	if objs.gyro and objs.gyro.Parent == r then return objs.gyro end
	if objs.gyro then objs.gyro:Destroy() end
	local g = Instance.new("BodyGyro")
	g.MaxTorque = Vector3.new(4e4, 4e4, 4e4)
	g.P = 8000
	g.D = Vector3.new(120, 120, 120)
	g.CFrame = r.CFrame
	g.Parent = r
	objs.gyro = g
	return g
end

local function clearGyro()
	if objs.gyro then objs.gyro:Destroy() objs.gyro = nil end
end

-- ================= joueur =================
local origSpeed, origJump, origUseJP, origCamType

local function setFly(on)
	local _, h, r = alive(LP)
	if on then
		if not r or objs.fly then return end
		local bv = Instance.new("BodyVelocity")
		bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
		bv.Velocity = Vector3.zero
		bv.Parent = r
		objs.fly = bv
		if h then pcall(function() h.PlatformStand = true end) end
	else
		if objs.fly then objs.fly:Destroy() objs.fly = nil end
		if h then pcall(function() h.PlatformStand = false end) end
		clearGyro()
	end
end

local function setNoclip(on)
	if objs.nc then objs.nc:Disconnect() objs.nc = nil end
	if on then
		objs.nc = RunService.Stepped:Connect(function()
			local c = LP.Character
			if not c then return end
			for _, v in ipairs(c:GetDescendants()) do
				if v:IsA("BasePart") and v.CanCollide then v.CanCollide = false end
			end
		end)
	end
end

local function setSpeed(on)
	local _, h = alive(LP)
	if on then if h then origSpeed = h.WalkSpeed end
	elseif h then pcall(function() h.WalkSpeed = origSpeed or 16 end) origSpeed = nil end
end

local function setJump(on)
	local _, h = alive(LP)
	if on then if h then origJump = h.JumpPower origUseJP = h.UseJumpPower end
	elseif h then pcall(function() h.JumpPower = origJump or 50 h.UseJumpPower = origUseJP or false end) origJump, origUseJP = nil, nil end
end

local function setFreeze(on)
	local _, h, r = alive(LP)
	if not r then return end
	pcall(function() r.Anchored = on end)
	if h then pcall(function() h.PlatformStand = on end) end
end

local function applyScale()
	local _, h = alive(LP)
	if not h then return end
	local v = S.Char.scale and S.Char.scalev or 1
	pcall(function()
		if h.BodyHeightScale then h.BodyHeightScale.Value = v end
		if h.BodyWidthScale then h.BodyWidthScale.Value = v end
		if h.BodyDepthScale then h.BodyDepthScale.Value = v end
		if h.HeadScale then h.HeadScale.Value = math.clamp(v, 0.6, 1.6) end
	end)
end

local function setFreecam(on)
	if on then
		origCamType = Camera.CameraType
		Camera.CameraType = Enum.CameraType.Scriptable
	else
		Camera.CameraType = origCamType or Enum.CameraType.Custom
	end
end

-- ================= troll =================
local trollObj = { parts = {}, ghost = {}, lgt = {}, aura = {}, trail = {} }

local function tGhost(on)
	local c = LP.Character
	if on then
		if not c then return end
		for _, v in ipairs(c:GetDescendants()) do
			if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
				trollObj.ghost[v] = v.LocalTransparencyModifier
				pcall(function() v.LocalTransparencyModifier = 1 end)
			end
		end
	else
		for v, t in pairs(trollObj.ghost) do
			pcall(function() if v.Parent then v.LocalTransparencyModifier = t end end)
		end
		trollObj.ghost = {}
	end
end

local function tRagdoll(on)
	local _, h = alive(LP)
	if not h then return end
	if on then
		pcall(function() h.PlatformStand = true h:ChangeState(Enum.HumanoidStateType.Physics) end)
	else
		pcall(function() h.PlatformStand = false h:ChangeState(Enum.HumanoidStateType.GettingUp) end)
	end
end

local function tFog(on)
	if on then
		trollObj.lgt = {
			FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart, Ambient = Lighting.Ambient,
			Brightness = Lighting.Brightness, OutdoorAmbient = Lighting.OutdoorAmbient,
		}
		pcall(function()
			Lighting.FogEnd = 45 Lighting.FogStart = 8
			Lighting.Ambient = Color3.fromRGB(8, 10, 16)
			Lighting.OutdoorAmbient = Color3.fromRGB(10, 14, 22)
			Lighting.Brightness = 0.6
		end)
	else
		local t = trollObj.lgt
		if t.FogEnd then
			pcall(function()
				Lighting.FogEnd = t.FogEnd Lighting.FogStart = t.FogStart
				Lighting.Ambient = t.Ambient Lighting.Brightness = t.Brightness
				Lighting.OutdoorAmbient = t.OutdoorAmbient
			end)
		end
		trollObj.lgt = {}
	end
end

local function tRain(on)
	if on then
		if trollObj.rainConn then return end
		trollObj.rainConn = RunService.Heartbeat:Connect(function()
			if #trollObj.parts > 90 then return end
			local p = Instance.new("Part")
			local s = math.random(2, 5) / 2
			p.Size = Vector3.new(s, s, s)
			p.Anchored = false
			p.CanCollide = true
			p.Color = Color3.fromHSV(math.random(), 0.8, 1)
			p.Material = Enum.Material.Neon
			local base = Camera.CFrame.Position + Camera.CFrame.LookVector * 14
			p.Position = base + Vector3.new(math.random(-18, 18), math.random(10, 22), math.random(-18, 18))
			p.Parent = WS
			trollObj.parts[#trollObj.parts + 1] = p
			task.delay(14, function()
				for i, v in ipairs(trollObj.parts) do
					if v == p then table.remove(trollObj.parts, i) break end
				end
				pcall(function() p:Destroy() end)
			end)
		end)
	else
		if trollObj.rainConn then trollObj.rainConn:Disconnect() trollObj.rainConn = nil end
		for _, p in ipairs(trollObj.parts) do pcall(function() p:Destroy() end) end
		trollObj.parts = {}
	end
end

local function tAura(on)
	for _, v in ipairs(trollObj.aura) do pcall(function() v:Destroy() end) end
	trollObj.aura = {}
	if not on then return end
	for i = 1, 8 do
		local p = Instance.new("Part")
		p.Size = Vector3.new(0.6, 0.6, 0.6)
		p.Anchored = true
		p.CanCollide = false
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromHSV((i - 1) / 8, 0.9, 1)
		p.Parent = WS
		trollObj.aura[i] = p
	end
end

local function tTrail(on)
	if on then
		if trollObj.trailConn then return end
		trollObj.trailConn = RunService.Heartbeat:Connect(function()
			if #trollObj.trail > 60 then
				local old = table.remove(trollObj.trail, 1)
				pcall(function() old:Destroy() end)
			end
			local _, _, r = alive(LP)
			if not r then return end
			local p = Instance.new("Part")
			p.Size = Vector3.new(1.2, 1.2, 1.2)
			p.Anchored = true
			p.CanCollide = false
			p.Material = Enum.Material.Neon
			p.Color = Color3.fromHSV((os.clock() * 0.3) % 1, 0.9, 1)
			p.Position = r.Position
			p.Parent = WS
			trollObj.trail[#trollObj.trail + 1] = p
			task.delay(3, function() pcall(function() p:Destroy() end) end)
		end)
	else
		if trollObj.trailConn then trollObj.trailConn:Disconnect() trollObj.trailConn = nil end
		for _, p in ipairs(trollObj.trail) do pcall(function() p:Destroy() end) end
		trollObj.trail = {}
	end
end

local function tParty(on)
	if on then
		if trollObj.partyConn then return end
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Parent = Lighting
		trollObj.cc = cc
		local hue = 0
		trollObj.partyConn = RunService.Heartbeat:Connect(function()
			hue = (hue + 0.01) % 1
			pcall(function()
				Lighting.Ambient = Color3.fromHSV(hue, 0.7, 1)
				cc.TintColor = Color3.fromHSV((hue + 0.3) % 1, 0.4, 1)
			end)
		end)
	else
		if trollObj.partyConn then trollObj.partyConn:Disconnect() trollObj.partyConn = nil end
		if trollObj.cc then pcall(function() trollObj.cc:Destroy() end) trollObj.cc = nil end
	end
end

local function tConfetti()
	local _, _, r = alive(LP)
	local origin = r and r.Position or Camera.CFrame.Position
	for _ = 1, 45 do
		local p = Instance.new("Part")
		p.Size = Vector3.new(0.5, 0.5, 0.5)
		p.CanCollide = false
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromHSV(math.random(), 0.9, 1)
		p.Position = origin + Vector3.new(math.random(-3, 3), 2, math.random(-3, 3))
		p.Parent = WS
		p.AssemblyLinearVelocity = Vector3.new(math.random(-40, 40), math.random(30, 70), math.random(-40, 40))
		task.delay(5, function() pcall(function() p:Destroy() end) end)
	end
end

local function tFollow(on)
	local _, h, r = alive(LP)
	if on then
		if not r or objs.follow then return end
		local bv = Instance.new("BodyVelocity")
		bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
		bv.Parent = r
		objs.follow = bv
	else
		if objs.follow then objs.follow:Destroy() objs.follow = nil end
	end
end

local function pickPlayer(random)
	local _, _, myRoot = alive(LP)
	if not myRoot then return nil end
	if random then
		local l = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LP and alive(p) then l[#l + 1] = p end
		end
		if #l == 0 then return nil end
		return l[math.random(1, #l)]
	end
	local best, bd = nil, math.huge
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP then
			local _, _, r = alive(p)
			if r then
				local d = (r.Position - myRoot.Position).Magnitude
				if d < bd then bd = d best = p end
			end
		end
	end
	return best
end

local function tTeleport(random)
	local p = pickPlayer(random)
	if not p then return end
	local _, _, myRoot = alive(LP)
	local _, _, tr = alive(p)
	if myRoot and tr then myRoot.CFrame = tr.CFrame * CFrame.new(0, 0, 3) end
end

local function tJumpscare()
	local layer = new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0, ZIndex = 150,
	}, gui)
	local txt = new("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "SMOOTH.DEV",
		TextColor3 = C.accent, Font = Enum.Font.GothamBlack, TextSize = 130, ZIndex = 151,
	}, layer)
	Tween:Create(txt, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextSize = 96 }):Play()

	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://131961136"
	s.Volume = 4
	s.Parent = SoundSvc
	pcall(function() s:Play() end)

	task.delay(0.85, function()
		Tween:Create(layer, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		Tween:Create(txt, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
	end)
	task.delay(1.3, function() pcall(function() layer:Destroy() s:Destroy() end) end)
end

local function tSit(on)
	local _, h = alive(LP)
	if h then pcall(function() h.Sit = on end) end
end

local function tAfk(on)
	if objs.afk then objs.afk:Disconnect() objs.afk = nil end
	if on then
		objs.afk = LP.Idled:Connect(function()
			pcall(function()
				VIM:CaptureController()
				VIM:ClickButton2(Vector2.zero)
			end)
		end)
	end
end

-- ================= boucle =================
local fps = 0
local fpsAcc, fpsTime = 0, 0

track(RunService.RenderStepped:Connect(function(dt)
	if dead then return end

	fpsAcc = fpsAcc + 1
	fpsTime = fpsTime + dt
	if fpsTime >= 0.5 then
		fps = math.floor(fpsAcc / fpsTime)
		fpsAcc, fpsTime = 0, 0
	end

	pcall(function()
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LP then
				if not drawESP(p) then killESP(p) end
			end
		end
	end)

	local aiming = S.Aimbot.on and UIS:IsKeyDown(S.Aimbot.key)
	local silent = S.Silent.on and UIS:IsKeyDown(S.Silent.key)

	if silent then
		local p = target(S.Silent)
		if p then applyAim(p, true) end
	elseif aiming or S.Aimbot.trigger then
		local p = target(S.Aimbot)
		if p then
			applyAim(p, S.Aimbot.instant)
			if S.Aimbot.autofire then fire() end
		end
	end

	if S.Char.fly and objs.fly then
		local _, _, r = alive(LP)
		if r then
			local d = Vector3.zero
			if UIS:IsKeyDown(Enum.KeyCode.W) then d = d + Camera.CFrame.LookVector end
			if UIS:IsKeyDown(Enum.KeyCode.S) then d = d - Camera.CFrame.LookVector end
			if UIS:IsKeyDown(Enum.KeyCode.D) then d = d + Camera.CFrame.RightVector end
			if UIS:IsKeyDown(Enum.KeyCode.A) then d = d - Camera.CFrame.RightVector end
			if UIS:IsKeyDown(Enum.KeyCode.Space) then d = d + Vector3.yAxis end
			if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then d = d - Vector3.yAxis end
			if d.Magnitude > 0 then objs.fly.Velocity = d.Unit * S.Char.sv
			else objs.fly.Velocity = Vector3.zero end
		end
	end

	if S.Troll.spin or S.Char.fly then
		local g = ensureGyro()
		if g and g.Parent then
			local pos = g.Parent.Position
			if S.Troll.spin then
				spinAngle = (spinAngle + math.rad(S.Troll.spinspd) * dt) % (math.pi * 2)
				g.CFrame = CFrame.new(pos) * CFrame.Angles(0, spinAngle, 0)
			else
				local look = Camera.CFrame.LookVector
				local flat = Vector3.new(look.X, 0, look.Z)
				if flat.Magnitude < 0.02 then flat = Vector3.new(0, 0, -1) end
				g.CFrame = CFrame.lookAt(pos, pos + flat.Unit)
			end
		end
	elseif objs.gyro then
		clearGyro()
	end

	if S.Cam.free then
		local d = Vector3.zero
		if UIS:IsKeyDown(Enum.KeyCode.W) then d = d + Camera.CFrame.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.S) then d = d - Camera.CFrame.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.D) then d = d + Camera.CFrame.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.A) then d = d - Camera.CFrame.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.Space) then d = d + Vector3.yAxis end
		if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then d = d - Vector3.yAxis end
		if d.Magnitude > 0 then Camera.CFrame = Camera.CFrame + d.Unit * (S.Cam.freespd * dt) end
	end

	if S.Cam.orbit then
		local _, _, r = alive(LP)
		if r then
			local a = math.rad(os.clock() * S.Cam.orbitspd)
			local pos = r.Position + Vector3.new(math.cos(a) * S.Cam.orbitr, 4, math.sin(a) * S.Cam.orbitr)
			Camera.CFrame = CFrame.lookAt(pos, r.Position)
		end
	end

	if S.Troll.aura and #trollObj.aura > 0 then
		local _, _, r = alive(LP)
		if r then
			local t = os.clock() * 2
			for i, v in ipairs(trollObj.aura) do
				local a = t + (i - 1) * (math.pi * 2 / #trollObj.aura)
				pcall(function()
					v.CFrame = CFrame.new(r.Position + Vector3.new(math.cos(a) * 2.6, math.sin(t + i) * 0.6 + 1, math.sin(a) * 2.6))
				end)
			end
		end
	end

	if S.Troll.follow and objs.follow then
		local _, _, r = alive(LP)
		local p = pickPlayer(false)
		local _, _, tr = alive(p or LP)
		if r and tr and p and tr ~= r then
			local d = tr.Position - r.Position
			if d.Magnitude > 6 then objs.follow.Velocity = d.Unit * math.min(d.Magnitude * 2, 90)
			else objs.follow.Velocity = Vector3.zero end
		end
	end

	if S.Troll.shake then
		local i = S.Troll.shakei
		Camera.CFrame = Camera.CFrame * CFrame.new(
			(math.random() - 0.5) * i / 30, (math.random() - 0.5) * i / 30, 0)
	end
end))

task.spawn(function()
	local hue = 0
	while not dead do
		RunService.RenderStepped:Wait()
		if S.Troll.rainbow then
			hue = (hue + 0.004) % 1
			local c = LP.Character
			if c then
				for _, v in ipairs(c:GetDescendants()) do
					if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
						pcall(function() v.Color = Color3.fromHSV(hue, 0.85, 1) end)
					end
				end
			end
		end
	end
end)

task.spawn(function()
	while not dead do
		task.wait(0.35)
		if dead then break end
		pcall(function()
			local _, h = alive(LP)
			if h then
				if S.Char.speed then h.WalkSpeed = S.Char.sv end
				if S.Char.jump then h.UseJumpPower = true h.JumpPower = S.Char.jv end
			end
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= LP and S.HB.on then applyHB(p) else restoreHB(p) end
			end
		end)
	end
end)

-- ================= fenêtre =================
local ring = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(220, 220), BackgroundTransparency = 1, BorderSizePixel = 0,
	ZIndex = 50, Visible = false,
}, gui)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
new("UIStroke", { Color = C.accent, Thickness = 1, Transparency = 0.5 }, ring)

local win = new("Frame", {
	Size = UDim2.fromOffset(600, 440),
	Position = UDim2.fromOffset(50, 90),
	BackgroundColor3 = C.shell,
	BorderSizePixel = 0, Active = true, ZIndex = 10,
	Visible = false, BackgroundTransparency = 1,
}, gui)
round(win, 14)
new("UIStroke", { Color = C.line, Thickness = 1 }, win)
local winScale = new("UIScale", { Scale = 0.94 }, win)

-- halo de fond
local glow = new("Frame", {
	Size = UDim2.fromOffset(280, 280),
	Position = UDim2.fromOffset(-90, -90),
	BackgroundColor3 = C.accent2,
	BackgroundTransparency = 0.94,
	BorderSizePixel = 0,
	ZIndex = 10,
}, win)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, glow)
glow.ZIndex = 10

-- sidebar
local side = new("Frame", {
	Size = UDim2.new(0, 176, 1, 0),
	BackgroundColor3 = C.ink,
	BackgroundTransparency = 0.35,
	BorderSizePixel = 0,
	ZIndex = 11,
}, win)
round(side, 14)
new("Frame", {
	Size = UDim2.new(0, 14, 1, 0), Position = UDim2.fromScale(1, 0),
	AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = C.ink,
	BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 11,
}, side)

local dragZone = new("TextButton", {
	Size = UDim2.new(1, 0, 0, 74), BackgroundTransparency = 1,
	Text = "", AutoButtonColor = false, ZIndex = 30,
}, side)

local logo = new("TextLabel", {
	Size = UDim2.new(1, -28, 0, 18), Position = UDim2.fromOffset(16, 18),
	BackgroundTransparency = 1, Text = "SMOOTH",
	TextColor3 = C.text, Font = Enum.Font.GothamBlack, TextSize = 17,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13,
}, side)
grad(logo, C.text, C.accent)

new("TextLabel", {
	Size = UDim2.new(1, -28, 0, 14), Position = UDim2.fromOffset(16, 37),
	BackgroundTransparency = 1, Text = ".dev  ·  v10",
	TextColor3 = C.sub, Font = Enum.Font.Gotham, TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13,
}, side)

-- recherche
local searchBox = new("Frame", {
	Size = UDim2.new(1, -28, 0, 26), Position = UDim2.fromOffset(14, 58),
	BackgroundColor3 = C.card, BorderSizePixel = 0, ZIndex = 13,
}, side)
round(searchBox, 7)
local searchStroke = new("UIStroke", { Color = C.line, Thickness = 1 }, searchBox)
new("TextLabel", {
	Size = UDim2.fromOffset(16, 26), Position = UDim2.fromOffset(7, 0),
	BackgroundTransparency = 1, Text = "⌕", TextColor3 = C.sub,
	Font = Enum.Font.GothamBold, TextSize = 13, ZIndex = 14,
}, searchBox)
local searchInput = new("TextBox", {
	Size = UDim2.new(1, -26, 1, 0), Position = UDim2.fromOffset(24, 0),
	BackgroundTransparency = 1, Text = "", PlaceholderText = "Rechercher",
	PlaceholderColor3 = C.sub, TextColor3 = C.text,
	Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
	ClearTextOnFocus = false, ZIndex = 14,
}, searchBox)

-- onglets
local tabHolder = new("Frame", {
	Size = UDim2.new(1, -20, 0, 280), Position = UDim2.fromOffset(10, 96),
	BackgroundTransparency = 1, ZIndex = 13,
}, side)
new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, tabHolder)

local indicator = new("Frame", {
	Size = UDim2.fromOffset(3, 18), Position = UDim2.fromOffset(0, 11),
	BackgroundColor3 = C.accent, BorderSizePixel = 0, ZIndex = 15,
}, tabHolder)
round(indicator, 2)
grad(indicator, C.accent, C.accent2, 90)

local foot = new("Frame", {
	Size = UDim2.new(1, -20, 0, 52), Position = UDim2.new(0, 10, 1, -62),
	BackgroundTransparency = 1, ZIndex = 13,
}, side)
new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, foot)

new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1,
	Text = "INSERT  ·  menu\nR-SHIFT  ·  unload",
	TextColor3 = Color3.fromRGB(78, 88, 102), Font = Enum.Font.Gotham, TextSize = 9,
	TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, ZIndex = 14,
}, foot)

-- header contenu
local head = new("Frame", {
	Size = UDim2.new(1, -200, 0, 52), Position = UDim2.fromOffset(190, 16),
	BackgroundTransparency = 1, ZIndex = 12,
}, win)

local headTitle = new("TextLabel", {
	Size = UDim2.new(1, -90, 0, 20), BackgroundTransparency = 1, Text = "",
	TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 15,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13,
}, head)

local headSub = new("TextLabel", {
	Size = UDim2.new(1, -90, 0, 14), Position = UDim2.fromOffset(0, 20),
	BackgroundTransparency = 1, Text = "",
	TextColor3 = C.sub, Font = Enum.Font.Gotham, TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13,
}, head)

local minBtn = new("TextButton", {
	Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -54, 0, 16),
	BackgroundColor3 = C.card, Text = "–", TextColor3 = C.text,
	Font = Enum.Font.GothamBold, TextSize = 13, BorderSizePixel = 0,
	AutoButtonColor = false, ZIndex = 14,
}, win)
round(minBtn, 7)

local xBtn = new("TextButton", {
	Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -26, 0, 16),
	BackgroundColor3 = C.card, Text = "X", TextColor3 = C.bad,
	Font = Enum.Font.GothamBold, TextSize = 11, BorderSizePixel = 0,
	AutoButtonColor = false, ZIndex = 14,
}, win)
round(xBtn, 7)

local content = new("Frame", {
	Size = UDim2.new(1, -206, 1, -86), Position = UDim2.fromOffset(190, 64),
	BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 12,
}, win)

-- ================= cartes =================
local function makeCard(pane, title, sub, order, h)
	local r = new("Frame", {
		Size = UDim2.new(1, -10, 0, h or 46),
		BackgroundColor3 = C.card, BorderSizePixel = 0, LayoutOrder = order, ZIndex = 13,
	}, pane)
	round(r, 10)
	local stroke = new("UIStroke", { Color = C.line, Thickness = 1 }, r)
	local sc = new("UIScale", { Scale = 1 }, r)

	local t = new("TextLabel", {
		Size = UDim2.new(1, -110, 0, 15), Position = UDim2.fromOffset(13, 9),
		BackgroundTransparency = 1, Text = title,
		TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 14,
	}, r)

	local s = new("TextLabel", {
		Size = UDim2.new(1, -110, 0, 13), Position = UDim2.fromOffset(13, 24),
		BackgroundTransparency = 1, Text = sub or "",
		TextColor3 = C.sub, Font = Enum.Font.Gotham, TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 14,
	}, r)

	local ctrl = new("Frame", {
		Size = UDim2.fromOffset(0, 0), AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0), BackgroundTransparency = 1, ZIndex = 14,
	}, r)

	cards[#cards + 1] = { frame = r, text = string.lower(title) }

	r.MouseEnter:Connect(function()
		Tween:Create(r, T_FAST, { BackgroundColor3 = C.cardHi }):Play()
		Tween:Create(stroke, T_FAST, { Color = Color3.fromRGB(48, 60, 76) }):Play()
		Tween:Create(sc, T_SMOOTH, { Scale = 1.008 }):Play()
	end)
	r.MouseLeave:Connect(function()
		Tween:Create(r, T_FAST, { BackgroundColor3 = C.card }):Play()
		Tween:Create(stroke, T_FAST, { Color = C.line }):Play()
		Tween:Create(sc, T_SMOOTH, { Scale = 1 }):Play()
	end)

	return r, ctrl, sc, stroke, t, s
end

local function sectionCard(pane, txt, order)
	local r = new("Frame", {
		Size = UDim2.new(1, -10, 0, 22), BackgroundTransparency = 1,
		LayoutOrder = order, ZIndex = 13,
	}, pane)
	new("TextLabel", {
		Size = UDim2.fromOffset(180, 22), BackgroundTransparency = 1,
		Text = string.upper(txt), TextColor3 = Color3.fromRGB(96, 108, 124),
		Font = Enum.Font.GothamBold, TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 14,
	}, r)
	local ln = new("Frame", {
		Size = UDim2.new(1, -190, 0, 1), Position = UDim2.new(0, 188, 0.5, 0),
		BackgroundColor3 = C.line, BorderSizePixel = 0, ZIndex = 14,
	}, r)
	grad(ln, C.line, C.ink)
end

local function switchCtrl(ctrl, tbl, key, cb)
	local pill = new("Frame", {
		Size = UDim2.fromOffset(40, 20), AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0), BackgroundColor3 = Color3.fromRGB(36, 42, 52),
		BorderSizePixel = 0, ZIndex = 15,
	}, ctrl)
	round(pill, 10)
	local knob = new("Frame", {
		Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(3, 3),
		BackgroundColor3 = Color3.fromRGB(126, 138, 154), BorderSizePixel = 0, ZIndex = 16,
	}, pill)
	round(knob, 7)
	local halo = new("UIStroke", { Color = C.accent, Thickness = 1.5, Transparency = 1 }, pill)

	local function paint(anim)
		local on = tbl[key]
		Tween:Create(pill, anim and T_SPRING or T_FAST, {
			BackgroundColor3 = on and C.accent2 or Color3.fromRGB(36, 42, 52),
		}):Play()
		Tween:Create(knob, anim and T_SPRING or T_FAST, {
			Position = on and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3),
			BackgroundColor3 = on and C.accent or Color3.fromRGB(126, 138, 154),
		}):Play()
		Tween:Create(halo, T_FAST, { Transparency = on and 0.4 or 1 }):Play()
	end

	pill.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			playClick()
			tbl[key] = not tbl[key]
			paint(true)
			if cb then cb(tbl[key]) end
		end
	end)

	paint(false)
	refreshers[#refreshers + 1] = function() paint(false) end
end

local function toggleCard(pane, title, sub, tbl, key, order, cb)
	local r, ctrl = makeCard(pane, title, sub, order)
	local b = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 14 }, r)
	switchCtrl(ctrl, tbl, key, cb)
	b.MouseButton1Click:Connect(function()
		playClick()
		tbl[key] = not tbl[key]
		for _, f in ipairs(refreshers) do end
		local on = tbl[key]
		ctrl:FindFirstChildOfClass("Frame").BackgroundColor3 = on and C.accent2 or Color3.fromRGB(36, 42, 52)
		if cb then cb(on) end
	end)
end

local function sliderCard(pane, title, sub, tbl, key, mn, mx, order, cb)
	local r, ctrl = makeCard(pane, title, sub, order, 62)
	local chip = new("Frame", {
		Size = UDim2.fromOffset(46, 18), AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 9), BackgroundColor3 = Color3.fromRGB(24, 29, 37),
		BorderSizePixel = 0, ZIndex = 15,
	}, ctrl)
	round(chip, 5)
	local val = new("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
		TextColor3 = C.accent, Font = Enum.Font.GothamBold, TextSize = 10, ZIndex = 16,
	}, chip)
	local trk = new("Frame", {
		Size = UDim2.new(1, -26, 0, 4), Position = UDim2.fromOffset(13, 46),
		BackgroundColor3 = Color3.fromRGB(34, 40, 49), BorderSizePixel = 0, ZIndex = 15,
	}, r)
	round(trk, 2)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.accent, BorderSizePixel = 0, ZIndex = 16 }, trk)
	round(fill, 2)
	grad(fill, C.accent2, C.accent)
	local dot = new("Frame", {
		Size = UDim2.fromOffset(10, 10), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = Color3.fromRGB(238, 247, 255),
		BorderSizePixel = 0, ZIndex = 17,
	}, trk)
	round(dot, 5)

	local function apply(v, anim)
		v = math.clamp(v, mn, mx)
		local a = (v - mn) / (mx - mn)
		Tween:Create(fill, anim and T_FAST or T_SMOOTH, { Size = UDim2.fromScale(a, 1) }):Play()
		Tween:Create(dot, anim and T_FAST or T_SMOOTH, { Position = UDim2.fromScale(a, 0.5) }):Play()
		val.Text = tostring(math.floor(v * 100) / 100)
		tbl[key] = math.floor(v * 100) / 100
		if cb then cb(tbl[key]) end
	end

	trk.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			playClick()
			objs.drag = { trk, function(v) apply(v, true) end, mn, mx }
		end
	end)
	apply(tbl[key], false)
	refreshers[#refreshers + 1] = function() apply(tbl[key], false) end
end

local function keyCard(pane, title, sub, tbl, key, order)
	local r, ctrl = makeCard(pane, title, sub, order)
	local chip = new("Frame", {
		Size = UDim2.fromOffset(60, 20), AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0), BackgroundColor3 = Color3.fromRGB(24, 29, 37),
		BorderSizePixel = 0, ZIndex = 15,
	}, ctrl)
	round(chip, 5)
	new("UIStroke", { Color = C.line, Thickness = 1 }, chip)
	local b = new("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		Text = tbl[key].Name, TextColor3 = C.accent,
		Font = Enum.Font.GothamBold, TextSize = 10, ZIndex = 16,
	}, chip)
	local wait = false
	b.MouseButton1Click:Connect(function()
		playClick()
		press(r)
		wait = true
		b.Text = "..."
	end)
	track(UIS.InputBegan:Connect(function(inp, gp)
		if wait and not gp and inp.UserInputType == Enum.UserInputType.Keyboard then
			playClick()
			tbl[key] = inp.KeyCode
			b.Text = inp.KeyCode.Name
			wait = false
		end
	end))
	refreshers[#refreshers + 1] = function() b.Text = tbl[key].Name end
end

local function cycleCard(pane, title, sub, tbl, key, list, order)
	local r, ctrl = makeCard(pane, title, sub, order)
	local chip = new("Frame", {
		Size = UDim2.fromOffset(74, 20), AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0), BackgroundColor3 = Color3.fromRGB(24, 29, 37),
		BorderSizePixel = 0, ZIndex = 15,
	}, ctrl)
	round(chip, 5)
	new("UIStroke", { Color = C.line, Thickness = 1 }, chip)
	local b = new("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		Text = tostring(tbl[key]), TextColor3 = C.accent,
		Font = Enum.Font.GothamBold, TextSize = 10, ZIndex = 16,
	}, chip)
	b.MouseButton1Click:Connect(function()
		playClick()
		press(r)
		local idx = 1
		for k, v in ipairs(list) do if v == tbl[key] then idx = k break end end
		idx = (idx % #list) + 1
		tbl[key] = list[idx]
		b.Text = tostring(tbl[key])
	end)
	refreshers[#refreshers + 1] = function() b.Text = tostring(tbl[key]) end
end

local function actionCard(pane, title, sub, cb, order, col)
	local r, ctrl = makeCard(pane, title, sub, order)
	local b = new("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 14,
	}, r)
	local arrow = new("TextLabel", {
		Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0), BackgroundTransparency = 1,
		Text = "›", TextColor3 = col or C.accent,
		Font = Enum.Font.GothamBold, TextSize = 16, ZIndex = 15,
	}, ctrl)
	b.MouseButton1Click:Connect(function()
		playClick()
		press(r)
		cb()
	end)
	return arrow
end

-- ================= onglets =================
local currentPane
local function selectTab(i)
	local rec = tabs[i]
	if not rec then return end
	for k, o in ipairs(tabs) do
		o.pane.Visible = (k == i)
		Tween:Create(o.icon, T_FAST, { TextColor3 = (k == i) and C.accent or C.sub }):Play()
		Tween:Create(o.label, T_FAST, { TextColor3 = (k == i) and C.text or C.sub }):Play()
		Tween:Create(o.btn, T_FAST, { BackgroundColor3 = (k == i) and C.card or C.ink }):Play()
		Tween:Create(o.btn, T_FAST, { BackgroundTransparency = (k == i) and 0 or 1 }):Play()
	end
	Tween:Create(indicator, T_CIRC, { Position = UDim2.fromOffset(0, (i - 1) * 44 + 11) }):Play()
	headTitle.Text = rec.name
	headSub.Text = rec.sub
	currentPane = rec.pane
	-- entrée en cascade
	local n = 0
	for _, ch in ipairs(rec.pane:GetChildren()) do
		if ch:IsA("Frame") and ch:FindFirstChildOfClass("UIScale") then
			n = n + 1
			local sc = ch:FindFirstChildOfClass("UIScale")
			sc.Scale = 0.96
			local stroke = ch:FindFirstChildOfClass("UIStroke")
			if stroke then stroke.Transparency = 1 end
			task.delay(n * 0.018, function()
				if sc.Parent then
					Tween:Create(sc, T_SPRING, { Scale = 1 }):Play()
					if stroke then Tween:Create(stroke, T_SMOOTH, { Transparency = 0 }):Play() end
				end
			end)
		end
	end
end

local function makeTab(name, icon, sub, order)
	local b = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = C.ink,
		BackgroundTransparency = 1, Text = "", BorderSizePixel = 0,
		AutoButtonColor = false, LayoutOrder = order, ZIndex = 14,
	}, tabHolder)
	round(b, 8)

	local ic = new("TextLabel", {
		Size = UDim2.fromOffset(16, 40), Position = UDim2.fromOffset(13, 0),
		BackgroundTransparency = 1, Text = icon, TextColor3 = C.sub,
		Font = Enum.Font.GothamBold, TextSize = 12, ZIndex = 15,
	}, b)

	local lb = new("TextLabel", {
		Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(35, 0),
		BackgroundTransparency = 1, Text = name, TextColor3 = C.sub,
		Font = Enum.Font.GothamMedium, TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 15,
	}, b)

	local pane = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 2, ScrollBarImageColor3 = Color3.fromRGB(46, 55, 68),
		CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false, ZIndex = 13,
	}, content)
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, pane)

	tabs[#tabs + 1] = { btn = b, pane = pane, name = name, sub = sub, icon = ic, label = lb }
	b.MouseButton1Click:Connect(function()
		playClick()
		selectTab(#tabs and (function()
			for k, o in ipairs(tabs) do if o.btn == b then return k end end
		end)())
	end)
	return pane
end

-- ================= recherche =================
searchInput:GetPropertyChangedSignal("Text"):Connect(function()
	local q = string.lower(searchInput.Text)
	if not currentPane then return end
	for _, rec in ipairs(cards) do
		if rec.frame.Parent == currentPane then
			rec.frame.Visible = (q == "" or string.find(rec.text, q, 1, true) ~= nil)
		end
	end
	Tween:Create(searchStroke, T_FAST, { Color = (q ~= "") and C.accent or C.line }):Play()
end)

-- ================= profil =================
local profilePane = makeTab("Profil", "◉", "votre compte et la session", 1)

local pCard = new("Frame", {
	Size = UDim2.new(1, -10, 0, 92), BackgroundColor3 = C.card, BorderSizePixel = 0, LayoutOrder = 1, ZIndex = 13,
}, profilePane)
round(pCard, 10)
new("UIStroke", { Color = C.accent, Transparency = 0.72, Thickness = 1 }, pCard)

local avatar = new("ImageLabel", {
	Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(14, 14),
	BackgroundColor3 = Color3.fromRGB(22, 25, 31), BorderSizePixel = 0,
	Image = "rbxthumb://type=AvatarHeadShot&id=" .. LP.UserId .. "&w=150&h=150", ZIndex = 14,
}, pCard)
round(avatar, 10)

new("TextLabel", {
	Size = UDim2.new(1, -108, 0, 18), Position = UDim2.fromOffset(90, 20),
	BackgroundTransparency = 1, Text = LP.DisplayName,
	TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 14,
}, pCard)

new("TextLabel", {
	Size = UDim2.new(1, -108, 0, 14), Position = UDim2.fromOffset(90, 38),
	BackgroundTransparency = 1, Text = "@" .. LP.Name,
	TextColor3 = C.accent, Font = Enum.Font.GothamMedium, TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 14,
}, pCard)

local online = new("Frame", {
	Size = UDim2.fromOffset(6, 6), Position = UDim2.fromOffset(91, 58),
	BackgroundColor3 = C.ok, BorderSizePixel = 0, ZIndex = 14,
}, pCard)
round(online, 3)
new("TextLabel", {
	Size = UDim2.fromOffset(100, 14), Position = UDim2.fromOffset(102, 54),
	BackgroundTransparency = 1, Text = "connecte",
	TextColor3 = Color3.fromRGB(110, 190, 158), Font = Enum.Font.Gotham, TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 14,
}, pCard)

local function statCard(label, order)
	local r, ctrl = makeCard(profilePane, label, "", order, 32)
	local v = new("TextLabel", {
		Size = UDim2.new(1, -110, 1, 0), AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0), BackgroundTransparency = 1,
		Text = "-", TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 15,
	}, ctrl)
	-- sous-titre masqué, label recentré
	local sub = r:FindFirstChild("TextLabel")
	return v
end

sectionCard(profilePane, "Informations", 2)
local vId = statCard("Identifiant", 3)
local vAge = statCard("Anciennete du compte", 4)
local vTeam = statCard("Equipe", 5)
sectionCard(profilePane, "Session", 6)
local vHealth = statCard("Vie", 7)
local vPing = statCard("Ping", 8)
local vFps = statCard("Images par seconde", 9)
local vPlayers = statCard("Joueurs du serveur", 10)
sectionCard(profilePane, "Position", 11)
local vPos = statCard("Coordonnees", 12)
local vPlace = statCard("Experience", 13)

vId.Text = tostring(LP.UserId)
vAge.Text = LP.AccountAge .. " jours"
vPlace.Text = tostring(game.PlaceId)

task.spawn(function()
	while not dead do
		task.wait(0.5)
		if dead then break end
		pcall(function()
			local _, h, r = alive(LP)
			vTeam.Text = (LP.Team and LP.Team.Name) or "Aucune"
			vHealth.Text = h and (math.floor(h.Health) .. " / " .. math.floor(h.MaxHealth)) or "-"
			local ping = 0
			pcall(function() ping = math.floor((LP:GetNetworkPing() or 0) * 1000) end)
			vPing.Text = ping .. " ms"
			vFps.Text = tostring(fps)
			vPlayers.Text = tostring(#Players:GetPlayers())
			vPos.Text = r and string.format("%d, %d, %d", math.floor(r.Position.X), math.floor(r.Position.Y), math.floor(r.Position.Z)) or "-"
		end)
	end
end)

-- ================= contenu des onglets =================
local combat = makeTab("Combat", "⌖", "visee et assistance de tir", 2)
sectionCard(combat, "Aimbot", 1)
toggleCard(combat, "Aimbot", "Active la visee automatique", S.Aimbot, "on", 2)
keyCard(combat, "Touche aimbot", "Maintenir pour viser", S.Aimbot, "key", 3)
toggleCard(combat, "Verif equipe", "Ignore les coequipiers", S.Aimbot, "team", 4)
toggleCard(combat, "Ignore knocked", "Saute les joueurs au sol", S.Aimbot, "ignoreknock", 5)
cycleCard(combat, "Partie visee", "Os cible par la visee", S.Aimbot, "part", { "Head", "Nearest", "Random", "Torso" }, 6)
sliderCard(combat, "FOV", "Champ de detection", S.Aimbot, "fov", 20, 500, 7)
sliderCard(combat, "Lissage", "Douceur du suivi", S.Aimbot, "smooth", 0.05, 1, 8)
sliderCard(combat, "Prediction", "Anticipation du mouvement", S.Aimbot, "pred", 0, 1, 9)
sliderCard(combat, "Distance max", "Portee de la visee", S.Aimbot, "maxd", 50, 3000, 10)
sectionCard(combat, "Rage", 11)
toggleCard(combat, "Snap instantane", "Visee sans interpolation", S.Aimbot, "instant", 12)
toggleCard(combat, "Auto fire", "Tire des que la cible est prise", S.Aimbot, "autofire", 13)
sliderCard(combat, "Delai tir", "Intervalle entre les tirs", S.Aimbot, "firedelay", 0.02, 0.5, 14)
toggleCard(combat, "Trigger bot", "Vise sans maintenir la touche", S.Aimbot, "trigger", 15)
toggleCard(combat, "Wall check", "Cible uniquement a vue", S.Aimbot, "vis", 16)
toggleCard(combat, "Hitbox expander", "Agrandit la tete des cibles", S.HB, "on", 17)
sliderCard(combat, "Taille hitbox", "Volume de la hitbox", S.HB, "size", 2, 20, 18)
toggleCard(combat, "Cercle FOV", "Affiche le cercle a l ecran", S.ESP, "fovcircle", 19)
sectionCard(combat, "Silent", 20)
toggleCard(combat, "Silent aim", "Correction invisible de la visee", S.Silent, "on", 21)
keyCard(combat, "Touche silent", "Maintenir pour corriger", S.Silent, "key", 22)
toggleCard(combat, "Equipe silent", "Ignore les coequipiers", S.Silent, "team", 23)
sliderCard(combat, "FOV silent", "Champ de detection", S.Silent, "fov", 20, 500, 24)
sliderCard(combat, "Distance silent", "Portee du silent", S.Silent, "maxd", 50, 3000, 25)

local visuel = makeTab("Visuel", "◈", "esp et affichage", 3)
sectionCard(visuel, "ESP", 1)
toggleCard(visuel, "ESP actif", "Affiche les joueurs", S.ESP, "on", 2)
toggleCard(visuel, "Boite", "Contour autour de la cible", S.ESP, "box", 3)
toggleCard(visuel, "Remplissage", "Fond translucide", S.ESP, "fill", 4)
toggleCard(visuel, "Pseudo", "Nom au dessus de la cible", S.ESP, "name", 5)
toggleCard(visuel, "Vie", "Barre de vie", S.ESP, "hp", 6)
toggleCard(visuel, "Distance", "Metres jusqu a la cible", S.ESP, "dist", 7)
toggleCard(visuel, "Tracer", "Ligne depuis le bas de l ecran", S.ESP, "tracer", 8)
toggleCard(visuel, "Chams", "Surlignage plein", S.ESP, "chams", 9)
toggleCard(visuel, "Verif equipe", "Ignore les coequipiers", S.ESP, "team", 10)
sliderCard(visuel, "Distance max", "Portee de l esp", S.ESP, "maxd", 50, 3000, 11)

local joueur = makeTab("Joueur", "✦", "deplacement et camera", 4)
sectionCard(joueur, "Deplacement", 1)
toggleCard(joueur, "Vitesse", "Modifie la vitesse de marche", S.Char, "speed", 2, setSpeed)
sliderCard(joueur, "Valeur vitesse", "Vitesse appliquee", S.Char, "sv", 16, 300, 3)
toggleCard(joueur, "Saut haut", "Augmente la puissance de saut", S.Char, "jump", 4, setJump)
sliderCard(joueur, "Valeur saut", "Puissance appliquee", S.Char, "jv", 50, 400, 5)
toggleCard(joueur, "Fly", "Vol libre", S.Char, "fly", 6, setFly)
toggleCard(joueur, "Noclip", "Traverse les murs", S.Char, "noclip", 7, setNoclip)
toggleCard(joueur, "Freeze", "Immobilise le personnage", S.Char, "freeze", 8, setFreeze)
sectionCard(joueur, "Camera", 9)
toggleCard(joueur, "Freecam", "Camera detachee", S.Cam, "free", 10, setFreecam)
sliderCard(joueur, "Vitesse freecam", "Vitesse de deplacement", S.Cam, "freespd", 10, 300, 11)
toggleCard(joueur, "Orbite", "Camera en rotation autour de vous", S.Cam, "orbit", 12)
sliderCard(joueur, "Rayon orbite", "Distance de rotation", S.Cam, "orbitr", 5, 60, 13)
sliderCard(joueur, "Vitesse orbite", "Vitesse de rotation", S.Cam, "orbitspd", 10, 400, 14)
sectionCard(joueur, "Personnage", 15)
toggleCard(joueur, "Taille custom", "Modifie l echelle du corps", S.Char, "scale", 16, applyScale)
sliderCard(joueur, "Echelle", "Facteur de taille", S.Char, "scalev", 0.4, 3, 17, function() if S.Char.scale then applyScale() end end)

local troll = makeTab("Troll", "✧", "effets et actions", 5)
sectionCard(troll, "Animation", 1)
toggleCard(troll, "Spin", "Rotation continue du corps", S.Troll, "spin", 2)
sliderCard(troll, "Vitesse spin", "Vitesse de rotation", S.Troll, "spinspd", 40, 900, 3)
toggleCard(troll, "Ragdoll", "Personnage mou", S.Troll, "ragdoll", 4, tRagdoll)
toggleCard(troll, "Arc-en-ciel", "Cycle de couleurs", S.Troll, "rainbow", 5)
toggleCard(troll, "Invisible", "Corps transparent en local", S.Troll, "ghost", 6, tGhost)
toggleCard(troll, "Aura", "Particules en orbite", S.Troll, "aura", 7, tAura)
toggleCard(troll, "Trainee", "Sillage colore", S.Troll, "trail", 8, tTrail)
toggleCard(troll, "S'asseoir", "Force la position assise", S.Troll, "sit", 9, tSit)
sectionCard(troll, "Ambiance", 10)
toggleCard(troll, "Pluie de parts", "Blocs qui tombent autour de vous", S.Troll, "rain", 11, tRain)
toggleCard(troll, "Camera shake", "Tremblement de camera", S.Troll, "shake", 12)
sliderCard(troll, "Intensite shake", "Force du tremblement", S.Troll, "shakei", 0.2, 6, 13)
toggleCard(troll, "Nuit / brouillard", "Assombrit la scene", S.Troll, "fog", 14, tFog)
toggleCard(troll, "Party lights", "Lumieres colorees", S.Troll, "party", 15, tParty)
sectionCard(troll, "Actions", 16)
toggleCard(troll, "Suivre joueur", "Colle le joueur le plus proche", S.Troll, "follow", 17, tFollow)
toggleCard(troll, "Anti-AFK", "Evite l exclusion", S.Troll, "afk", 18, tAfk)
actionCard(troll, "Teleport au plus proche", "Va vers le joueur le plus proche", function() tTeleport(false) end, 19)
actionCard(troll, "Teleport aleatoire", "Va vers un joueur au hasard", function() tTeleport(true) end, 20)
actionCard(troll, "Confettis", "Explosion de blocs colores", tConfetti, 21)
actionCard(troll, "Jumpscare", "Flash plein ecran", tJumpscare, 22)

local divers = makeTab("Divers", "⚙", "raccourcis et maintenance", 6)
sectionCard(divers, "Raccourcis", 1)
actionCard(divers, "Insert", "Ouvre ou ferme le menu", function() end, 2)
actionCard(divers, "RightShift", "Decharge le script", function() end, 3)
sectionCard(divers, "Maintenance", 4)
actionCard(divers, "Reset toutes les options", "Remet chaque reglage a zero", function()
	setFly(false) setNoclip(false) setFreeze(false)
	tGhost(false) tFog(false) tRain(false) tAura(false) tTrail(false) tParty(false) tAfk(false)
	if S.Cam.free then setFreecam(false) end
	for grp, t in pairs(DEFAULTS) do
		for k, v in pairs(t) do S[grp][k] = v end
	end
	for _, f in ipairs(refreshers) do pcall(f) end
end, 5)
actionCard(divers, "Unload", "Ferme et nettoie tout", Unload, 6, C.bad)

selectTab(1)

-- ================= drag =================
local dragging, dragStart, startPos
dragZone.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = i.Position
		startPos = win.Position
	end
end)

track(UIS.InputChanged:Connect(function(i)
	if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
		local d = i.Position - dragStart
		win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
	if objs.drag and i.UserInputType == Enum.UserInputType.MouseMovement then
		local d = objs.drag
		local w = d[1].AbsoluteSize.X
		if w > 0 then
			local a = math.clamp((i.Position.X - d[1].AbsolutePosition.X) / w, 0, 1)
			d[2](d[3] + a * (d[4] - d[3]))
		end
	end
end))
track(UIS.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		dragging = false
		objs.drag = nil
	end
end))

local minimized = false
minBtn.MouseButton1Click:Connect(function()
	playClick()
	minimized = not minimized
	side.Visible = not minimized
	head.Visible = not minimized
	content.Visible = not minimized
	win.Size = minimized and UDim2.fromOffset(600, 54) or UDim2.fromOffset(600, 440)
end)

track(RunService.RenderStepped:Connect(function()
	if dead then return end
	local aiming = S.Aimbot.on and UIS:IsKeyDown(S.Aimbot.key)
	local silent = S.Silent.on and UIS:IsKeyDown(S.Silent.key)
	ring.Visible = S.ESP.fovcircle or aiming or silent
	local r = silent and S.Silent.fov or S.Aimbot.fov
	ring.Size = UDim2.fromOffset(r * 2, r * 2)
end))

task.spawn(function()
	while not dead do
		task.wait(0.4)
		if dead then break end
		pcall(function()
			if gui.Parent ~= expected then
				if syn and syn.protect_gui then pcall(syn.protect_gui, gui) end
				gui.Parent = expected
			end
			gui.DisplayOrder = 2147483647
		end)
	end
end)

track(LP.CharacterAdded:Connect(function()
	if objs.fly then objs.fly:Destroy() objs.fly = nil end
	if objs.follow then objs.follow:Destroy() objs.follow = nil end
	clearGyro()
	origSpeed, origJump, origUseJP = nil, nil, nil
	trollObj.ghost = {}
	if S.Char.fly then task.delay(0.8, function() if S.Char.fly and not dead then setFly(true) end end) end
	if S.Char.noclip then task.delay(0.3, function() if S.Char.noclip and not dead then setNoclip(true) end end) end
	if S.Char.scale then task.delay(0.8, applyScale) end
end))

track(Players.PlayerRemoving:Connect(function(p) killESP(p) restoreHB(p) end))

function Unload()
	if dead then return end
	dead = true
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	for p in pairs(esp) do killESP(p) end
	for p in pairs(hbStore) do restoreHB(p) end
	if objs.fly then pcall(function() objs.fly:Destroy() end) objs.fly = nil end
	if objs.follow then pcall(function() objs.follow:Destroy() end) objs.follow = nil end
	if objs.nc then pcall(function() objs.nc:Disconnect() end) objs.nc = nil end
	clearGyro()
	if trollObj.rainConn then pcall(function() trollObj.rainConn:Disconnect() end) end
	if trollObj.trailConn then pcall(function() trollObj.trailConn:Disconnect() end) end
	if trollObj.partyConn then pcall(function() trollObj.partyConn:Disconnect() end) end
	for _, p in ipairs(trollObj.parts) do pcall(function() p:Destroy() end) end
	for _, p in ipairs(trollObj.trail) do pcall(function() p:Destroy() end) end
	for _, p in ipairs(trollObj.aura) do pcall(function() p:Destroy() end) end
	if trollObj.cc then pcall(function() trollObj.cc:Destroy() end) end
	tGhost(false)
	tFog(false)
	pcall(function() Camera.CameraType = origCamType or Enum.CameraType.Custom end)
	pcall(function()
		local _, h, r = alive(LP)
		if r then r.Anchored = false end
		if h then
			h.Sit = false
			h.WalkSpeed = origSpeed or 16
			if origJump then h.JumpPower = origJump end
		end
	end)
	pcall(function() gui:Destroy() end)
	getgenv().V = nil
end
getgenv().V = { Unload = Unload }

xBtn.MouseButton1Click:Connect(Unload)

track(UIS.InputBegan:Connect(function(inp, gp)
	if gp then return end
	if inp.KeyCode == Enum.KeyCode.Insert then win.Visible = not win.Visible end
	if inp.KeyCode == Enum.KeyCode.RightShift then Unload() end
end))

-- ================= lancement =================
task.spawn(function()
	local boot = Instance.new("CanvasGroup")
	boot.Size = UDim2.fromScale(1, 1)
	boot.BackgroundColor3 = Color3.fromRGB(4, 5, 8)
	boot.BackgroundTransparency = 0.06
	boot.BorderSizePixel = 0
	boot.GroupTransparency = 1
	boot.ZIndex = 200
	boot.Parent = gui

	local skip = new("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
		AutoButtonColor = false, ZIndex = 220,
	}, boot)

	local card = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 22),
		Size = UDim2.fromOffset(340, 168),
		BackgroundColor3 = C.shell,
		BorderSizePixel = 0, ZIndex = 201, ClipsDescendants = true,
	}, boot)
	round(card, 14)
	local cStroke = new("UIStroke", { Color = C.accent, Transparency = 1, Thickness = 1 }, card)
	local cScale = new("UIScale", { Scale = 0.9 }, card)

	local scan = new("Frame", {
		Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0, -28),
		BackgroundColor3 = C.accent, BackgroundTransparency = 0.92,
		BorderSizePixel = 0, ZIndex = 202,
	}, card)

	local logo2 = new("TextLabel", {
		Size = UDim2.new(1, -36, 0, 30), Position = UDim2.fromOffset(18, 26),
		BackgroundTransparency = 1, Text = "SMOOTH.DEV",
		TextColor3 = C.accent, Font = Enum.Font.GothamBlack, TextSize = 25,
		TextTransparency = 1, ZIndex = 204,
	}, card)

	local line = new("Frame", {
		Size = UDim2.new(0, 0, 0, 2), Position = UDim2.fromOffset(18, 60),
		BackgroundColor3 = C.accent, BorderSizePixel = 0, ZIndex = 204,
	}, card)
	round(line, 1)

	local status = new("TextLabel", {
		Size = UDim2.new(1, -70, 0, 14), Position = UDim2.fromOffset(18, 72),
		BackgroundTransparency = 1, Text = "",
		TextColor3 = C.sub, Font = Enum.Font.Gotham, TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 204,
	}, card)

	local pct = new("TextLabel", {
		Size = UDim2.fromOffset(54, 14), Position = UDim2.new(1, -72, 0, 72),
		BackgroundTransparency = 1, Text = "0%",
		TextColor3 = C.accent, Font = Enum.Font.GothamBold, TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 204,
	}, card)

	local trackF = new("Frame", {
		Size = UDim2.new(1, -36, 0, 3), Position = UDim2.fromOffset(18, 94),
		BackgroundColor3 = Color3.fromRGB(30, 34, 42), BorderSizePixel = 0, ZIndex = 204,
	}, card)
	round(trackF, 2)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.accent, BorderSizePixel = 0, ZIndex = 205 }, trackF)
	round(fill, 2)
	grad(fill, C.accent2, C.accent)

	local dots = {}
	for i = 1, 3 do
		local d = new("Frame", {
			Size = UDim2.fromOffset(4, 4), Position = UDim2.fromOffset(18 + (i - 1) * 9, 110),
			BackgroundColor3 = Color3.fromRGB(48, 54, 64), BorderSizePixel = 0, ZIndex = 204,
		}, card)
		round(d, 2)
		dots[i] = d
	end

	new("TextLabel", {
		Size = UDim2.new(1, -36, 0, 12), Position = UDim2.fromOffset(18, 126),
		BackgroundTransparency = 1, Text = "clic pour passer",
		TextColor3 = Color3.fromRGB(66, 74, 86), Font = Enum.Font.Gotham, TextSize = 9, ZIndex = 204,
	}, card)

	local skipped = false
	skip.MouseButton1Click:Connect(function() skipped = true end)

	task.spawn(function()
		while card.Parent and not skipped do
			for i = 1, 3 do
				local d = dots[i]
				task.spawn(function()
					Tween:Create(d, TweenInfo.new(0.16), { BackgroundColor3 = C.accent }):Play()
					task.wait(0.16)
					if d.Parent then Tween:Create(d, TweenInfo.new(0.3), { BackgroundColor3 = Color3.fromRGB(48, 54, 64) }):Play() end
				end)
				task.wait(0.1)
			end
			task.wait(0.2)
		end
	end)

	task.spawn(function()
		while card.Parent and not skipped do
			scan.Position = UDim2.new(0, 0, 0, -28)
			Tween:Create(scan, TweenInfo.new(1.1, Enum.EasingStyle.Linear), { Position = UDim2.new(0, 0, 0, 168) }):Play()
			task.wait(1.15)
		end
	end)

	Tween:Create(boot, TweenInfo.new(0.28), { GroupTransparency = 0 }):Play()
	Tween:Create(card, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	Tween:Create(cScale, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.wait(0.3)

	Tween:Create(logo2, TweenInfo.new(0.24), { TextTransparency = 0 }):Play()
	Tween:Create(cStroke, TweenInfo.new(0.24), { Transparency = 0.55 }):Play()
	Tween:Create(line, TweenInfo.new(0.36, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.new(1, -36, 0, 2) }):Play()
	task.wait(0.1)

	local steps = { "initialisation du client", "resolution du rig", "chargement de l esp", "liaison du render", "synchronisation" }
	for i = 1, #steps do
		if skipped then break end
		status.Text = steps[i]
		pct.Text = math.floor(i / #steps * 100) .. "%"
		Tween:Create(fill, TweenInfo.new(0.34, Enum.EasingStyle.Quint), { Size = UDim2.fromScale(i / #steps, 1) }):Play()
		task.wait(0.28)
	end

	if not skipped then
		status.Text = "pret"
		pct.Text = "100%"
		Tween:Create(fill, TweenInfo.new(0.14), { Size = UDim2.fromScale(1, 1) }):Play()
		task.wait(0.34)
	end

	Tween:Create(logo2, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
	Tween:Create(card, TweenInfo.new(0.24), { Position = UDim2.new(0.5, 0, 0.5, -18) }):Play()
	Tween:Create(cScale, TweenInfo.new(0.24), { Scale = 1.05 }):Play()
	Tween:Create(boot, TweenInfo.new(0.3), { GroupTransparency = 1 }):Play()
	task.wait(0.26)
	boot:Destroy()

	win.Visible = true
	Tween:Create(winScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	Tween:Create(win, TweenInfo.new(0.34), { BackgroundTransparency = 0 }):Play()
	selectTab(1)
end)

print("[SMOOTH.DEV] loaded")
