param([switch]$PublicOnly,[switch]$SimpleStyle)
if($SimpleStyle){$PublicOnly=$true}
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$out=Join-Path $PSScriptRoot 'Chapter 3 Diagrams'
$model=Get-Content -Raw -LiteralPath (Join-Path $out 'schema-visualizer.json')|ConvertFrom-Json
if($PublicOnly){$model.Tables=@($model.Tables|Where-Object Name -Like 'public.*');$model.Relations=@($model.Relations|Where-Object Child -Like 'public.*')}
$expectedTables=if($PublicOnly){13}else{16};$expectedLinks=if($PublicOnly){18}else{21};$stem=if($PublicOnly){'05-public-schema-erd'}else{'05-erd-one-page'}
if($SimpleStyle){$stem='05-public-schema-erd-simple'}
if($SimpleStyle){$model.Relations=@($model.Relations|Where-Object Parent -ne 'auth.users');$expectedLinks=9}
$tables=@{};foreach($table in $model.Tables){$tables[$table.Name]=$table}
$tables['auth.users']=[pscustomobject]@{Name='auth.users';Columns=@([pscustomobject]@{Name='id';Type='uuid';Required=$true;Keys=@('PK')})}
$width=3508;$height=2480;$cw=740;$hh=86;$rh=46
$cards=@{};$svg=[Collections.Generic.List[string]]::new();$primitives=[Collections.Generic.List[object]]::new()
$bmp=[Drawing.Bitmap]::new($width,$height);$bmp.SetResolution(300,300);$g=[Drawing.Graphics]::FromImage($bmp)
$g.Clear([Drawing.Color]::White);$g.SmoothingMode='AntiAlias';$g.TextRenderingHint='AntiAliasGridFit'
function E([string]$s){[Security.SecurityElement]::Escape($s)}
function Box($x,$y,$w,$h,$fill,$stroke='#cbd5e1'){
 $brush=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml($fill));$pen=[Drawing.Pen]::new([Drawing.ColorTranslator]::FromHtml($stroke),1.5)
 try{$g.FillRectangle($brush,[single]$x,[single]$y,[single]$w,[single]$h);$g.DrawRectangle($pen,[single]$x,[single]$y,[single]$w,[single]$h)}finally{$brush.Dispose();$pen.Dispose()}
 $svg.Add('<rect x="'+$x+'" y="'+$y+'" width="'+$w+'" height="'+$h+'" fill="'+$fill+'" stroke="'+$stroke+'"/>')
 $primitives.Add(@{Kind='rect';X=$x;Y=$y;W=$w;H=$h;Fill=$fill;Stroke=$stroke})
}
function Text($text,$x,$y,$size=30,$color='#172b46',$bold=$false){
 $style=if($bold){[Drawing.FontStyle]::Bold}else{[Drawing.FontStyle]::Regular};$font=[Drawing.Font]::new('Arial',[single]$size,$style,[Drawing.GraphicsUnit]::Pixel);$brush=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml($color))
 try{$g.DrawString($text,$font,$brush,[single]$x,[single]$y)}finally{$font.Dispose();$brush.Dispose()}
 $weight=if($bold){'700'}else{'400'};$svg.Add('<text x="'+$x+'" y="'+($y+$size)+'" font-family="Arial, sans-serif" font-size="'+$size+'" font-weight="'+$weight+'" fill="'+$color+'">'+(E $text)+'</text>')
 $primitives.Add(@{Kind='text';Text=$text;X=$x;Y=$y;Size=$size;Color=$color;Bold=$bold})
}
function Card($name,$x,$y,$fieldNames){
 $columns=@(foreach($field in $fieldNames){$column=@($tables[$name].Columns|Where-Object Name -EQ $field);if($column.Count -ne 1){throw "Missing/ambiguous field: $name.$field"};$column[0]})
 foreach($col in $tables[$name].Columns){if(('PK' -in $col.Keys -or 'FK' -in $col.Keys) -and $col.Name -notin $fieldNames){throw "Key field omitted from overview: $name.$($col.Name)"}}
 $cards[$name]=[pscustomobject]@{Name=$name;X=$x;Y=$y;Columns=$columns;H=($hh+$rh*$columns.Count)}
}
function RowY($card,$field){for($i=0;$i -lt $card.Columns.Count;$i++){if($card.Columns[$i].Name -eq $field){return $card.Y+$hh+$rh*$i+$rh/2}};throw "Missing endpoint $($card.Name).$field"}
function LinePath($points,$segments,$color,$tooltip){
 $pen=[Drawing.Pen]::new([Drawing.ColorTranslator]::FromHtml($color),3.2)
 try{foreach($s in $segments){$g.DrawLine($pen,[single]$s[0][0],[single]$s[0][1],[single]$s[1][0],[single]$s[1][1])}}finally{$pen.Dispose()}
 $d=(@($segments|ForEach-Object {'M '+($_[0]-join ' ')+' L '+($_[1]-join ' ')})-join ' ')
 $svg.Add('<path d="'+$d+'" fill="none" stroke="'+$color+'" stroke-width="3.2"><title>'+(E $tooltip)+'</title></path>')
 $primitives.Add(@{Kind='path';Points=$points;Segments=$segments;Color=$color})
 $portIndex=0
 foreach($point in @($points[0],$points[$points.Count-1])){
  if($SimpleStyle){continue}
  $radius=if($portIndex -eq 0){1.3}else{3.5};$portIndex++
  $brush=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml($color));try{$g.FillEllipse($brush,($point[0]-$radius),($point[1]-$radius),(2*$radius),(2*$radius))}finally{$brush.Dispose()}
  $svg.Add('<circle cx="'+$point[0]+'" cy="'+$point[1]+'" r="'+$radius+'" fill="'+$color+'"/>');$primitives.Add(@{Kind='dot';X=$point[0];Y=$point[1];Radius=$radius;Color=$color})
 }
}
function SymbolLine($a,$b){
 $pen=[Drawing.Pen]::new([Drawing.ColorTranslator]::FromHtml('#475569'),3.2)
 try{$g.DrawLine($pen,[single]$a[0],[single]$a[1],[single]$b[0],[single]$b[1])}finally{$pen.Dispose()}
 $svg.Add('<path d="M '+($a -join ' ')+' L '+($b -join ' ')+'" fill="none" stroke="#475569" stroke-width="3.2"/>')
 $primitives.Add(@{Kind='line';Points=@($a,$b);Color='#475569'})
}
function Cardinality($point,$toward,$many,$optional){
 $dx=[Math]::Sign($toward[0]-$point[0]);$dy=[Math]::Sign($toward[1]-$point[1]);$nx=-$dy;$ny=$dx
 if($many){
  foreach($side in @(-1,1)){SymbolLine @(($point[0]+$nx*9*$side),($point[1]+$ny*9*$side)) @(($point[0]+$dx*18),($point[1]+$dy*18))}
 }else{SymbolLine @(($point[0]+$dx*9+$nx*9),($point[1]+$dy*9+$ny*9)) @(($point[0]+$dx*9-$nx*9),($point[1]+$dy*9-$ny*9))}
 $cx=$point[0]+$dx*29;$cy=$point[1]+$dy*29
 if($optional){
  $pen=[Drawing.Pen]::new([Drawing.ColorTranslator]::FromHtml('#475569'),3.2)
  try{$g.FillEllipse([Drawing.Brushes]::White,[single]($cx-6),[single]($cy-6),12,12);$g.DrawEllipse($pen,[single]($cx-6),[single]($cy-6),12,12)}finally{$pen.Dispose()}
  $svg.Add('<circle cx="'+$cx+'" cy="'+$cy+'" r="6" fill="white" stroke="#475569" stroke-width="3.2"/>')
  $primitives.Add(@{Kind='circle';X=$cx;Y=$cy;Radius=6;Fill='#ffffff';Stroke='#475569';LineWidth=3.2})
 }else{SymbolLine @(($cx+$nx*9),($cy+$ny*9)) @(($cx-$nx*9),($cy-$ny*9))}
}
try {
 $svg.Add('<svg xmlns="http://www.w3.org/2000/svg" width="297mm" height="210mm" viewBox="0 0 3508 2480"><rect width="3508" height="2480" fill="white"/>')
 Text $(if($PublicOnly){'Figure 5. Public-Schema Entity Relationship Diagram'}else{'Figure 5. Physical database schema'}) 40 20 43 '#172b46' $true
 Text $(if($PublicOnly){'All 12 public tables and their declared foreign keys; selected attributes; auth.users shown as a reference.'}else{'One-page ERD overview: all application tables and declared foreign keys; selected attributes shown.'}) 40 80 29 '#52657b'
 # Each table appears once. Complete field declarations remain in the dictionary.
 Card 'auth.users' 40 200 @('id')
 Card 'public.profiles' 40 480 @('id','username','email','full_name','role','account_status')
 if(-not $PublicOnly){
  Card 'private.account_sessions' 40 1000 @('user_id','session_scope','session_id','session_created_at')
  Card 'private.admin_login_attempts' 40 1400 @('bucket','window_start','attempts')
  Card 'public.activity_logs' 40 1740 @('id','actor_id','actor_name','action','entity_type','occurred_at')
 }else{
  Card 'public.mobile_attendance_pairing_policy' 40 1100 @('singleton','updated_by','max_pairs')
  Card 'public.activity_logs' 40 1600 @('id','actor_id','actor_name','action','entity_type','occurred_at')
 }
 Card 'public.membership_applications' 910 200 @('id','auth_user_id','member_id','reviewed_by','application_type','status')
 Card 'public.members' 910 850 @('id','auth_user_id','application_id','full_name','plan','status','expiry_date')
 Card 'public.membership_history' 910 1600 @('id','member_id','recorded_by','event_type','new_expiry_date')
 Card 'public.attendance' 1780 200 @('id','member_id','recorded_by','checked_out_by','time_in','time_out')
 if(-not $PublicOnly){
  Card 'private.attendance_scan_requests' 1780 700 @('request_id','operator_id','member_id','created_at')
  Card 'public.mobile_attendance_pairing_policy' 1780 1100 @('singleton','updated_by','max_pairs')
  Card 'public.mobile_attendance_scan_sessions' 1780 1450 @('id','created_by','paired_device_id','expires_at')
  Card 'public.mobile_attendance_scan_events' 1780 1880 @('id','session_id','qr_payload','created_at')
 }else{
  Card 'public.mobile_attendance_scan_sessions' 1780 1000 @('id','created_by','paired_device_id','expires_at')
  Card 'public.mobile_attendance_scan_events' 1780 1600 @('id','session_id','qr_payload','created_at')
 }
 Card 'public.products' 2650 200 @('id','name','category','price','stock','is_active')
 Card 'public.sales' 2650 850 @('id','member_id','processed_by','receipt_number','total','sold_at')
 Card 'public.sale_items' 2650 1600 @('id','sale_id','product_id','item_name','quantity','line_total')
 if($cards.Count -ne $expectedTables -or $model.Relations.Count -ne $expectedLinks){throw 'Unexpected table/relationship coverage.'}
 foreach($table in $model.Tables){if(-not $cards.ContainsKey($table.Name)){throw 'An application table is missing from the figure.'}}
 # Check the page geometry before drawing.
 $allCards=@($cards.Values)
 for($i=0;$i -lt $allCards.Count;$i++){
  $a=$allCards[$i];if($a.X+$cw -gt $width-40 -or $a.Y+$a.H -gt 2220){throw "Table exceeds page area: $($a.Name)"}
  for($j=$i+1;$j -lt $allCards.Count;$j++){$b=$allCards[$j];if($a.X -lt $b.X+$cw -and $a.X+$cw -gt $b.X -and $a.Y -lt $b.Y+$b.H -and $a.Y+$a.H -gt $b.Y){throw 'Table cards overlap.'}}
 }
 $palette=@('#1d4ed8','#0f766e','#7c3aed','#a16207','#be185d','#475569','#0369a1')
 if($SimpleStyle){$palette=@('#475569')}
 $routes=[Collections.Generic.List[object]]::new();$parentUse=@{};$longTop=0;$longBottom=0
 foreach($r in $model.Relations){
  $i=$routes.Count;$p=$cards[$r.Parent];$c=$cards[$r.Child];$parentKey=$r.Parent+'.'+$r.ParentField
  $degree=@($model.Relations|Where-Object {$_.Parent -eq $r.Parent -and $_.ParentField -eq $r.ParentField}).Count
  if(-not $parentUse.ContainsKey($parentKey)){$parentUse[$parentKey]=0};$ordinal=$parentUse[$parentKey];$parentUse[$parentKey]++
  # Separate attachment points within the same key row avoid a shared source segment.
  $py=(RowY $p $r.ParentField)+(($ordinal+1)/($degree+1)-0.5)*36+($i+1)*0.013
  $cy=(RowY $c $r.Field)+($i+1)*0.023;$pc=[int](($p.X-40)/870);$cc=[int](($c.X-40)/870)
  $route=[pscustomobject]@{Relation=$r;Index=$i;PY=$py;CY=$cy;PX=0;CX=0;Gutters=@();Lanes=@{};Bus=0;Points=@();Segments=@()}
  if($pc -eq $cc){
   $route.PX=$p.X+$cw;$route.CX=$c.X+$cw;$route.Gutters=@($pc)
  }elseif([Math]::Abs($pc-$cc) -eq 1){
   if($pc -lt $cc){$route.PX=$p.X+$cw;$route.CX=$c.X}else{$route.PX=$p.X;$route.CX=$c.X+$cw}
   $route.Gutters=@([Math]::Min($pc,$cc))
  }else{
   $route.PX=$p.X+$cw;$route.CX=$c.X;$route.Gutters=@($pc,($cc-1))
   if($r.Parent -eq 'auth.users'){$route.Bus=125+($longTop*10);$longTop++}else{$route.Bus=2230+($longBottom*12);$longBottom++}
  }
  $routes.Add($route)
 }
 # Every edge gets its own vertical track in each routing gutter it uses.
 $laneSpacing=[Collections.Generic.List[double]]::new()
 foreach($gutter in 0..3){
  $using=@($routes|Where-Object {$gutter -in $_.Gutters}|Sort-Object CY,PY)
  $left=40+$gutter*870+$cw;$right=if($gutter -eq 3){$width-20}else{40+($gutter+1)*870};$spacing=($right-$left-20)/($using.Count+1)
  if($spacing -lt 6){throw 'Routing gutter is too narrow for distinct relationship tracks.'};$laneSpacing.Add($spacing)
  for($j=0;$j -lt $using.Count;$j++){$using[$j].Lanes[$gutter]=$left+10+($j+1)*$spacing}
 }
 # Fan out each key's ports in track order. Links travelling upward use the
 # upper half of the key row; downward links use the lower half.
 foreach($group in @($routes|Group-Object {$_.Relation.Parent+'.'+$_.Relation.ParentField+'|'+$_.PX})){
  $base=RowY $cards[$group.Group[0].Relation.Parent] $group.Group[0].Relation.ParentField
  $up=@($group.Group|Where-Object {$(if($_.Gutters.Count -gt 1){$_.Bus}else{$_.CY}) -lt $base}|Sort-Object { [Math]::Abs($_.Lanes[$_.Gutters[0]]-$_.PX) })
  $down=@($group.Group|Where-Object {$(if($_.Gutters.Count -gt 1){$_.Bus}else{$_.CY}) -ge $base}|Sort-Object { -[Math]::Abs($_.Lanes[$_.Gutters[0]]-$_.PX) })
  $ordered=@($up)+@($down)
  for($j=0;$j -lt $ordered.Count;$j++){$ordered[$j].PY=$base-22+($j+1)*44/($ordered.Count+1)+($ordered[$j].Index+1)*0.013}
 }
 $routingInput=[IO.Path]::GetTempFileName();$routingOutput=[IO.Path]::GetTempFileName()
 try{
  $records=@(foreach($route in $routes){
   [pscustomobject]@{Index=$route.Index;Group=($route.Relation.Parent+'.'+$route.Relation.ParentField+'|'+$route.PX);BaseY=(RowY $cards[$route.Relation.Parent] $route.Relation.ParentField);PX=$route.PX;CX=$route.CX;CY=$route.CY;Bus=$route.Bus;Gutters=@($route.Gutters);Lanes=@(foreach($gutter in $route.Gutters){[pscustomobject]@{Gutter=$gutter;X=$route.Lanes[$gutter]}})}
  })
  $records|ConvertTo-Json -Depth 12 -Compress|Set-Content -LiteralPath $routingInput -Encoding UTF8
  & node (Join-Path $PSScriptRoot 'optimize-erd-routing.mjs') $routingInput $routingOutput
  if($LASTEXITCODE -ne 0){throw 'Relationship routing optimization failed.'}
  $optimized=Get-Content -Raw -LiteralPath $routingOutput|ConvertFrom-Json
  foreach($route in $routes){$route.Points=@($optimized[$route.Index].Points)}
 }finally{Remove-Item -LiteralPath $routingInput,$routingOutput -Force}
 $allSegments=[Collections.Generic.List[object]]::new()
 foreach($route in $routes){
  for($j=0;$j -lt $route.Points.Count-1;$j++){
   $a=$route.Points[$j];$b=$route.Points[$j+1];$allSegments.Add([pscustomobject]@{Route=$route.Index;A=$a;B=$b;Horizontal=($a[1] -eq $b[1]);Cuts=[Collections.Generic.List[double]]::new()})
  }
 }
 # A visible gap at each crossing distinguishes the two relationships without
 # drawing them on top of one another. Horizontal links pass over vertical links.
 $crossings=0
 for($i=0;$i -lt $allSegments.Count;$i++){
  $a=$allSegments[$i]
  for($j=$i+1;$j -lt $allSegments.Count;$j++){
   $b=$allSegments[$j];if($a.Route -eq $b.Route){continue}
   if($a.Horizontal -eq $b.Horizontal){
    if($a.Horizontal){$same=[Math]::Abs($a.A[1]-$b.A[1]) -lt 0.001;$lo=[Math]::Max([Math]::Min($a.A[0],$a.B[0]),[Math]::Min($b.A[0],$b.B[0]));$hi=[Math]::Min([Math]::Max($a.A[0],$a.B[0]),[Math]::Max($b.A[0],$b.B[0]))}
    else{$same=[Math]::Abs($a.A[0]-$b.A[0]) -lt 0.001;$lo=[Math]::Max([Math]::Min($a.A[1],$a.B[1]),[Math]::Min($b.A[1],$b.B[1]));$hi=[Math]::Min([Math]::Max($a.A[1],$a.B[1]),[Math]::Max($b.A[1],$b.B[1]))}
    if($same -and $hi-$lo -gt 0.001){throw "Two relationship lines share a segment: routes $($a.Route)/$($b.Route), $($a.A -join ',') to $($a.B -join ','), $($b.A -join ',') to $($b.B -join ',')."}
   }else{
    if($a.Horizontal){$h=$a;$v=$b}else{$h=$b;$v=$a};$x=$v.A[0];$y=$h.A[1]
    if($x -gt [Math]::Min($h.A[0],$h.B[0]) -and $x -lt [Math]::Max($h.A[0],$h.B[0]) -and $y -gt [Math]::Min($v.A[1],$v.B[1]) -and $y -lt [Math]::Max($v.A[1],$v.B[1])){$v.Cuts.Add($y);$crossings++}
   }
  }
 }
 foreach($route in $routes){
  $visible=[Collections.Generic.List[object]]::new()
  foreach($s in @($allSegments|Where-Object Route -EQ $route.Index)){
   if($s.Horizontal){$visible.Add(@($s.A,$s.B));continue}
   $x=$s.A[0];$lo=[Math]::Min($s.A[1],$s.B[1]);$hi=[Math]::Max($s.A[1],$s.B[1]);$cursor=$lo
   foreach($cut in @($s.Cuts|Sort-Object -Unique)){
    $before=[Math]::Max($lo,$cut-6);$after=[Math]::Min($hi,$cut+6)
    if($before -gt $cursor){$visible.Add(@(@($x,$cursor),@($x,$before)))};$cursor=[Math]::Max($cursor,$after)
   }
   if($cursor -lt $hi){$visible.Add(@(@($x,$cursor),@($x,$hi)))}
  }
  $route.Segments=@($visible);$r=$route.Relation
  LinePath $route.Points $route.Segments $palette[$route.Index%$palette.Count] ($r.Parent+'.'+$r.ParentField+' -> '+$r.Child+'.'+$r.Field+'; ON DELETE '+$r.Delete)
  if($SimpleStyle){
   $fk=@($tables[$r.Child].Columns|Where-Object Name -eq $r.Field)[0]
   Cardinality $route.Points[0] $route.Points[1] $false (-not $fk.Required)
   Cardinality $route.Points[-1] $route.Points[-2] ('UQ' -notin $fk.Keys -and 'PK' -notin $fk.Keys) $true
  }
 }
 foreach($card in ($cards.Values|Sort-Object X,Y)){
  $x=$card.X;$y=$card.Y;$schema,$name=$card.Name -split '\.',2;$fill=if($schema -eq 'private'){'#ece8f7'}elseif($schema -eq 'auth'){'#e2e8f0'}else{'#dbeafe'}
  if($SimpleStyle){$fill='#078daf'}
  Box $x $y $cw $card.H '#ffffff';Box $x $y $cw $hh $fill
  Text $(if($schema -eq 'auth'){'auth | managed reference'}else{$schema}) ($x+15) ($y+6) 24 $(if($SimpleStyle){'#ffffff'}else{'#52657b'})
  Text $name ($x+15) ($y+38) $(if($PublicOnly){32}else{28}) $(if($SimpleStyle){'#ffffff'}else{'#172b46'}) $true
  for($i=0;$i -lt $card.Columns.Count;$i++){
   $col=$card.Columns[$i];$ry=$y+$hh+$rh*$i
   if($i%2 -eq 0){Box ($x+1) $ry ($cw-2) $rh '#f7f9fc' '#f7f9fc'}
   $keyText=(@('PK','FK','UQ')|Where-Object {$_ -in $col.Keys})-join '/'
   if($SimpleStyle -and 'FK' -in $col.Keys -and -not @($model.Relations|Where-Object {$_.Child -eq $card.Name -and $_.Field -eq $col.Name}).Count){$keyText=$keyText.Replace('FK','AUTH')}
   Text $keyText ($x+10) ($ry+11) 20 '#1d4ed8' $true
   Text $col.Name ($x+108) ($ry+6) $(if($PublicOnly){35}else{30})
   $typeText=$col.Type+$(if($col.Required){' *'}else{''});$typeSize=if($PublicOnly){25}else{23}
   $measureFont=[Drawing.Font]::new('Arial',$typeSize,[Drawing.FontStyle]::Regular,[Drawing.GraphicsUnit]::Pixel)
   while($g.MeasureString($typeText,$measureFont).Width -gt $cw-575){$measureFont.Dispose();$typeSize--;$measureFont=[Drawing.Font]::new('Arial',$typeSize,[Drawing.FontStyle]::Regular,[Drawing.GraphicsUnit]::Pixel)};$measureFont.Dispose()
   Text $typeText ($x+565) ($ry+10) $typeSize '#52657b'
  }
 }
 Text $(if($SimpleStyle){'PK = primary key   FK = foreign key   AUTH = FK to auth.users   UQ = unique   * = NOT NULL. Circle = zero; bar = one; fork = many.'}else{'PK = primary key   FK = foreign key   UQ = unique constraint/index   * = NOT NULL. Lines connect referenced keys to foreign-key columns.'}) 40 2300 28
 Text $(if($SimpleStyle){'12 public tables; 18 foreign keys: 9 drawn relationships and 9 AUTH references. All PK/FK fields are shown; other fields are selected.'}elseif($PublicOnly){'12 public tables + auth.users reference; 18 public foreign keys. All PK/FK columns are shown; other attributes are selected for readability.'}else{'15 application tables + auth.users reference; 21 declared foreign keys. All key columns are shown; other attributes are selected for readability.'}) 40 2345 28 '#52657b'
 Text $(if($PublicOnly){'All 162 public fields and the 3 private tables remain in the data dictionary. Gaps at crossings indicate separate links, not junctions.'}else{'Full 174-column definitions: see the data dictionary. Gaps at line crossings indicate separate relationships, not junctions.'}) 40 2390 28 '#52657b'
 Text 'Source: project pgAdmin schema export and checked migration baseline. Layout: A4 landscape, one page.' 40 2433 25 '#52657b'
 $svg.Add('</svg>')
 $bmp.Save((Join-Path $out ($stem+'.png')),[Drawing.Imaging.ImageFormat]::Png)
 [IO.File]::WriteAllLines((Join-Path $out ($stem+'.svg')),$svg,[Text.UTF8Encoding]::new($false))
 [pscustomobject]@{Width=$width;Height=$height;ExpectedTables=$expectedTables;ExpectedLinks=$expectedLinks;Primitives=@($primitives)}|ConvertTo-Json -Depth 15 -Compress|Set-Content -LiteralPath (Join-Path $out ($stem+'-drawing.json')) -Encoding UTF8
 & node (Join-Path $PSScriptRoot 'export-erd-one-page-pdf.mjs') $stem
 if($LASTEXITCODE -ne 0){throw 'One-page PDF export failed.'}
 "Rendered $expectedLinks relationships with unique routing tracks, no shared segments, and $crossings crossing gaps on one A4 landscape page."
}finally{$g.Dispose();$bmp.Dispose()}
