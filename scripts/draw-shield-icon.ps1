param([string]$OutPath)
# Draws the Shield item's icon (assets/shield-icon.png): a spectral blue heater shield with a
# darker right half, a white ghost emblem and a shine, in the same sticker style as the other
# item icons. The same picture circles a shielded player in game.
Add-Type -AssemblyName System.Drawing

$size = 256
$bmp = New-Object System.Drawing.Bitmap $size, $size
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)

$inkColor = [System.Drawing.Color]::FromArgb(255, 15, 15, 18)
$blue = [System.Drawing.Color]::FromArgb(255, 80, 200, 255)
$blueDark = [System.Drawing.Color]::FromArgb(255, 40, 130, 220)
$rim = [System.Drawing.Color]::FromArgb(255, 210, 240, 255)

# The shield's shape: flat top with rounded corners, sides curving down to a point.
function ShieldPath([float]$inset) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $l = 36 + $inset; $r = 220 - $inset; $t = 24 + $inset; $b = 236 - $inset
    $p.AddLine($l + 20, $t, $r - 20, $t)
    $p.AddArc($r - 40, $t, 40, 40, 270, 90)
    $p.AddBezier($r, $t + 20, $r, 150, 190, 200, 128, $b)
    $p.AddBezier(128, $b, 66, 200, $l, 150, $l, $t + 20)
    $p.AddArc($l, $t, 40, 40, 180, 90)
    $p.CloseFigure()
    return $p
}

$shield = ShieldPath 0
$outline = New-Object System.Drawing.Pen $inkColor, 16
$outline.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$g.DrawPath($outline, $shield)
$g.FillPath((New-Object System.Drawing.SolidBrush $rim), $shield)

# The face, inset from the rim: light left half, darker right half.
$face = ShieldPath 14
$g.FillPath((New-Object System.Drawing.SolidBrush $blue), $face)
$g.SetClip($face)
$g.FillRectangle((New-Object System.Drawing.SolidBrush $blueDark), 128, 0, 128, 256)
$g.ResetClip()
$g.DrawPath((New-Object System.Drawing.Pen $inkColor, 5), $face)

# A white ghost emblem in the middle.
$ghost = New-Object System.Drawing.Drawing2D.GraphicsPath
$ghost.AddArc(92, 78, 72, 72, 180, 180)
$ghost.AddLine(164, 114, 164, 162)
$ghost.AddLine(164, 162, 152, 150)
$ghost.AddLine(152, 150, 140, 162)
$ghost.AddLine(140, 162, 128, 150)
$ghost.AddLine(128, 150, 116, 162)
$ghost.AddLine(116, 162, 104, 150)
$ghost.AddLine(104, 150, 92, 162)
$ghost.CloseFigure()
$g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)), $ghost)
$g.DrawPath((New-Object System.Drawing.Pen $inkColor, 6), $ghost)
$eye = New-Object System.Drawing.SolidBrush $inkColor
$g.FillEllipse($eye, 108, 104, 12, 16)
$g.FillEllipse($eye, 136, 104, 12, 16)

# White shine on the top left.
$shine = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(220, 255, 255, 255))
$g.FillEllipse($shine, 62, 48, 40, 16)
$g.FillEllipse($shine, 58, 72, 12, 30)

$g.Dispose()
$bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
