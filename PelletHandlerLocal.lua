local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- Server
local PelletServer = workspace:WaitForChild('PelletServer') :: Script

-- Remote Events
local InitializePellets = PelletServer:WaitForChild('InitializePellets') :: RemoteFunction
local UpdatePellets = PelletServer:WaitForChild('UpdatePellets') :: RemoteEvent

-- Data
local serverData = nil :: ServerData

-- Data Structure Declarations
export type ServerData = {
	chunkTable: {[string]: ChunkData},
	numChunks: number,
	pelletSpacing: number,
	pelletStartPos: number,
r3,
	region: Part,
	regionOriginPosition: Vector3,
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
	PelletInstance: Part, -- Local Diff: To keep track of locally created pellet instances
}

-- ECS System to handle the chunks of pellets, render and update them
function createPellet(newPosition)
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

	local light = Instance.new('PointLight')
	light.Brightness = 2
	light.Color = Color3.new(1, 1, 1)
	light.Range = 10
	light.Parent = pellet

	pellet.Parent = workspace
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
		local pellet = createPellet(pelletData.Position)
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

-- MAIN 

function init()
	serverData = InitializePellets:InvokeServer() :: ServerData
	print(serverData)
	spawnChunksForRegion(serverData.region)
end




init()