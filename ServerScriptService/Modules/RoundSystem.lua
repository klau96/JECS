-- creator: n_ukes

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local TimerSystem = require(script.Parent.TimerSystem)
local bindables = require(SSS.Modules:WaitForChild("BindablesCollection"))

local LobbySpawn = workspace:WaitForChild("LobbySpawn")
local GameSpawn = workspace:WaitForChild("GameSpawn")

local MIN_PLAYERS = 2
local INTERMISSION_S = 10
local LOAD_MAP_S = 10
local READY_S = 5
local ROUND_TIME_S = 120
local POST_TIME_S = 10

local SPEEDUP = 60
local SPEED_INCREASE = 3
local MAX_SPEED = 65

local P = {
	Lobby = "Lobby",
	Intermission = "Intermission",
	Loading = "Loading",
	Ready = "Ready",
	Playing = "Playing",
	Post = "Post",
}

local M = { name = "RoundSystem", priority = 10 }

local world, C
local round

local state = {
	nextSpeedupAt = nil,
	loadingMap = false,
	lastShownSecs = {
		Lobby=-1,
		Intermission=-1,
		Loading=-1,
		Ready=-1,
		Game=-1,
		Post=-1
	}
}

-- UI emitters
local function emitPhase(phase: string, prompt: string?)
	local gs = bindables and bindables.GameServer
	if gs and gs.RoundPhase then
		gs.RoundPhase:Fire(phase, prompt or "")
	end
end

local function emitTimer(label: string, secs: number?)
	-- throttle
	local s = math.max(0, math.ceil(secs or 0))
	if state.lastShownSecs[label] == s then return end
	state.lastShownSecs[label] = s

	local gs = bindables and bindables.GameServer
	if gs and gs.RoundTimer then
		gs.RoundTimer:Fire(label, s)
	end
end

local function emitAnnounce(text: string)
	local gs = bindables and bindables.GameServer
	if gs and gs.RoundAnnounce then
		gs.RoundAnnounce:Fire(text)
	end
end

-- helpers
local function setPhase(nextPhase: string, prompt: string?)
	world:set(round, C.Gameplay.Phase, nextPhase)
	if prompt then world:set(round, C.Gameplay.Prompt, prompt) end
	emitPhase(nextPhase, prompt)
end

local function countLobbyPlayers(): number
	local n = 0
	for _ in world:query(C.Player.PlayerRef, C.Tags.InLobby):iter() do n += 1 end
	return n
end

local function speedUpPacman()
	for id, role, speed in world:query(C.Role.playerType, C.Movement.PacmanSpeed):iter() do
		if role == "Pacman" then
			local newSpeed = math.min((speed or 22) + SPEED_INCREASE, MAX_SPEED)
			if newSpeed > (speed or 0) then
				world:set(id, C.Movement.PacmanSpeed, newSpeed)
			end
		end
	end
	emitAnnounce("Pacman is speeding up!")
end

local function teleportInLobbyTo(part: BasePart)
	for id, plr in world:query(C.Player.PlayerRef, C.Tags.InLobby):iter() do
		local char = plr.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			char:PivotTo(part.CFrame + Vector3.new(0, 5, 0))
		end
		world:remove(id, C.Tags.InLobby)
		world:add(id, C.Tags.InGame)
		if not world:has(id, C.Role.Alive) then world:set(id, C.Role.Alive, true) end
	end
end

local function returnEveryoneToLobby()
	for id, plr in world:query(C.Player.PlayerRef, C.Tags.InGame):iter() do
		world:remove(id, C.Tags.InGame)
		world:add(id, C.Tags.InLobby)
		world:set(id, C.Role.playerType, "Spectator")
		world:set(id, C.Role.Alive, true)
		local char = plr.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			char:PivotTo(LobbySpawn.CFrame + Vector3.new(0, 5, 0))
		end
	end
end

-- phases
local function enterLobby()
	setPhase(P.Lobby, "Waiting for players…")
	state.nextSpeedupAt = nil
	state.loadingMap = false
	emitTimer("Lobby", 0)
end

