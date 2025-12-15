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

local Bindables = require(ServerScriptService.Modules:WaitForChild('BindablesCollection'))

-- Types
local Types = require(ReplicatedStorage.Modules.Types)

export type NodeClass = typeof(nodeClass.new())
export type Pointer = typeof(PointerModule.new())

export type MazeSettings = {
	boardW: number,
	cellW: number,
	h: number,
}
export type MazeServerData = {
	nodes: {NodeClass},
	pointer: Pointer?,
	region: Part?,
	regionOriginPosition: Vector3?,
}

-- Variables
local Settings: MazeSettings = {
	boardW = 16,
	cellW = 25,
	h = 60,
}

--local ServerData: MazeServerData = {
--	nodes = {},
--	pointer = nil,
--	region = nil,
--	regionOriginPosition = nil,
--}
local ServerData: MazeServerData = nil;

-- Extra
local SoundModule = require(ReplicatedStorage.Modules:WaitForChild('Sound'))

function InitializeServerData()
	-- initialize ServerData
	ServerData = {
		nodes = {},
		pointer = nil,
		region = nil,
		regionOriginPosition = nil,
	} :: MazeServerData
end

function InitializeMazeRegion(mazeRegion)
	--ServerData.region = workspace.PelletRegion
	ServerData.region = mazeRegion
	local regionOriginX = ServerData.region.Position.X - ServerData.region.Size.X/2
	local regionOriginZ = ServerData.region.Position.Z - ServerData.region.Size.Z/2
	ServerData.regionOriginPosition = Vector3.new(regionOriginX, ServerData.region.Position.Y, regionOriginZ)
end

function InitializeNodeClass()
	nodeClass.boardW = Settings.boardW
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
	for i = 1, Settings.boardW do
		for j = 1, Settings.boardW do
			local currentNode = nodeClass.new(i, j, Settings.cellW, Settings.h, Settings.boardW);
			currentNode.regionOriginPosition = ServerData.regionOriginPosition
			currentNode.wallsFolder = nodeClass.wallsFolder
			currentNode:spawnWalls();
			ServerData.nodes[index] = currentNode;
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
	local nodeStack = stackModule.new(Settings.cellW * Settings.cellW);
	local current = ServerData.nodes[1];
	--Mark first one as visited and push onto stack
	current.visited = true;
	
	nodeStack:push(current);
	
	-- Initialize the Pointer
	print('[MazeServer] Pointer about to be created!')
	ServerData.pointer = PointerModule.new(Settings.cellW, Settings.h) :: Pointer
	ServerData.pointer:createPointerInstance()
	
	while not nodeStack:isEmpty() do
		current = nodeStack:pop();
		current:changeWallColors();
		--pointer.Position = Vector3.new(current.x, 0,current.y)
		ServerData.pointer:setPointerPosition(current)
		
		-- Will return a random neighbor from the node
		local neighbor, index = current:checkNeighbors(ServerData.nodes); 
	
		if neighbor ~= nil then
			nodeStack:push(current);
			removeWalls(current, neighbor);
			neighbor.visited = true;
			nodeStack:push(neighbor);
			task.wait()
		end
	end
end

-- Additions to maze generator script
-- puf 

export type PassageLookup = {[number]: {number}}
local passageLookup = {} :: PassageLookup
local allPassages = {}

function findRandomNodeIndex()
	local irandom = math.random(1, Settings.boardW)
	local jrandom = math.random(1, Settings.boardW)
	local randomIndex = (nodeClass:calculateStackNodeIndex(irandom, jrandom))
	
	return randomIndex
end

function removeWallFromTargetNode(targetIndex: number)
	-- function runs after maze-generation
	local targetNode = ServerData.nodes[targetIndex]
	--targetIndex = findRandomNodeIndex()
	
	
	local nextNode = nil
	local nextIndex = nil
	
	local wallIndexes = nil
	local wallsExist = false
	
	local checkCounter = 0
	
	-- Loop —> Find a Valid Neighboring Wall
	while not wallsExist do
		--pointer.Position = Vector3.new(targetNode.x, 0, targetNode.y)
		ServerData.pointer:setPointerPosition(targetNode)
		-- find a valid neighbor to the node
		nextNode = targetNode:checkNeighbors(ServerData.nodes)
		nextIndex = nextNode:calculateStackNodeIndex(nextNode.i, nextNode.j)
		-- find out whether there's still a wall between them
		
		-- Target Node has NO neighbors (somehow)
		if nextNode == nil then return end
		
		local nodeTable = {targetNode, nextNode}
		wallIndexes = findWallIndexesBetweenNodes(nodeTable)
		
		wallsExist = wallsBetweenNodesExist(nodeTable, wallIndexes)
		task.wait()
		ServerData.pointer:setPointerPosition(nextNode)

		local targetWallIsPassage = passageLookup[targetIndex] and table.find(passageLookup[targetIndex], wallIndexes[1])
		
		local nextWallIsPassage = passageLookup[nextIndex] and table.find(passageLookup[nextIndex], wallIndexes[2])
		if targetWallIsPassage or nextWallIsPassage then
			-- wall exists, but is already a passage
			-- therefore wall does not exist
			print('PassageLookup: Walls Exist already')
			
			wallsExist = false
		end
		--print(string.format("Nodes: (%d, %d) —> Do walls exist? = %s", targetIndex, nextIndex, tostring(wallsExist)) )
		
		-- Condition: Break infinite loop if no valid passage walls exist
		checkCounter = checkCounter + 1
		if checkCounter > 2 then
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
	for i, node in ipairs(ServerData.nodes) do
		node.visited = false
	end
