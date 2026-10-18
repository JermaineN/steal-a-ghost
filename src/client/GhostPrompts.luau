-- Shows "Sell" on your own ghosts and "Steal" on everyone else's, or "Capture" instead of
-- "Steal" while you hold the PolterPuller 4000.
-- This only hides buttons; the server still checks every action.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local GhostPrompts = {}

local VACUUM = "polterpuller" -- the PolterPuller 4000's tool name (its item id)

local function holdingVacuum(): boolean
	return player.Character ~= nil and player.Character:FindFirstChild(VACUUM) ~= nil
end

-- Every ghost's update function, so they can all refresh when you take the vacuum out or put it away.
local updaters: { [Model]: () -> () } = {}

local function setup(model: Model)
	local body = model:WaitForChild("Body", 10)
	local steal = body and body:WaitForChild("StealPrompt", 10)
	local sell = body and body:WaitForChild("SellPrompt", 10)
	if not steal or not sell then
		return
	end
	local capture = body:FindFirstChild("CapturePrompt") :: ProximityPrompt?

	-- Only on a ghost still flying to its base after being bought (see server GhostService).
	local rebuy = body:FindFirstChild("RebuyPrompt") :: ProximityPrompt?

	-- No Steal/Capture/Sell while the ghost is being carried off, captured or is still flying in
	-- after being bought; while it flies, everyone but its owner can buy it out from under them.
	local function update()
		local mine = model:GetAttribute("OwnerUserId") == player.UserId
		local arriving = model:GetAttribute("Arriving") == true
		local busy = model:GetAttribute("Carried") == true or model:GetAttribute("Capturing") == true or arriving
		local vacuum = holdingVacuum()
		steal.Enabled = not mine and not busy and not vacuum
		sell.Enabled = mine and not busy
		if capture then
			capture.Enabled = not mine and not busy and vacuum
		end
		if rebuy and rebuy.Parent then
			rebuy.Enabled = not mine and arriving
		end
	end
	model:GetAttributeChangedSignal("Carried"):Connect(update)
	model:GetAttributeChangedSignal("Arriving"):Connect(update)
	model:GetAttributeChangedSignal("Capturing"):Connect(update)
	updaters[model] = update
	model.Destroying:Connect(function()
		updaters[model] = nil
	end)
	update()
end

local function updateAll()
	for _, update in updaters do
		update()
	end
end

function GhostPrompts.start()
	CollectionService:GetInstanceAddedSignal("PlacedGhost"):Connect(function(model)
		task.spawn(setup, model)
	end)
	for _, model in CollectionService:GetTagged("PlacedGhost") do
		task.spawn(setup, model)
	end

	-- Holding a tool means it's in your character, so watch what comes and goes there.
	local function watch(character: Model)
		character.ChildAdded:Connect(function(child)
			if child.Name == VACUUM then
				updateAll()
			end
		end)
		character.ChildRemoved:Connect(function(child)
			if child.Name == VACUUM then
				updateAll()
			end
		end)
		updateAll()
	end
	player.CharacterAdded:Connect(watch)
	if player.Character then
		watch(player.Character)
	end
end

return GhostPrompts
