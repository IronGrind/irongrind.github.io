$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=Split-Path $PSScriptRoot -Parent
$svg=Join-Path $root 'Chapter 3 Diagrams/03-user-supplied-dfd.svg'
$png=Join-Path $root 'Review Evidence/Current Manuscript Review/dfd-preview.png'
$backup=Join-Path $root ('Review Backups/supplied-dfd-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $backup -Force|Out-Null
$evidence=[Collections.Generic.List[string]]::new()
foreach($name in @('Chapter 3','Chapters 1-3 with Table of Contents')) {
 $path=Join-Path $root ($name+'.docx');$work=Join-Path $backup ($name+' staged.docx')
 Copy-Item -LiteralPath $path -Destination (Join-Path $backup ($name+'.docx'))
 Copy-Item -LiteralPath $path -Destination $work
 $zip=[IO.Compression.ZipFile]::Open($work,'Update')
 try {
  function ReadPart($part){$rd=[IO.StreamReader]::new($zip.GetEntry($part).Open());try{return ,([xml]$rd.ReadToEnd())}finally{$rd.Dispose()}}
  function WritePart($part,$xml){$entry=$zip.GetEntry($part);if(-not $entry){$entry=$zip.CreateEntry($part)};$s=$entry.Open();$s.SetLength(0);$wr=[IO.StreamWriter]::new($s,[Text.UTF8Encoding]::new($false));try{$xml.Save($wr)}finally{$wr.Dispose()}}
  function AddBinary($part,$source){$old=$zip.GetEntry($part);if($old){$old.Delete()};$s=$zip.CreateEntry($part).Open();try{$bytes=[IO.File]::ReadAllBytes($source);$s.Write($bytes,0,$bytes.Length)}finally{$s.Dispose()}}
  $doc=ReadPart 'word/document.xml';$rels=ReadPart 'word/_rels/document.xml.rels';$types=ReadPart '[Content_Types].xml'
  $ns=[Xml.XmlNamespaceManager]::new($doc.NameTable)
  foreach($pair in @(@('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main'),@('a','http://schemas.openxmlformats.org/drawingml/2006/main'),@('wp','http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing'),@('r','http://schemas.openxmlformats.org/officeDocument/2006/relationships'))){$ns.AddNamespace($pair[0],$pair[1])}
  function TextOf($p){($p.SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join ''}
  function SetText($p,$value){$texts=@($p.SelectNodes('.//w:t',$ns));if(-not $texts.Count){throw 'Missing text run'};$texts[0].InnerText=$value;foreach($t in @($texts|Select-Object -Skip 1)){$t.InnerText=''}}
  $tablesBefore=@($doc.SelectNodes('//w:tbl',$ns)|ForEach-Object OuterXml)
  $paras=@($doc.SelectNodes('//w:body/w:p',$ns))
  $heading=@($paras|Where-Object {(TextOf $_).Trim() -eq 'Data Flow Diagram'})
  $caption=@($paras|Where-Object {(TextOf $_).Trim() -eq 'Figure 3a-e. Level 1 Data Flow - Gane-Sarson'})
  if($heading.Count -ne 1 -or $caption.Count -ne 1){throw 'Unexpected DFD heading/caption'}
  $images=[Collections.Generic.List[object]]::new();$p=$heading[0].NextSibling
  while($p -and $p -ne $caption[0]){if($p.SelectSingleNode('.//w:drawing',$ns)){$images.Add($p)};$p=$p.NextSibling}
  if($images.Count -ne 5){throw "Expected five old DFD panels, found $($images.Count)"}
  $keep=$images[0];foreach($extra in @($images|Select-Object -Skip 1)){if($extra.SelectSingleNode('w:pPr/w:sectPr',$ns)){throw 'Unexpected section break in DFD image'};[void]$extra.ParentNode.RemoveChild($extra)}
  $blip=$keep.SelectSingleNode('.//a:blip',$ns);$blip.SetAttribute('embed',$ns.LookupNamespace('r'),'rIdSuppliedDfdPng')
  $extList=$doc.CreateElement('a','extLst',$ns.LookupNamespace('a'));$ext=$doc.CreateElement('a','ext',$ns.LookupNamespace('a'));$ext.SetAttribute('uri','{96DAC541-7B7A-43D3-8B79-37D633B846F1}')
  $svgBlip=$doc.CreateElement('asvg','svgBlip','http://schemas.microsoft.com/office/drawing/2016/SVG/main');$svgBlip.SetAttribute('embed',$ns.LookupNamespace('r'),'rIdSuppliedDfdSvg');[void]$ext.AppendChild($svgBlip);[void]$extList.AppendChild($ext)
  $priorExt=$blip.SelectSingleNode('a:extLst',$ns);if($priorExt){[void]$blip.RemoveChild($priorExt)};[void]$blip.AppendChild($extList)
  $cx=5486400;$cy=[long][Math]::Round($cx*3755.0/5527.0)
  foreach($extent in $keep.SelectNodes('.//wp:extent | .//a:xfrm/a:ext',$ns)){$extent.SetAttribute('cx',[string]$cx);$extent.SetAttribute('cy',[string]$cy)}
  $info=$keep.SelectSingleNode('.//wp:docPr',$ns);$info.SetAttribute('descr','User-supplied complete Level 1 DFD, preserved as supplied. Full-resolution SVG is embedded for zoom.');$info.SetAttribute('title','IronGrind supplied Level 1 DFD')
  foreach($entry in @(@('rIdSuppliedDfdPng','media/user-supplied-dfd.png'),@('rIdSuppliedDfdSvg','media/user-supplied-dfd.svg'))){$rel=$rels.CreateElement('Relationship',$rels.DocumentElement.NamespaceURI);$rel.SetAttribute('Id',$entry[0]);$rel.SetAttribute('Type','http://schemas.openxmlformats.org/officeDocument/2006/relationships/image');$rel.SetAttribute('Target',$entry[1]);[void]$rels.DocumentElement.AppendChild($rel)}
  if(-not @($types.Types.Default|Where-Object Extension -eq 'svg').Count){$default=$types.CreateElement('Default',$types.DocumentElement.NamespaceURI);$default.SetAttribute('Extension','svg');$default.SetAttribute('ContentType','image/svg+xml');[void]$types.DocumentElement.AppendChild($default)}
  SetText $caption[0] 'Figure 3. Level 1 Data Flow Diagram - Gane-Sarson'
  foreach($para in $doc.SelectNodes('//w:body/w:p',$ns)){
   $text=TextOf $para
   if($text.StartsWith('Figures 3a-e expand')){SetText $para 'Figure 3 expands the system into nine processes using the supplied Level 1 DFD. Its data-store symbols identify public application tables; managed authentication and private security/session stores are outside this drawing.'}
   elseif($text.StartsWith('Figure 3a-e expands')){SetText $para 'Figure 3 reproduces the complete user-supplied Level 1 DFD in Gane-Sarson notation. It shows Member / Applicant, Staff and Admin interacting with nine numbered processes. The full-resolution SVG is embedded for enlargement; the supplied arrows and labels are retained rather than silently redrawn. Implementation differences identified during review are recorded in the accompanying manuscript review report.'}
   elseif($text.StartsWith('Store identifiers remain consistent across the panels.')){SetText $para 'The supplied drawing labels D1 profiles, D2 membership_applications, D3 members, D4 attendance, D5 products, D6 sales, D7 sale_items, D8 membership_history, D9 activity_logs, D10 mobile_attendance_pairing_policy, D11 mobile_attendance_scan_sessions and D12 mobile_attendance_scan_events. The presence of a table in this design drawing does not establish that current scanner code writes to it: D12 is retained legacy storage, while current authenticated attendance uses attendance and a private retry-protection record. Auth and private session/security tables are not drawn. The Activity Logs viewer reads recorded events; the supplied event-flow routing should be checked against this read-only implementation before treating the diagram as an implementation-exact model.'}
  }
  $tablesAfter=@($doc.SelectNodes('//w:tbl',$ns)|ForEach-Object OuterXml)
  if(($tablesBefore -join "`n") -cne ($tablesAfter -join "`n")){throw 'Tables changed'}
  WritePart 'word/document.xml' $doc;WritePart 'word/_rels/document.xml.rels' $rels;WritePart '[Content_Types].xml' $types
  AddBinary 'word/media/user-supplied-dfd.svg' $svg;AddBinary 'word/media/user-supplied-dfd.png' $png
 }finally{$zip.Dispose()}
 $check=[IO.Compression.ZipFile]::OpenRead($work)
 try {foreach($part in $check.Entries|Where-Object {$_.FullName.EndsWith('.xml') -or $_.FullName.EndsWith('.rels')}){$rd=[IO.StreamReader]::new($part.Open());try{$parsed=[xml]$rd.ReadToEnd()}finally{$rd.Dispose()}}}finally{$check.Dispose()}
 Copy-Item -LiteralPath $work -Destination $path -Force
 $evidence.Add("$name : replaced five DFD panels with the supplied SVG plus PNG fallback; updated four DFD paragraphs; all tables preserved; XML parsed; backup $backup")
}
[IO.File]::WriteAllLines((Join-Path $root 'Review Evidence/Current Manuscript Review/DFD Replacement Verification.txt'),$evidence,[Text.UTF8Encoding]::new($false))
$evidence
