$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$root=Split-Path $PSScriptRoot -Parent;$dir=Join-Path $root 'Chapter 3 Diagrams';$panels=Get-Content -Raw (Join-Path $dir '_Sources/dfd-process-panel-index.json')|ConvertFrom-Json
$W=4200;$actorX=55;$actorW=490;$processX=1450;$processW=700;$storeX=3260;$storeW=880;$top=185;$actorStep=66;$storeStep=54;$rowGap=8
$rowHeights=@($panels|ForEach-Object {[Math]::Max(160,[Math]::Max($_.actors.Count*$actorStep+20,$_.stores.Count*$storeStep+18))});$H=$top+($rowHeights|Measure-Object -Sum).Sum+($panels.Count-1)*$rowGap+58
$bmp=[Drawing.Bitmap]::new($W,$H);$bmp.SetResolution(300,300);$g=[Drawing.Graphics]::FromImage($bmp);$g.PageUnit=[Drawing.GraphicsUnit]::Pixel;$g.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias;$g.TextRenderingHint=[Drawing.Text.TextRenderingHint]::AntiAliasGridFit;$g.Clear([Drawing.Color]::White)
$ink=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(23,34,53));$muted=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(83,98,116));$flowBrush=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(38,54,74));$pale=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(232,240,250));$white=[Drawing.Brushes]::White
$fontTitle=[Drawing.Font]::new('Arial',14,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Point);$fontSub=[Drawing.Font]::new('Arial',7.5,[Drawing.FontStyle]::Regular,[Drawing.GraphicsUnit]::Point);$fontActor=[Drawing.Font]::new('Arial',8,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Point);$fontProcess=[Drawing.Font]::new('Arial',10,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Point);$fontNumber=[Drawing.Font]::new('Arial',7.5,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Point);$fontStore=[Drawing.Font]::new('Arial',6.5,[Drawing.FontStyle]::Regular,[Drawing.GraphicsUnit]::Point);$fontStoreId=[Drawing.Font]::new('Arial',6.5,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Point);$fontFlow=[Drawing.Font]::new('Arial',5,[Drawing.FontStyle]::Regular,[Drawing.GraphicsUnit]::Point);$fontFoot=[Drawing.Font]::new('Arial',5.5,[Drawing.FontStyle]::Regular,[Drawing.GraphicsUnit]::Point)
$actorPen=[Drawing.Pen]::new([Drawing.Color]::FromArgb(64,81,106),2.1);$processPen=[Drawing.Pen]::new([Drawing.Color]::FromArgb(36,74,120),2.4);$storePen=[Drawing.Pen]::new([Drawing.Color]::FromArgb(64,81,106),2.1);$flowPen=[Drawing.Pen]::new([Drawing.Color]::FromArgb(52,68,90),1.8);$dividerPen=[Drawing.Pen]::new([Drawing.Color]::FromArgb(215,222,231),1.2)
function DrawText($g,[string]$value,[Drawing.Font]$font,[Drawing.Brush]$brush,[float]$x,[float]$y,[float]$w,[float]$h,[string]$align='center'){$sf=[Drawing.StringFormat]::new();$sf.Alignment=if($align -eq 'left'){[Drawing.StringAlignment]::Near}else{[Drawing.StringAlignment]::Center};$sf.LineAlignment=[Drawing.StringAlignment]::Center;$sf.Trimming=[Drawing.StringTrimming]::EllipsisWord;$g.DrawString($value,$font,$brush,[Drawing.RectangleF]::new($x,$y,$w,$h),$sf);$sf.Dispose()}
function Flow($g,[float]$x1,[float]$x2,[float]$y,[string]$label,[Drawing.Font]$font,[Drawing.Pen]$pen,[Drawing.Brush]$brush,[float]$maxW){$p=[Drawing.Pen]::new($pen.Color,$pen.Width);$p.CustomEndCap=[Drawing.Drawing2D.AdjustableArrowCap]::new(4.5,5.5);$g.DrawLine($p,$x1,$y,$x2,$y);$p.Dispose();$w=[Math]::Min($maxW,[Math]::Max(130,$g.MeasureString($label,$font).Width+18));$h=21.0;$x=($x1+$x2-$w)/2;$g.FillRectangle($white,$x,$y-($h/2),$w,$h);DrawText $g $label $font $brush ($x+2) ($y-($h/2)) ($w-4) $h}
DrawText $g 'Iron Grind Fitness Gym - Complete Level 1 Data Flow Diagram' $fontTitle $ink 55 28 ($W-110) 52 'left'
DrawText $g 'Gane-Sarson notation | nine processes in one page | arrows show each data-flow direction' $fontSub $muted 55 86 ($W-110) 30 'left'
$y=$top
for($pIndex=0;$pIndex -lt $panels.Count;$pIndex++){
 $panel=$panels[$pIndex];$rowH=$rowHeights[$pIndex];$processY=$y+5;$processH=$rowH-10
 if($pIndex -gt 0){$g.DrawLine($dividerPen,55,$y-4,$W-55,$y-4)}
 $processRect=[Drawing.Rectangle]::new($processX,$processY,$processW,$processH);$g.FillRectangle($pale,$processRect);$g.DrawRectangle($processPen,$processRect);$g.DrawLine($processPen,$processX,$processY+34,$processX+$processW,$processY+34)
 DrawText $g $panel.processId $fontNumber $ink $processX ($processY+2) $processW 30
 DrawText $g $panel.name $fontProcess $ink ($processX+18) ($processY+42) ($processW-36) ($processH-50)
 $actorGroup=$panel.actors.Count*$actorStep;$actorStart=$processY+($processH-$actorGroup)/2
 for($a=0;$a -lt $panel.actors.Count;$a++){
  $center=$actorStart+$a*$actorStep+$actorStep/2;$ay=$center-25;$actorRect=[Drawing.Rectangle]::new($actorX,[int]$ay,$actorW,50);$g.FillRectangle($white,$actorRect);$g.DrawRectangle($actorPen,$actorRect)
  DrawText $g $panel.actors[$a][0] $fontActor $ink ($actorX+10) ($ay+4) ($actorW-20) 42
  Flow $g ($actorX+$actorW) $processX ($center-15) $panel.actorLabels[$a][0] $fontFlow $flowPen $flowBrush 780
  Flow $g $processX ($actorX+$actorW) ($center+15) $panel.actorLabels[$a][1] $fontFlow $flowPen $flowBrush 780
 }
 $storeStart=$processY+($processH-($panel.stores.Count*$storeStep-6))/2
 for($s=0;$s -lt $panel.stores.Count;$s++){
  $store=$panel.stores[$s];$sy=$storeStart+$s*$storeStep;$boxH=46
  $g.DrawLine($storePen,$storeX,$sy,$storeX+$storeW,$sy);$g.DrawLine($storePen,$storeX,$sy,$storeX,$sy+$boxH);$g.DrawLine($storePen,$storeX,$sy+$boxH,$storeX+$storeW,$sy+$boxH);$g.DrawLine($storePen,$storeX+88,$sy,$storeX+88,$sy+$boxH)
  DrawText $g $store[0] $fontStoreId $ink $storeX ($sy+2) 86 ($boxH-4)
  $name=[string]$store[1];$name=$name.Replace('private.','private.')
  DrawText $g $name $fontStore $ink ($storeX+98) ($sy+2) ($storeW-108) ($boxH-4) 'left'
  $labels=$panel.storeLabels.($store[0]);if(-not $labels){$labels=@('Updated data','Stored data')}
  if($store[2]){Flow $g ($processX+$processW) $storeX ($sy+14) ('TO STORE: '+$labels[0]) $fontFlow $flowPen $flowBrush 1030}
  if($store[3]){Flow $g $storeX ($processX+$processW) ($sy+36) ('FROM STORE: '+$labels[1]) $fontFlow $flowPen $flowBrush 1030}
 }
 $y+=$rowH+$rowGap
}
DrawText $g 'Repeated entity and data-store boxes are references to the same roles and physical tables. D12 is reserved and has no active frontend dependency.' $fontFoot $muted 55 ($H-44) ($W-110) 26 'left'
$out=Join-Path $dir '_Sources/03-dfd-complete-one-page.png';$bmp.Save($out,[Drawing.Imaging.ImageFormat]::Png)
$g.Dispose();$bmp.Dispose();$ink.Dispose();$muted.Dispose();$flowBrush.Dispose();$pale.Dispose();$actorPen.Dispose();$processPen.Dispose();$storePen.Dispose();$flowPen.Dispose();$dividerPen.Dispose();$fontTitle.Dispose();$fontSub.Dispose();$fontActor.Dispose();$fontProcess.Dispose();$fontNumber.Dispose();$fontStore.Dispose();$fontStoreId.Dispose();$fontFlow.Dispose();$fontFoot.Dispose()
"Rendered one complete nine-process DFD page (${W}x${H}px); each connector stays within its process row."
