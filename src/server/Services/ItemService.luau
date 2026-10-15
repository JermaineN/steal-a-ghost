-- Items: tools that sit in each player's inventory (Roblox's built-in Backpack, the hotbar at the
-- bottom of the screen). Number keys equip/unequip them: slot 1 is the first tool, and so on.
-- Every player starts with a Bat in slot 1. A hit knocks the player over (RagdollService), and a
-- thief who gets hit drops the stolen ghost, which flies home.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPack = game:GetService("StarterPack")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Notify = require(script.Parent.Parent.Util.Notify)
local RagdollService = require(script.Parent.RagdollService)
local StealService = require(script.Parent.StealService)

local ItemService = {}

local lastSwing: { [Player]: number } = {}

local function getAliveRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return root :: BasePart
	end
	return nil
end

local function hitPlayer(swinger: Player, target: Player, direction: Vector3)
	local carry = StealService.getCarry(target)
	if carry then
		local owner = carry.owner
		StealService.returnGhost(target, swinger.DisplayName .. " bonked you! The ghost flew home.")
		if owner == swinger then
			Notify.send(owner, "You got your ghost back!", "success")
		else
			Notify.send(swinger, "You bonked a thief!", "success")
			Notify.send(owner, swinger.DisplayName .. " got your ghost back!", "success")
		end
	end
	local push = direction * GameConfig.BatKnockbackSpeed + Vector3.new(0, GameConfig.BatKnockbackLift, 0)
	RagdollService.knock(target, push)
end

-- The bonk, played from the hit player so everyone nearby hears it. A sound played on the
-- server is heard by every player.
local function playBonk(target: Player)
	local root = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local config = GameConfig.BatHitSound
	local sound = Instance.new("Sound")
	sound.Name = "Bonk"
	sound.SoundId = "rbxassetid://" .. config.soundId
	sound.Volume = config.volume
	sound.PlaybackSpeed = config.pitch
	sound.Parent = root
	sound:Play()
	Debris:AddItem(sound, 4)
end

-- The moment the bat reaches the front: hits everyone within reach and roughly in front of the
-- swinger, using server positions.
local function checkHits(swinger: Player, tool: Tool)
	local root = getAliveRoot(swinger)
	-- They may have put the bat away or been knocked over during the wind-up.
	if not root or tool.Parent ~= swinger.Character or RagdollService.isRagdolled(swinger) then
		return
	end
	for _, target in Players:GetPlayers() do
		local targetRoot = getAliveRoot(target)
		if target == swinger or not targetRoot or not RagdollService.canKnock(target) then
			continue
		end
		local offset = targetRoot.Position - root.Position
		local flat = Vector3.new(offset.X, 0, offset.Z)
		local inFront = flat.Magnitude < 2 or root.CFrame.LookVector:Dot(flat.Unit) > 0
		if offset.Magnitude <= GameConfig.BatRange and inFront then
			-- Push away from the swinger (straight ahead of them if standing on top of each other).
			local direction = if flat.Magnitude > 0.1 then flat.Unit else root.CFrame.LookVector
			playBonk(target)
			hitPlayer(swinger, target, direction)
		end
	end
end

-- Called on the server when a player swings their bat (clicks while it's equipped).
local function swing(tool: Tool)
	local character = tool.Parent
	local swinger = Players:GetPlayerFromCharacter(character)
	if not swinger or RagdollService.isRagdolled(swinger) then
		return
	end
	local now = os.clock()
	if now - (lastSwing[swinger] or 0) < GameConfig.BatSwingCooldown then
		return
	end
	lastSwing[swinger] = now

	-- Everyone else plays the swing animation (BatSwing on the client); the swinger's own device
	-- already started it the moment they clicked.
	for _, other in Players:GetPlayers() do
		if other ~= swinger then
			Remotes.BatSwing:FireClient(other, character)
		end
	end
	task.delay(GameConfig.BatHitDelay, checkHits, swinger, tool)
end

-- Builds the bat: a thin grip (the Handle, which the hand holds) and a thicker barrel.
local function buildBat(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Bat"
	tool.ToolTip = "Click to swing. Bonk thieves to get your ghost back"
	tool.TextureId = GameConfig.BatIcon -- the picture in the hotbar
	tool.CanBeDropped = false -- otherwise Backspace drops it on the ground
	-- Where the hand holds the grip; the tilt points the bat up instead of straight ahead.
	tool.Grip = CFrame.new(0, 0, 0.6) * CFrame.Angles(math.rad(-60), 0, 0)

	local wood = Color3.fromRGB(150, 100, 60)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 1.6)
	handle.Color = Color3.fromRGB(60, 40, 30) -- dark tape on the grip
	handle.Material = Enum.Material.Fabric
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local barrel = Instance.new("Part")
	barrel.Name = "Barrel"
	barrel.Size = Vector3.new(0.5, 0.5, 2.6)
	barrel.Color = wood
	barrel.Material = Enum.Material.Wood
	barrel.CanCollide = false
	barrel.Massless = true
	-- The barrel sticks out past the grip, away from the hand.
	barrel.CFrame = handle.CFrame * CFrame.new(0, 0, -(handle.Size.Z + barrel.Size.Z) / 2)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = barrel
	weld.Parent = barrel
	barrel.Parent = tool

	return tool
end

function ItemService.start()
	-- StarterPack is copied into every player's Backpack each time their character spawns,
	-- so the bat comes back after a respawn.
	local bat = buildBat()
	bat.Parent = StarterPack

	-- Tool.Activated fires on the server too, so each copy of the bat is wired up here.
	local function onToolAdded(item: Instance)
		if item:IsA("Tool") and item.Name == "Bat" and not item:GetAttribute("Wired") then
			item:SetAttribute("Wired", true)
			item.Activated:Connect(function()
				swing(item)
			end)
		end
	end
	-- Each spawn gives the player a brand-new Backpack, so watch for those too.
	local function onBackpack(backpack: Instance)
		if backpack:IsA("Backpack") then
			backpack.ChildAdded:Connect(onToolAdded)
			for _, item in backpack:GetChildren() do
				onToolAdded(item)
			end
		end
	end
	local function watchBackpack(player: Player)
		player.ChildAdded:Connect(onBackpack)
		for _, child in player:GetChildren() do
			onBackpack(child)
		end
	end
	Players.PlayerAdded:Connect(watchBackpack)
	for _, player in Players:GetPlayers() do
		watchBackpack(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
	end)
end

return ItemService
