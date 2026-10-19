param([string]$OutDir)
# Draws the side menu's icons (assets/menu-*.png) in one matching "sticker" style: thick dark
# outlines, flat Halloween colours and a white shine. 256x256, transparent background.
Add-Type -AssemblyName System.Drawing

$INK = [System.Drawing.Color]::FromArgb(255, 20, 10, 30)
$SHINE = [System.Drawing.Color]::FromArgb(150, 255, 255, 255)
$GHOST = [System.Drawing.Color]::FromArgb(255, 240, 240, 255)

function New-Canvas {
	$bmp = New-Object System.Drawing.Bitmap 256, 256
	$g = [System.Drawing.Graphics]::FromImage($bmp)
	$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
	$g.Clear([System.Drawing.Color]::Transparent)
	return @($bmp, $g)
}
function Pen($color, $width) {
	$p = New-Object System.Drawing.Pen $color, $width
	$p.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
	$p.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
	$p.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
	return $p
}
function Brush($r, $g, $b) { return New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, $r, $g, $b)) }
function RoundRect($x, $y, $w, $h, $r) {
	$p = New-Object System.Drawing.Drawing2D.GraphicsPath
	$p.AddArc($x, $y, $r * 2, $r * 2, 180, 90)
	$p.AddArc($x + $w - $r * 2, $y, $r * 2, $r * 2, 270, 90)
	$p.AddArc($x + $w - $r * 2, $y + $h - $r * 2, $r * 2, $r * 2, 0, 90)
	$p.AddArc($x, $y + $h - $r * 2, $r * 2, $r * 2, 90, 90)
	$p.CloseFigure()
	return $p
}
# Fill a shape and outline it.
function Sticker($g, $path, $brush) {
	$g.DrawPath((Pen $INK 12), $path)
	$g.FillPath($brush, $path)
}
# A little ghost: round head, straight sides, wavy bottom, two eyes. (cx, cy) is its centre.
function Ghost($g, $cx, $cy, $size) {
	$w = $size; $h = $size * 1.15
	$x = $cx - $w / 2; $y = $cy - $h / 2
	$p = New-Object System.Drawing.Drawing2D.GraphicsPath
	$p.AddArc($x, $y, $w, $w, 180, 180)
	$p.AddLine($x + $w, $y + $w / 2, $x + $w, $y + $h)
	$wave = $w / 3
	$p.AddBezier($x + $w, $y + $h, $x + $w - $wave * 0.5, $y + $h - $wave * 0.6, $x + $w - $wave * 0.5, $y + $h - $wave * 0.6, $x + $w - $wave, $y + $h)
	$p.AddBezier($x + $w - $wave, $y + $h, $x + $w - $wave * 1.5, $y + $h - $wave * 0.6, $x + $w - $wave * 1.5, $y + $h - $wave * 0.6, $x + $wave, $y + $h)
	$p.AddBezier($x + $wave, $y + $h, $x + $wave * 0.5, $y + $h - $wave * 0.6, $x + $wave * 0.5, $y + $h - $wave * 0.6, $x, $y + $h)
	$p.CloseFigure()
	$g.DrawPath((Pen $INK ([Math]::Max(6, $size / 9))), $p)
	$g.FillPath((New-Object System.Drawing.SolidBrush $GHOST), $p)
	$eye = $size / 7
	$inkBrush = New-Object System.Drawing.SolidBrush $INK
	$g.FillEllipse($inkBrush, $cx - $size * 0.2 - $eye / 2, $cy - $size * 0.12, $eye, $eye * 1.4)
	$g.FillEllipse($inkBrush, $cx + $size * 0.2 - $eye / 2, $cy - $size * 0.12, $eye, $eye * 1.4)
}
function Save($bmp, $g, $name) {
	$g.Dispose()
	$bmp.Save((Join-Path $OutDir $name), [System.Drawing.Imaging.ImageFormat]::Png)
	$bmp.Dispose()
}

# --- Shop: a money bag with a big green $ ---
$bmp, $g = New-Canvas
$sack = New-Object System.Drawing.Drawing2D.GraphicsPath
$sack.AddEllipse(40, 86, 176, 150)
$neck = New-Object System.Drawing.Drawing2D.GraphicsPath
$neck.AddPolygon(@((New-Object System.Drawing.PointF 100, 52), (New-Object System.Drawing.PointF 156, 52), (New-Object System.Drawing.PointF 146, 100), (New-Object System.Drawing.PointF 110, 100)))
$top = New-Object System.Drawing.Drawing2D.GraphicsPath
$top.AddEllipse(84, 22, 88, 44)
$tan = Brush 218 172 100
Sticker $g $sack $tan
Sticker $g $neck $tan
Sticker $g $top $tan
Sticker $g (RoundRect 92 88 72 22 10) (Brush 125 78 38)
$g.DrawArc((Pen $SHINE 10), 62, 108, 70, 90, 190, 70)
$dollar = New-Object System.Drawing.Drawing2D.GraphicsPath
$font = New-Object System.Drawing.FontFamily "Arial Black"
$dollar.AddString('$', $font, 0, 120, (New-Object System.Drawing.PointF 74, 100), [System.Drawing.StringFormat]::GenericDefault)
$g.DrawPath((Pen $INK 12), $dollar)
$g.FillPath((Brush 70 220 90), $dollar)
Save $bmp $g "menu-shop.png"

