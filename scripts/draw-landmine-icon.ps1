param([string]$OutPath)
# Draws the Landmine item's hotbar icon (assets/landmine-icon.png): a squat disc mine with a red
# light on top.
Add-Type -AssemblyName System.Drawing

$size = 256
$bmp = New-Object System.Drawing.Bitmap $size, $size
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)

$ink = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 15, 15, 18)), 6
$ink.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$body = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 88, 94, 74))
$bodyDark = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 58, 62, 50))
$cap = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 120, 126, 104))

# Side of the disc (a band between two ellipses).
$side = New-Object System.Drawing.Drawing2D.GraphicsPath
$side.AddArc(28, 120, 200, 70, 180, -180)
$side.AddLine(228, 155, 228, 125)
$side.AddArc(28, 90, 200, 70, 0, 180)
$side.CloseFigure()
$g.FillPath($bodyDark, $side)
$g.DrawPath($ink, $side)

# Top face.
$g.FillEllipse($body, 28, 90, 200, 70)
$g.DrawEllipse($ink, 28, 90, 200, 70)

# Raised cap (pressure plate).
$g.FillEllipse($cap, 83, 103, 90, 34)
$g.DrawEllipse($ink, 83, 103, 90, 34)

# Bolts around the top.
$bolt = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 30, 32, 26))
foreach ($p in @(@(52, 118), @(196, 118), @(124, 146), @(124, 94))) { $g.FillEllipse($bolt, $p[0] - 5, $p[1] - 5, 10, 10) }

# Red light with a glow.
$glow = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(110, 255, 60, 40))
$g.FillEllipse($glow, 106, 82, 44, 44)
$red = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 50, 35))
$g.FillEllipse($red, 116, 92, 24, 24)
$g.DrawEllipse((New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 15, 15, 18)), 4), 116, 92, 24, 24)
$shine = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(220, 255, 220, 210))
$g.FillEllipse($shine, 121, 96, 8, 7)

$g.Dispose()
$bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
