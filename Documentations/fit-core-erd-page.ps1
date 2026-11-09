param([string]$DocumentPath=(Join-Path $PSScriptRoot 'Chapter 3.docx'))
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression
$work=Join-Path ([IO.Path]::GetTempPath()) ('chapter3-erd-page-'+[guid]::NewGuid().ToString('N')+'.docx')
Copy-Item -LiteralPath $DocumentPath -Destination $work
try{
 $zip=[IO.Compression.ZipArchive]::new([IO.File]::Open($work,'Open','ReadWrite'),[IO.Compression.ZipArchiveMode]::Update)
 try{
  $entry=$zip.GetEntry('word/document.xml');$r=[IO.StreamReader]::new($entry.Open());$d=[Xml.XmlDocument]::new();$d.PreserveWhitespace=$true;$d.LoadXml($r.ReadToEnd());$r.Dispose()
  $w='http://schemas.openxmlformats.org/wordprocessingml/2006/main';$n=[Xml.XmlNamespaceManager]::new($d.NameTable);$n.AddNamespace('w',$w);$n.AddNamespace('a','http://schemas.openxmlformats.org/drawingml/2006/main');$n.AddNamespace('wp','http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing')
  function Txt($p){return ($p.SelectNodes('.//w:t',$n)|ForEach-Object InnerText)-join ''}
  function Attr($node,$name,$value){[void]$node.SetAttribute($name,$w,$value)}
  $paras=@($d.SelectNodes('//w:body/w:p',$n));$heading=@($paras|Where-Object {(Txt $_).Trim() -eq 'Entity Relationship Diagram'});$caption=@($paras|Where-Object {(Txt $_).Trim() -match '^Figure 5(?:a-[cd])?\.'})
  if($heading.Count -ne 1 -or $caption.Count -ne 1){throw 'Cannot unambiguously locate the ERD section.'}
  $pictures=[Collections.Generic.List[object]]::new();$empty=[Collections.Generic.List[object]]::new();$node=$heading[0].NextSibling
  while($node -and -not [object]::ReferenceEquals($node,$caption[0])){
   if($node.LocalName -eq 'p'){
    if($node.SelectSingleNode('.//a:blip',$n)){$pictures.Add($node)}
    elseif(-not (Txt $node).Trim()){$empty.Add($node)}
    else{throw 'Unexpected text between ERD heading and caption.'}
   };$node=$node.NextSibling
  }
  if(-not $node -or -not $pictures.Count){throw 'ERD image/caption ordering is invalid.'}
  $picture=$pictures[0];$removed=$pictures.Count-1
  # Locate old panels by their section, because Word may renumber relationship IDs.
  foreach($p in @($pictures|Select-Object -Skip 1)+@($empty)){[void]$p.ParentNode.RemoveChild($p)}
  $after=$caption[0].NextSibling;while($after -and $after.LocalName -ne 'p'){$after=$after.NextSibling};if(-not $after){throw 'Missing explanation after the ERD caption.'}
  foreach($item in @(@{P=$heading[0];Kind='heading'},@{P=$picture;Kind='picture'},@{P=$caption[0];Kind='caption'})){
   $p=$item.P;$old=$p.SelectSingleNode('w:pPr',$n);$pr=$d.CreateElement('w','pPr',$w)
   if($item.Kind -eq 'heading'){$style=$d.CreateElement('w','pStyle',$w);Attr $style 'val' 'Heading3';[void]$pr.AppendChild($style)}
   if($item.Kind -ne 'caption'){[void]$pr.AppendChild($d.CreateElement('w','keepNext',$w))}
   [void]$pr.AppendChild($d.CreateElement('w','keepLines',$w))
   if($item.Kind -eq 'heading'){[void]$pr.AppendChild($d.CreateElement('w','pageBreakBefore',$w))}
   $spacing=$d.CreateElement('w','spacing',$w);Attr $spacing 'before' '0';Attr $spacing 'after' $(if($item.Kind -eq 'heading'){'100'}elseif($item.Kind -eq 'picture'){'80'}else{'0'});Attr $spacing 'line' '240';Attr $spacing 'lineRule' 'auto';[void]$pr.AppendChild($spacing)
   $ind=$d.CreateElement('w','ind',$w);foreach($key in @('left','right','firstLine')){Attr $ind $key '0'};[void]$pr.AppendChild($ind)
   $align=$d.CreateElement('w','jc',$w);Attr $align 'val' $(if($item.Kind -eq 'heading'){'left'}else{'center'});[void]$pr.AppendChild($align)
   if($old -and $old.SelectSingleNode('w:rPr',$n)){[void]$pr.AppendChild($old.SelectSingleNode('w:rPr',$n).CloneNode($true))}
   if($old){[void]$p.ReplaceChild($pr,$old)}else{[void]$p.PrependChild($pr)}
   foreach($cachedBreak in @($p.SelectNodes('.//w:lastRenderedPageBreak',$n))){[void]$cachedBreak.ParentNode.RemoveChild($cachedBreak)}
  }
  $afterPr=$after.SelectSingleNode('w:pPr',$n);if(-not $afterPr){$afterPr=$d.CreateElement('w','pPr',$w);[void]$after.PrependChild($afterPr)}
  if(-not $afterPr.SelectSingleNode('w:pageBreakBefore',$n)){
   $pb=$d.CreateElement('w','pageBreakBefore',$w);$preceding=$afterPr.SelectNodes('w:pStyle | w:keepNext | w:keepLines',$n)
   if($preceding.Count){[void]$afterPr.InsertAfter($pb,$preceding[$preceding.Count-1])}else{[void]$afterPr.PrependChild($pb)}
  }
  # Fit the 6 x 7 inch figure and allow a full inch for its heading/caption.
  $section=$d.SelectSingleNode('//w:body/w:sectPr',$n);$pageSize=$section.SelectSingleNode('w:pgSz',$n);$margins=$section.SelectSingleNode('w:pgMar',$n)
  $usableW=[int]$pageSize.GetAttribute('w',$w)-[int]$margins.GetAttribute('left',$w)-[int]$margins.GetAttribute('right',$w)
  $usableH=[int]$pageSize.GetAttribute('h',$w)-[int]$margins.GetAttribute('top',$w)-[int]$margins.GetAttribute('bottom',$w)
  $cx=[long][Math]::Min(5486400,$usableW*635);$cy=[long]($cx*2100/1800);$maxH=[long](($usableH-1440)*635)
  if($cy -gt $maxH){$cy=$maxH;$cx=[long]($cy*1800/2100)}
  foreach($extent in $picture.SelectNodes('.//wp:extent | .//a:xfrm/a:ext',$n)){$extent.SetAttribute('cx',"$cx");$extent.SetAttribute('cy',"$cy")}
  $remaining=@();$node=$heading[0].NextSibling;while(-not [object]::ReferenceEquals($node,$caption[0])){if($node.SelectSingleNode('.//a:blip',$n)){$remaining+=,$node};$node=$node.NextSibling}
  if($remaining.Count -ne 1 -or $cy+914400 -gt $usableH*635){throw 'The ERD page does not fit its available area.'}
  $s=$entry.Open();$s.SetLength(0);$writer=[IO.StreamWriter]::new($s,[Text.UTF8Encoding]::new($false));try{$d.Save($writer)}finally{$writer.Dispose()}
 }finally{$zip.Dispose()}
 Copy-Item -LiteralPath $work -Destination $DocumentPath -Force
 "Placed the complete ERD and caption on a dedicated page; removed $removed old panel(s); image size $([Math]::Round($cx/914400,2)) x $([Math]::Round($cy/914400,2)) inches."
}finally{if(Test-Path -LiteralPath $work){Remove-Item -LiteralPath $work -Force}}
