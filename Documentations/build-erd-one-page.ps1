$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$out=Join-Path $PSScriptRoot 'Chapter 3 Diagrams'
$model=Get-Content -Raw -LiteralPath (Join-Path $out 'schema-visualizer.json')|ConvertFrom-Json
$tables=@{};foreach($table in $model.Tables){$tables[$table.Name]=$table}
$tables['auth.users']=[pscustomobject]@{Name='auth.users';Columns=@([pscustomobject]@{Name='id';Type='uuid';Required=$true;Keys=@('PK')})}
$width=3508;$height=2480;$cw=780;$hh=86;$rh=46
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
function LinePath($points,$color,$tooltip){
 $ps=[Drawing.PointF[]]@($points|ForEach-Object {[Drawing.PointF]::new($_[0],$_[1])});$pen=[Drawing.Pen]::new([Drawing.ColorTranslator]::FromHtml($color),3)
 try{$g.DrawLines($pen,$ps)}finally{$pen.Dispose()}
 $d='M '+($points[0] -join ' ');for($k=1;$k -lt $points.Count;$k++){$d+=' L '+($points[$k] -join ' ')}
 $svg.Add('<path d="'+$d+'" fill="none" stroke="'+$color+'" stroke-width="3"><title>'+(E $tooltip)+'</title></path>')
 $primitives.Add(@{Kind='path';Points=$points;Color=$color})
 foreach($point in @($points[0],$points[$points.Count-1])){
  $brush=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml($color));try{$g.FillEllipse($brush,($point[0]-4),($point[1]-4),8,8)}finally{$brush.Dispose()}
  $svg.Add('<circle cx="'+$point[0]+'" cy="'+$point[1]+'" r="4" fill="'+$color+'"/>');$primitives.Add(@{Kind='dot';X=$point[0];Y=$point[1];Color=$color})
 }
}
try {
 $svg.Add('<svg xmlns="http://www.w3.org/2000/svg" width="297mm" height="210mm" viewBox="0 0 3508 2480"><rect width="3508" height="2480" fill="white"/>')
 Text 'Figure 5. Physical database schema' 40 20 43 '#172b46' $true
 Text 'One-page ERD overview: all application tables and declared foreign keys; selected attributes shown.' 40 80 29 '#52657b'
 # Each table appears once. Complete field declarations remain in the dictionary.
 Card 'auth.users' 40 200 @('id')
 Card 'public.profiles' 40 480 @('id','username','email','full_name','role','account_status')
 Card 'private.account_sessions' 40 1000 @('user_id','session_scope','session_id','session_created_at')
 Card 'private.admin_login_attempts' 40 1400 @('bucket','window_start','attempts')
 Card 'public.activity_logs' 40 1740 @('id','actor_id','actor_name','action','entity_type','occurred_at')
 Card 'public.membership_applications' 910 200 @('id','auth_user_id','member_id','reviewed_by','application_type','status')
 Card 'public.members' 910 850 @('id','auth_user_id','application_id','full_name','plan','status','expiry_date')
 Card 'public.membership_history' 910 1600 @('id','member_id','recorded_by','event_type','new_expiry_date')
 Card 'public.attendance' 1780 200 @('id','member_id','recorded_by','checked_out_by','time_in','time_out')
 Card 'private.attendance_scan_requests' 1780 700 @('request_id','operator_id','member_id','created_at')
 Card 'public.mobile_attendance_pairing_policy' 1780 1100 @('singleton','updated_by','max_pairs')
 Card 'public.mobile_attendance_scan_sessions' 1780 1450 @('id','created_by','paired_device_id','expires_at')
 Card 'public.mobile_attendance_scan_events' 1780 1880 @('id','session_id','qr_payload','created_at')
 Card 'public.products' 2650 200 @('id','name','category','price','stock','is_active')
 Card 'public.sales' 2650 850 @('id','member_id','processed_by','receipt_number','total','sold_at')
 Card 'public.sale_items' 2650 1600 @('id','sale_id','product_id','item_name','quantity','line_total')
 if($cards.Count -ne 16 -or $model.Relations.Count -ne 21){throw 'Unexpected table/relationship coverage.'}
 # Check the page geometry before drawing.
 $allCards=@($cards.Values)
 for($i=0;$i -lt $allCards.Count;$i++){
  $a=$allCards[$i];if($a.X+$cw -gt $width-40 -or $a.Y+$a.H -gt 2220){throw "Table exceeds page area: $($a.Name)"}
  for($j=$i+1;$j -lt $allCards.Count;$j++){$b=$allCards[$j];if($a.X -lt $b.X+$cw -and $a.X+$cw -gt $b.X -and $a.Y -lt $b.Y+$b.H -and $a.Y+$a.H -gt $b.Y){throw 'Table cards overlap.'}}
 }
 $palette=@('#2563eb','#0f766e','#7c3aed','#b45309','#be185d','#475569','#0891b2')
 for($i=0;$i -lt $model.Relations.Count;$i++){
  $r=$model.Relations[$i];$p=$cards[$r.Parent];$c=$cards[$r.Child];$py=RowY $p $r.ParentField;$cy=RowY $c $r.Field;$lane=($i%6)*7
  if($p.X -eq $c.X){
   if($p.X -eq 40){$px=$p.X+$cw;$cx=$c.X+$cw;$mid=$px+15+$lane}else{$px=$p.X;$cx=$c.X;$mid=$px-15-$lane}
   $points=@(@($px,$py),@($mid,$py),@($mid,$cy),@($cx,$cy))
  }elseif([Math]::Abs($p.X-$c.X) -eq 870){
   if($p.X -lt $c.X){$px=$p.X+$cw;$cx=$c.X;$mid=$px+15+$lane}else{$px=$p.X;$cx=$c.X+$cw;$mid=$cx+15+$lane}
   $points=@(@($px,$py),@($mid,$py),@($mid,$cy),@($cx,$cy))
  }else{
   # Long links use the clear top/bottom perimeter instead of crossing table cards.
   $px=$p.X+$cw;$cx=$c.X;$start=$px+15+$lane;$end=$cx-15-$lane
   $bus=if($r.Parent -eq 'auth.users'){125+($i%7)*6}else{2230+($i%4)*8}
   $points=@(@($px,$py),@($start,$py),@($start,$bus),@($end,$bus),@($end,$cy),@($cx,$cy))
  }
  LinePath $points $palette[$i%$palette.Count] ($r.Parent+'.'+$r.ParentField+' -> '+$r.Child+'.'+$r.Field+'; ON DELETE '+$r.Delete)
 }
 foreach($card in ($cards.Values|Sort-Object X,Y)){
  $x=$card.X;$y=$card.Y;$schema,$name=$card.Name -split '\.',2;$fill=if($schema -eq 'private'){'#ece8f7'}elseif($schema -eq 'auth'){'#e2e8f0'}else{'#dbeafe'}
  Box $x $y $cw $card.H '#ffffff';Box $x $y $cw $hh $fill
  Text $(if($schema -eq 'auth'){'auth | managed reference'}else{$schema}) ($x+15) ($y+6) 24 '#52657b'
  Text $name ($x+15) ($y+38) 28 '#172b46' $true
  for($i=0;$i -lt $card.Columns.Count;$i++){
   $col=$card.Columns[$i];$ry=$y+$hh+$rh*$i
   if($i%2 -eq 0){Box ($x+1) $ry ($cw-2) $rh '#f7f9fc' '#f7f9fc'}
   Text ((@($col.Keys)|Sort-Object)-join '/') ($x+10) ($ry+11) 20 '#1d4ed8' $true
   Text $col.Name ($x+108) ($ry+6) 30
   Text ($col.Type+$(if($col.Required){' *'}else{''})) ($x+565) ($ry+10) 23 '#52657b'
  }
 }
 Text 'PK = primary key   FK = foreign key   UQ = unique constraint/index   * = NOT NULL. Lines connect referenced keys to foreign-key columns.' 40 2300 28
 Text '15 application tables + auth.users reference; 21 declared foreign keys. All key columns are shown; other attributes are selected for readability.' 40 2345 28 '#52657b'
 Text 'Full 174-column definitions: see the data dictionary. UUID fields without declared foreign keys have no relationship line.' 40 2390 28 '#52657b'
 Text 'Source: project pgAdmin schema export and checked migration baseline. Layout: A4 landscape, one page.' 40 2433 25 '#52657b'
 $svg.Add('</svg>')
 $bmp.Save((Join-Path $out '05-erd-one-page.png'),[Drawing.Imaging.ImageFormat]::Png)
 [IO.File]::WriteAllLines((Join-Path $out '05-erd-one-page.svg'),$svg,[Text.UTF8Encoding]::new($false))
 [pscustomobject]@{Width=$width;Height=$height;Primitives=@($primitives)}|ConvertTo-Json -Depth 15 -Compress|Set-Content -LiteralPath (Join-Path $out '05-erd-one-page-drawing.json') -Encoding UTF8
 & node (Join-Path $PSScriptRoot 'export-erd-one-page-pdf.mjs')
 if($LASTEXITCODE -ne 0){throw 'One-page PDF export failed.'}
 'Rendered one connected A4 landscape schema overview: 15 application tables, auth.users reference, 21 foreign-key connections, all PK/FK columns.'
}finally{$g.Dispose();$bmp.Dispose()}
