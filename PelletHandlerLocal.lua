local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- Server
local PelletServer = workspace:WaitForChild('PelletServer') :: Script

-- Remote Events
local InitializePellets = PelletServer:WaitForChild('InitializePellets') :: RemoteEvent
local UpdatePellets = PelletServer:WaitForChild('UpdatePellets')


-- Data
local chunkTable = {}

-- ECS System to handle the chunks of pellets, render and update them
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

	print(string.format("CHUNK HASH: [%s] = %s, (%d, y, %d)", chunkHash, chunkTable[chunkHash].chunk.Name, chunk.Position.X, chunk.Position.Z))
	return chunk, chunkHash
end