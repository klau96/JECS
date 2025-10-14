local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local jecs = require(ReplicatedStorage.Shared.jecs)

local world = jecs.World.new()
type Entity<T = nil> = jecs.Entity<T>

-- Jecs Variables
local Pellet = world:component() :: Entity<Part>
local Position = world:component() :: Entity<Vector3>
local ChunkHash = world:component() :: Entity<string>
local Collected = world:component() :: Entity<boolean>

-- Regular Variables
local region = workspace:FindFirstChild('PelletRegion') :: Part
local regionOriginX = region.Position.X - region.Size.X/2
local regionOriginZ = region.Position.Z - region.Size.Z/2

-- Data Structure Declarations
export type ServerData = {
	chunkTable: {[string]: ChunkData},
	numChunks: number,
	pelletSpacing: number,
	pelletStartPos: number,
	chunkSize: Vector3,
	region: Part,	
	world: jecs.World,
}

export type ChunkData = {
	ix: number,
	iz: number,
	worldData: {PelletData}, -- Serialized version of world, Array of PelletData's
	originPosition: Vector3,
	centerPosition: Vector3,
}

export type PelletData = {
	Position: Vector3,
	Collected: boolean,
	ChunkHash: string,
}

-- Initialize serverData
local serverData = {} :: ServerData
serverData.region = region
serverData.pelletSpacing = 20
serverData.pelletStartPos = 10
serverData.numChunks = 0
serverData.chunkSize = Vector3.new(100, 10, 100)

-- Authoritative Data on server
serverData.chunkTable = {}
serverData.chunkTable.regionOrigin = Vector3.new(regionOriginX, region.Position.Y, regionOriginZ)

-- Remotes
local UpdatePellets = script:WaitForChild('UpdatePellets') :: RemoteEvent


--[[
Create Chunks
Define chunk hash table
Create pellet positions

Player Collision system
	Create check for which chunk a player is in
	Create collision system
	Remove a pellet from world
	Send information to all clients

Create OnRemove function
	Send information to all clients
]]


function generateHash(posx, posz)
	return string.format("%d,%d", posx, posz)
end

function createChunk(region, ix, iz)
	
	-- Create hash key for chunk based on stringified position
	local chunkHash = generateHash(ix, iz)

	local originX = regionOriginX + ix*serverData.chunkSize.X
	local originZ = regionOriginZ + iz*serverData.chunkSize.Z
	local centerX = originX + serverData.chunkSize.X / 2
	local centerZ = originZ + serverData.chunkSize.Z / 2
	local centerYAboveRegion = region.Position.Y + serverData.chunkSize.Y/2

	-- Create ChunkData entry for this chunk's information
	serverData.chunkTable[chunkHash] = {}
	-- Point to the new chunkData entry with reference variable (tables are always reference)
	local chunkData = serverData.chunkTable[chunkHash] :: ChunkData
	chunkData.ix = ix
	chunkData.iz = iz
	chunkData.originPosition = Vector3.new(originX, centerYAboveRegion, originZ)
	chunkData.centerPosition = Vector3.new(centerX, centerYAboveRegion, centerZ)
	
	-- Create JECS World for Chunk
	--serverData.chunkTable[chunkHash].world = jecs.World.new() :: jecs.World
	chunkData.world = jecs.World.new() :: jecs.World
	
	--serverData.chunkTable[chunkHash].ix = ix
	--serverData.chunkTable[chunkHash].iz = iz
	--serverData.chunkTable[chunkHash].originPosition = Vector3.new(originX, centerYAboveRegion, originZ)
	--serverData.chunkTable[chunkHash].centerPosition = Vector3.new(centerX, centerYAboveRegion, centerZ)
	
	-- TODO: Fully flesh out ServerData and ChunkData data strutures, 
	-- TODO: Work on local chunk creation + handling ServerData
	-- TODO: Work on Pellet Collision system
	
	print(string.format("CHUNK HASH: [%s] = %s, (%d, y, %d)", chunkHash, serverData.chunkTable[chunkHash], chunkData.world))
	serverData.numChunks += 1
	
	return chunkHash
end

function addPelletToChunk()
	
end

function spawnPelletsForChunk(chunkHash : string)
	
	local chunkData = serverData[chunkHash] :: ChunkData
	local cx = serverData.chunkSize.X
	local cz = serverData.chunkSize.Z
	
	local originx = chunkData.originPosition.X
	local originz = chunkData.originPosition.Z
	
	-- For loop for pellet positions
	for x = serverData.pelletStartPos, cx-1, serverData.pelletSpacing do -- chunk size X - 1, preveants inclusion of ending
		for z = serverData.pelletStartPos, cz-1, serverData.pelletSpacing do
			local coordx = originx + x
			local coordz = originz + z
			-- Create pellet part locally
			--local pellet = createPellet(region, coordx, coordz)
			
			-- TODO: Add pellet information to the world
			-- Serialized Version of the Pellet
			local newPellet = {} :: PelletData
			newPellet.Position = Vector3.new(coordx, serverData.region.Position.Y + 3, coordz)
			newPellet.ChunkHash = chunkHash
			newPellet.Collected = false
			
			-- Insert into chunkData world
			table.insert(chunkData.worldData, newPellet)
			
			-- JECS Version of the pellet in world
			local pelletEntity = world:entity()
			world:set(pelletEntity, Position, newPellet.Position)
			world:set(pelletEntity, Collected, false)
			world:set(pelletEntity, ChunkHash, chunkHash)
		end
	end
end

-- TODO: Spawn chunks with consideration to region position offset
function spawnChunksForRegion(region : Part)
	-- Root Origin for region part
	local numChunksX = math.ceil(region.Size.X / serverData.chunkSize.X)
	local numChunksZ = math.ceil(region.Size.Z / serverData.chunkSize.Z)

	for ix = 0, numChunksX - 1 do
		for iz = 0, numChunksZ - 1 do
			--local cornerx = regionOriginX + x
			--local cornerz = regionOriginZ + z
			local chunkHash = createChunk(region, ix, iz)
			spawnPelletsForChunk(chunkHash)
			print( string.format("Created chunk [%s] at (%d, %d)", chunkHash, ix, iz) )
		end
	end
end