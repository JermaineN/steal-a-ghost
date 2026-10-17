-- While you carry a stolen ghost or are caged (the server sets your "Carrying" attribute in
-- StealService, "Caged" in CageService): turns off jumping on your device. The server enforces
-- it too (jump strength 0); this makes the controls match. The hotbar hides itself (UI/Hotbar).
local Players = game:GetService("Players")

local CarryControls = {}

local function apply(carrying: boolean)
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, not carrying)
	end
end

function CarryControls.start()
	local player = Players.LocalPlayer
	local function update()
		apply(player:GetAttribute("Carrying") == true or player:GetAttribute("Caged") == true)
	end
	player:GetAttributeChangedSignal("Carrying"):Connect(update)
	player:GetAttributeChangedSignal("Caged"):Connect(update)
	-- A new character always starts able to jump; just catch up on the current state.
	player.CharacterAdded:Connect(update)
end

return CarryControls
