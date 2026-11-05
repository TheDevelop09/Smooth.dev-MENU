--[[ SMOOTH.DEV v27b — UI: WindUI (MIT)
     Insert = menu | RightShift = unload | rond cliquable au repli ]]

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local Tween      = game:GetService("TweenService")
local VIM        = game:GetService("VirtualUser")
local Lighting   = game:GetService("Lighting")
local SoundSvc   = game:GetService("SoundService")
local WS         = workspace

local LP = Players.LocalPlayer
local mouse = LP:GetMouse()
local Camera = WS.CurrentCamera
WS:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	if WS.CurrentCamera then Camera = WS.CurrentCamera end
end)

if getgenv().V and type(getgenv().V) == "table" and getgenv().V.Unload then
	pcall(getgenv().V.Unload)
end

local EXCLUDE = Enum.RaycastFilterType.Exclude or Enum.RaycastFilterType.Blacklist

local AB = {
	on = false, mode = "Toujours", toggled = false, key = Enum.KeyCode.E,
	fov = 140, smooth = 0.18, pred = 0.12, team = true, ignoreknock = true,
	part = "Head", maxd = 1200, vis = false, style = "CFrame", instant = false,
	autofire = false, firedelay = 0.09, trigger = false, trigdelay = 0.06,
	priority = "Curseur", sticky = true, stickyms = 260, marker = true,
}
local SA = {
	on = false, mode = "Touche", toggled = false, key = Enum.KeyCode.Q,
	fov = 170, team = true, maxd = 1200, vis = false, part = "Head",
	pred = 0.12, chance = 100,
}
local HB  = { on = false, size = 6, root = false }
local ESP = { on = true, box = true, name = true, hp = true, dist = true, chams = false,
	tracer = false, team = false, maxd = 900, fovcircle = true, fill = false }
local CHAR  = { speed = false, sv = 60, jump = false, jv = 95, fly = false, noclip = false,
	scale = false, scalev = 1, freeze = false }
local CAM   = { free = false, freespd = 60, orbit = false, orbitr = 16, orbitspd = 60 }
local TROLL = { spin = false, spinspd = 220, ragdoll = false, rainbow = false, rain = false,
	shake = false, shakei = 1.2, fog = false, ghost = false, follow = false,
	aura = false, trail = false, party = false, afk = false, sit = false,
	tornado = false, tploop = false, tprate = 3, beacon = false, music = false }
local B = { profile = "Standard", env = true, kick = true, kickFilter = true, rejoin = false,
	lock = true, sigspoof = true, velspoof = false, conns = true, scripts = true,
	gui = true, fpscap = false, fps = 60, maxspeed = 60, maxvel = 70 }

local conns, esp, objs, hbStore = {}, {}, {}, {}
local dead, unloading, bypassWrite = false, false, false
local menuGui
local function track(c) conns[#conns + 1] = c return c end

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

local function partOf(c, mode)
	if not c then return nil end
	mode = mode or AB.part
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
		for _, d in ipairs(c:GetChildren()) do
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

local locked, lockedAt = nil, 0

local function aimActive()
	if not AB.on then return false end
	if AB.mode == "Toujours" then return true end
	if AB.mode == "Touche" then return UIS:IsKeyDown(AB.key) end
	return AB.toggled
end

local function silentActive()
	if not SA.on then return false end
	if SA.mode == "Toujours" then return true end
	if SA.mode == "Touche" then return UIS:IsKeyDown(SA.key) end
	return SA.toggled
end

local function validate(p, cfg)
	local c, h, r = alive(p)
	if not r then return nil end
	if cfg.team and LP.Team ~= nil and p.Team == LP.Team then return nil end
	if cfg.ignoreknock and h.PlatformStand then return nil end
	if (r.Position - Camera.CFrame.Position).Magnitude > cfg.maxd then return nil end
	local pt = partOf(c, cfg.part)
	if not pt then return nil end
	if cfg.vis and not visible(pt) then return nil end
	local sp = Camera:WorldToViewportPoint(pt.Position)
	if sp.Z <= 0 then return nil end
	local d = (Vector2.new(sp.X, sp.Y) - Camera.ViewportSize / 2).Magnitude
	if d > cfg.fov then return nil end
	return pt, d, r
end

local function pickTarget(cfg)
	local now = os.clock()
	if cfg.sticky ~= false and locked and now - lockedAt < (cfg.stickyms or 260) / 1000 then
		if validate(locked, cfg) then return locked end
	end
	local best, bestScore = nil, math.huge
	local myRoot = getRoot(LP.Character)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP then
			local pt, d, r = validate(p, cfg)
			if pt then
				local score = d
				if cfg.priority == "Distance" and myRoot then
					score = (r.Position - myRoot.Position).Magnitude
				elseif cfg.priority == "Vie" then
					local h = getHum(p.Character)
					score = h and h.Health or 1000
				end
				if score < bestScore then bestScore = score best = p end
			end
		end
	end
	if best then locked, lockedAt = best, now end
	return best
end

local function aimPos(p, pred)
	local c, h, r = alive(p)
	if not r then return nil end
	local pt = partOf(c, AB.part)
	if not pt then return nil end
	local v = r.AssemblyLinearVelocity or r.Velocity or Vector3.zero
	return pt.Position + v * (pred or 0) * 0.15
end

local lastFire = 0
local function fire(delay)
	if os.clock() - lastFire < delay then return end
	lastFire = os.clock()
	if mouse1click then
		if pcall(mouse1click) then return end
	end
	pcall(function()
		VIM:ClickButton1(Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2))
	end)
end

local function aimStep(dt)
	if dead then return end
	local active = aimActive()
	local trig = AB.trigger and AB.on
	if not active and not trig then locked = nil return end
	local target = pickTarget(AB)
	if not target then locked = nil return end
	local pos = aimPos(target, AB.pred)
	if not pos then return end

	if active then
		local goal = CFrame.lookAt(Camera.CFrame.Position, pos)
		if AB.instant then
			Camera.CFrame = goal
		elseif AB.style == "Relatif" and mousemoverel then
			local sp = Camera:WorldToViewportPoint(pos)
			local vp = Camera.ViewportSize
			local dx, dy = sp.X - vp.X / 2, sp.Y - vp.Y / 2
			if math.abs(dx) > 1 or math.abs(dy) > 1 then
				local k = math.clamp(1 - math.exp(-dt / math.max(AB.smooth, 0.02) * 6), 0.02, 1)
				pcall(mousemoverel, dx * k, dy * k)
			end
		elseif AB.style == "Absolu" and mousemoveabs then
			local sp = Camera:WorldToViewportPoint(pos)
			if sp.Z > 0 then
				local vp = Camera.ViewportSize
				local cx, cy = vp.X / 2, vp.Y / 2
				local k = math.clamp(1 - math.exp(-dt / math.max(AB.smooth, 0.02) * 6), 0.02, 1)
				pcall(mousemoveabs, cx + (sp.X - cx) * k, cy + (sp.Y - cy) * k)
			end
		else
			local k = math.clamp(1 - math.exp(-dt / math.max(AB.smooth, 0.02) * 6), 0.02, 1)
			Camera.CFrame = Camera.CFrame:Lerp(goal, k)
		end
	end

	if AB.autofire and active then fire(AB.firedelay) end
	if trig then
		local pt = partOf(target.Character, AB.part)
		if pt and (not AB.vis or visible(pt)) then fire(AB.trigdelay + AB.firedelay) end
	end
end

local function silentTarget()
	if not silentActive() then return nil end
	local t = pickTarget({ team = SA.team, ignoreknock = true, maxd = SA.maxd,
		fov = SA.fov, vis = SA.vis, part = SA.part })
	if not t then return nil end
	if SA.chance < 100 and math.random(100) > SA.chance then return nil end
	local pt = partOf(t.Character, SA.part)
	if not pt then return nil end
	local r = getRoot(t.Character) or pt
	local v = r.AssemblyLinearVelocity or Vector3.zero
	return pt.Position + v * SA.pred * 0.15
end

-- ================= ESP =================
local gui, espLayer

local function killESP(p)
	local e = esp[p]
	if e then
		if e.root then e.root:Destroy() end
		if e.hl then e.hl:Destroy() end
		esp[p] = nil
	end
end

local function makeESP()
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.ZIndex = 5
	root.Visible = false
	root.Parent = espLayer

	local e = { root = root, corners = {} }

	e.box = Instance.new("Frame")
	e.box.Size = UDim2.fromScale(1, 1)
	e.box.BackgroundTransparency = 1
	e.box.BorderSizePixel = 0
	e.box.ZIndex = 6
	e.box.Parent = root
	e.stroke = Instance.new("UIStroke", e.box)
	e.stroke.Color = Color3.fromRGB(0, 214, 255)
	e.stroke.Thickness = 1
	e.stroke.Transparency = 0.35

	e.fillFrame = Instance.new("Frame")
	e.fillFrame.Size = UDim2.fromScale(1, 1)
	e.fillFrame.BackgroundColor3 = Color3.fromRGB(0, 214, 255)
	e.fillFrame.BackgroundTransparency = 0.88
	e.fillFrame.BorderSizePixel = 0
	e.fillFrame.ZIndex = 5
	e.fillFrame.Parent = root

	for i = 1, 8 do
		local c = Instance.new("Frame")
		c.BackgroundColor3 = Color3.fromRGB(0, 214, 255)
		c.BorderSizePixel = 0
		c.ZIndex = 7
		c.Parent = root
		e.corners[i] = c
	end

	e.hpBg = Instance.new("Frame")
	e.hpBg.Size = UDim2.new(0, 3, 1, 0)
	e.hpBg.Position = UDim2.fromOffset(-6, 0)
	e.hpBg.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	e.hpBg.BorderSizePixel = 0
	e.hpBg.ZIndex = 7
	e.hpBg.Parent = root

	e.hp = Instance.new("Frame")
	e.hp.Size = UDim2.fromScale(1, 1)
	e.hp.BackgroundColor3 = Color3.fromRGB(0, 255, 90)
	e.hp.BorderSizePixel = 0
	e.hp.ZIndex = 8
	e.hp.Parent = e.hpBg

	e.tracer = Instance.new("Frame")
	e.tracer.BackgroundColor3 = Color3.fromRGB(0, 214, 255)
	e.tracer.BorderSizePixel = 0
	e.tracer.ZIndex = 3
	e.tracer.AnchorPoint = Vector2.new(0.5, 0.5)
	e.tracer.Size = UDim2.fromOffset(1, 1)
	e.tracer.Visible = false
	e.tracer.Parent = espLayer

	e.name = Instance.new("TextLabel")
	e.name.Size = UDim2.new(1, 0, 0, 13)
	e.name.Position = UDim2.fromOffset(0, -15)
	e.name.BackgroundTransparency = 1
	e.name.TextColor3 = Color3.new(1, 1, 1)
	e.name.TextStrokeTransparency = 0.2
	e.name.Font = Enum.Font.GothamBold
	e.name.TextSize = 11
	e.name.ZIndex = 8
	e.name.Parent = root

	e.dist = Instance.new("TextLabel")
	e.dist.Size = UDim2.new(1, 0, 0, 12)
	e.dist.Position = UDim2.new(0, 0, 1, 2)
	e.dist.BackgroundTransparency = 1
	e.dist.TextColor3 = Color3.fromRGB(190, 200, 215)
	e.dist.TextStrokeTransparency = 0.35
	e.dist.Font = Enum.Font.Gotham
	e.dist.TextSize = 10
	e.dist.ZIndex = 8
	e.dist.Parent = root

	return e
