-- Cosmetics (CosmeticConfig): buying them with gems (BuyCosmetic remote), owning Robux ones
-- through their game pass, and wearing one of each kind (WearCosmetic remote, from the
-- Inventory). Owned cosmetics are "Cosmetic_<id>" = true player attributes; the worn one of each
-- kind is "Wear_<kind>" = id (saved in DataService `worn`). Titles are worn through TitleService.
-- Everyone sees them: the aura and pet go on the character (hidden while Invisible), the
-- tombstones and flowers on the owner's base (put back to normal when they leave).
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticConfig = require(ReplicatedStorage.Shared.Config.CosmeticConfig)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Notify = require(script.Parent.Parent.Util.Notify)
local CosmeticModels = require(script.Parent.CosmeticModels)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local TitleService = require(script.Parent.TitleService)

local CosmeticService = {}

-- Where a pet floats, relative to its owner's root part (beside and behind the right shoulder).
local PET_OFFSET = Vector3.new(2.5, 1.2, 2)
local WEARABLE_KINDS = { aura = true, pet = true, tombstone = true, flowers = true }

local pets: { [Player]: Model } = {}
local petFolder = Instance.new("Folder")
petFolder.Name = "Pets"
petFolder.Parent = workspace

local function worn(player: Player, kind: string): string?
	return player:GetAttribute("Wear_" .. kind)
end

---------------------------------------------------------------------------
-- On the character: aura and pet
---------------------------------------------------------------------------

-- A pet floats after its owner: AlignPosition and AlignOrientation pull its body toward an
-- attachment on the owner's root part. The owner's device simulates it, so it moves smoothly.
local function spawnPet(player: Player, root: BasePart, cosmeticId: string)
	local pet = CosmeticModels.pet(cosmeticId)
	if not pet then
		return
	end
	local body = pet.PrimaryPart :: BasePart
	local target = Instance.new("Attachment")
	target.Name = "CosmeticPetTarget"
	target.Position = PET_OFFSET
	target.Parent = root
	local own = Instance.new("Attachment")
	own.Parent = body
	local align = Instance.new("AlignPosition")
	align.Attachment0 = own
	align.Attachment1 = target
	align.MaxForce = 100000
	align.Responsiveness = 20
	align.Parent = body
	local orient = Instance.new("AlignOrientation")
	orient.Attachment0 = own
	orient.Attachment1 = target
	orient.MaxTorque = 100000
	orient.Responsiveness = 20
	orient.Parent = body
	pet:PivotTo(root.CFrame * CFrame.new(PET_OFFSET))
	pet.Name = player.Name .. "_Pet"
	pet.Parent = petFolder
	pcall(body.SetNetworkOwner, body, player)
	pets[player] = pet
end

-- Puts the worn aura and pet on the character (or takes them off). Nothing shows while
-- they're invisible (Smoke Bomb).
local function applyCharacter(player: Player)
	if pets[player] then
		pets[player]:Destroy()
		pets[player] = nil
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	CosmeticModels.removeAura(root)
	local oldTarget = root:FindFirstChild("CosmeticPetTarget")
	if oldTarget then
		oldTarget:Destroy()
	end
	if player:GetAttribute("Invisible") then
		return
	end
	local auraId = worn(player, "aura")
	if auraId then
		CosmeticModels.aura(auraId, root)
	end
	local petId = worn(player, "pet")
	if petId then
		spawnPet(player, root, petId)
	end
end

---------------------------------------------------------------------------
-- On the base: tombstones and flowers
---------------------------------------------------------------------------

-- Paints the base's tombstones in a style, or back to normal (nil). Each stone remembers its
-- own colour and material the first time it's painted.
local function paintTombstones(plot, cosmeticId: string?)
	local style = cosmeticId and CosmeticModels.Tombstones[cosmeticId]
	for _, part in plot.model:GetDescendants() do
		if part:IsA("BasePart") and (part.Name == "Tombstone" or part.Name == "TombstoneTop") then
			if part:GetAttribute("OriginalColor") == nil then
				part:SetAttribute("OriginalColor", part.Color)
				part:SetAttribute("OriginalMaterial", part.Material.Name)
			end
			part.Color = if style then style.color else part:GetAttribute("OriginalColor")
			part.Material = if style
				then style.material
				else (Enum.Material :: any)[part:GetAttribute("OriginalMaterial")]
		end
	end
end

-- Puts a bunch of flowers on both sides of every tombstone, or removes them (nil).
local function placeFlowers(plot, cosmeticId: string?)
	local old = plot.model:FindFirstChild("CosmeticFlowers")
	if old then
		old:Destroy()
	end
	if not cosmeticId then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "CosmeticFlowers"
	for _, slot in plot.slots do
		-- Slots are 3 studs above the ground; the tombstone stands 3.6 studs behind the slot.
		for _, side in { -1, 1 } do
			local flowers = CosmeticModels.flowers(cosmeticId, slot * CFrame.new(side * 2.9, -3, 3.6))
			if flowers then
				flowers.Parent = folder
			end
		end
	end
	folder.Parent = plot.model
