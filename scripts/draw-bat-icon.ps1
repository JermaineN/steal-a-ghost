param([string]$OutPath)
Add-Type -AssemblyName System.Drawing

$size = 256
$bmp = New-Object System.Drawing.Bitmap $size, $size
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)

# Draw the bat lying along the x axis, centred, then rotate it to a diagonal.
$g.TranslateTransform(128, 128)
$g.RotateTransform(-45)

$outline = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 25, 15, 10)), 8
$outline.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

# Barrel: a tapered shape from the grip to a rounded end.
$barrel = New-Object System.Drawing.Drawing2D.GraphicsPath
$barrel.AddLine(-30, -9, 70, -21)
$barrel.AddArc(58, -21, 42, 42, -90, 180)
$barrel.AddLine(70, 21, -30, 9)
$barrel.CloseFigure()

# Grip (handle) and the round knob at its end.
$grip = New-Object System.Drawing.RectangleF -100, -8, 74, 16
$knob = New-Object System.Drawing.RectangleF -114, -14, 18, 28

$g.DrawPath($outline, $barrel)
$g.DrawRectangle($outline, $grip.X, $grip.Y, $grip.Width, $grip.Height)
$g.DrawEllipse($outline, $knob)

$wood = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 170, 115, 70))
$g.FillPath($wood, $barrel)
$tape = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 70, 48, 36))
$g.FillRectangle($tape, $grip)
$g.FillEllipse($tape, $knob)

# Tape wraps on the grip.
$wrap = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 40, 26, 20)), 3
foreach ($x in -90, -76, -62, -48) { $g.DrawLine($wrap, $x, -8, ($x + 6), 8) }

# Shine along the top of the barrel.
$shine = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(150, 255, 225, 180)), 5
$shine.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$shine.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$g.DrawLine($shine, -18, -4, 72, -13)

$g.Dispose()
$bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
