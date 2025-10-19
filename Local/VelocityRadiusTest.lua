local RunService = game:GetService('RunService')

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild('Humanoid') :: Humanoid
local hroot = character:WaitForChild('HumanoidRootPart') :: BasePart

function createVelocityLaser()
	local part = Instance.new('Part')
	part.Material = Enum.Material.ForceField
	part.Size = Vector3.new(0.25, 0.25, 4)
	--part.Transparency = 0.8
	part.CanCollide = false
	part.Anchored = true
	part.Massless = true
	part.Color = Color3.new(1, 0, 0)
	part.Name = "Laser"
	part.Parent = workspace
	return part
end

function createCylinder()
	local part = Instance.new('Part')
	part.Material = Enum.Material.ForceField
	part.Size = Vector3.new(8, 12, 12)
	part.Shape = Enum.PartType.Cylinder
	--part.Transparency = 0.8
	part.CanCollide = false
	part.Anchored = true
	part.Massless = true
	part.Color = Color3.new(1, 0, 0)
	part.Name = "Laser"
	part.CFrame = part.CFrame * CFrame.Angles(0, math.pi, 0)
	part.Parent = workspace
	return part
end

local laser = createVelocityLaser() :: BasePart
local cylinder = createCylinder() :: BasePart

function setLaserPosition()
	local velocity = hroot.AssemblyLinearVelocity
	local magnitude = velocity.Magnitude/6
	local direction = velocity.Unit
	laser.Size = Vector3.new(.25, .25, magnitude)
	local laserPosition = hroot.Position + direction * magnitude/2
	laser.CFrame = CFrame.new(laserPosition, laserPosition + direction)
	
	setCylinderPosition(hroot.Position, direction, magnitude)
end

function setCylinderPosition(position, direction, magnitude)
	local endPosition = position + direction*magnitude 
	--local endPosition = position -- for static on-character position
	cylinder.CFrame = CFrame.new(endPosition) * CFrame.Angles(0, 0, math.rad(90))
end



--RunService.Heartbeat:Connect(function(deltaTime: number)
--	setLaserPosition()
--end)