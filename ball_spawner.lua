--[[
	JECS Example by maeriil
	
	Throwing balls in the air
]]

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local jecs = require(ReplicatedStorage.jecs)		

type Entity<T = nil> = jecs.Entity<T>
local world = jecs.World.new()

local Part = world:component() :: Entity<Part>
local Velocity = world:component() :: Entity<Velocity>
local Timestamp = world:component() :: Entity<number>

local Players = game:GetService('Players')

repeat wait() print('waiting for player ininja966') until Players:WaitForChild('ininja966')

local TargetPlayer = Players.ininja966 :: Player
local Character = TargetPlayer.Character or TargetPlayer.CharacterAdded:Wait()

local hroot = Character:FindFirstChild('HumanoidRootPart') :: Part

local function r(a, b)
	return math.random(a, b)
end


local spawn_ball do
	local interval_time = 0.5
	local prev_time = os.clock()

	function spawn_ball()
		-- Stop loop if interval time not passed
		local curr_time = os.clock()
		if curr_time - prev_time <= interval_time then
			return
		end

		-- Container for this specific ball part
		local e = world:entity()

		local ball = Instance.new('Part')
		ball.Shape = Enum.PartType.Ball
		ball.Color = Color3.fromRGB(r(0, 255), r(0, 255), r(0, 255))
		ball.Position = vector.create(r(-20, 20), 1, r(-20, 20))
		ball.Parent = workspace

		world:set(e, Part, ball) -- entity container, component, instance Part
		world:set(e, Velocity, vector.create(0, 20, 0))
		world:set(e, Timestamp, os.clock())
		prev_time = curr_time
	end
end


local apply_force do
	local interval_time = 0.5
	function apply_force()
		-- Query all ball parts with velocity
		for id, part, velocity, prev_time in world:query(Part, Velocity, Timestamp):iter() do
			local curr_time = os.clock()
			if curr_time - prev_time <= interval_time then
				continue
			end

			print('before: ', velocity)
			local lookAt = CFrame.new(part.Position, hroot.Position).LookVector
			local dist = (part.Position - hroot.Position).Magnitude
			local resultVector = lookAt*(dist/10)
			print('TYPE CHECK:', lookAt, type(lookAt), resultVector, type(resultVector))
			world:set(id, Velocity, resultVector)
			print('after: ', velocity)

			part:ApplyImpulse(velocity)
			world:set(id, Timestamp, curr_time)
		end
	end
end


local ballHeartbeat = RunService.Heartbeat:Connect(function(deltaTime: number)
	--print("JECS_BallThrowing : spawned ball", #world:query(Part, Velocity))
	spawn_ball()
end)

RunService.Stepped:Connect(function(deltaTime: number)
	apply_force() -- Run in steppd because physics
end)