-- Services
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ServerScriptService = game:GetService('ServerScriptService')
local TweenService = game:GetService('TweenService')

-- Modules
local NodeClassModule = require(script.Parent:WaitForChild('NodeClass'))
export type NodeClass = typeof(NodeClassModule.new()) 

local SoundModule = require(ReplicatedStorage.Modules:WaitForChild('Sound'))

local pointer = {}
pointer.__index = pointer;
pointer.pointerColor = Color3.new(0.309804, 1, 0.470588);

-- Export Type
export type Pointer = {
	Instance: Part,
	light: PointLight,
	NodeSettings: {
		cellW: number,
		h: number,
	},
	createPointerInstance: (self: Pointer) -> Part,
	CreatePointLight: (self: Pointer) -> nil,
	PlayEndTweenLoop: (self: Pointer) -> nil,
}

-- Constructor
function pointer.new(cellW:number, h:number) : Pointer
	local self = setmetatable({}, pointer) :: Pointer
	self.Instance = nil
	self.NodeSettings = {}
	self.NodeSettings.cellW = cellW
	self.NodeSettings.h = h
	
	self.Instance = nil :: Part
	
	return self;
end

function pointer:createPointerInstance() : Part
	local ptr = Instance.new("Part")
	ptr.Size = Vector3.new(self.NodeSettings.cellW, self.NodeSettings.h, self.NodeSettings.cellW);
	pointer = ptr
	ptr.Anchored = true;
	ptr.CanCollide = false;
	ptr.Material = Enum.Material.Neon;
	ptr.Parent = workspace;
	ptr.Color = self.pointerColor;
	ptr.Name = "PointerPart"

	local att = Instance.new("Attachment")
	att.Name = "Attachment"
	att.Parent = pointer
	
	self.Instance = ptr
	return self.Instance
end

function pointer:setPointerPosition(current: NodeClass)
	self.Instance.Position = Vector3.new(current.x, 0, current.y) + current.regionOriginPosition - Vector3.new(current.w/2, 0, current.w/2)
	SoundModule.PlaySoundAtLocation(SoundModule.boop, self.Instance.Position)
end

function pointer:CreatePointLight()
	local light = Instance.new('PointLight')
	light.Brightness = 1
	light.Color = self.pointerColor
	light.Range = 16
	light.Parent = self.Instance
	self.light = light
	return light
end

--[[
	Description:
		At the end of pointer operations,
		Make a repeating tween that makes the pointer small
]]
function pointer:PlayEndTweenLoop()
	local pos = self.Instance.Position :: Vector3
	local newPos = Vector3.new(pos.X, pos.Y+10, pos.Z)
	local targetSize = Vector3.new(4, 4, 4)
	
	self:CreatePointLight()
	
	local TweenSmall = TweenService:Create(
		self.Instance,
		TweenInfo.new(
			4,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.InOut,
			0,
			false
		),
		{	Size=targetSize,
			Position=newPos
		}
	)
	
	local TweenOscillate = TweenService:Create(
		self.Instance,
		TweenInfo.new(
			2,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.InOut,
			-1, 
			true
		),
		{
			Position = newPos + Vector3.new(0, 1, 0)
		}
	)
	local TweenRotate = TweenService:Create(
		self.Instance,
		TweenInfo.new(
			3,
			Enum.EasingStyle.Linear,
			Enum.EasingDirection.In,
			-1, 
			false
		),
		{
			Orientation = self.Instance.Orientation + Vector3.new(0, 360, 0)
		}
	)
	
	
	TweenSmall:Play()
	TweenSmall.Completed:Connect(function()
		TweenOscillate:Play()
		TweenRotate:Play()
	end)
end

return pointer
