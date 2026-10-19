param([string]$OutDir)
# Draws the eight Robux game pass pictures in the same "sticker" style as the other icons (thick
# dark outlines, flat Halloween colours, white shine). Two files per pass:
#   pass-<id>.png      256x256, transparent: the Shop card picture in the game
#   pass-<id>-hub.png  512x512 on a coloured background: the pass icon on the Creator Hub
#                      (Roblox shows pass icons cropped to a circle, so the drawing stays inside it)
Add-Type -AssemblyName System.Drawing

$INK = [System.Drawing.Color]::FromArgb(255, 20, 10, 30)
$SHINE = [System.Drawing.Color]::FromArgb(150, 255, 255, 255)
$GHOST = [System.Drawing.Color]::FromArgb(255, 240, 240, 255)

function P($x, $y) { return New-Object System.Drawing.PointF $x, $y }
function Pen($color, $width) {
	$p = New-Object System.Drawing.Pen $color, $width
	$p.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
	$p.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
	$p.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
	return $p
}
function Rgb($r, $gr, $b) { return [System.Drawing.Color]::FromArgb(255, $r, $gr, $b) }
function Brush($r, $gr, $b) { return New-Object System.Drawing.SolidBrush (Rgb $r $gr $b) }
function RoundRect($x, $y, $w, $h, $r) {
	$p = New-Object System.Drawing.Drawing2D.GraphicsPath
	$p.AddArc($x, $y, $r * 2, $r * 2, 180, 90)
	$p.AddArc($x + $w - $r * 2, $y, $r * 2, $r * 2, 270, 90)
	$p.AddArc($x + $w - $r * 2, $y + $h - $r * 2, $r * 2, $r * 2, 0, 90)
	$p.AddArc($x, $y + $h - $r * 2, $r * 2, $r * 2, 90, 90)
	$p.CloseFigure()
	return $p
}
function Ellipse($x, $y, $w, $h) {
	$p = New-Object System.Drawing.Drawing2D.GraphicsPath
	$p.AddEllipse($x, $y, $w, $h)
	return $p
}
function Polygon($points) {
	$p = New-Object System.Drawing.Drawing2D.GraphicsPath
	$p.AddPolygon($points)
	return $p
}
# Fill a shape and outline it.
function Sticker($g, $path, $brush, $width = 12) {
	$g.DrawPath((Pen $INK $width), $path)
	$g.FillPath($brush, $path)
}
# Big outlined words (Arial Black).
function Words($g, $text, $size, $x, $y, $brush) {
	$path = New-Object System.Drawing.Drawing2D.GraphicsPath
	$font = New-Object System.Drawing.FontFamily "Arial Black"
	$path.AddString($text, $font, 0, $size, (P $x $y), [System.Drawing.StringFormat]::GenericDefault)
	$g.DrawPath((Pen $INK ([Math]::Max(8, $size / 7))), $path)
	$g.FillPath($brush, $path)
}
# A little ghost: round head, straight sides, wavy bottom, two eyes. (cx, cy) is its centre.
function Ghost($g, $cx, $cy, $size) {
	$w = $size; $h = $size * 1.15
	$x = $cx - $w / 2; $y = $cy - $h / 2
	$p = New-Object System.Drawing.Drawing2D.GraphicsPath
	$p.AddArc($x, $y, $w, $w, 180, 180)
	$p.AddLine($x + $w, $y + $w / 2, $x + $w, $y + $h)
	$wave = $w / 3
	$p.AddBezier($x + $w, $y + $h, $x + $w - $wave * 0.5, $y + $h - $wave * 0.6, $x + $w - $wave * 0.5, $y + $h - $wave * 0.6, $x + $w - $wave, $y + $h)
	$p.AddBezier($x + $w - $wave, $y + $h, $x + $w - $wave * 1.5, $y + $h - $wave * 0.6, $x + $w - $wave * 1.5, $y + $h - $wave * 0.6, $x + $wave, $y + $h)
	$p.AddBezier($x + $wave, $y + $h, $x + $wave * 0.5, $y + $h - $wave * 0.6, $x + $wave * 0.5, $y + $h - $wave * 0.6, $x, $y + $h)
	$p.CloseFigure()
	$g.DrawPath((Pen $INK ([Math]::Max(6, $size / 9))), $p)
	$g.FillPath((New-Object System.Drawing.SolidBrush $GHOST), $p)
	$eye = $size / 7
	$inkBrush = New-Object System.Drawing.SolidBrush $INK
	$g.FillEllipse($inkBrush, $cx - $size * 0.2 - $eye / 2, $cy - $size * 0.12, $eye, $eye * 1.4)
	$g.FillEllipse($inkBrush, $cx + $size * 0.2 - $eye / 2, $cy - $size * 0.12, $eye, $eye * 1.4)
	$g.DrawArc((Pen $SHINE ([Math]::Max(4, $size / 14))), $x + $w * 0.14, $y + $w * 0.12, $w * 0.5, $w * 0.5, 190, 60)
}
# A four-pointed sparkle centred on (cx, cy).
function Sparkle($g, $cx, $cy, $r, $brush) {
	$pts = @()
	for ($i = 0; $i -lt 8; $i++) {
		$a = ($i * 45 - 90) * [Math]::PI / 180
		$len = if ($i % 2 -eq 0) { $r } else { $r * 0.3 }
		$pts += P ($cx + [Math]::Cos($a) * $len) ($cy + [Math]::Sin($a) * $len)
	}
	Sticker $g (Polygon $pts) $brush ([Math]::Max(6, $r / 5))
}
# A gold coin with a $ on it.
function Coin($g, $cx, $cy, $r) {
	Sticker $g (Ellipse ($cx - $r) ($cy - $r) ($r * 2) ($r * 2)) (Brush 255 205 50) ([Math]::Max(6, $r / 3))
	$g.DrawEllipse((Pen (Rgb 225 160 30) ([Math]::Max(3, $r / 8))), $cx - $r * 0.7, $cy - $r * 0.7, $r * 1.4, $r * 1.4)
	$path = New-Object System.Drawing.Drawing2D.GraphicsPath
	$font = New-Object System.Drawing.FontFamily "Arial Black"
	$fmt = New-Object System.Drawing.StringFormat
	$fmt.Alignment = [System.Drawing.StringAlignment]::Center
	$fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
	$path.AddString('$', $font, 0, $r * 1.3, (P $cx ($cy + $r * 0.06)), $fmt)
	$g.FillPath((Brush 200 130 20), $path)
}

