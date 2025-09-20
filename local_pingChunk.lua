
-- TODO: Testing Character, can delete later
local RunService = game:GetService('RunService')


local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hum = char:WaitForChild('Humanoid') :: Humanoid
local hr = char:WaitForChild('HumanoidRootPart') :: Part

-- Chunk and Pellet information
local chunkSize = Vector3.new(100, 10, 100)
local pelletSpacing = 10
local chunkTable = {}
local numChunks = 0

-- Variables
local currentChunk = "5050"

-- Server
local PelletVisualizer = workspace:WaitForChild('PelletVisualizer')
local PingChunk = PelletVisualizer:WaitForChild('PingChunk')

-- Loop
local heartbeatLoop = RunService.Heartbeat:Connect(function(deltaTime: number)
	local ox = hr.Position.X - hr.Position.X%100 + chunkSize.X/2 
	local oz = hr.Position.Z - hr.Position.Z%100 + chunkSize.Z/2
	local hash = string.format("%d%d", ox, oz)	
	
	if hash ~= currentChunk then
		print(string.format("Local — PingChunk:FireServer(%s)", hash))
		currentChunk = hash
		PingChunk:FireServer(hash)
	end
end)

-- Humanoid Died — Disconnect Heartbeat
hum.Died:Connect(function()
	heartbeatLoop:Disconnect()
end)


-- 