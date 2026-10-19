param([string]$OutPath)
# Draws the Nuke item's icon (assets/nuke-icon.png): a chunky remote control, tipped to the
# right, with an antenna, a yellow-and-black hazard ring round a big red button, and a radiation
# sign underneath.
Add-Type -AssemblyName System.Drawing

$size = 256
$bmp = New-Object System.Drawing.Bitmap $size, $size
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)

function Color($a, $r, $gr, $b) { [System.Drawing.Color]::FromArgb($a, $r, $gr, $b) }
function RoundRect($x, $y, $w, $h, $r) {
	$p = New-Object System.Drawing.Drawing2D.GraphicsPath
	$p.AddArc($x, $y, $r * 2, $r * 2, 180, 90)
	$p.AddArc($x + $w - $r * 2, $y, $r * 2, $r * 2, 270, 90)
	$p.AddArc($x + $w - $r * 2, $y + $h - $r * 2, $r * 2, $r * 2, 0, 90)
	$p.AddArc($x, $y + $h - $r * 2, $r * 2, $r * 2, 90, 90)
	$p.CloseFigure()
	return $p
}

$inkColor = Color 255 15 15 18
$ink = New-Object System.Drawing.Pen $inkColor, 7
$ink.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$thin = New-Object System.Drawing.Pen $inkColor, 5

# Everything is drawn upright, then tipped 12 degrees to the right around the middle.
$g.TranslateTransform(128, 132)
$g.RotateTransform(12)
$g.TranslateTransform(-128, -132)

# Antenna with a red tip.
$g.DrawLine((New-Object System.Drawing.Pen $inkColor, 13), 150, 70, 168, 14)
$g.DrawLine((New-Object System.Drawing.Pen (Color 255 150 150 160), 6), 150, 70, 168, 14)
$g.FillEllipse((New-Object System.Drawing.SolidBrush (Color 255 255 60 45)), 157, 3, 22, 22)
$g.DrawEllipse($thin, 157, 3, 22, 22)

# Body.
$body = RoundRect 70 62 116 180 24
$g.FillPath((New-Object System.Drawing.SolidBrush (Color 255 62 66 78)), $body)
$side = RoundRect 160 70 22 166 10
$g.FillPath((New-Object System.Drawing.SolidBrush (Color 255 44 47 58)), $side)
$g.DrawPath($ink, $body)

# Hazard ring: yellow with black stripes, clipped to a circle.
$ring = New-Object System.Drawing.Drawing2D.GraphicsPath
$ring.AddEllipse(78, 74, 92, 92)
$g.FillPath((New-Object System.Drawing.SolidBrush (Color 255 255 205 40)), $ring)
$g.SetClip($ring)
$stripe = New-Object System.Drawing.Pen (Color 255 25 25 28), 12
for ($i = -100; $i -le 120; $i += 28) { $g.DrawLine($stripe, 78 + $i, 166, 170 + $i, 74) }
$g.ResetClip()
$g.DrawPath($ink, $ring)

# The big red button, with a darker rim and a white shine.
$g.FillEllipse((New-Object System.Drawing.SolidBrush (Color 255 160 20 20)), 92, 92, 64, 64)
$g.FillEllipse((New-Object System.Drawing.SolidBrush (Color 255 240 45 40)), 92, 86, 64, 60)
$g.DrawEllipse($ink, 92, 86, 64, 66)
$g.FillEllipse((New-Object System.Drawing.SolidBrush (Color 230 255 255 255)), 106, 94, 22, 13)

# Radiation sign (three blades round a dot) on a yellow disc.
$g.FillEllipse((New-Object System.Drawing.SolidBrush (Color 255 255 205 40)), 98, 178, 52, 52)
$g.DrawEllipse($thin, 98, 178, 52, 52)
$black = New-Object System.Drawing.SolidBrush (Color 255 25 25 28)
foreach ($start in @(-120, 0, 120)) { $g.FillPie($black, 104, 184, 40, 40, $start - 30, 60) }
$g.FillEllipse((New-Object System.Drawing.SolidBrush (Color 255 255 205 40)), 115, 195, 18, 18)
$g.FillEllipse($black, 119, 199, 10, 10)

# Shine down the body's left edge.
$g.FillPath((New-Object System.Drawing.SolidBrush (Color 150 255 255 255)), (RoundRect 80 176 9 50 4))

$g.Dispose()
$bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
