-- Phone/tablet sizing. `Mobile.scale` is GameConfig.MobileHudScale on a touch device with no
-- keyboard, and 1 everywhere else; UI that should be smaller on phones multiplies by it.
-- `Mobile.start` also shrinks the titles above everyone's head on this device.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local Mobile = {}

Mobile.isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
Mobile.scale = if Mobile.isMobile then GameConfig.MobileHudScale else 1

-- The server builds the title billboard (TitleTag) with a size in pixels; shrink it here.
local function shrinkTitleTag(tag: Instance)
	if tag.Name == "TitleTag" and tag:IsA("BillboardGui") and not tag:GetAttribute("MobileScaled") then
		tag:SetAttribute("MobileScaled", true)
		local size = tag.Size
		tag.Size = UDim2.new(
			size.X.Scale * Mobile.scale,
			size.X.Offset * Mobile.scale,
			size.Y.Scale * Mobile.scale,
			size.Y.Offset * Mobile.scale
		)
	end
end

local function watchCharacter(character: Model)
	for _, child in character:GetChildren() do
		shrinkTitleTag(child)
	end
	character.ChildAdded:Connect(shrinkTitleTag)
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
end

return Mobile
