$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=Split-Path $PSScriptRoot -Parent
$backupDir=Join-Path $root ('Review Backups/chapter-spacing-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
[void][IO.Directory]::CreateDirectory($backupDir)
$w='http://schemas.openxmlformats.org/wordprocessingml/2006/main'
$reports=[Collections.Generic.List[string]]::new();$staged=[Collections.Generic.List[object]]::new()
function ReadXml($archive,$part){$sr=[IO.StreamReader]::new($archive.GetEntry($part).Open());try{$xml=[Xml.XmlDocument]::new();$xml.PreserveWhitespace=$true;$xml.LoadXml($sr.ReadToEnd());return ,$xml}finally{$sr.Dispose()}}
function Namespace($xml){$ns=[Xml.XmlNamespaceManager]::new($xml.NameTable);$ns.AddNamespace('w',$w);$ns.AddNamespace('wp','http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing');$ns.AddNamespace('a','http://schemas.openxmlformats.org/drawingml/2006/main');return ,$ns}
function SetAttr($node,$key,$value){[void]$node.SetAttribute($key,$w,[string]$value)}
function Property($parent,$name){
 $ns=Namespace $parent.OwnerDocument;$existing=$parent.SelectSingleNode('w:'+$name,$ns);if($existing){return ,$existing}
 $new=$parent.OwnerDocument.CreateElement('w',$name,$w)
 $order=if($parent.LocalName -eq 'rPr'){@('rStyle','rFonts','b','bCs','i','iCs','caps','smallCaps','strike','dstrike','outline','shadow','emboss','imprint','noProof','snapToGrid','vanish','webHidden','color','spacing','w','kern','position','sz','szCs','highlight','u','effect','bdr','shd','fitText','vertAlign','rtl','cs','em','lang','eastAsianLayout','specVanish','oMath','rPrChange')}elseif($parent.LocalName -eq 'pPr'){@('pStyle','keepNext','keepLines','pageBreakBefore','framePr','widowControl','numPr','suppressLineNumbers','pBdr','shd','tabs','suppressAutoHyphens','kinsoku','wordWrap','overflowPunct','topLinePunct','autoSpaceDE','autoSpaceDN','bidi','adjustRightInd','snapToGrid','spacing','ind','contextualSpacing','mirrorIndents','suppressOverlap','jc','textDirection','textAlignment','textboxTightWrap','outlineLvl','divId','cnfStyle','rPr','sectPr','pPrChange')}else{@()}
 $index=if($null -ne $order){[array]::IndexOf($order,$name)}else{-1};$next=$null
 if($index -ge 0){foreach($child in $parent.ChildNodes){$other=[array]::IndexOf($order,$child.LocalName);if($other -gt $index){$next=$child;break}}}
 if($next){[void]$parent.InsertBefore($new,$next)}else{[void]$parent.AppendChild($new)};return ,$new
}
function Font($pr){$fonts=Property $pr 'rFonts';foreach($key in @('asciiTheme','hAnsiTheme','eastAsiaTheme','cstheme','csTheme')){$fonts.RemoveAttribute($key,$w)};foreach($key in @('ascii','hAnsi','eastAsia','cs')){SetAttr $fonts $key 'Times New Roman'};foreach($key in @('sz','szCs')){SetAttr (Property $pr $key) 'val' 24}}
function Spacing($pr){$spacing=Property $pr 'spacing';SetAttr $spacing 'line' 360;SetAttr $spacing 'lineRule' 'auto';$grid=Property $pr 'snapToGrid';SetAttr $grid 'val' 0}
function SectionBox($section){$ns=Namespace $section.OwnerDocument;$size=$section.SelectSingleNode('w:pgSz',$ns);return @((([long]$size.GetAttribute('w',$w)-2160-1440)*635),(([long]$size.GetAttribute('h',$w)-2880)*635))}
function FollowingSection($node,$document){$ns=Namespace $document;while($node){if($node.LocalName -eq 'sectPr'){return ,$node};$sec=$node.SelectSingleNode('w:pPr/w:sectPr',$ns);if($sec){return ,$sec};$node=$node.NextSibling};return ,$document.SelectSingleNode('//w:body/w:sectPr',$ns)}
function Hash($entry){$stream=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create();try{return [Convert]::ToBase64String($sha.ComputeHash($stream))}finally{$stream.Dispose();$sha.Dispose()}}
foreach($chapter in 1..3){
 $source=Join-Path $root "Chapter $chapter.docx";$backup=Join-Path $backupDir "Chapter $chapter.docx";$work=Join-Path $backupDir "Chapter $chapter formatted.docx"
 Copy-Item -LiteralPath $source -Destination $backup;Copy-Item -LiteralPath $source -Destination $work
 $sourceHash=(Get-FileHash $source).Hash;$zip=[IO.Compression.ZipFile]::Open($work,'Update');$changed=[Collections.Generic.List[string]]::new();$imageCount=0;$tableCount=0
 try{
  foreach($part in @($zip.Entries|Where-Object {$_.FullName -match '^word/(document|styles|numbering|footnotes|endnotes|header\d+|footer\d+)\.xml$'}|ForEach-Object FullName)){
   $xml=ReadXml $zip $part;$ns=Namespace $xml
   foreach($run in $xml.SelectNodes('//w:r',$ns)){$pr=$run.SelectSingleNode('w:rPr',$ns);if(-not $pr){$pr=$xml.CreateElement('w','rPr',$w);[void]$run.PrependChild($pr)};Font $pr}
   foreach($paragraph in $xml.SelectNodes('//w:p',$ns)){$pr=$paragraph.SelectSingleNode('w:pPr',$ns);if(-not $pr){$pr=$xml.CreateElement('w','pPr',$w);[void]$paragraph.PrependChild($pr)};Spacing $pr;Font (Property $pr 'rPr')}
   foreach($pr in @($xml.SelectNodes('//w:rPr',$ns))){Font $pr}
   foreach($pr in @($xml.SelectNodes('//w:pPr',$ns))){Spacing $pr}
   if($part -eq 'word/styles.xml'){
    $defaults=Property $xml.DocumentElement 'docDefaults';$rd=Property $defaults 'rPrDefault';Font (Property $rd 'rPr');$pd=Property $defaults 'pPrDefault';Spacing (Property $pd 'pPr')
    foreach($style in $xml.SelectNodes('//w:style',$ns)){Font (Property $style 'rPr');if($style.GetAttribute('type',$w) -in @('paragraph','table')){Spacing (Property $style 'pPr')}}
   }
   foreach($section in $xml.SelectNodes('//w:sectPr',$ns)){$margins=Property $section 'pgMar';SetAttr $margins 'left' 2160;foreach($key in @('right','top','bottom')){SetAttr $margins $key 1440};SetAttr $margins 'gutter' 0}
   # Exact row heights can clip 12-point text after increasing line spacing.
   foreach($height in $xml.SelectNodes('//w:trHeight[@w:hRule="exact"]',$ns)){SetAttr $height 'hRule' 'atLeast'}
   if($part -eq 'word/document.xml'){
    $body=$xml.SelectSingleNode('//w:body',$ns)
    foreach($node in @($body.ChildNodes)){
     if($node.LocalName -notin @('p','tbl')){continue};$section=FollowingSection $node $xml;$box=SectionBox $section
     foreach($drawing in $node.SelectNodes('.//wp:inline|.//wp:anchor',$ns)){
      $extent=$drawing.SelectSingleNode('wp:extent',$ns);$cx=[long]$extent.GetAttribute('cx');$cy=[long]$extent.GetAttribute('cy');if($cx -le 0 -or $cy -le 0){throw 'Invalid figure dimensions'}
      # Reserve one inch for a heading/caption and paragraph spacing on the figure page.
      $scale=[Math]::Min(1,[Math]::Min($box[0]/$cx,($box[1]-914400)/$cy));if($scale -lt 1){$newX=[long][Math]::Floor($cx*$scale);$newY=[long][Math]::Floor($cy*$scale);$extent.SetAttribute('cx',"$newX");$extent.SetAttribute('cy',"$newY");foreach($ext in $drawing.SelectNodes('.//a:xfrm/a:ext',$ns)){$ext.SetAttribute('cx',"$newX");$ext.SetAttribute('cy',"$newY")};$imageCount++}
     }
     if($node.LocalName -eq 'tbl'){
      $grid=@($node.SelectNodes('w:tblGrid/w:gridCol',$ns));$width=($grid|ForEach-Object {[long]$_.GetAttribute('w',$w)}|Measure-Object -Sum).Sum
      $available=[long]($box[0]/635);$indent=$node.SelectSingleNode('w:tblPr/w:tblInd[@w:type="dxa"]',$ns);if($indent){$available-=[Math]::Max(0,[long]$indent.GetAttribute('w',$w))}
      if($width -gt $available){$ratio=$available/$width;foreach($col in $grid){SetAttr $col 'w' ([long][Math]::Floor([long]$col.GetAttribute('w',$w)*$ratio))};foreach($cell in $node.SelectNodes('.//w:tcW[@w:type="dxa"]',$ns)){SetAttr $cell 'w' ([long][Math]::Floor([long]$cell.GetAttribute('w',$w)*$ratio))};$tw=$node.SelectSingleNode('w:tblPr/w:tblW',$ns);if($tw){SetAttr $tw 'type' 'dxa';SetAttr $tw 'w' $available};$tableCount++}
     }
    }
   }
   $zip.GetEntry($part).Delete();$stream=$zip.CreateEntry($part).Open();$writer=[IO.StreamWriter]::new($stream,[Text.UTF8Encoding]::new($false));$xml.Save($writer);$writer.Dispose();$changed.Add($part)
  }
  # All wording, fields, figures, citations and relationship targets must be preserved.
  $original=[IO.Compression.ZipFile]::OpenRead($backup)
  try{
   foreach($entry in $original.Entries){$new=$zip.GetEntry($entry.FullName);if(-not $new){throw 'Missing package part'};if(-not $changed.Contains($entry.FullName)){if((Hash $entry) -ne (Hash $new)){throw ('Unexpected package change: '+$entry.FullName)};continue};$previous=ReadXml $original $entry.FullName;$current=ReadXml $zip $entry.FullName;$pns=Namespace $previous;$cns=Namespace $current
    foreach($selector in @('//w:t','//w:instrText','//w:fldChar','//w:tbl//w:t')){$one=@($previous.SelectNodes($selector,$pns)|ForEach-Object OuterXml);$two=@($current.SelectNodes($selector,$cns)|ForEach-Object OuterXml);if(($one -join "`n") -cne ($two -join "`n")){throw "Content changed in $($entry.FullName): $selector"}}
    foreach($run in $current.SelectNodes('//w:r',$cns)){$pr=$run.SelectSingleNode('w:rPr',$cns);if($pr.SelectSingleNode('w:rFonts',$cns).GetAttribute('ascii',$w) -ne 'Times New Roman' -or $pr.SelectSingleNode('w:sz',$cns).GetAttribute('val',$w) -ne '24'){throw 'Run font mismatch'}}
    foreach($p in $current.SelectNodes('//w:p',$cns)){$spacing=$p.SelectSingleNode('w:pPr/w:spacing',$cns);if($spacing.GetAttribute('line',$w) -ne '360' -or $spacing.GetAttribute('lineRule',$w) -ne 'auto'){throw 'Paragraph spacing mismatch'}}
    foreach($section in $current.SelectNodes('//w:sectPr',$cns)){$m=$section.SelectSingleNode('w:pgMar',$cns);foreach($key in @('left','right','top','bottom')){$expected=if($key -eq 'left'){'2160'}else{'1440'};if($m.GetAttribute($key,$w) -ne $expected){throw 'Margin mismatch'}}}
   }
  }finally{$original.Dispose()}
 }finally{$zip.Dispose()}
 $reports.Add("Chapter ${chapter}: PASS - Times New Roman 12 pt; 1.5-line spacing in all paragraphs, including tables/captions; all sections use 1.5-inch left and 1-inch other margins. $imageCount figures proportionally reduced; $tableCount table grids fitted. Text, field instructions, table text and all unchanged package parts/media preserved.")
 $staged.Add([pscustomobject]@{Source=$source;Work=$work;Hash=$sourceHash})
}
# Stage and validate all chapters before replacing any manuscript.
$handles=[Collections.Generic.List[object]]::new()
try{foreach($item in $staged){if((Get-FileHash $item.Source).Hash -ne $item.Hash){throw 'A manuscript changed during formatting'};$handles.Add([IO.File]::Open($item.Source,'Open','ReadWrite','None'))}}finally{foreach($handle in $handles){$handle.Dispose()}}
foreach($item in $staged){Copy-Item -LiteralPath $item.Work -Destination $item.Source -Force}
$reports.Add('Formatting only; page orientation, existing paragraph before/after spacing, wording and embedded image bytes preserved. No application/schema/deployment change. Actual Word pagination remains a separate visual check.')
$reports.Add('Backup: '+$backupDir)
$reports|Set-Content -Encoding UTF8 (Join-Path $root 'Review Evidence/Chapter 1-3 Spacing Verification.txt')
$reports
