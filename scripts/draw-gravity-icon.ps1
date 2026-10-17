param([string]$OutPath)
# Draws the Gravity item's icon (assets/gravity-icon.png): a swirling purple vortex with a dark
# core and three bright arms curling inward, in the same sticker style as the other item icons.
Add-Type -AssemblyName System.Drawing

$size = 256
$bmp = New-Object System.Drawing.Bitmap $size, $size
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)

$inkColor = [System.Drawing.Color]::FromArgb(255, 15, 15, 18)
$cx = 128; $cy = 128

# Outer glow disc.
$glow = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 110, 60, 200))
$g.FillEllipse($glow, 22, 22, 212, 212)
$g.DrawEllipse((New-Object System.Drawing.Pen $inkColor, 7), 22, 22, 212, 212)
$mid = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 80, 40, 160))
$g.FillEllipse($mid, 52, 52, 152, 152)

# Three swirl arms curling into the centre, each with an arrowhead pointing inward.
function Draw-Arm($angleOffset) {
    $points = @()
    for ($i = 0; $i -le 20; $i++) {
        $t = $i / 20
        $r = 86 - 60 * $t
        $a = ($angleOffset + 200 * $t) * [Math]::PI / 180
        $points += New-Object System.Drawing.PointF ($cx + $r * [Math]::Cos($a)), ($cy + $r * [Math]::Sin($a))
    }
    $outline = New-Object System.Drawing.Pen $inkColor, 22
    $outline.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $outline.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawCurve($outline, [System.Drawing.PointF[]]$points)
    $arm = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 205, 150, 255)), 12
    $arm.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $arm.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawCurve($arm, [System.Drawing.PointF[]]$points)
}
Draw-Arm 0
Draw-Arm 120
Draw-Arm 240

# Dark core with a bright rim.
$core = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 25, 12, 45))
$g.FillEllipse($core, 98, 98, 60, 60)
$g.DrawEllipse((New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 230, 200, 255)), 5), 98, 98, 60, 60)
$g.DrawEllipse((New-Object System.Drawing.Pen $inkColor, 3), 95, 95, 66, 66)

# White shine on the outer disc.
$shine = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(200, 255, 255, 255))
$g.FillEllipse($shine, 60, 42, 30, 16)

$g.Dispose()
$bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
