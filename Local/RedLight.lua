local RunService = game:GetService('RunService')

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild('Humanoid') :: Humanoid
local hroot = character:WaitForChild('HumanoidRootPart') :: Part

local light = nil :: SpotLight

function createRedLight()
	local light = Instance.new('SpotLight')
	light.Face = Enum.NormalId.Front
	light.Color = Color3.new(1, 0, 0)
	light.Brightness = 10
	light.Range = 50
	light.Shadows = false
	light.Parent = hroot
	light.Enabled = true
	return light
end

--function updateRedLight()
--	light.Angle = math.deg(90)
--end

light = createRedLight()

player.Chatted:Connect(function(message: string, recipient: Player)
	print('Chatted: ', message, message == "/morph pacman")
	if string.lower(message) == "/morph pacman" then
		print('>>>> LIGHT PARENT = ', light.Parent)
		light.Enabled = true
	end
end)


--RunService.Heartbeat:Connect(function(deltaTime: number)
--	updateRedLight()
--end)