-- Draws the Shield item's effect: three shield icons circling every shielded player (anyone with
-- a "ShieldUntil" attribute in the future, see ShieldService), so everyone can tell they can't be
-- knocked over or caged. Each device draws them itself, so they spin smoothly. They blink in the
-- last second, and hide while the player is invisible (Smoke Bomb).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local ShieldClient = {}

local COUNT = 3
local RADIUS = 3.2 -- studs from the player's middle
local SPIN = 2.4 -- radians per second
local BOB = 0.35 -- studs up and down
local ICON_SIZE = 1.7 -- studs

type Orbit = { holder: Folder, icons: { BillboardGui } }

function ShieldClient.start()
	local orbits: { [Player]: Orbit } = {}
	local container = Instance.new("Folder")
	container.Name = "ShieldOrbits"
	container.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local function remove(player: Player)
		local orbit = orbits[player]
		if orbit then
			orbit.holder:Destroy()
			orbits[player] = nil
		end
	end

	local function build(player: Player, root: BasePart): Orbit
		local holder = Instance.new("Folder")
		holder.Name = player.Name
		local icons = {}
		for index = 1, COUNT do
			local icon = Instance.new("BillboardGui")
			icon.Name = "Shield" .. index
			icon.Adornee = root
			icon.Size = UDim2.fromScale(ICON_SIZE, ICON_SIZE)
			icon.LightInfluence = 0
			icon.MaxDistance = 150
			local image = Instance.new("ImageLabel")
			image.Size = UDim2.fromScale(1, 1)
			image.BackgroundTransparency = 1
			image.Image = GameConfig.ShieldIcon
			image.Parent = icon
			icon.Parent = holder
			table.insert(icons, icon)
		end
		holder.Parent = container
		return { holder = holder, icons = icons }
	end

	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		local clock = os.clock()
		for _, player in Players:GetPlayers() do
			local untilTime = player:GetAttribute("ShieldUntil")
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not untilTime or now >= untilTime or not root then
				remove(player)
				continue
			end
			local orbit = orbits[player]
			if orbit and orbit.icons[1].Adornee ~= root then
				remove(player) -- respawned: start again on the new character
				orbit = nil
			end
			orbit = orbit or build(player, root)
			orbits[player] = orbit

			-- Blink in the last second; hidden while invisible.
			local left = untilTime - now
			local visible = not player:GetAttribute("Invisible") and (left > 1 or math.floor(clock * 8) % 2 == 0)
			for index, icon in orbit.icons do
				local angle = clock * SPIN + (index - 1) * (2 * math.pi / COUNT)
				local bob = math.sin(clock * 3 + index) * BOB
				icon.StudsOffsetWorldSpace = Vector3.new(math.cos(angle) * RADIUS, 0.5 + bob, math.sin(angle) * RADIUS)
				icon.Enabled = visible
			end
		end
		for player in orbits do
			if not player.Parent then
				remove(player)
			end
		end
	end)
end

return ShieldClient
