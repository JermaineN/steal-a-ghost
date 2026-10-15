-- Builds an anchored Part from a table of properties, e.g. Parts.make(folder, { Size = ..., Color = ... }).
local Parts = {}

function Parts.make(parent: Instance, props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

-- Draws a part "fullbright": every face except the bottom is painted with a SurfaceGui that
-- ignores scene lighting, so it looks lit up (like neon) in the dark without lighting up
-- anything around it. `brightness` above 1 pushes the colour past normal. Each face's fill is a
-- Frame named "Glow" (CollectEffect flashes these). Returns the SurfaceGuis, so callers can hide
-- them: a SurfaceGui still shows on an invisible part unless it's disabled.
function Parts.paintFullbright(part: BasePart, color: Color3, brightness: number): { SurfaceGui }
	local surfaces = {}
	for _, face in
		{ Enum.NormalId.Top, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }
	do
		local surface = Instance.new("SurfaceGui")
		surface.Name = "Fullbright" .. face.Name
		surface.Face = face
		surface.LightInfluence = 0
		surface.Brightness = brightness
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.PixelsPerStud = 20
		local glow = Instance.new("Frame")
		glow.Name = "Glow"
		glow.Size = UDim2.fromScale(1, 1)
		glow.BorderSizePixel = 0
		glow.BackgroundColor3 = color
		glow.Parent = surface
		surface.Parent = part
		table.insert(surfaces, surface)
	end
	return surfaces
end

return Parts
