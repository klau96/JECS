local playerScore = {}
playerScore.__index = playerScore

export type PlayerScore = {
	Player: Player,
	PelletsCollected: {},
	NumberOfPellets: number,
	Value: number,
	
	Initialize: () -> nil,
	GetScore: () -> number,
	AddCollectedPellet: (number) -> boolean,
}

function playerScore.new(player: Player) : PlayerScore
	local self = setmetatable({}, playerScore)
	self.Player = player;
	
	self:Initialize(); -- Set initial values upon start of each round
	
	return self;
end

function playerScore:Initialize()
	self.Value = 0;
	self.PelletsCollected = {};
	self.NumberOfPellets = #self.PelletsCollected;
end

function playerScore:GetScore()
	return self.Value
end

function playerScore:AddCollectedPellet(pellet: number)
	table.insert(self.PelletsCollected, pellet)
	self.NumberOfPellets = #self.PelletsCollected;
	return true
end

return playerScore
