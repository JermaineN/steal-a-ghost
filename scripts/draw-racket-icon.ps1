param([string]$OutPath)
# Draws the Tennis Racket item's icon (assets/racket-icon.png): an orange racket lying diagonally
# with white strings, a dark grip and a tennis ball, in the same sticker style as the other item
# icons.
Add-Type -AssemblyName System.Drawing

$size = 256
$bmp = New-Object System.Drawing.Bitmap $size, $size
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)

$ink = [System.Drawing.Color]::FromArgb(255, 15, 15, 18)
$frame = [System.Drawing.Color]::FromArgb(255, 255, 140, 30)
$grip = [System.Drawing.Color]::FromArgb(255, 55, 35, 70)
$ball = [System.Drawing.Color]::FromArgb(255, 205, 245, 60)

# The racket on a diagonal: head top-right, grip bottom-left.
$g.TranslateTransform(128, 128)
$g.RotateTransform(-45)
$g.TranslateTransform(-128, -128)

$outline = New-Object System.Drawing.Pen $ink, 14
$outline.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

# Shaft and grip.
$g.DrawRectangle($outline, 116, 150, 24, 92)
$g.FillRectangle((New-Object System.Drawing.SolidBrush $frame), 116, 150, 24, 30)
$g.FillRectangle((New-Object System.Drawing.SolidBrush $grip), 116, 180, 24, 62)
$tape = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 120, 90, 140)), 3
foreach ($y in 192, 206, 220, 234) { $g.DrawLine($tape, 116, $y, 140, $y - 8) }

# The head: an oval frame with a string grid inside.
$g.DrawEllipse($outline, 72, 14, 112, 140)
$g.SetClip((New-Object System.Drawing.RectangleF 84, 26, 88, 116))
$inner = New-Object System.Drawing.Drawing2D.GraphicsPath
$inner.AddEllipse(84, 26, 88, 116)
$g.SetClip($inner)
$g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 40, 24, 60))), $inner)
$string = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 245, 245, 250)), 3
for ($x = 92; $x -le 168; $x += 12) { $g.DrawLine($string, $x, 20, $x, 150) }
for ($y = 34; $y -le 140; $y += 12) { $g.DrawLine($string, 80, $y, 180, $y) }
$g.ResetClip()
$ring = New-Object System.Drawing.Pen $frame, 12
$g.DrawEllipse($ring, 78, 20, 100, 128)
$g.DrawEllipse((New-Object System.Drawing.Pen $ink, 3), 84, 26, 88, 116)

# White shine on the frame.
$shine = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(220, 255, 255, 255)), 4
$g.DrawArc($shine, 80, 22, 96, 124, 200, 50)

$g.ResetTransform()
# A tennis ball in the bottom left corner.
$g.FillEllipse((New-Object System.Drawing.SolidBrush $ball), 22, 176, 58, 58)
$g.DrawEllipse((New-Object System.Drawing.Pen $ink, 7), 22, 176, 58, 58)
$seam = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), 4
$g.DrawArc($seam, 6, 186, 40, 40, -60, 120)
$g.DrawArc($seam, 56, 184, 40, 40, 120, 120)

$g.Dispose()
$bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
