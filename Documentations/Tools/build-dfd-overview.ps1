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
    $pen = [Drawing.Pen]::new($line, 2); $brush = [Drawing.SolidBrush]::new($pale)
    try { $graphics.FillRectangle($brush, $x, $y, $w, $heightBox); $graphics.DrawLine($pen, $x, $y, $x + $w, $y); $graphics.DrawLine($pen, $x, $y + $heightBox, $x + $w, $y + $heightBox); $graphics.DrawLine($pen, $x, $y, $x, $y + $heightBox); $graphics.DrawLine($pen, $x + 72, $y, $x + 72, $y + $heightBox) } finally { $pen.Dispose(); $brush.Dispose() }
    Text $heading $small $ink ($x + 5) ($y + 12) 62 ($heightBox - 24) $center
    Text $detail $cardTitle $ink ($x + 88) ($y + 9) ($w - 100) 38
}
Text 'Figure 3. Simplified Data Flow Overview' $title $ink 55 24 1690 48
Text 'Read left to right: people send requests, the system performs its work, and information is read or saved.' $normal $muted 58 82 1680 34
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
    @{ x = 70; title = '1 · Access & accounts'; detail = 'Sign-in, roles, sessions and trusted-device checks'; },
    @{ x = 485; title = '2 · Membership'; detail = 'Applications, member records and renewals'; },
    @{ x = 900; title = '3 · Gym operations'; detail = 'Attendance, phone pairing, inventory and sales'; },
    @{ x = 1315; title = '4 · Oversight'; detail = 'Reports and recorded activity'; }
)
foreach ($group in $groups) {
    Rounded $group.x 535 390 245 ([Drawing.Color]::White) $line 14
    $graphics.FillRectangle([Drawing.SolidBrush]::new($accent), $group.x, 535, 390, 7)
    Text $group.title $cardTitle $accent ($group.x + 20) 563 350 58 $center
    Text $group.detail $normal $ink ($group.x + 28) 630 334 115 $center
}
Text 'The system reads and records the information needed by these functions.' $small $muted 75 790 1650 26 $center
Arrow 900 855 900 925 $true
Text 'READ / SAVE' $small $accent 815 875 170 26 $center
Text 'INFORMATION STORED (GROUPED FOR THIS OVERVIEW)' $sectionTitle $ink 55 940 1690 39 $center
$stores = @(
    @{ x = 58; id = 'D0, D1, D14–17'; title = 'Accounts & sessions'; detail = 'Identity · profiles · session security'; },
    @{ x = 402; id = 'D2, D3, D8'; title = 'Membership'; detail = 'Applications · members · history'; },
    @{ x = 746; id = 'D4, D10–13'; title = 'Attendance & pairing'; detail = 'Visits · phone pairing · scan requests'; },
    @{ x = 1090; id = 'D5–7'; title = 'Products & sales'; detail = 'Catalog · transactions · sale items'; },
    @{ x = 1434; id = 'D9'; title = 'Activity logs'; detail = 'Recorded system actions'; }
)
foreach ($store in $stores) {
    StoreBox $store.x 995 308 $store.id $store.title
    Text $store.detail $small $muted ($store.x + 88) 1037 210 62
}
Text 'Store groups are shown only to simplify the overview; the detailed DFD identifies each data store and its individual flows.' $small $muted 55 1140 1690 36 $center
$png = Join-Path $out '03-dfd-overview.png'
$bitmap.Save($png, [Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose(); $bitmap.Dispose()
'Created simplified overview PNG: ' + $png
