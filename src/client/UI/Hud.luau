-- On-screen HUD: cash, income per second, and message toasts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local Hud = {}

local TOAST_COLORS = {
	info = Color3.fromRGB(255, 255, 255),
	success = Color3.fromRGB(120, 255, 140),
	error = Color3.fromRGB(255, 110, 110),
}
local MAX_TOASTS = 4

local function makeLabel(props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
	label.BackgroundTransparency = 1
	for key, value in props do
		(label :: any)[key] = value
	end
	return label
end

function Hud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local cashLabel = makeLabel({
		Name = "Cash",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(260, 44),
		BackgroundTransparency = 0.2,
		TextColor3 = Color3.fromRGB(120, 255, 140),
		Text = "$0",
		Parent = gui,
	})
	Instance.new("UICorner").Parent = cashLabel

	local incomeLabel = makeLabel({
		Name = "Income",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 58),
		Size = UDim2.fromOffset(200, 22),
		Text = "+$0/s",
		Parent = gui,
	})

	local toasts = Instance.new("Frame")
	toasts.Name = "Toasts"
	toasts.AnchorPoint = Vector2.new(0.5, 1)
	toasts.Position = UDim2.new(0.5, 0, 1, -110)
	toasts.Size = UDim2.fromOffset(420, 180)
	toasts.BackgroundTransparency = 1
	toasts.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, 6)
	layout.Parent = toasts

	local toastCount = 0
	Remotes.Notify.OnClientEvent:Connect(function(message: string, kind: string)
		toastCount += 1
		local toast = makeLabel({
			Size = UDim2.new(1, 0, 0, 32),
			LayoutOrder = toastCount,
			BackgroundTransparency = 0.25,
			TextColor3 = TOAST_COLORS[kind] or TOAST_COLORS.info,
			Text = message,
			Parent = toasts,
		})
		Instance.new("UICorner").Parent = toast

		local existing = toasts:GetChildren()
		if #existing - 1 > MAX_TOASTS then -- minus the UIListLayout
			for _, child in existing do
				if child:IsA("TextLabel") and child ~= toast then
					child:Destroy()
					break
				end
			end
		end

		task.delay(3, function()
			local fade = TweenService:Create(toast, TweenInfo.new(0.4), {
				TextTransparency = 1,
				BackgroundTransparency = 1,
			})
			fade.Completed:Connect(function()
				toast:Destroy()
			end)
			fade:Play()
		end)
	end)

	local function updateIncome()
		incomeLabel.Text = "+$" .. Format.cash(player:GetAttribute("IncomePerSecond") or 0) .. "/s"
	end
	player:GetAttributeChangedSignal("IncomePerSecond"):Connect(updateIncome)
	updateIncome()

	-- leaderstats appears once the server has loaded our data.
	task.spawn(function()
		local cash = player:WaitForChild("leaderstats"):WaitForChild("Cash") :: NumberValue
		local function updateCash()
			cashLabel.Text = "$" .. Format.cash(cash.Value)
		end
		cash.Changed:Connect(updateCash)
		updateCash()
	end)
end

return Hud
