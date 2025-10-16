local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local hroot = character:WaitForChild('HumanoidRootPart') :: Part

-- Services
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local jecs = require(ReplicatedStorage.Shared.jecs)

-- Server
local PelletServer = workspace:WaitForChild('PelletServer') :: Script


-- Remote Events
local InitializePellets = PelletServer:WaitForChild('InitializePellets') :: RemoteFunction
local UpdatePellets = PelletServer:WaitForChild('UpdatePellets') :: RemoteEvent

-- Data
local serverData = nil :: ServerData
local Pellet = nil -- Entity Component world declarations
local Position = nil 
local ChunkHash = nil
local Collected = nil

-- Data — Client-specific ECS Components
local ServerEntityID = nil 
-- Later: Component Declarations initialized in SetupServerData()

local IncludePelletFilterParams = nil
-- Later in code: FilteringDescendants initialized in SetupFilterParams()
-- The main folder where all pellets go is workspace.Pellets


-- Data Structure Declarations

--[[ 
	ServerData differences from Client <-> Server
	
	Both have a different 'serverData.world'
	Same ECS system, but is initialized in each script
	
	Different Entity ID's
		A pellet's data on the client / server ECS will have a different Entity ID
		I stored the server pellet's Entity ID onto the ServerData given to the client upon InitializePellets
		Then, I map it to the client' ServerData.pelletPositionLookup
		
]]
export type ServerData = {
	chunkTable: {[string]: ChunkData},
	numChunks: number,
	pelletSpacing: number,
	pelletStartPos: number,
	chunkSize: Vector3,
	region: Part,
	regionOriginPosition: Vector3,
	world: jecs.World,
	
	-- Local Additions
	pelletFolder: Folder,
	pelletPositionLookup: {[string]: {number} }, -- [PositionHash]: {["ClientID"]}
	pelletServerIDLookup: {[number]: string}
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
	ServerEntityID: number, -- Server ID

	-- Client-Sided variables
	PelletInstance: Part, -- Local Diff: To keep track of locally created pellet instances
	ClientEntityID: number, -- Client ID on local ECS system
}


function createFolderForPellets()
	local folder = Instance.new('Folder')
	folder.Name = "PelletsFolder"
	folder.Parent = workspace
	serverData.pelletFolder = folder
	return folder
end

-- ECS System to handle the chunks of pellets, render and update them
function createLocalPellet(newPosition: Vector3, chunkHash: string)
	local pellet = Instance.new('Part')
	pellet.Size = Vector3.new(1, 1, 1)
	pellet.Material = Enum.Material.Neon
	pellet.Anchored = true
	pellet.CanCollide = false
	pellet.Transparency = 0
	pellet.Color = Color3.new(1, 1, 1)
	pellet.Shape = Enum.PartType.Ball
	--pellet.Position = Vector3.new(px, region.Position.Y + 3, pz)
	pellet.Position = newPosition
	pellet.Name = "Pellet"

	local light = Instance.new('PointLight')
	light.Brightness = 2
	light.Color = Color3.new(1, 1, 1)
	light.Range = 10
	light.Parent = pellet

	-- Add to ECS
	local pelletEntityID = serverData.world:entity() -- Returns the number of the entity
	
	serverData.world:set(pelletEntityID, Pellet, true)
	serverData.world:set(pelletEntityID, Position, newPosition)
	serverData.world:set(pelletEntityID, Collected, false)
	serverData.world:set(pelletEntityID, ChunkHash, chunkHash)

	pellet.Parent = serverData.pelletFolder 
	print("createLocalPellet(): pelletEntity id = ", pelletEntityID)
	return pellet, pelletEntityID
end

function generateHash(posx, posz)
	return string.format("%d,%d", posx, posz)
end

function createChunk(chunkHash : string, chunkData : ChunkData)
	-- Spawn Chunk part
	local chunk = Instance.new('Part')
	chunk.Name = "Chunk"
	chunk.Size = serverData.chunkSize
	chunk.Anchored = true
	chunk.CanCollide = false
	chunk.Transparency = 0.8
	chunk.Color = Color3.new(1, 0, 0)

	chunk.Position = chunkData.centerPosition
	chunk.Parent = workspace

	-- Create dictionary for chunk information
	serverData.chunkTable[chunkHash].chunk = chunk
end

function createPelletLookupData(pelletData : PelletData)
	-- Create 2 hashes — Position, ServerEntityID
	local positionHash = tostring(pelletData.Position)
	local serverIDHash = tostring(pelletData.ServerEntityID)
	
	-- Set Position Lookup
	-- 	Used for local, check for collided pellet in own ECS using ClientEntityID
	--	Used from Client —> Server: inform server that pellet has been collected
	serverData.pelletPositionLookup[positionHash] = {}
	serverData.pelletPositionLookup[positionHash][1] = pelletData.ClientEntityID
	serverData.pelletPositionLookup[positionHash][2] = pelletData.ServerEntityID -- Server Entity
	
	-- Set ServerEntityID Lookup
	--	Used from Server —> Client: inform client that pellet has been collected by other player.
	--	Then, checks Position Lookup, local client ECS World to remove pellet
	serverData.pelletServerIDLookup[serverIDHash] = positionHash
	
	print('> Set', positionHash, ' to -> ', serverData.pelletPositionLookup[positionHash])
