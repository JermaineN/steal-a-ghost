-- Draws a title's word (TitleConfig) into a GUI: white text with a thick dark outline, tinted by
-- the title's gradient, plus a glint layer on top for shiny titles. Used by both the server (the
-- title above each player's head) and the client (the Inventory's title cards). Clients animate
-- the tagged gradients (client GradientAnimator): the colours slide, the glint sweeps across.
local CollectionService = game:GetService("CollectionService")

local TitleText = {}

TitleText.ANIMATED_TAG = "AnimatedGradient"
TitleText.SHINE_TAG = "ShineGradient"

local function label(props: { [string]: any }): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	for key, value in props do
		(text :: any)[key] = value
	end
	return text
end

-- Builds the title in `parent`, filling it (position and size it with a Frame or the parent).
-- Returns the main label.
function TitleText.create(parent: Instance, title, outlineThickness: number?): TextLabel
	local main = label({ Name = "Title", Size = UDim2.fromScale(1, 1), Text = title.text })
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(15, 5, 25)
	stroke.Thickness = outlineThickness or 3
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = main
	local colors = Instance.new("UIGradient")
	colors.Color = title.gradient
	colors.Parent = main
	CollectionService:AddTag(colors, TitleText.ANIMATED_TAG)
	main.Parent = parent

	-- The glint: the same word in white on top, see-through except for a narrow slanted band
	-- that the client sweeps across the letters.
	if title.shine then
		local glint =
			label({ Name = "Glint", Size = UDim2.fromScale(1, 1), Text = title.text, ZIndex = main.ZIndex + 1 })
		local band = Instance.new("UIGradient")
		band.Rotation = 20
		band.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.4, 1),
			NumberSequenceKeypoint.new(0.5, 0.15),
			NumberSequenceKeypoint.new(0.6, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		band.Offset = Vector2.new(-1, 0) -- off to the side until the client sweeps it
		band.Parent = glint
		CollectionService:AddTag(band, TitleText.SHINE_TAG)
		glint.Parent = main
	end
	return main
end

-- The colour of a ColorSequence at `t` (0..1).
local function colorAt(sequence: ColorSequence, t: number): Color3
	local keypoints = sequence.Keypoints
	for index = 1, #keypoints - 1 do
		local a, b = keypoints[index], keypoints[index + 1]
		if t <= b.Time then
			return a.Value:Lerp(b.Value, (t - a.Time) / math.max(b.Time - a.Time, 1e-6))
		end
	end
	return keypoints[#keypoints].Value
end

-- The title as rich text for chat ("[THE GOAT]"), each letter coloured from the title's
-- gradient so it looks like the one above their head (chat text can't animate).
function TitleText.richText(title): string
	local text = "[" .. title.text .. "]"
	local length = utf8.len(text) or #text
	local parts = {}
	local index = 0
	for _, code in utf8.codes(text) do
		local character = utf8.char(code)
		if character == " " then
			table.insert(parts, " ")
		else
			local color = colorAt(title.gradient, if length > 1 then index / (length - 1) else 0)
			table.insert(parts, `<font color="#{color:ToHex()}">{character}</font>`)
		end
		index += 1
	end
	return "<b>" .. table.concat(parts) .. "</b>"
end

return TitleText
