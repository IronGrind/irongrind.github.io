param([string]$DocumentPath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'Chapter 3.docx'))
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Drawing
$root=Split-Path $PSScriptRoot -Parent;$diagram=Join-Path $root 'Chapter 3 Diagrams';$path=(Resolve-Path -LiteralPath $DocumentPath).Path
$backup=Join-Path $root ('Review Backups/dfd-no-overlap-'+(Get-Date -Format yyyyMMdd-HHmmss));New-Item -ItemType Directory -Path $backup -Force|Out-Null
Copy-Item -LiteralPath $path -Destination (Join-Path $backup 'Chapter 3 before DFD layout.docx')
$work=Join-Path $backup 'Chapter 3 working.docx';Copy-Item -LiteralPath $path -Destination $work
$zip=[IO.Compression.ZipFile]::Open($work,'Update')
try{
 function ReadXml($part){$reader=[IO.StreamReader]::new($zip.GetEntry($part).Open());try{return ,([xml]$reader.ReadToEnd())}finally{$reader.Dispose()}}
 function SaveXml($part,$xml){$stream=$zip.GetEntry($part).Open();$stream.SetLength(0);$writer=[IO.StreamWriter]::new($stream,[Text.UTF8Encoding]::new($false));try{$xml.Save($writer)}finally{$writer.Dispose()}}
 function WriteBinary($part,$file){$old=$zip.GetEntry($part);if($old){$old.Delete()};$stream=$zip.CreateEntry($part).Open();try{$bytes=[IO.File]::ReadAllBytes($file);$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}}
 function ParagraphText($paragraph){($paragraph.SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join ''}
 function ImageTarget($paragraph){$blip=$paragraph.SelectSingleNode('.//a:blip',$ns);if(-not $blip){return ''};$rid=$blip.GetAttribute('embed',$r);$relation=$rels.Relationships.Relationship|Where-Object Id -eq $rid;return [string]$relation.Target}
 function SetParagraphText($paragraph,[string]$value){$textNodes=$paragraph.SelectNodes('.//w:t',$ns);if(-not $textNodes.Count){throw 'The paragraph template has no text run.'};$textNodes[0].InnerText=$value;for($j=1;$j -lt $textNodes.Count;$j++){$textNodes[$j].InnerText=''}}
 function SetCentered($paragraph,[bool]$keepNext){
  $pr=$paragraph.SelectSingleNode('w:pPr',$ns);if(-not $pr){$pr=$doc.CreateElement('w','pPr',$w);$null=$paragraph.PrependChild($pr)}
  foreach($old in @($pr.SelectNodes('w:pageBreakBefore|w:sectPr|w:keepNext|w:jc',$ns))){$null=$pr.RemoveChild($old)}
  if($keepNext){$null=$pr.AppendChild($doc.CreateElement('w','keepNext',$w))}
  $jc=$doc.CreateElement('w','jc',$w);$null=$jc.SetAttribute('val',$w,'center');$null=$pr.AppendChild($jc)
  $spacing=$pr.SelectSingleNode('w:spacing',$ns);if(-not $spacing){$spacing=$doc.CreateElement('w','spacing',$w);$null=$pr.AppendChild($spacing)};foreach($att in @('before','after')){$null=$spacing.SetAttribute($att,$w,'0')}
 }
 $doc=ReadXml 'word/document.xml';$rels=ReadXml 'word/_rels/document.xml.rels';$w='http://schemas.openxmlformats.org/wordprocessingml/2006/main';$a='http://schemas.openxmlformats.org/drawingml/2006/main';$r='http://schemas.openxmlformats.org/officeDocument/2006/relationships';$ns=[Xml.XmlNamespaceManager]::new($doc.NameTable);$ns.AddNamespace('w',$w);$ns.AddNamespace('a',$a);$ns.AddNamespace('r',$r);$ns.AddNamespace('wp','http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing')
 $tables=$doc.SelectNodes('//w:body/w:tbl',$ns).Count;$dictionary=@($doc.SelectNodes('//w:body/w:tbl',$ns)|Select-Object -Skip 5);$fields=0;foreach($table in $dictionary){$fields+=$table.SelectNodes('w:tr',$ns).Count-1};if($tables -ne 23 -or $fields -ne 201){throw "Unexpected pre-edit schema tables: $tables tables, $fields fields."}
 $body=$doc.SelectSingleNode('//w:body',$ns);$paragraphs=@($body.SelectNodes('w:p',$ns));$captionTemplate=@($paragraphs|Where-Object {(ParagraphText $_).Trim() -match '^Figure 3a\.( Detailed Level 1 DFD| Level 1 DFD - Process 1\.0:)'}|Select-Object -First 1)[0];$pictureTemplate=@($paragraphs|Where-Object {(ImageTarget $_) -eq 'media/summary-dfd.png'}|Select-Object -First 1)[0];$noteTemplate=@($paragraphs|Where-Object {(ParagraphText $_).Trim().StartsWith('Figure 3a expands the overview') -or (ParagraphText $_).Trim().StartsWith('The nine process panels')}|Select-Object -First 1)[0];$securityCaption=@($paragraphs|Where-Object {(ParagraphText $_).Trim() -match '^Figure 3[ bj]\. User Login - Additional Individual Security Stores'}|Select-Object -First 1)[0];$securityPicture=@($paragraphs|Where-Object {(ImageTarget $_) -eq 'media/03a-login-security-stores.png'}|Select-Object -First 1)[0]
 if(-not $captionTemplate -or -not $pictureTemplate -or -not $noteTemplate -or -not $securityCaption -or -not $securityPicture){throw 'Expected current DFD captions and source images were not found.'}
 $captionTemplate=$captionTemplate.CloneNode($true);$pictureTemplate=$pictureTemplate.CloneNode($true);$noteTemplate=$noteTemplate.CloneNode($true)
 foreach($paragraph in @($body.SelectNodes('w:p',$ns))){$value=(ParagraphText $paragraph).Trim();$target=ImageTarget $paragraph
  if($target -eq 'media/detailed-dfd.png' -or $value -eq 'Figure 3a. Detailed Level 1 DFD - Individual Data Stores' -or $value -match '^Figure 3[a-j]\. Level 1 DFD - Process [1-9]\.0:'){
   $next=$paragraph.NextSibling;$null=$body.RemoveChild($paragraph);if($next -and $next.SelectSingleNode('.//a:blip',$ns)){$null=$body.RemoveChild($next)}
  }
  elseif($value.StartsWith('Figure 3a expands the overview') -or $value.StartsWith('The nine process panels')){$null=$body.RemoveChild($paragraph)}
 }
 $paragraphs=@($body.SelectNodes('w:p',$ns));$securityCaption=@($paragraphs|Where-Object {(ParagraphText $_).Trim() -match '^Figure 3[ bj]\. User Login - Additional Individual Security Stores'}|Select-Object -First 1)[0];$securityPicture=@($paragraphs|Where-Object {(ImageTarget $_) -eq 'media/03a-login-security-stores.png'}|Select-Object -First 1)[0]
 if(-not $securityCaption -or -not $securityPicture){throw 'Could not preserve the administrator security-store supplement.'}
 $null=$body.RemoveChild($securityPicture)
 $pictureBlip=$pictureTemplate.SelectSingleNode('.//a:blip',$ns);$maxDocPr=0;foreach($node in $doc.SelectNodes('//wp:docPr',$ns)){if([int]$node.GetAttribute('id') -gt $maxDocPr){$maxDocPr=[int]$node.GetAttribute('id')}}
 $cx=[long](6.5*914400)
 $names=@('Authenticate and authorize','Review online applications','User management','Review online renewals','Record and view attendance','Manage inventory and read catalog','Record product sale','Generate reports','Activity logs')
 for($i=1;$i -le 9;$i++){
  $file=Join-Path $diagram ("_Sources/dfd-process-{0}.png" -f $i);if(-not(Test-Path -LiteralPath $file)){throw "Missing process-panel image: $file"}
  $caption=$captionTemplate.CloneNode($true);SetParagraphText $caption ("Figure 3$([char](96+$i)). Level 1 DFD - Process $i.0: $($names[$i-1])");SetCentered $caption $true
  $picture=$pictureTemplate.CloneNode($true);SetCentered $picture $false;$blip=$picture.SelectSingleNode('.//a:blip',$ns);$rid="rIdDFDProcess$i";$null=$blip.SetAttribute('embed',$r,$rid)
  $existing=@($rels.DocumentElement.ChildNodes|Where-Object Id -eq $rid);foreach($old in $existing){$null=$rels.DocumentElement.RemoveChild($old)}
  $rel=$rels.CreateElement('Relationship',$rels.DocumentElement.NamespaceURI);$rel.SetAttribute('Id',$rid);$rel.SetAttribute('Type',$r+'/image');$rel.SetAttribute('Target',"media/dfd-process-$i.png");$null=$rels.DocumentElement.AppendChild($rel)
  WriteBinary "word/media/dfd-process-$i.png" $file
  $image=[Drawing.Image]::FromFile($file);$cy=[long]($cx*$image.Height/$image.Width);$image.Dispose()
  foreach($extent in $picture.SelectNodes('.//wp:extent|.//a:xfrm/a:ext',$ns)){$null=$extent.SetAttribute('cx',[string]$cx);$null=$extent.SetAttribute('cy',[string]$cy)}
  $docPr=$picture.SelectSingleNode('.//wp:docPr',$ns);$maxDocPr++;$docPr.SetAttribute('id',[string]$maxDocPr);$docPr.SetAttribute('name',"DFD process $i.0");$docPr.SetAttribute('descr',"Gane-Sarson process $i.0: $($names[$i-1]); individually labeled actor and data-store flows arranged in separate, non-crossing lanes.")
  $null=$body.InsertBefore($caption,$securityCaption);$null=$body.InsertBefore($picture,$securityCaption)
 }
 $note= $noteTemplate.CloneNode($true);SetParagraphText $note 'The nine process panels decompose the same Level 1 DFD. Each panel places external roles on the left, one numbered process in the center, and individually named stores on the right. Separate horizontal arrows show each input, output, read, and write. Repeated actor and store identifiers refer to the same entities; paneling does not add functions or database tables. D12 remains reserved and is not shown as an active frontend dependency. Figure 3j isolates the administrator login-security stores D15-D17.'
 $null=$body.InsertBefore($note,$securityCaption)
 foreach($paragraph in $body.SelectNodes('w:p',$ns)){$value=ParagraphText $paragraph;if($value.Contains('Figure 3b') -and -not $value.Contains('Level 1 DFD - Process')){SetParagraphText $paragraph ($value.Replace('Figure 3b','Figure 3j'))};if($value.Contains('the full DFD in Figure 3a')){SetParagraphText $paragraph ($value.Replace('the full DFD in Figure 3a','the detailed process panels in Figures 3a-i'))}}
 $captionSecurity=@($body.SelectNodes('w:p',$ns)|Where-Object {(ParagraphText $_).Trim() -match '^Figure 3j\. User Login - Additional Individual Security Stores'}|Select-Object -First 1)[0];if(-not $captionSecurity){throw 'The security supplement caption did not renumber to Figure 3j.'}
 $overviewNote=@($body.SelectNodes('w:p',$ns)|Where-Object {(ParagraphText $_).Contains('Figure 3j identifies the additional individual security stores')}|Select-Object -First 1)[0]
 if(-not $overviewNote){$overviewNote=@($body.SelectNodes('w:p',$ns)|Where-Object {(ParagraphText $_).Contains('Figure 3 expands the system into nine functions')}|Select-Object -First 1)[0];if($overviewNote){$value=ParagraphText $overviewNote;SetParagraphText $overviewNote ($value.Replace('Figure 3b identifies','Figure 3j identifies'))}}
 $securityNote=@($body.SelectNodes('w:p',$ns)|Where-Object {(ParagraphText $_).Trim().StartsWith('Figure 3b expands the security-storage view') -or (ParagraphText $_).Trim().StartsWith('Figure 3j expands the security-storage view')}|Select-Object -First 1)[0]
 if($securityNote){$value=ParagraphText $securityNote;$value=$value.Replace('Figure 3b','Figure 3j').Replace('the full DFD in Figure 3a','the detailed process panels in Figures 3a-i');SetParagraphText $securityNote $value}
 $null=$body.InsertBefore($securityPicture,$captionSecurity)
 if($doc.SelectNodes('//w:body/w:tbl',$ns).Count -ne $tables){throw 'The table count changed during the diagram update.'};$afterDictionary=@($doc.SelectNodes('//w:body/w:tbl',$ns)|Select-Object -Skip 5);$afterFields=0;foreach($table in $afterDictionary){$afterFields+=$table.SelectNodes('w:tr',$ns).Count-1};if($afterFields -ne $fields){throw 'The dictionary field count changed during the diagram update.'}
 SaveXml 'word/document.xml' $doc;SaveXml 'word/_rels/document.xml.rels' $rels
}finally{$zip.Dispose()}
$fileLock=[IO.File]::Open($path,'Open','ReadWrite','None');$fileLock.Dispose();Copy-Item -LiteralPath $work -Destination $path -Force
"Updated Chapter 3 with nine individual-flow panels; preserved all $tables tables and $fields dictionary fields. Backup: $backup"
