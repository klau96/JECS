local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local jecs = require(ReplicatedStorage.jecs)

local region = workspace:FindFirstChild('PelletRegion') :: Part
local regionOriginX = region.Position.X - region.Size.X/2
local regionOriginZ = region.Position.Z - region.Size.Z/2

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

function createChunk(region, ix, iz)
	numChunks += 1

	local chunk = Instance.new('Part')
	chunk.Name = "Chunk"
	chunk.Size = chunkSize
	chunk.Anchored = true
	chunk.CanCollide = false
	chunk.Transparency = 0.8
	chunk.Color = Color3.new(1, 0, 0)
	
	local originX = regionOriginX + ix*chunkSize.X
	local originZ = regionOriginZ + iz*chunkSize.Z
	local centerX = originX + chunkSize.X / 2
	local centerZ = originZ + chunkSize.Z / 2
	local centerYAboveRegion = region.Position.Y + chunkSize.Y/2
	
	chunk.Position = Vector3.new(centerX, centerYAboveRegion, centerZ)
	chunk.Parent = workspace
	--print(string.format("Chunk %d position: (%d, %d)", numChunks, chunk.Position.X, chunk.Position.Z))

	-- Create hash key for chunk based on stringified position
	local chunkHash = generateHash(ix, iz)

	-- Create dictionary for chunk information
	chunkTable[chunkHash] = {chunk=chunk}

	-- Create JECS World for Chunk
	chunkTable[chunkHash].world = jecs.World.new() :: jecs.World

	print(string.format("CHUNK HASH: [%s] = %s, (%d, y, %d)", chunkHash, chunkTable[chunkHash].chunk.Name, chunk.Position.X, chunk.Position.Z))
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
	-- Root Origin for region part
	--local regionOriginX = region.Position.X - region.Size.X/2
	--local regionOriginZ = region.Position.Z - region.Size.Z/2
	local numChunksX = math.ceil(region.Size.X / chunkSize.X)
	local numChunksZ = math.ceil(region.Size.Z / chunkSize.Z)
	
	for ix = 0, numChunksX - 1 do
		for iz = 0, numChunksZ - 1 do
			--local cornerx = regionOriginX + x
			--local cornerz = regionOriginZ + z
			local chunk, chunkHash = createChunk(region, ix, iz)
			spawnPelletsForChunk(chunk)
			print( string.format("Created chunk [%s] at (%d, %d)", chunkHash, ix, iz) )
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


-- Uses: regionOriginX, regionOriginZ
function GetChunkHash(hr)
	local hx = hr.Position.X
	local hz = hr.Position.Z
	local localx = hx - regionOriginX
	local localz = hz - regionOriginZ
	
	-- chunk indices (floor works correctly for negative world coords because we already used region-relative origin)
	local ix = math.floor(localx / chunkSize.X)
	local iz = math.floor(localz / chunkSize.Z)
	
	local hash = generateHash(ix, iz)
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


-- Chunk Clicker Code

function createHighlight(target: Part)
	local highlight = Instance.new('Highlight')
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.new(0, 0, 1)
	highlight.OutlineTransparency = 0
	highlight.Adornee = target
	game.Debris:AddItem(highlight, 2)
	
	return highlight
end
local ClickChunk = script:WaitForChild('ClickChunk') :: RemoteEvent
ClickChunk.OnServerEvent:Connect(function(player: Player, targetChunk: Part)
	if table.find(chunkTable, targetChunk) then return false end
end)


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