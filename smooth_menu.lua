--[[ SMOOTH.DEV v17 — UI: WindUI (MIT)
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

local conns, esp, objs, hbStore = {}, {}, {}, {}
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
	local sp = Camera.WorldToViewportPoint(Camera, pos)
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
		if not S.Troll.spin then clearGyro() end
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
	local layer = Instance.new("Frame")
	layer.Size = UDim2.fromScale(1, 1)
	layer.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
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

	if S.Troll.spin then
		local g = ensureGyro()
		if g and g.Parent then
			local pos = g.Parent.Position
			spinAngle = (spinAngle + math.rad(S.Troll.spinspd) * dt) % (math.pi * 2)
			g.CFrame = CFrame.new(pos) * CFrame.Angles(0, spinAngle, 0)
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

-- ================= couche ESP =================
local ownGui = Instance.new("ScreenGui")
ownGui.Name = "SmoothDevOverlay"
ownGui.ResetOnSpawn = false
ownGui.IgnoreGuiInset = true
ownGui.DisplayOrder = 2147483647
ownGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
if syn and syn.protect_gui then pcall(syn.protect_gui, ownGui) end
if type(gethui) == "function" then
	pcall(function() ownGui.Parent = gethui() end)
else
	pcall(function() ownGui.Parent = game:GetService("CoreGui") end)
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
ring.Size = UDim2.fromOffset(220, 220)
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

track(RunService.RenderStepped:Connect(function()
	if dead then return end
	local aiming = S.Aimbot.on and UIS:IsKeyDown(S.Aimbot.key)
	local silent = S.Silent.on and UIS:IsKeyDown(S.Silent.key)
	ring.Visible = S.ESP.fovcircle or aiming or silent
	local r = silent and S.Silent.fov or S.Aimbot.fov
	ring.Size = UDim2.fromOffset(r * 2, r * 2)
end))

-- ================= lib =================
local before = {}
for _, g in ipairs(game:GetService("CoreGui"):GetChildren()) do before[g] = true end

local WindUI
local okLib = pcall(function()
	WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)
if not okLib or not WindUI then
	warn("[SMOOTH.DEV] WindUI indisponible")
	return
end

local winProps = {}
winProps.Title = "SMOOTH.DEV"
winProps.Author = "smooth.dev"
winProps.Folder = "SmoothDev"
winProps.Theme = "Dark"
winProps.Size = UDim2.fromOffset(580, 460)
winProps.ToggleKey = Enum.KeyCode.Insert
winProps.HasOutline = true
winProps.Resizable = true

local window = WindUI:CreateWindow(winProps)

for _, g in ipairs(game:GetService("CoreGui"):GetChildren()) do
	if not before[g] and g:IsA("ScreenGui") then
		if syn and syn.protect_gui then pcall(syn.protect_gui, g) end
		g.DisplayOrder = 2147483646
		g.ResetOnSpawn = false
		break
	end
end

-- ================= helpers de widget =================
local function safe(fn)
	local ok, err = pcall(fn)
	if not ok then warn("[SMOOTH.DEV] widget: " .. tostring(err)) end
end

local function newTab(title, icon)
	local p = {}
	p.Title = title
	p.Icon = icon
	return window:Tab(p)
end

local function newSection(parent, title)
	local p = {}
	p.Title = title
	return parent:Section(p)
end

local function newParagraph(parent, text)
	local p = {}
	p.Title = text
	return parent:Paragraph(p)
end

local function newButton(parent, title, cb)
	safe(function()
		local p = {}
		p.Title = title
		p.Callback = cb
		parent:Button(p)
	end)
end

local function newDropdown(parent, title, desc, values, default, cb)
	safe(function()
		local p = {}
		p.Title = title
		p.Desc = desc
		p.Values = values
		p.Value = default
		p.Callback = cb
		parent:Dropdown(p)
	end)
end

local function newToggle(parent, title, desc, tbl, key, cb)
	safe(function()
		local p = {}
		p.Title = title
		p.Desc = desc
		p.Value = tbl[key]
		p.Callback = function(v)
			tbl[key] = v
			if cb then cb(v) end
		end
		parent:Toggle(p)
	end)
end

local function newSlider(parent, title, desc, tbl, key, mn, mx, cb)
	safe(function()
		local range = {}
		range.Min = mn
		range.Max = mx
		range.Default = tbl[key]

		local p = {}
		p.Title = title
		p.Desc = desc
		p.Value = range
		p.Callback = function(v)
			tbl[key] = v
			if cb then cb(v) end
		end
		parent:Slider(p)
	end)
end

local function newKeybind(parent, title, desc, tbl, key)
	safe(function()
		local p = {}
		p.Title = title
		p.Desc = desc
		p.Value = tbl[key].Name
		p.Callback = function(v)
			local kc = Enum.KeyCode[v]
			if kc then tbl[key] = kc end
		end
		parent:Keybind(p)
	end)
end

local function resetAll()
	setFly(false) setNoclip(false) setFreeze(false)
	tGhost(false) tFog(false) tRain(false) tAura(false) tTrail(false) tParty(false) tAfk(false)
	if S.Cam.free then setFreecam(false) end
	for _, grp in pairs(S) do
		for k in pairs(grp) do
			if k == "on" then grp[k] = false end
		end
	end
end

-- ================= PROFIL =================
local profilTab = newTab("Profil", "user-round")
local pInfo = newSection(profilTab, "Compte")
newParagraph(pInfo, "Pseudo : " .. LP.DisplayName .. " (@" .. LP.Name .. ")")
newParagraph(pInfo, "Identifiant : " .. LP.UserId)
newParagraph(pInfo, "Anciennete : " .. LP.AccountAge .. " jours")

local pSession = newSection(profilTab, "Session")
local parTeam = newParagraph(pSession, "Equipe : -")
local parHealth = newParagraph(pSession, "Vie : -")
local parPing = newParagraph(pSession, "Ping : -")
local parPlayers = newParagraph(pSession, "Joueurs : -")
newParagraph(pSession, "Experience : " .. game.PlaceId)

task.spawn(function()
	while not dead do
		task.wait(0.7)
		if dead then break end
		pcall(function()
			local _, h = alive(LP)
			parTeam:SetTitle("Equipe : " .. ((LP.Team and LP.Team.Name) or "aucune"))
			parHealth:SetTitle("Vie : " .. (h and (math.floor(h.Health) .. " / " .. math.floor(h.MaxHealth)) or "-"))
			local ping = 0
			pcall(function() ping = math.floor((LP:GetNetworkPing() or 0) * 1000) end)
			parPing:SetTitle("Ping : " .. ping .. " ms")
			parPlayers:SetTitle("Joueurs : " .. #Players:GetPlayers())
		end)
	end
end)

-- ================= COMBAT =================
local combatTab = newTab("Combat", "crosshair")
local secAim = newSection(combatTab, "Aimbot")
newToggle(secAim, "Aimbot", "Visee automatique", S.Aimbot, "on")
newKeybind(secAim, "Touche aimbot", "Maintenir pour viser", S.Aimbot, "key")
newToggle(secAim, "Verif equipe", "Ignore les coequipiers", S.Aimbot, "team")
newToggle(secAim, "Ignore knocked", "Saute les joueurs au sol", S.Aimbot, "ignoreknock")
newDropdown(secAim, "Partie visee", "Os cible par la visee",
	{ "Head", "Nearest", "Random", "Torso" }, "Head",
	function(v) S.Aimbot.part = v end)
newSlider(secAim, "FOV", "Champ de detection", S.Aimbot, "fov", 20, 500)
newSlider(secAim, "Lissage", "Douceur du suivi", S.Aimbot, "smooth", 0.05, 1)
newSlider(secAim, "Prediction", "Anticipation du mouvement", S.Aimbot, "pred", 0, 1)
newSlider(secAim, "Distance max", "Portee de la visee", S.Aimbot, "maxd", 50, 3000)

local secRage = newSection(combatTab, "Rage")
newToggle(secRage, "Snap instantane", "Sans interpolation", S.Aimbot, "instant")
newToggle(secRage, "Auto fire", "Tire des que la cible est prise", S.Aimbot, "autofire")
newSlider(secRage, "Delai tir", "Intervalle entre les tirs", S.Aimbot, "firedelay", 0.02, 0.5)
newToggle(secRage, "Trigger bot", "Vise sans maintenir", S.Aimbot, "trigger")
newToggle(secRage, "Wall check", "Cible uniquement a vue", S.Aimbot, "vis")
newToggle(secRage, "Hitbox expander", "Agrandit la tete", S.HB, "on")
newSlider(secRage, "Taille hitbox", "Volume", S.HB, "size", 2, 20)
newToggle(secRage, "Cercle FOV", "Affiche le cercle", S.ESP, "fovcircle")

local secSilent = newSection(combatTab, "Silent")
newToggle(secSilent, "Silent aim", "Correction invisible", S.Silent, "on")
newKeybind(secSilent, "Touche silent", "Maintenir pour corriger", S.Silent, "key")
newToggle(secSilent, "Equipe silent", "Ignore les coequipiers", S.Silent, "team")
newSlider(secSilent, "FOV silent", "Champ de detection", S.Silent, "fov", 20, 500)
newSlider(secSilent, "Distance silent", "Portee", S.Silent, "maxd", 50, 3000)

-- ================= VISUEL =================
local visuelTab = newTab("Visuel", "eye")
local secESP = newSection(visuelTab, "ESP")
newToggle(secESP, "ESP actif", "Affiche les joueurs", S.ESP, "on")
newToggle(secESP, "Boite", "Contour", S.ESP, "box")
newToggle(secESP, "Remplissage", "Fond translucide", S.ESP, "fill")
newToggle(secESP, "Pseudo", "Nom au dessus", S.ESP, "name")
newToggle(secESP, "Vie", "Barre de vie", S.ESP, "hp")
newToggle(secESP, "Distance", "Metres", S.ESP, "dist")
newToggle(secESP, "Tracer", "Ligne depuis le bas", S.ESP, "tracer")
newToggle(secESP, "Chams", "Surlignage plein", S.ESP, "chams")
newToggle(secESP, "Verif equipe", "Ignore les coequipiers", S.ESP, "team")
newSlider(secESP, "Distance max", "Portee de l esp", S.ESP, "maxd", 50, 3000)

-- ================= JOUEUR =================
local joueurTab = newTab("Joueur", "move")
local secMove = newSection(joueurTab, "Deplacement")
newToggle(secMove, "Vitesse", "Modifie la marche", S.Char, "speed", setSpeed)
newSlider(secMove, "Valeur vitesse", "Vitesse appliquee", S.Char, "sv", 16, 300)
newToggle(secMove, "Saut haut", "Puissance de saut", S.Char, "jump", setJump)
newSlider(secMove, "Valeur saut", "Puissance appliquee", S.Char, "jv", 50, 400)
newToggle(secMove, "Fly", "Vol libre", S.Char, "fly", setFly)
newToggle(secMove, "Noclip", "Traverse les murs", S.Char, "noclip", setNoclip)
newToggle(secMove, "Freeze", "Immobilise", S.Char, "freeze", setFreeze)

local secCam = newSection(joueurTab, "Camera")
newToggle(secCam, "Freecam", "Camera detachee", S.Cam, "free", setFreecam)
newSlider(secCam, "Vitesse freecam", "Deplacement", S.Cam, "freespd", 10, 300)
newToggle(secCam, "Orbite", "Rotation autour de vous", S.Cam, "orbit")
newSlider(secCam, "Rayon orbite", "Distance", S.Cam, "orbitr", 5, 60)
newSlider(secCam, "Vitesse orbite", "Rotation", S.Cam, "orbitspd", 10, 400)

local secBody = newSection(joueurTab, "Personnage")
newToggle(secBody, "Taille custom", "Echelle du corps", S.Char, "scale", applyScale)
newSlider(secBody, "Echelle", "Facteur", S.Char, "scalev", 0.4, 3, function()
	if S.Char.scale then applyScale() end
end)

-- ================= TROLL =================
local trollTab = newTab("Troll", "sparkles")
local secAnim = newSection(trollTab, "Animation")
newToggle(secAnim, "Spin", "Rotation continue", S.Troll, "spin")
newSlider(secAnim, "Vitesse spin", "Rotation", S.Troll, "spinspd", 40, 900)
newToggle(secAnim, "Ragdoll", "Personnage mou", S.Troll, "ragdoll", tRagdoll)
newToggle(secAnim, "Arc-en-ciel", "Cycle de couleurs", S.Troll, "rainbow")
newToggle(secAnim, "Invisible", "Transparent en local", S.Troll, "ghost", tGhost)
newToggle(secAnim, "Aura", "Particules en orbite", S.Troll, "aura", tAura)
newToggle(secAnim, "Trainee", "Sillage colore", S.Troll, "trail", tTrail)
newToggle(secAnim, "S'asseoir", "Position assise", S.Troll, "sit", tSit)

local secAmb = newSection(trollTab, "Ambiance")
newToggle(secAmb, "Pluie de parts", "Blocs qui tombent", S.Troll, "rain", tRain)
newToggle(secAmb, "Camera shake", "Tremblement", S.Troll, "shake")
newSlider(secAmb, "Intensite shake", "Force", S.Troll, "shakei", 0.2, 6)
newToggle(secAmb, "Nuit / brouillard", "Assombrit", S.Troll, "fog", tFog)
newToggle(secAmb, "Party lights", "Lumieres colorees", S.Troll, "party", tParty)

local secAct = newSection(trollTab, "Actions")
newToggle(secAct, "Suivre joueur", "Colle le plus proche", S.Troll, "follow", tFollow)
newToggle(secAct, "Anti-AFK", "Evite l exclusion", S.Troll, "afk", tAfk)
newButton(secAct, "Teleport au plus proche", function() tTeleport(false) end)
newButton(secAct, "Teleport aleatoire", function() tTeleport(true) end)
newButton(secAct, "Confettis", tConfetti)
newButton(secAct, "Jumpscare", tJumpscare)

-- ================= DIVERS =================
local diversTab = newTab("Divers", "settings")
local secKey = newSection(diversTab, "Raccourcis")
newParagraph(secKey, "Insert : ouvre ou ferme le menu")
newParagraph(secKey, "RightShift : decharge le script")
local secMaint = newSection(diversTab, "Maintenance")
newButton(secMaint, "Reset toutes les options", resetAll)
newButton(secMaint, "Unload", function() Unload() end)

pcall(function() window:SelectTab(1) end)

-- ================= unload =================
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
	pcall(function() window:Destroy() end)
	pcall(function() ownGui:Destroy() end)
	getgenv().V = nil
end
getgenv().V = { Unload = Unload }

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

track(UIS.InputBegan:Connect(function(inp, gp)
	if gp then return end
	if inp.KeyCode == Enum.KeyCode.RightShift then Unload() end
end))

print("[SMOOTH.DEV] loaded")
