param([string]$SchemaExport)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$out=Join-Path $PSScriptRoot 'Chapter 3 Diagrams'
$modelPath=Join-Path $out 'schema-visualizer.json'
if($SchemaExport){
 $sql=Get-Content -Raw -LiteralPath $SchemaExport
 $tables=@(foreach($match in [regex]::Matches($sql,'(?ms)CREATE TABLE IF NOT EXISTS ((?:public|private)\.\w+)\s*\((.*?)^\);')){
  $body=$match.Groups[2].Value;$columns=@(foreach($line in ($body -split "`n")){
   if($line -match '^    (?!CONSTRAINT)(\w+)\s+(.+?)\s*,?\s*$'){
    $name=$Matches[1];$definition=$Matches[2].TrimEnd(',');$type=([regex]::Split($definition,'\s+(?:COLLATE|NOT NULL|DEFAULT|GENERATED)\b'))[0]
    $type=$type.Replace('timestamp with time zone','timestamptz').Replace('character varying','varchar').Replace(', ', ',')
    [pscustomobject]@{Name=$name;Type=$type;Required=($definition -match '\bNOT NULL\b');Keys=@()}
   }
  })
  foreach($key in [regex]::Matches($body,'CONSTRAINT \w+ (PRIMARY KEY|UNIQUE) \(([^)]+)\)')){
   $tag=if($key.Groups[1].Value -eq 'PRIMARY KEY'){'PK'}else{'UQ'}
   foreach($name in ($key.Groups[2].Value -split ',\s*')){$col=$columns|Where-Object Name -EQ $name;$col.Keys=@($col.Keys)+$tag}
  }
  [pscustomobject]@{Name=$match.Groups[1].Value;Columns=$columns}
 })
 $relations=@(foreach($match in [regex]::Matches($sql,'(?ms)ALTER TABLE IF EXISTS ((?:public|private)\.\w+)\s+ADD CONSTRAINT (\w+) FOREIGN KEY \(([^)]+)\)\s+REFERENCES ([\w.]+) \(([^)]+)\) MATCH SIMPLE\s+ON UPDATE [\w ]+?\s+ON DELETE ([\w ]+?);')){
  $table=$tables|Where-Object Name -EQ $match.Groups[1].Value
  $col=$table.Columns|Where-Object Name -EQ $match.Groups[3].Value;$col.Keys=@($col.Keys)+'FK'
  [pscustomobject]@{Child=$table.Name;Field=$col.Name;Parent=$match.Groups[4].Value;ParentField=$match.Groups[5].Value;Delete=$match.Groups[6].Value.Trim()}
 })
 # pgAdmin's ERD script emits this index as CREATE INDEX; its uniqueness is
 # independently declared in the checked-in database baseline.
 $baseline=Get-Content -Raw (Join-Path $PSScriptRoot '../supabase/migrations/20261105043517_remote_schema.sql')
 if($baseline -notmatch 'CREATE UNIQUE INDEX "members_auth_user_id_uidx"') {throw 'Cannot substantiate unique members.auth_user_id index.'}
 $col=($tables|Where-Object Name -EQ 'public.members').Columns|Where-Object Name -EQ 'auth_user_id';$col.Keys=@($col.Keys)+'UQ'
 if($tables.Count -ne 15 -or $relations.Count -ne 21 -or ($tables.Columns|Measure-Object).Count -ne 174){throw 'Unexpected application schema coverage.'}
 [pscustomobject]@{Source='Author-supplied pgAdmin ERD export; auth-user uniqueness checked against migration baseline';Tables=$tables;Relations=$relations}|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $modelPath -Encoding UTF8
}
$model=Get-Content -Raw -LiteralPath $modelPath|ConvertFrom-Json
$tables=@{};foreach($table in $model.Tables){$tables[$table.Name]=$table}
$tables['auth.users']=[pscustomobject]@{Name='auth.users';Columns=@([pscustomobject]@{Name='id';Type='uuid';Required=$true;Keys=@('PK')})}
$rowH=33;$headerH=80;$cardW=780
$svg=[Collections.Generic.List[string]]::new()
function Esc([string]$s){[Security.SecurityElement]::Escape($s)}
function Rect($x,$y,$w,$h,$fill,$stroke='#cbd5e1'){
 $brush=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml($fill));$pen=[Drawing.Pen]::new([Drawing.ColorTranslator]::FromHtml($stroke),1.4)
 $g.FillRectangle($brush,[single]$x,[single]$y,[single]$w,[single]$h);$g.DrawRectangle($pen,[single]$x,[single]$y,[single]$w,[single]$h);$brush.Dispose();$pen.Dispose()
 $svg.Add('<rect x="'+$x+'" y="'+$y+'" width="'+$w+'" height="'+$h+'" fill="'+$fill+'" stroke="'+$stroke+'"/>')
}
function Txt($text,$x,$y,$size=26,$color='#172b46',$bold=$false){
 $style=if($bold){[Drawing.FontStyle]::Bold}else{[Drawing.FontStyle]::Regular};$font=[Drawing.Font]::new('Arial',[single]$size,$style,[Drawing.GraphicsUnit]::Pixel);$brush=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml($color))
 $g.DrawString($text,$font,$brush,[single]$x,[single]$y);$font.Dispose();$brush.Dispose();$weight=if($bold){'700'}else{'400'}
 $svg.Add('<text x="'+$x+'" y="'+($y+$size)+'" font-family="Arial, sans-serif" font-size="'+$size+'" font-weight="'+$weight+'" fill="'+$color+'">'+(Esc $text)+'</text>')
}
function Card($name,$x,$y,$reference=$false){
 $table=$tables[$name];$cols=@(if($reference){$table.Columns|Where-Object Name -EQ 'id'}else{$table.Columns})
 $script:cards[$name]=[pscustomobject]@{Name=$name;X=$x;Y=$y;H=($headerH+$rowH*$cols.Count);Columns=$cols;Reference=$reference}
}
function FieldY($card,$field){$index=0;while($index -lt $card.Columns.Count -and $card.Columns[$index].Name -ne $field){$index++};if($index -eq $card.Columns.Count){throw "Field not displayed: $($card.Name).$field"};return $card.Y+$headerH+$index*$rowH+$rowH/2}
function Connect($relation,$i){
 $parent=$cards[$relation.Parent];$child=$cards[$relation.Child];$py=FieldY $parent $relation.ParentField;$cy=FieldY $child $relation.Field
 # Reference lines run through the central gutter; table cards are drawn over them.
 if($parent.X -lt $child.X){$px=$parent.X+$cardW;$cx=$child.X;$mid=900+($i%5-2)*10}
 elseif($parent.X -gt $child.X){$px=$parent.X;$cx=$child.X+$cardW;$mid=900+($i%5-2)*10}
 elseif($parent.X -lt 900){$px=$parent.X+$cardW;$cx=$child.X+$cardW;$mid=845+($i%6)*10}
 else{$px=$parent.X;$cx=$child.X;$mid=955-($i%6)*10}
 $color=$palette[$i%$palette.Count];$pen=[Drawing.Pen]::new([Drawing.ColorTranslator]::FromHtml($color),2.5)
 $points=[Drawing.PointF[]]@([Drawing.PointF]::new($px,$py),[Drawing.PointF]::new($mid,$py),[Drawing.PointF]::new($mid,$cy),[Drawing.PointF]::new($cx,$cy))
 $g.DrawLines($pen,$points);$brush=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml($color));$g.FillEllipse($brush,$px-4,$py-4,8,8);$g.FillEllipse($brush,$cx-4,$cy-4,8,8);$brush.Dispose();$pen.Dispose()
 $tip=$relation.Parent+'.'+$relation.ParentField+' -> '+$relation.Child+'.'+$relation.Field+'; ON DELETE '+$relation.Delete
 $svg.Add('<g><title>'+(Esc $tip)+'</title><path d="M '+$px+' '+$py+' H '+$mid+' V '+$cy+' H '+$cx+'" fill="none" stroke="'+$color+'" stroke-width="2.5"/><circle cx="'+$px+'" cy="'+$py+'" r="4" fill="'+$color+'"/><circle cx="'+$cx+'" cy="'+$cy+'" r="4" fill="'+$color+'"/></g>')
}
function DrawCard($card){
 $x=$card.X;$y=$card.Y;$schema=($card.Name -split '\.')[0];$name=($card.Name -split '\.')[1]
 $header=if($schema -eq 'private'){'#ece8f7'}elseif($schema -eq 'auth'){'#e2e8f0'}else{'#dbeafe'}
 Rect $x $y $cardW $card.H '#ffffff';Rect $x $y $cardW $headerH $header
 $tag=if($card.Reference){' | reference'}elseif($schema -eq 'auth'){' | managed reference'}else{''}
 Txt ($schema+$tag) ($x+18) ($y+9) 20 '#52657b'
 Txt $name ($x+18) ($y+34) 26 '#172b46' $true
 for($j=0;$j -lt $card.Columns.Count;$j++){
  $col=$card.Columns[$j];$ry=$y+$headerH+$j*$rowH
  if($j%2 -eq 0){Rect ($x+1) $ry ($cardW-2) $rowH '#f7f9fc' '#f7f9fc'}
  $keys=(@($col.Keys)|Sort-Object)-join '/';Txt $keys ($x+12) ($ry+5) 18 '#1d4ed8' $true
  Txt $col.Name ($x+115) ($ry+3) 25
  $type=$col.Type+$(if($col.Required){' *'}else{''});Txt $type ($x+512) ($ry+6) 21 '#53647a'
 }
}
$palette=@('#2563eb','#0f766e','#7c3aed','#b45309','#be185d','#475569')
$panels=@(
 @{Letter='a';Title='Membership applications and member records';Height=1740;Nodes=@(@('auth.users',50,150,$true),@('public.profiles',970,150,$true),@('public.membership_applications',50,360,$false),@('public.members',970,360,$false));Children=@('public.membership_applications','public.members')},
 @{Letter='b';Title='Accounts, membership history and audit storage';Height=1940;Nodes=@(@('auth.users',50,150,$true),@('public.members',970,150,$true),@('public.profiles',50,360,$false),@('public.membership_history',970,360,$false),@('private.account_sessions',50,900,$false),@('private.admin_login_attempts',50,1220,$false),@('public.activity_logs',970,1030,$false));Children=@('public.profiles','public.membership_history','private.account_sessions')},
 @{Letter='c';Title='Attendance and mobile scanner pairing';Height=1840;Nodes=@(@('auth.users',50,150,$true),@('public.members',970,150,$true),@('public.attendance',50,360,$false),@('private.attendance_scan_requests',50,820,$false),@('public.mobile_attendance_pairing_policy',50,1200,$false),@('public.mobile_attendance_scan_sessions',970,360,$false),@('public.mobile_attendance_scan_events',970,900,$false));Children=@('public.attendance','private.attendance_scan_requests','public.mobile_attendance_pairing_policy','public.mobile_attendance_scan_sessions','public.mobile_attendance_scan_events')},
 @{Letter='d';Title='Products, sales and sale items';Height=1670;Nodes=@(@('auth.users',50,150,$true),@('public.members',970,150,$true),@('public.products',50,360,$false),@('public.sales',970,360,$false),@('public.sale_items',970,1040,$false));Children=@('public.sales','public.sale_items')}
)
$coverage=[Collections.Generic.List[string]]::new();$linksShown=[Collections.Generic.List[string]]::new()
for($page=0;$page -lt $panels.Count;$page++){
 $panel=$panels[$page];$cards=@{};$svg.Clear();$height=$panel.Height
 $bmp=[Drawing.Bitmap]::new(1800,$height);$g=[Drawing.Graphics]::FromImage($bmp);$g.Clear([Drawing.Color]::White);$g.SmoothingMode='AntiAlias';$g.TextRenderingHint='AntiAliasGridFit'
 $svg.Add('<svg xmlns="http://www.w3.org/2000/svg" width="1800" height="'+$height+'" viewBox="0 0 1800 '+$height+'"><rect width="100%" height="100%" fill="white"/>')
 Txt ('Figure 5'+$panel.Letter+'. '+$panel.Title) 50 28 35 '#172b46' $true
 Txt 'Physical database schema | table columns and declared foreign-key connections' 50 82 24 '#53647a'
 foreach($node in $panel.Nodes){Card $node[0] $node[1] $node[2] $node[3];if(-not $node[3]){$coverage.Add($node[0])}}
 $rs=@($model.Relations|Where-Object Child -In $panel.Children)
 foreach($r in $rs){if(-not $cards.ContainsKey($r.Parent) -or -not $cards.ContainsKey($r.Child)){throw "Missing endpoint for $($r.Child).$($r.Field)"}}
 for($i=0;$i -lt $rs.Count;$i++){Connect $rs[$i] $i;$linksShown.Add($rs[$i].Child+'.'+$rs[$i].Field)}
 foreach($node in $panel.Nodes){DrawCard $cards[$node[0]]}
 $fy=$height-170
 Txt 'PK = primary key     FK = foreign key     UQ = unique key/index     * = NOT NULL' 50 $fy 24
 Txt 'Lines join a referenced key to its foreign-key column. Reference cards repeat existing tables.' 50 ($fy+38) 23 '#53647a'
 Txt 'Types abbreviated: varchar = character varying; timestamptz = timestamp with time zone.' 50 ($fy+73) 23 '#53647a'
 Txt 'Source: project pgAdmin schema export; application tables only, with auth.users as a managed reference.' 50 ($fy+108) 21 '#53647a'
 $svg.Add('</svg>');$stem='05-erd-'+($page+1)
 $bmp.Save((Join-Path $out ($stem+'.png')),[Drawing.Imaging.ImageFormat]::Png);$g.Dispose();$bmp.Dispose()
 [IO.File]::WriteAllLines((Join-Path $out ($stem+'.svg')),$svg,[Text.UTF8Encoding]::new($false))
}
if($coverage.Count -ne 15 -or @($coverage|Select-Object -Unique).Count -ne 15 -or $linksShown.Count -ne 21 -or @($linksShown|Select-Object -Unique).Count -ne 21){throw 'Rendered schema coverage is incomplete or duplicated.'}
'Rendered four schema figures: 15 complete table cards, 174 columns, 21 foreign-key connections, plus reference cards.'
