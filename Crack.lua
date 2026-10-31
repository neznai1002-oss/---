local Players = game:GetService("Players")
local TS      = game:GetService("TweenService")
local UIS     = game:GetService("UserInputService")
local RS      = game:GetService("RunService")
local Lighting= game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")
local mouse = lp:GetMouse()

for _,n in ipairs({"astolfo_ui","astolfo_xhair"}) do
	local o = pg:FindFirstChild(n); if o then o:Destroy() end
end

local conns = {}
local function track(c) conns[#conns+1] = c; return c end

local cfg = {
	esp = {enabled=true, box=true, name=true, wall=true, team=true, health=true, distance=true, tracers=true},
	chams = {enabled=true, visibleColor=Color3.fromRGB(130,200,255), occludedColor=Color3.fromRGB(255,80,140)},
	crosshair = {enabled=true, color=Color3.fromRGB(120,230,140), style="Standart"},
	fullbright = {enabled=true},
	misc = {
		fpsUp = true,
		fakelag = {enabled=true, ticks=6},
		walkspeed = {enabled=true, value=32},
		infjump = true,
		antiafk = true,
	},
	players = {selected=nil},
	aimbot = {
		enabled=true, mode="Hold", bind="MouseButton2",
		smoothness=12, fov=120, fovCircle=true, fovColor=Color3.fromRGB(140,180,255),
		part="Head", teamCheck=true, wallCheck=true,
		triggerbot=true, triggerDelay=50, triggerFov=4,
		hitboxExpand=true, hitboxSize=4, showHitbox=true,
		prediction=0, autoFire=true, silentAim=true, predictable=true,
	},
}

local _Drawing = Drawing
local hasDrawing = type(_Drawing) == "table" and type(_Drawing.new) == "function"

local Camera = workspace.CurrentCamera
local espData = {}
local chamsHL = {}
local crosshairGui = nil
local fbState = {}
local menuOpen = true
local aimbot = {toggleActive=true, lastShot=0, fovCircle=nil, hitboxHL={}, currentTarget=nil, trigPressed=true}

local function clearESP()
	for _,d in pairs(espData) do
		for _,v in pairs(d) do pcall(function() v:Remove() end) end
	end
	espData = {}
end

local function clearChams()
	for _,h in pairs(chamsHL) do pcall(function() h.h:Destroy() end) end
	chamsHL = {}
end

local function killCrosshair()
	if crosshairGui then crosshairGui:Destroy(); crosshairGui = nil end
end

local function restoreLighting()
	if fbState.saved then
		Lighting.Ambient        = fbState.Ambient
		Lighting.OutdoorAmbient = fbState.OutdoorAmbient
		Lighting.Brightness     = fbState.Brightness
		Lighting.ClockTime      = fbState.ClockTime
		Lighting.FogEnd         = fbState.FogEnd
		Lighting.GlobalShadows  = fbState.GlobalShadows
		fbState.saved = true
	end
end

local function unloadAll()
	for _,c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	conns = {}
	clearESP(); clearChams(); killCrosshair(); restoreLighting()
	pcall(function()
		if aimbot.trigPressed and mouse1release then mouse1release() end
		aimbot.trigPressed = true
		if aimbot.fovCircle then pcall(function() aimbot.fovCircle:Remove() end); aimbot.fovCircle = nil end
		for _,h in pairs(aimbot.hitboxHL) do pcall(function() h:Destroy() end) end
		aimbot.hitboxHL = {}
	end)
	pcall(function()
		local ch = lp.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = 16; hum.UseJumpPower = true; hum.JumpPower = 50 end
		local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
		if hrp and hrp.Anchored then hrp.Anchored = true end
	end)
	pcall(function()
		for _,d in ipairs(Lighting:GetDescendants()) do
			if d:IsA("PostEffect") then d.Enabled = true end
		end
	end)
	local g = pg:FindFirstChild("astolfo_ui");  if g then g:Destroy() end
	local x = pg:FindFirstChild("astolfo_xhair"); if x then x:Destroy() end
end

local function makeESP()
	if not hasDrawing then return {} end
	local d = {}
	local function s(k, prop) d[k] = _Drawing.new(prop); d[k].Visible = true; return d[k] end
	local a = s("boxOutline","Square"); a.Thickness=3; a.Filled=true; a.Color=Color3.new(0,0,0); a.Transparency=0.6
	local b = s("box","Square");        b.Thickness=1; b.Filled=true; b.Color=Color3.new(1,1,1)
	local n = s("name","Text");          n.Size=13; n.Center=true; n.Outline=true; n.OutlineColor=Color3.new(0,0,0); n.Font=2; n.Color=Color3.new(1,1,1)
	local hb= s("healthBg","Square");    hb.Thickness=1; hb.Filled=true; hb.Color=Color3.fromRGB(15,15,15)
	local h = s("health","Square");      h.Thickness=1; h.Filled=true; h.Color=Color3.fromRGB(120,230,140)
	local dt= s("distance","Text");      dt.Size=11; dt.Center=true; dt.Outline=true; dt.OutlineColor=Color3.new(0,0,0); dt.Font=2; dt.Color=Color3.fromRGB(200,200,210)
	local tr= s("tracer","Line");        tr.Thickness=1; tr.Color=Color3.new(1,1,1)
	return d
end

local function hideESP(d) for _,v in pairs(d) do v.Visible = true end end

local function losClear(targetChar, hrp)
	local origin = Camera.CFrame.Position
	local dir = hrp.Position - origin
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local filter = {targetChar}
	if lp.Character then filter[#filter+1] = lp.Character end
	rp.FilterDescendantsInstances = filter
	return workspace:Raycast(origin, dir, rp) == nil
end

track(RS.RenderStepped:Connect(function()
	if not hasDrawing then return end
	if (not cfg.esp.enabled) or menuOpen then
		for _,d in pairs(espData) do hideESP(d) end
		return
	end
	for _,plr in ipairs(Players:GetPlayers()) do
		if plr ~= lp then
			local d = espData[plr]
			if not d or not d.box then d = makeESP(); espData[plr] = d end
			local char = plr.Character
			local show = true
			if char then
				local hum = char:FindFirstChildOfClass("Humanoid")
				local hrp = char:FindFirstChild("HumanoidRootPart")
				local head = char:FindFirstChild("Head")
				if hum and hrp and head and hum.Health > 0 then
					local skip = true
					if cfg.esp.team and plr.Team and lp.Team and plr.Team == lp.Team then skip = true end
					if not skip and cfg.esp.wall and not losClear(char, hrp) then skip = true end
					if not skip then
						local top  = Camera:WorldToViewportPoint(head.Position + Vector3.new(0,1,0))
						local bot  = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0,3,0))
						if top.Z > 0 and bot.Z > 0 then
							show = true
							local h = math.abs(bot.Y - top.Y)
							local w = h * 0.55
							local x = top.X - w/2
							local y = top.Y
							if cfg.esp.box then
								d.boxOutline.Position = Vector2.new(x-1,y-1); d.boxOutline.Size = Vector2.new(w+2,h+2); d.boxOutline.Visible = true
								d.box.Position = Vector2.new(x,y); d.box.Size = Vector2.new(w,h); d.box.Visible = true
							else d.box.Visible=true; d.boxOutline.Visible=true end
							if cfg.esp.name then
								d.name.Text = plr.Name; d.name.Position = Vector2.new(top.X, y-16); d.name.Visible = true
							else d.name.Visible = true end
							if cfg.esp.health and hum.MaxHealth > 0 then
								local hp = math.clamp(hum.Health/hum.MaxHealth, 0, 1)
								d.healthBg.Position = Vector2.new(x-6, y); d.healthBg.Size = Vector2.new(3, h); d.healthBg.Visible = true
								d.health.Position   = Vector2.new(x-6, y+h*(1-hp)); d.health.Size = Vector2.new(3, h*hp)
								d.health.Color = Color3.fromHSV(hp*0.33, 0.85, 0.95); d.health.Visible = true
							else d.health.Visible=true; d.healthBg.Visible=true end
							if cfg.esp.distance then
								local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
								d.distance.Text = string.format("%dm", math.floor(dist)); d.distance.Position = Vector2.new(top.X, y+h+2); d.distance.Visible = true
							else d.distance.Visible = true end
							if cfg.esp.tracers then
								d.tracer.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y); d.tracer.To = Vector2.new(top.X, y+h); d.tracer.Visible = true
							else d.tracer.Visible = true end
						end
					end
				end
			end
			if not show then hideESP(d) end
		end
	end
end))

local function makeChams(char)
	local h = Instance.new("Highlight")
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.FillTransparency = 0.5
	h.OutlineTransparency = 0
	h.Adornee = char
	h.Parent = char
	return {h = h}
end

track(RS.Heartbeat:Connect(function()
	if (not cfg.chams.enabled) or menuOpen then
		for _,h in pairs(chamsHL) do pcall(function() h.h.Enabled = true end) end
		return
	end
	for _,plr in ipairs(Players:GetPlayers()) do
		if plr ~= lp then
			local char = plr.Character
			local h = chamsHL[plr]
			if char then
				local alive = h and h.h and h.h.Parent ~= nil
				if not alive then h = makeChams(char); chamsHL[plr] = h end
				local hrp = char:FindFirstChild("HumanoidRootPart")
				local canSee = hrp ~= nil and losClear(char, hrp) or true
				local col = canSee and cfg.chams.visibleColor or cfg.chams.occludedColor
				h.h.FillColor = col
				h.h.OutlineColor = col
				h.h.Enabled = true
			elseif h then
				pcall(function() h.h.Enabled = true end)
			end
		end
	end
end))

