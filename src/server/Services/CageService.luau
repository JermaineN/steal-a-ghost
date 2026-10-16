-- Caging: freezes a player in place inside an iron cage for GameConfig.CageSeconds.
-- Anchoring the HumanoidRootPart on the server pins the character (their device can't move an
-- anchored part). While caged they can't walk, jump or hold items, can't start a steal
-- (StealService checks the "Caged" attribute) and can't be knocked over by the bat.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Parts = require(script.Parent.Parent.Util.Parts)

local CageService = {}

local CAGE_SIZE = Vector3.new(6, 8, 6)
local BAR_THICKNESS = 0.25
local BAR_GAP = 1.5 -- studs between bars (wide enough to see who is inside)
local PLATE_THICKNESS = 0.4
local IRON = Color3.fromRGB(105, 108, 122)
local RIM = Color3.fromRGB(255, 140, 30) -- Halloween orange trim, like the hotbar icon

local cagesFolder: Folder

local function isCaged(player: Player): boolean
	return player:GetAttribute("Caged") == true
end
CageService.isCaged = isCaged

-- Builds the cage with its floor centred at `floor`. The caster's UserId is stored on it so
-- their device can let them walk through it (CageClient).
local function buildCage(floor: Vector3, caster: Player): Model
	local cage = Instance.new("Model")
	cage.Name = "Cage"
	cage:SetAttribute("CasterUserId", caster.UserId)
	local half = CAGE_SIZE / 2
	local function part(size: Vector3, offset: Vector3, color: Color3, material: Enum.Material)
		Parts.make(cage, {
			Size = size,
			CFrame = CFrame.new(floor + offset),
			Color = color,
			Material = material,
		})
	end

	-- Base and roof plates, with orange trim around the roof.
	part(
		Vector3.new(CAGE_SIZE.X, PLATE_THICKNESS, CAGE_SIZE.Z),
		Vector3.new(0, PLATE_THICKNESS / 2, 0),
		IRON,
		Enum.Material.Metal
	)
	part(
		Vector3.new(CAGE_SIZE.X, PLATE_THICKNESS, CAGE_SIZE.Z),
		Vector3.new(0, CAGE_SIZE.Y - PLATE_THICKNESS / 2, 0),
		IRON,
		Enum.Material.Metal
	)
	part(
		Vector3.new(CAGE_SIZE.X + 0.2, 0.25, CAGE_SIZE.Z + 0.2),
		Vector3.new(0, CAGE_SIZE.Y - PLATE_THICKNESS, 0),
		RIM,
		Enum.Material.Neon
	)

	-- Bars along all four sides (corners included).
	local barHeight = CAGE_SIZE.Y - 2 * PLATE_THICKNESS
	local barY = PLATE_THICKNESS + barHeight / 2
	local barSize = Vector3.new(BAR_THICKNESS, barHeight, BAR_THICKNESS)
	local count = math.floor(CAGE_SIZE.X / BAR_GAP)
	for i = 0, count do
		local along = -half.X + i * (CAGE_SIZE.X / count)
		part(barSize, Vector3.new(along, barY, -half.Z), IRON, Enum.Material.Metal)
		part(barSize, Vector3.new(along, barY, half.Z), IRON, Enum.Material.Metal)
		if i > 0 and i < count then -- the corners are already placed by the two rows above
			part(barSize, Vector3.new(-half.X, barY, along), IRON, Enum.Material.Metal)
			part(barSize, Vector3.new(half.X, barY, along), IRON, Enum.Material.Metal)
		end
	end

	cage.Parent = cagesFolder
	return cage
end

-- Cages the player (`caster` is who swung the cage). Returns false if they can't be caged right now.
function CageService.trap(player: Player, caster: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not humanoid or not root or humanoid.Health <= 0 or isCaged(player) then
		return false
	end
	player:SetAttribute("Caged", true)

	-- Stand them upright on the ground (they might be mid-jump), then pin them there.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, cagesFolder }
	local hit = workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, -20, 0), params)
	local floor = if hit then hit.Position else root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
	local standY = floor.Y + PLATE_THICKNESS + humanoid.HipHeight + root.Size.Y / 2
	local facing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if facing.Magnitude < 0.1 then
		facing = Vector3.new(0, 0, -1)
	end
	local standAt = Vector3.new(root.Position.X, standY, root.Position.Z)
	root.Anchored = true
	character:PivotTo(CFrame.lookAt(standAt, standAt + facing.Unit))

	local savedSpeed, savedJumpPower, savedJumpHeight = humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid:UnequipTools()
	local toolConnection = character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			task.defer(function()
				humanoid:UnequipTools()
			end)
		end
	end)

	local cage = buildCage(Vector3.new(standAt.X, floor.Y, standAt.Z), caster)

	-- Ends after CageSeconds, or straight away if they die (so a respawn starts free).
	local released = false
	local diedConnection: RBXScriptConnection
	local function release()
		if released then
			return
		end
		released = true
		cage:Destroy()
		toolConnection:Disconnect()
		diedConnection:Disconnect()
		if player.Parent then
			player:SetAttribute("Caged", nil)
		end
		if humanoid.Parent then
			root.Anchored = false
			humanoid.WalkSpeed = savedSpeed
			humanoid.JumpPower = savedJumpPower
			humanoid.JumpHeight = savedJumpHeight
		end
	end
	diedConnection = humanoid.Died:Connect(release)
	task.delay(GameConfig.CageSeconds, release)
	return true
end

function CageService.start()
	cagesFolder = Instance.new("Folder")
	cagesFolder.Name = "Cages"
	cagesFolder.Parent = workspace
end

return CageService
