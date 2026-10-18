-- The PolterPuller 4000 (a Shop item, held from the hotbar). While a player holds it, other
-- players' ghosts show "Capture" instead of "Steal" (client GhostPrompts). Capturing starts with
-- the same checks as stealing (inside their base, unlocked, a free grave), then takes
-- GameConfig.CaptureSeconds for the ghost's rarity. Meanwhile:
--   * a swirling suction beam runs from the nozzle to the ghost, which shakes and shrinks;
--   * a sign over the ghost shows "CAPTURING", its rarity (in its colours) and a countdown;
--   * the vacuum roars, and the owner's steal alarm goes off with a warning.
-- It's cancelled if the capturer is knocked over, caged, dies, puts the vacuum away or moves out
-- of range, or the base locks. When it finishes, the ghost pops into the nozzle and appears in
-- the capturer's base, counting as a steal (Top Thieves, steal streak / WANTED). If the owner
-- leaves mid-capture the capturer gets the ghost, like stealing. Cooldown: CaptureCooldownMultiplier
-- x the capture time, whether it worked or not.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local GhostConfig = require(ReplicatedStorage.Shared.Config.GhostConfig)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Notify = require(script.Parent.Parent.Util.Notify)
local BountyService = require(script.Parent.BountyService)
local DataService = require(script.Parent.DataService)
local GhostService = require(script.Parent.GhostService)
local PlotService = require(script.Parent.PlotService)
local RagdollService = require(script.Parent.RagdollService)
local ShieldService = require(script.Parent.ShieldService)
local StealService = require(script.Parent.StealService)

local CaptureService = {}

CaptureService.ITEM_ID = "polterpuller"

local SUCTION_GREEN = Color3.fromRGB(120, 255, 130)
local TEXT_OUTLINE = Color3.fromRGB(20, 8, 30)
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local readyAt: { [Player]: number } = {}

type Capture = {
	capturer: Player,
	owner: Player,
	slot: number,
	entry: any,
	finish: (success: boolean) -> (),
}
local active: { [Player]: Capture } = {} -- by capturer

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function heldVacuum(player: Player): Tool?
	local character = player.Character
	local tool = character and character:FindFirstChild(CaptureService.ITEM_ID)
	return if tool and tool:IsA("Tool") then tool else nil
end

-- How long a ghost of this rarity takes to capture.
function CaptureService.secondsFor(rarity: string): number
	return GameConfig.CaptureSeconds[rarity] or 16
end

-- The sign over the ghost: "CAPTURING", its rarity in its colours, and a big countdown with a
-- draining bar. Returns the gui and a function that updates the countdown.
local function buildSign(body: BasePart, def, seconds: number): (BillboardGui, (number) -> ())
	local gui = Instance.new("BillboardGui")
	gui.Name = "CaptureSign"
	gui.Adornee = body
	gui.Size = UDim2.fromOffset(220, 120)
	gui.StudsOffset = Vector3.new(0, def.size / 2 + 6.5, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 150

	local function line(text: string, y: number, height: number, color: Color3, thickness: number): TextLabel
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(0, y)
		label.Size = UDim2.new(1, 0, 0, height)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = color
		label.Text = text
		local stroke = Instance.new("UIStroke")
		stroke.Color = TEXT_OUTLINE
		stroke.Thickness = thickness
		stroke.Parent = label
		label.Parent = gui
		return label
	end
	line("CAPTURING!", 0, 26, SUCTION_GREEN, 2.5)
	-- The rarity in its own colours (gradient for the top rarities, like the ghost labels).
	local rarity = GhostConfig.Rarities[def.rarity]
	local gradient = Theme.RarityGradients[def.rarity]
	local rarityLabel =
		line(string.upper(def.rarity), 28, 22, if gradient then Color3.new(1, 1, 1) else rarity.color, 2)
	if gradient then
		local shimmer = Instance.new("UIGradient")
		shimmer.Color = gradient
		shimmer.Parent = rarityLabel
		CollectionService:AddTag(shimmer, "AnimatedGradient") -- shimmers (client GradientAnimator)
	end
	local countdown = line(string.format("%.1f", seconds), 52, 44, Color3.new(1, 1, 1), 3)

	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 100)
	bar.Size = UDim2.fromOffset(150, 12)
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
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = SUCTION_GREEN
	fill.Parent = bar
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	gui.Parent = body
	return gui,
		function(left: number)
			countdown.Text = string.format("%.1f", math.max(left, 0))
			fill.Size = UDim2.fromScale(math.clamp(left / seconds, 0, 1), 1)
		end
end

