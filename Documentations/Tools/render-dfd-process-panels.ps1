$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$root=Split-Path $PSScriptRoot -Parent
$dir=Join-Path $root 'Chapter 3 Diagrams'
$data=Get-Content -Raw (Join-Path $dir '_Sources/dfd-process-panel-index.json')|ConvertFrom-Json
$W=2100;$actorX=48;$actorW=285;$processX=700;$processW=440;$storeX=1605;$storeW=445;$top=150
$navy=[Drawing.Color]::FromArgb(23,34,53);$muted=[Drawing.Color]::FromArgb(83,98,116);$lineColor=[Drawing.Color]::FromArgb(52,68,90);$border=[Drawing.Color]::FromArgb(64,81,106);$processFill=[Drawing.Color]::FromArgb(232,240,250);$white=[Drawing.Brushes]::White
function MakeFont([float]$size,[bool]$bold=$false){$style=if($bold){[Drawing.FontStyle]::Bold}else{[Drawing.FontStyle]::Regular};[Drawing.Font]::new('Arial',$size,$style,[Drawing.GraphicsUnit]::Point)}
function DrawText($g,[string]$value,[Drawing.Font]$font,[Drawing.Brush]$brush,[float]$x,[float]$y,[float]$w,[float]$h,[string]$align='center'){
 $sf=[Drawing.StringFormat]::new();$sf.Alignment=if($align -eq 'left'){[Drawing.StringAlignment]::Near}else{[Drawing.StringAlignment]::Center};$sf.LineAlignment=[Drawing.StringAlignment]::Center;$sf.Trimming=[Drawing.StringTrimming]::Word; $sf.FormatFlags=[Drawing.StringFormatFlags]::LineLimit
 $g.DrawString($value,$font,$brush,[Drawing.RectangleF]::new($x,$y,$w,$h),$sf);$sf.Dispose()
}
function DrawFlow($g,[float]$x1,[float]$x2,[float]$y,[string]$label,[Drawing.Font]$font,[Drawing.Pen]$pen,[Drawing.Brush]$textBrush,[float]$maxLabelW){
 $p=[Drawing.Pen]::new($pen.Color,2);$p.CustomEndCap=[Drawing.Drawing2D.AdjustableArrowCap]::new(7,8);$g.DrawLine($p,$x1,$y,$x2,$y);$p.Dispose()
 $w=[Math]::Min($maxLabelW,[Math]::Max(170,$g.MeasureString($label,$font).Width+22));$h=30.0;$x=($x1+$x2-$w)/2;$y0=$y-($h/2)
 $g.FillRectangle($white,$x,$y0,$w,$h);$g.DrawRectangle([Drawing.Pens]::White,$x,$y0,$w,$h);DrawText $g $label $font $textBrush ($x+3) $y0 ($w-6) $h 'center'
}
function ProcessLines([string]$value,[int]$limit){$words=$value -split '\s+';$lines=[Collections.Generic.List[string]]::new();$line='';foreach($word in $words){$next=if($line){"$line $word"}else{$word};if($next.Length -gt $limit -and $line){$lines.Add($line);$line=$word}else{$line=$next}};if($line){$lines.Add($line)};return ,$lines.ToArray()}
$titleFont=MakeFont 17 $true;$subFont=MakeFont 10;$actorFont=MakeFont 12 $true;$processFont=MakeFont 16 $true;$idFont=MakeFont 14 $true;$storeFont=MakeFont 10.5;$flowFont=MakeFont 9.5;$footFont=MakeFont 9
$brush=[Drawing.SolidBrush]::new($navy);$mutedBrush=[Drawing.SolidBrush]::new($muted);$flowBrush=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(38,54,74));$entityPen=[Drawing.Pen]::new($border,2.4);$processPen=[Drawing.Pen]::new([Drawing.Color]::FromArgb(36,74,120),2.8);$storePen=[Drawing.Pen]::new($border,2.4);$flowPen=[Drawing.Pen]::new($lineColor,2)
foreach($panel in $data){
 $actorCount=$panel.actors.Count;$storeCount=$panel.stores.Count
 $processHeight=[Math]::Max(330,[Math]::Max($storeCount*104+40,($actorCount-1)*145+150));$height=$top+$processHeight+85
 $bmp=[Drawing.Bitmap]::new($W,$height);$bmp.SetResolution(200,200);$g=[Drawing.Graphics]::FromImage($bmp);$g.PageUnit=[Drawing.GraphicsUnit]::Pixel;$g.Clear([Drawing.Color]::White);$g.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias;$g.TextRenderingHint=[Drawing.Text.TextRenderingHint]::AntiAliasGridFit
 DrawText $g "Process $($panel.processId) — $($panel.name)" $titleFont $brush 48 22 1980 52 'left'
 DrawText $g 'Gane–Sarson notation · arrows show the direction of each data flow' $subFont $mutedBrush 48 76 1980 35 'left'
 $processY=$top;$procRect=[Drawing.Rectangle]::new($processX,$processY,$processW,$processHeight);$g.FillRectangle([Drawing.SolidBrush]::new($processFill),$procRect);$g.DrawRectangle($processPen,$procRect);$g.DrawLine($processPen,$processX,$processY+58,$processX+$processW,$processY+58)
 DrawText $g $panel.processId $idFont $brush $processX ($processY+6) $processW 44
 $nameLines=ProcessLines $panel.name 26;$nameText=$nameLines -join "`n";DrawText $g $nameText $processFont $brush ($processX+30) ($processY+82) ($processW-60) ($processHeight-112)
 foreach($i in 0..($actorCount-1)){
  $center=$processY+$processHeight/2+($i-($actorCount-1)/2)*145;$y=$center-46;$rect=[Drawing.Rectangle]::new($actorX,[int]$y,$actorW,92);$g.FillRectangle($white,$rect);$g.DrawRectangle($entityPen,$rect)
  DrawText $g $panel.actors[$i][0] $actorFont $brush ($actorX+12) ($y+8) ($actorW-24) 76
  $inputLabel=$panel.actorLabels[$i][0];$outputLabel=$panel.actorLabels[$i][1]
  DrawFlow $g ($actorX+$actorW) $processX ($center-24) $inputLabel $flowFont $flowPen $flowBrush 340
  DrawFlow $g $processX ($actorX+$actorW) ($center+24) $outputLabel $flowFont $flowPen $flowBrush 340
 }
 for($i=0;$i -lt $storeCount;$i++){
  $store=$panel.stores[$i];$y=$processY+18+$i*104;$g.DrawLine($storePen,$storeX,$y,$storeX+$storeW,$y);$g.DrawLine($storePen,$storeX,$y,$storeX,$y+78);$g.DrawLine($storePen,$storeX,$y+78,$storeX+$storeW,$y+78);$g.DrawLine($storePen,$storeX+83,$y,$storeX+83,$y+78)
  DrawText $g $store[0] $idFont $brush $storeX ($y+8) 82 60
  DrawText $g $store[1] $storeFont $brush ($storeX+96) ($y+7) ($storeW-105) 64 'left'
  $labels=$panel.storeLabels.($store[0]);if(-not $labels){$labels=@('Updated records','Stored records')}
  if($store[2]){DrawFlow $g ($processX+$processW) $storeX ($y+26) $labels[0] $flowFont $flowPen $flowBrush 420}
  if($store[3]){DrawFlow $g $storeX ($processX+$processW) ($y+60) $labels[1] $flowFont $flowPen $flowBrush 420}
 }
 DrawText $g 'Repeated actor and store names across panels identify the same system roles and physical data stores.' $footFont $mutedBrush 48 ($height-52) 1980 28 'left'
 $file=Join-Path $dir ("_Sources/dfd-process-{0}.png" -f $panel.panel);$bmp.Save($file,[Drawing.Imaging.ImageFormat]::Png);$g.Dispose();$bmp.Dispose()
}
$titleFont.Dispose();$subFont.Dispose();$actorFont.Dispose();$processFont.Dispose();$idFont.Dispose();$storeFont.Dispose();$flowFont.Dispose();$footFont.Dispose();$brush.Dispose();$mutedBrush.Dispose();$flowBrush.Dispose();$entityPen.Dispose();$processPen.Dispose();$storePen.Dispose();$flowPen.Dispose()
"Rendered $($data.Count) separated process panels to 200-DPI PNGs."