# Each pass: background colour for the Creator Hub version, and how to draw it (256x256 space).
$passes = [ordered]@{
	# 2x Money: a stack of green bills and a big yellow "2x".
	"double_money" = @{ bg = (Rgb 70 200 90); draw = {
		param($g)
		$state = $g.Save()
		$g.TranslateTransform(128, 110); $g.RotateTransform(-14); $g.TranslateTransform(-128, -110)
		Sticker $g (RoundRect 22 56 200 108 14) (Brush 60 160 75)
		$g.Restore($state)
		Sticker $g (RoundRect 30 74 200 108 14) (Brush 95 205 100)
		$g.DrawPath((Pen (Rgb 50 140 65) 5), (RoundRect 44 88 172 80 8))
		Sticker $g (Ellipse 98 96 64 64) (Brush 150 230 140) 6
		$dollar = New-Object System.Drawing.Drawing2D.GraphicsPath
		$fmt = New-Object System.Drawing.StringFormat
		$fmt.Alignment = [System.Drawing.StringAlignment]::Center
		$fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
		$dollar.AddString('$', (New-Object System.Drawing.FontFamily "Arial Black"), 0, 48, (P 130 130), $fmt)
		$g.FillPath((Brush 40 120 55), $dollar)
		$g.DrawLine((Pen $SHINE 8), 48, 92, 84, 92)
		Words $g "2x" 100 92 128 (Brush 255 215 50)
	} }
	# VIP: a gold crown with gems and "VIP" on the band.
	"vip" = @{ bg = (Rgb 255 190 40); draw = {
		param($g)
		$crown = Polygon @((P 36 196), (P 30 92), (P 82 140), (P 128 58), (P 174 140), (P 226 92), (P 220 196))
		Sticker $g $crown (Brush 255 205 50) 14
		foreach ($tip in @(@(30, 84), @(128, 50), @(226, 84))) {
			Sticker $g (Ellipse ($tip[0] - 16) ($tip[1] - 16) 32 32) (Brush 255 225 110) 10
		}
		Sticker $g (RoundRect 26 168 204 50 12) (Brush 230 155 30)
		Sticker $g (Ellipse 112 104 32 40) (Brush 230 50 70) 8
		Sticker $g (Ellipse 62 136 22 26) (Brush 90 170 255) 7
		Sticker $g (Ellipse 172 136 22 26) (Brush 90 170 255) 7
		$g.DrawLine((Pen $SHINE 8), 52, 110, 56, 150)
		$fmt = New-Object System.Drawing.StringFormat
		$fmt.Alignment = [System.Drawing.StringAlignment]::Center
		$fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
		$text = New-Object System.Drawing.Drawing2D.GraphicsPath
		$text.AddString("VIP", (New-Object System.Drawing.FontFamily "Arial Black"), 0, 40, (P 128 195), $fmt)
		$g.DrawPath((Pen $INK 7), $text)
		$g.FillPath((Brush 175 95 255), $text)
	} }
	# Extra Hotbar Slot: two hotbar slots, the new one with a big green plus.
	"extra_slot" = @{ bg = (Rgb 255 140 30); draw = {
		param($g)
		Sticker $g (RoundRect 16 76 104 104 18) (Brush 70 55 90)
		Ghost $g 68 128 50
		Sticker $g (RoundRect 104 52 140 140 22) (Brush 85 60 110) 14
		$g.DrawPath((Pen (Rgb 255 150 40) 8), (RoundRect 114 62 120 120 16))
		$plus = New-Object System.Drawing.Drawing2D.GraphicsPath
		$plus.AddPolygon(@((P 160 76), (P 188 76), (P 188 108), (P 220 108), (P 220 136), (P 188 136), (P 188 168), (P 160 168), (P 160 136), (P 128 136), (P 128 108), (P 160 108)))
		Sticker $g $plus (Brush 90 220 100) 12
		$g.DrawLine((Pen $SHINE 6), 166, 84, 166, 100)
	} }
	# Fast Flight: a ghost zooming along with speed streaks behind it.
	"fast_flight" = @{ bg = (Rgb 80 160 255); draw = {
		param($g)
		foreach ($line in @(@(84, 18, 92), @(128, 8, 82), @(172, 26, 88))) {
			$g.DrawLine((Pen $INK 26), $line[1], $line[0], $line[2], $line[0])
			$g.DrawLine((Pen (Rgb 150 210 255) 14), $line[1], $line[0], $line[2], $line[0])
		}
		$state = $g.Save()
		$g.TranslateTransform(156, 128); $g.RotateTransform(-20); $g.TranslateTransform(-156, -128)
		Ghost $g 156 124 120
		$g.Restore($state)
	} }
	# Auto Collect: a red horseshoe magnet pulling up coins.
	"auto_collect" = @{ bg = (Rgb 230 70 90); draw = {
		param($g)
		$shape = New-Object System.Drawing.Drawing2D.GraphicsPath
		$shape.AddLine(66, 150, 66, 96)
		$shape.AddArc(66, 34, 124, 124, 180, 180)
		$shape.AddLine(190, 96, 190, 150)
		$flat = { param($color, $w) $p = Pen $color $w; $p.StartCap = 0; $p.EndCap = 0; $p }
		$g.DrawPath((& $flat $INK 62), $shape)
		$g.DrawPath((& $flat (Rgb 230 60 70) 46), $shape)
		$g.FillRectangle((New-Object System.Drawing.SolidBrush $INK), 29, 120, 74, 42)
		$g.FillRectangle((New-Object System.Drawing.SolidBrush $INK), 153, 120, 74, 42)
		$g.FillRectangle((Brush 215 220 235), 43, 128, 46, 26)
		$g.FillRectangle((Brush 215 220 235), 167, 128, 46, 26)
		$g.DrawArc((Pen $SHINE 8), 54, 22, 100, 100, 200, 50)
		foreach ($y in @(186, 214)) {
			$g.DrawLine((Pen $INK 12), 70, $y + 12, 84, $y)
			$g.DrawLine((Pen $INK 12), 186, $y + 12, 172, $y)
			$g.DrawLine((Pen (Rgb 255 230 120) 6), 70, $y + 12, 84, $y)
			$g.DrawLine((Pen (Rgb 255 230 120) 6), 186, $y + 12, 172, $y)
		}
		Coin $g 128 208 36
	} }
	# NIGHTMARE title: a horned skull with glowing red eyes.
	"title_nightmare" = @{ bg = (Rgb 170 20 35); draw = {
		param($g)
		$left = New-Object System.Drawing.Drawing2D.GraphicsPath
		$left.AddBezier(80, 72, 48, 56, 32, 30, 40, 6)
		$left.AddBezier(40, 6, 70, 30, 96, 42, 108, 58)
		$left.CloseFigure()
		$right = New-Object System.Drawing.Drawing2D.GraphicsPath
		$right.AddBezier(176, 72, 208, 56, 224, 30, 216, 6)
		$right.AddBezier(216, 6, 186, 30, 160, 42, 148, 58)
		$right.CloseFigure()
		Sticker $g $left (Brush 200 25 40)
		Sticker $g $right (Brush 200 25 40)
		$bone = Brush 240 230 210
		Sticker $g (RoundRect 86 150 84 72 18) $bone
		Sticker $g (Ellipse 56 40 144 136) $bone
		$g.FillPath($bone, (RoundRect 92 150 72 40 12))
		$inkBrush = New-Object System.Drawing.SolidBrush $INK
		$g.FillEllipse($inkBrush, 78, 92, 42, 40)
		$g.FillEllipse($inkBrush, 136, 92, 42, 40)
		$g.FillEllipse((Brush 255 40 40), 92, 104, 16, 16)
		$g.FillEllipse((Brush 255 40 40), 150, 104, 16, 16)
		$g.FillEllipse((Brush 255 200 200), 96, 107, 6, 6)
		$g.FillEllipse((Brush 255 200 200), 154, 107, 6, 6)
		$g.FillPath($inkBrush, (Polygon @((P 128 138), (P 118 158), (P 138 158))))
		foreach ($x in @(106, 128, 150)) { $g.DrawLine((Pen $INK 6), $x, 182, $x, 212) }
		$g.DrawLine((Pen $INK 6), 94, 196, 162, 196)
		$g.DrawArc((Pen $SHINE 9), 72, 54, 80, 70, 190, 60)
	} }
	# Golden Sparkles aura: a big gold sparkle with smaller ones around it.
	"aura_golden" = @{ bg = (Rgb 240 175 30); draw = {
		param($g)
		Sparkle $g 118 134 92 (Brush 255 210 50)
		Sparkle $g 200 60 38 (Brush 255 235 130)
		Sparkle $g 44 52 28 (Brush 255 235 130)
		Sparkle $g 206 196 30 (Brush 255 200 40)
		$g.FillPolygon((New-Object System.Drawing.SolidBrush $SHINE), @((P 118 62), (P 126 124), (P 112 112)))
		foreach ($dot in @(@(60, 210), @(222, 128), @(160, 28))) {
			Sticker $g (Ellipse ($dot[0] - 9) ($dot[1] - 9) 18 18) (Brush 255 240 160) 6
		}
	} }
	# Ghost Buddy pet: a small happy ghost with a pink collar and heart tag.
	"pet_ghost" = @{ bg = (Rgb 255 110 170); draw = {
		param($g)
		Ghost $g 124 130 150
		$g.FillEllipse((Brush 255 170 200), 66, 132, 22, 14)
		$g.FillEllipse((Brush 255 170 200), 160, 132, 22, 14)
		$g.DrawArc((Pen $INK 6), 110, 130, 28, 20, 20, 140)
		Sticker $g (RoundRect 46 158 156 20 8) (Brush 255 100 160) 8
		$heart = New-Object System.Drawing.Drawing2D.GraphicsPath
		$heart.AddBezier(124, 186, 104, 168, 106, 196, 124, 212)
		$heart.AddBezier(124, 212, 142, 196, 144, 168, 124, 186)
		$heart.CloseFigure()
		Sticker $g $heart (Brush 255 215 60) 7
		$float = New-Object System.Drawing.Drawing2D.GraphicsPath
		$float.AddBezier(212, 50, 190, 26, 182, 62, 212, 82)
		$float.AddBezier(212, 82, 242, 62, 234, 26, 212, 50)
		$float.CloseFigure()
		Sticker $g $float (Brush 255 90 150) 8
	} }
}

