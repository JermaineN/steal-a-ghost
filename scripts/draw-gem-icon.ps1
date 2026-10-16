param([string]$OutPath)
# Draws the gem currency icon (assets/gem-icon.png): a faceted blue gem with a thick black border
# and a white shine, in the same sticker style as the menu icons. 256x256, transparent background.
Add-Type -AssemblyName System.Drawing

$bmp = New-Object System.Drawing.Bitmap 256, 256
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)

function P($x, $y) { return New-Object System.Drawing.PointF $x, $y }
function Brush($r, $gr, $b) { return New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, $r, $gr, $b)) }
function Facet($points, $brush) {
	$path = New-Object System.Drawing.Drawing2D.GraphicsPath
	$path.AddPolygon($points)
	$g.FillPath($brush, $path)
}

# Outline of the whole gem: flat top, slanted shoulders, pointed bottom.
$outline = @((P 78 40), (P 178 40), (P 228 96), (P 128 224), (P 28 96))
$ink = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 15, 10, 25)), 22
$ink.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$shape = New-Object System.Drawing.Drawing2D.GraphicsPath
$shape.AddPolygon($outline)
$g.DrawPath($ink, $shape)

# Facets in light-to-dark blues.
Facet @((P 78 40), (P 128 40), (P 104 96), (P 28 96)) (Brush 150 225 255)      # top left
Facet @((P 128 40), (P 178 40), (P 228 96), (P 152 96)) (Brush 90 190 255)     # top right
Facet @((P 128 40), (P 152 96), (P 104 96)) (Brush 195 240 255)                # top middle
Facet @((P 28 96), (P 104 96), (P 128 224)) (Brush 60 160 245)                 # bottom left
Facet @((P 104 96), (P 152 96), (P 128 224)) (Brush 90 190 255)                # bottom middle
Facet @((P 152 96), (P 228 96), (P 128 224)) (Brush 35 120 220)                # bottom right

# Facet lines, then the outer border again on top so the edges stay crisp.
$line = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 15, 10, 25)), 6
$line.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$g.DrawLine($line, 28, 96, 228, 96)
$g.DrawLine($line, 128, 40, 104, 96)
$g.DrawLine($line, 128, 40, 152, 96)
$g.DrawLine($line, 104, 96, 128, 224)
$g.DrawLine($line, 152, 96, 128, 224)
$border = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 15, 10, 25)), 12
$border.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$g.DrawPath($border, $shape)

# Shine.
$shine = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(220, 255, 255, 255)), 9
$shine.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$shine.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$g.DrawLine($shine, 70, 82, 88, 56)
$g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(230, 255, 255, 255))), 52, 108, 14, 14)

$g.Dispose()
$bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
