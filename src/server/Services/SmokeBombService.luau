-- The Smoke Bomb (a Shop item, used from the hotbar): click to vanish. A smoke cloud bursts where
-- you stand with a "poof", and you're invisible to everyone for GameConfig.SmokeBombSeconds. It
-- ends early if you're knocked over (bat, landmine), caged, die, pick up a stolen ghost, or take
-- the Smoke Bomb out again (selecting its hotbar slot "recasts" it to cancel); either way you
-- reappear in another puff of smoke. While invisible you can't use other items (ItemService checks the
-- "Invisible" attribute). The cooldown starts when you use it and survives respawning.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Notify = require(script.Parent.Parent.Util.Notify)
local DataService = require(script.Parent.DataService)
local RagdollService = require(script.Parent.RagdollService)

local SmokeBombService = {}

SmokeBombService.ITEM_ID = "smoke_bomb"

-- When each player's smoke bomb can next be used, in server time (workspace:GetServerTimeNow()).
local readyAt: { [Player]: number } = {}

-- What was hidden, so it can be put back exactly: { [instance] = { property, value } }.
type Hidden = { [Instance]: { property: string, value: any } }
local hiddenFor: { [Player]: Hidden } = {}

-- A burst of smoke at `position` that fades away over SmokeBombFadeSeconds, with the poof sound.
-- Everyone sees and hears it.
local function smokeCloud(position: Vector3)
	local anchor = Instance.new("Part")
	anchor.Name = "SmokeCloud"
	anchor.Size = Vector3.new(4, 5, 4)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Position = position
	anchor.Parent = workspace

	local fade = GameConfig.SmokeBombFadeSeconds
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(205, 200, 215), Color3.fromRGB(120, 112, 135))
	smoke.LightEmission = 0
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 3),
		NumberSequenceKeypoint.new(0.3, 7),
		NumberSequenceKeypoint.new(1, 9),
	})
	-- Thick at first, fading to nothing by the end of its life.
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.4, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Lifetime = NumberRange.new(fade * 0.8, fade)
	smoke.Speed = NumberRange.new(2, 6)
	smoke.Drag = 3
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-40, 40)
	smoke.Acceleration = Vector3.new(0, 1.5, 0)
	-- Puffs out for a quarter of a second. (A one-off Emit() from the server can reach players'
	-- devices before the emitter itself does, so they'd see nothing.)
	smoke.Rate = 180
	smoke.Shape = Enum.ParticleEmitterShape.Box
	smoke.Parent = anchor
	task.delay(0.25, function()
		smoke.Enabled = false
	end)

	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. GameConfig.SmokeBombSound.soundId
	sound.Volume = GameConfig.SmokeBombSound.volume
	sound.RollOffMaxDistance = 120
	sound.Parent = anchor
	sound:Play()

	Debris:AddItem(anchor, fade + 1)
end

-- Hides every visible thing on the character (body, accessories, face, name and any wanted tag)
-- and remembers how it was.
local function hide(player: Player, character: Model)
	local hidden: Hidden = {}
	local function set(instance: Instance, property: string, value: any)
		if hidden[instance] == nil then
			hidden[instance] = { property = property, value = (instance :: any)[property] }
		end
		(instance :: any)[property] = value
	end
	for _, item in character:GetDescendants() do
		if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" then
			set(item, "Transparency", 1)
		elseif item:IsA("Decal") then
			set(item, "Transparency", 1)
		elseif item:IsA("BillboardGui") or item:IsA("Highlight") then
			set(item, "Enabled", false)
		elseif item:IsA("Humanoid") then
			set(item, "DisplayDistanceType", Enum.HumanoidDisplayDistanceType.None)
		end
	end
	hiddenFor[player] = hidden
end

local function show(player: Player)
	for instance, saved in hiddenFor[player] or {} do
		if instance.Parent then
			(instance :: any)[saved.property] = saved.value
		end
	end
	hiddenFor[player] = nil
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Ends the invisibility (time's up, knocked, caged, died): another puff where they are now.
local function reappear(player: Player)
	if not player:GetAttribute("Invisible") then
		return
	end
	player:SetAttribute("Invisible", nil)
	local root = rootOf(player)
	if root then
		smokeCloud(root.Position)
	end
	show(player)
end

-- Called by ItemService when a player clicks while holding the smoke bomb.
function SmokeBombService.tryUse(player: Player, tool: Tool)
	local character = player.Character
	local root = rootOf(player)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	if
		DataService.getItemCount(player, SmokeBombService.ITEM_ID) <= 0
		or player:GetAttribute("Invisible")
		or player:GetAttribute("Caged")
		or player:GetAttribute("Carrying")
		or RagdollService.isRagdolled(player)
	then
		return
	end
	local now = workspace:GetServerTimeNow()
	local waitLeft = (readyAt[player] or 0) - now
	if waitLeft > 0 then
		Notify.send(player, "Smoke Bomb ready in " .. math.ceil(waitLeft) .. "s", "error")
		return
	end
	readyAt[player] = now + GameConfig.SmokeBombCooldownSeconds
	tool:SetAttribute("ReadyAt", readyAt[player]) -- the hotbar shows the cooldown from this

	-- Poof: put the bomb away (no items while invisible) and vanish.
	humanoid:UnequipTools()
	smokeCloud(root.Position)
	hide(player, character)
	player:SetAttribute("Invisible", true)

	-- Watch for the end: time's up, knocked over, caged, stole a ghost, recast, died, respawned
	-- or left.
	local endsAt = os.clock() + GameConfig.SmokeBombSeconds
	task.spawn(function()
		while player.Parent and player:GetAttribute("Invisible") do
			local stillHere = player.Character == character and humanoid.Health > 0
			if
				not stillHere
				or os.clock() >= endsAt
				or RagdollService.isRagdolled(player)
				or player:GetAttribute("Caged")
				or player:GetAttribute("Carrying")
			then
				break
			end
			-- Taking the Smoke Bomb out again cancels it; no other items while invisible (a held
			-- tool would also show).
			local held = character:FindFirstChildOfClass("Tool")
			if held and held.Name == SmokeBombService.ITEM_ID then
				break
			elseif held then
				humanoid:UnequipTools()
			end
			RunService.Heartbeat:Wait()
		end
		if player.Parent then
			reappear(player)
		end
	end)
end

-- The smoke bomb's cooldown for a new copy of the tool (after respawning).
function SmokeBombService.readyAt(player: Player): number?
	return readyAt[player]
end

function SmokeBombService.start()
	Players.PlayerRemoving:Connect(function(player)
		readyAt[player] = nil
		hiddenFor[player] = nil
	end)
end

return SmokeBombService
