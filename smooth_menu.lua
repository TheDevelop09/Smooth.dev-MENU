--[[ SMOOTH.DEV v8
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
local ACC = Color3.fromRGB(0, 214, 255)
local BG  = Color3.fromRGB(14, 14, 18)
local CARD = Color3.fromRGB(30, 30, 38)

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

local conns, esp, objs, hbStore, refreshers = {}, {}, {}, {}, {}
local dead = false
local function track(c) conns[#conns + 1] = c return c end

-- ================= rig-agnostique =================
local function getHum(c)
	if not c then return nil end
	local h = c:FindFirstChildOfClass("Humanoid")
	if h then return h end
	return c:FindFirstChildWhichIsA("Humanoid")
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

-- ================= shell UI =================
local function new(cls, props, par)
	local o = Instance.new(cls)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = par
	return o
end
local function round(o, r) new("UICorner", { CornerRadius = UDim.new(0, r) }, o) end

local clickSound
local function playClick()
	if not clickSound then
		clickSound = Instance.new("Sound")
		clickSound.SoundId = "rbxassetid://131961136"
		clickSound.Volume = 0.16
		clickSound.PlaybackSpeed = 3.6
		clickSound.Parent = SoundSvc
	end
	pcall(function()
		clickSound:Stop()
		clickSound.TimePosition = 0
		clickSound:Play()
	end)
end

local function pulse(o)
	local s = o:FindFirstChildOfClass("UIScale")
	if not s then s = new("UIScale", {}, o) end
	Tween:Create(s, TweenInfo.new(0.07), { Scale = 0.972 }):Play()
	task.delay(0.07, function()
		if s.Parent then Tween:Create(s, TweenInfo.new(0.1), { Scale = 1 }):Play() end
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
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 12),
	Size = UDim2.fromOffset(112, 22),
	BackgroundColor3 = Color3.fromRGB(10, 11, 14),
	BackgroundTransparency = 0.15,
	BorderSizePixel = 0,
	ZIndex = 60,
}, gui)
round(wm, 5)
new("UIStroke", { Color = ACC, Transparency = 0.6, Thickness = 1 }, wm)
new("TextLabel", {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
	Text = "SMOOTH.DEV", TextColor3 = ACC,
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
	e.stroke = new("UIStroke", { Color = ACC, Thickness = 1, Transparency = 0.35 }, e.box)
	e.fillFrame = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = ACC, BackgroundTransparency = 0.88, BorderSizePixel = 0, ZIndex = 5 }, root)

	for i = 1, 8 do
		e.corners[i] = new("Frame", { BackgroundColor3 = ACC, BorderSizePixel = 0, ZIndex = 7 }, root)
	end

	e.hpBg = new("Frame", {
		Size = UDim2.new(0, 3, 1, 0), Position = UDim2.fromOffset(-6, 0),
		BackgroundColor3 = Color3.fromRGB(20, 22, 28), BorderSizePixel = 0, ZIndex = 7,
	}, root)
	e.hp = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(0, 255, 90), BorderSizePixel = 0, ZIndex = 8 }, e.hpBg)

	e.tracer = new("Frame", {
		BackgroundColor3 = ACC, BorderSizePixel = 0, ZIndex = 4,
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
		local to = Vector2.new((minx + maxx) / 2, maxy)
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
			hl.FillColor = ACC
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

-- ================= gyro (spin droit + vol droit) =================
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
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 150,
	}, gui)
	local txt = new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "SMOOTH.DEV",
		TextColor3 = ACC,
		Font = Enum.Font.GothamBlack,
		TextSize = 130,
		ZIndex = 151,
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
	task.delay(1.3, function()
		pcall(function() layer:Destroy() s:Destroy() end)
	end)
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
track(RunService.RenderStepped:Connect(function(dt)
	if dead then return end

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

	-- orientation droite : spin autour de Y, ou maintien vertical en vol
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
new("UIStroke", { Color = ACC, Thickness = 1, Transparency = 0.5 }, ring)

local win = new("Frame", {
	Size = UDim2.fromOffset(470, 400),
	Position = UDim2.fromOffset(40, 100),
	BackgroundColor3 = BG, BorderSizePixel = 0, Active = true, ZIndex = 10,
	Visible = false, BackgroundTransparency = 1,
}, gui)
round(win, 10)
local winStroke = new("UIStroke", { Color = Color3.fromRGB(55, 55, 68) }, win)
local winScale = new("UIScale", { Scale = 0.92 }, win)

local bar = new("Frame", {
	Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = Color3.fromRGB(19, 19, 25),
	BorderSizePixel = 0, ZIndex = 11,
}, win)
round(bar, 10)

new("TextLabel", {
	Size = UDim2.new(1, 0, 1, 0), Position = UDim2.fromOffset(12, 0),
	BackgroundTransparency = 1, Text = "SMOOTH.DEV",
	TextColor3 = ACC, Font = Enum.Font.GothamBlack, TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12,
}, bar)

local minBtn = new("TextButton", {
	Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -56, 0.5, -11),
	BackgroundColor3 = Color3.fromRGB(35, 35, 44), Text = "-", TextColor3 = ACC,
	Font = Enum.Font.GothamBold, TextSize = 13, BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 13,
}, bar)
round(minBtn, 6)

local xBtn = new("TextButton", {
	Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -28, 0.5, -11),
	BackgroundColor3 = Color3.fromRGB(35, 35, 44), Text = "X", TextColor3 = Color3.fromRGB(255, 110, 110),
	Font = Enum.Font.GothamBold, TextSize = 12, BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 13,
}, bar)
round(xBtn, 6)

