param([string]$OutPath)
# Draws the PolterPuller 4000's icon (assets/polterpuller-icon.png): a purple ghost-catching
# tank with a glowing green window (a little ghost inside), a hose curling out of it to a
# wide nozzle, in the same sticker style as the other item icons. An original design for this
# game (a Halloween ghost vacuum), not a copy of any other game's device.
Add-Type -AssemblyName System.Drawing

$size = 256
$bmp = New-Object System.Drawing.Bitmap $size, $size
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)

$inkColor = [System.Drawing.Color]::FromArgb(255, 15, 15, 18)
$ink = New-Object System.Drawing.Pen $inkColor, 7
$ink.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

# Hose: a thick dark curve from the tank to the nozzle, with ribs.
$hosePoints = [System.Drawing.PointF[]]@(
    (New-Object System.Drawing.PointF 120, 190),
    (New-Object System.Drawing.PointF 160, 215),
    (New-Object System.Drawing.PointF 200, 190),
    (New-Object System.Drawing.PointF 205, 140)
)
$hoseOutline = New-Object System.Drawing.Pen $inkColor, 30
$hoseOutline.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$hoseOutline.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$g.DrawCurve($hoseOutline, $hosePoints)
$hose = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 70, 60, 85)), 18
$hose.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$hose.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$hose.DashPattern = [single[]]@(1.2, 0.35)
$g.DrawCurve($hose, $hosePoints)

# Nozzle: a wide cone opening upward-right, purple with a green glowing mouth.
$nozzle = New-Object System.Drawing.Drawing2D.GraphicsPath
$nozzle.AddPolygon([System.Drawing.PointF[]]@(
    (New-Object System.Drawing.PointF 190, 150),
    (New-Object System.Drawing.PointF 220, 150),
    (New-Object System.Drawing.PointF 244, 82),
    (New-Object System.Drawing.PointF 166, 82)
))
$g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 150, 90, 230))), $nozzle)
$g.DrawPath($ink, $nozzle)
$g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 120, 255, 130))), 166, 70, 78, 24)
$g.DrawEllipse($ink, 166, 70, 78, 24)

# Tank: a rounded purple capsule.
$tank = New-Object System.Drawing.Drawing2D.GraphicsPath
$tank.AddArc(30, 40, 100, 60, 180, 180)
$tank.AddLine(130, 70, 130, 190)
$tank.AddArc(30, 160, 100, 60, 0, 180)
$tank.CloseFigure()
$g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 110, 60, 200))), $tank)
$g.DrawPath($ink, $tank)
# Metal bands.
$band = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 200, 200, 215))
foreach ($y in @(84, 176)) {
    $g.FillRectangle($band, 32, $y, 96, 12)
    $g.DrawRectangle((New-Object System.Drawing.Pen $inkColor, 4), 32, $y, 96, 12)
}
# Glowing green window with a little ghost inside.
$window = New-Object System.Drawing.Rectangle 48, 102, 64, 68
$g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 120, 255, 130))), $window)
$g.DrawEllipse((New-Object System.Drawing.Pen $inkColor, 5), $window)
$ghost = New-Object System.Drawing.Drawing2D.GraphicsPath
$ghost.AddArc(64, 114, 32, 32, 180, 180)
$ghost.AddLine(96, 130, 96, 156)
$ghost.AddLine(96, 156, 90, 150)
$ghost.AddLine(90, 150, 84, 156)
$ghost.AddLine(84, 156, 78, 150)
$ghost.AddLine(78, 150, 72, 156)
$ghost.AddLine(72, 156, 64, 150)
$ghost.CloseFigure()
$g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 255, 255))), $ghost)
$g.DrawPath((New-Object System.Drawing.Pen $inkColor, 3), $ghost)
$g.FillEllipse((New-Object System.Drawing.SolidBrush $inkColor), 72, 126, 6, 8)
$g.FillEllipse((New-Object System.Drawing.SolidBrush $inkColor), 83, 126, 6, 8)

# White shine on the tank.
$shine = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(210, 255, 255, 255))
$g.FillEllipse($shine, 42, 52, 30, 14)
$g.FillRectangle($shine, 38, 108, 6, 50)

$g.Dispose()
$bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