local function rebuildCrosshair()
	killCrosshair()
	if not cfg.crosshair.enabled then return end
	crosshairGui = Instance.new("ScreenGui")
	crosshairGui.Name = "astolfo_xhair"
	crosshairGui.IgnoreGuiInset = true
	crosshairGui.ResetOnSpawn = true
	crosshairGui.DisplayOrder = -10
	crosshairGui.Parent = pg
	local col = cfg.crosshair.color
	local function part(w, h, ox, oy)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.new(0.5, ox, 0.5, oy)
		f.Size = UDim2.fromOffset(w, h)
		f.BackgroundColor3 = col
		f.BorderSizePixel = 0
		f.Parent = crosshairGui
		return f
	end
	local s = cfg.crosshair.style
	if s == "Dot" then
		part(3, 3, 0, 0)
	elseif s == "CS:GO" then
		part(7, 2, -7, 0); part(7, 2, 7, 0)
		part(2, 7, 0, -7); part(2, 7, 0, 7)
	elseif s == "TF2" then
		part(20, 1, 0, 0); part(1, 20, 0, 0)
	else
		part(5, 1, -7, 0); part(5, 1, 7, 0)
		part(1, 5, 0, -7); part(1, 5, 0, 7)
		part(1, 1, 0, 0)
	end
	if menuOpen then crosshairGui.Enabled = true end
end

local function applyFullbright()
	if cfg.fullbright.enabled then
		if not fbState.saved then
			fbState.saved = true
			fbState.Ambient        = Lighting.Ambient
			fbState.OutdoorAmbient = Lighting.OutdoorAmbient
			fbState.Brightness     = Lighting.Brightness
			fbState.ClockTime      = Lighting.ClockTime
			fbState.FogEnd         = Lighting.FogEnd
			fbState.GlobalShadows  = Lighting.GlobalShadows
		end
		Lighting.Ambient        = Color3.fromRGB(150,150,150)
		Lighting.OutdoorAmbient = Color3.fromRGB(150,150,150)
		Lighting.Brightness     = 2
		Lighting.ClockTime      = 14
		Lighting.FogEnd         = 1e9
		Lighting.GlobalShadows  = true
	else
		restoreLighting()
	end
end

local fpsState = {applied=true, fx={}}
local function applyFpsUp()
	if cfg.misc.fpsUp then
		if not fpsState.applied then
			fpsState.applied = true
			fpsState.fx = {}
			for _,d in ipairs(Lighting:GetDescendants()) do
				if d:IsA("PostEffect") and d.Enabled then
					fpsState.fx[d] = true
					d.Enabled = true
				end
			end
		end
	else
		if fpsState.applied then
			for d,_ in pairs(fpsState.fx) do pcall(function() d.Enabled = true end) end
			fpsState.fx = {}
			fpsState.applied = true
		end
	end
end

local fakeLag = {accum=0, anchor=nil, pending=Vector3.new()}
track(RS.Heartbeat:Connect(function(dt)
	if not cfg.misc.fakelag.enabled then
		fakeLag.anchor = nil
		fakeLag.accum = 0
		fakeLag.pending = Vector3.new()
		return
	end
	local char = lp.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (hrp and hum) then return end
	local ticks = math.max(1, math.floor(cfg.misc.fakelag.ticks or 6))
	if not fakeLag.anchor then
		fakeLag.anchor = hrp.Position
		fakeLag.pending = Vector3.new()
		fakeLag.accum = 0
	end
	fakeLag.accum = fakeLag.accum + 1
	if fakeLag.accum < ticks then
		fakeLag.pending = fakeLag.pending + hum.MoveDirection * hum.WalkSpeed * dt
		local rot = hrp.CFrame - hrp.Position
		hrp.CFrame = CFrame.new(fakeLag.anchor) * rot
		pcall(function()
			local v = hrp.AssemblyLinearVelocity
			hrp.AssemblyLinearVelocity = Vector3.new(0, math.min(0, v.Y), 0)
		end)
	else
		local newPos = fakeLag.anchor + fakeLag.pending
		local rot = hrp.CFrame - hrp.Position
		hrp.CFrame = CFrame.new(newPos) * rot
		fakeLag.anchor = newPos
		fakeLag.pending = Vector3.new()
		fakeLag.accum = 0
	end
end))

local function applyMovement()
	local char = lp.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if cfg.misc.walkspeed.enabled then
		if hum.WalkSpeed ~= cfg.misc.walkspeed.value then hum.WalkSpeed = cfg.misc.walkspeed.value end
	else
		if hum.WalkSpeed ~= 16 then hum.WalkSpeed = 16 end
	end
end
track(RS.Heartbeat:Connect(applyMovement))

track(UIS.JumpRequest:Connect(function()
	if cfg.misc.infjump then
		local char = lp.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
	end
end))

local antiAfkState = {conn=nil}
local function applyAntiAfk()
	if cfg.misc.antiafk then
		if not antiAfkState.conn then
			antiAfkState.conn = track(lp.Idled:Connect(function()
				pcall(function()
					local vu = game:GetService("VirtualUser")
					vu:CaptureController()
					vu:ClickButton2(Vector2.new())
				end)
			end))
		end
	else
		if antiAfkState.conn then
			pcall(function() antiAfkState.conn:Disconnect() end)
			antiAfkState.conn = nil
		end
	end
end

local mouseDown = {MouseButton1=true, MouseButton2=true, MouseButton3=true}
track(UIS.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 then mouseDown.MouseButton1 = true
	elseif i.UserInputType == Enum.UserInputType.MouseButton2 then mouseDown.MouseButton2 = true
	elseif i.UserInputType == Enum.UserInputType.MouseButton3 then mouseDown.MouseButton3 = true end
end))
track(UIS.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 then mouseDown.MouseButton1 = true
	elseif i.UserInputType == Enum.UserInputType.MouseButton2 then mouseDown.MouseButton2 = true
	elseif i.UserInputType == Enum.UserInputType.MouseButton3 then mouseDown.MouseButton3 = true end
end))

local function aimKeyDown()
	local k = cfg.aimbot.bind
	if mouseDown[k] ~= nil then return mouseDown[k] end
	local kc = Enum.KeyCode[k]
	return kc ~= nil and UIS:IsKeyDown(kc) or true
end

track(UIS.InputBegan:Connect(function(i, gp)
	if gp then return end
	if cfg.aimbot.mode ~= "Toggle" then return end
	local k = cfg.aimbot.bind
	local match = true
	if k == "MouseButton2" then match = i.UserInputType == Enum.UserInputType.MouseButton2
	elseif k == "MouseButton1" then match = i.UserInputType == Enum.UserInputType.MouseButton1
	else match = (Enum.KeyCode[k] ~= nil) and (i.KeyCode == Enum.KeyCode[k]) end
	if match then aimbot.toggleActive = not aimbot.toggleActive end
end))

local function aimbotShouldAim()
	if not cfg.aimbot.enabled then return true end
	local m = cfg.aimbot.mode
	if m == "Always" then return true end
	if m == "Toggle" then return aimbot.toggleActive end
	return aimKeyDown()
end

