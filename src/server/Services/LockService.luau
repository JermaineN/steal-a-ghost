-- Base lock: the owner steps on the lock button, and for a while red jail bars appear across
-- the entrance and an invisible wall behind them blocks everyone except the owner. Anyone
-- already inside when the lock starts is pushed out (dropping any ghost they were stealing
-- from this base). The bars are only a see-through warning; the wall does the blocking.
-- Only a fresh step counts: standing on the button doesn't re-lock when the cooldown ends,
-- so an AFK owner can't keep their base locked forever.
--
-- The owner walks through their own wall thanks to collision groups (named groups of parts
-- where you choose which groups bump into each other): each base's wall is in "LockWall<n>",
-- its owner's character is in "PlotOwner<n>", and those two groups don't collide.
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Notify = require(script.Parent.Parent.Util.Notify)
local PlotService = require(script.Parent.PlotService)
local StealService = require(script.Parent.StealService)

local LockService = {}

local COLOR_READY = Color3.fromRGB(80, 255, 120)
local COLOR_LOCKED = Color3.fromRGB(255, 70, 80)
local COLOR_COOLDOWN = Color3.fromRGB(150, 150, 150)

local function wallGroup(plot): string
	return "LockWall" .. plot.index
end

local function ownerGroup(plot): string
	return "PlotOwner" .. plot.index
end

-- Puts every part of a character (including ones added later, like accessories) in `group`.
local function setCharacterGroup(character: Model, group: string)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = group
		end
	end
	character.DescendantAdded:Connect(function(part)
		if part:IsA("BasePart") then
			part.CollisionGroup = group
		end
	end)
end

-- Shows the bars and makes the invisible wall solid while locked; hides and opens them otherwise.
local function setBarsLocked(plot, locked: boolean)
	if plot.barsLocked == locked then
		return
	end
	plot.barsLocked = locked
	for _, surface in plot.lockBarSurfaces do
		surface.Enabled = locked
	end
	plot.lockWall.CanCollide = locked
end

local function tryLock(plot, player: Player)
	if plot.owner ~= player then
		return
	end
	local now = os.clock()
	if now < plot.lockCooldownUntil then
		return
	end
	plot.lockedUntil = now + GameConfig.LockDurationSeconds
	plot.lockCooldownUntil = plot.lockedUntil + GameConfig.LockCooldownSeconds
	Notify.send(player, `Base locked for {GameConfig.LockDurationSeconds} seconds!`, "success")
end

-- Pushes everyone except the owner out of a locked base. The wall stops anyone walking in, so
-- this catches players who were already inside when the lock started (and anyone who gets in
-- some other way, like an exploiter).
local function ejectIntruders(plot)
	for _, player in Players:GetPlayers() do
		if player == plot.owner then
			continue
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and PlotService.isInside(plot, root.Position) then
			local carry = StealService.getCarry(player)
			if carry and carry.owner == plot.owner then
				StealService.returnGhost(player, "The base locked and the ghost flew back!")
			end
			character:PivotTo(plot.ejectCFrame)
			Notify.send(player, "This base is locked!", "error")
		end
	end
end

-- True if the plot's owner is standing on (or right above) the lock button.
local function isOwnerOnButton(plot): boolean
	local character = plot.owner and plot.owner.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end
	local button = plot.lockButton
	local offset = button.CFrame:PointToObjectSpace(root.Position)
	local margin = GameConfig.LockButtonMargin
	return math.abs(offset.X) <= button.Size.X / 2 + margin
		and math.abs(offset.Z) <= button.Size.Z / 2 + margin
		and offset.Y > 0
		and offset.Y < 6
end

local function updatePlot(plot, now: number)
	-- Lock only when the owner steps onto the button (off -> on), not while they stand there.
	local onButton = isOwnerOnButton(plot)
	if onButton and not plot.ownerWasOnButton then
		tryLock(plot, plot.owner)
	end
	plot.ownerWasOnButton = onButton

	local locked = now < plot.lockedUntil
	setBarsLocked(plot, locked)

	local text, color
	if not plot.owner then
		text, color = "", COLOR_COOLDOWN
	elseif locked then
		text, color = `LOCKED {math.ceil(plot.lockedUntil - now)}s`, COLOR_LOCKED
	elseif now < plot.lockCooldownUntil then
		text, color = `Lock ready in {math.ceil(plot.lockCooldownUntil - now)}s`, COLOR_COOLDOWN
	else
		text, color = "Step here to LOCK", COLOR_READY
	end
	plot.lockLabel.Text = text
	plot.lockLabel.TextColor3 = color
	plot.lockButton.Color = color

	if locked then
		ejectIntruders(plot)
	end
end

-- Lets a base's owner walk through their own lock wall. Called once they've been given a base.
function LockService.playerAdded(player: Player)
	local plot = PlotService.getPlot(player)
	if not plot then
		return
	end
	local group = ownerGroup(plot)
	player.CharacterAdded:Connect(function(character)
		setCharacterGroup(character, group)
	end)
	if player.Character then
		setCharacterGroup(player.Character, group)
	end
end

function LockService.start(plots)
	for _, plot in plots do
		PhysicsService:RegisterCollisionGroup(wallGroup(plot))
		PhysicsService:RegisterCollisionGroup(ownerGroup(plot))
		PhysicsService:CollisionGroupSetCollidable(wallGroup(plot), ownerGroup(plot), false)
		plot.lockWall.CollisionGroup = wallGroup(plot)
	end

	task.spawn(function()
		while true do
			local now = os.clock()
			for _, plot in plots do
				updatePlot(plot, now)
			end
			task.wait(0.25)
		end
	end)
end

return LockService
