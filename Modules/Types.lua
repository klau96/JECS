--[[
Module to define type definitions for data structures

spaghetti code by ininja966

]]

local types = {}

-- Used by: GameServer
export type ScoreTable = {
	PlayerList: {Player},
	SurvivorList: {Player},
	Pacman: Player?,

	PlayerScoreLookup: {
		[string]: PlayerScore
	},
	PacmanScore: PacmanScore?,
}

-- Used by: MazeServer
export type NodeInfo = {
	CenterPosition: Vector3,
	i: number,
	j: number,
}
export type MazeInformation = {
	Corners: {NodeInfo},
	PacmanSpawnPosition: NodeInfo,
}

return types
