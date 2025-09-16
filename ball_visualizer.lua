local region = workspace:FindFirstChild('PelletRegion') :: Part
local chunkSize = Vector3.new(100, 10, 100)
local pelletSpacing = 10

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

function createChunk(region, px, pz)
	local chunk = Instance.new('Part')
	chunk.Name = "Chunk"
	chunk.Size = chunkSize
	chunk.Anchored = true
	chunk.CanCollide = false
	chunk.Transparency = 0.8
	chunk.Color = Color3.new(1, 0, 0)
	chunk.Position = Vector3.new(px, region.Position.Y + chunkSize.Y/2, pz)
	chunk.Parent = workspace
	return chunk
end

chunkTable = {}

function spawnPelletsForChunk(chunk : Part)
	local cx = chunkSize.X
	local cz = chunkSize.Z
	for x = 0, cx-1, pelletSpacing do -- chunk size X - 1, prevents inclusion of ending
		for z = 0, cz-1, pelletSpacing do
			local coordx = chunk.Position.X - cx/2 + x
			local coordz = chunk.Position.Z - cz/2 + z
			local pellet = createPellet(region, coordx, coordz)
			wait()
		end
	end
end

function spawnChunksForRegion(region : Part)
	for x = 0, region.Size.X-1, chunkSize.X do
		for z = 0, region.Size.Z-1, chunkSize.Z do
			local coordx = x + chunkSize.X/2 - region.Size.X/2
			local coordz = z + chunkSize.Z/2 - region.Size.Z/2
			local chunk = createChunk(region, coordx, coordz)
			spawnPelletsForChunk(chunk)
			table.insert(chunkTable, chunk)
			print( string.format("Created chunk at (%d, %d) -> x, z = (%d, %d)", coordx, coordz, x, z) )
		end
	end
end

spawnChunksForRegion(region)