-- The suction: two green beams from the nozzle's mouth to the ghost, with streaks flowing toward
-- the nozzle, and sparkles pulled off the ghost. Returns everything made, to clean up after.
local function buildSuction(mouth: Attachment, body: BasePart): { Instance }
	local target = Instance.new("Attachment")
	target.Name = "SuctionTarget"
	target.Parent = body

	local function beam(width: number, transparency: number, speed: number): Beam
		local b = Instance.new("Beam")
		b.Attachment0 = target
		b.Attachment1 = mouth
		b.Color = ColorSequence.new(Color3.fromRGB(200, 255, 205), SUCTION_GREEN)
		b.LightEmission = 1
		b.Transparency = NumberSequence.new(transparency, transparency * 0.4)
		b.Width0 = width
		b.Width1 = width * 0.25 -- funnels into the nozzle
		b.FaceCamera = true
		b.Texture = "rbxasset://textures/particles/smoke_main.dds"
		b.TextureMode = Enum.TextureMode.Wrap
		b.TextureLength = 2
		b.TextureSpeed = speed -- the streaks flow along the beam toward the nozzle
		b.Segments = 12
		b.Parent = body
		return b
	end
	local wide = beam(4, 0.7, 3)
	local core = beam(1.6, 0.35, 5)

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = SPARKLE_TEXTURE
	sparkles.Color = ColorSequence.new(SUCTION_GREEN)
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new(0.6, 0)
	sparkles.Lifetime = NumberRange.new(0.4, 0.7)
	sparkles.Speed = NumberRange.new(3, 6)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Rate = 30
	sparkles.Parent = target

	return { target, wide, core, sparkles }
end

local function playSound(parent: Instance, config, looped: boolean?): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. config.soundId
	sound.Volume = config.volume
	sound.Looped = looped == true
	sound.RollOffMaxDistance = 100
	sound.Parent = parent
	if config.startAt then
		sound.TimePosition = config.startAt
	end
	sound:Play()
	return sound
end