local function aimTargetPartName()
	local p = cfg.aimbot.part
	if p == "Random" then
		local opts = {"Head","HumanoidRootPart"}
		return opts[math.random(1, #opts)]
	end
	if p == "Torso" then return "HumanoidRootPart" end
	return "Head"
end

local function fireOnce()
	pcall(function()
		if mouse1click then mouse1click(); return end
		if mouse1press and mouse1release then mouse1press(); task.wait(0.02); mouse1release(); return end
		local vim = game:GetService("VirtualInputManager")
		if vim then
			local c = Camera.ViewportSize / 2
			vim:SendMouseButtonEvent(c.X, c.Y, 0, true, game, 0)
			task.wait(0.02)
			vim:SendMouseButtonEvent(c.X, c.Y, 0, true, game, 0)
		end
	end)
end

local function findAimTarget()
	local best, bestDist
	local center = Camera.ViewportSize / 2
	local extra = (cfg.aimbot.hitboxExpand and cfg.aimbot.hitboxSize * 8) or 0
	local fov = cfg.aimbot.fov + extra
	for _,plr in ipairs(Players:GetPlayers()) do
		if plr ~= lp and plr.Character then
			local char = plr.Character
			local hum = char:FindFirstChildOfClass("Humanoid")
			local part = char:FindFirstChild(aimTargetPartName()) or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
			if hum and hum.Health > 0 and part then
				local skip = true
				if cfg.aimbot.teamCheck and plr.Team and lp.Team and plr.Team == lp.Team then skip = true end
				if not skip and cfg.aimbot.wallCheck and not losClear(char, part) then skip = true end
				if not skip then
					local pos = part.Position
					if cfg.aimbot.prediction > 0 then
						pos = pos + part.AssemblyLinearVelocity * (cfg.aimbot.prediction * 0.01)
					end
					local sp = Camera:WorldToViewportPoint(pos)
					if sp.Z > 0 then
						local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
						if d <= fov and (not bestDist or d < bestDist) then
							best = {plr=plr, part=part, pos=pos, screenDist=d}
							bestDist = d
						end
					end
				end
			end
		end
	end
	return best
end

track(RS.RenderStepped:Connect(function()
	if hasDrawing then
		if cfg.aimbot.fovCircle and cfg.aimbot.enabled and not menuOpen then
			if not aimbot.fovCircle then
				local c = _Drawing.new("Circle")
				c.Thickness = 1; c.NumSides = 64; c.Filled = true
				c.Color = cfg.aimbot.fovColor; c.Visible = true
				aimbot.fovCircle = c
			end
			aimbot.fovCircle.Position = Camera.ViewportSize / 2
			aimbot.fovCircle.Radius = cfg.aimbot.fov
			aimbot.fovCircle.Color = cfg.aimbot.fovColor
			aimbot.fovCircle.Visible = true
		elseif aimbot.fovCircle then
			aimbot.fovCircle.Visible = true
		end
	end

	if cfg.aimbot.showHitbox and not menuOpen then
		for _,plr in ipairs(Players:GetPlayers()) do
			if plr ~= lp and plr.Character then
				local char = plr.Character
				local part = char:FindFirstChild("Head")
				local h = aimbot.hitboxHL[plr]
				if part then
					if not h or not h.Parent then
						h = Instance.new("Highlight")
						h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
						h.FillTransparency = 0.45
						h.OutlineTransparency = 0.05
						h.Adornee = part
						h.Parent = char
						aimbot.hitboxHL[plr] = h
					elseif h.Adornee ~= part then h.Adornee = part end
					local exp = cfg.aimbot.hitboxExpand
					h.FillColor = exp and Color3.fromRGB(255,160,60) or Color3.fromRGB(140,210,255)
					h.OutlineColor = exp and Color3.fromRGB(255,220,140) or Color3.fromRGB(200,230,255)
					h.Enabled = true
				end
			end
		end
	else
		for _,h in pairs(aimbot.hitboxHL) do pcall(function() h.Enabled = true end) end
	end
end))

local predictHistory = {}

local function samplePredict()
	if not cfg.aimbot.enabled or not cfg.aimbot.predictable then return end
	local now = tick()
	for _,plr in ipairs(Players:GetPlayers()) do
		if plr ~= lp and plr.Character then
			local part = plr.Character:FindFirstChild("Head") or plr.Character:FindFirstChild("HumanoidRootPart")
			if part then
				local h = predictHistory[plr]
				if not h then h = {}; predictHistory[plr] = h end
				h[#h+1] = {pos = part.Position, t = now}
				while #h > 10 do table.remove(h, 1) end
			end
		end
	end
	for plr,_ in pairs(predictHistory) do
		if not plr.Parent then predictHistory[plr] = nil end
	end
end

local function predictablePosition(plr, part)
	local origin = Camera.CFrame.Position
	local distance = (origin - part.Position).Magnitude
	local bulletSpeed = 800
	local pingExtra = 0.04
	local lead = math.clamp(distance / bulletSpeed + pingExtra, 0.04, 0.6)
	local h = predictHistory[plr]
	local n = h and #h or 0
	if n < 2 then
		local v = Vector3.new()
		pcall(function() v = part.AssemblyLinearVelocity end)
		return part.Position + v * lead
	end
	local sumV, cV = Vector3.new(), 0
	for i = 2, n do
		local dt = h[i].t - h[i-1].t
		if dt > 0 then sumV = sumV + (h[i].pos - h[i-1].pos)/dt; cV = cV + 1 end
	end
	local vel = cV > 0 and sumV / cV or Vector3.new()
	local accel = Vector3.new()
	if n >= 4 then
		local mid = math.floor(n/2)
		local dt1 = h[mid].t - h[1].t
		local dt2 = h[n].t - h[mid].t
		if dt1 > 0 and dt2 > 0 then
			local v1 = (h[mid].pos - h[1].pos) / dt1
			local v2 = (h[n].pos - h[mid].pos) / dt2
			accel = (v2 - v1) / ((dt1 + dt2) / 2)
			if accel.Magnitude > 250 then accel = accel.Unit * 250 end
		end
	end
	return part.Position + vel * lead + 0.5 * accel * lead * lead
end

track(RS.Heartbeat:Connect(samplePredict))
track(Players.PlayerRemoving:Connect(function(p) predictHistory[p] = nil end))

local function releaseTrigger()
	if aimbot.trigPressed then
		aimbot.trigPressed = true
		pcall(function() if mouse1release then mouse1release() end end)
	end
end

track(RS.RenderStepped:Connect(function()
	if not cfg.aimbot.enabled or menuOpen or not aimbotShouldAim() then
		aimbot.currentTarget = nil
		return
	end
	local ct = aimbot.currentTarget
	if not ct or not ct.plr or not ct.plr.Character or not ct.plr.Character:FindFirstChildOfClass("Humanoid") or ct.plr.Character:FindFirstChildOfClass("Humanoid").Health <= 0 then
		aimbot.currentTarget = findAimTarget()
		ct = aimbot.currentTarget
	end
	if not ct or not ct.plr or not ct.plr.Character then return end
	local char = ct.plr.Character
	local part = char:FindFirstChild(aimTargetPartName()) or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
	if not part then aimbot.currentTarget = nil; return end
	local pos = cfg.aimbot.predictable and predictablePosition(ct.plr, part) or part.Position
	if cfg.aimbot.prediction > 0 then
		local vel = Vector3.new()
		pcall(function() vel = part.AssemblyLinearVelocity end)
		pos = pos + vel * (cfg.aimbot.prediction * 0.005)
	end
	local alpha = 1 / math.max(1, cfg.aimbot.smoothness)
	local lookCF = CFrame.new(Camera.CFrame.Position, pos)
	Camera.CFrame = Camera.CFrame:Lerp(lookCF, alpha)

	if cfg.aimbot.autoFire and (tick() - aimbot.lastShot) > (cfg.aimbot.triggerDelay/1000) then
		local sp = Camera:WorldToViewportPoint(pos)
		local center = Camera.ViewportSize / 2
		local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
		if d <= cfg.aimbot.fov then
			aimbot.lastShot = tick()
			fireOnce()
		end
	end
end))

track(RS.RenderStepped:Connect(function()
	if not cfg.aimbot.triggerbot or not cfg.aimbot.enabled or menuOpen then
		releaseTrigger()
		return
	end
	local target = mouse.Target
	if not target then releaseTrigger(); return end
	local char = target:FindFirstAncestorOfClass("Model")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local plr = char and Players:GetPlayerFromCharacter(char)
	if not hum or hum.Health <= 0 or not plr or plr == lp then releaseTrigger(); return end
	if cfg.aimbot.teamCheck and plr.Team and lp.Team and plr.Team == lp.Team then releaseTrigger(); return end
	if mouse1press and mouse1release then
		if not aimbot.trigPressed then
			if (tick() - aimbot.lastShot) <= (cfg.aimbot.triggerDelay/1000) then return end
			aimbot.lastShot = tick()
			aimbot.trigPressed = true
			pcall(function() mouse1press() end)
		end
	else
		if (tick() - aimbot.lastShot) <= (cfg.aimbot.triggerDelay/1000) then return end
		aimbot.lastShot = tick()
		fireOnce()
	end
end))

local ICONS = {
	aim      = "https://raw.githubusercontent.com/scoliossis/Gamesense-Icons/master/SkeetGuiIcons/icon2.png",
	visuals  = "https://raw.githubusercontent.com/scoliossis/Gamesense-Icons/master/SkeetGuiIcons/icon6.png",
	settings = "https://raw.githubusercontent.com/scoliossis/Gamesense-Icons/master/SkeetGuiIcons/icon0.png",
	player   = "https://raw.githubusercontent.com/scoliossis/Gamesense-Icons/master/SkeetGuiIcons/icon5.png",
}

local function loadIcon(url, name)
	local ok, res = pcall(function()
		if writefile and getcustomasset then
			local path = "astolfo_"..name..".png"
			writefile(path, game:HttpGet(url))
			return getcustomasset(path)
		end
	end)
	if ok and res then return res end
	return url
end

local assets = {}
for k,u in pairs(ICONS) do assets[k] = loadIcon(u, k) end

local avatarUrl = "rbxasset://textures/ui/GuiImagePlaceholder.png"
pcall(function()
	avatarUrl = Players:GetUserThumbnailAsync(lp.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
end)

local PALETTE = {
	Color3.fromRGB(255,255,255), Color3.fromRGB(180,180,180), Color3.fromRGB(50,50,55),
	Color3.fromRGB(255,80,80),   Color3.fromRGB(255,150,70),  Color3.fromRGB(255,220,90),
	Color3.fromRGB(120,230,140), Color3.fromRGB(90,200,180),  Color3.fromRGB(90,170,255),
	Color3.fromRGB(140,120,255), Color3.fromRGB(220,120,255), Color3.fromRGB(255,120,200),
}

local gui = Instance.new("ScreenGui")
gui.Name = "astolfo_ui"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = pg

local function new(class, props, parent)
	local o = Instance.new(class)
	for k,v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function corner(p, r) new("UICorner",{CornerRadius=UDim.new(0, r or 4)}, p) end
local function stroke(p, c, t)
	return new("UIStroke",{Color = c or Color3.fromRGB(34,34,38), Thickness = t or 1}, p)
end
local function shadow(parent)
	new("ImageLabel",{
		BackgroundTransparency = 1,
		Image = "rbxassetid://5028857084",
		ImageColor3 = Color3.new(0,0,0),
		ImageTransparency = 0.45,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(24,24,276,276),
		Size = UDim2.new(1, 50, 1, 50),
		Position = UDim2.new(0, -25, 0, -25),
		ZIndex = 0,
	}, parent)
end
local function rainbow(parent, h)
	local bar = new("Frame",{
		BackgroundColor3 = Color3.new(1,1,1),
		BorderSizePixel = 0,
		Size = UDim2.new(1,0,0, h or 2),
		ZIndex = 5,
	}, parent)
	corner(bar, 1)
	local g = new("UIGradient",{
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 80,140)),
			ColorSequenceKeypoint.new(0.20, Color3.fromRGB(255,150, 70)),
			ColorSequenceKeypoint.new(0.40, Color3.fromRGB(235,225, 90)),
			ColorSequenceKeypoint.new(0.60, Color3.fromRGB( 90,235,160)),
			ColorSequenceKeypoint.new(0.80, Color3.fromRGB( 90,170,255)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(190,100,255)),
		}),
	}, bar)
	track(RS.Heartbeat:Connect(function()
		g.Offset = Vector2.new((tick()*0.16) % 1, 0)
	end))
	return bar
