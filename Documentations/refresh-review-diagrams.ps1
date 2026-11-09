$ErrorActionPreference='Stop'
# Render role/use-case figures, schema-style ERD panels, and Gane-Sarson figures.
$source=Get-Content -Raw (Join-Path $PSScriptRoot 'build-chapter3-diagrams.ps1')
$definitions=$source.Substring(0,$source.IndexOf("Canvas 'Figure 2."))
$start=$source.IndexOf("Canvas 'Figure 4.")
$end=$source.IndexOf('# Extract the physical schema')
Invoke-Expression ($definitions+$source.Substring($start,$end-$start))
$erdStart=$source.IndexOf('# Extract the physical schema')
Invoke-Expression ($definitions+$source.Substring($erdStart))
# Render Gane-Sarson figures without invoking the obsolete relationship mapping.
$source=Get-Content -Raw (Join-Path $PSScriptRoot 'Chapter 3 Diagrams/gane-sarson.ps1')
$end=$source.IndexOf('& (Join-Path $PSScriptRoot')
if($end -lt 0){$end=$source.IndexOf('$path=Join-Path')}
Invoke-Expression $source.Substring(0,$end)
Add-Type -AssemblyName System.IO.Compression
$path=Join-Path $PSScriptRoot 'Chapter 3.docx'
$zip=[IO.Compression.ZipArchive]::new([IO.File]::Open($path,'Open','ReadWrite'),[IO.Compression.ZipArchiveMode]::Update)
try {
 $entry=$zip.GetEntry('word/document.xml');$r=[IO.StreamReader]::new($entry.Open());$doc=[Xml.XmlDocument]::new();$doc.PreserveWhitespace=$true;$doc.LoadXml($r.ReadToEnd());$r.Dispose()
 $r=[IO.StreamReader]::new($zip.GetEntry('word/_rels/document.xml.rels').Open());[xml]$rels=$r.ReadToEnd();$r.Dispose()
 $ns=[Xml.XmlNamespaceManager]::new($doc.NameTable)
 $ns.AddNamespace('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main');$ns.AddNamespace('a','http://schemas.openxmlformats.org/drawingml/2006/main');$ns.AddNamespace('r','http://schemas.openxmlformats.org/officeDocument/2006/relationships');$ns.AddNamespace('wp','http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing')
 foreach($b in @($doc.SelectNodes('//a:blip[starts-with(@r:embed,"rIdGaneDfd")]',$ns))){$p=$b;while($p.LocalName -ne 'p'){$p=$p.ParentNode};[void]$p.ParentNode.RemoveChild($p)}
 $images=@{'rId9'='02-context.png';'rId10'='03-data-flow-1.png';'rId11'='03-data-flow-2.png';'rId12'='03-data-flow-3.png';'rId13'='03-data-flow-4.png';'rId14'='03-data-flow-5.png';'rId15'='04-use-cases.png';'rId34'='20-staff-operations.png'}
 foreach($rid in $images.Keys){
  $rel=$rels.Relationships.Relationship|Where-Object Id -EQ $rid
  $part='word/'+$rel.Target;$old=$zip.GetEntry($part);$old.Delete()
  $entryImage=$zip.CreateEntry($part);$s=$entryImage.Open();$file=Join-Path $PSScriptRoot ('Chapter 3 Diagrams/'+$images[$rid]);$bytes=[IO.File]::ReadAllBytes($file);$s.Write($bytes,0,$bytes.Length);$s.Dispose()
  $b=$doc.SelectSingleNode("//a:blip[@r:embed='$rid']",$ns);$p=$b;while($p.LocalName -ne 'p'){$p=$p.ParentNode}
  $im=[Drawing.Image]::FromFile($file);$cx=[long]5486400;$cy=[long]($cx*$im.Height/$im.Width);$im.Dispose()
  foreach($extent in $p.SelectNodes('.//wp:extent | .//a:xfrm/a:ext',$ns)){$extent.SetAttribute('cx',"$cx");$extent.SetAttribute('cy',"$cy")}
 }
 $entry=$zip.GetEntry('word/document.xml');$s=$entry.Open();$s.SetLength(0);$w=[IO.StreamWriter]::new($s);$doc.Save($w);$w.Dispose()
}finally{$zip.Dispose()}
& (Join-Path $PSScriptRoot 'update-schema-erd.ps1')
Write-Output 'Updated context, five DFD panels, use cases, and staff operations; removed duplicate diagram panels.'
