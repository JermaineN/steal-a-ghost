-- Phone/tablet sizing. `Mobile.scale` is GameConfig.MobileHudScale on a touch device with no
-- keyboard, and 1 everywhere else; UI that should be smaller on phones multiplies by it.
-- `Mobile.start` also shrinks some floating text built by the server, on this device only:
-- the titles above everyone's head (MobileHudScale), and the base texts (MobileBaseTextScale):
-- ghost labels (name, mutation, rarity, income) and the collect pads' "COLLECT $X". Ghosts on
-- the walkway, the base signs and the lock text keep their size.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local Mobile = {}

Mobile.isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
Mobile.scale = if Mobile.isMobile then GameConfig.MobileHudScale else 1

-- Billboards on the bases to shrink, by name (GhostLabel, EconomyService).
local BASE_TEXTS = { GhostLabel = true, StoredCash = true }

-- Shrinks a server-built billboard once. Its size is in pixels, so the billboard gets smaller,
-- and a UIScale shrinks the text placed inside it in pixels to match.
local function shrink(gui: BillboardGui, factor: number, scaleContents: boolean)
	if gui:GetAttribute("MobileScaled") then
		return
	end
	gui:SetAttribute("MobileScaled", true)
	local size = gui.Size
	gui.Size = UDim2.new(size.X.Scale * factor, size.X.Offset * factor, size.Y.Scale * factor, size.Y.Offset * factor)
	if scaleContents then
		local scale = Instance.new("UIScale")
		scale.Scale = factor
		scale.Parent = gui
	end
end

-- The title above a head (TitleTag); its text already fills the billboard.
local function shrinkTitleTag(tag: Instance)
	if tag.Name == "TitleTag" and tag:IsA("BillboardGui") then
		shrink(tag, Mobile.scale, false)
	end
end

local function watchCharacter(character: Model)
	for _, child in character:GetChildren() do
		shrinkTitleTag(child)
	end
	character.ChildAdded:Connect(shrinkTitleTag)
end

local function shrinkBaseText(item: Instance)
	if BASE_TEXTS[item.Name] and item:IsA("BillboardGui") then
		local walkway = workspace:FindFirstChild("WalkwayGhosts")
		if not (walkway and item:IsDescendantOf(walkway)) then
			shrink(item, GameConfig.MobileBaseTextScale, true)
		end
	end
end

function Mobile.start()
	if not Mobile.isMobile then
		return
	end
	local function watchPlayer(other: Player)
		if other.Character then
			watchCharacter(other.Character)
		end
		other.CharacterAdded:Connect(watchCharacter)
	end
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	for _, item in workspace:GetDescendants() do
		shrinkBaseText(item)
	end
	workspace.DescendantAdded:Connect(shrinkBaseText)
end

return Mobile
