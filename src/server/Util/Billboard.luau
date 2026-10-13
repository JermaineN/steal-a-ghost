-- Creates floating text above a part. Returns the TextLabels so callers can update them.
local Billboard = {}

type Line = { text: string, color: Color3? }
type Options = { size: UDim2, offset: Vector3?, maxDistance: number?, lines: { Line } }

function Billboard.create(adornee: BasePart, options: Options): { TextLabel }
	local gui = Instance.new("BillboardGui")
	gui.Name = "Billboard"
	gui.Size = options.size
	gui.StudsOffset = options.offset or Vector3.zero
	gui.MaxDistance = options.maxDistance or 100
	gui.LightInfluence = 0
	gui.Adornee = adornee

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = gui

	local labels = {}
	for index, line in options.lines do
		local label = Instance.new("TextLabel")
		label.Name = "Line" .. index
		label.LayoutOrder = index
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1 / #options.lines)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = line.text
		label.TextColor3 = line.color or Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.3
		label.Parent = gui
		labels[index] = label
	end

	gui.Parent = adornee
	return labels
end

return Billboard
