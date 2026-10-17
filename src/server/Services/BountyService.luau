-- Wanted and bounties. Each successful steal adds to the thief's streak and bounty pool;
-- being stopped (StealService calls onStopped: hit, caught by the lock, dying) resets them.
-- At GameConfig.WantedStreak steals in a row the thief becomes WANTED: everyone is told, their
-- character glows red with a "WANTED" tag over their head, and the bounty keeps growing with
-- every further steal. The first player to hit them (StealService.knockLoose calls onHit) claims
-- it, paid from the thief's own cash (so friends can't farm free money). Nothing is saved:
-- leaving clears it.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Notify = require(script.Parent.Parent.Util.Notify)
local DataService = require(script.Parent.DataService)

local BountyService = {}

local WANTED_RED = Color3.fromRGB(255, 40, 50)
local BOUNTY_YELLOW = Color3.fromRGB(255, 220, 60)

type State = { streak: number, bounty: number, characterConnection: RBXScriptConnection? }
local states: { [Player]: State } = {}

local function stateFor(player: Player): State
	local state = states[player]
	if not state then
		state = { streak = 0, bounty = 0 }
		states[player] = state
	end
	return state
end

local function isWanted(player: Player): boolean
	return player:GetAttribute("Wanted") == true
end

local function notifyAll(message: string, kind: string)
	for _, player in Players:GetPlayers() do
		Notify.send(player, message, kind)
	end
end

-- The red glow and the "WANTED / $X BOUNTY" tag over the head, seen by everyone.
local function decorate(character: Model, bounty: number)
	local old = character:FindFirstChild("WantedTag")
	if old then
		old:Destroy()
	end
	if not character:FindFirstChild("WantedGlow") then
		local glow = Instance.new("Highlight")
		glow.Name = "WantedGlow"
		glow.FillColor = WANTED_RED
		glow.FillTransparency = 0.75
		glow.OutlineColor = WANTED_RED
		glow.Parent = character
	end
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = "WantedTag"
	tag.Adornee = head
	tag.Size = UDim2.fromOffset(220, 70)
	tag.StudsOffset = Vector3.new(0, 3.2, 0)
	tag.AlwaysOnTop = true
	tag.MaxDistance = 250
	tag.LightInfluence = 0
	local function line(text: string, y: number, height: number, color: Color3): TextLabel
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(0, y)
		label.Size = UDim2.new(1, 0, 0, height)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = color
		label.Text = text
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Thickness = 3
		stroke.Parent = label
		label.Parent = tag
		return label
	end
	local wanted = line("WANTED", 0, 40, Color3.new(1, 1, 1))
	-- Red-and-yellow shimmer (clients animate tagged gradients, see client GradientAnimator).
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, WANTED_RED),
		ColorSequenceKeypoint.new(0.5, BOUNTY_YELLOW),
		ColorSequenceKeypoint.new(1, WANTED_RED),
	})
	gradient.Parent = wanted
	CollectionService:AddTag(gradient, "AnimatedGradient")
	line("$" .. Format.cash(bounty) .. " BOUNTY", 40, 28, BOUNTY_YELLOW)
	tag.Parent = character
end

local function undecorate(character: Model?)
	if not character then
		return
	end
	for _, name in { "WantedTag", "WantedGlow" } do
		local item = character:FindFirstChild(name)
		if item then
			item:Destroy()
		end
	end
end

local function setWanted(player: Player, state: State)
	player:SetAttribute("Wanted", true)
	player:SetAttribute("Bounty", state.bounty)
	if player.Character then
		decorate(player.Character, state.bounty)
	end
	-- Keep the look after respawning.
	if not state.characterConnection then
		state.characterConnection = player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 10)
			if isWanted(player) then
				decorate(character, states[player].bounty)
			end
		end)
	end
end

local function clear(player: Player)
	local state = states[player]
	if state then
		state.streak = 0
		state.bounty = 0
		if state.characterConnection then
			state.characterConnection:Disconnect()
			state.characterConnection = nil
		end
	end
	if isWanted(player) then
		player:SetAttribute("Wanted", nil)
		player:SetAttribute("Bounty", nil)
		undecorate(player.Character)
	end
end

-- A steal was delivered: the thief's streak and bounty grow (`price` is the ghost's price).
function BountyService.onSteal(thief: Player, price: number)
	local state = stateFor(thief)
	state.streak += 1
	state.bounty += math.floor(price * GameConfig.BountyShare)
	if isWanted(thief) then
		setWanted(thief, state) -- refresh the bounty shown over their head
	elseif state.streak >= GameConfig.WantedStreak then
		setWanted(thief, state)
		notifyAll(`{thief.DisplayName} is WANTED! Bonk them to claim the ${Format.cash(state.bounty)} bounty!`, "error")
	end
end

-- A steal was stopped (hit, the base locked, they died): the streak starts over. A wanted thief
-- stays wanted (only a hit claims the bounty).
function BountyService.onStopped(thief: Player)
	local state = states[thief]
	if state and not isWanted(thief) then
		state.streak = 0
		state.bounty = 0
	end
end

-- `attacker` hit `victim` with an item. If the victim is wanted, the attacker claims the bounty.
function BountyService.onHit(attacker: Player, victim: Player)
	if attacker == victim or not isWanted(victim) then
		return
	end
	local bounty = states[victim] and states[victim].bounty or 0
	-- Paid from the thief's own cash (as much as they have).
	local paid = math.min(bounty, math.max(DataService.getCash(victim), 0))
	DataService.addCash(victim, -paid)
	DataService.addCash(attacker, paid)
	clear(victim)
	notifyAll(`{attacker.DisplayName} claimed the ${Format.cash(paid)} bounty on {victim.DisplayName}!`, "success")
end

function BountyService.playerRemoving(player: Player)
	clear(player)
	states[player] = nil
end

return BountyService
