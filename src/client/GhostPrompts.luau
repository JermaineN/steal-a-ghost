-- Shows "Sell" on your own ghosts and "Steal" on everyone else's.
-- This only hides buttons; the server still checks every action.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local GhostPrompts = {}

local function setup(model: Model)
	local body = model:WaitForChild("Body", 10)
	local steal = body and body:WaitForChild("StealPrompt", 10)
	local sell = body and body:WaitForChild("SellPrompt", 10)
	if not steal or not sell then
		return
	end

	-- No buttons while the ghost is being carried off or is still flying in after being bought.
	local function update()
		local mine = model:GetAttribute("OwnerUserId") == player.UserId
		local busy = model:GetAttribute("Carried") == true or model:GetAttribute("Arriving") == true
		steal.Enabled = not mine and not busy
		sell.Enabled = mine and not busy
	end
	model:GetAttributeChangedSignal("Carried"):Connect(update)
	model:GetAttributeChangedSignal("Arriving"):Connect(update)
	update()
end

function GhostPrompts.start()
	CollectionService:GetInstanceAddedSignal("PlacedGhost"):Connect(function(model)
		task.spawn(setup, model)
	end)
	for _, model in CollectionService:GetTagged("PlacedGhost") do
		task.spawn(setup, model)
	end
end

return GhostPrompts