local dragBar = new("TextButton", {
	Size = UDim2.new(1, -80, 1, 0), BackgroundTransparency = 1, Text = "",
	AutoButtonColor = false, ZIndex = 14,
}, bar)

local tabBar = new("Frame", {
	Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 32),
	BackgroundColor3 = Color3.fromRGB(17, 17, 22), BorderSizePixel = 0, ZIndex = 11,
}, win)
new("UIListLayout", { Padding = UDim.new(0, 4), FillDirection = Enum.FillDirection.Horizontal }, tabBar)
new("UIPadding", { PaddingLeft = UDim.new(0, 8) }, tabBar)

local content = new("Frame", {
	Size = UDim2.new(1, -16, 1, -68), Position = UDim2.fromOffset(8, 64),
	BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 11,
}, win)

local panes = {}
local function makeTab(name, i)
	local b = new("TextButton", {
		Size = UDim2.fromOffset(76, 20), BackgroundColor3 = Color3.fromRGB(26, 26, 33),
		Text = name, TextColor3 = Color3.fromRGB(130, 130, 145), Font = Enum.Font.GothamMedium,
		TextSize = 11, BorderSizePixel = 0, AutoButtonColor = false, LayoutOrder = i, ZIndex = 12,
	}, tabBar)
	round(b, 5)
	local pane = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 2, ScrollBarImageColor3 = Color3.fromRGB(50, 55, 68),
		CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false, ZIndex = 12,
	}, content)
	new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, pane)
	local rec = { btn = b, pane = pane }
	rec.select = function()
		for _, r in ipairs(panes) do
			r.pane.Visible = (r == rec)
			Tween:Create(r.btn, TweenInfo.new(0.1), {
				BackgroundColor3 = (r == rec) and Color3.fromRGB(30, 44, 56) or Color3.fromRGB(26, 26, 33),
				TextColor3 = (r == rec) and ACC or Color3.fromRGB(130, 130, 145),
			}):Play()
		end
	end
	panes[#panes + 1] = rec
	b.MouseButton1Click:Connect(function()
		playClick()
		pulse(b)
		rec.select()
	end)
	return pane
end

local function headRow(pane, txt, i)
	new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 15), BackgroundTransparency = 1, Text = txt,
		TextColor3 = Color3.fromRGB(95, 95, 112), Font = Enum.Font.GothamBold, TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = i,
	}, pane)
end

