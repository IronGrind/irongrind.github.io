$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$out=Join-Path $PSScriptRoot 'Chapter 3 Diagrams'
$model=Get-Content -Raw -LiteralPath (Join-Path $out 'schema-visualizer.json')|ConvertFrom-Json
$names=@('membership_applications','members','attendance','membership_history','sales','sale_items','products')
$tables=@{};foreach($name in $names){$tables[$name]=$model.Tables|Where-Object Name -EQ ('public.'+$name)}
$relations=@($model.Relations|Where-Object {($_.Parent -replace '^public\.','') -in $names -and ($_.Child -replace '^public\.','') -in $names})
if($relations.Count -ne 7){throw 'Expected exactly seven enforced relationships among the seven core tables.'}
$width=1800;$height=2100;$cw=500;$hh=50;$rh=42
$cards=@{};$svg=[Collections.Generic.List[string]]::new();$shapes=[Collections.Generic.List[object]]::new()
$bmp=[Drawing.Bitmap]::new($width,$height);$bmp.SetResolution(300,300);$g=[Drawing.Graphics]::FromImage($bmp);$g.Clear([Drawing.Color]::White);$g.SmoothingMode='AntiAlias';$g.TextRenderingHint='AntiAliasGridFit'
function Esc([string]$s){[Security.SecurityElement]::Escape($s)}
function Rect($x,$y,$w,$h){
 $pen=[Drawing.Pen]::new([Drawing.Color]::Black,2);try{$g.FillRectangle([Drawing.Brushes]::White,$x,$y,$w,$h);$g.DrawRectangle($pen,$x,$y,$w,$h)}finally{$pen.Dispose()}
 $svg.Add('<rect x="'+$x+'" y="'+$y+'" width="'+$w+'" height="'+$h+'" fill="white" stroke="black" stroke-width="2"/>');$shapes.Add(@{Kind='rect';X=$x;Y=$y;W=$w;H=$h;Fill='#ffffff';Stroke='#000000';LineWidth=2})
}
function Text($text,$x,$y,$size=26,$bold=$false){
 $font=[Drawing.Font]::new('Arial',$size,$(if($bold){[Drawing.FontStyle]::Bold}else{[Drawing.FontStyle]::Regular}),[Drawing.GraphicsUnit]::Pixel)
 try{$g.DrawString($text,$font,[Drawing.Brushes]::Black,$x,$y)}finally{$font.Dispose()}
 $svg.Add('<text x="'+$x+'" y="'+($y+$size)+'" font-family="Arial, sans-serif" font-size="'+$size+'" font-weight="'+$(if($bold){'700'}else{'400'})+'">'+(Esc $text)+'</text>');$shapes.Add(@{Kind='text';Text=$text;X=$x;Y=$y;Size=$size;Color='#000000';Bold=$bold})
}
function Path($points,$relationship=$false){
 $pen=[Drawing.Pen]::new([Drawing.Color]::Black,2.2);$ps=[Drawing.PointF[]]@($points|ForEach-Object {[Drawing.PointF]::new($_[0],$_[1])});try{$g.DrawLines($pen,$ps)}finally{$pen.Dispose()}
 $d='M '+($points[0]-join ' ');for($i=1;$i -lt $points.Count;$i++){$d+=' L '+($points[$i]-join ' ')}
 $segments=[Collections.Generic.List[object]]::new();for($i=1;$i -lt $points.Count;$i++){$segments.Add(@($points[$i-1],$points[$i]))}
 $svg.Add('<path d="'+$d+'" fill="none" stroke="black" stroke-width="2.2"/>');$shapes.Add(@{Kind=$(if($relationship){'path'}else{'line'});Points=$points;Segments=@($segments);Color='#000000';LineWidth=2.2})
}
function Circle($x,$y,$r){
 $pen=[Drawing.Pen]::new([Drawing.Color]::Black,2.2);try{$g.FillEllipse([Drawing.Brushes]::White,($x-$r),($y-$r),(2*$r),(2*$r));$g.DrawEllipse($pen,($x-$r),($y-$r),(2*$r),(2*$r))}finally{$pen.Dispose()}
 $svg.Add('<circle cx="'+$x+'" cy="'+$y+'" r="'+$r+'" fill="white" stroke="black" stroke-width="2.2"/>');$shapes.Add(@{Kind='circle';X=$x;Y=$y;Radius=$r;Fill='#ffffff';Stroke='#000000';LineWidth=2.2})
}
function Card($name,$x,$y,$fields){
 $cols=@(foreach($field in $fields){$c=@($tables[$name].Columns|Where-Object Name -EQ $field);if($c.Count -ne 1){throw "Missing field $name.$field"};$c[0]})
 $cards[$name]=@{Name=$name;X=$x;Y=$y;Columns=$cols;H=($hh+$rh*$cols.Count)}
}
function Marker($point,$other,$minimum,$maximum){
 $dx=[Math]::Sign($other[0]-$point[0]);$dy=[Math]::Sign($other[1]-$point[1]);$nx=-$dy;$ny=$dx
 if($maximum -eq 'many'){
  foreach($offset in @(-9,0,9)){Path @(@(($point[0]+$dx*25),($point[1]+$dy*25)),@(($point[0]+$dx*7+$nx*$offset),($point[1]+$dy*7+$ny*$offset)))}
 }else{Path @(@(($point[0]+$dx*11+$nx*9),($point[1]+$dy*11+$ny*9)),@(($point[0]+$dx*11-$nx*9),($point[1]+$dy*11-$ny*9)))}
 if($minimum -eq 0){Circle ($point[0]+$dx*35) ($point[1]+$dy*35) 5}
 else{Path @(@(($point[0]+$dx*33+$nx*9),($point[1]+$dy*33+$ny*9)),@(($point[0]+$dx*33-$nx*9),($point[1]+$dy*33-$ny*9)))}
}
function Relation($child,$field,$points){
 $r=@($relations|Where-Object {$_.Child -eq ('public.'+$child) -and $_.Field -eq $field});if($r.Count -ne 1){throw 'Relationship differs from verified schema.'}
 $column=$tables[$child].Columns|Where-Object Name -EQ $field
 # Points are ordered referenced parent -> referencing child. Cardinality at the
 # parent end is parents per child; at the child end it is children per parent.
 Path $points $true
 Marker $points[0] $points[1] $(if($column.Required){1}else{0}) 'one'
 Marker $points[$points.Count-1] $points[$points.Count-2] 0 $(if('UQ' -in $column.Keys -or 'PK' -in $column.Keys){'one'}else{'many'})
}
try{
 $svg.Add('<svg xmlns="http://www.w3.org/2000/svg" width="1800" height="2100" viewBox="0 0 1800 2100"><rect width="100%" height="100%" fill="white"/>')
 Text 'Figure 5. Core Business Entity Relationship Diagram' 50 25 36 $true
 Text 'Selected attributes; all seven entities belong to the public schema.' 50 80 24
 Card 'membership_applications' 50 180 @('id','member_id','application_type','plan','status','submitted_at')
 Card 'members' 650 180 @('id','application_id','full_name','plan','status','start_date','expiry_date')
 Card 'attendance' 1250 180 @('id','member_id','date','time_in','time_out')
 Card 'membership_history' 1250 700 @('id','member_id','event_type','new_plan','new_expiry_date')
 Card 'sales' 650 1100 @('id','member_id','receipt_number','total','status','sold_at')
 Card 'products' 50 1510 @('id','name','category','price','stock','is_active')
 Card 'sale_items' 1250 1510 @('id','sale_id','product_id','item_name','quantity','unit_price','line_total')
 Relation 'members' 'application_id' @(@(550,275),@(650,275))
 Relation 'membership_applications' 'member_id' @(@(650,405),@(550,405))
 Relation 'attendance' 'member_id' @(@(1150,300),@(1250,300))
 Relation 'membership_history' 'member_id' @(@(1150,470),@(1200,470),@(1200,800),@(1250,800))
 Relation 'sales' 'member_id' @(@(900,524),@(900,1100))
 Relation 'sale_items' 'sale_id' @(@(900,1402),@(900,1580),@(1250,1580))
 Relation 'sale_items' 'product_id' @(@(550,1760),@(1250,1760))
 foreach($card in $cards.Values){
  $x=$card.X;$y=$card.Y;Rect $x $y $cw $card.H
  Path @(@($x,($y+$hh)),@(($x+$cw),($y+$hh)))
  Path @(@(($x+340),($y+$hh)),@(($x+340),($y+$card.H)))
  $font=[Drawing.Font]::new('Arial',26,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel);$measure=$g.MeasureString($card.Name,$font);$font.Dispose()
  Text $card.Name ($x+($cw-$measure.Width)/2) ($y+9) 26 $true
  for($i=0;$i -lt $card.Columns.Count;$i++){
   $col=$card.Columns[$i];$keys=@(@('PK','FK','UQ')|Where-Object {$_ -in $col.Keys})
   $label=$col.Name+$(if($keys.Count){' ('+($keys-join ',')+')'}else{''})
   $size=26;$font=[Drawing.Font]::new('Arial',$size,[Drawing.FontStyle]::Regular,[Drawing.GraphicsUnit]::Pixel)
   while($g.MeasureString($label,$font).Width -gt 320){$font.Dispose();$size--;$font=[Drawing.Font]::new('Arial',$size,[Drawing.FontStyle]::Regular,[Drawing.GraphicsUnit]::Pixel)};$font.Dispose()
   Text $label ($x+10) ($y+$hh+$i*$rh+8) $size
   $type=$col.Type -replace '^varchar\(\d+\)$','varchar' -replace '^numeric\([^)]*\)$','numeric'
   Text $type ($x+350) ($y+$hh+$i*$rh+10) 21
  }
 }
 Text 'A' 590 240 21 $true;Text 'B' 590 370 21 $true
 Text 'A: members.application_id references membership_applications.id (optional unique link).' 50 1900 23
 Text 'B: membership_applications.member_id references members.id (optional member; multiple requests).' 50 1940 23
 Text "Circles = optional; bars = one; crow's feet = many. PK = primary key; FK = foreign key; UQ = unique." 50 1980 23
 Text 'Core business relationships only. The data dictionary documents all 15 tables, 174 fields and 21 foreign keys.' 50 2020 22
 Text 'Source: verified project database schema. Field types are abbreviated; full limits and constraints appear in the dictionary.' 50 2060 21
 $svg.Add('</svg>');$stem='05-core-business-erd'
 $bmp.Save((Join-Path $out ($stem+'.png')),[Drawing.Imaging.ImageFormat]::Png)
 [IO.File]::WriteAllLines((Join-Path $out ($stem+'.svg')),$svg,[Text.UTF8Encoding]::new($false))
 [pscustomobject]@{Width=$width;Height=$height;TableWidth=$cw;ExpectedLinks=7;ExpectedTables=7;PageWidthMM=210;PageHeightMM=297;Primitives=@($shapes)}|ConvertTo-Json -Depth 14 -Compress|Set-Content (Join-Path $out ($stem+'-drawing.json')) -Encoding UTF8
 & node (Join-Path $PSScriptRoot 'export-erd-one-page-pdf.mjs') $stem
 if($LASTEXITCODE -ne 0){throw 'Core ERD PDF validation/export failed.'}
 'Generated seven-table Core Business ERD with seven schema-verified relationships and correct optionality/uniqueness markers.'
}finally{$g.Dispose();$bmp.Dispose()}
