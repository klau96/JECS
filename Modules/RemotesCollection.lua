local remotes = {}

-- Types
export type RemotesTable = {RemoteEvent | RemoteFunction}

export type PelletServer_Remotes = {
	InitializePellets: RemoteFunction,
	UpdatePellets: RemoteEvent,
}

export type Remotes = {
	PelletServer: RemotesTable & PelletServer_Remotes,
}

-- Variables
local ScriptList = {
	PelletServer = workspace:WaitForChild('PelletServer') :: Script,
}

-- Module
remotes = {
	--------------------------------------------
	PelletServer = {
		InitializePellets = ScriptList.PelletServer:WaitForChild('InitializePellets') :: RemoteFunction,
		UpdatePellet = ScriptList.PelletServer:WaitForChild('UpdatePellet') :: RemoteEvent,
	} :: RemotesTable,
	--------------------------------------------
} :: Remotes

return remotes