end

local function ensureESP(p)
	if p == LP then return nil end
	local e = esp[p]
	if not e then e = makeESP() esp[p] = e end
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

local function hideEntry(e)
	if not e then return end
	e.root.Visible = false
	e.tracer.Visible = false
end

local function drawESP(p)
	local e = esp[p]
	if not ESP.on then hideEntry(e) return end
	local c, h, r = alive(p)
	if not r then hideEntry(e) return end
	if ESP.team and LP.Team ~= nil and p.Team == LP.Team then hideEntry(e) return end
	local dist = (r.Position - Camera.CFrame.Position).Magnitude
	if dist > ESP.maxd then hideEntry(e) return end

	local ok, bbCF, sz = pcall(function()
		local cf, s = c:GetBoundingBox()
		return cf, s
	end)
	if not ok or not sz then hideEntry(e) return end

	local hx, hy, hz = sz.X / 2, sz.Y / 2, sz.Z / 2
	local minx, maxx, miny, maxy = math.huge, -math.huge, math.huge, -math.huge
	local n = 0
	for _, sx in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			for _, sz2 in ipairs({ -1, 1 }) do
				local sp = Camera:WorldToViewportPoint((bbCF * CFrame.new(sx * hx, sy * hy, sz2 * hz)).Position)
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

	if n < 4 then hideEntry(e) return end
	if not e then e = makeESP() esp[p] = e end

	local w = math.max(maxx - minx, 22)
	local hgt = math.max(maxy - miny, 34)
	local x = minx - (w - (maxx - minx)) / 2
	local y = miny - (hgt - (maxy - miny)) / 2

	e.root.Visible = true
	e.root.Position = UDim2.fromOffset(x, y)
	e.root.Size = UDim2.fromOffset(w, hgt)
	setCorner(e, w, hgt, math.clamp(w * 0.22, 4, 12))

	e.box.Visible = ESP.box
	e.fillFrame.Visible = ESP.fill and ESP.box
	e.stroke.Transparency = ESP.box and 0.35 or 1
	for _, v in ipairs(e.corners) do v.Visible = ESP.box end

	e.name.Text = p.Name
	e.name.Visible = ESP.name
	e.dist.Text = math.floor(dist) .. "m"
	e.dist.Visible = ESP.dist

	e.hpBg.Visible = ESP.hp
	local a = math.clamp(h.Health / math.max(h.MaxHealth, 1), 0, 1)
	e.hp.Size = UDim2.fromScale(1, a)
	e.hp.Position = UDim2.new(0, 0, 1 - a, 0)
	e.hp.BackgroundColor3 = Color3.fromRGB(255 * (1 - a), 255 * a, 60)

	if ESP.tracer then
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

	if ESP.chams then
		if not e.hl or not e.hl.Parent then
			if e.hl then e.hl:Destroy() end
			local hl = Instance.new("Highlight")
			hl.FillColor = Color3.fromRGB(0, 214, 255)
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
end

-- ================= HITBOX =================
local HB_CORE = { "Head", "UpperTorso", "Torso" }

local function restoreHB(p)
	local e = hbStore[p]
	if e then
		for part, size in pairs(e) do
			pcall(function() if part.Parent then part.Size = size end end)
		end
	end
	hbStore[p] = nil
end

local function applyHB(p)
	local c = p.Character
	if not c then restoreHB(p) return end
	local list = {}
	for _, n in ipairs(HB_CORE) do
		local part = c:FindFirstChild(n)
		if part and part:IsA("BasePart") then list[#list + 1] = part end
	end
	if HB.root then
		local r = c:FindFirstChild("HumanoidRootPart")
		if r and r:IsA("BasePart") then list[#list + 1] = r end
	end
	local e = hbStore[p]
	if not e then e = {} hbStore[p] = e end
	for _, part in ipairs(list) do
		if not e[part] then
			e[part] = part.Size
			pcall(function() part.Massless = true end)
			pcall(function() part.CanQuery = true end)
		end
		if (part.Size - Vector3.new(HB.size, HB.size, HB.size)).Magnitude > 0.05 then
			pcall(function() part.Size = Vector3.new(HB.size, HB.size, HB.size) end)
		end
	end
end

-- ================= MOUVEMENT =================
local spinAngle = 0
local origSpeed, origJump, origUseJP, origCamType

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

local function setWalk(h, v)
	bypassWrite = true
	pcall(function() h.WalkSpeed = v end)
	bypassWrite = false
end

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
		if not TROLL.spin then clearGyro() end
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
	elseif h then setWalk(h, origSpeed or 16) origSpeed = nil end
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
	local v = CHAR.scale and CHAR.scalev or 1
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

-- ================= TROLL =================
local trollObj = { parts = {}, ghost = {}, lgt = {}, aura = {}, trail = {}, tornado = {} }

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
		trollObj.lgt = { FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
			Ambient = Lighting.Ambient, Brightness = Lighting.Brightness,
			OutdoorAmbient = Lighting.OutdoorAmbient }
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
	local layer = Instance.new("Frame")
	layer.Size = UDim2.fromScale(1, 1)
	layer.BackgroundColor3 = Color3.new(0, 0, 0)
	layer.BorderSizePixel = 0
	layer.ZIndex = 150
	layer.Parent = gui

	local txt = Instance.new("TextLabel")
	txt.Size = UDim2.fromScale(1, 1)
	txt.BackgroundTransparency = 1
	txt.Text = "SMOOTH.DEV"
	txt.TextColor3 = Color3.fromRGB(0, 214, 255)
	txt.Font = Enum.Font.GothamBlack
	txt.TextSize = 130
	txt.ZIndex = 151
	txt.Parent = layer

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

-- ================= JOUETS =================
local TX = {}

function TX.sound(id)
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. tostring(id)
	s.Volume = 2
	s.Parent = SoundSvc
	pcall(function() s:Play() end)
	task.delay(6, function() pcall(function() s:Destroy() end) end)
end

function TX.music(id)
	if objs.music then pcall(function() objs.music:Destroy() end) objs.music = nil end
	if not id or id == 0 then return end
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. tostring(id)
	s.Volume = 1.5
	s.Looped = true
	s.Parent = SoundSvc
	pcall(function() s:Play() end)
	objs.music = s
end

function TX.attach()
	local target = mouse.Target
	local _, _, r = alive(LP)
	if not target or not r then return end
	local w = Instance.new("WeldConstraint")
	w.Part0 = r
	w.Part1 = target
	w.Parent = r
	pcall(function() target.CanCollide = false end)
end

function TX.tpLoop(on)
	if not on then return end
	task.spawn(function()
		while TROLL.tploop and not dead do
			local _, _, r = alive(LP)
			if r then
				local base = r.Position + Vector3.new(math.random(-320, 320), 60, math.random(-320, 320))
				local params = RaycastParams.new()
				params.FilterType = EXCLUDE
				params.FilterDescendantsInstances = { LP.Character }
				local hit = WS:Raycast(base, Vector3.new(0, -600, 0), params)
				if hit then r.CFrame = CFrame.new(hit.Position + Vector3.new(0, 4, 0)) end
			end
			task.wait(TROLL.tprate)
		end
	end)
end

function TX.tornado(on)
	for _, p in ipairs(trollObj.tornado) do pcall(function() p:Destroy() end) end
	trollObj.tornado = {}
	if not on then return end
	for i = 1, 14 do
		local p = Instance.new("Part")
		p.Size = Vector3.new(0.7, 0.7, 0.7)
		p.Anchored = true
		p.CanCollide = false
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromHSV((i - 1) / 14, 0.9, 1)
		p.Parent = WS
		trollObj.tornado[i] = p
	end
end

function TX.beacon(on)
	local _, _, r = alive(LP)
	if not r then return end
	if not on then
		local l = r:FindFirstChildOfClass("PointLight")
		if l then l:Destroy() end
		return
	end
	local l = Instance.new("PointLight")
	l.Brightness = 6
	l.Range = 26
	l.Color = Color3.fromRGB(0, 200, 255)
	l.Parent = r
end

function TX.stopAll()
	TROLL.tploop = false
	TX.tornado(false)
	TX.beacon(false)
	if objs.music then pcall(function() objs.music:Destroy() end) objs.music = nil end
end

-- ================= BOUCLES =================
track(RunService.RenderStepped:Connect(function(dt)
	if dead then return end
	pcall(function()
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LP then drawESP(p) end
		end
	end)

	if CHAR.fly and objs.fly then
		local _, _, r = alive(LP)
		if r then
			local d = Vector3.zero
			if UIS:IsKeyDown(Enum.KeyCode.W) then d = d + Camera.CFrame.LookVector end
			if UIS:IsKeyDown(Enum.KeyCode.S) then d = d - Camera.CFrame.LookVector end
			if UIS:IsKeyDown(Enum.KeyCode.D) then d = d + Camera.CFrame.RightVector end
			if UIS:IsKeyDown(Enum.KeyCode.A) then d = d - Camera.CFrame.RightVector end
			if UIS:IsKeyDown(Enum.KeyCode.Space) then d = d + Vector3.yAxis end
			if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then d = d - Vector3.yAxis end
			if d.Magnitude > 0 then objs.fly.Velocity = d.Unit * CHAR.sv
			else objs.fly.Velocity = Vector3.zero end
		end
	end

	if TROLL.spin then
		local g = ensureGyro()
		if g and g.Parent then
			local pos = g.Parent.Position
			spinAngle = (spinAngle + math.rad(TROLL.spinspd) * dt) % (math.pi * 2)
			g.CFrame = CFrame.new(pos) * CFrame.Angles(0, spinAngle, 0)
		end
	elseif objs.gyro then
		clearGyro()
	end

	if CAM.free then
		local d = Vector3.zero
		if UIS:IsKeyDown(Enum.KeyCode.W) then d = d + Camera.CFrame.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.S) then d = d - Camera.CFrame.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.D) then d = d + Camera.CFrame.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.A) then d = d - Camera.CFrame.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.Space) then d = d + Vector3.yAxis end
		if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then d = d - Vector3.yAxis end
		if d.Magnitude > 0 then Camera.CFrame = Camera.CFrame + d.Unit * (CAM.freespd * dt) end
	end

	if CAM.orbit then
		local _, _, r = alive(LP)
		if r then
			local a = math.rad(os.clock() * CAM.orbitspd)
			Camera.CFrame = CFrame.lookAt(
				r.Position + Vector3.new(math.cos(a) * CAM.orbitr, 4, math.sin(a) * CAM.orbitr), r.Position)
		end
	end

	if TROLL.aura and #trollObj.aura > 0 then
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

	if TROLL.tornado and #trollObj.tornado > 0 then
		local _, _, r = alive(LP)
		if r then
			local t = os.clock() * 3
			for i, v in ipairs(trollObj.tornado) do
				local a = t + (i - 1) * (math.pi * 2 / #trollObj.tornado)
				local h = 0.5 + (i - 1) * 0.55
				pcall(function()
					v.CFrame = CFrame.new(r.Position + Vector3.new(math.cos(a) * (2 + i * 0.28), h, math.sin(a) * (2 + i * 0.28)))
				end)
			end
		end
	end

	if TROLL.follow and objs.follow then
		local _, _, r = alive(LP)
		local p = pickPlayer(false)
		local _, _, tr = alive(p or LP)
		if r and tr and p and tr ~= r then
			local d = tr.Position - r.Position
			if d.Magnitude > 6 then objs.follow.Velocity = d.Unit * math.min(d.Magnitude * 2, 90)
			else objs.follow.Velocity = Vector3.zero end
		end
	end

	if TROLL.shake then
		local i = TROLL.shakei
		Camera.CFrame = Camera.CFrame * CFrame.new(
			(math.random() - 0.5) * i / 30, (math.random() - 0.5) * i / 30, 0)
	end
end))

