param([string]$OutPath)
# Draws the Smoke Bomb item's icon (assets/smoke-bomb-icon.png): a round dark bomb with a lit
# fuse and a puff of grey smoke behind it, in the same sticker style as the other item icons.
Add-Type -AssemblyName System.Drawing

$size = 256
$bmp = New-Object System.Drawing.Bitmap $size, $size
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)

$inkColor = [System.Drawing.Color]::FromArgb(255, 15, 15, 18)
$ink = New-Object System.Drawing.Pen $inkColor, 6
$ink.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

# Smoke puff behind the bomb (top right): overlapping grey circles.
$smoke = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 170, 168, 182))
$smokeLight = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 210, 208, 220))
$puffs = @(@(150, 30, 60), @(186, 52, 52), @(128, 58, 46), @(170, 82, 44))
$cloud = New-Object System.Drawing.Drawing2D.GraphicsPath
# Winding fill: where circles overlap counts as inside (the default leaves overlaps empty).
$cloud.FillMode = [System.Drawing.Drawing2D.FillMode]::Winding
foreach ($p in $puffs) { $cloud.AddEllipse($p[0], $p[1], $p[2], $p[2]) }
$region = New-Object System.Drawing.Region $cloud
$g.FillRegion($smoke, $region)
foreach ($p in $puffs) { $g.DrawEllipse($ink, $p[0], $p[1], $p[2], $p[2]) }
$g.FillRegion($smoke, $region)
foreach ($p in $puffs) { $g.FillEllipse($smokeLight, $p[0] + 8, $p[1] + 6, $p[2] * 0.4, $p[2] * 0.3) }

# Fuse cap and fuse.
$capBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 90, 84, 104))
$g.FillRectangle($capBrush, 108, 72, 40, 26)
$g.DrawRectangle($ink, 108, 72, 40, 26)
$fuse = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 150, 110, 70)), 8
$fuse.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$fuse.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$fuseOutline = New-Object System.Drawing.Pen $inkColor, 14
$fuseOutline.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$fuseOutline.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$fusePoints = [System.Drawing.Point[]]@((New-Object System.Drawing.Point 128, 74), (New-Object System.Drawing.Point 134, 52), (New-Object System.Drawing.Point 150, 40))
$g.DrawCurve($fuseOutline, $fusePoints)
$g.DrawCurve($fuse, $fusePoints)

# The bomb: a dark purple ball.
$bomb = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 52, 40, 72))
$g.FillEllipse($bomb, 44, 86, 168, 160)
$g.DrawEllipse($ink, 44, 86, 168, 160)
# A purple band around it.
$band = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 175, 95, 255)), 12
$g.DrawArc($band, 52, 150, 152, 44, 0, 180)
# White shine.
$shine = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(230, 255, 255, 255))
$g.FillEllipse($shine, 74, 114, 34, 24)
$g.FillEllipse($shine, 66, 146, 12, 12)

# Spark at the end of the fuse.
$sparkOuter = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 140, 30))
$sparkInner = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 235, 120))
$star = New-Object System.Drawing.Drawing2D.GraphicsPath
$cx = 152; $cy = 38
$pts = @()
for ($i = 0; $i -lt 16; $i++) {
    $r = if ($i % 2 -eq 0) { 24 } else { 10 }
    $a = [Math]::PI * 2 * $i / 16
    $pts += New-Object System.Drawing.PointF ($cx + $r * [Math]::Cos($a)), ($cy + $r * [Math]::Sin($a))
}
$star.AddPolygon([System.Drawing.PointF[]]$pts)
$g.FillPath($sparkOuter, $star)
$g.DrawPath((New-Object System.Drawing.Pen $inkColor, 4), $star)
$g.FillEllipse($sparkInner, $cx - 7, $cy - 7, 14, 14)

$g.Dispose()
$bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
