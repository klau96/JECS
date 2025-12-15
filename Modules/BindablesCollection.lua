local bindables = {} :: Bindables

export type BindableTable = {BindableFunction | BindableEvent}

-- Note: Used to access Server Script instances 
local ScriptList = {
	GameServer = workspace:WaitForChild('GameServer') :: Script,
	MazeServer = workspace:WaitForChild('MazeServer') :: Script,
	PelletServer = workspace:WaitForChild('PelletServer') :: Script,
}

export type GameServer_Bindables = {
	GetPlayerScore 	: BindableFunction,
	UpdateScore 	: BindableEvent,
	StartGame 		: BindableEvent,
	
	MazeReady 		: BindableEvent,
	RoundAnnounce 	: BindableEvent,
	RoundOver 		: BindableEvent,
	RoundPhase		: BindableEvent,
	RoundTimer		: BindableEvent,
}

export type MazeServer_Bindables = {
	GenerateMaze: BindableFunction,
}

export type PelletServer_Bindables = {
	SpawnPellets: BindableFunction,
}


-- Note: Add Type-casting to each table entry HERE
export type Bindables = {
	GameServer: BindableTable & GameServer_Bindables, 
	MazeServer: BindableTable & MazeServer_Bindables,
	PelletServer: BindableTable & PelletServer_Bindables,
	-- TODO: Add Round Server Bindables
}

bindables = {
	--------------------------------------------
	GameServer = {
		GetPlayerScore = ScriptList.GameServer:WaitForChild('GetPlayerScore') :: BindableFunction,
		UpdateScore = ScriptList.GameServer:WaitForChild('UpdateScore') :: BindableEvent,
		StartGame = ScriptList.GameServer:WaitForChild('StartGame') :: BindableEvent,
		
		-- Used in Round System
		MazeReady= ScriptList.GameServer:WaitForChild('MazeReady') :: BindableEvent,
		RoundAnnounce = ScriptList.GameServer:WaitForChild('RoundAnnounce') :: BindableEvent,
		RoundOver = ScriptList.GameServer:WaitForChild('RoundOver') :: BindableEvent,
		RoundPhase = ScriptList.GameServer:WaitForChild('RoundPhase') :: BindableEvent,
		RoundTimer = ScriptList.GameServer:WaitForChild('RoundTimer') :: BindableEvent,
	} :: BindableTable,
	--------------------------------------------
	MazeServer = {
		GenerateMaze = ScriptList.MazeServer:WaitForChild('GenerateMaze') :: BindableFunction,
	} :: BindableTable,
	--------------------------------------------
	PelletServer = {
		SpawnPellets = ScriptList.PelletServer:WaitForChild('SpawnPellets') :: BindableFunction,
	} :: BindableTable,
	--------------------------------------------
} :: Bindables


return bindables