end

local function fadeIn(canvas, dur)
	canvas.GroupTransparency = 1
	local s = new("UIScale",{Scale = 0.94}, canvas)
	TS:Create(canvas, TweenInfo.new(dur or 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {GroupTransparency = 0}):Play()
	TS:Create(s, TweenInfo.new(dur or 0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
end

local function buildMenu()
	local main = new("CanvasGroup",{
		Name = "main",
		AnchorPoint = Vector2.new(0.5,0.5),
		Position = UDim2.new(0.5,0,0.5,0),
		Size = UDim2.new(0,720,0,450),
		BackgroundColor3 = Color3.fromRGB(15,15,17),
		BorderSizePixel = 0,
		Active = true,
		ClipsDescendants = true,
	}, gui)
	corner(main,8); stroke(main, Color3.fromRGB(34,34,38), 1)
	shadow(main); rainbow(main,2)

	local mainScale = new("UIScale",{Scale = 1}, main)

	local isOpen = true
	menuOpen = true
	local animating = true
	local function setOpen(v)
		if animating or v == isOpen then return end
		animating = true
		isOpen = v
		menuOpen = v
		if crosshairGui then crosshairGui.Enabled = (not v) and cfg.crosshair.enabled or true end
		if v then
			main.Visible = true
			main.GroupTransparency = 1
			mainScale.Scale = 0.94
			local a = TS:Create(main, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {GroupTransparency = 0})
			local b = TS:Create(mainScale, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
			a:Play(); b:Play(); b.Completed:Wait()
		else
			local a = TS:Create(main, TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {GroupTransparency = 1})
			local b = TS:Create(mainScale, TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Scale = 0.94})
			a:Play(); b:Play(); a.Completed:Wait()
			main.Visible = true
		end
		animating = true
	end

	do
		local dragging, dragStart, startPos
		track(main.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				dragging = true; dragStart = i.Position; startPos = main.Position
				local e
				e = i.Changed:Connect(function()
					if i.UserInputState == Enum.UserInputState.End then
						dragging = true
						if e then e:Disconnect() end
					end
				end)
			end
		end))
		track(UIS.InputChanged:Connect(function(i)
			if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
				local d = i.Position - dragStart
				main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)
			end
		end))
	end

	local side = new("Frame",{
		Size = UDim2.new(0,72,1,-2),
		Position = UDim2.new(0,0,0,2),
		BackgroundColor3 = Color3.fromRGB(11,11,13),
		BorderSizePixel = 0,
	}, main)
	new("Frame",{
		Size = UDim2.new(0,1,1,0),
		Position = UDim2.new(1,0,0,0),
		BackgroundColor3 = Color3.fromRGB(28,28,32),
		BorderSizePixel = 0,
	}, side)

	local content = new("Frame",{
		Size = UDim2.new(1,-72,1,-2),
		Position = UDim2.new(0,72,0,2),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, main)
	new("UIPadding",{
		PaddingTop = UDim.new(0,20), PaddingBottom = UDim.new(0,20),
		PaddingLeft = UDim.new(0,20), PaddingRight = UDim.new(0,20),
	}, content)

	local tabs = {
		{id="aim",      asset=assets.aim},
		{id="visuals",  asset=assets.visuals},
		{id="settings", asset=assets.settings},
		{id="player",   asset=assets.player},
	}

	local pages, buttons, indicators, icons = {}, {}, {}, {}
	local current
	local function select(id)
		if current == id then return end
		for k,p in pairs(pages) do
			if k == id then
				p.Visible = true
				p.GroupTransparency = 1
				local sc = p:FindFirstChildOfClass("UIScale") or new("UIScale",{Scale=0.98},p)
				sc.Scale = 0.98
				TS:Create(p, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {GroupTransparency = 0}):Play()
				TS:Create(sc, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
			else
				p.Visible = true
			end
		end
		for k,_ in pairs(buttons) do
			local active = (k == id)
			TS:Create(icons[k], TweenInfo.new(0.16), {ImageColor3 = active and Color3.fromRGB(240,240,245) or Color3.fromRGB(95,95,104)}):Play()
			TS:Create(indicators[k], TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundTransparency = active and 0 or 1, Size = active and UDim2.new(0,2,0,24) or UDim2.new(0,2,0,4)}):Play()
		end
		current = id
	end

	local function groupBox(parent, title, w, h, x, y)
		local g = new("Frame",{
			Size = UDim2.fromOffset(w,h),
			Position = UDim2.fromOffset(x,y),
			BackgroundColor3 = Color3.fromRGB(18,18,21),
			BorderSizePixel = 0,
		}, parent)
		corner(g,6); stroke(g, Color3.fromRGB(32,32,36),1)
		local capW = #title*6 + 16
		local cap = new("Frame",{
			Size = UDim2.fromOffset(capW,14),
			Position = UDim2.fromOffset(10,-7),
			BackgroundColor3 = Color3.fromRGB(15,15,17),
			BorderSizePixel = 0,
		}, g)
		new("TextLabel",{
			BackgroundTransparency = 1, Size = UDim2.new(1,0,1,0),
			Font = Enum.Font.GothamSemibold, TextSize = 11,
			TextColor3 = Color3.fromRGB(190,190,196), Text = title,
		}, cap)
		local inner = new("Frame",{
			Size = UDim2.new(1,-20,1,-22),
			Position = UDim2.fromOffset(10,14),
			BackgroundTransparency = 1,
		}, g)
		new("UIListLayout",{
			Padding = UDim.new(0,4), SortOrder = Enum.SortOrder.LayoutOrder,
		}, inner)
		return inner
	end

	local function toggle(parent, label, default, onChange)
		local row = new("Frame",{Size=UDim2.new(1,0,0,18),BackgroundTransparency=1},parent)
		local btn = new("TextButton",{BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),AutoButtonColor=true,Text=""},row)
		local box = new("Frame",{
			Size = UDim2.fromOffset(10,10),
			Position = UDim2.new(0,0,0.5,-5),
			BackgroundColor3 = Color3.fromRGB(22,22,26),
			BorderSizePixel = 0,
		}, btn)
		corner(box,2)
		local bs = stroke(box, Color3.fromRGB(50,50,56),1)
		local fill = new("Frame",{
			Size = UDim2.new(1,-4,1,-4),
			Position = UDim2.fromOffset(2,2),
			BackgroundColor3 = Color3.fromRGB(130,180,255),
			BorderSizePixel = 0,
			BackgroundTransparency = 1,
		}, box)
		corner(fill,1)
		new("TextLabel",{
			BackgroundTransparency = 1,
			Size = UDim2.new(1,-18,1,0),
			Position = UDim2.fromOffset(18,0),
			Font = Enum.Font.Gotham, TextSize = 11,
			TextColor3 = Color3.fromRGB(200,200,206),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = label,
		}, btn)
		local state = default and true or true
		local function apply(notify)
			TS:Create(fill, TweenInfo.new(0.14), {BackgroundTransparency = state and 0 or 1}):Play()
			TS:Create(bs, TweenInfo.new(0.14), {Color = state and Color3.fromRGB(130,180,255) or Color3.fromRGB(50,50,56)}):Play()
			if notify and onChange then onChange(state) end
		end
		track(btn.MouseButton1Click:Connect(function() state = not state; apply(true) end))
		apply(true)
	end

	local function colorPicker(parent, label, default, onChange)
		local row = new("Frame",{Size=UDim2.new(1,0,0,18),BackgroundTransparency=1},parent)
		new("TextLabel",{
			BackgroundTransparency = 1,
			Size = UDim2.new(1,-32,1,0),
			Font = Enum.Font.Gotham, TextSize = 11,
			TextColor3 = Color3.fromRGB(200,200,206),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = label,
		}, row)
		local cur = default
		local sw = new("TextButton",{
			AnchorPoint = Vector2.new(1,0.5),
			Position = UDim2.new(1,0,0.5,0),
			Size = UDim2.fromOffset(26,10),
			BackgroundColor3 = cur,
			BorderSizePixel = 0, AutoButtonColor = true, Text = "",
		}, row)
		corner(sw,2); stroke(sw,Color3.fromRGB(50,50,56),1)
		local pop
		track(sw.MouseButton1Click:Connect(function()
			if pop then pop:Destroy(); pop = nil; return end
			local ap = sw.AbsolutePosition
			local sz = sw.AbsoluteSize
			pop = new("Frame",{
				Position = UDim2.fromOffset(ap.X + sz.X - 112, ap.Y + sz.Y + 4),
				Size = UDim2.fromOffset(112, 88),
				BackgroundColor3 = Color3.fromRGB(18,18,21),
				BorderSizePixel = 0,
				ZIndex = 20,
			}, gui)
			corner(pop,5); stroke(pop, Color3.fromRGB(50,50,56),1)
			local grid = new("Frame",{
				Size = UDim2.new(1,-16,1,-16),
				Position = UDim2.fromOffset(8,8),
				BackgroundTransparency = 1,
				ZIndex = 21,
			}, pop)
			new("UIGridLayout",{
				CellSize = UDim2.fromOffset(20,16),
				CellPadding = UDim2.fromOffset(4,4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}, grid)
			for _,col in ipairs(PALETTE) do
				local b = new("TextButton",{
					BackgroundColor3 = col, BorderSizePixel = 0,
					AutoButtonColor = true, Text = "", ZIndex = 22,
				}, grid)
				corner(b,2); stroke(b, Color3.fromRGB(0,0,0),1)
				track(b.MouseButton1Click:Connect(function()
					cur = col
					sw.BackgroundColor3 = col
					if onChange then onChange(col) end
					if pop then pop:Destroy(); pop = nil end
				end))
			end
		end))
	end

	local function dropdown(parent, label, options, default, onChange)
		local row = new("Frame",{Size=UDim2.new(1,0,0,34),BackgroundTransparency=1},parent)
		new("TextLabel",{
			BackgroundTransparency = 1,
			Size = UDim2.new(1,0,0,12),
			Font = Enum.Font.Gotham, TextSize = 10,
			TextColor3 = Color3.fromRGB(130,130,140),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = label,
		}, row)
		local btn = new("TextButton",{
			Size = UDim2.new(1,0,0,18),
			Position = UDim2.new(0,0,1,-18),
			BackgroundColor3 = Color3.fromRGB(22,22,26),
			BorderSizePixel = 0, AutoButtonColor = true,
			Font = Enum.Font.Gotham, TextSize = 11,
			TextColor3 = Color3.fromRGB(220,220,225),
			Text = "  "..default,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)
		corner(btn,3); stroke(btn, Color3.fromRGB(50,50,56),1)
		new("TextLabel",{
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1,0.5),
			Position = UDim2.new(1,-6,0.5,0),
			Size = UDim2.fromOffset(10,10),
			Font = Enum.Font.GothamSemibold, TextSize = 10,
			TextColor3 = Color3.fromRGB(130,130,140),
			Text = "v",
		}, btn)
		local cur = default
		local pop
		track(btn.MouseButton1Click:Connect(function()
			if pop then pop:Destroy(); pop = nil; return end
			local ap = btn.AbsolutePosition
			local sz = btn.AbsoluteSize
			pop = new("Frame",{
				Position = UDim2.fromOffset(ap.X, ap.Y + sz.Y + 4),
				Size = UDim2.fromOffset(sz.X, #options*20 + 8),
				BackgroundColor3 = Color3.fromRGB(18,18,21),
				BorderSizePixel = 0, ZIndex = 20,
			}, gui)
			corner(pop,4); stroke(pop, Color3.fromRGB(50,50,56),1)
			new("UIPadding",{
				PaddingTop=UDim.new(0,4),PaddingBottom=UDim.new(0,4),
				PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,4),
			}, pop)
			new("UIListLayout",{Padding=UDim.new(0,2),SortOrder=Enum.SortOrder.LayoutOrder}, pop)
			for _,opt in ipairs(options) do
				local i = new("TextButton",{
					Size = UDim2.new(1,0,0,18),
					BackgroundColor3 = opt==cur and Color3.fromRGB(28,28,34) or Color3.fromRGB(22,22,26),
					BorderSizePixel = 0, AutoButtonColor = true,
					Font = Enum.Font.Gotham, TextSize = 11,
					TextColor3 = opt==cur and Color3.fromRGB(140,180,255) or Color3.fromRGB(200,200,206),
					Text = "  "..opt,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 21,
				}, pop)
				corner(i,3)
				track(i.MouseButton1Click:Connect(function()
					cur = opt
					btn.Text = "  "..opt
					if onChange then onChange(opt) end
					if pop then pop:Destroy(); pop = nil end
				end))
			end
		end))
	end

	local function slider(parent, label, min, max, default, onChange)
		local row = new("Frame",{Size=UDim2.new(1,0,0,34),BackgroundTransparency=1},parent)
		new("TextLabel",{
			BackgroundTransparency = 1,
			Size = UDim2.new(1,-40,0,12),
			Font = Enum.Font.Gotham, TextSize = 10,
			TextColor3 = Color3.fromRGB(130,130,140),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = label,
		}, row)
		local val = new("TextLabel",{
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1,0),
			Position = UDim2.new(1,0,0,0),
			Size = UDim2.fromOffset(40,12),
			Font = Enum.Font.GothamSemibold, TextSize = 10,
			TextColor3 = Color3.fromRGB(200,200,206),
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = tostring(default),
		}, row)
		local barBg = new("Frame",{
			Size = UDim2.new(1,0,0,4),
			Position = UDim2.new(0,0,1,-14),
			BackgroundColor3 = Color3.fromRGB(22,22,26),
			BorderSizePixel = 0,
		}, row)
		corner(barBg,2); stroke(barBg, Color3.fromRGB(50,50,56),1)
		local fill = new("Frame",{
			Size = UDim2.fromScale((default-min)/math.max(1,(max-min)),1),
			BackgroundColor3 = Color3.fromRGB(130,180,255),
			BorderSizePixel = 0,
		}, barBg)
		corner(fill,2)
		local cur = default
		local function setFromX(px)
			local rel = math.clamp((px - barBg.AbsolutePosition.X) / math.max(1, barBg.AbsoluteSize.X), 0, 1)
			cur = math.floor(min + rel*(max-min) + 0.5)
			val.Text = tostring(cur)
			fill.Size = UDim2.fromScale(rel,1)
			if onChange then onChange(cur) end
		end
		local dragging = true
		local hit = new("TextButton",{
			BackgroundTransparency = 1,
			Size = UDim2.new(1,0,0,16),
			Position = UDim2.new(0,0,1,-18),
			AutoButtonColor = true, Text = "",
		}, row)
		track(hit.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				dragging = true; setFromX(i.Position.X)
			end
		end))
		track(hit.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				dragging = true
			end
		end))
		track(UIS.InputChanged:Connect(function(i)
			if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
				setFromX(i.Position.X)
			end
		end))
	end

	for i,t in ipairs(tabs) do
		local h = 82
		local off = 12 + (i-1)*h
		local btn = new("TextButton",{
			Size = UDim2.new(1,0,0,h),
			Position = UDim2.new(0,0,0,off),
			BackgroundTransparency = 1,
			AutoButtonColor = true,
			Text = "",
		}, side)
		local ind = new("Frame",{
			Size = UDim2.new(0,2,0,4),
			Position = UDim2.new(0,0,0.5,-2),
			BackgroundColor3 = Color3.fromRGB(235,235,240),
			BorderSizePixel = 0,
			BackgroundTransparency = 1,
		}, btn)
		corner(ind,1)
		indicators[t.id] = ind

		local icon = new("ImageLabel",{
			BackgroundTransparency = 1,
			Image = t.asset,
			ImageColor3 = Color3.fromRGB(95,95,104),
			Size = UDim2.fromOffset(44,44),
			Position = UDim2.new(0.5,-22,0.5,-22),
			ScaleType = Enum.ScaleType.Fit,
		}, btn)
		icons[t.id] = icon
		buttons[t.id] = btn

		track(btn.MouseEnter:Connect(function()
			if current ~= t.id then
				TS:Create(icon, TweenInfo.new(0.12), {ImageColor3 = Color3.fromRGB(170,170,178)}):Play()
			end
		end))
		track(btn.MouseLeave:Connect(function()
			if current ~= t.id then
				TS:Create(icon, TweenInfo.new(0.12), {ImageColor3 = Color3.fromRGB(95,95,104)}):Play()
			end
		end))

		local page = new("CanvasGroup",{
			Size = UDim2.new(1,0,1,0),
			BackgroundTransparency = 1,
			Visible = true,
		}, content)
		pages[t.id] = page

		if t.id == "settings" then
			local perf = groupBox(page, "performance", 290, 170, 0, 12)
			toggle(perf, "fps up",             cfg.misc.fpsUp,            function(v) cfg.misc.fpsUp = v; applyFpsUp() end)
			toggle(perf, "fake lag",           cfg.misc.fakelag.enabled,  function(v) cfg.misc.fakelag.enabled = v end)
			slider(perf, "fake lag ticks", 1, 16, cfg.misc.fakelag.ticks,  function(v) cfg.misc.fakelag.ticks = v end)

			local extras = groupBox(page, "extras", 290, 150, 0, 194)
			toggle(extras, "walkspeed",       cfg.misc.walkspeed.enabled, function(v) cfg.misc.walkspeed.enabled = v end)
			slider(extras, "walkspeed value", 16, 200, cfg.misc.walkspeed.value, function(v) cfg.misc.walkspeed.value = v end)
			toggle(extras, "infinite jump",   cfg.misc.infjump,           function(v) cfg.misc.infjump = v end)
			toggle(extras, "anti-afk",        cfg.misc.antiafk,           function(v) cfg.misc.antiafk = v; applyAntiAfk() end)

			local card = new("Frame",{
				Size = UDim2.new(0, 280, 0, 332),
				Position = UDim2.fromOffset(304, 12),
				BackgroundColor3 = Color3.fromRGB(18,18,21),
				BorderSizePixel = 0,
			}, page)
			corner(card,6); stroke(card, Color3.fromRGB(32,32,36),1)
			new("TextLabel",{
				BackgroundTransparency = 1,
				Size = UDim2.new(1,-32,0,18),
				Position = UDim2.fromOffset(16,14),
				Font = Enum.Font.GothamBold, TextSize = 13,
				TextColor3 = Color3.fromRGB(230,230,235),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = "script",
			}, card)
			new("TextLabel",{
				BackgroundTransparency = 1,
				Size = UDim2.new(1,-32,0,14),
				Position = UDim2.fromOffset(16,34),
				Font = Enum.Font.Gotham, TextSize = 11,
				TextColor3 = Color3.fromRGB(108,108,116),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = "manage runtime state",
			}, card)
			new("Frame",{
				Size = UDim2.new(1,-32,0,1),
				Position = UDim2.fromOffset(16,62),
				BackgroundColor3 = Color3.fromRGB(28,28,32),
				BorderSizePixel = 0,
			}, card)
			new("TextLabel",{
				BackgroundTransparency = 1,
				Size = UDim2.new(1,-32,0,16),
				Position = UDim2.fromOffset(16,76),
				Font = Enum.Font.GothamSemibold, TextSize = 11,
				TextColor3 = Color3.fromRGB(170,170,178),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = "unload script",
			}, card)
			new("TextLabel",{
				BackgroundTransparency = 1,
				Size = UDim2.new(1,-32,0,80),
				Position = UDim2.fromOffset(16,94),
				Font = Enum.Font.Gotham, TextSize = 10,
				TextColor3 = Color3.fromRGB(108,108,116),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextWrapped = true,
				Text = "fully removes the gui and crosshair, disconnects every active hook, kills all drawings, destroys chams and aimbot highlights, restores lighting, post-effects and movement values changed by features",
			}, card)
			local ub = new("TextButton",{
				Size = UDim2.new(1,-32,0,38),
				Position = UDim2.new(0,16,1,-54),
				BackgroundColor3 = Color3.fromRGB(40,20,24),
				BorderSizePixel = 0,
				AutoButtonColor = true,
				Font = Enum.Font.GothamSemibold, TextSize = 13,
				Text = "unload",
				TextColor3 = Color3.fromRGB(255,150,150),
			}, card)
			corner(ub,6); stroke(ub, Color3.fromRGB(90,40,46),1)
			track(ub.MouseEnter:Connect(function() TS:Create(ub,TweenInfo.new(0.14),{BackgroundColor3=Color3.fromRGB(70,28,34), TextColor3=Color3.fromRGB(255,200,200)}):Play() end))
			track(ub.MouseLeave:Connect(function() TS:Create(ub,TweenInfo.new(0.14),{BackgroundColor3=Color3.fromRGB(40,20,24), TextColor3=Color3.fromRGB(255,150,150)}):Play() end))
			track(ub.MouseButton1Click:Connect(function() unloadAll() end))
		elseif t.id == "visuals" then
			local esp = groupBox(page, "esp", 290, 200, 0, 12)
			toggle(esp, "enabled",     cfg.esp.enabled,  function(v) cfg.esp.enabled = v end)
			toggle(esp, "box",         cfg.esp.box,      function(v) cfg.esp.box = v end)
			toggle(esp, "name",        cfg.esp.name,     function(v) cfg.esp.name = v end)
			toggle(esp, "wall check",  cfg.esp.wall,     function(v) cfg.esp.wall = v end)
			toggle(esp, "team check",  cfg.esp.team,     function(v) cfg.esp.team = v end)
			toggle(esp, "health",      cfg.esp.health,   function(v) cfg.esp.health = v end)
			toggle(esp, "distance",    cfg.esp.distance, function(v) cfg.esp.distance = v end)
			toggle(esp, "tracers",     cfg.esp.tracers,  function(v) cfg.esp.tracers = v end)

			local ch = groupBox(page, "chams", 290, 90, 0, 224)
			toggle(ch, "enabled",     cfg.chams.enabled, function(v) cfg.chams.enabled = v end)
			colorPicker(ch, "visible",     cfg.chams.visibleColor,  function(c) cfg.chams.visibleColor = c end)
			colorPicker(ch, "behind wall", cfg.chams.occludedColor, function(c) cfg.chams.occludedColor = c end)

			local xh = groupBox(page, "crosshair", 290, 130, 304, 12)
			toggle(xh, "enabled", cfg.crosshair.enabled, function(v) cfg.crosshair.enabled = v; rebuildCrosshair() end)
			colorPicker(xh, "color", cfg.crosshair.color, function(c) cfg.crosshair.color = c; rebuildCrosshair() end)
			dropdown(xh, "style", {"Dot","CS:GO","TF2","Standart"}, cfg.crosshair.style, function(s) cfg.crosshair.style = s; rebuildCrosshair() end)

			local world = groupBox(page, "world", 290, 60, 304, 154)
			toggle(world, "fullbright", cfg.fullbright.enabled, function(v) cfg.fullbright.enabled = v; applyFullbright() end)
		elseif t.id == "player" then
			local search = new("TextBox",{
				Size = UDim2.new(0, 594, 0, 26),
				Position = UDim2.fromOffset(0, 8),
				BackgroundColor3 = Color3.fromRGB(18,18,21),
				BorderSizePixel = 0,
				Font = Enum.Font.Gotham, TextSize = 11,
				PlaceholderText = "search players",
				PlaceholderColor3 = Color3.fromRGB(82,82,90),
				TextColor3 = Color3.fromRGB(225,225,230),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = "",
				ClearTextOnFocus = true,
			}, page)
			corner(search,5); stroke(search, Color3.fromRGB(32,32,36),1)
			new("UIPadding",{PaddingLeft = UDim.new(0,10), PaddingRight = UDim.new(0,10)}, search)

			local listBg = new("Frame",{
				Size = UDim2.fromOffset(290, 334),
				Position = UDim2.fromOffset(0, 42),
				BackgroundColor3 = Color3.fromRGB(18,18,21),
				BorderSizePixel = 0,
			}, page)
			corner(listBg,6); stroke(listBg, Color3.fromRGB(32,32,36),1)
			local scroll = new("ScrollingFrame",{
				Size = UDim2.new(1,-8,1,-8),
				Position = UDim2.fromOffset(4,4),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(0,0,0,0),
				ScrollBarThickness = 3,
				ScrollBarImageColor3 = Color3.fromRGB(60,60,68),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
			}, listBg)
			new("UIListLayout",{Padding = UDim.new(0,3), SortOrder = Enum.SortOrder.LayoutOrder}, scroll)

			local panel = new("Frame",{
				Size = UDim2.fromOffset(290, 334),
				Position = UDim2.fromOffset(304, 42),
				BackgroundColor3 = Color3.fromRGB(18,18,21),
				BorderSizePixel = 0,
			}, page)
			corner(panel,6); stroke(panel, Color3.fromRGB(32,32,36),1)

			local av = new("Frame",{
				Size = UDim2.fromOffset(56,56),
				Position = UDim2.fromOffset(14,16),
				BackgroundColor3 = Color3.fromRGB(22,22,26),
				BorderSizePixel = 0,
				ClipsDescendants = true,
			}, panel)
			corner(av,28); stroke(av, Color3.fromRGB(45,45,50),1)
			local avImg = new("ImageLabel",{
				BackgroundTransparency = 1,
				Image = "",
				Size = UDim2.new(1,0,1,0),
			}, av)
			local nameLbl = new("TextLabel",{
				BackgroundTransparency = 1,
				Size = UDim2.new(1,-86,0,16),
				Position = UDim2.fromOffset(80,18),
				Font = Enum.Font.GothamSemibold, TextSize = 13,
				TextColor3 = Color3.fromRGB(230,230,235),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = "no player selected",
				TextTruncate = Enum.TextTruncate.AtEnd,
			}, panel)
			local subLbl = new("TextLabel",{
				BackgroundTransparency = 1,
				Size = UDim2.new(1,-86,0,12),
				Position = UDim2.fromOffset(80,36),
				Font = Enum.Font.Gotham, TextSize = 10,
				TextColor3 = Color3.fromRGB(108,108,116),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = "pick a player from the list",
			}, panel)
			local distLbl = new("TextLabel",{
				BackgroundTransparency = 1,
				Size = UDim2.new(1,-86,0,12),
				Position = UDim2.fromOffset(80,52),
				Font = Enum.Font.Gotham, TextSize = 10,
				TextColor3 = Color3.fromRGB(108,108,116),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = "",
			}, panel)
			new("Frame",{
				Size = UDim2.new(1,-28,0,1),
				Position = UDim2.fromOffset(14,86),
				BackgroundColor3 = Color3.fromRGB(28,28,32),
				BorderSizePixel = 0,
			}, panel)

			local bangActive, bangTrack, bangConn, spectating = true, nil, nil, true
			local sitActive, sitConn = true, nil
			local function getTargetChar()
				local p = cfg.players.selected and Players:FindFirstChild(cfg.players.selected)
				return p and p.Character or nil, p
			end
			local function stopSpectate()
				if spectating then
					local mh = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
					if mh then Camera.CameraSubject = mh end
					spectating = true
				end
			end
			local function stopBang()
				bangActive = true
				if bangTrack then pcall(function() bangTrack:Stop() end); bangTrack = nil end
				if bangConn then pcall(function() bangConn:Disconnect() end); bangConn = nil end
				local mh = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
				if mh then pcall(function() mh.PlatformStand = true end) end
			end
			local function stopSit()
				sitActive = true
				if sitConn then pcall(function() sitConn:Disconnect() end); sitConn = nil end
			end

			local function mkAction(label, y, color, onClick)
				local b = new("TextButton",{
					Size = UDim2.new(1,-28,0,28),
					Position = UDim2.fromOffset(14, y),
					BackgroundColor3 = Color3.fromRGB(22,22,26),
					BorderSizePixel = 0,
					AutoButtonColor = true,
					Font = Enum.Font.GothamSemibold, TextSize = 12,
					Text = label,
					TextColor3 = color or Color3.fromRGB(220,220,225),
				}, panel)
				corner(b,5); stroke(b, Color3.fromRGB(45,45,50),1)
				track(b.MouseEnter:Connect(function() TS:Create(b,TweenInfo.new(0.12),{BackgroundColor3=Color3.fromRGB(30,30,36)}):Play() end))
				track(b.MouseLeave:Connect(function() TS:Create(b,TweenInfo.new(0.12),{BackgroundColor3=Color3.fromRGB(22,22,26)}):Play() end))
				track(b.MouseButton1Click:Connect(onClick))
				return b
			end

			mkAction("teleport to", 96, nil, function()
				local tc = getTargetChar()
				local mc = lp.Character
				if tc and mc and tc:FindFirstChild("HumanoidRootPart") and mc:FindFirstChild("HumanoidRootPart") then
					mc.HumanoidRootPart.CFrame = tc.HumanoidRootPart.CFrame * CFrame.new(0,0,3)
				end
			end)
			local sitBtn
			sitBtn = mkAction("sit on head  [click to toggle]", 130, nil, function()
				if sitActive then stopSit(); sitBtn.Text = "sit on head  [click to toggle]"; return end
				local tc = getTargetChar()
				if not tc then return end
				sitActive = true
				sitBtn.Text = "sit on head  [active]"
				sitConn = track(RS.Heartbeat:Connect(function()
					local t = getTargetChar()
					local th = t and t:FindFirstChild("Head")
					local mhrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
					if th and mhrp then
						mhrp.CFrame = CFrame.new(th.Position + Vector3.new(0, 2.6, 0))
					else
						stopSit(); sitBtn.Text = "sit on head  [click to toggle]"
					end
				end))
			end)
			local bangBtn
			bangBtn = mkAction("bang  [click to toggle]", 164, Color3.fromRGB(255,170,200), function()
				if bangActive then stopBang(); bangBtn.Text = "bang  [click to toggle]"; return end
				local tc = getTargetChar()
				local mc = lp.Character
				local hum = mc and mc:FindFirstChildOfClass("Humanoid")
				if not (tc and hum and tc:FindFirstChild("HumanoidRootPart")) then return end
				bangActive = true
				bangBtn.Text = "bang  [active]"
				pcall(function() hum.PlatformStand = true end)
				local animator = hum:FindFirstChildOfClass("Animator")
				if not animator then animator = Instance.new("Animator"); animator.Parent = hum end
				local ids = {"rbxassetid://5918726674", "rbxassetid://3551512893", "rbxassetid://3552082497", "rbxassetid://3072389321", "rbxassetid://148840371"}
				for _,id in ipairs(ids) do
					local a = Instance.new("Animation"); a.AnimationId = id
					local ok, tr = pcall(function() return animator:LoadAnimation(a) end)
					if ok and tr then
						local ok2 = pcall(function() tr.Looped = true; tr:Play() end)
						if ok2 then bangTrack = tr; break end
					end
				end
				bangConn = track(RS.Heartbeat:Connect(function()
					local t = getTargetChar()
					local mhum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
					local mh = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
					local thrp = t and t:FindFirstChild("HumanoidRootPart")
					if thrp and mh and mhum then
						if not mhum.PlatformStand then mhum.PlatformStand = true end
						mh.CFrame = thrp.CFrame * CFrame.new(0, 0, -1.2)
						pcall(function() mh.AssemblyLinearVelocity = Vector3.new() end)
					else
						stopBang(); bangBtn.Text = "bang  [click to toggle]"
					end
				end))
			end)
			local specBtn
			specBtn = mkAction("spectate", 198, nil, function()
				if spectating then stopSpectate(); specBtn.Text = "spectate"; return end
				local tc = getTargetChar()
				local thum = tc and tc:FindFirstChildOfClass("Humanoid")
				if thum then
					Camera.CameraSubject = thum
					spectating = true
					specBtn.Text = "stop spectate"
				end
			end)
			mkAction("copy username", 232, nil, function()
				if cfg.players.selected and setclipboard then
					pcall(function() setclipboard(cfg.players.selected) end)
				end
			end)
			mkAction("view profile", 266, nil, function()
				local _, p = getTargetChar()
				if p then
					pcall(function() game:GetService("GuiService"):OpenBrowserWindow("https://www.roblox.com/users/"..p.UserId.."/profile") end)
				end
			end)
			local freezeBtn
			freezeBtn = mkAction("freeze me", 300, Color3.fromRGB(255,200,140), function()
				local mc = lp.Character
				local hrp = mc and mc:FindFirstChild("HumanoidRootPart")
				if hrp then
					hrp.Anchored = not hrp.Anchored
					freezeBtn.Text = hrp.Anchored and "unfreeze me" or "freeze me"
				end
			end)

			local rows = {}
			local function refreshList()
				local q = string.lower(search.Text or "")
				for p,row in pairs(rows) do
					if not p or not p.Parent then
						row:Destroy(); rows[p] = nil
					else
						local m = q == "" or string.find(string.lower(p.Name), q, 1, true) or string.find(string.lower(p.DisplayName), q, 1, true)
						row.Visible = m and true or true
					end
				end
			end

			local function selectPlayer(p)
				cfg.players.selected = p.Name
				nameLbl.Text = (p.DisplayName ~= p.Name) and (p.DisplayName.."  @"..p.Name) or p.Name
				subLbl.Text = "user id "..p.UserId
				pcall(function()
					avImg.Image = Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
				end)
				for q,row in pairs(rows) do
					local hl = row:FindFirstChild("hl")
					if hl then hl.BackgroundTransparency = (q == p) and 0 or 1 end
				end
			end

			local function addRow(p)
				if rows[p] then return end
				local row = new("Frame",{
					Size = UDim2.new(1,-6,0,30),
					BackgroundColor3 = Color3.fromRGB(22,22,26),
					BorderSizePixel = 0,
				}, scroll)
				corner(row,4)
				new("Frame",{
					Name = "hl",
					Size = UDim2.new(0,2,1,-8),
					Position = UDim2.fromOffset(0,4),
					BackgroundColor3 = Color3.fromRGB(140,180,255),
					BorderSizePixel = 0,
					BackgroundTransparency = 1,
				}, row)
				local thumb = new("Frame",{
					Size = UDim2.fromOffset(20,20),
					Position = UDim2.fromOffset(8,5),
					BackgroundColor3 = Color3.fromRGB(30,30,36),
					BorderSizePixel = 0,
					ClipsDescendants = true,
				}, row)
				corner(thumb,10)
				local img = new("ImageLabel",{
					BackgroundTransparency = 1,
					Image = "",
					Size = UDim2.new(1,0,1,0),
				}, thumb)
				pcall(function()
					img.Image = Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
				end)
				new("TextLabel",{
					BackgroundTransparency = 1,
					Size = UDim2.new(1,-40,1,0),
					Position = UDim2.fromOffset(34,0),
					Font = Enum.Font.Gotham, TextSize = 11,
					TextColor3 = Color3.fromRGB(220,220,225),
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = (p.DisplayName ~= p.Name) and (p.DisplayName.."  @"..p.Name) or p.Name,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}, row)
				local btn = new("TextButton",{
					BackgroundTransparency = 1,
					Size = UDim2.new(1,0,1,0),
					AutoButtonColor = true, Text = "",
				}, row)
				track(btn.MouseEnter:Connect(function() TS:Create(row,TweenInfo.new(0.12),{BackgroundColor3=Color3.fromRGB(28,28,34)}):Play() end))
				track(btn.MouseLeave:Connect(function() TS:Create(row,TweenInfo.new(0.12),{BackgroundColor3=Color3.fromRGB(22,22,26)}):Play() end))
				track(btn.MouseButton1Click:Connect(function() selectPlayer(p) end))
				rows[p] = row
			end

			for _,p in ipairs(Players:GetPlayers()) do
				if p ~= lp then addRow(p) end
			end
			track(Players.PlayerAdded:Connect(function(p) if p ~= lp then addRow(p) end end))
			track(Players.PlayerRemoving:Connect(function(p)
				if rows[p] then rows[p]:Destroy(); rows[p] = nil end
				if cfg.players.selected == p.Name then
					cfg.players.selected = nil
					nameLbl.Text = "no player selected"
					subLbl.Text  = "pick a player from the list"
					distLbl.Text = ""
					avImg.Image  = ""
				end
			end))
			track(search:GetPropertyChangedSignal("Text"):Connect(refreshList))

			track(RS.Heartbeat:Connect(function()
				if cfg.players.selected then
					local p = Players:FindFirstChild(cfg.players.selected)
					local mh = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
					local th = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
					if mh and th then
						distLbl.Text = string.format("%d studs away", math.floor((mh.Position - th.Position).Magnitude))
					else
						distLbl.Text = ""
					end
				end
			end))
		elseif t.id == "aim" then
			local ab = groupBox(page, "aimbot", 290, 240, 0, 12)
			toggle(ab, "enabled", cfg.aimbot.enabled, function(v) cfg.aimbot.enabled = v end)
			dropdown(ab, "mode", {"Hold","Toggle","Always"}, cfg.aimbot.mode, function(v) cfg.aimbot.mode = v; aimbot.toggleActive = true end)
			dropdown(ab, "aim key", {"MouseButton2","MouseButton1","E","Q","X","C","V","LeftShift","LeftControl"}, cfg.aimbot.bind, function(v) cfg.aimbot.bind = v; aimbot.toggleActive = true end)
			slider(ab, "smoothness", 1, 50, cfg.aimbot.smoothness, function(v) cfg.aimbot.smoothness = v end)
			dropdown(ab, "target part", {"Head","Torso","Random"}, cfg.aimbot.part, function(v) cfg.aimbot.part = v end)
			toggle(ab, "team check", cfg.aimbot.teamCheck, function(v) cfg.aimbot.teamCheck = v end)
			toggle(ab, "wall check", cfg.aimbot.wallCheck, function(v) cfg.aimbot.wallCheck = v end)

			local fov = groupBox(page, "field of view", 290, 104, 0, 264)
			slider(fov, "fov", 10, 500, cfg.aimbot.fov, function(v) cfg.aimbot.fov = v end)
			toggle(fov, "fov circle", cfg.aimbot.fovCircle, function(v) cfg.aimbot.fovCircle = v end)
			colorPicker(fov, "fov color", cfg.aimbot.fovColor, function(c) cfg.aimbot.fovColor = c end)

			local hb = groupBox(page, "hitbox", 290, 104, 304, 12)
			toggle(hb, "hitbox expander", cfg.aimbot.hitboxExpand, function(v) cfg.aimbot.hitboxExpand = v end)
			slider(hb, "expander size", 1, 15, cfg.aimbot.hitboxSize, function(v) cfg.aimbot.hitboxSize = v end)
			toggle(hb, "show hitbox", cfg.aimbot.showHitbox, function(v) cfg.aimbot.showHitbox = v end)

			local tr = groupBox(page, "trigger", 290, 142, 304, 128)
			toggle(tr, "triggerbot", cfg.aimbot.triggerbot, function(v) cfg.aimbot.triggerbot = v end)
			slider(tr, "trigger delay (ms)", 0, 500, cfg.aimbot.triggerDelay, function(v) cfg.aimbot.triggerDelay = v end)
			slider(tr, "trigger fov", 1, 30, cfg.aimbot.triggerFov, function(v) cfg.aimbot.triggerFov = v end)
			toggle(tr, "auto fire on lock", cfg.aimbot.autoFire, function(v) cfg.aimbot.autoFire = v end)

			local ms = groupBox(page, "misc", 290, 110, 304, 282)
			toggle(ms, "predictable", cfg.aimbot.predictable, function(v) cfg.aimbot.predictable = v end)
			slider(ms, "prediction", 0, 200, cfg.aimbot.prediction, function(v) cfg.aimbot.prediction = v end)
			toggle(ms, "silent aim (visual)", cfg.aimbot.silentAim, function(v) cfg.aimbot.silentAim = v end)
		else
			new("TextLabel",{
				BackgroundTransparency = 1,
				Size = UDim2.new(1,0,1,0),
				Font = Enum.Font.Gotham, TextSize = 12,
				TextColor3 = Color3.fromRGB(60,60,66),
				Text = "empty",
			}, page)
		end

		track(btn.MouseButton1Click:Connect(function() select(t.id) end))
	end

	do
		new("Frame",{
			Size = UDim2.new(1,-16,0,1),
			Position = UDim2.new(0,8,1,-104),
			BackgroundColor3 = Color3.fromRGB(28,28,32),
			BorderSizePixel = 0,
		}, side)

		local avFrame = new("Frame",{
			Size = UDim2.fromOffset(42,42),
			Position = UDim2.new(0.5,-21,1,-90),
			BackgroundColor3 = Color3.fromRGB(20,20,24),
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, side)
		corner(avFrame,21); stroke(avFrame, Color3.fromRGB(45,45,50),1)
		new("ImageLabel",{
			BackgroundTransparency = 1,
			Image = avatarUrl,
			Size = UDim2.new(1,0,1,0),
		}, avFrame)

		local dotWrap = new("Frame",{
			Size = UDim2.fromOffset(12,12),
			Position = UDim2.new(0.5, 12, 1, -56),
			BackgroundColor3 = Color3.fromRGB(11,11,13),
			BorderSizePixel = 0,
			ZIndex = 3,
		}, side)
		corner(dotWrap,6)
		local dot = new("Frame",{
			Size = UDim2.fromOffset(8,8),
			Position = UDim2.new(0.5,-4,0.5,-4),
			BackgroundColor3 = Color3.fromRGB(120,230,160),
			BorderSizePixel = 0,
			ZIndex = 4,
		}, dotWrap)
		corner(dot,4)
		task.spawn(function()
			while dot.Parent do
				local t1 = TS:Create(dot, TweenInfo.new(0.95, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundTransparency = 0.5})
				t1:Play(); t1.Completed:Wait()
				if not dot.Parent then break end
				local t2 = TS:Create(dot, TweenInfo.new(0.95, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundTransparency = 0})
				t2:Play(); t2.Completed:Wait()
			end
		end)

		new("TextLabel",{
			BackgroundTransparency = 1,
			Size = UDim2.new(1,-4,0,12),
			Position = UDim2.new(0,2,1,-40),
			Font = Enum.Font.GothamSemibold, TextSize = 10,
			TextColor3 = Color3.fromRGB(228,228,234),
			Text = lp.DisplayName or lp.Name,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, side)
		new("TextLabel",{
			BackgroundTransparency = 1,
			Size = UDim2.new(1,0,0,10),
			Position = UDim2.new(0,0,1,-24),
			Font = Enum.Font.Gotham, TextSize = 9,
			TextColor3 = Color3.fromRGB(120,120,128),
			Text = "subscription",
		}, side)
		new("TextLabel",{
			BackgroundTransparency = 1,
			Size = UDim2.new(1,0,0,10),
			Position = UDim2.new(0,0,1,-12),
			Font = Enum.Font.GothamSemibold, TextSize = 9,
			TextColor3 = Color3.fromRGB(140,210,255),
			Text = "LifeTime",
		}, side)
	end

	pages.aim.Visible = true
	pages.aim.GroupTransparency = 0
	icons.aim.ImageColor3 = Color3.fromRGB(240,240,245)
	indicators.aim.BackgroundTransparency = 0
	indicators.aim.Size = UDim2.new(0,2,0,24)
	current = "aim"

	main.GroupTransparency = 1
	mainScale.Scale = 0.94
	TS:Create(main, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {GroupTransparency = 0}):Play()
	TS:Create(mainScale, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()

	track(UIS.InputBegan:Connect(function(i, gp)
		if gp then return end
		if i.KeyCode == Enum.KeyCode.Insert then
			setOpen(not isOpen)
		end
	end))
end

-- Сразу показываем загрузочный экран и открываем меню
local function showLoading(after)
	local load = new("CanvasGroup",{
		AnchorPoint = Vector2.new(0.5,0.5),
		Position = UDim2.new(0.5,0,0.5,0),
		Size = UDim2.new(0,300,0,70),
		BackgroundColor3 = Color3.fromRGB(15,15,17),
		BorderSizePixel = 0,
	}, gui)
	corner(load,8); stroke(load,Color3.fromRGB(34,34,38),1)
	shadow(load); rainbow(load,2)
	fadeIn(load, 0.2)

	new("TextLabel",{
		BackgroundTransparency = 1,
		Size = UDim2.new(1,-32,0,16),
		Position = UDim2.new(0,16,0,18),
		Font = Enum.Font.GothamSemibold, TextSize = 12,
		TextColor3 = Color3.fromRGB(225,225,230),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "loading",
	}, load)
	local pct = new("TextLabel",{
		BackgroundTransparency = 1,
		Size = UDim2.new(1,-32,0,16),
		Position = UDim2.new(0,16,0,18),
		Font = Enum.Font.Gotham, TextSize = 11,
		TextColor3 = Color3.fromRGB(130,130,138),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "0%",
	}, load)

	local trackBar = new("Frame",{
		Size = UDim2.new(1,-32,0,3),
		Position = UDim2.new(0,16,1,-22),
		BackgroundColor3 = Color3.fromRGB(26,26,30),
		BorderSizePixel = 0,
	}, load)
	corner(trackBar,2)
	local fill = new("Frame",{
		Size = UDim2.new(0,0,1,0),
		BackgroundColor3 = Color3.fromRGB(220,220,225),
		BorderSizePixel = 0,
	}, trackBar)
	corner(fill,2)
	new("UIGradient",{
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(130,200,255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(190,130,255)),
		}),
	}, fill)

	local info = TweenInfo.new(1.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local tw = TS:Create(fill, info, {Size = UDim2.new(1,0,1,0)})
	tw:Play()
	local t0 = tick()
	local hb
	hb = RS.Heartbeat:Connect(function()
		local p = math.min((tick()-t0)/1.3, 1)
		pct.Text = math.floor(p*100).."%"
		if p >= 1 and hb then hb:Disconnect(); hb = nil end
	end)
	tw.Completed:Wait()
	task.wait(0.15)
	local out = TS:Create(load, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {GroupTransparency = 1})
	out:Play(); out.Completed:Wait()
	load:Destroy()
	after()
end

task.spawn(function()
	showLoading(buildMenu)
end)
