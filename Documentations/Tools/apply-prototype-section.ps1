param([string]$DocumentPath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'Chapter 3.docx'))
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=Split-Path $PSScriptRoot -Parent
$assets=Join-Path $root 'Prototype Screenshots'
$model=Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $assets '_Sources/prototype-layout.json')|ConvertFrom-Json
if($model.SourceCount -ne 27 -or $model.MainFigureCount -ne 27){throw 'Unexpected screenshot coverage'}
$backup=Join-Path $root ('Review Backups/prototype-'+(Get-Date -Format yyyyMMdd-HHmmss))
New-Item -ItemType Directory -Path $backup -Force|Out-Null
Copy-Item -LiteralPath $DocumentPath -Destination (Join-Path $backup 'Chapter 3.docx')
$work=Join-Path $backup 'Chapter 3 working.docx';Copy-Item -LiteralPath $DocumentPath -Destination $work
$zip=[IO.Compression.ZipFile]::Open($work,'Update')
try{
 function ReadXml($part){$reader=[IO.StreamReader]::new($zip.GetEntry($part).Open());try{return ,([xml]$reader.ReadToEnd())}finally{$reader.Dispose()}}
 function SaveXml($part,$xml){$entry=$zip.GetEntry($part);if(-not $entry){$entry=$zip.CreateEntry($part)};$s=$entry.Open();$s.SetLength(0);$writer=[IO.StreamWriter]::new($s,[Text.UTF8Encoding]::new($false));try{$xml.Save($writer)}finally{$writer.Dispose()}}
 function Binary($part,$file){$entry=$zip.GetEntry($part);if($entry){$entry.Delete()};$s=$zip.CreateEntry($part).Open();try{$bytes=[IO.File]::ReadAllBytes($file);$s.Write($bytes,0,$bytes.Length)}finally{$s.Dispose()}}
 $doc=ReadXml 'word/document.xml';$rels=ReadXml 'word/_rels/document.xml.rels';$ct=ReadXml '[Content_Types].xml'
 $w='http://schemas.openxmlformats.org/wordprocessingml/2006/main';$a='http://schemas.openxmlformats.org/drawingml/2006/main';$r='http://schemas.openxmlformats.org/officeDocument/2006/relationships'
 $ns=[Xml.XmlNamespaceManager]::new($doc.NameTable);$ns.AddNamespace('w',$w);$ns.AddNamespace('a',$a);$ns.AddNamespace('r',$r);$ns.AddNamespace('wp','http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing')
 function Txt($node){($node.SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join ''}
 function Attr($node,$name,$value){$null=$node.SetAttribute($name,$w,[string]$value)}
 function Put($p,$text){$ts=$p.SelectNodes('.//w:t',$ns);$ts[0].InnerText=$text;foreach($t in @($ts|Select-Object -Skip 1)){$t.InnerText=''}}
 $body=$doc.SelectSingleNode('//w:body',$ns);$paras=@($body.SelectNodes('w:p',$ns));$forms=@($paras|Where-Object {(Txt $_).Trim() -eq 'Forms'})
 $gantt=@($paras|Where-Object {(Txt $_).Trim() -eq 'Gantt Chart'})
 if($forms.Count -ne 1 -or $gantt.Count -ne 1){throw 'Cannot identify Forms/Gantt boundaries'}
 $heading=$forms[0].NextSibling;while($heading -and (Txt $heading).Trim() -ne 'Prototype'){$heading=$heading.NextSibling}
 if(-not $heading){throw 'Prototype heading missing'}
 $old=[Collections.Generic.List[object]]::new();$node=$heading.NextSibling
 while($node -and -not [object]::ReferenceEquals($node,$gantt[0])){if($node.LocalName -ne 'p' -or $node.SelectSingleNode('w:pPr/w:sectPr',$ns)){throw 'Unexpected prototype section content'};$old.Add($node);$node=$node.NextSibling}
 if(-not $node){throw 'Prototype/Gantt ordering mismatch'}
 $pictureTemplate=@($old|Where-Object {$_.SelectSingleNode('.//a:blip',$ns)})[0]
 if(-not $pictureTemplate -or $pictureTemplate.SelectNodes('.//a:blip',$ns).Count -ne 1){throw 'Expected a single-image picture template'}
 $tablesBefore=(@($doc.SelectNodes('//w:tbl',$ns)|ForEach-Object OuterXml))-join ''
 $nextDrawingId=[int](@($doc.SelectNodes('//wp:docPr',$ns)|ForEach-Object {[int]$_.GetAttribute('id')}|Measure-Object -Maximum)[0].Maximum)+1
 function Paragraph($text,$kind='body',$pageBreak=$false,$keepNext=$false){
  $p=$doc.CreateElement('w','p',$w);$pr=$doc.CreateElement('w','pPr',$w)
  if($kind -eq 'heading'){$style=$doc.CreateElement('w','pStyle',$w);Attr $style 'val' 'Heading3';$null=$pr.AppendChild($style)}
  if($keepNext){$null=$pr.AppendChild($doc.CreateElement('w','keepNext',$w))}
  $null=$pr.AppendChild($doc.CreateElement('w','keepLines',$w))
  if($pageBreak){$null=$pr.AppendChild($doc.CreateElement('w','pageBreakBefore',$w))}
  $spacing=$doc.CreateElement('w','spacing',$w);Attr $spacing 'before' 0;Attr $spacing 'after' $(if($kind -eq 'heading'){120}else{80});Attr $spacing 'line' $(if($kind -eq 'body'){480}else{240});Attr $spacing 'lineRule' 'auto';$null=$pr.AppendChild($spacing)
  $ind=$doc.CreateElement('w','ind',$w);Attr $ind 'left' 0;Attr $ind 'right' 0;Attr $ind 'firstLine' $(if($kind -eq 'body'){720}else{0});$null=$pr.AppendChild($ind)
  $jc=$doc.CreateElement('w','jc',$w);Attr $jc 'val' $(if($kind -eq 'caption'){'center'}elseif($kind -eq 'heading'){'left'}else{'both'});$null=$pr.AppendChild($jc);$null=$p.AppendChild($pr)
  $run=$doc.CreateElement('w','r',$w);$rp=$doc.CreateElement('w','rPr',$w);$fonts=$doc.CreateElement('w','rFonts',$w);foreach($key in @('ascii','hAnsi','cs','eastAsia')){Attr $fonts $key 'Times New Roman'};$null=$rp.AppendChild($fonts);$sz=$doc.CreateElement('w','sz',$w);Attr $sz 'val' 24;$null=$rp.AppendChild($sz);$null=$run.AppendChild($rp)
  $t=$doc.CreateElement('w','t',$w);$t.InnerText=$text;$null=$run.AppendChild($t);$null=$p.AppendChild($run);return ,$p
 }
 function Insert($node){$null=$body.InsertBefore($node,$gantt[0])}
 Insert (Paragraph 'The following figures present complete browser-interface captures for IronGrind, organized by access, administrator, staff, member, and session workflows. Each main figure preserves the whole original screenshot and its layout. Supplementary enlarged details are provided only for three long registration forms. The screenshots illustrate captured interface states; operational permissions follow the functional requirements, use cases, and workflow descriptions.')
 $currentSection=-1;$imageCount=0
 foreach($f in $model.Figures){
  $firstInSection=$currentSection -ne $f.Section
  if($firstInSection){
   $currentSection=$f.Section;$section=@($model.Sections|Where-Object Id -eq $currentSection)[0]
   Insert (Paragraph $section.Name 'heading' ($currentSection -ne 0) $true)
   if($currentSection -ne 0){Insert (Paragraph $section.Introduction 'body' $false $true)}
  }
  $label=$f.Number.ToString('00')+$f.Suffix;$rid='rIdPrototype'+$label;$target='media/prototype-'+$label+'.png'
  Binary ('word/'+$target) $f.ImagePath
  $rel=@($rels.DocumentElement.ChildNodes|Where-Object Id -eq $rid)
  if($rel.Count -gt 1){throw 'Duplicate relationship ID'}
  if(-not $rel){$rel=$rels.CreateElement('Relationship',$rels.DocumentElement.NamespaceURI);$rel.SetAttribute('Id',$rid);$rel.SetAttribute('Type',$r+'/image');$null=$rels.DocumentElement.AppendChild($rel)}
  $rel.SetAttribute('Target',$target)
  $pic=$pictureTemplate.CloneNode($true)
  foreach($bm in @($pic.SelectNodes('.//w:bookmarkStart|.//w:bookmarkEnd|.//w:lastRenderedPageBreak',$ns))){$null=$bm.ParentNode.RemoveChild($bm)}
  $blip=$pic.SelectSingleNode('.//a:blip',$ns);$null=$blip.SetAttribute('embed',$r,$rid)
  foreach($ext in @($blip.SelectNodes('a:extLst/a:ext[@uri="{96DAC541-7B7A-43D3-8B79-37D633B846F1}"]',$ns))){$null=$ext.ParentNode.RemoveChild($ext)}
  foreach($crop in @($pic.SelectNodes('.//a:srcRect',$ns))){$null=$crop.ParentNode.RemoveChild($crop)}
  $maxWidth=if($f.Width -lt 300){3.0}elseif($f.SourceId -eq 15){4.8}else{6.2}
  $maxHeight=if($firstInSection){4.5}else{5.0}
  $width=[Math]::Min($maxWidth,$maxHeight*$f.Width/$f.Height);$height=$width*$f.Height/$f.Width
  $cx=[long]($width*914400);$cy=[long]($height*914400)
  foreach($ext in $pic.SelectNodes('.//wp:extent|.//a:xfrm/a:ext',$ns)){$ext.SetAttribute('cx',"$cx");$ext.SetAttribute('cy',"$cy")}
  $dp=$pic.SelectSingleNode('.//wp:docPr',$ns);$dp.SetAttribute('id',[string]$nextDrawingId);$nextDrawingId++;$dp.SetAttribute('name','Prototype '+$f.Label);$dp.SetAttribute('descr',$f.Caption+'; supplied screenshot '+$f.SourceId+'.')
  $oldPr=$pic.SelectSingleNode('w:pPr',$ns);$pr=$doc.CreateElement('w','pPr',$w);$null=$pr.AppendChild($doc.CreateElement('w','keepNext',$w));$null=$pr.AppendChild($doc.CreateElement('w','keepLines',$w))
  if(-not $firstInSection){$null=$pr.AppendChild($doc.CreateElement('w','pageBreakBefore',$w))}
  $spacing=$doc.CreateElement('w','spacing',$w);Attr $spacing 'before' 0;Attr $spacing 'after' 80;Attr $spacing 'line' 240;Attr $spacing 'lineRule' 'auto';$null=$pr.AppendChild($spacing)
  $ind=$doc.CreateElement('w','ind',$w);foreach($key in @('left','right','firstLine')){Attr $ind $key 0};$null=$pr.AppendChild($ind);$jc=$doc.CreateElement('w','jc',$w);Attr $jc 'val' 'center';$null=$pr.AppendChild($jc)
  if($oldPr){$null=$pic.ReplaceChild($pr,$oldPr)}else{$null=$pic.PrependChild($pr)}
  Insert $pic;Insert (Paragraph $f.Caption 'caption' $false $true);Insert (Paragraph $f.Description)
  $imageCount++
 }
 foreach($node in $old){$null=$body.RemoveChild($node)}
 if($imageCount -ne $model.Figures.Count){throw 'Missing screenshot part'}
 # Renumber only the following schedule caption/references, preserving its chart and dates.
 $node=$gantt[0].NextSibling;$renumbered=0
 while($node -and (Txt $node).Trim() -ne 'REFERENCES'){
  $text=Txt $node
  if($text -match '^Figure (21|33)\.'){Put $node 'Figure 33. Gantt Chart';$renumbered++}
  elseif($text -match 'Figure 21\b'){Put $node ($text -replace 'Figure 21\b','Figure 33')}
  $node=$node.NextSibling
 }
 if($renumbered -ne 1){throw 'Unexpected Gantt caption count'}
 # Align two general statements with the supplied captures; retain verification limits.
 foreach($p in $body.SelectNodes('w:p',$ns)){
  $text=Txt $p
  if($text.StartsWith('Successful physical multi-phone operation')){Put $p 'Successful physical multi-phone operation and complete visual browser behavior require separate recorded validation. The available automated artifacts do not establish completion of that end-to-end validation. The prototype figures document supplied browser-interface captures and role-specific controls; they do not, by themselves, establish the current production deployment state, successful physical camera operation, or measured usability. Formal usability or stakeholder-evaluation results should be reported only after the corresponding evaluation has been conducted and documented.'}
  elseif($text.StartsWith('4. Counter and attendance operations.')){Put $p ($text.Replace('enters the separate name fields and membership details','enters the member name and membership details'))}
 }
 if($tablesBefore -cne ((@($doc.SelectNodes('//w:tbl',$ns)|ForEach-Object OuterXml))-join '')){throw 'Requirements or dictionary tables changed'}
 if(-not @($ct.DocumentElement.ChildNodes|Where-Object Extension -eq 'png')){$type=$ct.CreateElement('Default',$ct.DocumentElement.NamespaceURI);$type.SetAttribute('Extension','png');$type.SetAttribute('ContentType','image/png');$null=$ct.DocumentElement.AppendChild($type)}
 SaveXml 'word/document.xml' $doc;SaveXml 'word/_rels/document.xml.rels' $rels;SaveXml '[Content_Types].xml' $ct
}finally{$zip.Dispose()}
& (Join-Path $PSScriptRoot 'verify-chapters.ps1') -Chapters 3 -DocumentPath $work
& (Join-Path $PSScriptRoot 'verify-prototype-section.ps1') -DocumentPath $work
$lock=[IO.File]::Open($DocumentPath,'Open','ReadWrite','None');$lock.Dispose()
Copy-Item -LiteralPath $work -Destination $DocumentPath -Force
"Updated Chapter 3: 27 whole-screenshot main figures and 8 selected enlarged details, Figures 6-32; Gantt remains Figure 33. Backup: $backup"
