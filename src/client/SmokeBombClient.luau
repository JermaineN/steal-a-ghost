-- While you're invisible from a Smoke Bomb (the server sets your "Invisible" attribute), you'd
-- lose track of your own character, so your device alone draws a faint purple outline around it.
-- Nobody else sees the outline.
local Players = game:GetService("Players")

local SmokeBombClient = {}

function SmokeBombClient.start()
	local player = Players.LocalPlayer
	local outline: Highlight? = nil
	local function update()
		local invisible = player:GetAttribute("Invisible") == true
		if invisible and not outline and player.Character then
			local highlight = Instance.new("Highlight")
			highlight.Name = "InvisibleOutline"
			highlight.FillTransparency = 1
			highlight.OutlineColor = Color3.fromRGB(175, 95, 255)
			highlight.OutlineTransparency = 0.3
			highlight.Parent = player.Character
			outline = highlight
		elseif not invisible and outline then
			outline:Destroy()
			outline = nil
		end
	end
	player:GetAttributeChangedSignal("Invisible"):Connect(update)
	player.CharacterAdded:Connect(function()
		outline = nil -- it went with the old character
		update()
	end)
end

return SmokeBombClient
