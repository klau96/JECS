-- Credit: AshRBX on YouTube
-- https://www.youtube.com/watch?v=nGveqHnicr8
-- Spaghetti code additions made by ininja966

-- Services
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ServerScriptService = game:GetService('ServerScriptService')
local TweenService = game:GetService('TweenService')

-- Modules
local nodeClass = require(script.NodeClass);
local stackModule = require(script.Stack);
local PointerModule = require(script:WaitForChild('Pointer'));
export type Pointer = typeof(PointerModule.new())

-- Maze Settings Variables
local boardW = 16;
local cellW = 25;
local h = 60;
local nodes = {};
local pointer = nil

-- Pellet Region
local region = workspace.PelletRegion
local regionOriginX = region.Position.X - region.Size.X/2
local regionOriginZ = region.Position.Z - region.Size.Z/2
local regionOriginPosition = Vector3.new(regionOriginX, region.Position.Y, regionOriginZ)

-- Extra
local SoundModule = require(ReplicatedStorage.Modules:WaitForChild('Sound'))


function initNodeClass()
	nodeClass.boardW = boardW
	nodeClass.wallsFolder = CreateFolderForWalls()
end

function CreateFolderForWalls()
	local folder = Instance.new("Folder")
	folder.Name = "MazeWalls"
	folder.Parent = workspace
	return folder
end

function createNewMaze()
	local index = 1;
	for i = 1, boardW do
		for j = 1, boardW do
			local currentNode = nodeClass.new(i, j, cellW, h, boardW);
			currentNode.regionOrigin = regionOriginPosition
			currentNode.wallsFolder = nodeClass.wallsFolder
			currentNode:spawnWalls();
			nodes[index] = currentNode;
			index += 1;
		end
	end
end

function wallsBetweenNodesExist(nodeTable, wallIndexes)
	return nodeTable[1].walls[wallIndexes[1]].Parent == nodeClass.wallsFolder and nodeTable[2].walls[wallIndexes[2]].Parent == nodeClass.wallsFolder
end

function removeWalls(currentNode: nodeClass, nextNode: nodeClass)
	local y = (currentNode.i - nextNode.i);
	local x = (currentNode.j - nextNode.j);
	local nodeTable = {currentNode, nextNode};
	
	if x == 1  then
		currentNode.walls[2]:Destroy();
		nextNode.walls[4]:Destroy();
	elseif x == -1 then
		currentNode.walls[4]:Destroy();
		nextNode.walls[2]:Destroy();
	end
	
	if y == 1  then
		currentNode.walls[1]:Destroy();
		nextNode.walls[3]:Destroy();
	elseif y == -1 then
		currentNode.walls[3]:Destroy();
		nextNode.walls[1]:Destroy();
	end
end

wallIndexLookup = { -- [x or y] = {currentNodeWall, nextNodeWall}
	x = {
		[1] = {2,4},
		[-1] = {4, 2},
	},
	y = {
		[1] = {1, 3},
		[-1] = {3, 1},
	}
}

function findWallIndexesBetweenNodes(nodeTable)
	local currentNode = nodeTable[1]
	local nextNode = nodeTable[2]
	local y = (currentNode.i - nextNode.i);
	local x = (currentNode.j - nextNode.j);
	
	return wallIndexLookup.x[x] or wallIndexLookup.y[y]
end


function calculateMaze()
	local nodeStack = stackModule.new(cellW * cellW);
	local current = nodes[1];
	--Mark first one as visited and push onto stack
	current.visited = true;
	
	nodeStack:push(current);
	
	-- Initialize the Pointer
	pointer = PointerModule.new(cellW, h) :: Pointer
	pointer:createPointerInstance()
	
	while not nodeStack:isEmpty() do
		current = nodeStack:pop();
		current:changeWallColours();
		--pointer.Position = Vector3.new(current.x, 0,current.y)
		pointer:setPointerPosition(current)
		
		-- Will return a random neighbor from the node
		local neighbor, index = current:checkNeighbors(nodes); 
	
		if neighbor ~= nil then
			nodeStack:push(current);
			removeWalls(current, neighbor);
			neighbor.visited = true;
			nodeStack:push(neighbor);
		end
		task.wait()
	end
end

-- Additions to maze generator script
-- puf 

export type PassageLookup = {[number]: {number}}
local passageLookup = {} :: PassageLookup
local allPassages = {}

function findRandomNodeIndex()
	local irandom = math.random(1, boardW)
	local jrandom = math.random(1, boardW)
	local randomIndex = (nodeClass:calculateStackNodeIndex(irandom, jrandom))
	
	return randomIndex
end