local function toggleRow(pane, txt, tbl, key, i, cb)
	local r = new("Frame", {
		Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = CARD, BorderSizePixel = 0, LayoutOrder = i,
	}, pane)
	round(r, 6)
	local b = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "" }, r)
	new("TextLabel", {
		Size = UDim2.new(1, -50, 1, 0), Position = UDim2.fromOffset(9, 0), BackgroundTransparency = 1,
		Text = txt, TextColor3 = Color3.fromRGB(232, 232, 240), Font = Enum.Font.Gotham, TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, r)
	local pill = new("Frame", {
		Size = UDim2.fromOffset(28, 15), Position = UDim2.new(1, -36, 0.5, -7),
		BackgroundColor3 = Color3.fromRGB(46, 46, 56), BorderSizePixel = 0,
	}, r)
	round(pill, 7)
	local knob = new("Frame", {
		Size = UDim2.fromOffset(11, 11), Position = UDim2.fromOffset(2, 2),
		BackgroundColor3 = Color3.fromRGB(150, 150, 165), BorderSizePixel = 0,
	}, pill)
	round(knob, 5)
	local function paint()
		local on = tbl[key]
		Tween:Create(pill, TweenInfo.new(0.1), { BackgroundColor3 = on and ACC or Color3.fromRGB(46, 46, 56) }):Play()
		Tween:Create(knob, TweenInfo.new(0.1), {
			Position = on and UDim2.fromOffset(15, 2) or UDim2.fromOffset(2, 2),
			BackgroundColor3 = on and Color3.fromRGB(10, 10, 14) or Color3.fromRGB(150, 150, 165),
		}):Play()
	end
	b.MouseButton1Click:Connect(function()
		playClick()
		pulse(r)
		tbl[key] = not tbl[key]
		paint()
		if cb then cb(tbl[key]) end
	end)
	paint()
	refreshers[#refreshers + 1] = paint
end

local function sliderRow(pane, txt, tbl, key, mn, mx, i, cb)
	local r = new("Frame", {
		Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = CARD, BorderSizePixel = 0, LayoutOrder = i,
	}, pane)
	round(r, 6)
	new("TextLabel", {
		Size = UDim2.new(1, -55, 0, 15), Position = UDim2.fromOffset(9, 3), BackgroundTransparency = 1,
		Text = txt, TextColor3 = Color3.fromRGB(232, 232, 240), Font = Enum.Font.Gotham, TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, r)
	local val = new("TextLabel", {
		Size = UDim2.fromOffset(46, 15), Position = UDim2.new(1, -52, 0, 3), BackgroundTransparency = 1,
		Text = "", TextColor3 = ACC, Font = Enum.Font.GothamBold, TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, r)
	local trk = new("Frame", {
		Size = UDim2.new(1, -18, 0, 4), Position = UDim2.new(0, 9, 0, 26),
		BackgroundColor3 = Color3.fromRGB(48, 48, 60), BorderSizePixel = 0,
	}, r)
	round(trk, 2)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = ACC, BorderSizePixel = 0 }, trk)
	round(fill, 2)
	local function apply(v)
		v = math.clamp(v, mn, mx)
		local a = (v - mn) / (mx - mn)
		fill.Size = UDim2.fromScale(a, 1)
		val.Text = tostring(math.floor(v * 100) / 100)
		tbl[key] = math.floor(v * 100) / 100
		if cb then cb(tbl[key]) end
	end
	trk.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 then
			playClick()
			objs.drag = { trk, apply, mn, mx }
		end
	end)
	apply(tbl[key])
	refreshers[#refreshers + 1] = function() apply(tbl[key]) end
end

local function keyRow(pane, txt, tbl, key, i)
	local r = new("Frame", {
		Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = CARD, BorderSizePixel = 0, LayoutOrder = i,
	}, pane)
	round(r, 6)
	new("TextLabel", {
		Size = UDim2.new(1, -90, 1, 0), Position = UDim2.fromOffset(9, 0), BackgroundTransparency = 1,
		Text = txt, TextColor3 = Color3.fromRGB(232, 232, 240), Font = Enum.Font.Gotham, TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, r)
	local b = new("TextButton", {
		Size = UDim2.fromOffset(72, 18), Position = UDim2.new(1, -80, 0.5, -9),
		BackgroundColor3 = Color3.fromRGB(40, 40, 50), Text = tbl[key].Name, TextColor3 = ACC,
		Font = Enum.Font.GothamBold, TextSize = 10, BorderSizePixel = 0, AutoButtonColor = false,
	}, r)
	round(b, 4)
	local wait = false
	b.MouseButton1Click:Connect(function()
		playClick()
		pulse(r)
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

local function cycleRow(pane, txt, tbl, key, list, i)
	local r = new("Frame", {
		Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = CARD, BorderSizePixel = 0, LayoutOrder = i,
	}, pane)
	round(r, 6)
	new("TextLabel", {
		Size = UDim2.new(1, -90, 1, 0), Position = UDim2.fromOffset(9, 0), BackgroundTransparency = 1,
		Text = txt, TextColor3 = Color3.fromRGB(232, 232, 240), Font = Enum.Font.Gotham, TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, r)
	local b = new("TextButton", {
		Size = UDim2.fromOffset(72, 18), Position = UDim2.new(1, -80, 0.5, -9),
		BackgroundColor3 = Color3.fromRGB(40, 40, 50), Text = tostring(tbl[key]), TextColor3 = ACC,
		Font = Enum.Font.GothamBold, TextSize = 10, BorderSizePixel = 0, AutoButtonColor = false,
	}, r)
	round(b, 4)
	b.MouseButton1Click:Connect(function()
		playClick()
		pulse(r)
		local idx = 1
		for k, v in ipairs(list) do if v == tbl[key] then idx = k break end end
		idx = (idx % #list) + 1
		tbl[key] = list[idx]
		b.Text = tostring(tbl[key])
	end)
	refreshers[#refreshers + 1] = function() b.Text = tostring(tbl[key]) end
end

local function buttonRow(pane, txt, cb, i, col)
	local b = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = CARD, Text = txt,
		TextColor3 = col or ACC, Font = Enum.Font.GothamBold, TextSize = 11,
		BorderSizePixel = 0, AutoButtonColor = false, LayoutOrder = i,
	}, pane)
	round(b, 6)
	b.MouseButton1Click:Connect(function()
		playClick()
		pulse(b)
		cb()
	end)
end

local LAYOUT = {
	{ name = "Combat", items = {
		{ "head", "AIMBOT" },
		{ "toggle", "Aimbot", S.Aimbot, "on" },
		{ "key", "Touche aimbot", S.Aimbot, "key" },
		{ "toggle", "Verif equipe", S.Aimbot, "team" },
		{ "toggle", "Ignore knocked", S.Aimbot, "ignoreknock" },
		{ "cycle", "Partie visee", S.Aimbot, "part", { "Head", "Nearest", "Random", "Torso" } },
		{ "slider", "FOV", S.Aimbot, "fov", 20, 500 },
		{ "slider", "Lissage", S.Aimbot, "smooth", 0.05, 1 },
		{ "slider", "Prediction", S.Aimbot, "pred", 0, 1 },
		{ "slider", "Distance max", S.Aimbot, "maxd", 50, 3000 },
		{ "head", "RAGE" },
		{ "toggle", "Snap instantane", S.Aimbot, "instant" },
		{ "toggle", "Auto fire", S.Aimbot, "autofire" },
		{ "slider", "Delai tir", S.Aimbot, "firedelay", 0.02, 0.5 },
		{ "toggle", "Trigger bot", S.Aimbot, "trigger" },
		{ "toggle", "Wall check", S.Aimbot, "vis" },
		{ "toggle", "Hitbox expander", S.HB, "on" },
		{ "slider", "Taille hitbox", S.HB, "size", 2, 20 },
		{ "toggle", "Cercle FOV", S.ESP, "fovcircle" },
		{ "head", "SILENT" },
		{ "toggle", "Silent aim", S.Silent, "on" },
		{ "key", "Touche silent", S.Silent, "key" },
		{ "toggle", "Equipe silent", S.Silent, "team" },
		{ "slider", "FOV silent", S.Silent, "fov", 20, 500 },
		{ "slider", "Distance silent", S.Silent, "maxd", 50, 3000 },
	} },
	{ name = "Visuel", items = {
		{ "head", "ESP" },
		{ "toggle", "ESP actif", S.ESP, "on" },
		{ "toggle", "Boite", S.ESP, "box" },
		{ "toggle", "Remplissage", S.ESP, "fill" },
		{ "toggle", "Pseudo", S.ESP, "name" },
		{ "toggle", "Vie", S.ESP, "hp" },
		{ "toggle", "Distance", S.ESP, "dist" },
		{ "toggle", "Tracer", S.ESP, "tracer" },
		{ "toggle", "Chams", S.ESP, "chams" },
		{ "toggle", "Verif equipe", S.ESP, "team" },
		{ "slider", "Distance max", S.ESP, "maxd", 50, 3000 },
	} },
	{ name = "Joueur", items = {
		{ "head", "DEPLACEMENT" },
		{ "toggle", "Vitesse", S.Char, "speed", setSpeed },
		{ "slider", "Valeur vitesse", S.Char, "sv", 16, 300 },
		{ "toggle", "Saut haut", S.Char, "jump", setJump },
		{ "slider", "Valeur saut", S.Char, "jv", 50, 400 },
		{ "toggle", "Fly", S.Char, "fly", setFly },
		{ "toggle", "Noclip", S.Char, "noclip", setNoclip },
		{ "toggle", "Freeze", S.Char, "freeze", setFreeze },
		{ "head", "CAMERA" },
		{ "toggle", "Freecam", S.Cam, "free", setFreecam },
		{ "slider", "Vitesse freecam", S.Cam, "freespd", 10, 300 },
		{ "toggle", "Orbite", S.Cam, "orbit" },
		{ "slider", "Rayon orbite", S.Cam, "orbitr", 5, 60 },
		{ "slider", "Vitesse orbite", S.Cam, "orbitspd", 10, 400 },
		{ "head", "PERSONNAGE" },
		{ "toggle", "Taille custom", S.Char, "scale", applyScale },
		{ "slider", "Echelle", S.Char, "scalev", 0.4, 3, nil, function() if S.Char.scale then applyScale() end end },
	} },
	{ name = "Troll", items = {
		{ "head", "ANIMATION" },
		{ "toggle", "Spin", S.Troll, "spin" },
		{ "slider", "Vitesse spin", S.Troll, "spinspd", 40, 900 },
		{ "toggle", "Ragdoll", S.Troll, "ragdoll", tRagdoll },
		{ "toggle", "Arc-en-ciel", S.Troll, "rainbow" },
		{ "toggle", "Invisible", S.Troll, "ghost", tGhost },
		{ "toggle", "Aura", S.Troll, "aura", tAura },
		{ "toggle", "Trainee", S.Troll, "trail", tTrail },
		{ "toggle", "S'asseoir", S.Troll, "sit", tSit },
		{ "head", "AMBIANCE" },
		{ "toggle", "Pluie de parts", S.Troll, "rain", tRain },
		{ "toggle", "Camera shake", S.Troll, "shake" },
		{ "slider", "Intensite shake", S.Troll, "shakei", 0.2, 6 },
		{ "toggle", "Nuit / brouillard", S.Troll, "fog", tFog },
		{ "toggle", "Party lights", S.Troll, "party", tParty },
		{ "head", "ACTIONS" },
		{ "toggle", "Suivre joueur", S.Troll, "follow", tFollow },
		{ "toggle", "Anti-AFK", S.Troll, "afk", tAfk },
		{ "button", "Teleport au plus proche", function() tTeleport(false) end },
		{ "button", "Teleport aleatoire", function() tTeleport(true) end },
		{ "button", "Confettis", tConfetti },
		{ "button", "Jumpscare", tJumpscare },
	} },
	{ name = "Divers", items = {
		{ "head", "RACCOURCIS" },
		{ "button", "Insert : menu", function() end },
		{ "button", "RightShift : unload", function() end },
		{ "head", "MAINTENANCE" },
		{ "button", "Reset toutes les options", function()
			setFly(false) setNoclip(false) setFreeze(false)
			tGhost(false) tFog(false) tRain(false) tAura(false) tTrail(false) tParty(false) tAfk(false)
			if S.Cam.free then setFreecam(false) end
			for grp, t in pairs(DEFAULTS) do
				for k, v in pairs(t) do S[grp][k] = v end
			end
			for _, f in ipairs(refreshers) do pcall(f) end
		end },
		{ "button", "Unload", Unload, nil, Color3.fromRGB(255, 110, 110) },
	} },
}

for ti, tabDef in ipairs(LAYOUT) do
	local pane = makeTab(tabDef.name, ti)
	for ii, item in ipairs(tabDef.items) do
		local kind = item[1]
		if kind == "head" then headRow(pane, item[2], ii)
		elseif kind == "toggle" then toggleRow(pane, item[2], item[3], item[4], ii, item[5])
		elseif kind == "slider" then sliderRow(pane, item[2], item[3], item[4], item[5], item[6], ii, item[7])
		elseif kind == "key" then keyRow(pane, item[2], item[3], item[4], ii)
		elseif kind == "cycle" then cycleRow(pane, item[2], item[3], item[4], item[5], ii)
		elseif kind == "button" then buttonRow(pane, item[2], item[3], ii, item[5])
		end
	end
end

panes[1].select()

-- ================= drag =================
local dragging, dragStart, startPos
dragBar.InputBegan:Connect(function(i)
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
	tabBar.Visible = not minimized
	content.Visible = not minimized
	win.Size = minimized and UDim2.fromOffset(470, 32) or UDim2.fromOffset(470, 400)
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

-- ================= animation de lancement =================
task.spawn(function()
	local boot = Instance.new("CanvasGroup")
	boot.Size = UDim2.fromScale(1, 1)
	boot.BackgroundColor3 = Color3.fromRGB(4, 5, 8)
	boot.BackgroundTransparency = 0.05
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
		Size = UDim2.fromOffset(340, 176),
		BackgroundColor3 = Color3.fromRGB(11, 12, 16),
		BorderSizePixel = 0,
		ZIndex = 201,
		ClipsDescendants = true,
	}, boot)
	round(card, 14)
	local cStroke = new("UIStroke", { Color = ACC, Transparency = 1, Thickness = 1 }, card)
	local cScale = new("UIScale", { Scale = 0.9 }, card)

	local accentTop = new("Frame", {
		Size = UDim2.new(1, -36, 0, 2),
		Position = UDim2.fromOffset(18, 0),
		BackgroundColor3 = ACC,
		BorderSizePixel = 0,
		ZIndex = 203,
	}, card)
	round(accentTop, 1)

	local scan = new("Frame", {
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.new(0, 0, 0, -30),
		BackgroundColor3 = ACC,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		ZIndex = 202,
	}, card)

	local logo = new("TextLabel", {
		Size = UDim2.new(1, -36, 0, 34),
		Position = UDim2.fromOffset(18, 26),
		BackgroundTransparency = 1,
		Text = "SMOOTH.DEV",
		TextColor3 = ACC,
		Font = Enum.Font.GothamBlack,
		TextSize = 26,
		TextTransparency = 1,
		ZIndex = 204,
	}, card)

	local line = new("Frame", {
		Size = UDim2.new(0, 0, 0, 2),
		Position = UDim2.fromOffset(18, 62),
		BackgroundColor3 = ACC,
		BorderSizePixel = 0,
		ZIndex = 204,
	}, card)
	round(line, 1)

	local status = new("TextLabel", {
		Size = UDim2.new(1, -70, 0, 14),
		Position = UDim2.fromOffset(18, 74),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Color3.fromRGB(118, 130, 146),
		Font = Enum.Font.Gotham,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 204,
	}, card)

	local pct = new("TextLabel", {
		Size = UDim2.fromOffset(54, 14),
		Position = UDim2.new(1, -72, 0, 74),
		BackgroundTransparency = 1,
		Text = "0%",
		TextColor3 = ACC,
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 204,
	}, card)

	local trackF = new("Frame", {
		Size = UDim2.new(1, -36, 0, 3),
		Position = UDim2.fromOffset(18, 96),
		BackgroundColor3 = Color3.fromRGB(30, 34, 42),
		BorderSizePixel = 0,
		ZIndex = 204,
	}, card)
	round(trackF, 2)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = ACC, BorderSizePixel = 0, ZIndex = 205 }, trackF)
	round(fill, 2)

	local dots = {}
	for i = 1, 3 do
		local d = new("Frame", {
			Size = UDim2.fromOffset(4, 4),
			Position = UDim2.fromOffset(18 + (i - 1) * 9, 112),
			BackgroundColor3 = Color3.fromRGB(48, 54, 64),
			BorderSizePixel = 0,
			ZIndex = 204,
		}, card)
		round(d, 2)
		dots[i] = d
	end

	local hint = new("TextLabel", {
		Size = UDim2.new(1, -36, 0, 12),
		Position = UDim2.fromOffset(18, 128),
		BackgroundTransparency = 1,
		Text = "clic pour passer",
		TextColor3 = Color3.fromRGB(66, 74, 86),
		Font = Enum.Font.Gotham,
		TextSize = 9,
		ZIndex = 204,
	}, card)

	local skipped = false
	skip.MouseButton1Click:Connect(function() skipped = true end)

	-- dots pulsés
	task.spawn(function()
		while card.Parent and not skipped do
			for i = 1, 3 do
				local d = dots[i]
				task.spawn(function()
					Tween:Create(d, TweenInfo.new(0.16), { BackgroundColor3 = ACC }):Play()
					task.wait(0.16)
					if d.Parent then Tween:Create(d, TweenInfo.new(0.3), { BackgroundColor3 = Color3.fromRGB(48, 54, 64) }):Play() end
				end)
				task.wait(0.1)
			end
			task.wait(0.2)
		end
	end)

	-- scanline
	task.spawn(function()
		while card.Parent and not skipped do
			scan.Position = UDim2.new(0, 0, 0, -30)
			Tween:Create(scan, TweenInfo.new(1.1, Enum.EasingStyle.Linear), { Position = UDim2.new(0, 0, 0, 176) }):Play()
			task.wait(1.15)
		end
	end)

	Tween:Create(boot, TweenInfo.new(0.28), { GroupTransparency = 0 }):Play()
	Tween:Create(card, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	Tween:Create(cScale, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.wait(0.3)

	Tween:Create(logo, TweenInfo.new(0.24), { TextTransparency = 0 }):Play()
	Tween:Create(cStroke, TweenInfo.new(0.24), { Transparency = 0.55 }):Play()
	Tween:Create(line, TweenInfo.new(0.36, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(1, -36, 0, 2) }):Play()
	task.wait(0.1)

	local steps = { "initialisation du client", "resolution du rig", "chargement de l esp", "liaison du render", "synchronisation" }
	for i = 1, #steps do
		if skipped then break end
		status.Text = steps[i]
		pct.Text = math.floor(i / #steps * 100) .. "%"
		Tween:Create(fill, TweenInfo.new(0.34, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(i / #steps, 1) }):Play()
		task.wait(0.28)
	end

	if not skipped then
		status.Text = "pret"
		pct.Text = "100%"
		Tween:Create(fill, TweenInfo.new(0.14), { Size = UDim2.fromScale(1, 1) }):Play()
		task.wait(0.34)
	end

	Tween:Create(logo, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
	Tween:Create(card, TweenInfo.new(0.24), { Position = UDim2.new(0.5, 0, 0.5, -18) }):Play()
	Tween:Create(cScale, TweenInfo.new(0.24), { Scale = 1.05 }):Play()
	Tween:Create(boot, TweenInfo.new(0.3), { GroupTransparency = 1 }):Play()
	task.wait(0.26)
	boot:Destroy()

	win.Visible = true
	Tween:Create(winScale, TweenInfo.new(0.34, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	Tween:Create(win, TweenInfo.new(0.34), { BackgroundTransparency = 0 }):Play()
end)

print("[SMOOTH.DEV] loaded")
