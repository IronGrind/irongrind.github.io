param([string]$DocumentPath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'Chapter 3.docx'))
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=Split-Path $PSScriptRoot -Parent;$path=$DocumentPath
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
 Binary 'word/media/summary-dfd.png' (Join-Path $root 'Chapter 3 Diagrams/03-dfd-overview.png')
 foreach($old in @($blip.SelectNodes('a:extLst/a:ext[@uri="{96DAC541-7B7A-43D3-8B79-37D633B846F1}"]',$n))){$null=$old.ParentNode.RemoveChild($old)}
 $svgRid='rIdSummaryDFDSVG';foreach($oldRel in @($rels.DocumentElement.ChildNodes|Where-Object Id -eq $svgRid)){$null=$rels.DocumentElement.RemoveChild($oldRel)}
 $cx=[long](8.8*914400);$cy=[long]($cx*1240/1800);foreach($e in $picture.SelectNodes('.//wp:extent|.//a:xfrm/a:ext',$n)){$e.SetAttribute('cx',"$cx");$e.SetAttribute('cy',"$cy")}
 function Section($landscape){
  $s=$d.SelectSingleNode('//w:body/w:sectPr',$n).CloneNode($true)
  $type=$s.SelectSingleNode('w:type',$n);if(-not $type){$type=$d.CreateElement('w','type',$w);$null=$s.InsertBefore($type,$s.SelectSingleNode('w:pgSz',$n))};$null=$type.SetAttribute('val',$w,'nextPage')
  if($landscape){$size=$s.SelectSingleNode('w:pgSz',$n);$null=$size.SetAttribute('w',$w,'15840');$null=$size.SetAttribute('h',$w,'12240');$null=$size.SetAttribute('orient',$w,'landscape');$m=$s.SelectSingleNode('w:pgMar',$n);foreach($a in @('top','bottom','left','right')){$null=$m.SetAttribute($a,$w,'720')}}
  return ,$s
 }
 $boundary=$heading.PreviousSibling
 if(-not $boundary -or -not $boundary.SelectSingleNode('w:bookmarkStart[@w:name="_SummaryDFDSection"]',$n)){
  $boundary=$d.CreateElement('w','p',$w);$pr=$d.CreateElement('w','pPr',$w);$sp=$d.CreateElement('w','spacing',$w);$null=$sp.SetAttribute('line',$w,'1');$null=$sp.SetAttribute('lineRule',$w,'exact');$null=$sp.SetAttribute('before',$w,'0');$null=$sp.SetAttribute('after',$w,'0');$null=$pr.AppendChild($sp);$null=$pr.AppendChild((Section $false));$null=$boundary.AppendChild($pr)
  $max=@($d.SelectNodes('//w:bookmarkStart',$n)|ForEach-Object {[int]$_.GetAttribute('id',$w)}|Measure-Object -Maximum)[0].Maximum;$id=[int]$max+1
  foreach($kind in @('bookmarkStart','bookmarkEnd')){$bm=$d.CreateElement('w',$kind,$w);$null=$bm.SetAttribute('id',$w,[string]$id);if($kind -eq 'bookmarkStart'){$null=$bm.SetAttribute('name',$w,'_SummaryDFDSection')};$null=$boundary.AppendChild($bm)}
  $null=$body.InsertBefore($boundary,$heading)
 }
 foreach($item in @($heading,$picture,$caption)){
  $pr=$item.SelectSingleNode('w:pPr',$n);if(-not $pr){$pr=$d.CreateElement('w','pPr',$w);$null=$item.PrependChild($pr)}
  foreach($old in @($pr.SelectNodes('w:pageBreakBefore|w:keepNext',$n))){$null=$pr.RemoveChild($old)}
  if(-not [object]::ReferenceEquals($item,$caption)){$null=$pr.AppendChild($d.CreateElement('w','keepNext',$w))}
  $spacing=$pr.SelectSingleNode('w:spacing',$n);if(-not $spacing){$spacing=$d.CreateElement('w','spacing',$w);$null=$pr.AppendChild($spacing)};foreach($att in @('before','after')){$null=$spacing.SetAttribute($att,$w,'0')}
 }
 $cp=$caption.SelectSingleNode('w:pPr',$n);foreach($old in @($cp.SelectNodes('w:sectPr',$n))){$null=$cp.RemoveChild($old)};$null=$cp.AppendChild((Section $true))
 foreach($item in @($picture,$caption)){$pr=$item.SelectSingleNode('w:pPr',$n);$ind=$pr.SelectSingleNode('w:ind',$n);if(-not $ind){$ind=$d.CreateElement('w','ind',$w);$null=$pr.AppendChild($ind)};foreach($att in @('left','right','firstLine')){$null=$ind.SetAttribute($att,$w,'0')};$jc=$pr.SelectSingleNode('w:jc',$n);if(-not $jc){$jc=$d.CreateElement('w','jc',$w);$null=$pr.AppendChild($jc)};$null=$jc.SetAttribute('val',$w,'center')}
 Put $caption 'Figure 3. Simplified Data Flow Overview - Gane-Sarson'
 foreach($p in $body.SelectNodes('w:p',$n)){$t=(Txt $p).Trim()
  if($t.StartsWith('Figure 3a-e expands') -or $t.StartsWith('Figure 3 summarizes')){Put $p 'This simplified overview groups the nine system functions into access and accounts, membership, gym operations, and oversight. The three actor cards summarize the information each role submits and receives. The lower band groups related records to make the main path easy to follow; these are logical categories, not combined physical tables. The detailed DFD panels that follow preserve every individually named data store and the specific flows between actors, processes, and stores.'}
  elseif($t.StartsWith('Reading the actor, process, and store together') -or $t.StartsWith('Reading each row identifies')){Put $p 'Read the overview from top to bottom: members/applicants, authorized staff, and administrators exchange requests and results with the system; its nine functions are arranged into four areas; the functions read or save persistent records. The grouped records are expanded into individually identified stores in the detailed DFD. The roles do not share identical permissions: members view their own attendance, authorized operators record scans, and inventory changes remain an administrator responsibility.'}
  elseif($t.StartsWith('Store identifiers remain consistent')){Put $p 'Store identifiers remain consistent with the detailed model. D0 represents auth.users, D1 profiles, D2 membership_applications, D3 members, D4 attendance, D5 products, D6 sales, D7 sale_items, D8 membership_history, and D9 activity_logs. D10 represents mobile_attendance_pairing_policy, D11 mobile_attendance_scan_sessions, D13 private.attendance_scan_requests, and D14 private.account_sessions. Each is drawn independently with its own identifier and store name. Report generation has separate incoming connections from D2, D3, D4, D5, D6, D7, and D8, rather than a combined report-source store. D12 remains reserved for the retained scan-event table and is not shown as an active frontend process dependency. A DFD describes the records used by its functional processes; it is not a requirement to reproduce every physical or internal security table. The complete application schema, including supporting tables outside this functional view, remains documented in the ERD scope and data dictionary. A two-way connector refers only to the labeled process and its one individual store, and the process explanations distinguish the information read from the information written.'}
 }
 $info=$picture.SelectSingleNode('.//wp:docPr',$n);$info.SetAttribute('name','Simplified data flow overview');$info.SetAttribute('descr','Three actor groups exchange requests and results with the Iron Grind system. Nine functions are grouped into four areas and connect to five logical record categories; detailed DFD panels name each physical data store.')
 $propertyOrder=@('pStyle','keepNext','keepLines','pageBreakBefore','framePr','widowControl','numPr','suppressLineNumbers','pBdr','shd','tabs','suppressAutoHyphens','kinsoku','wordWrap','overflowPunct','topLinePunct','autoSpaceDE','autoSpaceDN','bidi','adjustRightInd','snapToGrid','spacing','ind','contextualSpacing','mirrorIndents','suppressOverlap','jc','textDirection','textAlignment','textboxTightWrap','outlineLvl','divId','cnfStyle','rPr','sectPr','pPrChange')
 foreach($p in @($heading,$picture,$caption,$boundary)){$pr=$p.SelectSingleNode('w:pPr',$n);foreach($child in @($pr.ChildNodes|Sort-Object {$idx=[Array]::IndexOf($propertyOrder,$_.LocalName);if($idx -lt 0){32}else{$idx}})){$null=$pr.AppendChild($child)}}
 SaveXml 'word/document.xml' $d;SaveXml 'word/_rels/document.xml.rels' $rels
}finally{$z.Dispose()}
$lock=[IO.File]::Open($path,'Open','ReadWrite','None');$lock.Dispose();Copy-Item -LiteralPath $work -Destination $path -Force
'Inserted the simplified DFD overview PNG; retained the detailed individual-store DFD panels and updated the interpretation.'
