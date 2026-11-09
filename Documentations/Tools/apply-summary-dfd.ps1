$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=Split-Path $PSScriptRoot -Parent;$path=Join-Path $root 'Chapter 3.docx'
$backup=Join-Path $root ('Review Backups/summary-dfd-'+(Get-Date -Format yyyyMMdd-HHmmss));New-Item -ItemType Directory -Path $backup -Force|Out-Null
Copy-Item -LiteralPath $path -Destination (Join-Path $backup 'Chapter 3.docx')
$work=Join-Path $backup 'Chapter 3 working.docx';Copy-Item -LiteralPath $path -Destination $work
$z=[IO.Compression.ZipFile]::Open($work,'Update')
try{
 function ReadXml($part){$rd=[IO.StreamReader]::new($z.GetEntry($part).Open());try{return ,([xml]$rd.ReadToEnd())}finally{$rd.Dispose()}}
 function SaveXml($part,$xml){$s=$z.GetEntry($part).Open();$s.SetLength(0);$wr=[IO.StreamWriter]::new($s,[Text.UTF8Encoding]::new($false));try{$xml.Save($wr)}finally{$wr.Dispose()}}
 function Binary($part,$file){$old=$z.GetEntry($part);if($old){$old.Delete()};$s=$z.CreateEntry($part).Open();try{$b=[IO.File]::ReadAllBytes($file);$s.Write($b,0,$b.Length)}finally{$s.Dispose()}}
 $d=ReadXml 'word/document.xml';$rels=ReadXml 'word/_rels/document.xml.rels'
 $w='http://schemas.openxmlformats.org/wordprocessingml/2006/main';$a='http://schemas.openxmlformats.org/drawingml/2006/main';$r='http://schemas.openxmlformats.org/officeDocument/2006/relationships'
 $n=[Xml.XmlNamespaceManager]::new($d.NameTable);$n.AddNamespace('w',$w);$n.AddNamespace('a',$a);$n.AddNamespace('r',$r);$n.AddNamespace('wp','http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing')
 function Txt($p){($p.SelectNodes('.//w:t',$n)|ForEach-Object InnerText)-join ''}
 function Put($p,$t){$ts=$p.SelectNodes('.//w:t',$n);$ts[0].InnerText=$t;foreach($v in @($ts|Select-Object -Skip 1)){$v.InnerText=''}}
 $body=$d.SelectSingleNode('//w:body',$n);$paras=@($body.SelectNodes('w:p',$n));$heading=@($paras|Where-Object {(Txt $_).Trim() -eq 'Data Flow Diagram'})[0];$caption=@($paras|Where-Object {(Txt $_).Trim() -match '^Figure 3'})[0]
 if(-not $heading -or -not $caption){throw 'DFD boundary missing'}
 $between=[Collections.Generic.List[object]]::new();$p=$heading.NextSibling;while($p -and -not [object]::ReferenceEquals($p,$caption)){$between.Add($p);$p=$p.NextSibling}
 if(-not $p){throw 'Caption order mismatch'}
 $picture=@($between|Where-Object {$_.SelectSingleNode('.//a:blip',$n)})[0];if(-not $picture){throw 'DFD image missing'}
 foreach($old in $between){if(-not [object]::ReferenceEquals($old,$picture)){$null=$body.RemoveChild($old)}}
 $blip=$picture.SelectSingleNode('.//a:blip',$n);$rid=$blip.GetAttribute('embed',$r);$rel=@($rels.DocumentElement.ChildNodes|Where-Object Id -eq $rid)[0];$rel.SetAttribute('Target','media/summary-dfd.png')
 Binary 'word/media/summary-dfd.png' (Join-Path $root 'Chapter 3 Diagrams/_Sources/03-dfd-word-fallback.png')
 Binary 'word/media/summary-dfd.svg' (Join-Path $root 'Chapter 3 Diagrams/03-dfd-simple.svg')
 $svgRid='rIdSummaryDFDSVG';$sr=@($rels.DocumentElement.ChildNodes|Where-Object Id -eq $svgRid)
 if(-not $sr){$sr=$rels.CreateElement('Relationship',$rels.DocumentElement.NamespaceURI);$sr.SetAttribute('Id',$svgRid);$sr.SetAttribute('Type',$r+'/image');$sr.SetAttribute('Target','media/summary-dfd.svg');$null=$rels.DocumentElement.AppendChild($sr)}
 $list=$blip.SelectSingleNode('a:extLst',$n);if(-not $list){$list=$d.CreateElement('a','extLst',$a);$null=$blip.AppendChild($list)}
 $ext=$d.CreateElement('a','ext',$a);$ext.SetAttribute('uri','{96DAC541-7B7A-43D3-8B79-37D633B846F1}');$sb=$d.CreateElement('asvg','svgBlip','http://schemas.microsoft.com/office/drawing/2016/SVG/main');$null=$sb.SetAttribute('embed',$r,$svgRid);$null=$ext.AppendChild($sb);$null=$list.AppendChild($ext)
 $cx=[long](5.8*914400);$cy=[long]($cx*3300/2400);foreach($e in $picture.SelectNodes('.//wp:extent|.//a:xfrm/a:ext',$n)){$e.SetAttribute('cx',"$cx");$e.SetAttribute('cy',"$cy")}
 foreach($item in @($heading,$picture,$caption)){
  $pr=$item.SelectSingleNode('w:pPr',$n);if(-not $pr){$pr=$d.CreateElement('w','pPr',$w);$null=$item.PrependChild($pr)}
  foreach($old in @($pr.SelectNodes('w:pageBreakBefore|w:keepNext',$n))){$null=$pr.RemoveChild($old)}
  if(-not [object]::ReferenceEquals($item,$caption)){$null=$pr.AppendChild($d.CreateElement('w','keepNext',$w))}
  $spacing=$pr.SelectSingleNode('w:spacing',$n);if(-not $spacing){$spacing=$d.CreateElement('w','spacing',$w);$null=$pr.AppendChild($spacing)};foreach($att in @('before','after')){$null=$spacing.SetAttribute($att,$w,'0')}
 }
 $pp=$heading.SelectSingleNode('w:pPr',$n);$null=$pp.AppendChild($d.CreateElement('w','pageBreakBefore',$w))
 Put $caption 'Figure 3. Summary Level 1 Data Flow Diagram - Gane-Sarson'
 foreach($p in $body.SelectNodes('w:p',$n)){$t=(Txt $p).Trim()
  if($t.StartsWith('Figure 3a-e expands') -or $t.StartsWith('Figure 3 summarizes')){Put $p 'Figure 3 summarizes the context process as nine numbered functions in a single diagram. The center column contains processes 1.0 through 9.0, grouped existing data stores appear on the left, and the relevant external user groups appear on the right. Horizontal connectors reach the corresponding process and store or actor group directly, eliminating crossings. This is a summary presentation of the Level 1 model: related exchanges are combined into eighteen connectors, while the process descriptions below retain the detailed inputs, outputs, affected records, and role restrictions. The vertical placement organizes the figure and does not prescribe an execution sequence.'}
  elseif($t.StartsWith('Reading the actor, process, and store together')){Put $p 'Reading each row identifies the function, the users involved, and the information retrieved or recorded. A connector with arrowheads at both ends summarizes separate input and output directions; it does not indicate that identical information is sent in both directions. The reporting and log-viewing store connectors point only toward their processes because those functions retrieve existing records. The rectangles may list several participating roles to reduce repeated lines. Their inclusion does not give every listed role every capability named in the row. For example, a member submits an application while an administrator or authorized staff member reviews it; a member reads their own attendance while an authorized operator records a scan. Likewise, members and staff may read a permitted catalog, but only administrators maintain inventory.'}
  elseif($t.StartsWith('Store identifiers remain consistent')){Put $p 'Store identifiers remain consistent with the detailed model. D0 represents managed Auth accounts, D1 profiles, D2 membership applications, D3 members, D4 attendance, D5 products, D6 sales, D7 sale items, D8 membership history, and D9 activity logs. D10 represents mobile pairing policy, D11 scanner pairing sessions, D13 private attendance scan requests, and D14 private account sessions. D12 is reserved for the retained scan-event table and is not presented as an active frontend feature. A grouped store symbol lists the existing sources used by that process; it does not create an additional physical table. D2-D8 in reporting denotes the operational source stores. A two-way connector to a group means that the process reads some records and writes the applicable records, not that it writes to every table in the group. Detailed effects are described for each process and the actual tables are defined in the ERD and data dictionary.'}
 }
 SaveXml 'word/document.xml' $d;SaveXml 'word/_rels/document.xml.rels' $rels
}finally{$z.Dispose()}
$lock=[IO.File]::Open($path,'Open','ReadWrite','None');$lock.Dispose();Copy-Item -LiteralPath $work -Destination $path -Force
'Inserted the single summary DFD with SVG and PNG fallback; updated its interpretation while preserving all nine detailed process explanations.'