end

function spawnPelletsForChunk(chunkHash : string, chunkData : ChunkData)
	for i, pelletData : PelletData in ipairs(chunkData.worldData) do -- chunk size X - 1, preveants inclusion of ending
		local pellet, clientEntityID = createLocalPellet(pelletData.Position, chunkHash)
		pelletData.PelletInstance = pellet
		pelletData.ClientEntityID = clientEntityID
		createPelletLookupData(pelletData)
	end
end

function spawnChunksForRegion(region : Part)
	-- Root Origin for region part
	for chunkHash, chunkData in pairs(serverData.chunkTable) do
		createChunk(chunkHash, chunkData)
		spawnPelletsForChunk(chunkHash, chunkData)
		print( string.format("Created chunk [%s] at (%d, %d)", chunkHash, chunkData.ix, chunkData.iz) )
	end
end

-- TODO: Work on Pellet Collision system
--function spawnHitbox()
--	local hitbox = Instance.new('Part')
--	hitbox.Size = Vector3.new(4,5,4)
--	hitbox.Anchored = false
--	hitbox.CanCollide = false
--	hitbox.Color = Color3.fromRGB(150, 0, 255)
--	hitbox.Massless = true
--	hitbox.Transparency = 0.8
--	hitbox.CanTouch = true
	
--	local weld = Instance.new('Weld')
--	weld.C0 = CFrame.new(0, 0, 0)
--	weld.C1 = CFrame.new(0, 0, 0)
--	weld.Part0 = hroot
--	weld.Part1 = hitbox
	
--	hitbox.Parent = workspace
--	weld.Parent = hitbox
--	return hitbox
--end


function pelletDetectionLoop()
	local cache = serverData.world:query(Pellet, Position)
	--RunService.Heartbeat:Connect(function(deltaTime: number)
	while wait(1) do
		local hitPellets = workspace:GetPartBoundsInRadius(hroot.Position, 1, IncludePelletFilterParams)
		if hitPellets then
			for i, item in pairs(hitPellets) do
				print('detected: ', item, item.Position)
				
				-- Check if the PositionHash leads to any valid entity ID's
				local positionHash = tostring(item.Position)
				local clientEntityID = serverData.pelletPositionLookup[positionHash][1]
				if not clientEntityID then continue end
				print('201 positionHash returned: entity ID = ', serverData.pelletPositionLookup[positionHash][1])
				
				-- Check if the Client Entity ID leads to any valid entities
				if not serverData.world:contains(clientEntityID) then continue end
				print('201 entity id found in world:', serverData.world:get(clientEntityID, Position))
				
				-- TODO: Implement UpdatePellets, Client —> Server
				-- TODO: Pass in ServerEntityID to Server
				
				-- TODO (Server): Receive Pellet, Track pellets collected
				-- TODO (Server): Send authoritative Pellet State to all clients
				
				-- TODO (Client): Create Pellet VFX Handler, 
				-- TODO (Client): Program remove Pellet logic, remove from ECS World, PositionLookup, ServerEntityID Lookup
				UpdatePellets:FireServer()
				
				--for id, pellet, pos : Vector3 in cache:iter() do
				--	print('ECS LOOP: comparing ', id, pellet, '|', pos, '|', item.position)
				--	if pos == item.Position then
				--		print('DETECTED PELLET INSIDE ECS!')
				--		serverData.world:remove(id)
				--		game.Debris:AddItem(item, 0)
				--		break
				--	end
				--end
			end
			print('------')
		end
	--end) do
	end
end


function SetupFilterParams()
	-- Must be set after creating folder
	IncludePelletFilterParams = OverlapParams.new()
	IncludePelletFilterParams.FilterType = Enum.RaycastFilterType.Include
	IncludePelletFilterParams.FilterDescendantsInstances = {serverData.pelletFolder}
end

function SetupServerData()
	serverData.world = jecs.world()
	serverData.pelletPositionLookup = {}
	
	-- Initialize ECS Component Declarations 
	Pellet = serverData.world:component() :: Entity<Part>
	Position = serverData.world:component() :: Entity<Vector3>
	ChunkHash = serverData.world:component() :: Entity<string>
	Collected = serverData.world:component() :: Entity<boolean>
	
	-- Client-Sided ECS Components
	ServerEntityID = serverData.world:component() :: Entity<number>
end


-- MAIN 
function init()
	serverData = InitializePellets:InvokeServer() :: ServerData
	print('Local: serverData received = ', serverData)
	SetupServerData()
	createFolderForPellets()
	SetupFilterParams()
	
	spawnChunksForRegion(serverData.region)
	pelletDetectionLoop()
end


init()