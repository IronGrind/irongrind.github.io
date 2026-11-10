$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=Split-Path $PSScriptRoot -Parent
$snapshot=Get-ChildItem (Join-Path $root 'Review Backups') -Directory -Filter 'combined-chapters-*'|Sort-Object Name -Descending|Select-Object -First 1
if(-not $snapshot){throw 'Input snapshots are required.'}
$output=Join-Path $root 'Chapters 1-3 with Table of Contents.docx'
$stage=Join-Path $snapshot.FullName 'Combined staged.docx'
Copy-Item -LiteralPath (Join-Path $snapshot.FullName 'Chapter 1.docx') -Destination $stage -Force
$w='http://schemas.openxmlformats.org/wordprocessingml/2006/main';$r='http://schemas.openxmlformats.org/officeDocument/2006/relationships';$a='http://schemas.openxmlformats.org/drawingml/2006/main'
function LoadXml($archive,$name){$sr=[IO.StreamReader]::new($archive.GetEntry($name).Open());try{$x=[Xml.XmlDocument]::new();$x.PreserveWhitespace=$true;$x.LoadXml($sr.ReadToEnd());return ,$x}finally{$sr.Dispose()}}
function Ns($xml){$n=[Xml.XmlNamespaceManager]::new($xml.NameTable);$n.AddNamespace('w',$w);$n.AddNamespace('r',$r);$n.AddNamespace('a',$a);$n.AddNamespace('wp','http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing');return ,$n}
function Attr($node,$key,$value){[void]$node.SetAttribute($key,$w,[string]$value)}
function SaveXml($archive,$part,$xml){$e=$archive.GetEntry($part);if($e){$e.Delete()};$s=$archive.CreateEntry($part).Open();$writer=[IO.StreamWriter]::new($s,[Text.UTF8Encoding]::new($false));$xml.Save($writer);$writer.Dispose()}
function ResolvePart($base,$target){([uri]::new([uri]('https://package.invalid/'+$base),$target)).AbsolutePath.TrimStart('/')}
function RelativePart($base,$target){([uri]('https://package.invalid/'+$base)).MakeRelativeUri([uri]('https://package.invalid/'+$target)).ToString()}
function HashEntry($entry){$s=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create();try{[Convert]::ToBase64String($sha.ComputeHash($s))}finally{$s.Dispose();$sha.Dispose()}}
$zip=[IO.Compression.ZipFile]::Open($stage,'Update');$sourceArchives=[Collections.Generic.List[object]]::new();$headings=[Collections.Generic.List[object]]::new();$preservedMedia=0
try {
 $doc=LoadXml $zip 'word/document.xml';$ns=Ns $doc;$body=$doc.SelectSingleNode('//w:body',$ns)
 $rels=LoadXml $zip 'word/_rels/document.xml.rels';$styles=LoadXml $zip 'word/styles.xml';$numbering=LoadXml $zip 'word/numbering.xml';$types=LoadXml $zip '[Content_Types].xml'
 $primaryRelations=@{};foreach($rel in $rels.DocumentElement.ChildNodes){$primaryRelations[$rel.Type.Split('/')[-1]]=$rel.Id}
 function NewParagraph($value,$style='Normal'){
  $p=$doc.CreateElement('w','p',$w);$pr=$doc.CreateElement('w','pPr',$w);$ps=$doc.CreateElement('w','pStyle',$w);Attr $ps 'val' $style;[void]$pr.AppendChild($ps);$sp=$doc.CreateElement('w','spacing',$w);Attr $sp 'line' 360;Attr $sp 'lineRule' 'auto';[void]$pr.AppendChild($sp);[void]$p.AppendChild($pr);$run=$doc.CreateElement('w','r',$w);$rp=$doc.CreateElement('w','rPr',$w);$fonts=$doc.CreateElement('w','rFonts',$w);foreach($key in @('ascii','hAnsi','eastAsia','cs')){Attr $fonts $key 'Times New Roman'};[void]$rp.AppendChild($fonts);foreach($key in @('sz','szCs')){$size=$doc.CreateElement('w',$key,$w);Attr $size 'val' 24;[void]$rp.AppendChild($size)};[void]$run.AppendChild($rp);$text=$doc.CreateElement('w','t',$w);$text.InnerText=$value;[void]$run.AppendChild($text);[void]$p.AppendChild($run);return ,$p
 }
 function CloseSection(){
  $section=$body.SelectSingleNode('w:sectPr',$ns);if(-not $section){throw 'Missing final section'};[void]$body.RemoveChild($section)
  $break=$doc.CreateElement('w','p',$w);$pr=$doc.CreateElement('w','pPr',$w);$kind=$section.SelectSingleNode('w:type',$ns);if(-not $kind){$kind=$doc.CreateElement('w','type',$w);[void]$section.PrependChild($kind)};Attr $kind 'val' 'nextPage';[void]$pr.AppendChild($section);[void]$break.AppendChild($pr);[void]$body.AppendChild($break)
 }
 function MarkHeadings($container,$chapter){
  foreach($p in $container.SelectNodes('w:p',$ns)){$style=$p.SelectSingleNode('w:pPr/w:pStyle',$ns);if(-not $style){continue};$id=$style.GetAttribute('val',$w);if($id -notmatch '(?:^|_)Heading([123])$'){continue};$level=[int]$Matches[1];$text=($p.SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join '';if(-not $text.Trim()){continue};$bookmark='IGTOC_'+$chapter+'_'+$headings.Count;$start=$doc.CreateElement('w','bookmarkStart',$w);Attr $start 'id' (90000+$headings.Count);Attr $start 'name' $bookmark;$end=$doc.CreateElement('w','bookmarkEnd',$w);Attr $end 'id' (90000+$headings.Count);$first=$p.SelectSingleNode('w:r|w:hyperlink',$ns);if($first){[void]$p.InsertBefore($start,$first)}else{[void]$p.AppendChild($start)};[void]$p.AppendChild($end);$headings.Add([pscustomobject]@{Text=$text;Level=$level;Bookmark=$bookmark})}
 }
 MarkHeadings $body 1
 foreach($chapter in 2..3){
  $source=[IO.Compression.ZipFile]::OpenRead((Join-Path $snapshot.FullName "Chapter $chapter.docx"));$sourceArchives.Add($source)
  $incoming=LoadXml $source 'word/document.xml';$inn=Ns $incoming;$srcRels=LoadXml $source 'word/_rels/document.xml.rels';$srcStyles=LoadXml $source 'word/styles.xml';$srcNum=LoadXml $source 'word/numbering.xml';$srcTypes=LoadXml $source '[Content_Types].xml'
  if($incoming.SelectNodes('//w:footnoteReference|//w:endnoteReference',$inn).Count){throw 'Footnote merging requires explicit note ID mapping.'}
  if($srcNum.SelectNodes('//*[local-name()="numPicBullet"]').Count){throw 'Picture numbering needs an explicit relationship map.'}
  $map=@{};foreach($entry in $source.Entries){$map[$entry.FullName]="word/merge$chapter/"+$entry.FullName}
  foreach($global in @('document.xml','styles.xml','numbering.xml','settings.xml','fontTable.xml','webSettings.xml','footnotes.xml','endnotes.xml','theme/theme1.xml')){$map['word/'+$global]='word/'+$global}
  $ridMap=@{};foreach($rel in $srcRels.DocumentElement.ChildNodes){$kind=$rel.Type.Split('/')[-1];if($kind -in @('styles','numbering','settings','fontTable','webSettings','footnotes','endnotes','theme')){$ridMap[$rel.Id]=$primaryRelations[$kind];continue};$copy=$rels.ImportNode($rel,$true);$newId="c${chapter}_"+$rel.Id;$copy.SetAttribute('Id',$newId);$ridMap[$rel.Id]=$newId;if($rel.TargetMode -ne 'External'){$oldTarget=ResolvePart 'word/document.xml' $rel.Target;$copy.SetAttribute('Target',(RelativePart 'word/document.xml' $map[$oldTarget]))};[void]$rels.DocumentElement.AppendChild($copy)}
  $styleMap=@{};foreach($style in $srcStyles.SelectNodes('//w:style',(Ns $srcStyles))){$id=$style.GetAttribute('styleId',$w);$styleMap[$id]="C${chapter}_$id"}
  function Rewrite($xml,$main=$false){
   $n=Ns $xml
   foreach($node in $xml.SelectNodes('//w:pStyle|//w:rStyle|//w:tblStyle|//w:basedOn|//w:next|//w:link|//w:numStyleLink|//w:styleLink',$n)){$id=$node.GetAttribute('val',$w);if($styleMap.ContainsKey($id)){Attr $node 'val' $styleMap[$id]}}
   foreach($node in $xml.SelectNodes('//w:style',$n)){$old=$node.GetAttribute('styleId',$w);if($styleMap.ContainsKey($old)){Attr $node 'styleId' $styleMap[$old]};$node.RemoveAttribute('default',$w);$name=$node.SelectSingleNode('w:name',$n);if($name){Attr $name 'val' ("Chapter $chapter "+$name.GetAttribute('val',$w))}}
   foreach($node in $xml.SelectNodes('//w:numId|//w:abstractNumId',$n)){$old=[int]$node.GetAttribute('val',$w);if($node.LocalName -eq 'numId' -and $old -eq 0){continue};Attr $node 'val' ($old+$chapter*10000)}
   foreach($node in $xml.SelectNodes('//w:num',$n)){Attr $node 'numId' ([int]$node.GetAttribute('numId',$w)+$chapter*10000)}
   foreach($node in $xml.SelectNodes('//w:abstractNum',$n)){Attr $node 'abstractNumId' ([int]$node.GetAttribute('abstractNumId',$w)+$chapter*10000)}
   foreach($node in $xml.SelectNodes('//w:bookmarkStart|//w:bookmarkEnd',$n)){Attr $node 'id' ([int]$node.GetAttribute('id',$w)+$chapter*100000);if($node.LocalName -eq 'bookmarkStart'){Attr $node 'name' ("C${chapter}_"+$node.GetAttribute('name',$w))}}
   foreach($link in $xml.SelectNodes('//w:hyperlink[@w:anchor]',$n)){Attr $link 'anchor' ("C${chapter}_"+$link.GetAttribute('anchor',$w))}
   if($main){foreach($attribute in $xml.SelectNodes('//@*')){if($attribute.NamespaceURI -eq $r -and $ridMap.ContainsKey($attribute.Value)){$attribute.Value=$ridMap[$attribute.Value]}}}
  }
  Rewrite $incoming $true;Rewrite $srcStyles;Rewrite $srcNum
  foreach($style in $srcStyles.SelectNodes('//w:style',(Ns $srcStyles))){[void]$styles.DocumentElement.AppendChild($styles.ImportNode($style,$true))}
  foreach($node in $srcNum.DocumentElement.ChildNodes){if($node.LocalName -in @('abstractNum','num')){[void]$numbering.DocumentElement.AppendChild($numbering.ImportNode($node,$true))}}
  # Copy image and supporting parts into an isolated namespace; relocate their own relationships.
  foreach($entry in $source.Entries){
   $oldName=$entry.FullName;if($oldName -eq '[Content_Types].xml' -or $oldName -eq '_rels/.rels' -or $map[$oldName] -eq $oldName -or $oldName -eq 'word/_rels/document.xml.rels'){continue}
   $newName=$map[$oldName]
   if($oldName.EndsWith('.rels')){
    $partXml=LoadXml $source $oldName;$owner=$oldName -replace '_rels/([^/]+)\.rels$','$1';$newOwner=$map[$owner]
    foreach($rel in $partXml.DocumentElement.ChildNodes){if($rel.TargetMode -eq 'External'){continue};$target=ResolvePart $owner $rel.Target;if(-not $map.ContainsKey($target)){throw "Unmapped dependency $target"};$rel.SetAttribute('Target',(RelativePart $newOwner $map[$target]))};SaveXml $zip $newName $partXml
   }elseif($oldName.EndsWith('.xml')){$partXml=LoadXml $source $oldName;Rewrite $partXml;SaveXml $zip $newName $partXml
   }else{$s=$zip.CreateEntry($newName).Open();$input=$entry.Open();$input.CopyTo($s);$input.Dispose();$s.Dispose();if($oldName -like 'word/media/*'){if((HashEntry $entry) -ne (HashEntry $zip.GetEntry($newName))){throw 'Image bytes changed'};$preservedMedia++}}
  }
  foreach($type in $srcTypes.DocumentElement.ChildNodes){if($type.LocalName -eq 'Default'){$exists=@($types.DocumentElement.ChildNodes|Where-Object {$_.LocalName -eq 'Default' -and $_.Extension -eq $type.Extension});if(-not $exists){[void]$types.DocumentElement.AppendChild($types.ImportNode($type,$true))}}elseif($type.LocalName -eq 'Override'){$oldName=$type.PartName.TrimStart('/');if($map[$oldName] -and $map[$oldName] -ne $oldName){$copy=$types.ImportNode($type,$true);$copy.SetAttribute('PartName','/'+$map[$oldName]);[void]$types.DocumentElement.AppendChild($copy)}}}
  CloseSection
  $sourceBody=$incoming.SelectSingleNode('//w:body',$inn);$temporaryBody=$doc.CreateElement('w','body',$w);foreach($node in $sourceBody.ChildNodes){[void]$temporaryBody.AppendChild($doc.ImportNode($node,$true))};MarkHeadings $temporaryBody $chapter
  foreach($node in @($temporaryBody.ChildNodes)){[void]$body.AppendChild($node)}
 }
 # The front matter has its own portrait section, followed by the original chapter sections.
 $first=$body.FirstChild;$title=NewParagraph 'TABLE OF CONTENTS';$pr=$title.SelectSingleNode('w:pPr',$ns);$jc=$doc.CreateElement('w','jc',$w);Attr $jc 'val' 'center';[void]$pr.AppendChild($jc);[void]$body.InsertBefore($title,$first)
 $begin=NewParagraph '';$run=$begin.SelectSingleNode('w:r',$ns);$field=$doc.CreateElement('w','fldChar',$w);Attr $field 'fldCharType' 'begin';Attr $field 'dirty' 'true';[void]$run.AppendChild($field);$instrRun=$doc.CreateElement('w','r',$w);$instr=$doc.CreateElement('w','instrText',$w);$space=$doc.CreateAttribute('xml','space','http://www.w3.org/XML/1998/namespace');$space.Value='preserve';[void]$instr.Attributes.Append($space);$instr.InnerText=' TOC \o "1-3" \h \z \u ';[void]$instrRun.AppendChild($instr);[void]$begin.AppendChild($instrRun);$sepRun=$doc.CreateElement('w','r',$w);$sep=$doc.CreateElement('w','fldChar',$w);Attr $sep 'fldCharType' 'separate';[void]$sepRun.AppendChild($sep);[void]$begin.AppendChild($sepRun);[void]$body.InsertBefore($begin,$first)
 foreach($heading in $headings){$p=NewParagraph $heading.Text;$pr=$p.SelectSingleNode('w:pPr',$ns);$ind=$doc.CreateElement('w','ind',$w);Attr $ind 'left' (($heading.Level-1)*360);[void]$pr.AppendChild($ind);$run=$p.SelectSingleNode('w:r',$ns);[void]$p.RemoveChild($run);$link=$doc.CreateElement('w','hyperlink',$w);Attr $link 'anchor' $heading.Bookmark;[void]$link.AppendChild($run);[void]$p.AppendChild($link);[void]$body.InsertBefore($p,$first)}
 $end=NewParagraph '';$field=$doc.CreateElement('w','fldChar',$w);Attr $field 'fldCharType' 'end';[void]$end.SelectSingleNode('w:r',$ns).AppendChild($field);$sec=$doc.CreateElement('w','sectPr',$w);$kind=$doc.CreateElement('w','type',$w);Attr $kind 'val' 'nextPage';[void]$sec.AppendChild($kind);$size=$doc.CreateElement('w','pgSz',$w);Attr $size 'w' 12240;Attr $size 'h' 15840;[void]$sec.AppendChild($size);$margins=$doc.CreateElement('w','pgMar',$w);Attr $margins 'left' 2160;foreach($key in @('right','top','bottom')){Attr $margins $key 1440};Attr $margins 'header' 708;Attr $margins 'footer' 708;[void]$sec.AppendChild($margins);[void]$end.SelectSingleNode('w:pPr',$ns).AppendChild($sec);[void]$body.InsertBefore($end,$first)
 # Renumber drawing IDs across the assembled main document.
 $drawingId=1;foreach($drawing in $doc.SelectNodes('//wp:docPr',$ns)){$drawing.SetAttribute('id',[string]$drawingId);$drawingId++}
 # Keep numbering definitions in the schema's abstract-definition / instance order.
 $numNs=Ns $numbering
 foreach($node in @($numbering.SelectNodes('//w:abstractNum',$numNs))){[void]$numbering.DocumentElement.RemoveChild($node);$firstNum=$numbering.DocumentElement.SelectSingleNode('w:num',$numNs);if($firstNum){[void]$numbering.DocumentElement.InsertBefore($node,$firstNum)}else{[void]$numbering.DocumentElement.AppendChild($node)}}
 SaveXml $zip 'word/document.xml' $doc;SaveXml $zip 'word/styles.xml' $styles;SaveXml $zip 'word/numbering.xml' $numbering;SaveXml $zip 'word/_rels/document.xml.rels' $rels;SaveXml $zip '[Content_Types].xml' $types
 $settings=LoadXml $zip 'word/settings.xml';$sn=Ns $settings;$update=$settings.SelectSingleNode('//w:updateFields',$sn);if(-not $update){$update=$settings.CreateElement('w','updateFields',$w);[void]$settings.DocumentElement.AppendChild($update)};Attr $update 'val' 'true';SaveXml $zip 'word/settings.xml' $settings
 # Validate the chapter body text sequence and table content, excluding the new TOC.
 $expected=[Collections.Generic.List[string]]::new();$expectedTables=0
 foreach($chapter in 1..3){$source=[IO.Compression.ZipFile]::OpenRead((Join-Path $snapshot.FullName "Chapter $chapter.docx"));try{$x=LoadXml $source 'word/document.xml';$n=Ns $x;foreach($t in $x.SelectNodes('//w:body//w:t',$n)){$expected.Add($t.InnerText)};$expectedTables+=$x.SelectNodes('//w:tbl',$n).Count}finally{$source.Dispose()}}
 $actual=[Collections.Generic.List[string]]::new();$node=$first;while($node){foreach($t in $node.SelectNodes('.//w:t',$ns)){$actual.Add($t.InnerText)};$node=$node.NextSibling}
 if(($actual -join "`n") -cne ($expected -join "`n")){throw 'Chapter wording/order changed'}
 if($doc.SelectNodes('//w:tbl',$ns).Count -ne $expectedTables){throw 'Table count mismatch'}
 foreach($relPart in @($zip.Entries|Where-Object {$_.FullName.EndsWith('.rels')}|ForEach-Object FullName)){$x=LoadXml $zip $relPart;$owner=if($relPart -eq '_rels/.rels'){''}else{$relPart -replace '_rels/([^/]+)\.rels$','$1'};foreach($rel in $x.DocumentElement.ChildNodes){if($rel.TargetMode -eq 'External'){continue};$target=ResolvePart $owner $rel.Target;if(-not $zip.GetEntry($target)){throw "Broken relationship: $relPart -> $target"}}}
 foreach($part in @($zip.Entries|Where-Object {$_.FullName -match '\.(xml|rels)$'}|ForEach-Object FullName)){try{$parsed=LoadXml $zip $part}catch{throw "Generated XML failed to reopen: $part"}}
 $report=@("PASS: chapters 1-3 combined in order; all $($expected.Count) original text runs and $expectedTables tables retained.","PASS: $preservedMedia imported image/binary media parts byte-match the source; original Chapter 1 media retained.","PASS: styles and numbering namespaced; all XML parts reopen and package relationship targets resolve; drawing IDs unique.","PASS: linked TOC has $($headings.Count) chapter/section entries and a real three-level TOC field; automatic field update requested on open.",'LIMIT: page numbers require Word to update the TOC; cached entries are clickable but deliberately contain no invented page numbers.',"Input snapshots: $($snapshot.FullName)")
 $report|Set-Content -Encoding UTF8 (Join-Path $root 'Review Evidence/Combined Chapters Verification.txt');$report
}finally{foreach($source in $sourceArchives){$source.Dispose()};$zip.Dispose()}
Copy-Item -LiteralPath $stage -Destination $output -Force
Write-Output "Saved: $output"
