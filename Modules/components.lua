local jecs = require(game:GetService("ReplicatedStorage").Shared.jecs)
local world = require(game:GetService("ReplicatedStorage").Shared.world)

type Entity<T = nil> = jecs.Entity<T>

local Components = {}

Components.Player = {
	PlayerRef = world:component() :: Entity<Player>,
	Wins = world:component() :: Entity<number>,
	PlayerIndex = world:component() :: Entity<number>,
}

Components.Gameplay = {
	Phase = world:component() :: Entity<string>,
	Prompt = world:component() :: Entity<string>,
	Timer = world:component() :: Entity<number>,
}

Components.Tags = {
	InLobby = jecs.tag(),
	InGame = jecs.tag(),
	AFK = jecs.tag(),
	Grabbable = jecs.tag(),
}

Components.Pellet = {
	Tag = jecs.tag(),
	Position  = world:component() :: Entity<Vector3>,
	ChunkHash = world:component() :: Entity<string>,
	Collected = world:component() :: Entity<boolean>,
	NetId = world:component() :: Entity<number>,
}

Components.Combat = {
	Grabber = jecs.tag(),
	Grabbed = jecs.tag(),
	Grabbing = world:component() :: Entity<boolean>,
	GrabEndAt = world:component() :: Entity<number>,
	GrabTargetRef = world:component() :: Entity<Instance | number>,
	GrabCooldownUntil = world:component() :: Entity<number>,
	GrabIntent = world:component() :: Entity<boolean>,
	GrabRange = world:component() :: Entity<number>,
}

Components.Character = {
	HumanoidRef = world:component() :: Entity<Humanoid>,
	RootRef = world:component() :: Entity<BasePart>,
}

Components.Role = {
	playerType = world:component() :: Entity<"Ghost" | "Pacman" | "Spectator">,
	Alive = world:component() :: Entity<boolean>,
}

Components.Input = {
	Sprint = world:component() :: Entity<boolean>,
	CrawlToggle = world:component() :: Entity<boolean>,
}

Components.Movement = {
	BaseSpeed = world:component() :: Entity<number>,
	SprintSpeed = world:component() :: Entity<number>,
	CrawlSpeed = world:component() :: Entity<number>,
	
	SprintCooldown = world:component() :: Entity<number>,
	CrawlCooldown = world:component() :: Entity<number>,
	
	PacmanSpeed = world:component() :: Entity<number>,
	
	OnGround = world:component() :: Entity<boolean>,
	Running = world:component() :: Entity<boolean>,
	Crawling = world:component() :: Entity<boolean>,
	
	Airborne = world:component() :: Entity<boolean>,
	AirState = world:component() :: Entity<Enum.HumanoidStateType | nil>,
}

Components.Stamina = {
	Value = world:component() :: Entity<number>,
	Max = world:component() :: Entity<number>,
	DrainPerSec = world:component() :: Entity<number>,
	RegenPerSec = world:component() :: Entity<number>,
	RegenDelay = world:component() :: Entity<number>,
	MinToSprint = world:component() :: Entity<number>,
	ExhaustTill = world:component() :: Entity<number>,
	LastStop = world:component() :: Entity<number>,
}

Components.Morph = {
	IsPacman = world:component() :: Entity<boolean>,
	Request = world:component() :: Entity<"ToPacman" | "Restore">,
	AppliedRole = world:component() :: Entity<"Pacman" | "Spectator">,
}

return Components