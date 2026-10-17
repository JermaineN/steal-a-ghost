-- The Universal Key (a Shop item, used from the hotbar): click near someone's locked base to
-- unlock it. The owner is told straight away, then the unlock takes UniversalKeyUnlockSeconds:
-- the bars rattle and a key with a filling progress bar hangs over the gate, so everyone can see
-- who's breaking in. When it finishes, the lock ends (PlotService.forceUnlock). It's cancelled
-- if the key user is knocked over, caged, dies or walks away from the gate, or the lock ends by
-- itself first. The cooldown starts when the unlock begins.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Notify = require(script.Parent.Parent.Util.Notify)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local RagdollService = require(script.Parent.RagdollService)

local UniversalKeyService = {}

UniversalKeyService.ITEM_ID = "universal_key"

local GOLD = Color3.fromRGB(255, 190, 40)
local TEXT_OUTLINE = Color3.fromRGB(20, 8, 30)

local readyAt: { [Player]: number } = {}
local busy: { [Player]: boolean } = {} -- an unlock in progress

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- How far `position` is from a base's gate (its lock wall), ignoring height.
local function distanceToGate(plot, position: Vector3): number
	local gate = plot.lockWall.Position
	return (Vector3.new(gate.X, 0, gate.Z) - Vector3.new(position.X, 0, position.Z)).Magnitude
end

-- The closest locked base (not the player's own) whose gate is within reach.
local function lockedGateNear(player: Player, position: Vector3)
	local best, bestDistance = nil, GameConfig.UniversalKeyRange
	for _, plot in PlotService.getPlots() do
		if plot.owner and plot.owner ~= player and PlotService.isLocked(plot) then
			local distance = distanceToGate(plot, position)
			if distance <= bestDistance then
				best, bestDistance = plot, distance
			end
		end
	end
	return best
end

local function playSound(parent: Instance, config): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. config.soundId
	sound.Volume = config.volume
	sound.RollOffMaxDistance = 100
	sound.Parent = parent
	sound:Play()
	return sound
end

-- A gold key icon with a progress bar, hanging over the gate for everyone to see. Returns the
-- holder part, and the bar's fill (tweened to full over the unlock time).
local function buildProgress(plot, keyUser: Player): (Part, Frame)
	local anchor = Instance.new("Part")
	anchor.Name = "KeyProgress"
	anchor.Size = Vector3.one
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CFrame = plot.lockWall.CFrame * CFrame.new(0, 3, 0)
	anchor.Parent = workspace

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(230, 92)
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	gui.Parent = anchor

	local icon = Instance.new("ImageLabel")
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.fromScale(0.5, 0)
	icon.Size = UDim2.fromOffset(44, 44)
	icon.BackgroundTransparency = 1
	icon.Image = GameConfig.UniversalKeyIcon
	icon.Parent = gui
	-- The key jiggles while it works.
	TweenService
		:Create(
			icon,
			TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Rotation = 18 }
		)
		:Play()

	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromOffset(0, 44)
	label.Size = UDim2.new(1, 0, 0, 22)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = GOLD
	label.Text = keyUser.DisplayName .. " is unlocking..."
	local labelStroke = Instance.new("UIStroke")
	labelStroke.Color = TEXT_OUTLINE
	labelStroke.Thickness = 2
	labelStroke.Parent = label
	label.Parent = gui

	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 70)
	bar.Size = UDim2.fromOffset(160, 16)
	bar.BackgroundColor3 = Color3.fromRGB(18, 10, 28)
	bar.Parent = gui
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(1, 0)
	barCorner.Parent = bar
	local barStroke = Instance.new("UIStroke")
	barStroke.Color = TEXT_OUTLINE
	barStroke.Thickness = 2
	barStroke.Parent = bar
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = GOLD
	fill.Parent = bar
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	return anchor, fill
end

-- Called by ItemService when a player clicks while holding the Universal Key.
function UniversalKeyService.tryUse(player: Player, tool: Tool)
	local character = player.Character
	local root = rootOf(player)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not root or not humanoid or humanoid.Health <= 0 or busy[player] then
		return
	end
	if
		DataService.getItemCount(player, UniversalKeyService.ITEM_ID) <= 0
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
		Notify.send(player, "Universal Key ready in " .. math.ceil(waitLeft) .. "s", "error")
		return
	end
	local plot = lockedGateNear(player, root.Position)
	if not plot then
		Notify.send(player, "Stand at a locked base's gate to use the key.", "info")
		return -- nothing used up
	end

	-- Start: cooldown, tell the owner straight away, show it to everyone.
	readyAt[player] = now + GameConfig.UniversalKeyCooldownSeconds
	tool:SetAttribute("ReadyAt", readyAt[player])
	busy[player] = true
	local owner = plot.owner
	Notify.send(owner, `{player.DisplayName} is unlocking your base with a Universal Key!`, "error", {
		note = "Stop them! Bonk or cage them before the lock breaks.",
		seconds = 4,
	})
	Notify.send(player, "Unlocking...", "info")
	local anchor, fill = buildProgress(plot, player)
	local rattle = playSound(anchor, GameConfig.UniversalKeyPickSound)
	local seconds = GameConfig.UniversalKeyUnlockSeconds
	TweenService:Create(fill, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) }):Play()

	task.spawn(function()
		local startedAt = os.clock()
		local reason: string? = nil
		while os.clock() - startedAt < seconds do
			RunService.Heartbeat:Wait()
			local currentRoot = rootOf(player)
			if not player.Parent or player.Character ~= character or humanoid.Health <= 0 then
				reason = "died"
			elseif RagdollService.isRagdolled(player) or player:GetAttribute("Caged") then
				reason = "stopped"
			elseif not currentRoot or distanceToGate(plot, currentRoot.Position) > GameConfig.UniversalKeyRange + 4 then
				reason = "walked"
			elseif plot.owner ~= owner or not PlotService.isLocked(plot) then
				reason = "unlocked"
			end
			if reason then
				break
			end
		end
		busy[player] = nil
		rattle:Stop()

		if reason then
			-- Cancelled: say why, and fade the bar away.
			local messages = {
				stopped = "You were stopped! The lock held.",
				walked = "You walked away from the gate. The lock held.",
				unlocked = "That base isn't locked any more.",
			}
			if messages[reason] then
				Notify.send(player, messages[reason], "error")
			end
			if reason == "stopped" and owner.Parent then
				Notify.send(owner, `You stopped {player.DisplayName}'s key! Your base is still locked.`, "success")
			end
			anchor:Destroy()
			return
		end

		-- Done: the lock breaks.
		PlotService.forceUnlock(plot, GameConfig.LockCooldownSeconds)
		playSound(anchor, GameConfig.UniversalKeyUnlockSound)
		local gui = anchor:FindFirstChildOfClass("BillboardGui")
		local label = gui and gui:FindFirstChildOfClass("TextLabel")
		if label then
			label.Text = "UNLOCKED!"
		end
		Debris:AddItem(anchor, 1.5)
		Notify.send(player, `You unlocked {owner.DisplayName}'s base!`, "success")
		if owner.Parent then
			Notify.send(owner, `{player.DisplayName} unlocked your base!`, "error")
		end
	end)
end

function UniversalKeyService.readyAt(player: Player): number?
	return readyAt[player]
end

function UniversalKeyService.start()
	Players.PlayerRemoving:Connect(function(player)
		readyAt[player] = nil
		busy[player] = nil
	end)
end

return UniversalKeyService