-- Starts a capture: `capturer` used the Capture prompt on `owner`'s ghost in `slot`.
function CaptureService.tryCapture(capturer: Player, owner: Player, slot: number)
	local tool = heldVacuum(capturer)
	local root = rootOf(capturer)
	local humanoid = capturer.Character and capturer.Character:FindFirstChildOfClass("Humanoid")
	if capturer == owner or not tool or not root or not humanoid or humanoid.Health <= 0 or active[capturer] then
		return
	end
	if
		DataService.getItemCount(capturer, CaptureService.ITEM_ID) <= 0
		or capturer:GetAttribute("Invisible")
		or capturer:GetAttribute("Caged")
		or capturer:GetAttribute("Carrying")
		or RagdollService.isRagdolled(capturer)
	then
		return
	end
	local now = workspace:GetServerTimeNow()
	local waitLeft = (readyAt[capturer] or 0) - now
	if waitLeft > 0 then
		Notify.send(capturer, "PolterPuller ready in " .. math.ceil(waitLeft) .. "s", "error")
		return
	end

	-- The same rules as stealing.
	local entry = GhostService.getEntry(owner, slot)
	local ownerPlot = PlotService.getPlot(owner)
	if not entry or not GhostService.isInBase(entry) or not ownerPlot then
		return
	end
	if PlotService.isLocked(ownerPlot) then
		Notify.send(capturer, "This base is locked!", "error")
		return
	end
	if not GhostService.firstFreeSlot(capturer) then
		Notify.send(capturer, "Your base is full! Sell a ghost before capturing.", "error")
		return
	end
	if not PlotService.isInside(ownerPlot, root.Position) then
		Notify.send(capturer, "Get inside their base to capture!", "error")
		return
	end
	local body = entry.model.PrimaryPart :: BasePart
	if (body.Position - root.Position).Magnitude > GameConfig.CaptureRange then
		return
	end
	local mouth = tool.Handle:FindFirstChild("Mouth") :: Attachment?
	if not mouth then
		return
	end

	-- Start.
	local def = GhostConfig.byId[entry.id]
	local name = GhostService.displayName(def, entry.mutation)
	local seconds = CaptureService.secondsFor(def.rarity)
	entry.capturing = true
	ShieldService.stop(capturer) -- capturing counts as stealing: no shield while doing it
	entry.model:SetAttribute("Capturing", true)
	StealService.markRobbed(owner, 1)
	Notify.send(owner, `{capturer.DisplayName} is capturing your {name}! Hit them with your bat!`, "error", {
		note = `{seconds}s until it's gone. Don't leave, or they get it!`,
		seconds = 5,
	})
	Notify.send(capturer, `Capturing {name}... hold on for {seconds}s!`, "info")

	local model = entry.model
	local startPivot = model:GetPivot()
	local startScale = model:GetScale()
	local _, updateSign = buildSign(body, def, seconds)
	local sign = body:FindFirstChild("CaptureSign")
	local suction = buildSuction(mouth, body)
	local roar = playSound(tool.Handle, GameConfig.CaptureVacuumSound, true)

	local finished = false
	local function finish(success: boolean)
		if finished then
			return
		end
		finished = true
		active[capturer] = nil
		roar:Stop()
		roar:Destroy()
		for _, item in suction do
			item:Destroy()
		end
		if sign then
			sign:Destroy()
		end
		StealService.markRobbed(owner, -1)

		-- The cooldown, the same whether it worked or not.
		local cooldown = seconds * GameConfig.CaptureCooldownMultiplier
		readyAt[capturer] = workspace:GetServerTimeNow() + cooldown
		local currentTool = heldVacuum(capturer)
			or capturer:FindFirstChildOfClass("Backpack")
				and capturer:FindFirstChildOfClass("Backpack"):FindFirstChild(CaptureService.ITEM_ID)
		if currentTool then
			currentTool:SetAttribute("CooldownTotal", cooldown) -- the hotbar's shade uses this length
			currentTool:SetAttribute("ReadyAt", readyAt[capturer])
		end

		local stillThere = GhostService.getEntry(owner, slot) == entry
		if not success then
			if stillThere then
				entry.capturing = false
				model:SetAttribute("Capturing", false)
				model:ScaleTo(startScale)
				model:PivotTo(startPivot)
			end
			return
		end

		-- Success: the ghost shoots into the nozzle with a pop, then appears in the capturer's base.
		local newSlot = GhostService.firstFreeSlot(capturer)
		if not stillThere or not newSlot then
			if stillThere then
				entry.capturing = false
				model:SetAttribute("Capturing", false)
				model:ScaleTo(startScale)
				model:PivotTo(startPivot)
			end
			Notify.send(capturer, "Your base is full, so the ghost slipped free!", "error")
			return
		end
		local nozzle = heldVacuum(capturer)
		if nozzle then
			playSound(nozzle.Handle, GameConfig.CapturePopSound)
		end
		GhostService.removeGhost(owner, slot)
		GhostService.placeGhost(capturer, newSlot, entry.id, nil, entry.mutation)
		DataService.addSteal(capturer)
		BountyService.onSteal(capturer, def.price)
		Notify.send(capturer, `You captured {name}! It's in your base.`, "success")
		if owner.Parent then
			Notify.send(owner, `{capturer.DisplayName} captured your {name}!`, "error")
		end
	end
	active[capturer] = { capturer = capturer, owner = owner, slot = slot, entry = entry, finish = finish }

	-- Each frame: count down, shake and shrink the ghost toward the nozzle, and check nothing
	-- has stopped the capture.
	task.spawn(function()
		local character = capturer.Character
		local startedAt = os.clock()
		local random = Random.new()
		while not finished do
			local elapsed = os.clock() - startedAt
			local left = seconds - elapsed
			if left <= 0 then
				finish(true)
				return
			end
			local currentRoot = rootOf(capturer)
			local reason: string? = nil
			if not capturer.Parent or capturer.Character ~= character or humanoid.Health <= 0 then
				reason = "You dropped the PolterPuller!"
			elseif RagdollService.isRagdolled(capturer) or capturer:GetAttribute("Caged") then
				reason = "You were stopped! The ghost broke free."
			elseif not heldVacuum(capturer) then
				reason = "You put the PolterPuller away. The ghost broke free."
			elseif
				not currentRoot
				or (startPivot.Position - currentRoot.Position).Magnitude > GameConfig.CaptureRange + 4
			then
				reason = "Too far away! The ghost broke free."
			elseif PlotService.isLocked(ownerPlot) then
				reason = "The base locked! The ghost broke free."
			elseif GhostService.getEntry(owner, slot) ~= entry then
				reason = "The ghost is gone."
			end
			if reason then
				Notify.send(capturer, reason, "error")
				if owner.Parent and reason ~= "The ghost is gone." then
					Notify.send(owner, `{capturer.DisplayName}'s capture failed! Your ghost is safe.`, "success")
				end
				finish(false)
				return
			end

			updateSign(left)
			-- Shrink to 75% over the capture, lean toward the vacuum, and shake harder near the end.
			local progress = elapsed / seconds
			model:ScaleTo(startScale * (1 - 0.25 * progress))
			local toward = currentRoot.Position - startPivot.Position
			local lean = if toward.Magnitude > 0.1
				then toward.Unit * math.min(progress * 2.5, toward.Magnitude * 0.3)
				else Vector3.zero
			local shake = 0.08 + 0.3 * progress
			local jitter = Vector3.new(
				random:NextNumber(-shake, shake),
				random:NextNumber(-shake, shake),
				random:NextNumber(-shake, shake)
			)
			model:PivotTo(startPivot + lean + jitter)
			RunService.Heartbeat:Wait()
		end
	end)
end

-- The PolterPuller is used through the Capture prompt, not by clicking, so a click just explains.
function CaptureService.tryUse(player: Player, _tool: Tool)
	Notify.send(player, "Walk up to someone's ghost and press Capture!", "info")
end

function CaptureService.readyAt(player: Player): number?
	return readyAt[player]
end

-- Called when a player leaves, before their base is cleared: a capture of their ghost succeeds
-- straight away (leaving doesn't save it), and a capture they were doing is cancelled.
function CaptureService.playerRemoving(player: Player)
	for capturer, capture in active do
		if capture.owner == player then
			capture.finish(true)
		elseif capturer == player then
			capture.finish(false)
		end
	end
	readyAt[player] = nil
end

function CaptureService.start()
	GhostService.onCapturePromptTriggered = CaptureService.tryCapture
end

return CaptureService
