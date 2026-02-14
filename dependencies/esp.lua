local esp = {}
esp.objects = {}

local camera = workspace.CurrentCamera
local runService = game:GetService("RunService")
local players = game:GetService("Players")
local LocalPlayer = players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local defaultParams = {
	box = true,
	name = true,
	distance = true,
	tracer = true,
	healthBar = false,
	outline = true,
	color = Color3.new(1, 1, 1),
	text = "",
	fontSize = 13,
}

local function createDrawings()
	return {
		box = Drawing.new("Square"),
		boxOutline = Drawing.new("Square"),
		name = Drawing.new("Text"),
		distance = Drawing.new("Text"),
		tracer = Drawing.new("Line"),
		tracerOutline = Drawing.new("Line"),
		healthBar = Drawing.new("Square"),
		healthOutline = Drawing.new("Square"),
	}
end

local function setupDrawing(d, p)
	d.box.Filled = false
	d.box.Thickness = 1
	d.box.Visible = false

	d.boxOutline.Filled = false
	d.boxOutline.Thickness = 1.5
	d.boxOutline.Color = Color3.new(0, 0, 0)
	d.boxOutline.Visible = false

	d.name.Center = true
	d.name.Outline = p.outline
	d.name.Size = p.fontSize
	d.name.Visible = false

	d.distance.Center = true
	d.distance.Outline = p.outline
	d.distance.Size = p.fontSize
	d.distance.Visible = false

	d.tracer.Thickness = 1.4
	d.tracer.Visible = false

	d.tracerOutline.Thickness = 3.5
	d.tracerOutline.Color = Color3.new(0, 0, 0)
	d.tracerOutline.Transparency = 0.65
	d.tracerOutline.Visible = false

	d.healthBar.Filled = true
	d.healthBar.Visible = false

	d.healthOutline.Filled = false
	d.healthOutline.Thickness = 1.3
	d.healthOutline.Color = Color3.new(0, 0, 0)
	d.healthOutline.Visible = false
end

function esp:add(obj, customParams)
	if not obj or self.objects[obj] then
		return
	end

	local params = {}
	for k, v in pairs(defaultParams) do
		params[k] = customParams and customParams[k] ~= nil and customParams[k] or v
	end

	local drawings = createDrawings()
	setupDrawing(drawings, params)

	local data = {
		object = obj,
		params = params,
		drawings = drawings,
		connections = {},
	}

	self.objects[obj] = data

	if obj:IsA("Player") then
		table.insert(data.connections, obj.CharacterAdded:Connect(function() end))

		table.insert(
			data.connections,
			players.PlayerRemoving:Connect(function(p)
				if p == obj then
					esp:remove(obj)
				end
			end)
		)
	end

	local ancestryConn
	ancestryConn = obj.AncestryChanged:Connect(function(_, parent)
		if not parent then
			esp:remove(obj)
			ancestryConn:Disconnect()
		end
	end)
	table.insert(data.connections, ancestryConn)
end

function esp:remove(obj)
	local data = self.objects[obj]
	if not data then
		return
	end

	for _, v in pairs(data.drawings) do
		v:Remove()
	end

	for _, c in ipairs(data.connections) do
		pcall(c.Disconnect, c)
	end

	self.objects[obj] = nil
end

