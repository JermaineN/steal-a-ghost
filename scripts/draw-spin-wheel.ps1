param([string]$WedgePath, [string]$IconPath)
# Draws the Spin Wheel's two pictures:
#   assets/spin-wedge.png       one 60-degree slice of the wheel, pointing straight up from the
#                               picture's centre: white (the game tints it with each prize's
#                               colour), slightly darker toward the middle, with a thick dark
#                               outline. Six of them turned 60 degrees apart make the wheel.
#   assets/spin-wheel-icon.png  the window's icon: a little six-colour prize wheel with a pin on
#                               top, in the same sticker style as the other icons.
Add-Type -AssemblyName System.Drawing

$ink = [System.Drawing.Color]::FromArgb(255, 15, 15, 18)

function New-Canvas([int]$size) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    return @($bmp, $g)
}

# --- The wedge ---
$size = 512
$c = $size / 2
$r = $c - 6
$bmp, $g = New-Canvas $size
# GDI+ angles start at 3 o'clock and go clockwise; straight up is 270.
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$path.AddPie($c - $r, $c - $r, 2 * $r, 2 * $r, 240, 60)
# White at the rim, a soft grey toward the centre.
$fill = New-Object System.Drawing.Drawing2D.PathGradientBrush $path
$fill.CenterPoint = New-Object System.Drawing.PointF $c, $c
$fill.CenterColor = [System.Drawing.Color]::FromArgb(255, 185, 185, 195)
$fill.SurroundColors = @([System.Drawing.Color]::White)
$g.FillPath($fill, $path)
$outline = New-Object System.Drawing.Pen $ink, 8
$outline.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$g.DrawPath($outline, $path)
$g.Dispose()
$bmp.Save($WedgePath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

# --- The icon ---
$size = 256
$c = 128
$cy = 136
$r = 96
$bmp, $g = New-Canvas $size
$colors = @(
    [System.Drawing.Color]::FromArgb(255, 80, 190, 255),   # gems blue
    [System.Drawing.Color]::FromArgb(255, 90, 220, 110),   # money green
    [System.Drawing.Color]::FromArgb(255, 80, 190, 255),
    [System.Drawing.Color]::FromArgb(255, 255, 60, 90),    # mythic red
    [System.Drawing.Color]::FromArgb(255, 80, 190, 255),
    [System.Drawing.Color]::FromArgb(255, 90, 220, 110)
)
# Thick outline first, then the slices on top.
$g.FillEllipse((New-Object System.Drawing.SolidBrush $ink), $c - $r - 10, $cy - $r - 10, 2 * $r + 20, 2 * $r + 20)
for ($i = 0; $i -lt 6; $i++) {
    $g.FillPie((New-Object System.Drawing.SolidBrush $colors[$i]), $c - $r, $cy - $r, 2 * $r, 2 * $r, 240 + 60 * $i, 60)
}
$divider = New-Object System.Drawing.Pen $ink, 6
for ($i = 0; $i -lt 6; $i++) {
    $a = (240 + 60 * $i) * [Math]::PI / 180
    $g.DrawLine($divider, $c, $cy, $c + $r * [Math]::Cos($a), $cy + $r * [Math]::Sin($a))
}
# White shine on the top-left of the rim.
$shine = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(200, 255, 255, 255)), 9
$shine.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$shine.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$g.DrawArc($shine, $c - $r + 14, $cy - $r + 14, 2 * $r - 28, 2 * $r - 28, 195, 50)
# The hub.
$g.FillEllipse((New-Object System.Drawing.SolidBrush $ink), $c - 22, $cy - 22, 44, 44)
$g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 200, 60))), $c - 14, $cy - 14, 28, 28)
# The pin at the top, pointing down into the wheel.
$pin = New-Object System.Drawing.Drawing2D.GraphicsPath
$pin.AddPolygon(@(
    (New-Object System.Drawing.PointF ($c - 24), 14),
    (New-Object System.Drawing.PointF ($c + 24), 14),
    (New-Object System.Drawing.PointF $c, 70)
))
$pinOutline = New-Object System.Drawing.Pen $ink, 10
$pinOutline.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$g.DrawPath($pinOutline, $pin)
$g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 200, 60))), $pin)
$g.Dispose()
$bmp.Save($IconPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
