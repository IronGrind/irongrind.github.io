param([string]$SchemaExport=(Join-Path $env:USERPROFILE '.codex/attachments/a2d7710c-bf82-47ed-a2c5-9f1b489faa01/Pasted text.txt'))
$ErrorActionPreference='Stop'
$out=Join-Path $PSScriptRoot 'Chapter 3 Diagrams'
$source=Join-Path $env:USERPROFILE 'Downloads/erd_gym_simple.svg'
$doc=[xml](Get-Content -LiteralPath $source -Raw)
$root=$doc.DocumentElement
$nodes=@($root.ChildNodes)
function AddBadge($x,$y){
 $r=$doc.CreateElement('rect',$root.NamespaceURI)
 foreach($a in @{x=$x;y=$y;width=20;height=11;rx=2.5;fill='#475569'}.GetEnumerator()){$r.SetAttribute($a.Key,[string]$a.Value)}
 $null=$root.AppendChild($r)
 $t=$doc.CreateElement('text',$root.NamespaceURI)
 foreach($a in @{x=($x+10);y=($y+8.5);'font-size'=8;'font-weight'=700;fill='#fff';'text-anchor'='middle'}.GetEnumerator()){$t.SetAttribute($a.Key,[string]$a.Value)}
 $t.InnerText='UQ';$null=$root.AppendChild($t)
}
AddBadge 58 236
AddBadge 761 170
AddBadge 1078 280
# The auth-user row already has one badge; move its new UQ badge beside it.
# Keep the existing field-label alignment and all original table positions.
foreach($n in $nodes){
 if($n.LocalName -eq 'text' -and $n.GetAttribute('y') -eq '66'){$n.InnerText='Gym membership, attendance and sales system: selected attributes; complete definitions appear in the data dictionary.'}
}
# Give the history edge its own source port rather than sharing the sales edge.
$history=@($nodes|Where-Object {$_.LocalName -eq 'path' -and $_.GetAttribute('d') -eq 'M 970 131.0 L 995 131.0 L 995 443.0 L 1070 443.0'})[0]
if(-not $history){throw 'Expected history connector not found.'}
$history.SetAttribute('d','M 970 145 L 995 145 L 995 443 L 1070 443')
$index=[Array]::IndexOf($nodes,$history)
foreach($n in @($nodes[($index+1)],$nodes[($index+2)])){
 if($n.LocalName -ne 'line'){throw 'Unexpected history endpoint symbol.'}
 $n.SetAttribute('y1',[string]([double]$n.GetAttribute('y1')+14))
 $n.SetAttribute('y2',[string]([double]$n.GetAttribute('y2')+14))
}
# Match the user's Gane-Sarson palette; use FK* rather than color to identify Auth references.
foreach($n in @($root.ChildNodes)){
 if($n.LocalName -eq 'text'){
  if($n.InnerText -eq 'FK' -and $n.PreviousSibling.LocalName -eq 'rect' -and $n.PreviousSibling.GetAttribute('fill') -eq '#7c3aed'){$n.InnerText='FK*'}
  if($n.InnerText -eq 'Target of every purple FK badge'){$n.InnerText='Target of every FK* badge'}
 }
}
foreach($n in @($root.ChildNodes)){
 if($n.LocalName -eq 'text'){$n.SetAttribute('fill','#000000')}
 elseif($n.LocalName -eq 'rect'){
  if($n.HasAttribute('opacity')){$n.SetAttribute('opacity','0')}
  $fill=$n.GetAttribute('fill')
  if($fill -and $fill -notin @('#fff','#ffffff','white','none')){
   $n.SetAttribute('fill',$(if([double]$n.GetAttribute('height') -eq 11){'#d5e2f5'}else{'#ffffff'}))
  }
  if($n.HasAttribute('stroke')){$n.SetAttribute('stroke','#000000')}
 }elseif($n.LocalName -eq 'path'){
  if($n.GetAttribute('fill') -ne 'none'){$n.SetAttribute('fill','#d5e2f5')}
  if($n.HasAttribute('stroke')){$n.SetAttribute('stroke','#000000')}
 }elseif($n.LocalName -in @('line','circle')){
  if($n.HasAttribute('stroke')){$n.SetAttribute('stroke','#000000')}
 }
}
# Read exact declared sizes from the latest pgAdmin export without executing SQL.
$sql=Get-Content -Raw -LiteralPath $SchemaExport
$types=@{}
foreach($match in [regex]::Matches($sql,'(?ms)CREATE TABLE IF NOT EXISTS (public\.\w+)\s*\r?\n\(\r?\n(.*?)^\);')){
 $table=$match.Groups[1].Value
 foreach($c in [regex]::Matches($match.Groups[2].Value,'(?m)^    (\w+) (character varying(?:\(\d+\))?|numeric(?:\(\d+,\s*\d+\))?|timestamp with time zone|timestamp without time zone|uuid|text\[\]|text|jsonb|boolean|bigint|smallint|integer|date)\b?(\([^\r\n]*?)?')){
  $type=$c.Groups[2].Value.Replace('character varying','varchar').Replace('timestamp with time zone','timestamptz').Replace('timestamp without time zone','timestamp').Replace(', ',',')
  $types[$table+'.'+$c.Groups[1].Value]=$type
 }
}
if($types.Count -ne 162){throw "Expected 162 public field types; found $($types.Count)."}
$cardNodes=@($root.ChildNodes|Where-Object {$_.LocalName -eq 'rect' -and $_.GetAttribute('width') -eq '240' -and $_.HasAttribute('stroke')})
$shownTypes=0
foreach($n in @($root.ChildNodes|Where-Object {$_.LocalName -eq 'text' -and $_.GetAttribute('text-anchor') -eq 'end'})){
 $x=[double]$n.GetAttribute('x');$y=[double]$n.GetAttribute('y')
 $card=@($cardNodes|Where-Object {$x -ge [double]$_.GetAttribute('x') -and $x -le ([double]$_.GetAttribute('x')+240) -and $y -ge [double]$_.GetAttribute('y') -and $y -le ([double]$_.GetAttribute('y')+[double]$_.GetAttribute('height'))})[0]
 if(-not $card){throw 'Unmatched type label.'}
 $cx=[double]$card.GetAttribute('x');$cy=[double]$card.GetAttribute('y')
 $title=@($root.ChildNodes|Where-Object {$_.LocalName -eq 'text' -and $_.GetAttribute('text-anchor') -eq 'middle' -and [double]$_.GetAttribute('x') -eq ($cx+120) -and [double]$_.GetAttribute('y') -eq ($cy+20)})[0].InnerText
 $field=@($root.ChildNodes|Where-Object {$_.LocalName -eq 'text' -and $_.GetAttribute('font-size') -eq '12.5' -and $_.GetAttribute('y') -eq $n.GetAttribute('y') -and [double]$_.GetAttribute('x') -gt $cx -and [double]$_.GetAttribute('x') -lt $x})[0].InnerText
 $key='public.'+$title+'.'+$field
 if(-not $types.ContainsKey($key)){throw "Missing pgAdmin declaration: $key"}
 $n.InnerText=$types[$key];$shownTypes++
 # Fit exact type labels into a compact, separate right-aligned column.
 $n.SetAttribute('font-size','9.5')
}
"Applied $shownTypes exact field types from 162 verified public declarations."
# The figure description carries notation details; omit the two explanatory boxes.
foreach($n in @($root.ChildNodes)){
 $x=$null;$y=$null
 if($n.LocalName -in @('rect','text')){$x=$n.GetAttribute('x');$y=$n.GetAttribute('y')}
 elseif($n.LocalName -eq 'line'){$x=$n.GetAttribute('x1');$y=$n.GetAttribute('y1')}
 elseif($n.LocalName -eq 'circle'){$x=$n.GetAttribute('cx');$y=$n.GetAttribute('cy')}
 if($null -ne $x -and $null -ne $y -and [double]$x -ge 730 -and [double]$y -ge 600){$null=$root.RemoveChild($n)}
}
# Show Auth references explicitly using subdued dashed connectors.
$root.SetAttribute('viewBox','0 0 1700 1100');$root.SetAttribute('height','1100')
$background=@($root.ChildNodes|Where-Object {$_.LocalName -eq 'rect' -and -not $_.HasAttribute('x')})[0]
if($background){$background.SetAttribute('height','1100')}
foreach($n in @($root.ChildNodes|Where-Object {$_.LocalName -eq 'text' -and $_.InnerText -eq 'FK*'})){$n.InnerText='FK'}
function Element($tag,$attrs,$text=''){
 $el=$doc.CreateElement($tag,$root.NamespaceURI)
 foreach($a in $attrs.GetEnumerator()){$el.SetAttribute($a.Key,[string]$a.Value)}
 if($text){$el.InnerText=$text};$null=$root.AppendChild($el)
}
Element 'rect' @{x=730;y=990;width=240;height=70;rx=7;fill='#fff';stroke='#000000';'stroke-width'=1.6}
Element 'path' @{d='M 730 1020 V 997 Q 730 990 737 990 H 963 Q 970 990 970 997 V 1020 Z';fill='#d5e2f5'}
Element 'text' @{x=850;y=1010;'font-size'=14;'font-weight'=700;fill='#000000';'text-anchor'='middle'} 'auth.users'
Element 'text' @{x=748;y=1041;'font-size'=8;'font-weight'=700;fill='#000000';'text-anchor'='middle'} 'PK'
Element 'text' @{x=766;y=1041;'font-size'=12.5;fill='#000000'} 'id'
Element 'text' @{x=962;y=1041;'font-size'=9.5;fill='#000000';'text-anchor'='end'} 'uuid'
$authRoutes=@(
 @{X=290;Y=131;Lane=320;Required=$true;Unique=$true},
 @{X=390;Y=197;Lane=360;Required=$false;Unique=$false},
 @{X=970;Y=175;Lane=1010;Required=$false;Unique=$true},
 @{X=1310;Y=175;Lane=1340;Required=$false;Unique=$false},
 @{X=730;Y=465;Lane=700;Required=$false;Unique=$false},
 @{X=730;Y=487;Lane=680;Required=$false;Unique=$false},
 @{X=1310;Y=465;Lane=1380;Required=$false;Unique=$false},
 @{X=50;Y=443;Lane=25;Required=$true;Unique=$false},
 @{X=630;Y=663;Lane=660;Required=$false;Unique=$false}
)
$i=0
foreach($r in $authRoutes){
 $px=750+$i*25;$bus=780+$i*14;$i++
 Element 'path' @{d="M $px 990 L $px $bus L $($r.Lane) $bus L $($r.Lane) $($r.Y) L $($r.X) $($r.Y)";fill='none';stroke='#aab2bd';'stroke-width'=1.2;'stroke-dasharray'='6 5';'data-auth'='true';'data-required'=[string]$r.Required;'data-unique'=[string]$r.Unique}
}
$target=Join-Path $out '05-gym-erd-editable.svg'
$doc.Save($target)
$elements=@(foreach($n in $root.ChildNodes){
 if($n.LocalName -notin @('rect','text','path','line','circle')){continue}
 $attrs=@{};foreach($a in $n.Attributes){$attrs[$a.Name]=$a.Value}
 @{Tag=$n.LocalName;A=$attrs;Text=$n.InnerText}
})
$elements|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $out '05-gym-erd-elements.json') -Encoding UTF8
& node (Join-Path $PSScriptRoot 'export-editable-erd.mjs')
if($LASTEXITCODE -ne 0){throw 'Draw.io export failed.'}
"Saved corrected SVG: $target"