local function getBoxData(obj)
	local humanoid, centerPos, cf, size

	if obj:IsA("Player") then
		local char = obj.Character
		if not char then
			return
		end
		humanoid = char:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end

		local ok, cframe, sz = pcall(char.GetBoundingBox, char)
		if not ok then
			return
		end
		cf, size = cframe, sz
		centerPos = cframe.Position
	elseif obj:IsA("BasePart") then
		cf = obj.CFrame
		size = obj.Size
		centerPos = obj.Position
	elseif obj:IsA("Model") then
		local ok, cframe, sz = pcall(obj.GetBoundingBox, obj)
		if not ok then
			return
		end
		cf, size = cframe, sz
		centerPos = cframe.Position
	else
		return
	end

	if not cf or not size then
		return
	end

	local corners = {
		cf * Vector3.new(-size.X / 2, -size.Y / 2, -size.Z / 2),
		cf * Vector3.new(-size.X / 2, -size.Y / 2, size.Z / 2),
		cf * Vector3.new(-size.X / 2, size.Y / 2, -size.Z / 2),
		cf * Vector3.new(-size.X / 2, size.Y / 2, size.Z / 2),
		cf * Vector3.new(size.X / 2, -size.Y / 2, -size.Z / 2),
		cf * Vector3.new(size.X / 2, -size.Y / 2, size.Z / 2),
		cf * Vector3.new(size.X / 2, size.Y / 2, -size.Z / 2),
		cf * Vector3.new(size.X / 2, size.Y / 2, size.Z / 2),
	}

	local minX, minY = math.huge, math.huge
	local maxX, maxY = -math.huge, -math.huge
	local anyVisible = false

	for _, pt in corners do
		local screen, onScreen = camera:WorldToViewportPoint(pt)
		minX = math.min(minX, screen.X)
		minY = math.min(minY, screen.Y)
		maxX = math.max(maxX, screen.X)
		maxY = math.max(maxY, screen.Y)
		if onScreen then
			anyVisible = true
		end
	end

	if not anyVisible then
		return
	end

	return {
		topLeft = Vector2.new(minX, minY),
		bottomRight = Vector2.new(maxX, maxY),
		humanoid = humanoid,
		center3d = centerPos,
	}
end

runService.RenderStepped:Connect(function()
	for obj, data in pairs(esp.objects) do
		local p = data.params
		local d = data.drawings
		local col = p.color

		local box = getBoxData(obj)
		if not box then
			for _, v in pairs(d) do
				v.Visible = false
			end
			continue
		end

		local tl = box.topLeft
		local br = box.bottomRight
		local sz = br - tl
		local cx = (tl.X + br.X) / 2

		if p.box then
			d.box.Visible = true
			d.box.Position = tl
			d.box.Size = sz
			d.box.Color = col

			if p.outline then
				d.boxOutline.Visible = true
				d.boxOutline.Position = tl - Vector2.new(1, 1)
				d.boxOutline.Size = sz + Vector2.new(2, 2)
			else
				d.boxOutline.Visible = false
			end
		else
			d.box.Visible = false
			d.boxOutline.Visible = false
		end

		if p.name or p.text ~= "" then
			d.name.Visible = true
			d.name.Position = Vector2.new(cx, tl.Y - 16)
			d.name.Text = p.text ~= "" and p.text or obj.Name
			d.name.Color = col
		else
			d.name.Visible = false
		end

		if p.distance then
			local dist = (camera.CFrame.Position - box.center3d).Magnitude
			d.distance.Visible = true
			d.distance.Position = Vector2.new(cx, br.Y + 4)
			d.distance.Text = string.format("%.0f studs", dist)
			d.distance.Color = col
		else
			d.distance.Visible = false
		end

		if p.tracer then
			local from = Vector2.new(Mouse.X, Mouse.Y)
			local to = Vector2.new(cx, br.Y)

			d.tracer.Visible = true
			d.tracer.From = from
			d.tracer.To = to
			d.tracer.Color = col

			if p.outline then
				d.tracerOutline.Visible = true
				d.tracerOutline.From = from
				d.tracerOutline.To = to
			else
				d.tracerOutline.Visible = false
			end
		else
			d.tracer.Visible = false
			d.tracerOutline.Visible = false
		end

		if p.healthBar and box.humanoid then
			local hp = box.humanoid.Health
			local max = box.humanoid.MaxHealth
			local ratio = math.clamp(hp / max, 0, 1)

			local h = sz.Y * ratio
			local y = tl.Y + (sz.Y - h)

			d.healthOutline.Visible = true
			d.healthOutline.Position = Vector2.new(br.X + 5, tl.Y)
			d.healthOutline.Size = Vector2.new(4, sz.Y)

			d.healthBar.Visible = true
			d.healthBar.Position = Vector2.new(br.X + 5, y)
			d.healthBar.Size = Vector2.new(4, h)
			d.healthBar.Color = Color3.fromRGB(255 * (1 - ratio), 255 * ratio, 0)
		else
			d.healthBar.Visible = false
			d.healthOutline.Visible = false
		end
	end
end)

for _, plr in players:GetPlayers() do
	esp:add(plr)
end

players.PlayerAdded:Connect(esp.add, esp)

return esp
