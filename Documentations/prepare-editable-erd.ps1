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
