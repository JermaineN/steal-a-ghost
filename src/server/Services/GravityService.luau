-- Gravity (a Shop item, used from the hotbar): click to open a gravity well around you for
-- GravitySeconds. You're slowed down while it lasts. Everyone else inside GravityRadius is
-- pulled toward you: their own devices do the pulling (client GravityClient), since each
-- player's device moves their character. The server marks the well with a "GravityUntil"
-- attribute on you (server time), draws the swirling vortex everyone sees, and catches anyone
-- pulled within GravityCatchRadius: they drop a ghost they were stealing (it flies home), like
-- being hit. While it's open you can't be knocked over (RagdollService.canKnock); it still ends
-- early if you're caged or die. Cooldown starts on use.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Notify = require(script.Parent.Parent.Util.Notify)
local DataService = require(script.Parent.DataService)
local RagdollService = require(script.Parent.RagdollService)
local StealService = require(script.Parent.StealService)

local GravityService = {}

GravityService.ITEM_ID = "gravity"

local VOID_PURPLE = Color3.fromRGB(110, 60, 200)
local GLOW_PURPLE = Color3.fromRGB(205, 150, 255)
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

-- When each player's gravity can next be used, in server time.
local readyAt: { [Player]: number } = {}

-- A visual-only part welded to the user's character (never collides, weighs nothing).
local function visualPart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

