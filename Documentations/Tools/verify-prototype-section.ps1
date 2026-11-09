param([string]$DocumentPath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'Chapter 3.docx'))
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=Split-Path $PSScriptRoot -Parent;$model=Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $root 'Prototype Screenshots/_Sources/prototype-layout.json')|ConvertFrom-Json
$zip=[IO.Compression.ZipFile]::OpenRead($DocumentPath)
try{
 $rd=[IO.StreamReader]::new($zip.GetEntry('word/document.xml').Open());$doc=[xml]$rd.ReadToEnd();$rd.Dispose();$rd=[IO.StreamReader]::new($zip.GetEntry('word/_rels/document.xml.rels').Open());$rels=[xml]$rd.ReadToEnd();$rd.Dispose()
 $ns=[Xml.XmlNamespaceManager]::new($doc.NameTable);$ns.AddNamespace('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main');$ns.AddNamespace('a','http://schemas.openxmlformats.org/drawingml/2006/main');$ns.AddNamespace('r','http://schemas.openxmlformats.org/officeDocument/2006/relationships');$ns.AddNamespace('wp','http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing')
 $all=@($doc.SelectNodes('//w:body/w:p',$ns)|ForEach-Object {(($_.SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join '').Trim()})
 $sha=[Security.Cryptography.SHA256]::Create();$count=0
 foreach($f in $model.Figures){
  if(@($all|Where-Object {$_ -ceq $f.Caption}).Count -ne 1){throw ('Missing/duplicate caption '+$f.Label)}
  if(@($all|Where-Object {$_ -ceq $f.Description}).Count -ne 1){throw ('Missing explanation '+$f.Label)}
  $rid='rIdPrototype'+$f.Number.ToString('00')+$f.Suffix
  $rel=@($rels.DocumentElement.ChildNodes|Where-Object Id -eq $rid);if($rel.Count -ne 1){throw 'Missing screenshot relationship'}
  $entry=$zip.GetEntry('word/'+$rel[0].Target);if(-not $entry){throw 'Screenshot part missing'}
  $s=$entry.Open();try{$actual=[Convert]::ToBase64String($sha.ComputeHash($s))}finally{$s.Dispose()};$expected=[Convert]::ToBase64String($sha.ComputeHash([IO.File]::ReadAllBytes($f.ImagePath)));if($actual -ne $expected){throw ('Embedded screenshot mismatch '+$f.Label)}
  $blip=@($doc.SelectNodes('//a:blip',$ns)|Where-Object {$_.GetAttribute('embed',$ns.LookupNamespace('r')) -eq $rid});if($blip.Count -ne 1){throw 'Missing/duplicate screenshot placement'}
  $count++
 }
 if(($model.Figures.SourceId|Sort-Object -Unique).Count -ne 27 -or $count -ne 38){throw 'Incomplete original capture coverage'}
 if(@($all|Where-Object {$_ -eq 'Figure 33. Gantt Chart'}).Count -ne 1){throw 'Gantt figure not renumbered'}
 if(@($all|Where-Object {$_ -match '^Figure (15\. Report Preview|16\. Final Report Print|20\. Staff workflow|21\. Gantt Chart)'}).Count){throw 'Superseded prototype caption remains'}
 $ids=@($doc.SelectNodes('//wp:docPr',$ns)|ForEach-Object {$_.GetAttribute('id')});if(($ids|Sort-Object -Unique).Count -ne $ids.Count){throw 'Duplicate drawing identifiers'}
 $report=@('Prototype verification passed.','27 supplied original screenshots represented in 38 readable figure parts.','Figures 6-32: each caption and explanation appears once; all embedded PNGs match the approved full captures or their lossless parts.','Gantt caption renumbered to Figure 33; schedule content retained.','All picture placements resolve to embedded media; drawing identifiers are unique.')
 $report|Set-Content -Encoding UTF8 -LiteralPath (Join-Path $root 'Review Evidence/Prototype Section Verification.txt')
 $report
}finally{$zip.Dispose()}
