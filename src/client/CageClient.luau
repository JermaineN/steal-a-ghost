-- Lets you walk through cages you cast. Your own device moves your character, so turning off a
-- cage's collision here (only on your screen) lets you pass through it, while it stays solid for
-- everyone else. The server marks each cage with its caster's UserId (CageService).
local Players = game:GetService("Players")

local CageClient = {}

local function onCage(cage: Instance)
	if cage:GetAttribute("CasterUserId") ~= Players.LocalPlayer.UserId then
		return
	end
	-- The cage's parts may still be arriving from the server, so catch late ones too.
	local function makePassable(part: Instance)
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
	for _, part in cage:GetDescendants() do
		makePassable(part)
	end
	cage.DescendantAdded:Connect(makePassable)
end

function CageClient.start()
	local cages = workspace:WaitForChild("Cages")
	cages.ChildAdded:Connect(onCage)
	for _, cage in cages:GetChildren() do
		onCage(cage)
	end
end

return CageClient
