-- While you carry a stolen ghost (the server sets your "Carrying" attribute in StealService):
-- hides the item hotbar and turns off jumping on your device. The server enforces both too
-- (puts your item away, sets jump strength to 0); this makes the screen and controls match.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local CarryControls = {}

local function apply(carrying: boolean)
	-- SetCoreGuiEnabled can fail right after joining, before Roblox's own UI is ready.
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, not carrying)
	end)
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, not carrying)
	end
end

function CarryControls.start()
	local player = Players.LocalPlayer
	player:GetAttributeChangedSignal("Carrying"):Connect(function()
		apply(player:GetAttribute("Carrying") == true)
	end)
	-- A new character always starts able to jump; just catch up on the current state.
	player.CharacterAdded:Connect(function()
		apply(player:GetAttribute("Carrying") == true)
	end)
end

return CarryControls
