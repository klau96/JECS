-- Services
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')
local jecs = require(ReplicatedStorage.Shared.jecs)

-- Local
local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local hroot = character:WaitForChild('HumanoidRootPart') :: Part

-- Modules
local SoundModule = require(ReplicatedStorage.Modules:WaitForChild('Sound'))

-- Server
local PelletServer = workspace:FindFirstChild('PelletServer') :: Script


-- Remote Events
export type RemotesTable = {
	InitializePellets: RemoteFunction,
	UpdatePellet: RemoteEvent,
}

local Remotes: RemotesTable = {
	InitializePellets = PelletServer:FindFirstChild('InitializePellets') :: RemoteFunction,
	UpdatePellet = PelletServer:FindFirstChild('UpdatePellet') :: RemoteEvent,
}

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
	pelletPositionLookup: {[string]: PelletData}, -- [PositionHash]: PelletData
	pelletServerIDLookup: {[number]: PelletData},
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
	light.Brightness = .5
	light.Color = Color3.new(1, 1, 1)
	light.Range = 12
	light.Parent = pellet

	-- Add new pellet to Client World ECS
	local clientEntityID = serverData.world:entity() -- Returns the number of the entity
	
	serverData.world:set(clientEntityID, Pellet, true)
	serverData.world:set(clientEntityID, Position, newPosition)
	serverData.world:set(clientEntityID, Collected, false)
	serverData.world:set(clientEntityID, ChunkHash, chunkHash)

	pellet.Parent = serverData.pelletFolder 
	return pellet, clientEntityID
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
	chunk.Transparency = 0.98
	chunk.Color = Color3.new(0, 0.34844, 1)

	chunk.Position = chunkData.centerPosition
	chunk.Parent = workspace

	-- Create dictionary for chunk information
	serverData.chunkTable[chunkHash].chunk = chunk
end

function createPelletLookupData(pelletData : PelletData)
	-- Create 2 hashes — Position, ServerEntityID
	local positionHash = tostring(pelletData.Position)
	local serverIDHash = pelletData.ServerEntityID
	
	-- Set Position Lookup
	-- 	Used for local, check for collided pellet in own ECS using ClientEntityID
	--	Used from Client —> Server: inform server that pellet has been collected
	serverData.pelletPositionLookup[positionHash] = pelletData
	
	-- Set ServerEntityID Lookup
	--	Used from Server —> Client: inform client that pellet has been collected by other player.
	--	Then, checks Position Lookup, local client ECS World to remove pellet
	serverData.pelletServerIDLookup[serverIDHash] = pelletData
	
	--print('> Set', positionHash, ' to -> ', serverData.pelletPositionLookup[positionHash])
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
		--print( string.format("Created chunk [%s] at (%d, %d)", chunkHash, chunkData.ix, chunkData.iz) )
		task.wait()
	end
end

-- TODO: Work on Pellet Collision system

--[[ 
	Parameters: 
		
]]

local testSparkle = ReplicatedStorage.Assets.TEMPORARY:WaitForChild('TestSparkle') :: ParticleEmitter
local testPelletSound = ReplicatedStorage.Assets.TEMPORARY:WaitForChild('CollectSoundRetro') :: Sound
local tweenSizes = {Vector3.new(2, 2, 2), Vector3.new(.1, .1, .1)}
local tweenWaitTime = 0.5

function TweenPelletLighting(pellet: Part)
	local lighting = pellet:FindFirstChildOfClass('PointLight') :: PointLight

	local lightingTween = TweenService:Create(
		lighting,
		TweenInfo.new(
			0.3,
			Enum.EasingStyle.Linear,
			Enum.EasingDirection.In,
			0,
			false
		),
		{Range=0, Brightness=0}
	)
	lightingTween:Play()
end

function TweenPelletAnimation(pellet: Part)
	local tweenBig = TweenService:Create(
		pellet,
		TweenInfo.new(
			.1,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In,
			0,
			false
		),
		{Size=tweenSizes[1]}
	)
	
	local tweenSmall = TweenService:Create(
		pellet,
		TweenInfo.new(
			0.2,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out,
			0,
			false
		),
		{Size=tweenSizes[2]}
	)
	
	tweenBig:Play()
	tweenBig.Completed:Connect(function(playbackState: Enum.PlaybackState)
		tweenSmall:Play()
	end)
	return tweenSmall
end

--function CreateSparkle(position: Vector3)
--	local att = Instance.new("Attachment")
--	att.Parent = workspace
--	att.CFrame = CFrame.new(position)

--	local particle = testSparkle:Clone()
--	particle.Parent = att
--	particle:Emit(1)
--	game.Debris:AddItem(att, 2)
--	return att, particle
--end

function DeleteFromWorkspace(pelletData: PelletData)
	game.Debris:AddItem(pelletData.PelletInstance, 0)
end

function DeleteFromECS(pelletData: PelletData)
	serverData.world:delete(pelletData.ClientEntityID)
end

