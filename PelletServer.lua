local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
repeat wait() until ReplicatedStorage.Shared:FindFirstChild('jecs')
local jecs = require(ReplicatedStorage.Shared.jecs)

-- Remotes
local InitializePellets = script:WaitForChild('InitializePellets') :: RemoteFunction
local UpdatePellets = script:WaitForChild('UpdatePellets') :: RemoteEvent

-- Regular Variables
local region = workspace:FindFirstChild('PelletRegion') :: Part
local regionOriginX = region.Position.X - region.Size.X/2
local regionOriginZ = region.Position.Z - region.Size.Z/2

regionOriginX = tonumber(string.format("%.1f", regionOriginX))
regionOriginZ = tonumber(string.format("%.1f", regionOriginZ))


-- Data Structure Declarations
--[[ 
	Description:
		Stores authoritative data
		Stores the Server's jecs.world()
]]
export type AuthoritativeData = {
	world: jecs.World,
}

export type ServerData = {
	chunkTable: {[string]: ChunkData},
	numChunks: number,
	pelletSpacing: number,
	pelletStartPos: number,
	chunkSize: Vector3,
	region: Part,
	regionOriginPosition: Vector3,
	--world: jecs.World, 	-- Removed, cannot send this through remotes
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
	ServerEntityID: number,
	
	-- Server use only
	CollectedBy: Player,
}

-- Initialize ServerData
local serverData = {} :: ServerData
serverData.region = region
serverData.pelletSpacing = 25
serverData.pelletStartPos = serverData.pelletSpacing/2
serverData.numChunks = 0
serverData.chunkSize = Vector3.new(100, 10, 100)

serverData.chunkTable = {}
serverData.regionOriginPosition = Vector3.new(regionOriginX, region.Position.Y, regionOriginZ)

-- Jecs
type Entity<T = nil> = jecs.Entity<T>

-- Initialize AuthoritativeData
local authData = {} :: AuthoritativeData
authData.world = jecs.world()

-- Initialize Jecs Components to the World
local Pellet = authData.world:component() :: Entity<Part>
local Position = authData.world:component() :: Entity<Vector3>
local ChunkHash = authData.world:component() :: Entity<string>
local Collected = authData.world:component() :: Entity<boolean>


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

--[[
	Parameters: region, ix, iz
	
	Description: 
		Given a region, chunk indexes
		Calculate the information of the chunk
		Store into ChunkData structure
		
		Create an array 'worldData'
		Each chunk will hold an array of PelletData structures
]]
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
	-- Create worldData array, holds all PelletData structures for this current chunk
	chunkData.worldData = {}
	
	return chunkHash
end


--[[
	Parameters:
		chunkHash : The indexes hashed specifically for the chunk
		
	Description:
	
]]
function spawnPelletsForChunk(chunkHash : string)
	
	local chunkData = serverData.chunkTable[chunkHash] :: ChunkData
	local cx = serverData.chunkSize.X
	local cz = serverData.chunkSize.Z
	
	local originx = chunkData.originPosition.X
	local originz = chunkData.originPosition.Z
	
	-- For loop for pellet positions
	for x = serverData.pelletStartPos, cx-1, serverData.pelletSpacing do -- chunk size X - 1, preveants inclusion of ending
		for z = serverData.pelletStartPos, cz-1, serverData.pelletSpacing do
			local coordx = originx + x
			local coordz = originz + z
			
			-- Serialized Version of the Pellet
			local newPellet = {} :: PelletData
			newPellet.Position = Vector3.new(coordx, serverData.region.Position.Y + 3.5, coordz)
			newPellet.ChunkHash = chunkHash
			newPellet.Collected = false
			
			
			-- Create an Entity inside the global ECS world
			local pelletEntityID = authData.world:entity()
			authData.world:set(pelletEntityID, Position, newPellet.Position)
			authData.world:set(pelletEntityID, Collected, false)
			authData.world:set(pelletEntityID, ChunkHash, chunkHash)
			
			-- Add Server Pellet's EntityID to send to Client
			newPellet.ServerEntityID = pelletEntityID

			-- Insert into chunkData world
			table.insert(chunkData.worldData, newPellet)
		end
	end
end


function spawnChunksForRegion(region : Part)
	-- Root Origin for region part
	local numChunksX = math.ceil(region.Size.X / serverData.chunkSize.X)
	local numChunksZ = math.ceil(region.Size.Z / serverData.chunkSize.Z)

	for ix = 0, numChunksX - 1 do
		for iz = 0, numChunksZ - 1 do
			local chunkHash = createChunk(region, ix, iz)
			spawnPelletsForChunk(chunkHash)
			--print( string.format("Created chunk [%s] at (%d, %d)", chunkHash, ix, iz) )
		end
	end
end

spawnChunksForRegion(serverData.region)


InitializePellets.OnServerInvoke = function(player: Player)
	return serverData
end

UpdatePellets.OnServerEvent:Connect(function(player: Player, ServerEntityID: number)
	print('[Pellet] Server — UpdatePellets() — Player ', player.Name, ' collected Pellet.ServerEntityID = ', ServerEntityID)
	local pelletPosition = authData.world:get(ServerEntityID, Position)
	--print('Server — UpdatePellets() — Pellet\'s Position:', pelletPosition)
	-- TODO: Remove Pellet
end)