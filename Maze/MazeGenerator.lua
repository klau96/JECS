-- Credit: AshRBX on YouTube
-- https://www.youtube.com/watch?v=nGveqHnicr8
-- Spaghetti code additions made by ininja966

local boardW = 20;
local cellW = 25;
local h = 30;

local nodeClass = require(script.NodeClass);
nodeClass.boardW = boardW
local stackModule = require(script.Stack);

export type NodeArray = {nodeClass};

local nodes = {} :: NodeArray;

function createNewMaze()
	local index = 1;
	for i = 1, boardW do
		for j = 1, boardW do
			local currentNode = nodeClass.new(i, j, cellW, h, boardW);
			currentNode:spawnWalls();
			nodes[index] = currentNode;
			index += 1;
		end
	end
end

function wallsBetweenNodesExist(nodeTable, wallIndexes)
	return nodeTable[1].walls[wallIndexes[1]].Parent == workspace and nodeTable[2].walls[wallIndexes[2]].Parent == workspace
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

function createPointer(current: nodeClass)
	local pointer = Instance.new("Part")
	pointer.Size = Vector3.new(cellW, h, cellW);
	pointer.Position = Vector3.new(current.x, 0,current.y)
	pointer.Anchored = true;
	pointer.CanCollide = false;
	pointer.Material = Enum.Material.Neon;
	pointer.Parent = workspace;
	pointer.Color = Color3.new(0.309804, 1, 0.470588);
	return pointer
end

function calculateMaze()
	local nodeStack = stackModule.new(cellW * cellW);
	local current = nodes[1];
	--Mark first one as visited and push onto stack
	current.visited = true;
	--print(current:checkNeighbors(nodes));
	nodeStack:push(current);
	
	--Create the currentNodePointerMesh
	local pointer = createPointer(current)
	
	while not nodeStack:isEmpty() do
		current = nodeStack:pop();
		current:changeWallColours();
		pointer.Position = Vector3.new(current.x, 0,current.y)
		
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
passageLookup = {} :: PassageLookup

function findRandomNodeIndex()
	local irandom = math.random(1, boardW)
	local jrandom = math.random(1, boardW)
	local randomIndex = (nodeClass:calculateStackNodeIndex(irandom, jrandom))
	print(string.format("random node: [%d], (%d, %d)", randomIndex, irandom, jrandom))
	return randomIndex
end

function removeRandomWalls(targetIndex: number)
	-- function that is ran post-maze-generation
	local targetNode = nil
	local targetIndex = nil
	
	local nextNode = nil
	local nextIndex = nil
	
	local wallIndexes = nil
	local wallsExist = false
	
	while not wallsExist do
		-- find a random node
		targetIndex = findRandomNodeIndex()
		targetNode = nodes[targetIndex]
		-- find a valid neighbor to the node
		nextNode = targetNode:checkNeighbors(nodes)
		nextIndex = nextNode:calculateStackNodeIndex(nextNode.i, nextNode.j)
		-- find out whether there's still a wall between them
		
		-- Target Node has NO neighbors (somehow)
		if nextNode == nil then return end
		
		local nodeTable = {targetNode, nextNode}
		wallIndexes = findWallIndexesBetweenNodes(nodeTable)
		
		wallsExist = wallsBetweenNodesExist(nodeTable, wallIndexes)
		
		local targetWallIsPassage = passageLookup[targetIndex] and table.find(passageLookup[targetIndex], wallIndexes[1])
		local nextWallIsPassage = passageLookup[nextIndex] and table.find(passageLookup[nextIndex], wallIndexes[2])
		if targetWallIsPassage or nextWallIsPassage then
			-- wall exists, but is already a passage
			-- therefore wall does not exist
			print('PassageLookup: Walls Exist already')
			wallsExist = false
		end
		print(string.format("Nodes: (%d, %d) —> Do walls exist? = %s", targetIndex, nextIndex, tostring(wallsExist)) )
		task.wait()
	end
	
	-- Add new nodes to Passage Lookup
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
end

local theWallColor = Color3.new(1, 0.192782, 0.584207)
function makePassageWall(wall: Part)
	wall.Color = theWallColor
	wall.Transparency = 0.6
	wall.CanCollide = false
	wall.Material = Enum.Material.Neon
	
	wall.Size = wall.Size - Vector3.new(0, 28, 0)
	wall.Position = wall.Position + Vector3.new(0, 14, 0)
end

function resetVisitedNodes()
	for i, node in ipairs(nodes) do
		node.visited = false
	end
end

wait(1);
createNewMaze();
calculateMaze();
print("--------------------------")
resetVisitedNodes()


for i = 1, 50 do
	removeRandomWalls()
end