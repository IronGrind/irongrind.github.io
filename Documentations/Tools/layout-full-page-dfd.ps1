$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=Split-Path $PSScriptRoot -Parent
$backup=Join-Path $root ('Review Backups/landscape-dfd-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $backup -Force|Out-Null
$report=[Collections.Generic.List[string]]::new()
foreach($name in @('Chapter 3','Chapters 1-3 with Table of Contents')){
 $path=Join-Path $root ($name+'.docx');Copy-Item -LiteralPath $path -Destination (Join-Path $backup ($name+'.docx'))
 $stage=Join-Path $backup ($name+' staged.docx');Copy-Item -LiteralPath $path -Destination $stage
 $zip=[IO.Compression.ZipFile]::Open($stage,'Update')
 try{
  $rd=[IO.StreamReader]::new($zip.GetEntry('word/document.xml').Open());try{[xml]$doc=$rd.ReadToEnd()}finally{$rd.Dispose()}
  $ns=[Xml.XmlNamespaceManager]::new($doc.NameTable)
  foreach($pair in @(@('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main'),@('a','http://schemas.openxmlformats.org/drawingml/2006/main'),@('wp','http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing'))){$ns.AddNamespace($pair[0],$pair[1])}
  $w=$ns.LookupNamespace('w')
  function TextOf($p){($p.SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join ''}
  function Child($node,$name){$child=$node.SelectSingleNode('w:'+$name,$ns);if(-not $child){$child=$doc.CreateElement('w',$name,$w);[void]$node.AppendChild($child)};return ,$child}
  function Attr($node,$name,$value){[void]$node.SetAttribute($name,$w,[string]$value)}
  $allTextBefore=@($doc.SelectNodes('//w:t',$ns)|ForEach-Object InnerText)-join "`n"
  $tablesBefore=@($doc.SelectNodes('//w:tbl',$ns)|ForEach-Object OuterXml)-join "`n"
  $heading=@($doc.SelectNodes('//w:body/w:p',$ns)|Where-Object{(TextOf $_).Trim() -eq 'Data Flow Diagram'})
  $caption=@($doc.SelectNodes('//w:body/w:p',$ns)|Where-Object{(TextOf $_).Trim() -eq 'Figure 3. Level 1 Data Flow Diagram - Gane-Sarson'})
  if($heading.Count -ne 1 -or $caption.Count -ne 1){throw 'DFD boundaries not unique'}
  $picture=$heading[0].NextSibling
  if(-not $picture.SelectSingleNode('.//wp:inline',$ns) -or $picture.NextSibling -ne $caption[0]){throw 'Unexpected DFD image layout'}
  $following=$caption[0].NextSibling
  $section=$caption[0].SelectSingleNode('following::w:sectPr[1]',$ns)
  if(-not $section){throw 'No following section properties'}
  $landscape=$section.CloneNode($true)
  Attr (Child $landscape 'type') 'val' 'nextPage'
  $size=Child $landscape 'pgSz';Attr $size 'w' 15840;Attr $size 'h' 12240;Attr $size 'orient' 'landscape';$size.RemoveAttribute('code',$w)
  $margin=Child $landscape 'pgMar';foreach($side in @('top','bottom','left','right')){Attr $margin $side 720};Attr $margin 'header' 360;Attr $margin 'footer' 360
  $numbering=$landscape.SelectSingleNode('w:pgNumType',$ns);if($numbering){$numbering.RemoveAttribute('start',$w)}
  $captionProps=Child $caption[0] 'pPr';[void]$captionProps.AppendChild($landscape)
  # The original section still governs the prose that follows and keeps its footer references.
  Attr (Child $section 'type') 'val' 'nextPage'
  $followingSize=$section.SelectSingleNode('w:pgSz',$ns)
  if($followingSize.GetAttribute('w',$w) -ge $followingSize.GetAttribute('h',$w)){throw 'Explanation section was not portrait'}
  foreach($p in @($heading[0],$picture,$caption[0])){
   $pr=Child $p 'pPr';$space=Child $pr 'spacing';Attr $space 'before' 0;Attr $space 'after' 0;Attr $space 'line' 240;Attr $space 'lineRule' 'auto'
   Attr (Child $pr 'jc') 'val' 'center'
   foreach($key in @('pageBreakBefore','keepNext','keepLines')){$node=$pr.SelectSingleNode('w:'+$key,$ns);if($node){[void]$pr.RemoveChild($node)}}
   foreach($br in @($p.SelectNodes('.//w:br[@w:type="page"] | .//w:lastRenderedPageBreak',$ns))){[void]$br.ParentNode.RemoveChild($br)}
  }
  Attr (Child (Child $heading[0] 'pPr') 'keepNext') 'val' 1
  Attr (Child (Child $picture 'pPr') 'keepNext') 'val' 1
  foreach($run in $picture.SelectNodes('.//w:r',$ns)){Attr (Child (Child $run 'rPr') 'sz') 'val' 2}
  $cx=9144000;$cy=[long][Math]::Round($cx*3755.0/5527.0)
  foreach($extent in $picture.SelectNodes('.//wp:extent | .//a:xfrm/a:ext',$ns)){$extent.SetAttribute('cx',[string]$cx);$extent.SetAttribute('cy',[string]$cy)}
  if((@($doc.SelectNodes('//w:t',$ns)|ForEach-Object InnerText)-join "`n") -cne $allTextBefore){throw 'Manuscript wording changed'}
  if((@($doc.SelectNodes('//w:tbl',$ns)|ForEach-Object OuterXml)-join "`n") -cne $tablesBefore){throw 'Tables changed'}
  $zip.GetEntry('word/document.xml').Delete();$wr=[IO.StreamWriter]::new($zip.CreateEntry('word/document.xml').Open(),[Text.UTF8Encoding]::new($false));try{$doc.Save($wr)}finally{$wr.Dispose()}
 }finally{$zip.Dispose()}
 Copy-Item -LiteralPath $stage -Destination $path -Force
 $report.Add("$name : one dedicated 11 x 8.5 inch landscape DFD section; image 10 inches wide with preserved aspect ratio; explanation begins in the next portrait section; text and tables unchanged; footer references retained; no page-number restart added.")
}
$report.Add('Backup: '+$backup)
$report|Set-Content -Encoding UTF8 -LiteralPath (Join-Path $root 'Review Evidence/DFD Landscape Layout Verification.txt')
$report
