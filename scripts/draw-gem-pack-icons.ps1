param([string]$OutDir)
# Draws the four Robux gem pack pictures (StoreConfig.GemPacks) in the same "sticker" style as the
# gem icon: a bigger pile of gems for a bigger pack. Two files per pack:
#   pack-<id>.png      256x256, transparent: the Currency card picture in the game
#   pack-<id>-hub.png  512x512 on a blue glow: the Developer Product icon on the Creator Hub
#                      (Roblox may crop it to a circle, so the drawing stays inside it)
Add-Type -AssemblyName System.Drawing

$INK = [System.Drawing.Color]::FromArgb(255, 15, 10, 25)

function P($x, $y) { return New-Object System.Drawing.PointF $x, $y }
function Brush($r, $gr, $b) { return New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, $r, $gr, $b)) }
function Pen($color, $width) {
	$p = New-Object System.Drawing.Pen $color, $width
	$p.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
	$p.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
	$p.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
	return $p
}

# One gem, the same shape as assets/gem-icon.png (drawn there in a 256 box), centred on (cx, cy)
# and scaled by $s (1 = the full-size icon).
function Gem($g, $cx, $cy, $s) {
	$state = $g.Save()
	$g.TranslateTransform($cx, $cy)
	$g.ScaleTransform($s, $s)
	$g.TranslateTransform(-128, -132)
	$shape = New-Object System.Drawing.Drawing2D.GraphicsPath
	$shape.AddPolygon(@((P 78 40), (P 178 40), (P 228 96), (P 128 224), (P 28 96)))
	$g.DrawPath((Pen $INK 22), $shape)
	$facets = @(
		@(@((P 78 40), (P 128 40), (P 104 96), (P 28 96)), (Brush 150 225 255)),
		@(@((P 128 40), (P 178 40), (P 228 96), (P 152 96)), (Brush 90 190 255)),
		@(@((P 128 40), (P 152 96), (P 104 96)), (Brush 195 240 255)),
		@(@((P 28 96), (P 104 96), (P 128 224)), (Brush 60 160 245)),
		@(@((P 104 96), (P 152 96), (P 128 224)), (Brush 90 190 255)),
		@(@((P 152 96), (P 228 96), (P 128 224)), (Brush 35 120 220))
	)
	foreach ($facet in $facets) {
		$path = New-Object System.Drawing.Drawing2D.GraphicsPath
		$path.AddPolygon($facet[0])
		$g.FillPath($facet[1], $path)
	}
	$line = Pen $INK 6
	$g.DrawLine($line, 28, 96, 228, 96)
	$g.DrawLine($line, 128, 40, 104, 96)
	$g.DrawLine($line, 128, 40, 152, 96)
	$g.DrawLine($line, 104, 96, 128, 224)
	$g.DrawLine($line, 152, 96, 128, 224)
	$g.DrawPath((Pen $INK 12), $shape)
	$g.DrawLine((Pen ([System.Drawing.Color]::FromArgb(220, 255, 255, 255)) 9), 70, 82, 88, 56)
	$g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(230, 255, 255, 255))), 52, 108, 14, 14)
	$g.Restore($state)
}

# A four-pointed white twinkle.
function Sparkle($g, $cx, $cy, $r) {
	$path = New-Object System.Drawing.Drawing2D.GraphicsPath
	$k = $r * 0.28
	$path.AddPolygon(@((P $cx ($cy - $r)), (P ($cx + $k) ($cy - $k)), (P ($cx + $r) $cy), (P ($cx + $k) ($cy + $k)),
		(P $cx ($cy + $r)), (P ($cx - $k) ($cy + $k)), (P ($cx - $r) $cy), (P ($cx - $k) ($cy - $k))))
	$g.DrawPath((Pen $INK 6), $path)
	$g.FillPath((Brush 255 255 255), $path)
}

# Each pack: gems listed back to front as (x, y, scale), plus sparkles (x, y, radius).
$packs = [ordered]@{
	gems_500 = @{
		gems = ,@(128, 128, 0.9)
		sparkles = ,@(214, 52, 18)
	}
	gems_1200 = @{
		gems = @(@(84, 112, 0.6), @(154, 136, 0.7))
		sparkles = @(@(220, 48, 18), @(36, 206, 12))
	}
	gems_3000 = @{
		gems = @(@(80, 104, 0.52), @(176, 104, 0.52), @(128, 150, 0.62))
		sparkles = @(@(128, 34, 18), @(226, 196, 14), @(30, 196, 12))
	}
	gems_8000 = @{
		gems = @(@(60, 116, 0.42), @(196, 116, 0.42), @(128, 92, 0.48), @(86, 168, 0.5), @(170, 168, 0.5))
		sparkles = @(@(42, 46, 16), @(218, 42, 18), @(232, 220, 12), @(24, 222, 10))
	}
}

function DrawPack($g, $pack) {
	foreach ($gem in $pack.gems) { Gem $g $gem[0] $gem[1] $gem[2] }
	foreach ($s in $pack.sparkles) { Sparkle $g $s[0] $s[1] $s[2] }
}

foreach ($id in $packs.Keys) {
	$pack = $packs[$id]

	# Shop card picture: transparent, 256x256.
	$bmp = New-Object System.Drawing.Bitmap 256, 256
	$g = [System.Drawing.Graphics]::FromImage($bmp)
	$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
	$g.Clear([System.Drawing.Color]::Transparent)
	DrawPack $g $pack
	$g.Dispose()
	$bmp.Save((Join-Path $OutDir "pack-$id.png"), [System.Drawing.Imaging.ImageFormat]::Png)
	$bmp.Dispose()

	# Creator Hub icon: 512x512, a blue glow (the gem colour), drawing in the middle.
	$bmp = New-Object System.Drawing.Bitmap 512, 512
	$g = [System.Drawing.Graphics]::FromImage($bmp)
	$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
	$dark = [System.Drawing.Color]::FromArgb(255, 18, 40, 80)
	$g.Clear($dark)
	$glow = New-Object System.Drawing.Drawing2D.GraphicsPath
	$glow.AddEllipse(-40, -40, 592, 592)
	$brush = New-Object System.Drawing.Drawing2D.PathGradientBrush $glow
	$brush.CenterColor = [System.Drawing.Color]::FromArgb(255, 70, 160, 255)
	$brush.SurroundColors = @($dark)
	$g.FillRectangle($brush, 0, 0, 512, 512)
	$g.TranslateTransform(64, 64)
	$g.ScaleTransform(1.5, 1.5)
	DrawPack $g $pack
	$g.Dispose()
	$bmp.Save((Join-Path $OutDir "pack-$id-hub.png"), [System.Drawing.Imaging.ImageFormat]::Png)
	$bmp.Dispose()
}