RunService:BindToRenderStep("SMOOTH_AIM", Enum.RenderPriority.Camera.Value + 1, function(dt)
	pcall(aimStep, dt)
end)

task.spawn(function()
	while not dead do
		task.wait(0.5)
		if dead then break end
		pcall(function()
			for p in pairs(esp) do if not p.Parent then killESP(p) end end
			if ESP.on then
				for _, p in ipairs(Players:GetPlayers()) do
					if p ~= LP then ensureESP(p) end
				end
			end
		end)
	end
end)

task.spawn(function()
	local hue = 0
	while not dead do
		RunService.RenderStepped:Wait()
		if TROLL.rainbow then
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
				if CHAR.speed then
					local v = CHAR.sv
					if B.speedcap then v = math.min(v, B.maxspeed) end
					setWalk(h, v)
				end
				if CHAR.jump then
					bypassWrite = true
					h.UseJumpPower = true
					h.JumpPower = CHAR.jv
					bypassWrite = false
				end
			end
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= LP and HB.on then applyHB(p) else restoreHB(p) end
			end
		end)
	end
end)

-- ================= GUI =================
local ownGui = Instance.new("ScreenGui")
ownGui.Name = "SmoothDevOverlay"
ownGui.ResetOnSpawn = false
ownGui.IgnoreGuiInset = true
ownGui.DisplayOrder = 2147483647
ownGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
if syn and syn.protect_gui then pcall(syn.protect_gui, ownGui) end
pcall(function() ownGui.Parent = game:GetService("CoreGui") end)
if not ownGui.Parent and type(gethui) == "function" then
	pcall(function() ownGui.Parent = gethui() end)
end
if not ownGui.Parent then ownGui.Parent = LP:WaitForChild("PlayerGui") end
gui = ownGui

espLayer = Instance.new("Frame")
espLayer.Size = UDim2.fromScale(1, 1)
espLayer.BackgroundTransparency = 1
espLayer.BorderSizePixel = 0
espLayer.ZIndex = 4
espLayer.Parent = ownGui

local ring = Instance.new("Frame")
ring.AnchorPoint = Vector2.new(0.5, 0.5)
ring.Position = UDim2.fromScale(0.5, 0.5)
ring.BackgroundTransparency = 1
ring.BorderSizePixel = 0
ring.ZIndex = 2
ring.Visible = false
ring.Parent = ownGui
Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
local ringStroke = Instance.new("UIStroke", ring)
ringStroke.Color = Color3.fromRGB(0, 214, 255)
ringStroke.Thickness = 1
ringStroke.Transparency = 0.5

local marker = Instance.new("Frame")
marker.AnchorPoint = Vector2.new(0.5, 0.5)
marker.Size = UDim2.fromOffset(14, 14)
marker.BackgroundTransparency = 1
marker.BorderSizePixel = 0
marker.ZIndex = 9
marker.Visible = false
marker.Parent = ownGui
do
	local m1 = Instance.new("Frame")
	m1.Size = UDim2.new(1, 0, 0, 1)
	m1.Position = UDim2.fromScale(0, 0.5)
	m1.BackgroundColor3 = Color3.fromRGB(0, 214, 255)
	m1.BorderSizePixel = 0
	m1.ZIndex = 9
	m1.Parent = marker
	local m2 = Instance.new("Frame")
	m2.Size = UDim2.new(0, 1, 1, 0)
	m2.Position = UDim2.fromScale(0.5, 0)
	m2.BackgroundColor3 = Color3.fromRGB(0, 214, 255)
	m2.BorderSizePixel = 0
	m2.ZIndex = 9
	m2.Parent = marker
end

track(RunService.RenderStepped:Connect(function()
	if dead then return end
	local active = aimActive()
	local silent = silentActive()
	ring.Visible = ESP.fovcircle or active or silent
	local r = silent and SA.fov or AB.fov
	ring.Size = UDim2.fromOffset(r * 2, r * 2)
	ringStroke.Color = active and Color3.fromRGB(120, 255, 180) or Color3.fromRGB(0, 214, 255)

	if AB.marker and active and locked and locked.Character then
		local pt = partOf(locked.Character, AB.part)
		local sp = pt and Camera:WorldToViewportPoint(pt.Position)
		if sp and sp.Z > 0 then
			marker.Visible = true
			marker.Position = UDim2.fromOffset(sp.X, sp.Y)
		else
			marker.Visible = false
		end
	else
		marker.Visible = false
	end
end))

-- ================= PREMIER PLAN =================
local FG = { on = true }

local function pushAbove()
	if not FG.on then return end
	pcall(function()
		ownGui.DisplayOrder = 2147483647
		local cg = game:GetService("CoreGui")
		local rg = cg:FindFirstChild("RobloxGui")
		if rg and rg:IsA("ScreenGui") and rg.DisplayOrder >= ownGui.DisplayOrder then
			rg.DisplayOrder = 2147483646
		end
		for _, g in ipairs(cg:GetChildren()) do
			if g ~= ownGui and g:IsA("ScreenGui") then
				local n = g.Name:lower()
				if (n:find("menu") or n:find("roblox") or n:find("overlay")) and g.DisplayOrder >= ownGui.DisplayOrder then
					pcall(function() g.DisplayOrder = 2147483645 end)
				end
			end
		end
	end)
end

task.spawn(function()
	while not dead do
		pushAbove()
		task.wait(0.35)
	end
end)

-- ================= TOAST =================
local toastHolder = Instance.new("Frame")
toastHolder.AnchorPoint = Vector2.new(1, 1)
toastHolder.Position = UDim2.new(1, -16, 1, -16)
toastHolder.Size = UDim2.fromOffset(300, 260)
toastHolder.BackgroundTransparency = 1
toastHolder.ZIndex = 200
toastHolder.Parent = ownGui
do
	local tl = Instance.new("UIListLayout")
	tl.VerticalAlignment = Enum.VerticalAlignment.Bottom
	tl.SortOrder = Enum.SortOrder.LayoutOrder
	tl.Padding = UDim.new(0, 6)
	tl.Parent = toastHolder
end

local function toast(text)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, 30)
	f.BackgroundColor3 = Color3.fromRGB(12, 16, 24)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.ZIndex = 201
	f.Parent = toastHolder

	local st = Instance.new("UIStroke", f)
	st.Color = Color3.fromRGB(0, 214, 255)
	st.Transparency = 1

	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, -18, 1, 0)
	l.Position = UDim2.fromOffset(10, 0)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Gotham
	l.TextSize = 11
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.TextColor3 = Color3.fromRGB(210, 230, 245)
	l.Text = text
	l.TextTransparency = 1
	l.ZIndex = 202
	l.Parent = f

	local ti = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	Tween:Create(f, ti, { BackgroundTransparency = 0.1 }):Play()
	Tween:Create(st, ti, { Transparency = 0.45 }):Play()
	Tween:Create(l, ti, { TextTransparency = 0 }):Play()

	task.delay(3.6, function()
		local o = TweenInfo.new(0.3)
		Tween:Create(f, o, { BackgroundTransparency = 1 }):Play()
		Tween:Create(st, o, { Transparency = 1 }):Play()
		Tween:Create(l, o, { TextTransparency = 1 }):Play()
		task.wait(0.32)
		pcall(function() f:Destroy() end)
	end)
end

-- ================= CIEL =================
local skyState = { saved = false, orig = {}, atmo = nil, sky = nil }

local function saveLighting()
	if skyState.saved then return end
	skyState.saved = true
	for _, k in ipairs({ "Ambient", "OutdoorAmbient", "Brightness", "ClockTime", "FogEnd",
		"FogStart", "FogColor", "ExposureCompensation", "EnvironmentDiffuseScale",
		"EnvironmentSpecularScale", "GeographicLatitude", "GlobalShadows" }) do
		pcall(function() skyState.orig[k] = Lighting[k] end)
	end
end

local function restoreLighting()
	for k, v in pairs(skyState.orig) do pcall(function() Lighting[k] = v end) end
	skyState.orig = {}
	skyState.saved = false
end

local function killSky()
	if skyState.sky then pcall(function() skyState.sky:Destroy() end) skyState.sky = nil end
	for _, c in ipairs(Lighting:GetChildren()) do
		if c:IsA("Sky") then pcall(function() c:Destroy() end) end
	end
end

local function killAtmo()
	if skyState.atmo then pcall(function() skyState.atmo:Destroy() end) skyState.atmo = nil end
	for _, c in ipairs(Lighting:GetChildren()) do
		if c:IsA("Atmosphere") then pcall(function() c:Destroy() end) end
	end
end

local function ensureAtmo()
	if skyState.atmo and skyState.atmo.Parent then return skyState.atmo end
	killAtmo()
	local a = Instance.new("Atmosphere")
	a.Parent = Lighting
	skyState.atmo = a
	return a
end

local function setSkybox(id)
	saveLighting()
	killSky()
	if not id or id == 0 then return end
	local a = "rbxassetid://" .. tostring(id)
	local sky = Instance.new("Sky")
	sky.SkyboxBk = a sky.SkyboxDn = a sky.SkyboxFt = a
	sky.SkyboxLf = a sky.SkyboxRt = a sky.SkyboxUp = a
	sky.Parent = Lighting
	skyState.sky = sky
end

