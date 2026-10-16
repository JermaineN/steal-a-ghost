-- Makes coloured text shimmer: every UIGradient tagged "AnimatedGradient" slides gently back and
-- forth, like the rare-spawn banners. The server tags the rarity (Legendary and rarer) and
-- mutation words on ghost labels (GhostLabel); windows can tag their own gradients too.
-- Each gradient starts at a different point, so labels next to each other don't move in step.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local GradientAnimator = {}

GradientAnimator.TAG = "AnimatedGradient"
local SPEED = 0.9 -- how fast the colours drift
local SWING = 0.5 -- how far they slide each way (in widths of the text)

function GradientAnimator.start()
	local gradients: { [UIGradient]: number } = {} -- gradient -> its starting point

	local function add(instance: Instance)
		if instance:IsA("UIGradient") then
			gradients[instance] = math.random() * math.pi * 2
		end
	end
	for _, instance in CollectionService:GetTagged(GradientAnimator.TAG) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(GradientAnimator.TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(GradientAnimator.TAG):Connect(function(instance)
		gradients[instance :: UIGradient] = nil
	end)

	RunService.RenderStepped:Connect(function()
		local t = os.clock() * SPEED
		for gradient, phase in gradients do
			gradient.Offset = Vector2.new(math.sin(t + phase) * SWING, 0)
		end
	end)
end

return GradientAnimator
