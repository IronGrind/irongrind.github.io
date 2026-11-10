$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=Split-Path $PSScriptRoot -Parent
$backup=Get-ChildItem (Join-Path $root 'Review Backups') -Directory -Filter 'gantt-planning-*'|Sort-Object Name -Descending|Select-Object -First 1
if(-not $backup){throw 'Missing Gantt correction backup'}
$report=[Collections.Generic.List[string]]::new()
$explanation='Figure 33 presents the original ten-week development schedule for IronGrind, from August 24 to October 28, 2026. The activity and date columns identify the work assigned to each scheduled week. As clarified by the proponents, Planning occupies Weeks 1-4 and consists of identifying a potential client, conducting the first client interview to identify problems and needs, project conceptualization, and drafting the proposal. Design occupies Weeks 5-8 and covers interface design, prototype development, client feedback, and refinement. Development occupies Weeks 9-10 and covers frontend, backend, database, API, and supporting work alongside the project chapters. The four planning labels reflect the activities reported by the proponents. The existing date ranges are retained as schedule assignments and do not independently establish the actual completion dates of those activities.'
foreach($name in @('Chapter 3.docx','Chapters 1-3 with Table of Contents.docx')){
 $original=Join-Path $backup.FullName $name;$destination=Join-Path $root $name
 if((Get-FileHash $original).Hash -ne (Get-FileHash $destination).Hash){throw "Document changed since backup: $name"}
 $stage=Join-Path $backup.FullName ('Updated '+$name);Copy-Item -LiteralPath $original -Destination $stage -Force
 $zip=[IO.Compression.ZipFile]::Open($stage,'Update');$oldZip=[IO.Compression.ZipFile]::OpenRead($original)
 try{
  function ReadXml($archive,$part){$sr=[IO.StreamReader]::new($archive.GetEntry($part).Open());try{$x=[Xml.XmlDocument]::new();$x.PreserveWhitespace=$true;$x.LoadXml($sr.ReadToEnd());return ,$x}finally{$sr.Dispose()}}
  function Hash($entry){$s=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create();try{[Convert]::ToBase64String($sha.ComputeHash($s))}finally{$s.Dispose();$sha.Dispose()}}
  $doc=ReadXml $zip 'word/document.xml';$rels=ReadXml $zip 'word/_rels/document.xml.rels';$ns=[Xml.XmlNamespaceManager]::new($doc.NameTable);$ns.AddNamespace('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main');$ns.AddNamespace('a','http://schemas.openxmlformats.org/drawingml/2006/main');$ns.AddNamespace('r','http://schemas.openxmlformats.org/officeDocument/2006/relationships')
  function Txt($p){($p.SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join ''}
  $paras=@($doc.SelectNodes('//w:body/w:p',$ns));$captions=@($paras|Where-Object {(Txt $_).Trim() -eq 'Figure 33. Gantt Chart'});$paragraphs=@($paras|Where-Object {(Txt $_).Trim() -match '^(Figure 33 presents|The Gantt chart presents)'})
  if($captions.Count -ne 1 -or $paragraphs.Count -ne 1){throw "Ambiguous Gantt section in $name"}
  $picture=$captions[0].PreviousSibling;while($picture -and -not $picture.SelectSingleNode('.//a:blip',$ns)){$picture=$picture.PreviousSibling};if(-not $picture){throw 'Missing Gantt image'}
  $blip=$picture.SelectSingleNode('.//a:blip',$ns);$id=$blip.GetAttribute('embed',$ns.LookupNamespace('r'));$rel=@($rels.DocumentElement.ChildNodes|Where-Object Id -eq $id);if($rel.Count -ne 1){throw 'Ambiguous Gantt image relationship'};$imagePart='word/'+$rel[0].Target
  $before=@($doc.SelectNodes('//w:body/*',$ns)|Where-Object {-not [object]::ReferenceEquals($_,$paragraphs[0])}|ForEach-Object OuterXml)-join ''
  $texts=$paragraphs[0].SelectNodes('.//w:t',$ns);$texts[0].InnerText=$explanation;foreach($t in @($texts|Select-Object -Skip 1)){$t.InnerText=''}
  if($before -cne ((@($doc.SelectNodes('//w:body/*',$ns)|Where-Object {-not [object]::ReferenceEquals($_,$paragraphs[0])}|ForEach-Object OuterXml))-join '')){throw 'Unrelated document content changed'}
  $zip.GetEntry($imagePart).Delete();$stream=$zip.CreateEntry($imagePart).Open();$png=[IO.File]::ReadAllBytes((Join-Path $root 'Chapter 3 Diagrams/33-gantt.png'));$stream.Write($png,0,$png.Length);$stream.Dispose()
  $zip.GetEntry('word/document.xml').Delete();$stream=$zip.CreateEntry('word/document.xml').Open();$writer=[IO.StreamWriter]::new($stream,[Text.UTF8Encoding]::new($false));$doc.Save($writer);$writer.Dispose()
  $parsed=ReadXml $zip 'word/document.xml'
  foreach($entry in $oldZip.Entries){if($entry.FullName -in @('word/document.xml',$imagePart)){continue};if((Hash $entry) -ne (Hash $zip.GetEntry($entry.FullName))){throw ('Unexpected change: '+$entry.FullName)}}
  $stream=[IO.MemoryStream]::new($png);$sha=[Security.Cryptography.SHA256]::Create();try{if((Hash $zip.GetEntry($imagePart)) -ne [Convert]::ToBase64String($sha.ComputeHash($stream))){throw 'Gantt PNG mismatch'}}finally{$stream.Dispose();$sha.Dispose()}
  $report.Add("PASS: $name - only the Gantt image and its explanatory paragraph changed; all other body nodes, tables, styles, TOC fields, relationships and media preserved.")
 }finally{$zip.Dispose();$oldZip.Dispose()}
 Copy-Item -LiteralPath $stage -Destination $destination -Force
}
$report.Add('Planning rows: identifying a potential client; first client interview and identification of problems/needs; project conceptualization; drafting the proposal. Existing dates and design/development activities retained. Rendered PNG visually inspected. No deployment or actual-completion-date verification claimed.')
$report.Add('Backup: '+$backup.FullName)
$report|Set-Content -Encoding UTF8 (Join-Path $root 'Review Evidence/Gantt Planning Correction Verification.txt')
$report
