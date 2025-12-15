-- Services
local RunService = game:GetService('RunService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ServerScriptService = game:GetService('ServerScriptService')
local Players = game:GetService('Players')
local Players2 = game:GetService('GeometryService')

-- Modules
local PlayerScoreModule = require(ServerScriptService.Server.PlayerScore)
local PacmanScoreModule = require(ServerScriptService.Server.PacmanScore)
local Bindables = require(ServerScriptService.Modules.BindablesCollection)

local world = require(ReplicatedStorage.Shared.world)
local C = require(ReplicatedStorage.Shared.components)

-- Types
local Types = require(ReplicatedStorage.Modules.Types)

export type PlayerScore = typeof(PlayerScoreModule.new())
export type PacmanScore = typeof(PacmanScoreModule.new())

-- Variables
local serverData = nil :: Types.GameServerData
local scoreTable = nil :: Types.ScoreTable

function ClearScoreTable()
	if scoreTable == nil then 
		print('[GameServer]: ERROR 404, scoreTable == nil check.')	
		return
	end
	-- Check if there are entries
	for i, v in pairs(scoreTable) do
		table.clear(scoreTable)
		break
	end
end

function InitializeScoreTable()
	local newScoreTable: Types.ScoreTable = {
		PlayerList = {},
		SurvivorList = {},
		Pacman = nil,
		PlayerScoreLookup = {},
		PacmanScore = nil,
	}
	
	return newScoreTable
end

function InitializeGameServerData(newMazeInfo: Types.MazeInformation)
	serverData = {
		mazeInfo = newMazeInfo
	} :: Types.GameServerData
end

local function ApplyRoles()
	if not scoreTable then return end
	
	local pacmanPlr = scoreTable.Pacman
	if not pacmanPlr then return end
	
	for id, plr in world:query(C.Player.PlayerRef):iter() do
		if plr == pacmanPlr then
			world:set(id, C.Role.playerType, "Pacman")
		else
			world:set(id, C.Role.playerType, "Ghost")
		end
		
		world:set(id, C.Role.Alive, true)
	end
end

local function PacmanMorph()
	if not scoreTable or not scoreTable.Pacman then return end
	local pacmanPlr = scoreTable.Pacman
	
	for e, plr, role in world:query(C.Player.PlayerRef, C.Role.playerType):iter() do
		if plr == pacmanPlr and role == "Pacman" then
			world:set(e, C.Morph.Request, "ToPacman")
			world:set(e, C.Morph.IsPacman, true)
		end
	end
end

function SelectPacman()
	scoreTable.PlayerList = Players:GetPlayers()
	
	local chosenIndex = math.random(1, #scoreTable.PlayerList)
	scoreTable.Pacman = scoreTable.PlayerList[chosenIndex]
end

function AddSurvivors()
	-- Assumes that scoreTable is created already
	for i, player in ipairs(scoreTable.PlayerList) do
		if player ~= scoreTable.Pacman then
			table.insert(scoreTable.SurvivorList, player)
		end
	end
end

function InitializeScores()
	-- Create pacman's score
	scoreTable.PacmanScore = PacmanScoreModule.new(scoreTable.Pacman)
	
	-- Create all survivor scores
	for i, player in ipairs(scoreTable.SurvivorList) do
		scoreTable.PlayerScoreLookup[player.Name] = PlayerScoreModule.new(player)
	end
end

function CreateScoreTable()
	print('[GameServer]: STARTING —> CreateScoreTable()')
	ClearScoreTable()
	scoreTable = InitializeScoreTable()
	
	-- Initialize PlayerList, Pacman
	SelectPacman()
	
	-- Create the list of survivors without Pacman
	AddSurvivors()
	
	-- Use the module, create Scores types
	InitializeScores()
	
	print("[GameServer]: FINISHED CreateScoreTable() —> ScoreTable = ", scoreTable)
end

function AddCollectedPelletAndScore(targetPlayerScore: PlayerScore, ServerEntityID)
	-- Insert Entity ID to Array of pellets
	table.insert(targetPlayerScore.PelletsCollected, ServerEntityID)
	-- Add to value
	targetPlayerScore.Value = targetPlayerScore.Value + 100
end

function SpawnSurvivors()
	local survivorCorners = serverData.mazeInfo.SurvivorCorners
	
	-- Loop through players, spawn at alternating corners
	local i = 1
	for _, survivor in ipairs(scoreTable.SurvivorList) do
		local hr = survivor.Character:FindFirstChild("HumanoidRootPart")
		-- humanoid root part check
		if not hr then 
			print("> ERROR [GameServer]: Survivor ", survivor.Name, " does not have humanoid root part!") 
			continue 
		end
		
		-- Send humanoid root part to corner
		local targetCorner = survivorCorners[i]
		print('[GameServer] SURVIVOR CORNERS: ', i, targetCorner)
		hr.CFrame = CFrame.new(targetCorner.CenterPosition)
		
		-- Iterate i, which is the target corner index
		-- 	This is only the case if there are 4 or more players
		--	Multiple players can spawn at the same corner
		i += 1
		if i > #survivorCorners then
			i = 1
		end
	end
end

function SpawnPacman()
	local hr = scoreTable.Pacman.Character:FindFirstChild('HumanoidRootPart')
	local pacmanSpawnNode = serverData.mazeInfo.PacmanSpawnNode :: Types.NodeInfo
	hr.CFrame = CFrame.new(pacmanSpawnNode.CenterPosition)
end

function CreateBindableFunctions()
	
	-- Only to be called by the PelletServer, which authenticates valid pellets
	Bindables.GameServer.UpdateScore.Event:Connect(function(player: Player, ServerEntityID: number)
		if not scoreTable then return end
		print('[GameServer]: UpdateScore: received parameters = ', player, ServerEntityID)
		if not scoreTable.PlayerScoreLookup[player.Name] then return false end
		
		local targetPlayerScore = scoreTable.PlayerScoreLookup[player.Name] :: PlayerScore
		
		print('[GameServer]: Found Player Score: ', targetPlayerScore)
		AddCollectedPelletAndScore(targetPlayerScore, ServerEntityID)
	end)
	
	-- Called by: some server scripts (?)
	Bindables.GameServer.GetPlayerScore.OnInvoke = function(player: Player)
		print('[GameServer]: BINDABLE GetPlayerScore.OnInvoke() ->', player)
		-- Check if player is pacman
		if scoreTable.Pacman and scoreTable.Pacman == player then
			return scoreTable.PacmanScore.Value
		end
		
		-- Check if player has an entry in survivor's Score Lookup Table
		if scoreTable.PlayerScoreLookup[player.Name] then
			return scoreTable.PlayerScoreLookup[player.Name].Value
		end
		
		return nil
	end
	
	-- Called by : RoundSystem
	Bindables.GameServer.StartGame.Event:Connect(function()
		print('==== [GameServer]: GameServer.StartGame CALLED! ====')
		Main()
		print('==== [GameServer]: GameServer.StartGame FINISHED! ====')
	end)
end

function Init()
	CreateBindableFunctions()
end

function Main()
	-- Receive an event from RoundSystem
	
	-- Create a new score table
	CreateScoreTable()
	
	-- Set Maze Region
	local mazeRegion = workspace:FindFirstChild('MazeRegion') :: BasePart
	
	-- Call Bindable to spawn pellets — Send in MazeRegion
	Bindables.PelletServer.SpawnPellets:Invoke(mazeRegion)
	
	-- Call Bindable to generate maze
	print('[GameServer]: CALLING: MazeServer.GenerateMaze()...')
	local mazeInfo = Bindables.MazeServer.GenerateMaze:Invoke(scoreTable, mazeRegion) :: Types.MazeInformation
	print("[GameServer]: GenerateMaze() Completed! -> ", mazeInfo)
	
	-- Step —> UPDATE: GameServer's ServerData variable
	InitializeGameServerData(mazeInfo)
	
	-- Set Roles / Characters
	ApplyRoles() -- apply the "Ghost" and "Pacman" role from components
	PacmanMorph() -- morph Pacman
	
	-- Spawn Survivors in Corners that are NOT pacman's corner
	task.wait(10)
	SpawnSurvivors()
	SpawnPacman()
end


Init()