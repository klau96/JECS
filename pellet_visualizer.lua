local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local jecs = require(ReplicatedStorage.jecs)

local region = workspace:FindFirstChild('PelletRegion') :: Part
local chunkSize = Vector3.new(100, 10, 100)
local pelletSpacing = 10
local pelletStartPos = 5
local chunkTable = {}
local numChunks = 0

-- Testing for player-chunk bounding check
local spotlightChunk = nil -- Used to highlight a specific chunk for 1 player
local PingChunkRemote = script:WaitForChild('PingChunk') :: RemoteEvent

-- Pellet Collision
local PelletCollision = script:WaitForChild('PelletCollision') :: RemoteEvent
local collisionLoop = nil

-- Player Pellet Collections and Jecs
type Entity<T = nil> = jecs.Entity<T>


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
	local pelletPosition = pellet.Position
	return pellet, pelletPosition
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
	local chunkHash = string.format("%d%d", chunk.Position.X, chunk.Position.Z)
	
	-- Create dictionary for chunk information
	chunkTable[chunkHash] = {chunk=chunk}
	
	-- Create JECS World for Chunk
	chunkTable[chunkHash].world = jecs.World.new() :: jecs.World
	
	-- TODO: Create components for the Chunk
	-- Remember that each chunk has it's own component table
	-- Since global component declaration is not possible in JECS
	chunkTable[chunkHash].components = {}
	chunkTable[chunkHash].components.Position = chunkTable[chunkHash].world:component() :: Entity<Vector3>
	
	print(string.format("%s = {%s}", chunkHash, chunkTable[chunkHash].chunk.Name))
	return chunk, chunkHash
end

function spawnPelletsForChunk(chunk : Part, chunkHash : string)
	local cx = chunkSize.X
	local cz = chunkSize.Z
	local world = chunkTable[chunkHash].world
	local components = chunkTable[chunkHash].components
	local Position = components.Position
	for x = pelletStartPos, cx-1, pelletSpacing do -- chunk size X - 1, preveants inclusion of ending
		for z = pelletStartPos, cz-1, pelletSpacing do
			local coordx = chunk.Position.X - cx/2 + x
			local coordz = chunk.Position.Z - cz/2 + z
			local pellet, pelletPosition = createPellet(region, coordx, coordz)
			
			-- TODO: Created entity, now check entity position in collision loop
			local entity = world:entity()
			world:set(entity, Position, pelletPosition)
			print('created', entity, 'in chunk: ', chunkHash)
		end
	end
end

function spawnChunksForRegion(region : Part)
	for x = 0, region.Size.X-1, chunkSize.X do
		for z = 0, region.Size.Z-1, chunkSize.Z do
			local coordx = x + chunkSize.X/2 - region.Size.X/2
			local coordz = z + chunkSize.Z/2 - region.Size.Z/2
			local chunk, chunkHash = createChunk(region, coordx, coordz)
			spawnPelletsForChunk(chunk, chunkHash)
			--print( string.format("Created chunk at (%d, %d) -> x, z = (%d, %d)", coordx, coordz, x, z) )
		end
	end
end

local PingChunkCallback = nil

function CreatePingChunkCallback()
	if PingChunkCallback ~= nil then
		PingChunkCallback:Disconnect()
		PingChunkCallback = nil
	end 
	
	task.wait()
	
	PingChunkCallback = PingChunkRemote.OnServerEvent:Connect(function(player: Player, hash)
		--local hash = string.format("%d%d", posx, posz)
		if chunkTable[hash] and chunkTable[hash].chunk ~= spotlightChunk then
			-- Reset previous spotlightChunk
			spotlightChunk.Color = Color3.new(1, 0, 0)

			-- Highlight new chunk
			spotlightChunk = chunkTable[hash].chunk
			spotlightChunk.Color = Color3.new(0, 1, 0)
		end
	end)
end

--[[
Function: GetChunkHash()
	Given a humanoid root part, using it's position
	Return the hash according to the chunk sizes
]]
function GetChunkHash(hr)
	local ox = hr.Position.X - hr.Position.X%100 + chunkSize.X/2 
	local oz = hr.Position.Z - hr.Position.Z%100 + chunkSize.Z/2
	local hash = string.format("%d%d", ox, oz)
	if chunkTable[hash] ~= nil then
		return hash
	end
	return nil
end

function checkChunkCollisions(chunkHash, hr)
	local world = chunkTable[chunkHash].world
	local Position = chunkTable[chunkHash].components.Position
	local hrPos = hr.Position
	for id, pos: Vector3 in world:query(Position) do
		local dist = (pos - hrPos).Magnitude
		print(string.format("check: [%s] id=%d, dist=%d -> (%d, %d, %d)", chunkHash, id, dist, pos.X, pos.Y, pos.Z))
	end
end

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
			
			-- Find the chunk that player is in
			local chunkHash = GetChunkHash(hr)
			if chunkHash == nil then continue end
			
			checkChunkCollisions(chunkHash, hr)
			print(string.format("hash collision loop: %s -> '%s'", player.Name, hash))
			
			
		end
	end)
end

function init()
	-- Spawn parts for visualizing chunks & pellets
	spawnChunksForRegion(region)

	-- Intitialize spotlightChunk
	spotlightChunk = chunkTable["5050"].chunk
	
	-- Create remote callback for PingChunk remote event
	CreatePingChunkCallback()
	
	CreateHeartbeatCollisionLoop()
end

init()