end

function resetPointer()
	ServerData.pointer:setPointerPosition(ServerData.nodes[1])
	ServerData.pointer:PlayEndTweenLoop()
end


-- Maze Additions

function generateUniformPassages()
	for i = 2, Settings.boardW, 4 do
		for j = 2, Settings.boardW, 4 do	
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

function MazeInformation_GetNodePosition(i, j)
	-- Uses: Settings, ServerData
	local centerx = i*Settings.cellW - Settings.cellW/2
	local y = 3
	local centerz = j*Settings.cellW - Settings.cellW/2
	local centerPos = Vector3.new(centerx, y, centerz) 
	
	return centerPos + ServerData.regionOriginPosition
end

function GetMazeInformation()
	-- Creates a Types.MazeInformation
	-- Which then holds Corner information with Types.NodeInfo
	
	local mazeInfo: Types.MazeInformation = {
		Corners = {},
		PacmanSpawnNode = nil,
		PacmanCornerIndex = nil,
	}
	local ivalues = {1, Settings.boardW}
	local jvalues = {1, Settings.boardW}
	
	-- Create Corners Information through NodeInfo objects
	for _, i in ipairs(ivalues) do
		for _, j in ipairs(jvalues) do
			local nodeInfo = {} :: Types.NodeInfo
			nodeInfo.CenterPosition = MazeInformation_GetNodePosition(i, j)
			nodeInfo.i = i
			nodeInfo.j = j
			
			table.insert(mazeInfo.Corners, nodeInfo)
		end
	end
	
	-- TEMP: Create the Center maze Pacman spawn position
	
	--local pacmanNode = {} :: Types.NodeInfo
	--pacmanNode.i = math.floor(Settings.boardW/2)
	--pacmanNode.j = math.floor(Settings.boardW/2)
	--pacmanNode.CenterPosition = MazeInformation_GetNodePosition(pacmanNode.i, pacmanNode.j)
	--mazeInfo.PacmanSpawnNode = pacmanNode.CenterPosition
	
	-- Select the random corner for pacman
	local pacmanCornerIndex = math.random(1, #mazeInfo.Corners)
	mazeInfo.PacmanCornerIndex = pacmanCornerIndex
	mazeInfo.PacmanSpawnNode = mazeInfo.Corners[mazeInfo.PacmanCornerIndex]
	
	mazeInfo.SurvivorCorners = table.clone(mazeInfo.Corners)
	table.remove(mazeInfo.SurvivorCorners, mazeInfo.PacmanCornerIndex)
	
	print('[MazeServer] CORNER CHECK:', mazeInfo.Corners, mazeInfo.SurvivorCorners, mazeInfo.PacmanSpawnNode.CenterPosition)
	
	return mazeInfo
end

-- Bindables
function CreateBindableFunctions()
	--------------------------------------------
	Bindables.MazeServer.GenerateMaze.OnInvoke = function(scoreTable: Types.ScoreTable, mazeRegion: Part)
		print("MazeServer.GenerateMaze.OnInvoke() -> ", scoreTable)
		InitializeServerData();
		InitializeMazeRegion(mazeRegion);
		InitializeNodeClass();
		
		task.wait(1);
		createNewMaze();
		calculateMaze();

		resetVisitedNodes()

		generateUniformPassages()
		generateRandomPassages()

		resetPointer()
		changeAllPassageColors()
		
		local mazeInfo = GetMazeInformation() -- Corner Positions are in Types.NodeInfo
		
		return mazeInfo :: Types.MazeInformation
	end
	--------------------------------------------
end

CreateBindableFunctions()
