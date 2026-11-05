$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression
$path=Join-Path (Get-Location) 'Documentations\Chapter 3.docx'
$z=[IO.Compression.ZipArchive]::new([IO.File]::Open($path,'Open','ReadWrite'),[IO.Compression.ZipArchiveMode]::Update)
try{
$e=$z.GetEntry('word/document.xml');$r=[IO.StreamReader]::new($e.Open());$d=[Xml.XmlDocument]::new();$d.PreserveWhitespace=$true;$d.LoadXml($r.ReadToEnd());$r.Dispose()
$n=[Xml.XmlNamespaceManager]::new($d.NameTable);$n.AddNamespace('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main');$n.AddNamespace('wp','http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing')
function Element($prefix,$name){return $d.CreateElement($prefix,$name,$n.LookupNamespace($prefix))}
function Property($parent,$name){$v=$parent.SelectSingleNode("w:$name",$n);if(-not $v){$v=Element 'w' $name;[void]$parent.AppendChild($v)};return ,$v}
function Attr($node,$key,$value){$node.SetAttribute($key,$n.LookupNamespace('w'),[string]$value)}
function TextOf($node){return ($node.SelectNodes('.//w:t',$n)|ForEach-Object {$_.InnerText}) -join ''}
function Bold($rpr,$yes){foreach($tag in @('b','bCs')){$v=Property $rpr $tag;[void](Attr $v 'val' $(if($yes){'1'}else{'0'}))}}
# Convert floating figures into text-flow images before removing layout spacer paragraphs.
$converted=0
foreach($anchor in @($d.SelectNodes('//wp:anchor',$n))){$inline=Element 'wp' 'inline';foreach($a in @('distT','distB','distL','distR')){$inline.SetAttribute($a,'0')};foreach($tag in @('extent','effectExtent','docPr','cNvGraphicFramePr')){$node=$anchor.SelectSingleNode("wp:$tag",$n);if($node){[void]$inline.AppendChild($node.CloneNode($true))}};foreach($node in $anchor.ChildNodes){if($node.LocalName -eq 'graphic'){[void]$inline.AppendChild($node.CloneNode($true))}};[void]$anchor.ParentNode.ReplaceChild($inline,$anchor);$converted++}
$body=$d.SelectSingleNode('//w:body',$n);$removed=0
foreach($p in @($body.SelectNodes('w:p',$n))){if(-not (TextOf $p).Trim() -and -not $p.SelectSingleNode('.//w:drawing | .//w:pict | .//w:object | .//w:sectPr | .//w:fldChar | .//w:instrText',$n)){[void]$body.RemoveChild($p);$removed++}}
$headings=@('INTRODUCTION','RESEARCH METHODOLOGY','Data Process Modeling','Diagrams','Context Diagram','Data Flow Diagram','Use Case Diagram','Entity Relationship Diagram','Overall Description','Data Dictionary','Forms','Prototype','Gantt Chart')
$bodyParagraphs=0
foreach($p in $d.SelectNodes('//w:p',$n)){
 $texts=$p.SelectNodes('.//w:t',$n);if($texts.Count){$texts[0].InnerText=$texts[0].InnerText.TrimStart();$texts[$texts.Count-1].InnerText=$texts[$texts.Count-1].InnerText.TrimEnd();foreach($text in $texts){$text.InnerText=$text.InnerText -replace '[\t ]{2,}',' '}}
 $t=(TextOf $p).Trim();$inTable=$p.SelectSingleNode('ancestor::w:tc',$n);$isImage=$null -ne $p.SelectSingleNode('.//w:drawing | .//w:pict',$n)
 $pr=$p.SelectSingleNode('w:pPr',$n);if(-not $pr){$pr=Element 'w' 'pPr';[void]$p.PrependChild($pr)}
 foreach($tag in @('ind','spacing','jc','tabs','contextualSpacing','keepNext','keepLines','pageBreakBefore','snapToGrid')){foreach($old in @($pr.SelectNodes("w:$tag",$n))){[void]$pr.RemoveChild($old)}}
 $style=$pr.SelectSingleNode('w:pStyle',$n);$styleName=if($style){$style.GetAttribute('val',$n.LookupNamespace('w'))}else{''}
 $chapter=$t -match '^Chapter 3$|^RESEARCH METHODOLOGY$';$caption=$t -match '^(Figure|Table)\s+\d';$heading=(-not $inTable -and -not $caption -and (($styleName -match '^Heading' -and $t.Length -lt 110) -or $t -in $headings -or $t -match '^\d+\.0 [^.]{1,65}$'))
 if($style -and -not $heading -and -not $chapter){[void]$pr.RemoveChild($style)}
 $sp=Property $pr 'spacing';$jc=Property $pr 'jc';$ind=Property $pr 'ind'
 if($inTable){$firstRow=$p.SelectSingleNode('ancestor::w:tr',$n);$header=-not $firstRow.PreviousSibling -or -not ($firstRow.PreviousSibling.LocalName -eq 'tr');[void](Attr $sp 'before' 0);[void](Attr $sp 'after' 40);[void](Attr $sp 'line' 240);[void](Attr $sp 'lineRule' 'auto');[void](Attr $jc 'val' 'left');[void](Attr $ind 'firstLine' 0);$makeBold=$header}
 elseif($chapter){[void](Attr $jc 'val' 'center');[void](Attr $sp 'before' 0);[void](Attr $sp 'after' 120);[void](Attr $sp 'line' 360);[void](Attr $sp 'lineRule' 'auto');$makeBold=$true;[void](Property $pr 'keepNext')}
 elseif($heading){[void](Attr $jc 'val' 'left');[void](Attr $sp 'before' 200);[void](Attr $sp 'after' 80);[void](Attr $sp 'line' 240);[void](Attr $sp 'lineRule' 'auto');$makeBold=$true;[void](Property $pr 'keepNext')}
 elseif($caption){[void](Attr $jc 'val' $(if($t.StartsWith('Figure')){'center'}else{'left'}));[void](Attr $sp 'before' 80);[void](Attr $sp 'after' 120);[void](Attr $sp 'line' 240);[void](Attr $sp 'lineRule' 'auto');$makeBold=$false;if($t.StartsWith('Table')){[void](Property $pr 'keepNext')}}
 elseif($isImage){[void](Attr $jc 'val' 'center');[void](Attr $sp 'before' 80);[void](Attr $sp 'after' 80);[void](Attr $sp 'line' 240);[void](Attr $sp 'lineRule' 'auto');$makeBold=$false;$next=$p.NextSibling;if($next -and (TextOf $next).Trim() -match '^Figure\s+\d'){[void](Property $pr 'keepNext')}}
 else{[void](Attr $jc 'val' 'both');[void](Attr $sp 'before' 0);[void](Attr $sp 'after' 100);[void](Attr $sp 'line' 360);[void](Attr $sp 'lineRule' 'auto');[void](Attr $ind 'firstLine' 720);$makeBold=$false;$bodyParagraphs++}
 [void](Property $pr 'widowControl');$mark=Property $pr 'rPr';Bold $mark $makeBold
 foreach($run in $p.SelectNodes('.//w:r',$n)){$rp=$run.SelectSingleNode('w:rPr',$n);if(-not $rp){$rp=Element 'w' 'rPr';[void]$run.PrependChild($rp)};Bold $rp $makeBold;foreach($tag in @('spacing','position','w','kern')){foreach($old in @($rp.SelectNodes("w:$tag",$n))){[void]$rp.RemoveChild($old)}}}
}
# Limit figure dimensions to the page's available content area while retaining aspect ratio.
$n.AddNamespace('a','http://schemas.openxmlformats.org/drawingml/2006/main')
$section=$body.SelectSingleNode('w:sectPr',$n);$page=$section.SelectSingleNode('w:pgSz',$n);$margins=$section.SelectSingleNode('w:pgMar',$n)
$maxW=5486400L;$maxH=6858000L
if($page -and $margins){$width=[int]$page.GetAttribute('w',$n.LookupNamespace('w'))-[int]$margins.GetAttribute('left',$n.LookupNamespace('w'))-[int]$margins.GetAttribute('right',$n.LookupNamespace('w'));$height=[int]$page.GetAttribute('h',$n.LookupNamespace('w'))-[int]$margins.GetAttribute('top',$n.LookupNamespace('w'))-[int]$margins.GetAttribute('bottom',$n.LookupNamespace('w'));$maxW=[Math]::Min($maxW,$width*635);$maxH=[Math]::Min($maxH,($height-720)*635)}
foreach($inline in $d.SelectNodes('//wp:inline',$n)){$ext=$inline.SelectSingleNode('wp:extent',$n);$cx=[long]$ext.GetAttribute('cx');$cy=[long]$ext.GetAttribute('cy');$scale=[Math]::Min(1,[Math]::Min($maxW/$cx,$maxH/$cy));if($scale -lt 1){$cx=[long]($cx*$scale);$cy=[long]($cy*$scale);$ext.SetAttribute('cx',"$cx");$ext.SetAttribute('cy',"$cy");foreach($aext in $inline.SelectNodes('.//a:xfrm/a:ext',$n)){$aext.SetAttribute('cx',"$cx");$aext.SetAttribute('cy',"$cy")}}}
$e.Delete();$e=$z.CreateEntry('word/document.xml');$w=[IO.StreamWriter]::new($e.Open(),[Text.UTF8Encoding]::new($false));$w.Write($d.OuterXml);$w.Dispose()
"Removed $removed empty spacer paragraphs; converted $converted floating figures; normalized paragraph/table spacing and restricted bold to headings and table headers."
}finally{$z.Dispose()}
