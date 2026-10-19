-- Makes coloured text shimmer: every UIGradient tagged "AnimatedGradient" slides gently back and
-- forth, like the rare-spawn banners. The server tags the rarity (Legendary and rarer) and
-- mutation words on ghost labels (GhostLabel); windows can tag their own gradients too.
-- Each gradient starts at a different point, so labels next to each other don't move in step.
-- Gradients tagged "ShineGradient" (the glint on shiny titles, Shared.TitleText) instead sweep
-- across once every few seconds, like light catching the letters.
-- Looping colours (the Secret rarity's, also worn by THE GOAT) don't slide back and forth:
-- their pattern scrolls one way forever, wrapping round so there's no seam.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Theme = require(ReplicatedStorage.Shared.Theme)

local GradientAnimator = {}

GradientAnimator.TAG = "AnimatedGradient"
local SPEED = 0.9 -- how fast the colours drift
local SWING = 0.5 -- how far they slide each way (in widths of the text)
local SHINE_TAG = "ShineGradient"
local SHINE_SWEEP = 0.8 -- seconds for the glint to cross the text
local SHINE_EVERY = 2.6 -- seconds from one glint to the next
local LOOP_SECONDS = 5 -- seconds for a looping pattern to scroll one full width
-- Colours that loop instead of sliding back and forth. Each must start and end on the same colour.
local LOOPING = { Theme.RarityGradients.Secret }

local function sameColors(a: ColorSequence, b: ColorSequence): boolean
	if #a.Keypoints ~= #b.Keypoints then
		return false
	end
	for index, keypoint in a.Keypoints do
		local other = b.Keypoints[index]
		if math.abs(keypoint.Time - other.Time) > 1e-3 or keypoint.Value:ToHex() ~= other.Value:ToHex() then
			return false
		end
	end
	return true
end

-- True if these colours scroll in a loop (tag the gradient AnimatedGradient and it will).
function GradientAnimator.loops(colors: ColorSequence): boolean
	for _, looping in LOOPING do
		if sameColors(colors, looping) then
			return true
		end
	end
	return false
end

-- The pattern's colour at `x` (0 to 1).
local function colorAt(pattern: ColorSequence, x: number): Color3
	local keypoints = pattern.Keypoints
	for index = 2, #keypoints do
		local before, after = keypoints[index - 1], keypoints[index]
		if x <= after.Time then
			local span = after.Time - before.Time
			local alpha = if span > 0 then (x - before.Time) / span else 0
			return before.Value:Lerp(after.Value, alpha)
		end
	end
	return keypoints[#keypoints].Value
end

-- The pattern moved `shift` (0 to 1) of a width to the right, with what slides off the right
-- end coming back in on the left.
local function scrolled(pattern: ColorSequence, shift: number): ColorSequence
	local points = {}
	local keypoints = pattern.Keypoints
	-- The last keypoint is the same colour as the first, so it's skipped (it would land on it).
	for index = 1, #keypoints - 1 do
		local time = (keypoints[index].Time + shift) % 1
		if time > 1e-3 and time < 1 - 1e-3 then
			table.insert(points, { time = time, color = keypoints[index].Value })
		end
	end
	table.sort(points, function(a, b)
		return a.time < b.time
	end)
	local edge = colorAt(pattern, (1 - shift) % 1)
	local result = { ColorSequenceKeypoint.new(0, edge) }
	for _, point in points do
		table.insert(result, ColorSequenceKeypoint.new(point.time, point.color))
	end
	table.insert(result, ColorSequenceKeypoint.new(1, edge))
	return ColorSequence.new(result)
end

function GradientAnimator.start()
	local gradients: { [UIGradient]: number } = {} -- gradient -> its starting point
	local loops: { [UIGradient]: ColorSequence } = {} -- gradient -> its colours, unscrolled

	local function add(instance: Instance)
		if not instance:IsA("UIGradient") then
			return
		end
		if GradientAnimator.loops(instance.Color) then
			loops[instance] = instance.Color
			instance.Offset = Vector2.zero
		else
			gradients[instance] = math.random() * math.pi * 2
		end
	end
	for _, instance in CollectionService:GetTagged(GradientAnimator.TAG) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(GradientAnimator.TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(GradientAnimator.TAG):Connect(function(instance)
		gradients[instance :: UIGradient] = nil
		loops[instance :: UIGradient] = nil
	end)

	local shines: { [UIGradient]: boolean } = {}
	local function addShine(instance: Instance)
		if instance:IsA("UIGradient") then
			shines[instance] = true
		end
	end
	for _, instance in CollectionService:GetTagged(SHINE_TAG) do
		addShine(instance)
	end
	CollectionService:GetInstanceAddedSignal(SHINE_TAG):Connect(addShine)
	CollectionService:GetInstanceRemovedSignal(SHINE_TAG):Connect(function(instance)
		shines[instance :: UIGradient] = nil
	end)

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local t = now * SPEED
		for gradient, phase in gradients do
			gradient.Offset = Vector2.new(math.sin(t + phase) * SWING, 0)
		end
		local shift = (now / LOOP_SECONDS) % 1
		for gradient, pattern in loops do
			gradient.Color = scrolled(pattern, shift)
		end
		-- All glints sweep together (left to right, then wait off to the side).
		local sweep = math.min((now % SHINE_EVERY) / SHINE_SWEEP, 1)
		local shineOffset = Vector2.new(-1 + 2 * sweep, 0)
		for gradient in shines do
			gradient.Offset = shineOffset
		end
	end)
end

return GradientAnimator