# --- Rebirth: two arrows chasing each other around a little ghost ---
$bmp, $g = New-Canvas
$purple = [System.Drawing.Color]::FromArgb(255, 175, 95, 255)
foreach ($start in @(205, 25)) {
	$g.DrawArc((Pen $INK 40), 34, 34, 188, 188, $start, 120)
	$g.DrawArc((Pen $purple 24), 34, 34, 188, 188, $start, 120)
	# Arrowhead at the end of the arc, pointing along the circle (clockwise).
	$a = ($start + 120) * [Math]::PI / 180
	$cx = 128 + 94 * [Math]::Cos($a); $cy = 128 + 94 * [Math]::Sin($a)
	$tx = -[Math]::Sin($a); $ty = [Math]::Cos($a)   # direction of travel
	$nx = [Math]::Cos($a); $ny = [Math]::Sin($a)    # outward
	$tip = New-Object System.Drawing.PointF ($cx + $tx * 34), ($cy + $ty * 34)
	$left = New-Object System.Drawing.PointF ($cx + $nx * 30), ($cy + $ny * 30)
	$right = New-Object System.Drawing.PointF ($cx - $nx * 30), ($cy - $ny * 30)
	$head = New-Object System.Drawing.Drawing2D.GraphicsPath
	$head.AddPolygon(@($tip, $left, $right))
	$g.DrawPath((Pen $INK 12), $head)
	$g.FillPath((New-Object System.Drawing.SolidBrush $purple), $head)
}
Ghost $g 128 132 78
Save $bmp $g "menu-rebirth.png"

# --- Index: a spellbook with a ghost on the cover and an orange bookmark ---
$bmp, $g = New-Canvas
Sticker $g (RoundRect 62 196 146 30 8) (Brush 245 235 210)   # pages showing at the bottom
Sticker $g (RoundRect 50 30 156 182 18) (Brush 125 70 205)   # cover
$g.FillRectangle((Brush 95 50 165), 56, 36, 22, 170)          # spine shading
$g.DrawLine((Pen $INK 6), 80, 36, 80, 206)
$ribbon = New-Object System.Drawing.Drawing2D.GraphicsPath
$ribbon.AddPolygon(@((New-Object System.Drawing.PointF 168, 30), (New-Object System.Drawing.PointF 190, 30), (New-Object System.Drawing.PointF 190, 98), (New-Object System.Drawing.PointF 179, 86), (New-Object System.Drawing.PointF 168, 98)))
Sticker $g $ribbon (Brush 255 140 30)
$g.DrawLine((Pen $SHINE 8), 96, 50, 150, 50)
Ghost $g 136 126 72
Save $bmp $g "menu-index.png"

# --- Inventory: an orange backpack ---
$bmp, $g = New-Canvas
$g.DrawArc((Pen $INK 30), 92, 14, 72, 70, 180, 180)            # handle
$g.DrawArc((Pen (([System.Drawing.Color]::FromArgb(255, 150, 80, 30))) 14), 92, 14, 72, 70, 180, 180)
Sticker $g (RoundRect 52 46 152 186 40) (Brush 245 135 40)       # body
Sticker $g (RoundRect 52 46 152 74 36) (Brush 210 100 25)        # top flap
Sticker $g (RoundRect 82 140 92 70 18) (Brush 210 100 25)        # front pocket
Sticker $g (RoundRect 116 104 24 30 6) (Brush 255 215 90)        # buckle
$g.DrawLine((Pen $INK 6), 96, 160, 160, 160)                     # pocket seam
$g.DrawArc((Pen $SHINE 10), 66, 128, 40, 80, 150, 70)
Save $bmp $g "menu-inventory.png"

# --- Codes: a teal gift box with an orange ribbon and bow ---
$bmp, $g = New-Canvas
$orange = Brush 255 140 30
foreach ($loop in @(@(62, 22, 66, 56, 20), @(128, 22, 66, 56, -20))) {   # bow loops
	$bow = New-Object System.Drawing.Drawing2D.GraphicsPath
	$bow.AddEllipse($loop[0], $loop[1], $loop[2], $loop[3])
	$m = New-Object System.Drawing.Drawing2D.Matrix
	$m.RotateAt($loop[4], (New-Object System.Drawing.PointF ($loop[0] + $loop[2] / 2), ($loop[1] + $loop[3] / 2)))
	$bow.Transform($m)
	Sticker $g $bow $orange
}
Sticker $g (RoundRect 50 120 156 108 14) (Brush 40 175 165)    # box
Sticker $g (RoundRect 36 82 184 50 14) (Brush 60 215 200)      # lid
Sticker $g (RoundRect 112 132 32 96 4) $orange                 # ribbon down the box
Sticker $g (RoundRect 110 82 36 50 4) $orange                  # ribbon over the lid
$g.FillEllipse((New-Object System.Drawing.SolidBrush $INK), 110, 58, 36, 34)   # knot
$g.FillEllipse((Brush 255 175 70), 116, 63, 24, 24)
$g.DrawLine((Pen $SHINE 10), 54, 98, 96, 98)
$g.DrawLine((Pen $SHINE 10), 66, 140, 66, 200)
Save $bmp $g "menu-codes.png"
