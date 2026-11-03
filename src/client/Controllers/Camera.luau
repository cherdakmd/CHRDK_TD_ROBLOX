local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local Camera = {}
Camera.Center = Config.Map.Center
Camera.Distance = 188
Camera.Yaw = 0
Camera.Pitch = math.rad(59)
Camera.OnTap = nil
local rightDown, middleDown = false, false
local tapStart, tapPosition, tapTime, dragged = nil, nil, 0, false
local touches, pinchDistance = {}, nil
local keys = {}

function Camera:Init()
	self.camera = workspace.CurrentCamera
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		self.camera = workspace.CurrentCamera
		if self.camera then self.camera.CameraType = Enum.CameraType.Scriptable end
	end)
	self.camera.CameraType = Enum.CameraType.Scriptable
	self.camera.FieldOfView = 50
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.UserInputType == Enum.UserInputType.Keyboard then
			keys[input.KeyCode] = true
			if input.KeyCode == Enum.KeyCode.R then self:Reset() end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			rightDown = true
		elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
			middleDown = true
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			tapStart = input.Position; tapPosition = input.Position; tapTime = os.clock(); dragged = false
		elseif input.UserInputType == Enum.UserInputType.Touch then
			touches[input] = input.Position
			tapStart = input.Position; tapPosition = input.Position; tapTime = os.clock(); dragged = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if rightDown then
				self.Yaw -= input.Delta.X * 0.004
				self.Pitch = math.clamp(self.Pitch + input.Delta.Y * 0.003, math.rad(40), math.rad(78))
			elseif middleDown then
				self:Pan(input.Delta)
			end
			if tapStart and (Vector2.new(input.Position.X, input.Position.Y) - Vector2.new(tapStart.X, tapStart.Y)).Magnitude > 8 then dragged = true end
		elseif input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
			self:Zoom(input.Position.Z > 0 and 0.9 or 1.1)
		elseif input.UserInputType == Enum.UserInputType.Touch then
			touches[input] = input.Position
			local points = {}
			for _, position in pairs(touches) do table.insert(points, position) end
			if #points >= 2 then
				local distance = (points[1] - points[2]).Magnitude
				if pinchDistance and distance > 5 then self:Zoom(pinchDistance / distance) end
				pinchDistance = distance; dragged = true
			elseif not processed and tapStart then
				local delta = Vector2.new(input.Position.X, input.Position.Y) - Vector2.new(tapPosition.X, tapPosition.Y)
				if (Vector2.new(input.Position.X, input.Position.Y) - Vector2.new(tapStart.X, tapStart.Y)).Magnitude > 9 then dragged = true end
				if dragged then self:Pan(delta) end
				tapPosition = Vector3.new(input.Position.X, input.Position.Y, 0)
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard then keys[input.KeyCode] = nil
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then rightDown = false
		elseif input.UserInputType == Enum.UserInputType.MouseButton3 then middleDown = false
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if input.UserInputType == Enum.UserInputType.Touch then touches[input] = nil; pinchDistance = nil end
			if tapStart and not dragged and os.clock() - tapTime < 0.45 and self.OnTap then
				self.OnTap(Vector2.new(input.Position.X, input.Position.Y))
			end
			tapStart = nil
		end
	end)
	RunService.RenderStepped:Connect(function(dt) self:Update(dt) end)
end

function Camera:Pan(delta)
	local scale = self.Distance / 650
	local right = Vector3.new(math.cos(self.Yaw), 0, -math.sin(self.Yaw))
	local forward = Vector3.new(-math.sin(self.Yaw), 0, -math.cos(self.Yaw))
	self.Center -= right * delta.X * scale + forward * delta.Y * scale
	self:Clamp()
end

function Camera:Zoom(factor)
	self.Distance = math.clamp(self.Distance * factor, 55, 270)
end

function Camera:Clamp()
	self.Center = Vector3.new(math.clamp(self.Center.X, -90, 90), 0, math.clamp(self.Center.Z, -60, 55))
end

function Camera:SetCenter(position)
	self.Center = Vector3.new(position.X, 0, position.Z); self:Clamp()
end

function Camera:Reset()
	self.Center = Config.Map.Center; self.Distance = 188; self.Yaw = 0; self.Pitch = math.rad(59)
end

function Camera:Update(dt)
	if not self.camera then return end
	local movement = Vector2.zero
	if keys[Enum.KeyCode.W] or keys[Enum.KeyCode.Up] then movement += Vector2.new(0, 1) end
	if keys[Enum.KeyCode.S] or keys[Enum.KeyCode.Down] then movement += Vector2.new(0, -1) end
	if keys[Enum.KeyCode.A] or keys[Enum.KeyCode.Left] then movement += Vector2.new(-1, 0) end
	if keys[Enum.KeyCode.D] or keys[Enum.KeyCode.Right] then movement += Vector2.new(1, 0) end
	if movement.Magnitude > 0 then
		local speed = self.Distance * 0.7 * math.min(dt, 0.05)
		local right = Vector3.new(math.cos(self.Yaw), 0, -math.sin(self.Yaw))
		local forward = Vector3.new(-math.sin(self.Yaw), 0, -math.cos(self.Yaw))
		self.Center += (right * movement.X + forward * movement.Y) * speed
		self:Clamp()
	end
	local offset = Vector3.new(math.sin(self.Yaw) * math.cos(self.Pitch), math.sin(self.Pitch), math.cos(self.Yaw) * math.cos(self.Pitch)) * self.Distance
	self.camera.CFrame = CFrame.lookAt(self.Center + offset, self.Center)
end

function Camera:GroundPoint(screenPosition)
	if not self.camera then return nil end
	local ray = self.camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
	if ray.Direction.Y >= -0.001 then return nil end
	local distance = (0.5 - ray.Origin.Y) / ray.Direction.Y
	if distance < 0 then return nil end
	local point = ray.Origin + ray.Direction * distance
	if math.abs(point.X) > 90 or math.abs(point.Z) > 60 then return nil end
	return point
end

return Camera