-- The well everyone sees, attached to the user: a faint purple tint on the ground the size of
-- the pull area with a glowing ring at its edge (the edge of the pull), streaks of light swirling
-- in from the ring toward the middle, a dark vortex under the user, a warping whoosh as it opens
-- and a rumbling hum while it lasts. Returns the
-- folder holding it all, and a function that fades it out.
local function buildWell(character: Model, root: BasePart): (Model, () -> ())
	local well = Instance.new("Model")
	well.Name = "GravityWell"
	local radius = GameConfig.GravityRadius
	local groundOffset = CFrame.new(0, -2.9, 0) -- the root sits about 3 studs above the ground

	-- The area: a faint purple tint on the ground (a thin cylinder lying flat; a cylinder's round
	-- faces point along its X axis), so the world under it still shows.
	local disc = visualPart({
		Name = "Area",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, radius * 2, radius * 2),
		Color = VOID_PURPLE,
		Material = Enum.Material.Neon,
		Transparency = 0.88,
	})
	disc.CFrame = root.CFrame * groundOffset * CFrame.Angles(0, 0, math.rad(90))
	disc.Parent = well

	-- A bright glowing ring of short segments marks the edge of the pull.
	local ringParts = {}
	local segments = 64
	local segmentLength = 2 * math.pi * radius / segments + 0.3
	for index = 1, segments do
		local angle = index / segments * math.pi * 2
		local segment = visualPart({
			Name = "Edge",
			Size = Vector3.new(segmentLength, 0.35, 0.6),
			Color = GLOW_PURPLE,
			Material = Enum.Material.Neon,
			Transparency = 0.15,
		})
		segment.CFrame = root.CFrame * groundOffset * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0.15, -radius)
		segment.Parent = well
		table.insert(ringParts, segment)
	end

	-- Streaks swirling inward from the edge to the middle: the pull, made visible. The disc shape
	-- with "Inward" sends each particle from the rim toward the centre.
	local streaks = Instance.new("ParticleEmitter")
	streaks.Name = "Pull"
	streaks.Texture = SPARKLE_TEXTURE
	streaks.Color = ColorSequence.new(GLOW_PURPLE, VOID_PURPLE)
	streaks.LightEmission = 1
	streaks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(0.7, 1.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	streaks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.2),
		NumberSequenceKeypoint.new(1, 0.6),
	})
	streaks.Lifetime = NumberRange.new(1.4, 1.6)
	streaks.Speed = NumberRange.new(radius / 1.5)
	-- The cylinder lies on its side, so its Right face is the one pointing up.
	streaks.EmissionDirection = Enum.NormalId.Right
	streaks.Shape = Enum.ParticleEmitterShape.Disc
	streaks.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	streaks.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	streaks.ShapePartial = 0 -- only the outer rim
	streaks.Rotation = NumberRange.new(0, 360)
	streaks.RotSpeed = NumberRange.new(180, 360)
	streaks.Rate = 160
	streaks.Parent = disc

	-- A dark vortex on the ground under the user, where the streaks end up.
	local core = visualPart({
		Name = "Core",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.25, 6, 6),
		Color = Color3.fromRGB(25, 12, 45),
		Material = Enum.Material.Neon,
		Transparency = 0.25,
	})
	core.CFrame = root.CFrame * groundOffset * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90))
	core.Parent = well
	local coreLight = Instance.new("PointLight")
	coreLight.Color = GLOW_PURPLE
	coreLight.Range = 20
	coreLight.Brightness = 3
	coreLight.Parent = core
	local swirl = Instance.new("ParticleEmitter")
	swirl.Texture = SPARKLE_TEXTURE
	swirl.Color = ColorSequence.new(GLOW_PURPLE)
	swirl.LightEmission = 1
	swirl.Size = NumberSequence.new(0.8, 0)
	swirl.Lifetime = NumberRange.new(0.5, 0.8)
	swirl.Speed = NumberRange.new(4)
	swirl.EmissionDirection = Enum.NormalId.Right
	swirl.Shape = Enum.ParticleEmitterShape.Disc
	swirl.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	swirl.Rate = 40
	swirl.Parent = core

	local hum = Instance.new("Sound")
	hum.SoundId = "rbxassetid://" .. GameConfig.GravitySound.soundId
	hum.Volume = GameConfig.GravitySound.volume
	hum.Looped = true
	hum.RollOffMaxDistance = radius * 3
	hum.Parent = core
	local warp = Instance.new("Sound")
	warp.Name = "Warp"
	warp.SoundId = "rbxassetid://" .. GameConfig.GravityWarpSound.soundId
	warp.Volume = GameConfig.GravityWarpSound.volume
	warp.RollOffMaxDistance = radius * 3
	warp.Parent = core

	-- Everything rides along with the user.
	local allParts = table.clone(ringParts)
	table.insert(allParts, disc)
	table.insert(allParts, core)
	for _, part in allParts do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end
	well.Parent = character
	hum:Play()
	warp:Play()

	-- The disc grows out from the user when it opens.
	disc.Size = Vector3.new(0.2, 4, 4)
	TweenService
		:Create(disc, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = Vector3.new(0.2, radius * 2, radius * 2) })
		:Play()

	local function fadeOut()
		streaks.Enabled = false
		swirl.Enabled = false
		TweenService:Create(hum, TweenInfo.new(0.4), { Volume = 0 }):Play()
		TweenService:Create(warp, TweenInfo.new(0.4), { Volume = 0 }):Play()
		TweenService:Create(disc, TweenInfo.new(0.4), { Size = Vector3.new(0.2, 2, 2) }):Play()
		TweenService:Create(core, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		for _, segment in ringParts do
			TweenService:Create(segment, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end
		task.delay(1.6, function() -- let the last streaks finish
			well:Destroy()
		end)
	end
	return well, fadeOut
end

-- Called by ItemService when a player clicks while holding Gravity.
function GravityService.tryUse(player: Player, tool: Tool)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	if
		DataService.getItemCount(player, GravityService.ITEM_ID) <= 0
		or player:GetAttribute("GravityUntil")
		or player:GetAttribute("Invisible")
		or player:GetAttribute("Caged")
		or player:GetAttribute("Carrying")
		or RagdollService.isRagdolled(player)
	then
		return
	end
	local now = workspace:GetServerTimeNow()
	local waitLeft = (readyAt[player] or 0) - now
	if waitLeft > 0 then
		Notify.send(player, "Gravity ready in " .. math.ceil(waitLeft) .. "s", "error")
		return
	end
	readyAt[player] = now + GameConfig.GravityCooldownSeconds
	tool:SetAttribute("ReadyAt", readyAt[player])

	-- Open the well: slow the user, tell every device to start pulling, and draw it.
	local endsAt = now + GameConfig.GravitySeconds
	player:SetAttribute("GravityUntil", endsAt)
	humanoid.WalkSpeed = GameConfig.GravityUserWalkSpeed
	local _, fadeOut = buildWell(character, root)

	-- While it's open, catch anyone pulled in close: they drop a stolen ghost (and a WANTED
	-- player's bounty is claimed), the same as being hit. Each player is caught once per well.
	local caught: { [Player]: boolean } = {}
	task.spawn(function()
		while workspace:GetServerTimeNow() < endsAt and player.Parent do
			local stillUp = player.Character == character and humanoid.Health > 0 and not player:GetAttribute("Caged")
			if not stillUp then
				break
			end
			for _, other in Players:GetPlayers() do
				local otherRoot = other ~= player
					and other.Character
					and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				-- Shielded players aren't pulled (client GravityClient) or caught.
				local shieldUntil = other:GetAttribute("ShieldUntil")
				local shielded = shieldUntil and workspace:GetServerTimeNow() < shieldUntil
				if otherRoot and not caught[other] and not shielded then
					local offset = otherRoot.Position - root.Position
					local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
					if flat <= GameConfig.GravityCatchRadius then
						caught[other] = true
						StealService.knockLoose(player, other, "caught")
					end
				end
			end
			RunService.Heartbeat:Wait()
		end

		-- Close the well.
		player:SetAttribute("GravityUntil", nil)
		-- A cage holds them still and gives back normal speed itself when it opens (CageService).
		if humanoid.Parent and not player:GetAttribute("Carrying") and not player:GetAttribute("Caged") then
			humanoid.WalkSpeed = GameConfig.WalkSpeed
		end
		fadeOut()
	end)
end

-- Gravity's cooldown for a new copy of the tool (after respawning).
function GravityService.readyAt(player: Player): number?
	return readyAt[player]
end

function GravityService.start()
	Players.PlayerRemoving:Connect(function(player)
		readyAt[player] = nil
	end)
end

return GravityService
