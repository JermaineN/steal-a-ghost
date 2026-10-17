param([string]$OutPath)
# Draws the Universal Key item's icon (assets/key-icon.png): a gold skeleton key lying diagonally,
# with a ghost-shaped hole in its bow, in the same sticker style as the other item icons.
Add-Type -AssemblyName System.Drawing

$size = 256
$bmp = New-Object System.Drawing.Bitmap $size, $size
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)

$inkColor = [System.Drawing.Color]::FromArgb(255, 15, 15, 18)
$gold = [System.Drawing.Color]::FromArgb(255, 255, 190, 40)
$goldDark = [System.Drawing.Color]::FromArgb(255, 205, 135, 20)

# Draw everything along a diagonal: rotate the canvas -45 degrees around the centre.
$g.TranslateTransform(128, 128)
$g.RotateTransform(-45)
$g.TranslateTransform(-128, -128)

# The key's shape, as one path (bow ring + shaft + teeth), so the outline goes round it once.
$key = New-Object System.Drawing.Drawing2D.GraphicsPath
$key.FillMode = [System.Drawing.Drawing2D.FillMode]::Winding
$key.AddEllipse(20, 78, 100, 100)           # bow (the round end)
$key.AddRectangle((New-Object System.Drawing.Rectangle 110, 114, 120, 28))  # shaft
$key.AddRectangle((New-Object System.Drawing.Rectangle 196, 140, 18, 34))   # tooth 1
$key.AddRectangle((New-Object System.Drawing.Rectangle 170, 140, 16, 24))   # tooth 2
$region = New-Object System.Drawing.Region $key

$outline = New-Object System.Drawing.Pen $inkColor, 14
$outline.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$g.DrawPath($outline, $key)
$g.FillRegion((New-Object System.Drawing.SolidBrush $gold), $region)

# Darker underside of the shaft and teeth for depth.
$g.FillRectangle((New-Object System.Drawing.SolidBrush $goldDark), 110, 132, 120, 10)
$g.FillRectangle((New-Object System.Drawing.SolidBrush $goldDark), 196, 160, 18, 14)
$g.FillRectangle((New-Object System.Drawing.SolidBrush $goldDark), 170, 154, 16, 10)

# A little ghost-shaped hole in the bow (dark), so it's clearly this game's key.
$ghost = New-Object System.Drawing.Drawing2D.GraphicsPath
$ghost.AddArc(46, 100, 48, 48, 180, 180)
$ghost.AddLine(94, 124, 94, 156)
$ghost.AddLine(94, 156, 86, 148)
$ghost.AddLine(86, 148, 78, 156)
$ghost.AddLine(78, 156, 70, 148)
$ghost.AddLine(70, 148, 62, 156)
$ghost.AddLine(62, 156, 54, 148)
$ghost.AddLine(54, 148, 46, 156)
$ghost.CloseFigure()
$g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 40, 24, 60))), $ghost)
$g.DrawPath((New-Object System.Drawing.Pen $inkColor, 5), $ghost)
$eye = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 255, 255))
$g.FillEllipse($eye, 60, 118, 9, 11)
$g.FillEllipse($eye, 75, 118, 9, 11)

# White shine on the bow and shaft.
$shine = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(220, 255, 255, 255))
$g.FillEllipse($shine, 36, 88, 26, 14)
$g.FillRectangle($shine, 130, 118, 60, 6)

$g.Dispose()
$bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