local function enterIntermission()
	setPhase(P.Intermission, "Round starting soon…")
	TimerSystem.set(round, INTERMISSION_S)
	emitTimer("Intermission", INTERMISSION_S)
end

local function enterLoading()
	setPhase(P.Loading, "Generating maze...")
	state.loadingMap = true
	
	-- fallback guard; primary signal is GameServer:MazeReady
	TimerSystem.set(round, LOAD_MAP_S)
	emitTimer("Loading", LOAD_MAP_S)
	
	local gs = bindables and bindables.GameServer
	if gs and gs.StartGame then
		gs.StartGame:Fire()
	end
end

local function enterReady()
	teleportInLobbyTo(GameSpawn)
	setPhase(P.Ready, "Get ready…")
	TimerSystem.set(round, READY_S)
	emitTimer("Ready", READY_S)
end

local function enterPlaying()
	setPhase(P.Playing, "Survive / Hunt / Collect!")
	TimerSystem.set(round, ROUND_TIME_S)
	emitTimer("Game", ROUND_TIME_S)
	state.nextSpeedupAt = ROUND_TIME_S - SPEEDUP
end

local function enterPost(reason: string)
	setPhase(P.Post, reason)
	TimerSystem.set(round, POST_TIME_S)
	emitTimer("Post", POST_TIME_S)
end

-- external end request (still available)
function M:requestEnd(winner: "Pacman" | "Ghosts", reason: string?)
	if world:get(round, C.Gameplay.Phase) == P.Playing then
		enterPost(reason or (winner .. " win"))
	end
end

-- lifecycle
function M:init(World, Components)
	world, C = World, Components
	
	if not round or not world:contains(round) then
		round = world:entity()
	end
	world:set(round, C.Gameplay.Phase, P.Lobby)
	world:set(round, C.Gameplay.Prompt, "Waiting for players…")
	emitPhase(P.Lobby, "Waiting for players…")
	
	-- Hook GameServer signals
	local gs = bindables and bindables.GameServer
	if gs then
		if gs.MazeReady then
			gs.MazeReady.Event:Connect(function()
				if world:get(round, C.Gameplay.Phase) == P.Loading then
					state.loadingMap = false
				end
			end)
		end
		if gs.RoundOver then
			gs.RoundOver.Event:Connect(function(winner, reason)
				if world:get(round, C.Gameplay.Phase) == P.Playing then
					enterPost(reason or (tostring(winner) .. " win"))
				end
			end)
		end
	end
end

function M:step(World, Components, dt)
	world, C = World, Components
	TimerSystem.tick(dt)
	
	local phase = world:get(round, C.Gameplay.Phase)
	
	if phase == P.Lobby then
		if countLobbyPlayers() >= MIN_PLAYERS then
			enterIntermission()
		end
		
	elseif phase == P.Intermission then
		local t = TimerSystem.time(round)
		emitTimer("Intermission", t)
		if countLobbyPlayers() < MIN_PLAYERS then
			enterLobby()
		elseif TimerSystem.done(round) then
			enterLoading()
		end
		
	elseif phase == P.Loading then
		local t = TimerSystem.time(round)
		emitTimer("Loading", t)
		if not state.loadingMap or TimerSystem.done(round) then
			enterReady()
		end
		
	elseif phase == P.Ready then
		local t = TimerSystem.time(round)
		emitTimer("Ready", t)
		if TimerSystem.done(round) then
			enterPlaying()
		end
		
	elseif phase == P.Playing then
		local t = TimerSystem.time(round)
		emitTimer("Game", t)
		
		if t and state.nextSpeedupAt and t <= state.nextSpeedupAt then
			speedUpPacman()
			state.nextSpeedupAt -= SPEEDUP
		end
		
		-- Only timer-based end here; other endings come via GameServer:RoundOver
		if TimerSystem.done(round) then
			enterPost("Time's up — Ghosts win!")
		end
		
	elseif phase == P.Post then
		local t = TimerSystem.time(round)
		emitTimer("Post", t)
		if TimerSystem.done(round) then
			returnEveryoneToLobby()
			enterIntermission()
		end
	end
end

return M
