-- Base lock: the owner steps on the lock button, and for a while nobody else can enter.
-- Only a fresh step counts: standing on the button doesn't re-lock when the cooldown ends,
-- so an AFK owner can't keep their base locked forever.
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

-- Pushes everyone except the owner out of a locked base.
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
	plot.barrier.Transparency = if locked then 0.5 else 1

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

function LockService.start(plots)
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