local ATMO = {
	Jour = { ClockTime = 13.5, Brightness = 2.4, FogEnd = 6000, FogStart = 0,
		Ambient = Color3.fromRGB(110, 118, 132), Outdoor = Color3.fromRGB(150, 160, 175),
		Density = 0.22, Haze = 0, Glare = 0.1, Decay = Color3.fromRGB(96, 108, 124), Offset = 0,
		FogColor = Color3.fromRGB(200, 214, 230) },
	Aube = { ClockTime = 6.2, Brightness = 1.8, FogEnd = 2200, FogStart = 20,
		Ambient = Color3.fromRGB(96, 88, 104), Outdoor = Color3.fromRGB(180, 140, 140),
		Density = 0.38, Haze = 1.6, Glare = 0.6, Decay = Color3.fromRGB(180, 120, 110), Offset = 0.1,
		FogColor = Color3.fromRGB(232, 190, 176) },
	Coucher = { ClockTime = 18.4, Brightness = 1.4, FogEnd = 1800, FogStart = 10,
		Ambient = Color3.fromRGB(78, 62, 78), Outdoor = Color3.fromRGB(190, 110, 96),
		Density = 0.45, Haze = 2.4, Glare = 0.9, Decay = Color3.fromRGB(210, 110, 80), Offset = 0.2,
		FogColor = Color3.fromRGB(226, 150, 118) },
	Nuit = { ClockTime = 0.4, Brightness = 0.7, FogEnd = 900, FogStart = 0,
		Ambient = Color3.fromRGB(22, 28, 44), Outdoor = Color3.fromRGB(30, 38, 58),
		Density = 0.5, Haze = 1.2, Glare = 0.35, Decay = Color3.fromRGB(40, 52, 80), Offset = 0.15,
		FogColor = Color3.fromRGB(18, 24, 40) },
	Brum = { ClockTime = 8, Brightness = 1.1, FogEnd = 420, FogStart = 6,
		Ambient = Color3.fromRGB(96, 102, 110), Outdoor = Color3.fromRGB(120, 128, 138),
		Density = 0.72, Haze = 4.5, Glare = 0.15, Decay = Color3.fromRGB(130, 138, 148), Offset = 0.3,
		FogColor = Color3.fromRGB(178, 188, 196) },
	Neon = { ClockTime = 1.2, Brightness = 1.6, FogEnd = 1400, FogStart = 0,
		Ambient = Color3.fromRGB(24, 14, 44), Outdoor = Color3.fromRGB(40, 20, 70),
		Density = 0.4, Haze = 2.2, Glare = 1.4, Decay = Color3.fromRGB(120, 60, 220), Offset = 0.25,
		FogColor = Color3.fromRGB(46, 22, 82) },
	Orage = { ClockTime = 15, Brightness = 0.9, FogEnd = 700, FogStart = 4,
		Ambient = Color3.fromRGB(44, 48, 58), Outdoor = Color3.fromRGB(62, 68, 80),
		Density = 0.68, Haze = 3.4, Glare = 0.2, Decay = Color3.fromRGB(70, 78, 92), Offset = 0.2,
		FogColor = Color3.fromRGB(96, 104, 116) },
}

local function applyAtmo(name)
	saveLighting()
	local p = ATMO[name]
	if not p then return end
	local a = ensureAtmo()
	pcall(function()
		Lighting.ClockTime = p.ClockTime Lighting.Brightness = p.Brightness
		Lighting.FogEnd = p.FogEnd Lighting.FogStart = p.FogStart
		Lighting.FogColor = p.FogColor Lighting.Ambient = p.Ambient
		Lighting.OutdoorAmbient = p.Outdoor
		a.Density = p.Density a.Haze = p.Haze a.Glare = p.Glare
		a.Decay = p.Decay a.Offset = p.Offset a.Color = p.FogColor
	end)
end

local SKIES = { { "Aucun", 0 }, { "Ciel degage", 271157042 }, { "Coucher", 64449541 },
	{ "Nuit", 179725526 }, { "Espace", 1141339603 }, { "Nuageux", 159454299 } }

-- ================= BYPASS =================
local Hooks = { namecall = nil, newindex = nil, index = nil }
local hookInstalled = false
local BLog = {}
local kickCount = 0

local AC_WORDS = { "anticheat", "anti cheat", "anti-cheat", "anti_cheat",
	"ac_", "_ac", "watchdog", "guardian", "sentinel", "cheat" }
local AC_REASONS = { "speed", "fly", "exploit", "cheat", "detect", "anticheat", "hack",
	"suspect", "movement", "velocity", "teleport", "walkspeed", "jumppower", "desync", "anomaly" }

