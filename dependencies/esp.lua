local esp = {}
esp.objects = {}

local camera = workspace.CurrentCamera
local runService = game:GetService("RunService")
local players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local defaultParams = {
	-- VISUALS
	box = true,
	name = true,
	distance = true,
	tracer = false,
	healthBar = false,

	-- OUTLINE
	outline = true,

	-- COLOR
	color = Color3.new(1, 1, 1),

	-- TEXT
	text = "",
	fontSize = 13,
}

local function createDrawings()
	return {
		box = Drawing.new("Square"),
		boxOutline = Drawing.new("Square"),
		name = Drawing.new("Text"),
		distance = Drawing.new("Text"),
		tracerOutline = Drawing.new("Line"),
		tracer = Drawing.new("Line"),
		healthBar = Drawing.new("Square"),
		healthOutline = Drawing.new("Square"),
	}
end

local function setupDrawing(d, params)
	-- Box
	d.box.Filled = false
	d.box.Thickness = 1
	d.box.Visible = false

	d.boxOutline.Filled = false
	d.boxOutline.Thickness = 1.45
	d.boxOutline.Color = Color3.new(0, 0, 0)
	d.boxOutline.Visible = false

	-- Text
	d.name.Center = true
	d.name.Outline = params.outline
	d.name.Size = params.fontSize
	d.name.Visible = false

	d.distance.Center = true
	d.distance.Outline = params.outline
	d.distance.Size = params.fontSize
	d.distance.Visible = false

	-- Tracer
	d.tracer.Thickness = 1
	d.tracer.Visible = false

	d.tracerOutline.Thickness = 3
	d.tracerOutline.Color = Color3.new(0, 0, 0)
	d.tracerOutline.Visible = false

	-- Health bar
	d.healthBar.Filled = true
	d.healthBar.Visible = false

	d.healthOutline.Filled = false
	d.healthOutline.Thickness = 1.2
	d.healthOutline.Color = Color3.new(0, 0, 0)
	d.healthOutline.Visible = false
end

function esp:add(obj, params)
	if not obj or self.objects[obj] then
		return
	end

	params = params or {}
	for k, v in pairs(defaultParams) do
		if params[k] == nil then
			params[k] = v
		end
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

	if typeof(obj) == "Instance" and obj:IsA("Player") then
		local function onCharacter(char)
			if not self.objects[obj] then
				return
			end
		end

		if obj.Character then
			onCharacter(obj.Character)
		end

		local charConn = obj.CharacterAdded:Connect(onCharacter)
		table.insert(data.connections, charConn)
	end

	if typeof(obj) == "Instance" then
		local conn
		conn = obj.AncestryChanged:Connect(function(_, parent)
			if not parent then
				if self.objects[obj] then
					self:remove(obj)
				end
				if conn then
					conn:Disconnect()
				end
			end
		end)
		table.insert(data.connections, conn)
	end

	if typeof(obj) == "Instance" and obj:IsA("Player") then
		local conn
		conn = players.PlayerRemoving:Connect(function(player)
			if player == obj then
				if self.objects[obj] then
					self:remove(obj)
				end
				if conn then
					conn:Disconnect()
				end
			end
		end)
		table.insert(data.connections, conn)
	end
end

function esp:remove(obj)
	local data = self.objects[obj]
	if not data then
		return
	end

	for _, d in pairs(data.drawings) do
		d:Remove()
	end

	if data.connections then
		for _, c in ipairs(data.connections) do
			pcall(function()
				c:Disconnect()
			end)
		end
	end

	self.objects[obj] = nil
end

