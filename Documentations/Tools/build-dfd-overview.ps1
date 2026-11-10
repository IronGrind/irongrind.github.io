$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path $PSScriptRoot -Parent
$out = Join-Path $root 'Chapter 3 Diagrams'
$width = 1800; $height = 1240
$bitmap = [Drawing.Bitmap]::new($width, $height)
$graphics = [Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$graphics.Clear([Drawing.Color]::White)
$ink = [Drawing.Color]::FromArgb(31, 41, 55)
$muted = [Drawing.Color]::FromArgb(83, 95, 112)
$accent = [Drawing.Color]::FromArgb(139, 0, 0)
$pale = [Drawing.Color]::FromArgb(247, 248, 250)
$line = [Drawing.Color]::FromArgb(177, 185, 197)
$normal = [Drawing.Font]::new('Arial', 18)
$small = [Drawing.Font]::new('Arial', 15)
$cardTitle = [Drawing.Font]::new('Arial', 21, [Drawing.FontStyle]::Bold)
$storeTitleFont = [Drawing.Font]::new('Arial', 15, [Drawing.FontStyle]::Bold)
$sectionTitle = [Drawing.Font]::new('Arial', 24, [Drawing.FontStyle]::Bold)
$title = [Drawing.Font]::new('Arial', 31, [Drawing.FontStyle]::Bold)
$center = [Drawing.StringFormat]::new(); $center.Alignment = [Drawing.StringAlignment]::Center; $center.LineAlignment = [Drawing.StringAlignment]::Center
$near = [Drawing.StringFormat]::new(); $near.Alignment = [Drawing.StringAlignment]::Near; $near.LineAlignment = [Drawing.StringAlignment]::Near
function Text($text, $font, $color, $x, $y, $w, $h, $format = $near) {
    $brush = [Drawing.SolidBrush]::new($color)
    try { $graphics.DrawString($text, $font, $brush, [Drawing.RectangleF]::new($x, $y, $w, $h), $format) } finally { $brush.Dispose() }
}
function Rounded($x, $y, $w, $h, $fill, $stroke, $radius = 18) {
    $path = [Drawing.Drawing2D.GraphicsPath]::new()
    $path.AddArc($x, $y, $radius, $radius, 180, 90); $path.AddArc($x + $w - $radius, $y, $radius, $radius, 270, 90)
    $path.AddArc($x + $w - $radius, $y + $h - $radius, $radius, $radius, 0, 90); $path.AddArc($x, $y + $h - $radius, $radius, $radius, 90, 90); $path.CloseFigure()
    $brush = [Drawing.SolidBrush]::new($fill); $pen = [Drawing.Pen]::new($stroke, 2)
    try { $graphics.FillPath($brush, $path); $graphics.DrawPath($pen, $path) } finally { $brush.Dispose(); $pen.Dispose(); $path.Dispose() }
}
function Arrow($x1, $y1, $x2, $y2, $both = $false) {
    $pen = [Drawing.Pen]::new($accent, 2.4); $pen.CustomEndCap = [Drawing.Drawing2D.AdjustableArrowCap]::new(6, 7)
    if ($both) { $pen.CustomStartCap = [Drawing.Drawing2D.AdjustableArrowCap]::new(6, 7) }
    try { $graphics.DrawLine($pen, $x1, $y1, $x2, $y2) } finally { $pen.Dispose() }
}
function StoreBox($x, $y, $w, $heading, $detail) {
    $heightBox = 118
    Rounded $x $y $w $heightBox $pale $line 12
    Text $heading $storeTitleFont $ink ($x + 10) ($y + 10) ($w - 20) 36 $center
    Text $detail $small $muted ($x + 15) ($y + 52) ($w - 30) 56 $center
}
Text 'Figure 3. Simplified Data Flow Overview' $title $ink 55 24 1690 48
Text 'Read top to bottom: people use the system, its functions do the work, and information is read or saved.' $normal $muted 58 82 1680 34
$actors = @(
    @{ x = 55; title = 'Member / Applicant'; detail = 'Sign in · apply or renew · view own account, attendance history and product catalog'; },
    @{ x = 640; title = 'Authorized Staff'; detail = 'Sign in · review permitted requests · scan attendance · register members · record sales'; },
    @{ x = 1225; title = 'Administrator'; detail = 'Sign in / approve devices · manage membership, inventory, reports and activity logs'; }
)
foreach ($actor in $actors) {
    Rounded $actor.x 145 520 188 ([Drawing.Color]::White) $line 12
    $graphics.FillRectangle([Drawing.SolidBrush]::new($accent), $actor.x, 145, 9, 188)
    Text $actor.title $cardTitle $ink ($actor.x + 28) 165 465 36
    Text $actor.detail $normal $muted ($actor.x + 28) 208 465 100
    $cx = $actor.x + 260
    Arrow ($cx - 10) 337 ($cx - 10) 407 $false
    Arrow ($cx + 10) 407 ($cx + 10) 337 $false
    Text 'requests ↓   results ↑' $small $muted ($actor.x + 125) 365 270 30 $center
}
Rounded 42 415 1716 435 ([Drawing.Color]::FromArgb(252, 252, 253)) $accent 22
Text 'IRON GRIND SYSTEM' $sectionTitle $ink 75 435 1650 42 $center
Text 'Nine functions, organized into four easy-to-follow areas' $small $muted 75 478 1650 28 $center
$groups = @(
    @{ x = 70; title = '1.0 Access and accounts'; detail = 'Sign-in, roles, sessions and trusted-device checks'; },
    @{ x = 485; title = '2.0-4.0 Membership'; detail = '2.0 Applications | 3.0 Member accounts | 4.0 Renewals'; },
    @{ x = 900; title = '5.0-7.0 Gym operations'; detail = '5.0 Attendance | 6.0 Inventory | 7.0 Product sales'; },
    @{ x = 1315; title = '8.0-9.0 Oversight'; detail = '8.0 Reports | 9.0 Activity logs'; }
)
foreach ($group in $groups) {
    Rounded $group.x 535 390 245 ([Drawing.Color]::White) $line 14
    $graphics.FillRectangle([Drawing.SolidBrush]::new($accent), $group.x, 535, 390, 7)
    Text $group.title $cardTitle $accent ($group.x + 20) 563 350 58 $center
    Text $group.detail $normal $ink ($group.x + 28) 630 334 115 $center
}
Text 'The system reads and records the information needed by these functions.' $small $muted 75 790 1650 26 $center
Arrow 900 855 900 925 $true
Text 'READ / SAVE' $small $accent 700 875 150 26 $center
Text 'INFORMATION STORED (GROUPED FOR THIS OVERVIEW)' $sectionTitle $ink 55 940 1690 39 $center
$stores = @(
    @{ x = 58; title = 'Accounts and sessions'; detail = 'Identity, profiles and trusted sessions'; },
    @{ x = 402; title = 'Membership'; detail = 'Applications, member records and renewals'; },
    @{ x = 746; title = 'Attendance and pairing'; detail = 'Visits, pairing settings and phone sessions'; },
    @{ x = 1090; title = 'Products and sales'; detail = 'Catalog, transactions and sale items'; },
    @{ x = 1434; title = 'Activity logs'; detail = 'Recorded system and security events'; }
)
foreach ($store in $stores) {
    StoreBox $store.x 995 308 $store.title $store.detail
}
Text 'Store groups are shown only to simplify the overview; the detailed DFD identifies each data store and its individual flows.' $small $muted 55 1140 1690 36 $center
$png = Join-Path $out '03-dfd-overview.png'
$bitmap.Save($png, [Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose(); $bitmap.Dispose()
'Created simplified overview PNG: ' + $png