end

local function applyBase(player: Player)
	local plot = PlotService.getPlot(player)
	if plot then
		paintTombstones(plot, worn(player, "tombstone"))
		placeFlowers(plot, worn(player, "flowers"))
	end
end

---------------------------------------------------------------------------
-- Buying and wearing
---------------------------------------------------------------------------

local function wear(player: Player, kind: string, cosmeticId: string?)
	DataService.setWorn(player, kind, cosmeticId)
	player:SetAttribute("Wear_" .. kind, cosmeticId)
	if kind == "aura" or kind == "pet" then
		applyCharacter(player)
	else
		applyBase(player)
	end
end

-- A cosmetic was just bought (gems or game pass): titles unlock (and go on), others are worn.
local function onBought(player: Player, cosmetic)
	if cosmetic.kind == "title" then
		TitleService.unlockBought(player)
	else
		wear(player, cosmetic.kind, cosmetic.id)
		Notify.send(player, `You got {cosmetic.name}!`, "success", { note = "Change it in your Inventory" })
	end
end

local function buy(player: Player, cosmeticId: unknown)
	local cosmetic = typeof(cosmeticId) == "string" and CosmeticConfig.byId[cosmeticId]
	if not cosmetic or cosmetic.currency ~= "gems" or not DataService.isLoaded(player) then
		return
	end
	if CosmeticConfig.owns(player, cosmetic.id) then
		Notify.send(player, `You already own {cosmetic.name}!`, "info")
		return
	end
	if not DataService.spendGems(player, cosmetic.price) then
		Notify.send(player, `Not enough gems for {cosmetic.name} ({Format.cash(cosmetic.price)} gems).`, "error")
		return
	end
	DataService.addCosmetic(player, cosmetic.id)
	onBought(player, cosmetic)
end

-- Wears an owned cosmetic of a kind, or takes that kind off (cosmeticId "").
local function setWorn(player: Player, kind: unknown, cosmeticId: unknown)
	if typeof(kind) ~= "string" or not WEARABLE_KINDS[kind] or typeof(cosmeticId) ~= "string" then
		return
	end
	if not DataService.isLoaded(player) then
		return
	end
	if cosmeticId == "" then
		wear(player, kind, nil)
		return
	end
	local cosmetic = CosmeticConfig.byId[cosmeticId]
	if cosmetic and cosmetic.kind == kind and CosmeticConfig.owns(player, cosmetic.id) then
		wear(player, kind, cosmetic.id)
	end
end

-- Called once the player's data has loaded (before TitleService, so bought titles count).
function CosmeticService.playerLoaded(player: Player)
	-- Robux cosmetics: owned while they own the game pass.
	for _, cosmetic in CosmeticConfig.Cosmetics do
		if cosmetic.currency == "robux" and cosmetic.passId ~= 0 then
			local ok, owns =
				pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, cosmetic.passId)
			if ok and owns then
				player:SetAttribute("Cosmetic_" .. cosmetic.id, true)
			end
		end
	end
	-- Put back what they were wearing (if they still own it).
	for kind, cosmeticId in DataService.getWorn(player) do
		if WEARABLE_KINDS[kind] and CosmeticConfig.owns(player, cosmeticId) then
			player:SetAttribute("Wear_" .. kind, cosmeticId)
		else
			DataService.setWorn(player, kind, nil)
		end
	end
	applyBase(player)
	applyCharacter(player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		applyCharacter(player)
	end)
	player:GetAttributeChangedSignal("Invisible"):Connect(function()
		applyCharacter(player)
	end)
end

-- Called before the base is handed back (PlotService.playerRemoving): plain tombstones, no
-- flowers, no pet.
function CosmeticService.playerRemoving(player: Player)
	if pets[player] then
		pets[player]:Destroy()
		pets[player] = nil
	end
	local plot = PlotService.getPlot(player)
	if plot then
		paintTombstones(plot, nil)
		placeFlowers(plot, nil)
	end
end

function CosmeticService.start()
	Remotes.BuyCosmetic.OnServerEvent:Connect(buy)
	Remotes.WearCosmetic.OnServerEvent:Connect(setWorn)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
		local cosmetic = CosmeticConfig.byPassId[gamePassId]
		if purchased and cosmetic and player.Parent then
			player:SetAttribute("Cosmetic_" .. cosmetic.id, true)
			onBought(player, cosmetic)
		end
	end)
end

return CosmeticService
