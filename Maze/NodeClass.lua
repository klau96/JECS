local nodeClass = {};
nodeClass.__index = nodeClass;
nodeClass.startColor = Color3.new(0.950042, 0.894057, 0);
nodeClass.normalColor = Color3.new(0.207843, 0.207843, 0.207843);
nodeClass.highlightColor = Color3.new(0.934203, 0.13724, 0.254231);
nodeClass.pointerColor = Color3.new(0.309804, 1, 0.470588);

function nodeClass.new(i, j, w, h, boardW)
	local self = setmetatable({}, nodeClass);
	self.i = i;
	self.j = j;
	
	self.x = j * w;
	self.y = i * w;
	
	self.wallColour = nodeClass.startColor;
	
	if self.x == w and self.y == w then
		self.wallColour = nodeClass.normalColor
	end
	
	self.w = w;
	self.boardW = boardW;
	
	self.h = h;
	self.stroke = 3;
	
	self.visited = false;
	
	self.walls = {};
	
	self.regionOrigin = nil :: Vector3
	return self;
end

function nodeClass:changeWallColours()
	for i, v: BasePart in pairs(self.walls) do
		v.Color = nodeClass.normalColor;
		v.Material = Enum.Material.Slate
	end
end

function nodeClass:spawnWalls()
	--TOP WALL
	self:createWall(Vector3.new(self.w,self.h, self.stroke), Vector3.new(self.x, 			0, self.y - self.w/2), "TOP");
	--LEFT WALL
	self:createWall(Vector3.new(self.stroke,self.h, self.w), Vector3.new(self.x - self.w/2, 0, self.y), "LEFT");
	--BOTTOM WALL
	self:createWall(Vector3.new(self.w,self.h, self.stroke), Vector3.new(self.x, 			0, self.y + self.w/2), "BOTTOM");
	--RIGHT WALL
	self:createWall(Vector3.new(self.stroke,self.h, self.w), Vector3.new(self.x + self.w/2, 0, self.y), "RIGHT");
end

function nodeClass:createWall(size, position, name)
	local wall = Instance.new("Part");
	wall.Anchored = true;
	wall.Name = name;
	wall.Size = size;
	wall.Position = position + self.regionOrigin - Vector3.new(self.w/2, 0, self.w/2);
	wall.CanCollide = true
	wall.Parent = game.Workspace;
	wall.Color = self.wallColour;
	wall.Material = Enum.Material.SmoothPlastic;
	table.insert(self.walls, wall);
end

function nodeClass:calculateStackNodeIndex(i ,j)
	if i < 1 or j < 1 or i > self.boardW or j > self.boardW then
		return "nil";
	end
	return (j + (i-1) * self.boardW);
end

function nodeClass:checkNeighbors(nodes)
	local neighbors = {}
	
	local bottom = nodes[self:calculateStackNodeIndex(self.i, self.j+1)];
	
	local left = nodes[self:calculateStackNodeIndex(self.i-1, self.j)];
	
	local top = nodes[self:calculateStackNodeIndex(self.i, self.j-1)];

	local right = nodes[self:calculateStackNodeIndex(self.i+1, self.j)];
	
	if top ~= nil and not top.visited then
		table.insert(neighbors, top);
	end
	if right ~= nil and not right.visited then
		table.insert(neighbors, right);
	end
	if bottom ~= nil and not bottom.visited then
		table.insert(neighbors, bottom);
	end
	if left ~= nil and not left.visited then
		table.insert(neighbors, left);
	end
	
	if #neighbors > 0 then
		local randomNeighbour = neighbors[math.random(1, #neighbors)];
		local index = table.find(nodes, randomNeighbour)
		return neighbors[math.random(1, #neighbors)], index;
	else
		return nil, nil;
	end

end

return nodeClass;
