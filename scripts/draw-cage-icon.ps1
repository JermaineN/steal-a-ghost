param([string]$OutPath)
# Draws the Cage item's hotbar icon (assets/cage-icon.png): an iron cage with an orange top ring.
Add-Type -AssemblyName System.Drawing

$size = 256
$bmp = New-Object System.Drawing.Bitmap $size, $size
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)

$outline = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 15, 15, 20)), 14
$outline.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$outline.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$iron = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 120, 125, 140)), 7
$iron.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$iron.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$orange = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 255, 140, 30)), 9

# Hanging ring on top.
$g.DrawEllipse($outline, 108, 18, 40, 34)
$g.DrawEllipse($orange, 108, 18, 40, 34)

# Vertical bars between the dome and the base.
$bars = 58, 87, 116, 140, 169, 198
foreach ($x in $bars) { $g.DrawLine($outline, $x, 78, $x, 214) }
foreach ($x in $bars) { $g.DrawLine($iron, $x, 78, $x, 214) }

# Domed top and flat base plates.
$plate = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 70, 72, 82))
$edge = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 15, 15, 20)), 5
$dome = New-Object System.Drawing.Drawing2D.GraphicsPath
$dome.AddArc(44, 46, 168, 64, 180, 180)
$dome.CloseFigure()
$g.FillPath($plate, $dome)
$g.DrawPath($edge, $dome)
$g.FillRectangle($plate, 40, 208, 176, 24)
$g.DrawRectangle($edge, 40, 208, 176, 24)

# Orange band across the dome, matching the ring.
$band = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 255, 140, 30)), 6
$g.DrawLine($band, 50, 76, 206, 76)

$g.Dispose()
$bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
