local bindables = {} :: Bindables

export type BindableTable = {BindableFunction | BindableEvent}

export type GameServer_Bindables = {
	GetPlayerScore: BindableFunction,
	UpdateScore: BindableEvent,
	StartGame: BindableEvent,
}

export type MazeServer_Bindables = {
	GenerateMaze: BindableFunction,
}

-- Note: Uses combination type casting
export type Bindables = {
	GameServer: BindableTable & GameServer_Bindables, 
	MazeServer: BindableTable & MazeServer_Bindables,
	PelletServer: BindableTable,
	-- TODO: Add Round Server
}

local ScriptList = {
	GameServer = workspace:WaitForChild('GameServer') :: Script,
	MazeServer = workspace:WaitForChild('MazeServer') :: Script,
	PelletServer = workspace:WaitForChild('PelletServer') :: Script,
}

bindables = {
	--------------------------------------------
	GameServer = {
		GetPlayerScore = ScriptList.GameServer:WaitForChild('GetPlayerScore') :: BindableFunction,
		UpdateScore = ScriptList.GameServer:WaitForChild('UpdateScore') :: BindableEvent,
		StartGame = ScriptList.GameServer:WaitForChild('StartGame') :: BindableEvent,
	} :: BindableTable,
	--------------------------------------------
	MazeServer = {
		GenerateMaze = ScriptList.MazeServer:WaitForChild('GenerateMaze') :: BindableFunction,
	} :: BindableTable,
	--------------------------------------------
	PelletServer = {
		
	} :: BindableTable,
	--------------------------------------------
} :: Bindables



return bindables
