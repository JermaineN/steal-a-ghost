-- Titles (TitleConfig): a word above a player's head that everyone sees, like "THE GOAT". A
-- player owns a title if their UserId is on its allow-list or they've earned it
-- (DataService.grantTitle). They pick which one to show in the Inventory (EquipTitle remote);
-- the choice is saved. Owned titles are shown to the player's device as "Title_<id>" = true
-- attributes, and the one they're showing as the "Title" attribute.
-- The first time someone owns a title (and has never picked one), it's put on for them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TitleConfig = require(ReplicatedStorage.Shared.Config.TitleConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TitleText = require(ReplicatedStorage.Shared.TitleText)
local DataService = require(script.Parent.DataService)

local TitleService = {}

local TAG_NAME = "TitleTag"
-- Studs above the head. BountyService puts WANTED above this when there's a title.
TitleService.HEIGHT = 2.8

local function owns(player: Player, titleId: string): boolean
	local title = TitleConfig.byId[titleId]
	if not title then
		return false
	end
	if title.allowedUserIds and table.find(title.allowedUserIds, player.UserId) then
		return true
	end
	return DataService.hasEarnedTitle(player, titleId)
end

-- Puts the player's current title above their character's head (or removes it).
local function decorate(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild(TAG_NAME)
	if old then
		old:Destroy()
	end
	local title = TitleConfig.byId[player:GetAttribute("Title") or ""]
	local head = character:FindFirstChild("Head") :: BasePart?
	if not title or not head then
		return
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = TAG_NAME
	tag.Adornee = head
	tag.Size = UDim2.fromOffset(240, 42)
	tag.StudsOffset = Vector3.new(0, TitleService.HEIGHT, 0)
	tag.MaxDistance = 100
	tag.LightInfluence = 0
	-- Hidden while they're invisible (Smoke Bomb).
	tag.Enabled = not player:GetAttribute("Invisible")
	TitleText.create(tag, title, 3)
	tag.Parent = character
end

local function setTitle(player: Player, titleId: string)
	DataService.setTitle(player, titleId)
	player:SetAttribute("Title", if titleId ~= "" then titleId else nil)
	decorate(player)
end

-- Called once the player's data has loaded.
function TitleService.playerLoaded(player: Player)
	local firstOwned: string? = nil
	for _, title in TitleConfig.Titles do
		if owns(player, title.id) then
			player:SetAttribute("Title_" .. title.id, true)
			firstOwned = firstOwned or title.id
		end
	end
	local saved = DataService.getTitle(player)
	if saved == nil then
		-- Never picked one: wear the first title they own.
		if firstOwned then
			setTitle(player, firstOwned)
		end
	elseif saved ~= "" and owns(player, saved) then
		setTitle(player, saved)
	end

	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 10)
		decorate(player)
	end)
	player:GetAttributeChangedSignal("Invisible"):Connect(function()
		local tag = player.Character and player.Character:FindFirstChild(TAG_NAME)
		if tag then
			(tag :: BillboardGui).Enabled = not player:GetAttribute("Invisible")
		end
	end)
end

function TitleService.start()
	Remotes.EquipTitle.OnServerEvent:Connect(function(player, titleId)
		if typeof(titleId) ~= "string" or not DataService.isLoaded(player) then
			return
		end
		if titleId ~= "" and not owns(player, titleId) then
			return
		end
		setTitle(player, titleId)
	end)
end

return TitleService
