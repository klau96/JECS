print("modulo result -50%100 = ", -50%100)
print("modulo result -50%100 = ", 50%100)


local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local jecs = require(ReplicatedStorage.jecs)

local region = workspace:FindFirstChild('PelletRegion') :: Part
local chunkSize = Vector3.new(100, 10, 100)
local pelletSpacing = 20
local pelletStartPos = 10
local chunkTable = {}
local numChunks = 0

-- Testing for player-chunk bounding check
local spotlightChunk = nil -- Used to highlight a specific chunk for 1 player
local PingChunkRemote = script:WaitForChild('PingChunk') :: RemoteEvent

-- Pellet Collision
local PelletCollision = script:WaitForChild('PelletCollision') :: RemoteEvent
local collisionLoop = nil

-- Player Pellet Collections


function createPellet(region, px, pz)
	local pellet = Instance.new('Part')
	pellet.Size = Vector3.new(1, 1, 1)
	pellet.Material = Enum.Material.Neon
	pellet.Anchored = true
	pellet.CanCollide = false
	pellet.Transparency = 0
	pellet.Color = Color3.new(1, 1, 1)
	pellet.Shape = Enum.PartType.Ball
	pellet.Position = Vector3.new(px, region.Position.Y + 3, pz)

	local light = Instance.new('PointLight')
	light.Brightness = 2
	light.Color = Color3.new(1, 1,1)
	light.Range = 10
	light.Parent = pellet

	pellet.Parent = workspace
	return pellet
end

function generateHash(posx, posz)
	return string.format("%d,%d", posx, posz)
end

function createChunk(region, px, pz)
	numChunks += 1

	local chunk = Instance.new('Part')
	chunk.Name = "Chunk"
	chunk.Size = chunkSize
	chunk.Anchored = true
	chunk.CanCollide = false
	chunk.Transparency = 0.8
	chunk.Color = Color3.new(1, 0, 0)
	chunk.Position = Vector3.new(px, region.Position.Y + chunkSize.Y/2, pz)
	chunk.Parent = workspace
	print(string.format("Chunk %d position: (%d, %d)", numChunks, chunk.Position.X, chunk.Position.Z))

	-- Create hash key for chunk based on stringified position
	local chunkHash = generateHash(chunk.Position.X, chunk.Position.Z)

	-- Create dictionary for chunk information
	chunkTable[chunkHash] = {chunk=chunk}

	-- Create JECS World for Chunk
	chunkTable[chunkHash].world = jecs.World.new() :: jecs.World

	print(string.format("%s = {%s}", chunkHash, chunkTable[chunkHash].chunk.Name))
	return chunk, chunkHash
end

function spawnPelletsForChunk(chunk : Part)
	local cx = chunkSize.X
	local cz = chunkSize.Z
	for x = pelletStartPos, cx-1, pelletSpacing do -- chunk size X - 1, preveants inclusion of ending
		for z = pelletStartPos, cz-1, pelletSpacing do
			local coordx = chunk.Position.X - cx/2 + x
			local coordz = chunk.Position.Z - cz/2 + z
			local pellet = createPellet(region, coordx, coordz)
		end
	end
end

-- TODO: Spawn chunks with consideration to region position offset
function spawnChunksForRegion(region : Part)
	for x = 0, region.Size.X-1, chunkSize.X do
		for z = 0, region.Size.Z-1, chunkSize.Z do
			local coordx = x + chunkSize.X/2 - region.Size.X/2
			local coordz = z + chunkSize.Z/2 - region.Size.Z/2
			local chunk, chunkHash = createChunk(region, coordx, coordz)
			spawnPelletsForChunk(chunk)
			print( string.format("Created chunk [%s] at (%d, %d) -> x, z = (%d, %d)", chunkHash, coordx, coordz, x, z) )
		end
	end
end

local PingChunkCallback = nil

function checkSpotlightChunk(hash)
	if chunkTable[hash] and chunkTable[hash].chunk ~= spotlightChunk then
		-- Reset previous spotlightChunk
		spotlightChunk.Color = Color3.new(1, 0, 0)

		-- Highlight new chunk
		spotlightChunk = chunkTable[hash].chunk
		spotlightChunk.Color = Color3.new(0, 1, 0)
	end
end

function CreatePingChunkCallback()
	if PingChunkCallback ~= nil then
		PingChunkCallback:Disconnect()
		PingChunkCallback = nil
	end 

	task.wait()

	PingChunkCallback = PingChunkRemote.OnServerEvent:Connect(function(player: Player, hash)
		checkSpotlightChunk(hash)
	end)
end

--[[
Function: GetChunkHash()
	Given a humanoid root part, using it's position
	Return the hash according to the chunk sizes
]]

local xoffset = (region.Size.X/2)%chunkSize.X
local zoffset = (region.Size.Z/2)%chunkSize.Z

print("x and z offset calc:", xoffset, zoffset)

function GetChunkHash(hr)
	local hx = hr.Position.X+xoffset
	local hz = hr.Position.Z+zoffset
	local ox = (hx - hx%(100) + chunkSize.X/2)-xoffset
	local oz = (hz - hz%(100) + chunkSize.Z/2)-zoffset
	local hash = generateHash(ox, oz)
	print(string.format('char pos: (%d, %d) hash: [%s]', hr.Position.X-hr.Position.X%10, hr.Position.Z-hr.Position.Z%10, hash))
	return hash
end

-- TODO: Fix the method for retrieving collisions, use Octree (?) or quad-trees
function CreateHeartbeatCollisionLoop()
	-- Delete existing loop
	if collisionLoop then
		collisionLoop:Disconnect()
	end

	-- Heartbeat loop through all players
	collisionLoop = RunService.Heartbeat:Connect(function(deltaTime: number)
		-- Get Players
		for i, player in Players:GetPlayers() do
			-- Character check
			local character = player.Character 
			if not character then break end

			-- Humanoid Root Part Check
			local hr = character:FindFirstChild('HumanoidRootPart')
			if not hr then break end

			local hash = GetChunkHash(hr)
			checkSpotlightChunk(hash)
		end
	end)
end

function init()
	-- Spawn parts for visualizing chunks & pellets
	spawnChunksForRegion(region)

	-- Intitialize spotlightChunk
	for key, value in pairs(chunkTable) do
		spotlightChunk = chunkTable[key].chunk
		break
	end
	

	-- Create remote callback for PingChunk remote event
	--CreatePingChunkCallback()

	CreateHeartbeatCollisionLoop() 
end

init()