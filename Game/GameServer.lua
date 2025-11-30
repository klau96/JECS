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

-- Types
local Types = require(ReplicatedStorage.Modules.Types)

export type PlayerScore = typeof(PlayerScoreModule.new())
export type PacmanScore = typeof(PacmanScoreModule.new())

-- Variables
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

function AddCollectedPelletAndScore(targetPlayerScore:PlayerScore, ServerEntityID)
	-- Insert Entity ID to Array of pellets
	table.insert(targetPlayerScore.PelletsCollected, ServerEntityID)
	-- Add to value
	targetPlayerScore.Value = targetPlayerScore.Value + 100
end

function CreateBindableFunctions()
	
	-- Only to be called by the PelletServer, which authenticates valid pellets
	Bindables.GameServer.UpdateScore.Event:Connect(function(player: Player, ServerEntityID: number)
		if not scoreTable then return end
		print('[GameServer]: UpdateScore: received parameters = ', player, ServerEntityID)
		if not scoreTable.PlayerScoreLookup[player.Name] then return false end
		
		local targetPlayerScore = scoreTable.PlayerScoreLookup[player.Name] :: PlayerScore
		
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

-- Main
function Main()
	-- Receive an event from RoundSystem
	-- Call the maze server script
	
	CreateScoreTable()
	
	-- Call Bindable to generate maze
	print('[GameServer]: CALLING: MazeServer.GenerateMaze()...')
	local mazeInfo = Bindables.MazeServer.GenerateMaze:Invoke(scoreTable) :: Types.MazeInformation
	print("[GameServer]: GenerateMaze() Completed! -> ", mazeInfo)
	
	print('TELEPORT: Beginning For-loop')
	for i, node: Types.NodeInfo in pairs(mazeInfo.Corners) do
		print('Setting ininja966 to', node.CenterPosition)
		game.Players.ininja966.Character.HumanoidRootPart.CFrame = CFrame.new(node.CenterPosition)
		task.wait(1)
	end 
	
	game.Players.ininja966.Character.HumanoidRootPart.CFrame = CFrame.new(mazeInfo.PacmanSpawnPosition.CenterPosition)
end

Init()

repeat task.wait() until #Players:GetPlayers() >= 1

--task.wait(1)

--print('==== [GameServer]: GAME STARTING ====')
--Main()
--print('==== [GameServer]: GAME MAIN() OPERATIONS ENDED! ====')