local function getBoxData(obj)
	local humanoid, centerPos, cf, size

	if typeof(obj) == "Instance" and obj:IsA("Player") then
		local char = obj.Character
		if not char then
			return
		end

		humanoid = char:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end

		local success, modelCFrame, modelSize = pcall(function()
			return char:GetBoundingBox()
		end)
		if not success then
			return
		end

		cf = modelCFrame
		size = modelSize
		centerPos = cf.Position
	elseif typeof(obj) == "Instance" and obj:IsA("BasePart") then
		cf = obj.CFrame
		size = obj.Size
		centerPos = obj.Position
	elseif typeof(obj) == "Instance" and obj:IsA("Model") then
		local success, modelCFrame, modelSize = pcall(function()
			return obj:GetBoundingBox()
		end)
		if not success then
			return
		end
		cf = modelCFrame
		size = modelSize
		centerPos = cf.Position
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

	for _, corner in ipairs(corners) do
		local screenPos, visible = camera:WorldToViewportPoint(corner)
		minX = math.min(minX, screenPos.X)
		minY = math.min(minY, screenPos.Y)
		maxX = math.max(maxX, screenPos.X)
		maxY = math.max(maxY, screenPos.Y)
		if visible then
			anyVisible = true
		end
	end

	if not anyVisible then
		return
	end

	return {
		topLeft = Vector2.new(minX, minY),
		bottomRight = Vector2.new(maxX, maxY),
		isPlayer = obj:IsA("Player"),
		humanoid = humanoid,
		center = centerPos,
	}
end

runService.RenderStepped:Connect(function()
	for obj, data in pairs(esp.objects) do
		local params = data.params
		local d = data.drawings
		local color = params.color

		local boxData = getBoxData(obj)
		if not boxData then
			for _, v in pairs(d) do
				v.Visible = false
			end
			continue
		end

		local topLeft = boxData.topLeft
		local bottomRight = boxData.bottomRight
		local boxSize = bottomRight - topLeft
		local centerX = (topLeft.X + bottomRight.X) / 2

		-- BOX
		if params.box then
			d.box.Visible = true
			d.box.Position = topLeft
			d.box.Size = boxSize
			d.box.Color = color

			if params.outline then
				d.boxOutline.Visible = true
				d.boxOutline.Position = topLeft - Vector2.new(1, 1)
				d.boxOutline.Size = boxSize + Vector2.new(2, 2)
			else
				d.boxOutline.Visible = false
			end
		else
			d.box.Visible = false
			d.boxOutline.Visible = false
		end

		-- NAME
		if params.name or params.text ~= "" then
			d.name.Visible = true
			d.name.Position = Vector2.new(centerX, topLeft.Y - 14)
			d.name.Text = params.text ~= "" and params.text or obj.Name
			d.name.Color = color
			d.name.Size = params.fontSize
			d.name.Outline = params.outline
		else
			d.name.Visible = false
		end

		-- DISTANCE
		if params.distance then
			local dist = (camera.CFrame.Position - boxData.center).Magnitude
			d.distance.Visible = true
			d.distance.Position = Vector2.new(centerX, bottomRight.Y + 4)
			d.distance.Text = string.format("%.0f studs", dist)
			d.distance.Color = params.color
		else
			d.distance.Visible = false
		end

		-- TRACER
		if params.tracer then
			local mouse = game:GetService("UserInputService"):GetMouseLocation()
			local from = Vector2.new(mouse.X, mouse.Y)
			d.tracer.Visible = true
			d.tracer.From = from
			d.tracer.To = topLeft + Vector2.new(boxSize.X / 2, boxSize.Y / 2)

			if params.outline then
				d.tracerOutline.Visible = true
				d.tracerOutline.From = from
				d.tracerOutline.To = topLeft + Vector2.new(boxSize.X / 2, boxSize.Y / 2)
			else
				d.tracerOutline.Visible = false
			end
		else
			d.tracer.Visible = false
		end

		-- HEALTHBAR
		if params.healthBar and boxData.humanoid then
			local humanoid = boxData.humanoid
			local hp = humanoid.Health
			local maxHp = humanoid.MaxHealth
			local percent = math.clamp(hp / maxHp, 0, 1)

			local barHeight = boxSize.Y * percent
			local barPos = Vector2.new(bottomRight.X + 4, topLeft.Y + (boxSize.Y - barHeight))

			d.healthOutline.Visible = true
			d.healthOutline.Position = Vector2.new(bottomRight.X + 4, topLeft.Y)
			d.healthOutline.Size = Vector2.new(2, boxSize.Y)

			d.healthBar.Visible = true
			d.healthBar.Position = barPos
			d.healthBar.Size = Vector2.new(2, barHeight)
			d.healthBar.Color = Color3.fromRGB(255 * (1 - percent), 255 * percent, 0)
		else
			d.healthBar.Visible = false
			d.healthOutline.Visible = false
		end
	end
end)

for _, player in players:GetChildren() do
	esp:add(player)
end

return esp
