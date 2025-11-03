-- Services
local RunService = game:GetService('RunService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ServerScriptService = game:GetService('ServerScriptService')
local Players = game:GetService('Players')
local Players2 = game:GetService('GeometryService')

-- Modules
local PlayerScoreModule = require(ServerScriptService.Server:WaitForChild('PlayerScore'))
local PacmanScoreModule = require(ServerScriptService.Server:WaitForChild('PacmanScore'))

-- Types
export type PlayerScore = typeof(PlayerScoreModule.new())
export type PacmanScore = typeof(PacmanScoreModule.new())

export type ScoreTable = {
	PlayerList: {Player},
	SurvivorList: {Player},
	Pacman: Player?,
	
	PlayerScoreLookup: {
		[string]: PlayerScore
	},
	PacmanScore: PacmanScore?,
}

export type Bindables = {
	GetPlayerScore: BindableFunction,
	UpdateScore: BindableEvent,
}

-- Variables
local scoreTable = {} :: ScoreTable

local bindables: Bindables = {
	GetPlayerScore = script:WaitForChild('GetPlayerScore'),
	UpdateScore = script:WaitForChild('UpdateScore')
}


function ClearScoreTable()
	if scoreTable == nil then return end
	-- Check if there are entries
	for i, v in pairs(scoreTable) do
		table.clear(scoreTable)
		break
	end
end

function InitializeScoreTable()
	local newScoreTable: ScoreTable = {
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
	ClearScoreTable()
	scoreTable = InitializeScoreTable()
	
	-- Initialize PlayerList, Pacman
	SelectPacman()
	
	-- Create the list of survivors without Pacman
	AddSurvivors()
	
	-- Use the module, create Scores
	InitializeScores()
	
	print("[GameServer]: ScoreTable = \n", scoreTable)
end

function AddCollectedPelletAndScore(targetPlayerScore:PlayerScore, ServerEntityID)
	-- Insert Entity ID to Array of pellets
	table.insert(targetPlayerScore.PelletsCollected, ServerEntityID)
	-- Add to value
	targetPlayerScore.Value = targetPlayerScore.Value + 100
end

function CreateBindableFunctions()
	bindables.UpdateScore.Event:Connect(function(player: Player, ServerEntityID: number)
		print('[GameServer]: UpdateScore: received parameters = ', player, ServerEntityID)
		if not scoreTable.PlayerScoreLookup[player.Name] then return false end
		
		local targetPlayerScore = scoreTable.PlayerScoreLookup[player.Name] :: PlayerScore
		
		AddCollectedPelletAndScore(targetPlayerScore, ServerEntityID)
		
	end)
	
	bindables.GetPlayerScore.OnInvoke = function(player: Player)
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
	print('[GameServer]: BINDABLE FUNCTIONS CREATED!')
end

-- Main
function Main()
	-- Receive an event from RoundSystem
	-- Call the maze server script
	CreateScoreTable()
	CreateBindableFunctions()
end

repeat task.wait() until #Players:GetPlayers() >= 4

task.wait(1)

print('==== GameServer: GAME STARTING ====')
Main()