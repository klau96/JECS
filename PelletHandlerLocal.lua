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
-- Later: Setup component declarations in SetupServerData()
local IncludePelletFilterParams = nil
-- Later in code: Set the FilteringDescendants to serverData.pelletFolder


-- Data Structure Declarations

--[[ 
	ServerData differences from Client <-> Server
	
	Both have a different 'serverData.world'
	Same ECS system, but is initialized in each script
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
	
	PelletInstance: Part, -- Local Diff: To keep track of locally created pellet instances
}


function createFolderForPellets()
	local folder = Instance.new('Folder')
	folder.Name = "Pellets"
	folder.Parent = workspace
	serverData.pelletFolder = folder
	return folder
end

-- ECS System to handle the chunks of pellets, render and update them
function createPellet(newPosition: Vector3, chunkHash: string)
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
	local pelletEntity = serverData.world:entity()
	
	serverData.world:set(pelletEntity, Pellet, true)
	serverData.world:set(pelletEntity, Position, newPosition)
	serverData.world:set(pelletEntity, Collected, false)
	serverData.world:set(pelletEntity, ChunkHash, chunkHash)

	pellet.Parent = serverData.pelletFolder
	return pellet
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

function spawnPelletsForChunk(chunkHash : string, chunkData : ChunkData)
	for i, pelletData : PelletData in ipairs(chunkData.worldData) do -- chunk size X - 1, preveants inclusion of ending
		local pellet = createPellet(pelletData.Position, chunkHash)
		pelletData.PelletInstance = pellet
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

				for id, pellet, pos : Vector3 in cache:iter() do
					print('ECS LOOP: comparing ', id, pellet, '|', pos, '|', item.position)
					if pos == item.Position then
						print('DETECTED PELLET INSIDE ECS!')
						serverData.world:remove(id)
						game.Debris:AddItem(item, 0)
						break
					end
				end
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
	Pellet = serverData.world:component() :: Entity<Part>
	Position = serverData.world:component() :: Entity<Vector3>
	ChunkHash = serverData.world:component() :: Entity<string>
	Collected = serverData.world:component() :: Entity<boolean>
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