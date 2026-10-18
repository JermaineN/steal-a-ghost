param([string]$OutPath)
# Draws the Mega Mallet item's icon (assets/mallet-icon.png): a huge iron mallet lying
# diagonally, with a wooden handle, glowing red striking faces and a shine, in the same sticker
# style as the other item icons.
Add-Type -AssemblyName System.Drawing

$size = 256
$bmp = New-Object System.Drawing.Bitmap $size, $size
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)

$ink = [System.Drawing.Color]::FromArgb(255, 15, 15, 18)
$wood = [System.Drawing.Color]::FromArgb(255, 150, 95, 55)
$woodDark = [System.Drawing.Color]::FromArgb(255, 110, 65, 35)
$iron = [System.Drawing.Color]::FromArgb(255, 95, 90, 115)
$ironDark = [System.Drawing.Color]::FromArgb(255, 60, 55, 78)
$glow = [System.Drawing.Color]::FromArgb(255, 255, 70, 50)

# Everything on a diagonal: handle bottom-left, head top-right.
$g.TranslateTransform(128, 128)
$g.RotateTransform(-40)
$g.TranslateTransform(-128, -128)

$outline = New-Object System.Drawing.Pen $ink, 14
$outline.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

# Handle.
$handle = New-Object System.Drawing.Drawing2D.GraphicsPath
$handle.AddRectangle((New-Object System.Drawing.Rectangle 30, 116, 130, 26))
$g.DrawPath($outline, $handle)
$g.FillPath((New-Object System.Drawing.SolidBrush $wood), $handle)
$g.FillRectangle((New-Object System.Drawing.SolidBrush $woodDark), 30, 132, 130, 10)
# Grip wraps.
$wrap = New-Object System.Drawing.SolidBrush $ink
foreach ($x in 44, 62, 80) { $g.FillRectangle($wrap, $x, 116, 6, 26) }

# Head: a big block with rounded corners.
$head = New-Object System.Drawing.Drawing2D.GraphicsPath
$hx = 150; $hy = 62; $hw = 84; $hh = 134; $r = 18
$head.AddArc($hx, $hy, $r, $r, 180, 90)
$head.AddArc($hx + $hw - $r, $hy, $r, $r, 270, 90)
$head.AddArc($hx + $hw - $r, $hy + $hh - $r, $r, $r, 0, 90)
$head.AddArc($hx, $hy + $hh - $r, $r, $r, 90, 90)
$head.CloseFigure()
$g.DrawPath($outline, $head)
$g.FillPath((New-Object System.Drawing.SolidBrush $iron), $head)
$g.SetClip($head)
$g.FillRectangle((New-Object System.Drawing.SolidBrush $ironDark), $hx + 48, $hy, 40, $hh)
$g.ResetClip()
# Glowing striking faces (top and bottom ends of the head) and a band.
$glowBrush = New-Object System.Drawing.SolidBrush $glow
$g.FillRectangle($glowBrush, $hx + 8, $hy + 6, $hw - 16, 14)
$g.FillRectangle($glowBrush, $hx + 8, $hy + $hh - 20, $hw - 16, 14)
$g.DrawRectangle((New-Object System.Drawing.Pen $ink, 4), $hx + 8, $hy + 6, $hw - 16, 14)
$g.DrawRectangle((New-Object System.Drawing.Pen $ink, 4), $hx + 8, $hy + $hh - 20, $hw - 16, 14)
$g.FillRectangle((New-Object System.Drawing.SolidBrush $ink), $hx, $hy + 60, $hw, 14)

# White shine on the head.
$shine = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(220, 255, 255, 255))
$g.FillRectangle($shine, $hx + 14, $hy + 28, 12, 28)
$g.FillRectangle($shine, $hx + 14, $hy + 84, 12, 20)

$g.Dispose()
$bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
