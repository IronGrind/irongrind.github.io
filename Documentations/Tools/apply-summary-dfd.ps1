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
 Binary 'word/media/summary-dfd.png' (Join-Path $root 'Chapter 3 Diagrams/_Sources/03-dfd-word-fallback.png')
 Binary 'word/media/summary-dfd.svg' (Join-Path $root 'Chapter 3 Diagrams/03-dfd-simple.svg')
 $svgRid='rIdSummaryDFDSVG';$sr=@($rels.DocumentElement.ChildNodes|Where-Object Id -eq $svgRid)
 if(-not $sr){$sr=$rels.CreateElement('Relationship',$rels.DocumentElement.NamespaceURI);$sr.SetAttribute('Id',$svgRid);$sr.SetAttribute('Type',$r+'/image');$sr.SetAttribute('Target','media/summary-dfd.svg');$null=$rels.DocumentElement.AppendChild($sr)}
 foreach($old in @($blip.SelectNodes('a:extLst/a:ext[@uri="{96DAC541-7B7A-43D3-8B79-37D633B846F1}"]',$n))){$null=$old.ParentNode.RemoveChild($old)}
 $list=$blip.SelectSingleNode('a:extLst',$n);if(-not $list){$list=$d.CreateElement('a','extLst',$a);$null=$blip.AppendChild($list)}
 $ext=$d.CreateElement('a','ext',$a);$ext.SetAttribute('uri','{96DAC541-7B7A-43D3-8B79-37D633B846F1}');$sb=$d.CreateElement('asvg','svgBlip','http://schemas.microsoft.com/office/drawing/2016/SVG/main');$null=$sb.SetAttribute('embed',$r,$svgRid);$null=$ext.AppendChild($sb);$null=$list.AppendChild($ext)
 $svg=[xml](Get-Content -Raw -LiteralPath (Join-Path $root 'Chapter 3 Diagrams/03-dfd-simple.svg'))
 $view=@($svg.DocumentElement.GetAttribute('viewBox') -split '\s+'|ForEach-Object {[double]$_})
 $cx=[long](8.8*914400);$cy=[long]($cx*$view[3]/$view[2]);foreach($e in $picture.SelectNodes('.//wp:extent|.//a:xfrm/a:ext',$n)){$e.SetAttribute('cx',"$cx");$e.SetAttribute('cy',"$cy")}
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
 Put $caption 'Figure 3. Summary Level 1 Data Flow Diagram - Gane-Sarson'
 foreach($p in $body.SelectNodes('w:p',$n)){$t=(Txt $p).Trim()
  if($t.StartsWith('Figure 3a-e expands') -or $t.StartsWith('Figure 3 summarizes')){Put $p 'Figure 3 summarizes the context process as nine numbered functions in one Level 1 overview. Processes 1.0 through 9.0 form the center column. Fourteen individual data stores appear on the left, while Member / Applicant, Authorized Staff, and Administrator each appear once on the right. Every data store has its own symbol, identifier, and name. Routed connectors identify the specific store or actor participating in each exchange; separate physical stores are not combined into a single symbol. The figure uses sixty-five connectors: forty-three connect functions and individual stores, and twenty-two connect functions and external actors. Related input/output directions for the same pair may share a two-headed connector, while their detailed records and permissions are explained below. Vertical placement organizes the diagram and does not prescribe execution order.'}
  elseif($t.StartsWith('Reading the actor, process, and store together') -or $t.StartsWith('Reading each row identifies')){Put $p 'Reading a process together with its labeled connections identifies who supplies or receives information and which records the function retrieves or changes. A connector with arrowheads at both ends summarizes distinct input/output or read/write directions; it does not mean that the same data travels both ways. A single arrowhead retains a one-way exchange: operational events flow toward the activity-log store, while report source data and filtered log data flow toward their reading processes. Small line bridges distinguish crossings from junctions, so a crossing does not combine the data on the two connectors. Each user group remains subject to its own permissions. For example, a member submits an application while an administrator or authorized staff member reviews it; a member reads their own attendance while an authorized operator records a scan. Members and staff may read the permitted product catalog, while inventory changes remain an administrator responsibility.'}
  elseif($t.StartsWith('Store identifiers remain consistent')){Put $p 'Store identifiers remain consistent with the detailed model. D0 represents auth.users, D1 profiles, D2 membership_applications, D3 members, D4 attendance, D5 products, D6 sales, D7 sale_items, D8 membership_history, and D9 activity_logs. D10 represents mobile_attendance_pairing_policy, D11 mobile_attendance_scan_sessions, D13 private.attendance_scan_requests, and D14 private.account_sessions. Each is drawn independently with its own identifier and store name. Report generation has separate incoming connections from D2, D3, D4, D5, D6, D7, and D8, rather than a combined report-source store. D12 remains reserved for the retained scan-event table and is not shown as an active frontend process dependency. A DFD describes the records used by its functional processes; it is not a requirement to reproduce every physical or internal security table. The complete application schema, including supporting tables outside this functional view, remains documented in the ERD scope and data dictionary. A two-way connector refers only to the labeled process and its one individual store, and the process explanations distinguish the information read from the information written.'}
 }
 $info=$picture.SelectSingleNode('.//wp:docPr',$n);$info.SetAttribute('name','Nine-function DFD');$info.SetAttribute('descr','Nine processes connected to fourteen individually identified data stores and three external actors. Separate store connections include all seven report sources; bridge arcs distinguish crossings.')
 $propertyOrder=@('pStyle','keepNext','keepLines','pageBreakBefore','framePr','widowControl','numPr','suppressLineNumbers','pBdr','shd','tabs','suppressAutoHyphens','kinsoku','wordWrap','overflowPunct','topLinePunct','autoSpaceDE','autoSpaceDN','bidi','adjustRightInd','snapToGrid','spacing','ind','contextualSpacing','mirrorIndents','suppressOverlap','jc','textDirection','textAlignment','textboxTightWrap','outlineLvl','divId','cnfStyle','rPr','sectPr','pPrChange')
 foreach($p in @($heading,$picture,$caption,$boundary)){$pr=$p.SelectSingleNode('w:pPr',$n);foreach($child in @($pr.ChildNodes|Sort-Object {$idx=[Array]::IndexOf($propertyOrder,$_.LocalName);if($idx -lt 0){32}else{$idx}})){$null=$pr.AppendChild($child)}}
 SaveXml 'word/document.xml' $d;SaveXml 'word/_rels/document.xml.rels' $rels
}finally{$z.Dispose()}
$lock=[IO.File]::Open($path,'Open','ReadWrite','None');$lock.Dispose();Copy-Item -LiteralPath $work -Destination $path -Force
'Inserted the single summary DFD with SVG and PNG fallback; updated its interpretation while preserving all nine detailed process explanations.'