function removeWallFromTargetNode(targetIndex: number)
	-- function that is ran post-maze-generation
	local targetNode = nodes[targetIndex]
	--targetIndex = findRandomNodeIndex()
	
	
	local nextNode = nil
	local nextIndex = nil
	
	local wallIndexes = nil
	local wallsExist = false
	
	local checkCounter = 0
	
	-- Loop —> Find a Valid Neighboring Wall
	while not wallsExist do
		--pointer.Position = Vector3.new(targetNode.x, 0, targetNode.y)
		pointer:setPointerPosition(targetNode)
		-- find a valid neighbor to the node
		nextNode = targetNode:checkNeighbors(nodes)
		nextIndex = nextNode:calculateStackNodeIndex(nextNode.i, nextNode.j)
		-- find out whether there's still a wall between them
		
		-- Target Node has NO neighbors (somehow)
		if nextNode == nil then return end
		
		local nodeTable = {targetNode, nextNode}
		wallIndexes = findWallIndexesBetweenNodes(nodeTable)
		
		wallsExist = wallsBetweenNodesExist(nodeTable, wallIndexes)
		task.wait()
		--pointer.Position = Vector3.new(nextNode.x, 0, nextNode.y)
		pointer:setPointerPosition(nextNode)

		local targetWallIsPassage = passageLookup[targetIndex] and table.find(passageLookup[targetIndex], wallIndexes[1])
		print('passgeWall creation:', targetWallIsPassage, wallsExist)
		local nextWallIsPassage = passageLookup[nextIndex] and table.find(passageLookup[nextIndex], wallIndexes[2])
		if targetWallIsPassage or nextWallIsPassage then
			-- wall exists, but is already a passage
			-- therefore wall does not exist
			print('PassageLookup: Walls Exist already')
			
			wallsExist = false
		end
		--print(string.format("Nodes: (%d, %d) —> Do walls exist? = %s", targetIndex, nextIndex, tostring(wallsExist)) )
		
		task.wait()
		checkCounter = checkCounter + 1
		if checkCounter > 16 then
			print('checkCounter reached 16! Returning false...')
			return false
		end
	end
	
	-- Add target / next nodes to Passage Lookup
	if not passageLookup[targetIndex] then
		passageLookup[targetIndex] = {}
	end
	if not passageLookup[nextIndex] then
		passageLookup[nextIndex] = {}
	end
	
	-- Add wall indexes to node's Passage Lookup
	table.insert(passageLookup[targetIndex], wallIndexes[1])
	table.insert(passageLookup[nextIndex], wallIndexes[2])
	
	-- Turn walls into passages
	local targetNodeWall = targetNode.walls[wallIndexes[1]] :: Part
	makePassageWall(targetNodeWall)
	
	local nextNodeWall = nextNode.walls[wallIndexes[2]] :: part
	makePassageWall(nextNodeWall)
	
	return true
end

function makePassageWall(wall: Part)
	print('making passage wall')
	table.insert(allPassages, wall)
	wall.Color = nodeClass.highlightColor
	wall.Material = Enum.Material.Neon
	
	local sizeDiff = 55
	wall.Size = wall.Size - Vector3.new(0, sizeDiff, 0)
	wall.Position = wall.Position + Vector3.new(0, sizeDiff/2, 0)
end

function changeAllPassageColors()
	for i, passage in ipairs(allPassages) do
		local tween = TweenService:Create(
			passage,
			TweenInfo.new(
				4,
				Enum.EasingStyle.Linear,
				Enum.EasingDirection.In,
				0,
				false
			),
			{
				Color=nodeClass.normalColor,
				Transparency = 0,
			}
		)
		tween:Play()
		-- Turn passage wall back to material
		tween.Completed:Connect(function()
			passage.Material = Enum.Material.Slate
		end)
	end
end

function resetVisitedNodes()
	for i, node in ipairs(nodes) do
		node.visited = false
	end
end

function resetPointer()
	pointer:setPointerPosition(nodes[1])
	pointer:PlayEndTweenLoop()
end

initNodeClass();

wait(1);
createNewMaze();
calculateMaze();
print("--------------------------")



function generateUniformPassages()
	for i = 2, boardW, 4 do
		for j = 2, boardW, 4 do	
			local targetIndex = nodeClass:calculateStackNodeIndex(i, j)
			removeWallFromTargetNode(targetIndex)
		end
	end
end

function generateRandomPassages()
	local counter = 0
	local numberOfPassages = 20
	
	while counter < numberOfPassages do 
		local targetIndex = findRandomNodeIndex()
		local result = removeWallFromTargetNode(targetIndex)
		if result then
			counter = counter + 1
		end
	end
end

resetVisitedNodes()

generateUniformPassages()
generateRandomPassages()

resetPointer()
changeAllPassageColors()