foreach ($id in $passes.Keys) {
	$pass = $passes[$id]

	# Shop card picture: transparent, 256x256.
	$bmp = New-Object System.Drawing.Bitmap 256, 256
	$g = [System.Drawing.Graphics]::FromImage($bmp)
	$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
	$g.Clear([System.Drawing.Color]::Transparent)
	& $pass.draw $g
	$g.Dispose()
	$bmp.Save((Join-Path $OutDir "pass-$id.png"), [System.Drawing.Imaging.ImageFormat]::Png)
	$bmp.Dispose()

	# Creator Hub icon: 512x512, a glowing background in the pass's colour, drawing in the middle.
	$bmp = New-Object System.Drawing.Bitmap 512, 512
	$g = [System.Drawing.Graphics]::FromImage($bmp)
	$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
	$c = $pass.bg
	$g.Clear([System.Drawing.Color]::FromArgb(255, [int]($c.R * 0.3), [int]($c.G * 0.3), [int]($c.B * 0.3)))
	$glow = New-Object System.Drawing.Drawing2D.GraphicsPath
	$glow.AddEllipse(-40, -40, 592, 592)
	$brush = New-Object System.Drawing.Drawing2D.PathGradientBrush $glow
	$brush.CenterColor = $c
	$brush.SurroundColors = @([System.Drawing.Color]::FromArgb(255, [int]($c.R * 0.3), [int]($c.G * 0.3), [int]($c.B * 0.3)))
	$g.FillRectangle($brush, 0, 0, 512, 512)
	$g.TranslateTransform(64, 64)
	$g.ScaleTransform(1.5, 1.5)
	& $pass.draw $g
	$g.Dispose()
	$bmp.Save((Join-Path $OutDir "pass-$id-hub.png"), [System.Drawing.Imaging.ImageFormat]::Png)
	$bmp.Dispose()
}
