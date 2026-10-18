param([string]$ConePath, [string]$WavePath)
# Draws the Mega Mallet's two ground pictures (seen from above, the swinger at the centre,
# pointing up = the way they face), both a slice of a circle $half degrees each side of straight
# up (keep it equal to GameConfig.MegaMalletHalfAngle):
#   assets/mallet-cone.png  the red warning cone: see-through red, stronger toward the edge, with
#                           a bright red outline (where you'll get hit)
#   assets/mallet-wave.png  the shockwave: a glowing orange-white band along the outer edge only;
#                           growing the picture sweeps the band outward
Add-Type -AssemblyName System.Drawing

$size = 512
$c = $size / 2
$half = 50  # degrees each side of straight up
# GDI+ angles start at 3 o'clock and go clockwise; straight up is 270.
$start = 270 - $half
$sweep = 2 * $half

function New-Canvas {
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    return @($bmp, $g)
}

# The cone: red, more solid toward the edge (worked out pixel by pixel for a smooth fade).
$bmp, $g = New-Canvas
$outer = $c - 6
$cosHalf = [Math]::Cos($half * [Math]::PI / 180)
for ($y = 0; $y -lt $size; $y++) {
    for ($x = 0; $x -lt $size; $x++) {
        $dx = $x - $c; $dy = $c - $y
        $r = [Math]::Sqrt($dx * $dx + $dy * $dy)
        if ($r -gt $outer -or $r -lt 1) { continue }
        if ($dy / $r -lt $cosHalf) { continue }  # outside the slice
        $alpha = [int](40 + 110 * [Math]::Pow($r / $outer, 2))
        $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($alpha, 235, 30, 40))
    }
}
$edge = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 255, 60, 60)), 8
$edge.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$r = $c - 6
$g.DrawPie($edge, $c - $r, $c - $r, 2 * $r, 2 * $r, $start, $sweep)
$g.Dispose()
$bmp.Save($ConePath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

# The wave: a soft glowing band at the outer edge.
$bmp, $g = New-Canvas
$band = 26
for ($i = 0; $i -lt $band; $i++) {
    $r = $c - 4 - $i
    $t = $i / $band
    $alpha = [int](255 * (1 - $t) * (1 - $t))
    $color = [System.Drawing.Color]::FromArgb($alpha, 255, [int](230 - 120 * $t), [int](200 - 170 * $t))
    $pen = New-Object System.Drawing.Pen $color, 2
    $g.DrawArc($pen, $c - $r, $c - $r, 2 * $r, 2 * $r, $start, $sweep)
}
$g.Dispose()
$bmp.Save($WavePath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
