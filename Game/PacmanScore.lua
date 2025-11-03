local pacmanScore = {}
pacmanScore.__index = pacmanScore

export type PacmanScore = {
	Player: Player,
	Value: number,
	Initialize: () -> nil,
	GetScore: () -> number,
}

function pacmanScore.new(player: Player)
	local self = setmetatable({}, pacmanScore)
	self.Player = player;
	
	self:Initialize()
	
	return self
end

function pacmanScore:Initialize()
	self.Value = 0;
end

function pacmanScore:GetScore()
	return self.Value
end

return pacmanScore
