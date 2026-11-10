$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path $PSScriptRoot -Parent
$out = Join-Path $root 'Chapter 3 Diagrams'
$bmp = [Drawing.Bitmap]::new(2200, 760)
$g = [Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear([Drawing.Color]::White)
$ink = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(24, 37, 54))
$actorFill = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(216, 228, 245))
$line = [Drawing.Pen]::new([Drawing.Color]::FromArgb(83, 103, 127), 3)
$arrow = [Drawing.Pen]::new([Drawing.Color]::FromArgb(83, 103, 127), 3)
$arrow.CustomEndCap = [Drawing.Drawing2D.AdjustableArrowCap]::new(7, 8)
$regular = [Drawing.Font]::new('Arial', 14)
$small = [Drawing.Font]::new('Arial', 14)
$bold = [Drawing.Font]::new('Arial', 24, [Drawing.FontStyle]::Bold)
$systemFont = [Drawing.Font]::new('Arial', 25, [Drawing.FontStyle]::Bold)
$numFont = [Drawing.Font]::new('Arial', 22)
$fmt = [Drawing.StringFormat]::new()
$fmt.Alignment = [Drawing.StringAlignment]::Center
$fmt.LineAlignment = [Drawing.StringAlignment]::Center
function Draw-Actor([int]$x,[int]$y,[int]$w,[int]$h,[string]$label) {
  $g.FillRectangle($actorFill,$x,$y,$w,$h); $g.DrawRectangle($line,$x,$y,$w,$h)
  $g.DrawString($label,$bold,$ink,[Drawing.RectangleF]::new($x+10,$y+10,$w-20,$h-20),$fmt)
}
function Draw-Arrow([int]$x1,[int]$y1,[int]$x2,[int]$y2) { $g.DrawLine($arrow,$x1,$y1,$x2,$y2) }
function Draw-Label([string]$text,[single]$x,[single]$y,[single]$w,[single]$h,[Drawing.Font]$font=$regular) {
  $g.FillRectangle([Drawing.Brushes]::White,$x,$y,$w,$h)
  $g.DrawString($text,$font,$ink,[Drawing.RectangleF]::new($x+5,$y+3,$w-10,$h-6))
}

# Same reference composition: member at left, system in the center, admin and staff at right.
Draw-Actor 35 300 270 150 "Member /`nApplicant"
Draw-Actor 1880 55 280 145 'Administrator'
Draw-Actor 1880 530 280 145 'Authorized Staff'
$systemPath = [Drawing.Drawing2D.GraphicsPath]::new()
$systemPath.AddArc(850,230,36,36,180,90); $systemPath.AddArc(1314,230,36,36,270,90)
$systemPath.AddArc(1314,444,36,36,0,90); $systemPath.AddArc(850,444,36,36,90,90); $systemPath.CloseFigure()
$g.FillPath([Drawing.Brushes]::White,$systemPath)
$headerPath = [Drawing.Drawing2D.GraphicsPath]::new()
$headerPath.AddArc(850,230,36,36,180,90); $headerPath.AddArc(1314,230,36,36,270,90)
$headerPath.AddLine(1350,248,1350,282); $headerPath.AddLine(1350,282,850,282); $headerPath.AddLine(850,282,850,248); $headerPath.CloseFigure()
$g.FillPath($actorFill,$headerPath)
$g.DrawPath($line,$systemPath)
$g.DrawLine($line,850,282,1350,282)
$g.DrawString('0',$numFont,$ink,[Drawing.RectangleF]::new(850,232,500,45),$fmt)
$g.DrawString('IronGrind Membership and'+"`n"+'Operations Management System',$systemFont,$ink,[Drawing.RectangleF]::new(875,310,450,100),$fmt)

# Member / applicant request and result flows.
Draw-Arrow 305 335 850 335
Draw-Arrow 850 410 305 410

# Administrator responsibilities and system results.
Draw-Arrow 1880 165 1350 295
Draw-Arrow 1350 355 1880 190

# Authorized staff responsibilities and system results.
Draw-Arrow 1880 565 1350 405
Draw-Arrow 1350 445 1880 610

# Place labels after every connector so later arrows cannot cut through their text.
Draw-Label "Credentials, registration details, renewal`nrequests, and permitted profile changes" 355 250 455 62
Draw-Label "Sign-in / application status; own membership,`nQR, visits, and product catalog" 355 420 455 62
Draw-Label "Review online applications / renewals; manage`nmemberships, inventory, staff, and devices" 1410 205 455 62
Draw-Label "Operation results, member / staff status,`nreports, and activity logs" 1455 345 410 62
Draw-Label "Credentials; counter work; online request`ndecisions; QR scans and product sales" 1415 455 455 62
Draw-Label "Access and task results; permitted attendance`nand own product-sale records" 1415 615 455 62

Draw-Label 'Walk-in customers transact through an operator. Payment is recorded at the gym; no online payment gateway or customer receipt is represented.' 35 715 2130 32 $small
$png = Join-Path $out '02-context.png'
$bmp.Save($png,[Drawing.Imaging.ImageFormat]::Png)
$fmt.Dispose(); $small.Dispose(); $regular.Dispose(); $bold.Dispose(); $systemFont.Dispose(); $numFont.Dispose(); $headerPath.Dispose(); $systemPath.Dispose()
$arrow.Dispose(); $line.Dispose(); $actorFill.Dispose(); $ink.Dispose(); $g.Dispose(); $bmp.Dispose()
Write-Output "Rendered $png"