function RemovePellet(pelletData: PelletData)
	--local att, particle = CreateSparkle(pelletData.PelletInstance.Position)
	local sound = SoundModule.PlaySoundAtLocation(SoundModule.pacmanPellet, pelletData.Position)
	TweenPelletLighting(pelletData.PelletInstance)
	local tweenSmall = TweenPelletAnimation(pelletData.PelletInstance) :: Tween
	
	tweenSmall.Completed:Wait()
	DeleteFromWorkspace(pelletData)
	DeleteFromECS(pelletData)
end

function CleanupPelletReferences(pelletData: PelletData)
	local positionHash = tostring(pelletData.Position)
	local serverEntityID = pelletData.ServerEntityID
	--serverData.pelletPositionLookup[positionHash] = nil
	--serverData.pelletServerIDLookup[ServerEntityID] = nil
end


function pelletDetectionLoop()
	local cache = serverData.world:query(Pellet, Position)
	RunService.Heartbeat:Connect(function(deltaTime: number)
		-- Get Pellets around Player — Spatial query
		local hitPellets = workspace:GetPartBoundsInRadius(hroot.Position, 6, IncludePelletFilterParams)
		
		if #hitPellets > 0 then
			for i, item in pairs(hitPellets) do
				-- Check if the PositionHash leads to any valid entity ID's
				local positionHash = tostring(item.Position)
				local pelletData = serverData.pelletPositionLookup[positionHash] :: PelletData
				local ServerEntityID = pelletData.ServerEntityID
				
				-- Check JECS World
				if pelletData.Collected == true then continue end
				
				local clientEntityID = pelletData.ClientEntityID
				if not clientEntityID then continue end
				--print('> 201 — PositionHash Returned: ClientEntityID = ', pelletData.ClientEntityID)
				
				-- Check if the Client Entity ID leads to any valid entities
				if not serverData.world:contains(clientEntityID) then continue end
				--print('> 201 — ClientEntityID Found!  Position =', serverData.world:get(clientEntityID, Position))
				
				local serverEntityID = pelletData.ServerEntityID
				print('[PelletHandler]: Client — UpdatePellet(): Sending ServerEntityID =', serverEntityID)
				
				-- Set Collected value
				pelletData.Collected = true
				serverData.world:set(clientEntityID, Collected, true)
				
				-- Send update to server
				print('LOCAL pellet handler: sending to server: ', serverEntityID)
				Remotes.UpdatePellet:FireServer(serverEntityID)
				
				-- Remove Pellet VFX
				RemovePellet(pelletData)
				print('> [PelletHandler]: Client — Collected PelletData = ', pelletData)
				--CleanupPelletReferences(pelletData)

				-- TODO (Server): Receive Pellet, Track pellets collected
				-- TODO (Server): Send authoritative Pellet State to all clients
				
				-- TODO (Client): Create Pellet VFX Handler, 
				-- TODO (Client): Program remove Pellet logic, remove from ECS World, PositionLookup, ServerEntityID Lookup
			end
			--print('------')
		end
	end)
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
	serverData.pelletServerIDLookup = {}
	
	-- Initialize ECS Component Declarations 
	Pellet = serverData.world:component() :: Entity<Part>
	Position = serverData.world:component() :: Entity<Vector3>
	ChunkHash = serverData.world:component() :: Entity<string>
	Collected = serverData.world:component() :: Entity<boolean>
	
	-- Client-Sided ECS Components
	ServerEntityID = serverData.world:component() :: Entity<number>
end

function SetupRemoteCalls()
	Remotes.UpdatePellet.OnClientEvent:Connect(function(ServerEntityID: number)
		-- Check if the Pellet exists and has not been collected
		local pelletData = serverData.pelletServerIDLookup[ServerEntityID]
		print('[PelletHandler] UpdatePellet EVENT RECEIVED: PelletData[',ServerEntityID,'] = ', pelletData)
		if not pelletData or pelletData.Collected == true then 
			print('[PelletHandler]: ERROR 404 — UpdatePellet, PelletData for ServerEntityID =', ServerEntityID, ' — Error 404!')
			return 
		end
		
		-- Check if the Client Entity ID leads to any valid entities
		if not serverData.world:contains(pelletData.ClientEntityID) then return end
		--print('201 — ClientEntityID Found!  Position =', serverData.world:get(pelletData.ClientEntityID, Position))
		
		RemovePellet(pelletData)
		
		-- Set Collected value
		pelletData.Collected = true
		serverData.world:set(pelletData.ClientEntityID, Collected, true)
	end)
end


-- Main
function init()
	print('Local: PelletHandler -> Init() called!')
	serverData = Remotes.InitializePellets:InvokeServer() :: ServerData
	
	print('Local: serverData received = ', serverData)
	SetupServerData()
	createFolderForPellets()
	SetupFilterParams()
	
	-- Create data for all pellets
	spawnChunksForRegion(serverData.region)
	SetupRemoteCalls()
	
	pelletDetectionLoop()
end

task.wait(1)

init()


--for id, pellet, pos : Vector3 in cache:iter() do
--	print('ECS LOOP: comparing ', id, pellet, '|', pos, '|', item.position)
--	if pos == item.Position then
--		print('DETECTED PELLET INSIDE ECS!')
--		serverData.world:remove(id)
--		game.Debris:AddItem(item, 0)
--		break
--	end
--end