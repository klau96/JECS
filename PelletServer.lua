-- Services
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local Players = game:GetService('Players')

-- Modules
local jecs = require(ReplicatedStorage.Shared:WaitForChild('jecs'))
type Entity<T = nil> = jecs.Entity<T>

-- Remotes

export type RemotesTable = {
	InitializePellets: RemoteFunction,
	UpdatePellet: RemoteEvent,
}


-- Data Structure Declarations
--[[ 
	Description:
		Stores authoritative data
		Stores the Server's jecs.world()
]]
export type AuthoritativeData = {
	-- Jecs World
	world: jecs.World,

	-- Jecs Components
	Pellet: Entity<Part>,
	Position: Entity<Vector3>,
	ChunkHash: Entity<string>,
	Collected: Entity<boolean>,
	
	-- Lookup Table — Mapping EntityID -> PelletData
	PelletEntityIDLookup: {
		[number]: PelletData
	}
}

export type ServerData = {
	chunkTable: {[string]: ChunkData},
	numChunks: number,
	pelletSpacing: number,
	pelletStartPos: number?,
	chunkSize: Vector3,
	region: Part,
	regionOriginX: Vector3,
	regionOriginZ: Vector3,
	regionOriginPosition: Vector3,
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

-- Types — For Communicating to other Server scripts
export type GameServerTable = {
	GameServer: Script,
	GetPlayerScore: BindableFunction?,
	UpdateScore: BindableEvent?,
}

export type RemotesTable = {
	InitialPellets: RemoteFunction,
	UpdatePellet: RemoteEvent,
}


-- Variables
local Remotes: RemotesTable = {
	InitializePellets = script:WaitForChild('InitializePellets') :: RemoteFunction,
	UpdatePellet = script:WaitForChild('UpdatePellet') :: RemoteEvent,
}

local authData = nil :: AuthoritativeData?
local serverData: ServerData = {
	region = nil,
	pelletSpacing = 25,
	pelletStartPos = nil,
	numChunks = 0,
	chunkSize = Vector3.new(100, 10, 100),
	chunkTable = {},
	regionOriginPostion = nil
}


local GameServerInstance = workspace:WaitForChild('GameServer')
local GameServerTable = {
	GameServer = GameServerInstance,
	GetPlayerScore = GameServerInstance:WaitForChild('GetPlayerScore') :: BindableFunction,
	UpdateScore = GameServerInstance:WaitForChild('UpdateScore') :: BindableEvent,
}

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

function InitializeAuthData()
	authData = {} :: AuthoritativeData
	authData.world = jecs.world()
	
	-- Initialize Jecs Components to the World
	authData.Pellet = authData.world:component() :: Entity<Part>
	authData.Position = authData.world:component() :: Entity<Vector3>
	authData.ChunkHash = authData.world:component() :: Entity<string>
	authData.Collected = authData.world:component() :: Entity<boolean>
	
	authData.PelletEntityIDLookup = {}
end

function CleanUpAuthData()
	for id in authData.world:entities():iter() do
		authData.world:remove(id)
	end
end

function InitializeServerData(region: Part)
	-- Region variables
	local regionOriginX = region.Position.X - region.Size.X/2
	local regionOriginZ = region.Position.Z - region.Size.Z/2

	serverData.regionOriginX = tonumber(string.format("%.1f", regionOriginX))
	serverData.regionOriginZ = tonumber(string.format("%.1f", regionOriginZ))
	
	serverData.region = region
	serverData.regionOriginPosition = Vector3.new(regionOriginX, serverData.region.Position.Y, regionOriginZ)
	
	-- Pellet Starting Offset
	serverData.pelletStartPos = serverData.pelletSpacing/2
	serverData.chunkTable = {}
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

	local originX = serverData.regionOriginX + ix*serverData.chunkSize.X
	local originZ = serverData.regionOriginZ + iz*serverData.chunkSize.Z
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
			--print('spawnPelletsForChunk(): ', pelletEntityID, "\nserverData=\n", serverData, "\nnewPellet =\n", newPellet)
			
			authData.world:set(pelletEntityID, authData.Position, newPellet.Position)
			authData.world:set(pelletEntityID, authData.Collected, false)
			authData.world:set(pelletEntityID, authData.ChunkHash, chunkHash)
			
			-- Add Server Pellet's EntityID to send to Client
			newPellet.ServerEntityID = pelletEntityID
			
			-- Add Entity ID to Server-Sided Lookup Table
			authData.PelletEntityIDLookup[newPellet.ServerEntityID] = newPellet

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

-- Pellet Functions
function CheckPelletValidity(ServerEntityID: number, character: Model)
	if not character or not character:FindFirstChild('HumanoidRootPart') then return false end
	local HumanoidRootPart = character.HumanoidRootPart :: Part
	
	local pelletPosition = authData.world:get(ServerEntityID, authData.Position)
	local pelletCollected = authData.world:get(ServerEntityID, authData.Collected)
	
	-- Pellet Radius check
	print('[PelletServer] Check Pellet Validity —> ', (pelletPosition - HumanoidRootPart.Position).Magnitude, pelletCollected)
	--if (pelletPosition - HumanoidRootPart.Position).Magnitude > 10 then return false end
	
	-- Pellet Collected Check
	return pelletCollected == false
end

function UpdateCollectedPellet_AuthData(ServerEntityID: number, player: Player)
	-- Set Collected in JECS World
	authData.world:set(ServerEntityID, authData.Collected, true)
	
	-- Set Collected in PelletData
	local pelletData = authData.PelletEntityIDLookup[ServerEntityID]
	pelletData.Collected = true
	pelletData.CollectedBy = player.Name
	
	print('[PelletServer] Firing All Clients...')
	-- Fire All Clients, Remove Pellet —> In PelletHandler
	Remotes.UpdatePellet:FireAllClients(ServerEntityID)
end

InitializeAuthData()
InitializeServerData(workspace:FindFirstChild('PelletRegion') :: Part)
spawnChunksForRegion(serverData.region)


print('Server: InitializePellets.OnServerInvoke() created.')
Remotes.InitializePellets.OnServerInvoke = function(player: Player)
	return serverData
end

Remotes.UpdatePellet.OnServerEvent:Connect(function(player: Player, ServerEntityID: number)
	print('[PelletServer] Server — UpdatePellet() — Player ', player.Name, ' collected Pellet.ServerEntityID = ', ServerEntityID)
	
	-- Validate Pellet's Position / Collected
	local pelletIsValid = CheckPelletValidity(ServerEntityID, player.Character)
	print('[PelletServer] Pellet Is Valid = ', pelletIsValid)
	if not pelletIsValid then return end
	
	
	GameServerTable.UpdateScore:Fire(player, ServerEntityID)
	print('[PelletServer] SCORE UPDATE:', player, GameServerTable.GetPlayerScore:Invoke(player) )
	
	UpdateCollectedPellet_AuthData(ServerEntityID, player)
end)