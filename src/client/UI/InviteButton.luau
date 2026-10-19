-- The "Invite" button in the bottom-right corner, next to the music button. It opens Roblox's
-- own invite-friends window. Friends who join boost your income (FriendBoostService), and the
-- button says so. While friends are here it shows how many.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Hud = require(script.Parent.Hud)
local Mobile = require(script.Parent.Mobile)

local InviteButton = {}

local PANEL_DARK = Color3.fromRGB(28, 16, 44)
local PINK = Theme.FriendPink
local TEXT_OUTLINE = Color3.fromRGB(20, 8, 30)
local WHITE = Color3.new(1, 1, 1)
local FONT = Enum.Font.FredokaOne
local QUICK = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local player = Players.LocalPlayer

local function new(className: string, props: { [string]: any }): any
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	instance.Parent = props.Parent
	return instance
end

local function promptInvite()
	local ok, canInvite = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
	if ok and canInvite then
		pcall(SocialService.PromptGameInvite, SocialService, player)
	else
		Hud.showToast("Invites aren't available right now.", "error")
	end
end

function InviteButton.start()
	local gui = new("ScreenGui", {
		Name = "Invite",
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- Same height and style as the round music button, to its left.
	local button = new("TextButton", {
		Name = "InviteButton",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -72, 1, -14),
		Size = UDim2.fromOffset(150, 48),
		BackgroundColor3 = PANEL_DARK,
		BackgroundTransparency = 0.1,
		Text = "",
		AutoButtonColor = false,
		Parent = gui,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = button })
	local stroke = new("UIStroke", {
		Color = PINK,
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = button,
	})
	-- Smaller on phones (Mobile.scale); the button shrinks toward its bottom-right corner.
	local scale = new("UIScale", { Scale = Mobile.scale, Parent = button })
	local title = new("TextLabel", {
		Position = UDim2.fromOffset(12, 5),
		Size = UDim2.new(1, -24, 0, 22),
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextColor3 = WHITE,
		Text = "Invite friends",
		Parent = button,
	})
	new("UIStroke", { Color = TEXT_OUTLINE, Thickness = 1.5, Parent = title })
	local perFriend = math.floor(GameConfig.FriendBoostPerFriend * 100 + 0.5)
	local subtitle = new("TextLabel", {
		Position = UDim2.fromOffset(12, 27),
		Size = UDim2.new(1, -24, 0, 16),
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextColor3 = PINK,
		Text = `+{perFriend}% income each`,
		Parent = button,
	})
	new("UIStroke", { Color = TEXT_OUTLINE, Thickness = 1.25, Parent = subtitle })

	button.MouseEnter:Connect(function()
		TweenService:Create(scale, QUICK, { Scale = 1.06 * Mobile.scale }):Play()
		TweenService:Create(stroke, QUICK, { Thickness = 3 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, QUICK, { Scale = Mobile.scale }):Play()
		TweenService:Create(stroke, QUICK, { Thickness = 2 }):Play()
	end)
	button.Activated:Connect(promptInvite)

	-- With friends here, the second line shows how many and the boost they give.
	local function update()
		local count = player:GetAttribute("FriendsHere") or 0
		local boost = math.floor((player:GetAttribute("FriendBoost") or 0) * 100 + 0.5)
		subtitle.Text = if count > 0 then `{count} here: +{boost}% income` else `+{perFriend}% income each`
	end
	player:GetAttributeChangedSignal("FriendsHere"):Connect(update)
	player:GetAttributeChangedSignal("FriendBoost"):Connect(update)
	update()
end

return InviteButton
