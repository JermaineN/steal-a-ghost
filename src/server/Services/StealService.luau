-- Stealing: grab a ghost from someone else's base and carry it back to yours.
-- The steal fails if the thief dies, gets hit with a bat (ItemService), or the base locks with them inside.
-- While carrying, the thief can't jump or hold items, and their device hides the hotbar (CarryControls
-- reads the "Carrying" attribute set here).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local GhostConfig = require(ReplicatedStorage.Shared.Config.GhostConfig)
local Notify = require(script.Parent.Parent.Util.Notify)
local GhostService = require(script.Parent.GhostService)
local PlotService = require(script.Parent.PlotService)

local StealService = {}

type Carry = {
	owner: Player,
	slot: number,
	model: Model,
	welds: { WeldConstraint },
	humanoid: Humanoid,
	originalSpeed: number,
	originalJumpPower: number,
	originalJumpHeight: number,
	diedConnection: RBXScriptConnection,
	toolConnection: RBXScriptConnection,
}
local carries: { [Player]: Carry } = {}
local cooldownUntil: { [Player]: number } = {}

local function getAliveRoot(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return root :: BasePart, humanoid
	end
	return nil, nil
end

-- Animated meshes (see GhostModels) are never anchored or welded here: their own weld to the
-- body holds them, and the client animates that weld.
local function isAnimated(part: BasePart): boolean
	return part:GetAttribute("Animated") == true
end

local function setAnchored(model: Model, anchored: boolean)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and not isAnimated(part) then
			part.Anchored = anchored
			part.Massless = not anchored
		end
	end
end

-- Welds the ghost above the thief's head.
local function attach(model: Model, root: BasePart): { WeldConstraint }
	local body = model.PrimaryPart :: BasePart
	model:PivotTo(root.CFrame * CFrame.new(0, body.Size.Y / 2 + 3, 0))

	local welds = {}
	local function weld(part0: BasePart, part1: BasePart)
		local constraint = Instance.new("WeldConstraint")
		constraint.Part0 = part0
		constraint.Part1 = part1
		constraint.Parent = part1
		table.insert(welds, constraint)
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part ~= body and not isAnimated(part) then
			weld(body, part)
		end
	end
	weld(root, body)

	setAnchored(model, false)
	return welds
end

-- Stops the carry (removes welds, restores speed, jumping and items). Returns the carry info, or nil if there was none.
local function endCarry(thief: Player): Carry?
	local carry = carries[thief]
	if not carry then
		return nil
	end
	carries[thief] = nil
	cooldownUntil[thief] = os.clock() + GameConfig.StealCooldownSeconds
	for _, weld in carry.welds do
		weld:Destroy()
	end
	carry.diedConnection:Disconnect()
	carry.toolConnection:Disconnect()
	if carry.humanoid.Parent then
		carry.humanoid.WalkSpeed = carry.originalSpeed
		carry.humanoid.JumpPower = carry.originalJumpPower
		carry.humanoid.JumpHeight = carry.originalJumpHeight
	end
	thief:SetAttribute("Carrying", nil)
	return carry
end

function StealService.getCarry(thief: Player): Carry?
	return carries[thief]
end

-- Sends the ghost back to its owner's slot.
function StealService.returnGhost(thief: Player, message: string?)
	local carry = endCarry(thief)
	if not carry then
		return
	end
	local entry = GhostService.getEntry(carry.owner, carry.slot)
	local slotCFrame = GhostService.getSlotCFrame(carry.owner, carry.slot)
	if entry and entry.model == carry.model and slotCFrame then
		setAnchored(carry.model, true)
		carry.model:PivotTo(slotCFrame)
		entry.carried = false
		carry.model:SetAttribute("Carried", false)
	end
	if message then
		Notify.send(thief, message, "error")
	end
end

-- When `attacker` hits a thief (bat, cage or landmine), the stolen ghost flies home.
-- `verb` describes the hit: "bonked", "caged", "blasted".
function StealService.knockLoose(attacker: Player, thief: Player, verb: string)
	local carry = carries[thief]
	if not carry then
		return
	end
	local owner = carry.owner
	StealService.returnGhost(thief, attacker.DisplayName .. " " .. verb .. " you! The ghost flew home.")
	if owner == attacker then
		Notify.send(owner, "You got your ghost back!", "success")
	else
		Notify.send(attacker, "You " .. verb .. " a thief!", "success")
		Notify.send(owner, attacker.DisplayName .. " got your ghost back!", "success")
	end
end

local function deliver(thief: Player)
	local carry = carries[thief]
	local entry = GhostService.getEntry(carry.owner, carry.slot)
	local newSlot = GhostService.firstFreeSlot(thief)
	if not entry or not newSlot then
		StealService.returnGhost(thief, "Your base is full, so the ghost flew back home!")
		return
	end

	endCarry(thief)
	local def = GhostConfig.byId[entry.id]
	GhostService.removeGhost(carry.owner, carry.slot)
	GhostService.placeGhost(thief, newSlot, entry.id)
	Notify.send(thief, "You stole " .. def.name .. "!", "success")
	Notify.send(carry.owner, thief.DisplayName .. " stole your " .. def.name .. "!", "error")
end

function StealService.tryStartSteal(thief: Player, owner: Player, slot: number)
	-- Caged players (CageService) can't steal.
	if thief == owner or carries[thief] or thief:GetAttribute("Caged") or os.clock() < (cooldownUntil[thief] or 0) then
		return
	end
	local entry = GhostService.getEntry(owner, slot)
	local ownerPlot = PlotService.getPlot(owner)
	if not entry or not GhostService.isInBase(entry) or not ownerPlot then
		return
	end
	if PlotService.isLocked(ownerPlot) then
		Notify.send(thief, "This base is locked!", "error")
		return
	end
	if not GhostService.firstFreeSlot(thief) then
		Notify.send(thief, "Your base is full! Sell a ghost before stealing.", "error")
		return
	end
	local root, humanoid = getAliveRoot(thief)
	-- The thief must actually be inside the base (stops grabbing through walls).
	if not root or not humanoid or not PlotService.isInside(ownerPlot, root.Position) then
		return
	end

	entry.carried = true
	entry.model:SetAttribute("Carried", true)
	-- Put away whatever they're holding, and keep putting it away if they try to equip something.
	humanoid:UnequipTools()
	local character = humanoid.Parent :: Model
	local carry: Carry = {
		owner = owner,
		slot = slot,
		model = entry.model,
		welds = attach(entry.model, root),
		humanoid = humanoid,
		originalSpeed = humanoid.WalkSpeed,
		originalJumpPower = humanoid.JumpPower,
		originalJumpHeight = humanoid.JumpHeight,
		diedConnection = humanoid.Died:Connect(function()
			StealService.returnGhost(thief, "You dropped the ghost!")
		end),
		-- Equipping a tool moves it into the character.
		toolConnection = character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				task.defer(function()
					humanoid:UnequipTools()
				end)
			end
		end),
	}
	carries[thief] = carry
	humanoid.WalkSpeed = GameConfig.CarryWalkSpeed
	-- Jump strength 0 = no jumping (whichever of the two settings the character uses).
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	thief:SetAttribute("Carrying", true)

	local def = GhostConfig.byId[entry.id]
	Notify.send(thief, "Run back to your base!", "info")
	Notify.send(owner, thief.DisplayName .. " is stealing your " .. def.name .. "! Hit them with your bat!", "error")
end

function StealService.playerRemoving(player: Player)
	if carries[player] then
		StealService.returnGhost(player)
	end
	for thief, carry in carries do
		if carry.owner == player then
			endCarry(thief)
			Notify.send(thief, "The owner left, so their ghost vanished.", "error")
		end
	end
	cooldownUntil[player] = nil
end

local function checkCarries()
	for thief in carries do
		local root = getAliveRoot(thief)
		if not root then
			StealService.returnGhost(thief, "You dropped the ghost!")
			continue
		end

		local thiefPlot = PlotService.getPlot(thief)
		if thiefPlot and PlotService.isInside(thiefPlot, root.Position) then
			deliver(thief)
		end
	end
end

function StealService.start()
	GhostService.onStealPromptTriggered = StealService.tryStartSteal

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.1 then
			elapsed = 0
			checkCarries()
		end
	end)
end

return StealService
