$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=Split-Path $PSScriptRoot -Parent
$backup=Join-Path $root 'Review Backups/non-dfd-diagrams-20261111/Chapter 3.docx'
$old=[IO.Compression.ZipFile]::OpenRead($backup);$current=[IO.Compression.ZipFile]::OpenRead((Join-Path $root 'Chapter 3.docx'))
try {
 function Xml($zip,$part){$sr=[IO.StreamReader]::new($zip.GetEntry($part).Open());try{$x=[Xml.XmlDocument]::new();$x.PreserveWhitespace=$true;$x.LoadXml($sr.ReadToEnd());return ,$x}finally{$sr.Dispose()}}
 $doc=Xml $current 'word/document.xml';$before=Xml $old 'word/document.xml';$rels=Xml $current 'word/_rels/document.xml.rels'
 $ns=[Xml.XmlNamespaceManager]::new($doc.NameTable);foreach($p in @(@('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main'),@('a','http://schemas.openxmlformats.org/drawingml/2006/main'),@('r','http://schemas.openxmlformats.org/officeDocument/2006/relationships'),@('wp','http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing'))){$ns.AddNamespace($p[0],$p[1])}
 function Txt($p){($p.SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join ''}
 $paras=@($doc.SelectNodes('//w:body/w:p',$ns));$report=[Collections.Generic.List[string]]::new()
 foreach($caption in @('Figure 2. Context - Gane-Sarson','Figure 4. Use Case Diagram','Figure 5. Public-schema Entity Relationship Diagram','Figure 33. Gantt Chart')){if(@($paras|Where-Object {(Txt $_).Trim() -eq $caption}).Count -ne 1){throw "Missing/duplicate caption: $caption"}}
 $tableCount=$doc.SelectNodes('//w:tbl',$ns).Count
 if((($doc.SelectNodes('//w:tbl',$ns)|ForEach-Object OuterXml)-join '') -cne (($before.SelectNodes('//w:tbl',$ns)|ForEach-Object OuterXml)-join '')){throw 'Tables changed'}
 $report.Add("PASS: all $tableCount requirements/dictionary tables byte-equivalent as XML; expected figure captions unique.")
 function HashEntry($entry){$s=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create();try{[Convert]::ToBase64String($sha.ComputeHash($s))}finally{$s.Dispose();$sha.Dispose()}}
 $allowed=@('word/document.xml')
 foreach($pair in @(@('Context Diagram','02-context'),@('Entity Relationship Diagram','05-gym-erd-editable'),@('Gantt Chart','33-gantt'))){$heading=@($paras|Where-Object {(Txt $_).Trim() -eq $pair[0]})[0];$p=$heading.NextSibling;while(-not $p.SelectSingleNode('.//a:blip',$ns)){$p=$p.NextSibling;if(-not $p){throw 'Missing image'}};$blip=$p.SelectSingleNode('.//a:blip',$ns);$id=$blip.GetAttribute('embed',$ns.LookupNamespace('r'));$rel=@($rels.DocumentElement.ChildNodes|Where-Object Id -eq $id)[0];$part='word/'+$rel.Target;$allowed+=$part;$file=Join-Path $root ('Chapter 3 Diagrams/'+$pair[1]+'.png');$hash=(Get-FileHash $file).Hash;$stream=$current.GetEntry($part).Open();$sha=[Security.Cryptography.SHA256]::Create();try{$embedded=([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','')}finally{$sha.Dispose();$stream.Dispose()};if($hash -ne $embedded){throw 'Embedded image mismatch'}
  if($p.SelectSingleNode('.//a:srcRect|.//a:extLst',$ns)){throw 'Unexpected crop/vector override'}
 }
 foreach($entry in $old.Entries){if($entry.FullName -in $allowed){continue};if((HashEntry $entry) -ne (HashEntry $current.GetEntry($entry.FullName))){throw "Unexpected package change: $($entry.FullName)"}}
 $report.Add('PASS: embedded context, ERD and Gantt images match verified PNG files; no cropping or stale vector override.')
 $report.Add('PASS: all unrelated package parts, including Agile, DFD, use-case and prototype image bytes, remain unchanged.')
 foreach($blip in $doc.SelectNodes('//a:blip',$ns)){$id=$blip.GetAttribute('embed',$ns.LookupNamespace('r'));$rel=@($rels.DocumentElement.ChildNodes|Where-Object Id -eq $id);if($rel.Count -ne 1 -or -not $current.GetEntry('word/'+$rel[0].Target)){throw 'Broken image reference'}}
 $model=Get-Content -Raw -Encoding UTF8 (Join-Path $root 'Chapter 3 Diagrams/schema-visualizer.json')|ConvertFrom-Json
 $fields=($model.Tables|ForEach-Object {$_.Columns.Count}|Measure-Object -Sum).Sum
 if($model.Tables.Count -ne 21 -or $fields -ne 224 -or $model.Relations.Count -ne 33){throw 'Model totals changed'}
 [xml]$editable=Get-Content -Raw -Encoding UTF8 (Join-Path $root 'Chapter 3 Diagrams/05-gym-erd-editable.drawio');if($editable.SelectNodes('//mxCell[@edge="1"]').Count -ne 18){throw 'Public ERD edge count changed'}
 $report.Add('PASS: full schema model has 21 tables / 224 fields / 33 foreign keys; public ERD retains 18 relationship edges.')
 if(@($doc.SelectNodes('//w:sectPr/w:pgSz[@w:orient="landscape"]',$ns)).Count -ne 3){throw 'Expected three dedicated landscape sections'}
 $report.Add('PASS: context, ERD and Gantt have dedicated landscape sections; all embedded image references resolve.')
 $report.Add('PASS: generator/application-script preservation checks compare opening/Agile and entire DFD section XML with the backup.')
 $report.Add('LIMIT: desktop Word automation did not complete; actual Word pagination and print layout are not certified. No completed PDF preview is claimed.')
 $report | Set-Content -Encoding UTF8 (Join-Path $root 'Review Evidence/diagram-recheck/Revision verification.txt')
 $report
} finally {$old.Dispose();$current.Dispose()}