local function blog(msg)
	BLog[#BLog + 1] = msg
	if #BLog > 80 then table.remove(BLog, 1) end
	task.spawn(toast, "bypass · " .. msg)
end

local function matches(list, str)
	local s = str:lower()
	for _, w in ipairs(list) do
		if s:find(w, 1, true) then return true end
	end
	return false
end

local function isCaller()
	if checkcaller then return checkcaller() end
	return bypassWrite
end

local function queueRejoin()
	if objs.rejoin then return end
	objs.rejoin = true
	blog("reconnexion dans 2s")
	task.delay(2, function()
		pcall(function() game:GetService("TeleportService"):Teleport(game.PlaceId, LP) end)
	end)
end

local function killLocalAC()
	local killed = 0
	for _, root in ipairs({ LP:FindFirstChild("PlayerScripts"), LP:FindFirstChild("PlayerGui"),
		game:GetService("ReplicatedFirst"), WS }) do
		if root then
			for _, d in ipairs(root:GetDescendants()) do
				if d:IsA("LocalScript") and not d.Disabled and matches(AC_WORDS, d.Name) then
					pcall(function() d.Disabled = true end)
					killed = killed + 1
				end
			end
		end
	end
	return killed
end

local function killHumanSignals()
	if not getconnections then return 0 end
	local _, h = alive(LP)
	if not h then return 0 end
	local n = 0
	for _, prop in ipairs({ "WalkSpeed", "JumpPower", "HipHeight" }) do
		pcall(function()
			for _, c in ipairs(getconnections(h:GetPropertyChangedSignal(prop))) do
				pcall(function() c:Disable() end)
				n = n + 1
			end
		end)
	end
	return n
end

local function killACConns()
	if not getconnections then return 0 end
	local n = 0
	for _, sig in ipairs({ RunService.Heartbeat, RunService.RenderStepped, RunService.Stepped }) do
		local ok, list = pcall(getconnections, sig)
		if ok and type(list) == "table" then
			for _, c in ipairs(list) do
				local okSrc, src = pcall(function() return debug.info(c.Function, "s") end)
				if okSrc and type(src) == "string" and matches(AC_WORDS, src) then
					pcall(function() c:Disable() end)
					n = n + 1
				end
			end
		end
	end
	return n
end

local function installHooks()
	if hookInstalled and Hooks.namecall then return true end
	local ok = pcall(function()
		local getmt = getrawmetatable or (debug and debug.getmetatable)
		local mt = getmt and getmt(game)
		if not mt or not mt.__namecall then error("metatable inaccessible") end
		setreadonly(mt, false)

		local oldNC = mt.__namecall
		local fnNC = newcclosure(function(self, ...)
			if not isCaller() then
				local m = getnamecallmethod()
				if m == "Kick" and B.kick and typeof(self) == "Instance" and self:IsA("Player") then
					local a = { ... }
					local reason = tostring(a[1] or "")
					if not B.kickFilter or matches(AC_REASONS, reason) then
						kickCount = kickCount + 1
						blog("kick bloque (" .. kickCount .. ") : " .. (reason ~= "" and reason or "sans raison"))
						if B.rejoin then queueRejoin() end
						return nil
					end
				elseif m == "Destroy" and B.gui and self == ownGui and not unloading then
					blog("destruction du gui bloquee")
					return nil
				elseif m == "GetPropertyChangedSignal" and B.sigspoof then
					local a = { ... }
					if typeof(self) == "Instance" and self:IsA("Humanoid")
						and (a[1] == "WalkSpeed" or a[1] == "JumpPower" or a[1] == "HipHeight") then
						return oldNC(self, "ClassName")
					end
				elseif SA.on and (m == "ScreenPointToRay" or m == "ViewportPointToRay") then
					local pos = silentTarget()
					if pos and typeof(self) == "Instance" and self:IsA("Camera") then
						local origin = Camera.CFrame.Position
						local dir = pos - origin
						if dir.Magnitude > 0.1 then
							local a = { ... }
							return Ray.new(origin, dir.Unit * (tonumber(a[3]) or 1000))
						end
					end
				elseif SA.on and (m == "Raycast" or m == "FindPartOnRay" or m == "FindPartOnRayWithIgnoreList") and self == WS then
					local pos = silentTarget()
					if pos then
						local a = { ... }
						if m == "Raycast" and typeof(a[1]) == "Vector3" and typeof(a[2]) == "Vector3" then
							local nd = pos - a[1]
							if nd.Magnitude > 0.1 then
								return oldNC(self, a[1], nd.Unit * a[2].Magnitude, a[3])
							end
						elseif typeof(a[1]) == "Ray" then
							local nd = pos - a[1].Origin
							if nd.Magnitude > 0.1 then
								return oldNC(self, Ray.new(a[1].Origin, nd.Unit * a[1].Direction.Magnitude), a[2])
							end
						end
					end
				end
			end
			return oldNC(self, ...)
		end)
		mt.__namecall = fnNC
		Hooks.namecall = fnNC

		local oldNI = mt.__newindex
		if oldNI then
			local fnNI = newcclosure(function(self, k, v)
				if not bypassWrite and not (checkcaller and checkcaller()) then
					if (k == "WalkSpeed" or k == "JumpPower" or k == "HipHeight")
						and B.lock and typeof(self) == "Instance" and self:IsA("Humanoid") then
						local lh = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
						if self == lh then return end
					end
					if k == "Parent" and v == nil and B.gui and self == ownGui and not unloading then
						return
					end
				end
				return oldNI(self, k, v)
			end)
			mt.__newindex = fnNI
			Hooks.newindex = fnNI
		end

		local oldIX = mt.__index
		if oldIX then
			local fnIX = newcclosure(function(self, k)
				if not isCaller() then
					if SA.on and typeof(self) == "Instance" and self:IsA("Mouse")
						and (k == "UnitRay" or k == "Hit" or k == "Target") then
						local pos = silentTarget()
						if pos then
							local origin = Camera.CFrame.Position
							if k == "UnitRay" then
								local d = pos - origin
								if d.Magnitude > 0.1 then return Ray.new(origin, d.Unit * 1000) end
							else
								local hit = WS:Raycast(origin, (pos - origin) * 1.2)
								if k == "Hit" then return hit and hit.Position or pos end
								return hit and hit.Instance
							end
						end
					end
					if B.velspoof and (k == "AssemblyLinearVelocity" or k == "Velocity") then
						local v = oldIX(self, k)
						if typeof(v) == "Vector3" and v.Magnitude > B.maxvel then
							return v.Unit * B.maxvel
						end
						return v
					end
				end
				return oldIX(self, k)
			end)
			mt.__index = fnIX
			Hooks.index = fnIX
		end

		setreadonly(mt, true)
		hookInstalled = true
	end)
	return ok and hookInstalled
end

local function unhook()
	pcall(function()
		local getmt = getrawmetatable or (debug and debug.getmetatable)
		local mt = getmt and getmt(game)
		if not mt then return end
		setreadonly(mt, false)
		if Hooks.namecall and mt.__namecall == Hooks.namecall then mt.__namecall = nil end
		if Hooks.newindex and mt.__newindex == Hooks.newindex then mt.__newindex = nil end
		if Hooks.index and mt.__index == Hooks.index then mt.__index = nil end
		setreadonly(mt, true)
	end)
	hookInstalled = false
	Hooks.namecall, Hooks.newindex, Hooks.index = nil, nil, nil
end

task.spawn(function()
	while not dead do
		task.wait(2)
		if hookInstalled and Hooks.namecall then
			pcall(function()
				local getmt = getrawmetatable or (debug and debug.getmetatable)
				local mt = getmt and getmt(game)
				if mt and mt.__namecall ~= Hooks.namecall then
					hookInstalled = false
					Hooks.namecall = nil
					if installHooks() then blog("hooks restaures") end
				end
			end)
		end
	end
end)

local function diagnose()
	local lines = {}
	local function add(k, v) lines[#lines + 1] = k .. " : " .. v end
	local okE, ex = pcall(function() return identifyexecutor and identifyexecutor() end)
	add("executeur", okE and tostring(ex) or "inconnu")
	add("hookmetamethod", type(hookmetamethod) == "function" and "oui" or "non")
	add("getconnections", type(getconnections) == "function" and "oui" or "non")
	add("checkcaller", type(checkcaller) == "function" and "oui" or "non")
	add("mousemoverel", type(mousemoverel) == "function" and "oui" or "non")
	add("mousemoveabs", type(mousemoveabs) == "function" and "oui" or "non")
	add("hooks actifs", hookInstalled and "oui" or "non")
	add("kicks bloques", tostring(kickCount))
	add("journal", tostring(#BLog) .. " entrees")
	return table.concat(lines, "\n")
end

local PROFILES = {
	Discret = { env = true, kick = true, kickFilter = true, rejoin = false,
		lock = false, sigspoof = false, velspoof = false,
		conns = false, scripts = true, gui = true, fpscap = true },
	Standard = { env = true, kick = true, kickFilter = true, rejoin = false,
		lock = true, sigspoof = true, velspoof = false,
		conns = true, scripts = true, gui = true, fpscap = false },
	Agressif = { env = true, kick = true, kickFilter = false, rejoin = true,
		lock = true, sigspoof = true, velspoof = true,
		conns = true, scripts = true, gui = true, fpscap = false },
}

local function applyProfile(name)
	local p = PROFILES[name]
	if not p then return end
	B.profile = name
	for k, v in pairs(p) do B[k] = v end
end

local function runBypass()
	blog("profil " .. B.profile)
	if B.env then
		blog(pcall(function()
			getgenv().SMOOTH_BYPASS = true
			if type(getmetatable(getgenv())) ~= "table" then setmetatable(getgenv(), {}) end
		end) and "environnement isole" or "isolation impossible")
	end
	blog(installHooks() and "hooks poses" or "hooks indisponibles")
	if B.scripts then blog("scripts AC desactives : " .. killLocalAC()) end
	if B.sigspoof then blog("signaux coupes : " .. killHumanSignals()) end
	if B.conns then blog("boucles coupees : " .. killACConns()) end
	if B.fpscap then blog(pcall(function() setfpscap(B.fps) end) and ("fps plafonnes a " .. B.fps) or "setfpscap absent") end
end

-- ================= POPUP =================
local bypassDone = false

do
	local layer = Instance.new("Frame")
	layer.Size = UDim2.fromScale(1, 1)
	layer.BackgroundColor3 = Color3.new(0, 0, 0)
	layer.BackgroundTransparency = 0.45
	layer.BorderSizePixel = 0
	layer.ZIndex = 400
	layer.Parent = ownGui

	local win = Instance.new("Frame")
	win.AnchorPoint = Vector2.new(0.5, 0.5)
	win.Position = UDim2.fromScale(0.5, 0.5)
	win.Size = UDim2.fromOffset(392, 300)
	win.BackgroundColor3 = Color3.fromRGB(9, 12, 18)
	win.BorderSizePixel = 0
	win.ZIndex = 401
	win.Parent = layer
	Instance.new("UICorner", win).CornerRadius = UDim.new(0, 10)
	local st = Instance.new("UIStroke", win)
	st.Color = Color3.fromRGB(0, 214, 255)
	st.Transparency = 0.55

	local bar = Instance.new("TextButton")
	bar.Size = UDim2.new(1, 0, 0, 36)
	bar.BackgroundTransparency = 1
	bar.Text = ""
	bar.AutoButtonColor = false
	bar.ZIndex = 402
	bar.Parent = win

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(16, 0)
	title.Size = UDim2.new(1, -32, 0, 36)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 13
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(0, 214, 255)
	title.Text = "SMOOTH.DEV  ·  DEMARRAGE"
	title.ZIndex = 402
	title.Parent = bar

	local sep = Instance.new("Frame")
	sep.Position = UDim2.fromOffset(0, 36)
	sep.Size = UDim2.new(1, 0, 0, 1)
	sep.BackgroundColor3 = Color3.fromRGB(26, 34, 46)
	sep.BorderSizePixel = 0
	sep.ZIndex = 402
	sep.Parent = win

	local sub = Instance.new("TextLabel")
	sub.Position = UDim2.fromOffset(16, 46)
	sub.Size = UDim2.new(1, -32, 0, 16)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 11
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextColor3 = Color3.fromRGB(120, 136, 154)
	sub.Text = "Choisis un profil de protection"
	sub.ZIndex = 402
	sub.Parent = win

	local status = Instance.new("TextLabel")
	status.Position = UDim2.fromOffset(16, 118)
	status.Size = UDim2.new(1, -32, 0, 14)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.Code
	status.TextSize = 9
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextColor3 = Color3.fromRGB(96, 110, 128)
	status.Text = "en attente"
	status.ZIndex = 402
	status.Parent = win

	local profRow = Instance.new("Frame")
	profRow.Position = UDim2.fromOffset(16, 72)
	profRow.Size = UDim2.new(1, -32, 0, 28)
	profRow.BackgroundTransparency = 1
	profRow.ZIndex = 402
	profRow.Parent = win

	local labels = {}
	for i, name in ipairs({ "Discret", "Standard", "Agressif" }) do
		local b = Instance.new("TextButton")
		b.Position = UDim2.fromOffset((i - 1) * 118, 0)
		b.Size = UDim2.fromOffset(112, 28)
		b.BackgroundColor3 = Color3.fromRGB(16, 21, 30)
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		b.Font = Enum.Font.GothamBold
		b.TextSize = 11
		b.Text = name
		b.TextColor3 = Color3.fromRGB(140, 156, 174)
		b.ZIndex = 403
		b.Parent = profRow
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
		local s2 = Instance.new("UIStroke", b)
		s2.Color = Color3.fromRGB(0, 214, 255)
		s2.Transparency = 1
		labels[name] = { btn = b, stroke = s2 }
		b.MouseButton1Click:Connect(function()
			applyProfile(name)
			for n, r in pairs(labels) do
				local on = n == name
				r.stroke.Transparency = on and 0.3 or 1
				r.btn.TextColor3 = on and Color3.fromRGB(0, 214, 255) or Color3.fromRGB(140, 156, 174)
			end
			status.Text = "profil " .. name .. " selectionne"
		end)
	end

	local logBox = Instance.new("ScrollingFrame")
	logBox.Position = UDim2.fromOffset(16, 140)
	logBox.Size = UDim2.new(1, -32, 0, 78)
	logBox.BackgroundColor3 = Color3.fromRGB(6, 9, 14)
	logBox.BorderSizePixel = 0
	logBox.ScrollBarThickness = 3
	logBox.CanvasSize = UDim2.new(0, 0, 0, 0)
	logBox.AutomaticCanvasSize = Enum.AutomaticSize.Y
	logBox.ZIndex = 402
	logBox.Parent = win
	Instance.new("UICorner", logBox).CornerRadius = UDim.new(0, 6)
	local ll = Instance.new("UIListLayout")
	ll.Padding = UDim.new(0, 2)
	ll.Parent = logBox

	local function push(msg)
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, -12, 0, 13)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.Code
		l.TextSize = 9
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = Color3.fromRGB(110, 150, 170)
		l.Text = msg
		l.ZIndex = 403
		l.Parent = logBox
	end

	local function btn(text, x, color, cb)
		local b = Instance.new("TextButton")
		b.Position = UDim2.new(0, x, 1, -44)
		b.Size = UDim2.fromOffset(174, 30)
		b.BackgroundColor3 = color
		b.BackgroundTransparency = 0.1
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		b.Font = Enum.Font.GothamBold
		b.TextSize = 11
		b.TextColor3 = Color3.fromRGB(6, 10, 16)
		b.Text = text
		b.ZIndex = 403
		b.Parent = win
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
		b.MouseButton1Click:Connect(cb)
		return b
	end

	btn("APPLIQUER ET LANCER", 16, Color3.fromRGB(0, 214, 255), function()
		if bypassDone then return end
		bypassDone = true
		runBypass()
		task.wait(0.3)
		pcall(function() layer:Destroy() end)
	end)

	local sk = btn("IGNORER", 202, Color3.fromRGB(46, 56, 70), function()
		if bypassDone then return end
		bypassDone = true
		pcall(function() layer:Destroy() end)
	end)
	sk.TextColor3 = Color3.fromRGB(210, 224, 236)

	local dragging, startPos, startInput
	bar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			startInput = i.Position
			startPos = win.Position
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - startInput
			win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	UIS.InputEnded:Connect(function() dragging = false end)

	for n, r in pairs(labels) do
		local on = n == B.profile
		r.stroke.Transparency = on and 0.3 or 1
		r.btn.TextColor3 = on and Color3.fromRGB(0, 214, 255) or Color3.fromRGB(140, 156, 174)
	end

	push("place " .. game.PlaceId)
	push("hookmetamethod : " .. (type(hookmetamethod) == "function" and "disponible" or "absent"))
	push("getconnections : " .. (type(getconnections) == "function" and "disponible" or "absent"))
	push("profil " .. B.profile .. " actif")

	while not bypassDone do task.wait() end
end

-- ================= INTRO =================
local introLayer = Instance.new("Frame")
introLayer.Size = UDim2.fromScale(1, 1)
introLayer.BackgroundColor3 = Color3.new(0, 0, 0)
introLayer.BorderSizePixel = 0
introLayer.ZIndex = 300
introLayer.Parent = ownGui

local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.new(1, 1, 1)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.ZIndex = 302
flash.Parent = introLayer

local slam = Instance.new("TextLabel")
slam.AnchorPoint = Vector2.new(0.5, 0.5)
slam.Position = UDim2.fromScale(0.5, 0.47)
slam.Size = UDim2.new(1, 0, 0, 220)
slam.BackgroundTransparency = 1
slam.Font = Enum.Font.GothamBlack
slam.TextSize = 210
slam.Text = "SMOOTH.DEV"
slam.TextColor3 = Color3.fromRGB(0, 214, 255)
slam.ZIndex = 303
slam.Parent = introLayer

local introRule = Instance.new("Frame")
introRule.AnchorPoint = Vector2.new(0.5, 0.5)
introRule.Position = UDim2.fromScale(0.5, 0.585)
introRule.Size = UDim2.fromOffset(0, 2)
introRule.BackgroundColor3 = Color3.fromRGB(0, 214, 255)
introRule.BorderSizePixel = 0
introRule.ZIndex = 303
introRule.Parent = introLayer

local introStatus = Instance.new("TextLabel")
introStatus.AnchorPoint = Vector2.new(0.5, 0.5)
introStatus.Position = UDim2.fromScale(0.5, 0.635)
introStatus.Size = UDim2.fromOffset(560, 16)
introStatus.BackgroundTransparency = 1
introStatus.Font = Enum.Font.Code
introStatus.TextSize = 11
introStatus.TextColor3 = Color3.fromRGB(110, 128, 148)
introStatus.TextTransparency = 1
introStatus.ZIndex = 303
introStatus.Parent = introLayer

local introSnd = Instance.new("Sound")
introSnd.SoundId = "rbxassetid://131961136"
introSnd.Volume = 3.2
introSnd.Parent = SoundSvc
pcall(function() introSnd:Play() end)

local LIB_URLS = {
	"https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua",
	"https://raw.githubusercontent.com/Footagesus/WindUI/refs/heads/main/dist/main.lua",
	"https://raw.githubusercontent.com/Footagesus/WindUI/refs/heads/main/main.lua",
	"https://github.com/Footagesus/WindUI/releases/latest/download/main.lua",
}

local WindUI, libDone, libErr = nil, false, nil

local function tryLoad()
	for _, url in ipairs(LIB_URLS) do
		local ok, res = pcall(function()
			local body
			local o1, b1 = pcall(function() return game:HttpGet(url, true) end)
			if o1 then body = b1 else
				local o2, b2 = pcall(function() return game:HttpGet(url) end)
				if not o2 then error(b2) end
				body = b2
			end
			return (loadstring or load)(body)()
		end)
		if ok and type(res) == "table" and res.CreateWindow then return res end
		libErr = tostring(res)
	end
	return nil
end

task.spawn(function() WindUI = tryLoad() libDone = true end)

local function waitLib()
	local function waitFor(sec)
		local d = os.clock() + sec
		while not libDone and os.clock() < d do task.wait(0.1) end
		return WindUI ~= nil
	end
	if waitFor(14) then return true end

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(440, 190)
	panel.BackgroundColor3 = Color3.fromRGB(10, 13, 20)
	panel.BorderSizePixel = 0
	panel.ZIndex = 310
	panel.Parent = introLayer
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

	local pt = Instance.new("TextLabel")
	pt.Position = UDim2.fromOffset(20, 18)
	pt.Size = UDim2.new(1, -40, 0, 18)
	pt.BackgroundTransparency = 1
	pt.Font = Enum.Font.GothamBold
	pt.TextSize = 12
	pt.TextXAlignment = Enum.TextXAlignment.Left
	pt.TextColor3 = Color3.fromRGB(240, 120, 120)
	pt.Text = "CHARGEMENT IMPOSSIBLE"
	pt.ZIndex = 311
	pt.Parent = panel

	local pb = Instance.new("TextLabel")
	pb.Position = UDim2.fromOffset(20, 42)
	pb.Size = UDim2.new(1, -40, 0, 60)
	pb.BackgroundTransparency = 1
	pb.Font = Enum.Font.Code
	pb.TextSize = 10
	pb.TextWrapped = true
	pb.TextXAlignment = Enum.TextXAlignment.Left
	pb.TextYAlignment = Enum.TextYAlignment.Top
	pb.TextColor3 = Color3.fromRGB(150, 164, 180)
	pb.Text = string.sub(tostring(libErr or "aucune reponse"), 1, 240)
	pb.ZIndex = 311
	pb.Parent = panel

	local choice = nil
	local function pbtn(txt, x, col, fn)
		local b = Instance.new("TextButton")
		b.Position = UDim2.new(0, x, 1, -42)
		b.Size = UDim2.fromOffset(190, 28)
		b.BackgroundColor3 = col
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		b.Font = Enum.Font.GothamBold
		b.TextSize = 11
		b.Text = txt
		b.ZIndex = 311
		b.Parent = panel
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
		b.MouseButton1Click:Connect(fn)
		return b
	end
	pbtn("REESSAYER", 20, Color3.fromRGB(0, 214, 255), function() choice = "retry" end)
	pbtn("FERMER", 230, Color3.fromRGB(46, 56, 70), function() choice = "close" end)

	while true do
		choice = nil
		repeat task.wait(0.1) until choice
		pcall(function() panel:Destroy() end)
		if choice == "close" then return false end
		introStatus.Text = "nouvelle tentative"
		libDone = false
		task.spawn(function() WindUI = tryLoad() libDone = true end)
		if waitFor(14) then return true end
		return waitLib()
	end
end

local function runScreamer()
	Tween:Create(slam, TweenInfo.new(0.2, Enum.EasingStyle.Circular, Enum.EasingDirection.Out), { TextSize = 96 }):Play()
	flash.BackgroundTransparency = 0.55
	Tween:Create(flash, TweenInfo.new(0.26), { BackgroundTransparency = 1 }):Play()
	task.wait(0.14)
	Tween:Create(introRule, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(340, 2) }):Play()
	introStatus.TextTransparency = 0
	for _, s in ipairs({ "BYPASS ACTIF", "CHARGEMENT DES MODULES", "MONTAGE DE L'INTERFACE" }) do
		introStatus.Text = s
		task.wait(0.28)
	end
	if not waitLib() then return false end
	Tween:Create(introLayer, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
	Tween:Create(slam, TweenInfo.new(0.4), { TextTransparency = 1, TextSize = 76 }):Play()
	Tween:Create(introRule, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
	Tween:Create(introStatus, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
	task.wait(0.42)
	return true
end

local before = {}
for _, g in ipairs(game:GetService("CoreGui"):GetChildren()) do before[g] = true end

if not runScreamer() then
	local err = Instance.new("TextLabel")
	err.AnchorPoint = Vector2.new(0.5, 0.5)
	err.Position = UDim2.fromScale(0.5, 0.5)
	err.Size = UDim2.fromOffset(600, 40)
	err.BackgroundTransparency = 1
	err.Font = Enum.Font.GothamBold
	err.TextSize = 13
	err.TextColor3 = Color3.fromRGB(230, 110, 110)
	err.Text = "SMOOTH.DEV — WindUI introuvable"
	err.Parent = ownGui
	pcall(function() introLayer:Destroy() end)
	return
end

local winProps = {}
winProps.Title = "SMOOTH.DEV"
winProps.Author = "smooth.dev"
winProps.Folder = "SmoothDev"
winProps.Theme = "Dark"
winProps.Size = UDim2.fromOffset(620, 500)
winProps.ToggleKey = Enum.KeyCode.Insert
winProps.HasOutline = true
winProps.Resizable = true

local window
if not pcall(function() window = WindUI:CreateWindow(winProps) end) or not window then
	pcall(function() introLayer:Destroy() end)
	return
end

for _, g in ipairs(game:GetService("CoreGui"):GetChildren()) do
	if not before[g] and g:IsA("ScreenGui") then
		if syn and syn.protect_gui then pcall(syn.protect_gui, g) end
		g.DisplayOrder = 2147483646
		g.ResetOnSpawn = false
		menuGui = g
		break
	end
end

pcall(function() introLayer:Destroy() end)

-- ================= WIDGETS =================
local function safe(fn)
	local ok, err = pcall(fn)
	if not ok then warn("[SMOOTH.DEV] widget: " .. tostring(err)) end
end

local function newTab(t, i) local p = {} p.Title = t p.Icon = i return window:Tab(p) end
local function newSection(pa, t) local p = {} p.Title = t return pa:Section(p) end
local function newParagraph(pa, t) local p = {} p.Title = t return pa:Paragraph(p) end
local function newButton(pa, t, cb) safe(function() local p = {} p.Title = t p.Callback = cb pa:Button(p) end) end

local function newDropdown(pa, t, d, vals, def, cb)
	safe(function()
		local p = {}
		p.Title = t p.Desc = d p.Values = vals p.Value = def p.Callback = cb
		pa:Dropdown(p)
	end)
end

local function newToggle(pa, t, d, tbl, key, cb)
	safe(function()
		local p = {}
		p.Title = t p.Desc = d p.Value = tbl[key]
		p.Callback = function(v) tbl[key] = v if cb then cb(v) end end
		pa:Toggle(p)
	end)
end

local function newSlider(pa, t, d, tbl, key, mn, mx, cb)
	safe(function()
		local range = {} range.Min = mn range.Max = mx range.Default = tbl[key] or mn
		local p = {}
		p.Title = t p.Desc = d p.Value = range
		p.Callback = function(v) tbl[key] = v if cb then cb(v) end end
		pa:Slider(p)
	end)
end

local function newKeybind(pa, t, d, tbl, key)
	safe(function()
		local p = {}
		p.Title = t p.Desc = d p.Value = tbl[key].Name
		p.Callback = function(v)
			local kc = Enum.KeyCode[v]
			if kc then tbl[key] = kc end
		end
		pa:Keybind(p)
	end)
end

local function newInput(pa, t, d, ph, cb)
	safe(function()
		local p = {}
		p.Title = t p.Desc = d p.Placeholder = ph p.Callback = cb
		pa:Input(p)
	end)
end

-- ================= CONSTRUCTION UI =================
local U = {}

-- ================= BULLE CLIQUABLE =================
do
	local bgui, btn, dragging, startPos, moved, pressAt = nil, nil, false, nil, 0, 0

	local function ensure()
		if bgui and bgui.Parent then return end
		bgui = Instance.new("ScreenGui")
		bgui.Name = "SmoothDevBubble"
		bgui.ResetOnSpawn = false
		bgui.IgnoreGuiInset = true
		bgui.DisplayOrder = 2147483647
		bgui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		if syn and syn.protect_gui then pcall(syn.protect_gui, bgui) end
		pcall(function() bgui.Parent = game:GetService("CoreGui") end)
		if not bgui.Parent and type(gethui) == "function" then
			pcall(function() bgui.Parent = gethui() end)
		end
		if not bgui.Parent then bgui.Parent = LP:WaitForChild("PlayerGui") end

		btn = Instance.new("TextButton")
		btn.Size = UDim2.fromOffset(52, 52)
		btn.Position = UDim2.new(1, -72, 0.5, -26)
		btn.BackgroundColor3 = Color3.fromRGB(9, 12, 18)
		btn.BackgroundTransparency = 0.08
		btn.Text = "S"
		btn.Font = Enum.Font.GothamBlack
		btn.TextSize = 21
		btn.TextColor3 = Color3.fromRGB(0, 214, 255)
		btn.AutoButtonColor = false
		btn.BorderSizePixel = 0
		btn.Visible = false
		btn.ZIndex = 2
		btn.Parent = bgui
		Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
		local bs = Instance.new("UIStroke", btn)
		bs.Color = Color3.fromRGB(0, 214, 255)
		bs.Thickness = 2
		bs.Transparency = 0.1
		local grd = Instance.new("UIGradient", bs)
		grd.Color = ColorSequence.new(Color3.fromRGB(0, 214, 255), Color3.fromRGB(120, 60, 255))
		grd.Rotation = 45

		btn.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				moved = 0
				pressAt = os.clock()
				startPos = Vector2.new(btn.AbsolutePosition.X, btn.AbsolutePosition.Y) - Vector2.new(i.Position.X, i.Position.Y)
				Tween:Create(btn, TweenInfo.new(0.1), { Size = UDim2.fromOffset(58, 58) }):Play()
			end
		end)

		track(UIS.InputChanged:Connect(function(i)
			if not dragging then return end
			if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement then
				local np = startPos + Vector2.new(i.Position.X, i.Position.Y)
				moved = moved + (i.Delta and i.Delta.Magnitude or 0)
				btn.Position = UDim2.fromOffset(np.X, np.Y)
			end
		end))

		track(UIS.InputEnded:Connect(function(i)
			if not dragging then return end
			if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
				Tween:Create(btn, TweenInfo.new(0.1), { Size = UDim2.fromOffset(52, 52) }):Play()
				local vp = Camera.ViewportSize
				local x, y = btn.AbsolutePosition.X, btn.AbsolutePosition.Y
				local tx = ((x + 26) < vp.X / 2) and 14 or (vp.X - 66)
				Tween:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Position = UDim2.fromOffset(tx, math.clamp(y, 50, math.max(vp.Y - 110, 70)))
				}):Play()
				if moved < 8 and os.clock() - pressAt < 1.2 then Bubble.restore() end
			end
		end))
	end

	Bubble = { on = false }

	function Bubble.show()
		if not U.showBubble then return end
		ensure()
		btn.Visible = true
	end

	function Bubble.hideBubble()
		if btn then btn.Visible = false end
	end

	function Bubble.collapse()
		if Bubble.on then return end
		Bubble.on = true
		if menuGui then menuGui.Enabled = false end
		Bubble.show()
	end

	function Bubble.restore()
		if not Bubble.on then return end
		Bubble.on = false
		Bubble.hideBubble()
		if menuGui then menuGui.Enabled = true end
		pcall(function() if window and window.Open then window:Open() end end)
	end

	function Bubble.sync()
		if not menuGui or not menuGui.Parent then return end
		if menuGui.Enabled and Bubble.on then
			Bubble.on = false
			Bubble.hideBubble()
		elseif not menuGui.Enabled and not Bubble.on then
			Bubble.collapse()
		end
	end

	function Bubble.destroy()
		if bgui then pcall(function() bgui:Destroy() end) bgui = nil end
	end
end

U.showBubble = true

pcall(function()
	if window.OnClose then
		window:OnClose(function() Bubble.collapse() end)
	end
end)

task.spawn(function()
	while not dead do
		task.wait(0.25)
		if dead then break end
		pcall(Bubble.sync)
	end
end)

local function buildUI()
	local aimTab = newTab("Aim", "crosshair")
	local secMain = newSection(aimTab, "Aimbot")
	newToggle(secMain, "Aimbot", "Visee automatique", AB, "on", function(v)
		if v then installHooks() else locked = nil end
	end)
	newDropdown(secMain, "Declenchement", "Toujours actif ou touche",
		{ "Toujours", "Touche", "Toggle" }, AB.mode, function(v) AB.mode = v AB.toggled = false end)
	newKeybind(secMain, "Touche de visee", "Pour Touche et Toggle", AB, "key")
	newToggle(secMain, "Ciblage collant", "Garde la cible un instant", AB, "sticky")
	newSlider(secMain, "Duree du collage", "Millisecondes", AB, "stickyms", 60, 900)
	newDropdown(secMain, "Priorite", "Choix de la cible", { "Curseur", "Distance", "Vie" },
		AB.priority, function(v) AB.priority = v end)
	newSlider(secMain, "FOV", "Champ de detection", AB, "fov", 20, 600)
	newSlider(secMain, "Lissage", "Secondes pour verrouiller", AB, "smooth", 0.02, 0.6)
	newSlider(secMain, "Prediction", "Avance sur le mouvement", AB, "pred", 0, 1)
	newSlider(secMain, "Distance max", "Portee", AB, "maxd", 50, 3000)
	newDropdown(secMain, "Partie visee", "Zone ciblee", { "Head", "Nearest", "Random", "Torso" },
		AB.part, function(v) AB.part = v end)
	newToggle(secMain, "Verif equipe", "Ignore les allies", AB, "team")
	newToggle(secMain, "Ignore au sol", "Saute les joueurs tombes", AB, "ignoreknock")
	newToggle(secMain, "Wall check", "Uniquement a vue", AB, "vis")

	local secMore = newSection(aimTab, "Comportement")
	newDropdown(secMore, "Methode", "Technique d'application", { "CFrame", "Relatif", "Absolu" },
		AB.style, function(v) AB.style = v end)
	newParagraph(secMore, "CFrame fiable partout. Relatif et Absolu bougent le vrai curseur.")
	newToggle(secMore, "Snap instantane", "Sans lissage", AB, "instant")
	newToggle(secMore, "Marqueur de cible", "Croix sur la cible", AB, "marker")
	newToggle(secMore, "Cercle FOV", "Affiche le champ", ESP, "fovcircle")

	local secFire = newSection(aimTab, "Tir")
	newToggle(secFire, "Auto fire", "Tire pendant la visee", AB, "autofire")
	newSlider(secFire, "Delai de tir", "Intervalle", AB, "firedelay", 0.02, 0.5)
	newToggle(secFire, "Trigger bot", "Tire sans viser", AB, "trigger")
	newSlider(secFire, "Delai trigger", "Reaction", AB, "trigdelay", 0.01, 0.5)

	local secSilent = newSection(aimTab, "Silent aim")
	newToggle(secSilent, "Silent aim", "Corrige les rayons sans bouger la camera", SA, "on", function(v)
		if v then installHooks() end
	end)
	newDropdown(secSilent, "Declenchement", "Toujours ou touche", { "Toujours", "Touche", "Toggle" },
		SA.mode, function(v) SA.mode = v SA.toggled = false end)
	newKeybind(secSilent, "Touche silent", "Pour Touche et Toggle", SA, "key")
	newSlider(secSilent, "FOV silent", "Champ", SA, "fov", 20, 600)
	newSlider(secSilent, "Chance", "Pourcentage de reussite", SA, "chance", 10, 100)
	newSlider(secSilent, "Prediction", "Avance", SA, "pred", 0, 1)
	newSlider(secSilent, "Distance silent", "Portee", SA, "maxd", 50, 3000)
	newDropdown(secSilent, "Partie touchee", "Zone ciblee", { "Head", "Nearest", "Random", "Torso" },
		SA.part, function(v) SA.part = v end)
	newToggle(secSilent, "Verif equipe", "Ignore les allies", SA, "team")
	newToggle(secSilent, "Wall check", "Uniquement a vue", SA, "vis")

	local secHit = newSection(aimTab, "Hitbox")
	newToggle(secHit, "Hitbox expander", "Agrandit les zones de touche", HB, "on")
	newSlider(secHit, "Taille hitbox", "Volume", HB, "size", 2, 20)
	newToggle(secHit, "Inclure le root", "HumanoidRootPart", HB, "root", function()
		for p in pairs(hbStore) do restoreHB(p) end
	end)

	local visTab = newTab("Visuel", "eye")
	local secESP = newSection(visTab, "Joueurs")
	newToggle(secESP, "ESP actif", "Affiche les joueurs", ESP, "on", function(v)
		if v then
			for _, p in ipairs(Players:GetPlayers()) do if p ~= LP then ensureESP(p) end end
		else
			for p in pairs(esp) do killESP(p) end
		end
	end)
	newToggle(secESP, "Boite", "Contour", ESP, "box")
	newToggle(secESP, "Remplissage", "Fond translucide", ESP, "fill")
	newToggle(secESP, "Pseudo", "Nom au dessus", ESP, "name")
	newToggle(secESP, "Vie", "Barre de vie", ESP, "hp")
	newToggle(secESP, "Distance", "Metres", ESP, "dist")
	newToggle(secESP, "Tracer", "Ligne depuis le bas", ESP, "tracer")
	newToggle(secESP, "Chams", "Surlignage plein", ESP, "chams")
	newToggle(secESP, "Verif equipe", "Ignore les allies", ESP, "team")
	newSlider(secESP, "Distance max", "Portee de l esp", ESP, "maxd", 50, 3000)

	local pTab = newTab("Joueur", "move")
	local secMove = newSection(pTab, "Deplacement")
	newToggle(secMove, "Vitesse", "Modifie la marche", CHAR, "speed", setSpeed)
	newSlider(secMove, "Valeur vitesse", "Vitesse appliquee", CHAR, "sv", 16, 300)
	newToggle(secMove, "Saut haut", "Puissance de saut", CHAR, "jump", setJump)
	newSlider(secMove, "Valeur saut", "Puissance", CHAR, "jv", 50, 400)
	newToggle(secMove, "Fly", "Vol libre", CHAR, "fly", setFly)
	newToggle(secMove, "Noclip", "Traverse les murs", CHAR, "noclip", setNoclip)
	newToggle(secMove, "Freeze", "Immobilise", CHAR, "freeze", setFreeze)

	local secCam = newSection(pTab, "Camera")
	newToggle(secCam, "Freecam", "Camera detachee", CAM, "free", setFreecam)
	newSlider(secCam, "Vitesse freecam", "Deplacement", CAM, "freespd", 10, 300)
	newToggle(secCam, "Orbite", "Rotation autour de vous", CAM, "orbit")
	newSlider(secCam, "Rayon orbite", "Distance", CAM, "orbitr", 5, 60)
	newSlider(secCam, "Vitesse orbite", "Rotation", CAM, "orbitspd", 10, 400)

	local secBody = newSection(pTab, "Corps")
	newToggle(secBody, "Taille custom", "Echelle du corps", CHAR, "scale", applyScale)
	newSlider(secBody, "Echelle", "Facteur", CHAR, "scalev", 0.4, 3, function()
		if CHAR.scale then applyScale() end
	end)

	local skyTab = newTab("Sky", "cloud")
	local secAtmo = newSection(skyTab, "Atmosphere")
	newDropdown(secAtmo, "Preset", "Ambiance globale",
		{ "Jour", "Aube", "Coucher", "Nuit", "Brum", "Neon", "Orage" }, "Jour",
		function(v) applyAtmo(v) end)
	newSlider(secAtmo, "Densite", "Epaisseur de l air", {}, "x", 0, 1, function(v)
		local a = ensureAtmo() pcall(function() a.Density = v end)
	end)
	newSlider(secAtmo, "Brume", "Halo diffus", {}, "x", 0, 6, function(v)
		local a = ensureAtmo() pcall(function() a.Haze = v end)
	end)
	newSlider(secAtmo, "Halo", "Eclat du soleil", {}, "x", 0, 2, function(v)
		local a = ensureAtmo() pcall(function() a.Glare = v end)
	end)
	newSlider(secAtmo, "Exposition", "Luminosite", {}, "x", 0, 3, function(v)
		pcall(function() Lighting.ExposureCompensation = v - 1 end)
	end)

	local secSky = newSection(skyTab, "Ciel")
	local names = {}
	for _, s in ipairs(SKIES) do names[#names + 1] = s[1] end
	newDropdown(secSky, "Cielbox", "Banque de ciels", names, "Aucun", function(v)
		for _, s in ipairs(SKIES) do
			if s[1] == v then setSkybox(s[2]) return end
		end
	end)
	newInput(secSky, "Image perso", "ID de skybox", "ID numerique", function(txt)
		local id = tonumber(tostring(txt):match("%d+"))
		if id then setSkybox(id) end
	end)
	newSlider(secSky, "Heure", "Position du soleil", {}, "x", 0, 24, function(v)
		pcall(function() Lighting.ClockTime = v end)
	end)
	newButton(secSky, "Retablir le ciel d'origine", function()
		killSky() killAtmo() restoreLighting()
	end)

	local tTab = newTab("Troll", "sparkles")
	local secAnim = newSection(tTab, "Animation")
	newToggle(secAnim, "Spin", "Rotation continue", TROLL, "spin")
	newSlider(secAnim, "Vitesse spin", "Rotation", TROLL, "spinspd", 40, 900)
	newToggle(secAnim, "Ragdoll", "Personnage mou", TROLL, "ragdoll", tRagdoll)
	newToggle(secAnim, "Arc-en-ciel", "Cycle de couleurs", TROLL, "rainbow")
	newToggle(secAnim, "Invisible", "Transparent en local", TROLL, "ghost", tGhost)
	newToggle(secAnim, "Aura", "Particules en orbite", TROLL, "aura", tAura)
	newToggle(secAnim, "Trainee", "Sillage colore", TROLL, "trail", tTrail)
	newToggle(secAnim, "Tornade", "Spirale autour de vous", TROLL, "tornado", TX.tornado)
	newToggle(secAnim, "S'asseoir", "Position assise", TROLL, "sit", tSit)

	local secAmb = newSection(tTab, "Ambiance")
	newToggle(secAmb, "Pluie de parts", "Blocs qui tombent", TROLL, "rain", tRain)
	newToggle(secAmb, "Camera shake", "Tremblement", TROLL, "shake")
	newSlider(secAmb, "Intensite shake", "Force", TROLL, "shakei", 0.2, 6)
	newToggle(secAmb, "Nuit / brouillard", "Assombrit", TROLL, "fog", tFog)
	newToggle(secAmb, "Party lights", "Lumieres colorees", TROLL, "party", tParty)
	newToggle(secAmb, "Balise lumineuse", "Lumiere sur vous", TROLL, "beacon", TX.beacon)

	local secAct = newSection(tTab, "Actions")
	newToggle(secAct, "Suivre joueur", "Colle le plus proche", TROLL, "follow", tFollow)
	newToggle(secAct, "Anti-AFK", "Evite l exclusion", TROLL, "afk", tAfk)
	newToggle(secAct, "TP aleatoire en boucle", "Teleporte sans arret", TROLL, "tploop", TX.tpLoop)
	newSlider(secAct, "Intervalle TP", "Secondes", TROLL, "tprate", 1, 20)
	newButton(secAct, "Teleport au plus proche", function() tTeleport(false) end)
	newButton(secAct, "Teleport aleatoire", function() tTeleport(true) end)
	newButton(secAct, "Confettis", tConfetti)
	newButton(secAct, "Attacher la part visee", TX.attach)
	newButton(secAct, "Jumpscare", tJumpscare)

	local secSound = newSection(tTab, "Son")
	newInput(secSound, "Son par ID", "Joue un son", "ID numerique", function(txt)
		local id = tonumber(tostring(txt):match("%d+"))
		if id then TX.sound(id) end
	end)
	newToggle(secSound, "Musique en boucle", "Joue en fond", TROLL, "music", function(v)
		if v then TX.music(131961136) else TX.music(0) end
	end)
	newButton(secSound, "Couper le son", function() TX.music(0) end)

	local bTab = newTab("Bypass", "shield")
	local secProf2 = newSection(bTab, "Profil")
	newDropdown(secProf2, "Profil", "Cohérence des couches",
		{ "Discret", "Standard", "Agressif" }, B.profile, function(v) applyProfile(v) end)
	newParagraph(secProf2, "Discret quasi invisible. Agressif bloque tout.")

	local secLayers = newSection(bTab, "Couches")
	newToggle(secLayers, "Isolation d'environnement", "Separe notre env", B, "env")
	newToggle(secLayers, "Anti kick", "Bloque Player:Kick", B, "kick", function(v) if v then installHooks() end end)
	newToggle(secLayers, "Filtre des raisons", "Ne bloque que l AC", B, "kickFilter")
	newToggle(secLayers, "Reconnexion auto", "Rejoint apres un kick", B, "rejoin")
	newToggle(secLayers, "Verrou vitesse / saut", "Empeche les resets", B, "lock", function(v) if v then installHooks() end end)
	newToggle(secLayers, "Neutraliser les signaux", "Coupe les listeners vitesse", B, "sigspoof", function(v)
		if v then installHooks() killHumanSignals() end
	end)
	newToggle(secLayers, "Spoof de velocite", "Plafonne la vitesse lue", B, "velspoof", function(v) if v then installHooks() end end)
	newToggle(secLayers, "Couper les boucles AC", "Desactive leurs connexions", B, "conns", function(v)
		if v then blog("boucles coupees : " .. killACConns()) end
	end)
	newToggle(secLayers, "Desactiver les scripts AC", "LocalScripts cibles", B, "scripts", function(v)
		if v then blog("scripts desactives : " .. killLocalAC()) end
	end)
	newToggle(secLayers, "Plafond de FPS", "Evite les FPS anormaux", B, "fpscap", function(v)
		pcall(function() setfpscap(v and B.fps or 0) end)
	end)
	newSlider(secLayers, "Vitesse max autorisee", "Plafond applique", B, "maxspeed", 20, 200)
	newSlider(secLayers, "Velocite max lue", "Valeur spoofee", B, "maxvel", 20, 400)
	newSlider(secLayers, "FPS plafonnes", "Valeur appliquee", B, "fps", 30, 240, function(v)
		if B.fpscap then pcall(function() setfpscap(v) end) end
	end)

	local secTools = newSection(bTab, "Outils")
	U.diag = newParagraph(secTools, "Diagnostic : appuie sur Analyser.")
	newButton(secTools, "Analyser", function() U.diag:SetTitle(diagnose()) end)
	newButton(secTools, "Reinstaller les hooks", function()
		unhook() blog(installHooks() and "hooks reinstalles" or "echec")
	end)
	newButton(secTools, "Appliquer toutes les couches", runBypass)
	newButton(secTools, "Rejoindre le serveur", function()
		pcall(function() game:GetService("TeleportService"):Teleport(game.PlaceId, LP) end)
	end)

	local secLog = newSection(bTab, "Journal")
	U.log = newParagraph(secLog, "Aucun evenement.")
	newButton(secLog, "Rafraichir", function()
		U.log:SetTitle(#BLog > 0 and table.concat(BLog, "\n") or "Aucun evenement.")
	end)

	local meTab = newTab("Profil", "user-round")
	local pInfo = newSection(meTab, "Compte")
	newParagraph(pInfo, "Pseudo : " .. LP.DisplayName .. " (@" .. LP.Name .. ")")
	newParagraph(pInfo, "Identifiant : " .. LP.UserId)
	newParagraph(pInfo, "Anciennete : " .. LP.AccountAge .. " jours")

	local pSession = newSection(meTab, "Session")
	U.team = newParagraph(pSession, "Equipe : -")
	U.hp = newParagraph(pSession, "Vie : -")
	U.ping = newParagraph(pSession, "Ping : -")
	U.players = newParagraph(pSession, "Joueurs : -")
	newParagraph(pSession, "Experience : " .. game.PlaceId)

	local dTab = newTab("Divers", "settings")
	local secTop = newSection(dTab, "Affichage")
	newToggle(secTop, "Toujours au premier plan", "Passe au-dessus du menu Roblox", FG, "on", function(v)
		if v then pushAbove() end
	end)
	newButton(secTop, "Forcer maintenant", pushAbove)
	newButton(secTop, "Replier dans le rond", function() Bubble.collapse() end)
	newToggle(secTop, "Rond cliquable", "Le menu replie devient un rond", U, "showBubble", function(v)
		if not Bubble.on then return end
		if v then Bubble.show() else Bubble.hideBubble() end
	end)

	local secKey = newSection(dTab, "Raccourcis")
	newParagraph(secKey, "Insert : ouvre ou ferme le menu")
	newParagraph(secKey, "RightShift : decharge le script")
	newParagraph(secKey, "Menu replie : un rond apparait, un tap le rouvre")

	local secMaint = newSection(dTab, "Maintenance")
	newButton(secMaint, "Reset toutes les options", function()
		setFly(false) setNoclip(false) setFreeze(false)
		tGhost(false) tFog(false) tRain(false) tAura(false) tTrail(false) tParty(false) tAfk(false)
		TX.stopAll()
		if CAM.free then setFreecam(false) end
		AB.on = false SA.on = false HB.on = false ESP.on = false
		locked = nil
		for p in pairs(hbStore) do restoreHB(p) end
	end)
	newButton(secMaint, "Unload", function() Unload() end)

	pcall(function() window:SelectTab(1) end)

	task.spawn(function()
		while not dead do
			task.wait(0.7)
			if dead then break end
			pcall(function()
				local _, h = alive(LP)
				U.team:SetTitle("Equipe : " .. ((LP.Team and LP.Team.Name) or "aucune"))
				U.hp:SetTitle("Vie : " .. (h and (math.floor(h.Health) .. " / " .. math.floor(h.MaxHealth)) or "-"))
				local ping = 0
				pcall(function() ping = math.floor((LP:GetNetworkPing() or 0) * 1000) end)
				U.ping:SetTitle("Ping : " .. ping .. " ms")
				U.players:SetTitle("Joueurs : " .. #Players:GetPlayers())
			end)
		end
	end)
end

buildUI()

-- ================= UNLOAD =================
function Unload()
	if dead then return end
	dead = true
	unloading = true
	pcall(function() RunService:UnbindFromRenderStep("SMOOTH_AIM") end)
	unhook()
	TX.stopAll()
	pcall(Bubble.destroy)
	pcall(function() if B.fpscap and setfpscap then setfpscap(0) end end)
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
	for _, p in ipairs(trollObj.tornado) do pcall(function() p:Destroy() end) end
	if trollObj.cc then pcall(function() trollObj.cc:Destroy() end) end
	tGhost(false) tFog(false)
	pcall(killSky) pcall(killAtmo) pcall(restoreLighting)
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
	pcall(function() window:Destroy() end)
	pcall(function() ownGui:Destroy() end)
	getgenv().V = nil
end
getgenv().V = { Unload = Unload }

track(Players.PlayerAdded:Connect(function(p)
	if p == LP then return end
	if ESP.on then ensureESP(p) end
	p.CharacterAdded:Connect(function()
		if ESP.on and not dead then ensureESP(p) end
	end)
end))

track(LP.CharacterAdded:Connect(function()
	if objs.fly then objs.fly:Destroy() objs.fly = nil end
	if objs.follow then objs.follow:Destroy() objs.follow = nil end
	clearGyro()
	origSpeed, origJump, origUseJP = nil, nil, nil
	trollObj.ghost = {}
	locked = nil
	if B.sigspoof then task.delay(1, function() if not dead then killHumanSignals() end end) end
	if CHAR.fly then task.delay(0.8, function() if CHAR.fly and not dead then setFly(true) end end) end
	if CHAR.noclip then task.delay(0.3, function() if CHAR.noclip and not dead then setNoclip(true) end end) end
	if CHAR.scale then task.delay(0.8, applyScale) end
	if TROLL.tornado then task.delay(0.6, function() if TROLL.tornado and not dead then TX.tornado(true) end end) end
	if TROLL.beacon then task.delay(0.6, function() if TROLL.beacon and not dead then TX.beacon(true) end end) end
end))

track(Players.PlayerRemoving:Connect(function(p) killESP(p) restoreHB(p) end))

track(UIS.InputBegan:Connect(function(inp, gp)
	if gp then return end
	if inp.KeyCode == Enum.KeyCode.RightShift then Unload() return end
	if AB.mode == "Toggle" and AB.on and inp.KeyCode == AB.key then AB.toggled = not AB.toggled end
	if SA.mode == "Toggle" and SA.on and inp.KeyCode == SA.key then SA.toggled = not SA.toggled end
end))

print("[SMOOTH.DEV] loaded")
