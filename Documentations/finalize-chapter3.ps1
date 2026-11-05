$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.Drawing
$zip=[IO.Compression.ZipArchive]::new([IO.File]::Open((Join-Path (Get-Location) 'Documentations\Chapter 3.docx'),'Open','ReadWrite'),[IO.Compression.ZipArchiveMode]::Update)
$entry=$zip.GetEntry('word/document.xml');$reader=[IO.StreamReader]::new($entry.Open());$doc=[Xml.XmlDocument]::new();$doc.PreserveWhitespace=$true;$doc.LoadXml($reader.ReadToEnd());$reader.Dispose()
$ns=[Xml.XmlNamespaceManager]::new($doc.NameTable);$ns.AddNamespace('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main');$ns.AddNamespace('a','http://schemas.openxmlformats.org/drawingml/2006/main');$ns.AddNamespace('r','http://schemas.openxmlformats.org/officeDocument/2006/relationships')
$re=$zip.GetEntry('word/_rels/document.xml.rels');$r=[IO.StreamReader]::new($re.Open());[xml]$rels=$r.ReadToEnd();$r.Dispose()
$images=@{'rId12'='02-context.png';'rId13'='03-data-flow.png';'rId14'='04-use-cases.png';'rId16'='05-erd-1.png';'rIdChapter3Erd2'='05-erd-2.png';'rIdChapter3Erd3'='05-erd-3.png';'rId33'='20-staff-operations.png'}
$id=5000
foreach($rid in $images.Keys){
 $rel=$rels.DocumentElement.ChildNodes|Where-Object {$_.Id -eq $rid};$part='word/'+$rel.Target;$old=$zip.GetEntry($part);$old.Delete();$e=$zip.CreateEntry($part);$s=$e.Open();$file=Join-Path (Get-Location) "Documentations\Chapter 3 Diagrams\$($images[$rid])";$bytes=[IO.File]::ReadAllBytes($file);$s.Write($bytes,0,$bytes.Length);$s.Dispose()
 $blip=$doc.SelectSingleNode("//a:blip[@r:embed='$rid']",$ns);$p=$blip;while($p.LocalName -ne 'p'){$p=$p.ParentNode}
 foreach($drawing in @($p.SelectNodes('.//w:drawing',$ns))){[void]$drawing.ParentNode.RemoveChild($drawing)}
 $text=($p.SelectNodes('.//w:t',$ns)|ForEach-Object {$_.InnerText}) -join ''
 if($text.Trim()){$np=$doc.CreateElement('w','p',$ns.LookupNamespace('w'));[void]$p.ParentNode.InsertAfter($np,$p);$p=$np}else{foreach($child in @($p.ChildNodes)){[void]$p.RemoveChild($child)}}
 $img=[Drawing.Image]::FromFile($file);$cx=[long]5486400;$cy=[long]($cx*$img.Height/$img.Width);if($cy -gt 6858000){$cy=6858000;$cx=[long]($cy*$img.Width/$img.Height)};$img.Dispose();$id++
 $fragment=$doc.CreateDocumentFragment()
 $fragment.InnerXml=@"
<w:pPr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:spacing w:before="0" w:after="0"/><w:jc w:val="center"/></w:pPr>
<w:r xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:drawing><wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" distT="0" distB="0" distL="0" distR="0"><wp:extent cx="$cx" cy="$cy"/><wp:docPr id="$id" name="$($images[$rid])"/><wp:cNvGraphicFramePr/><a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:nvPicPr><pic:cNvPr id="0" name="$($images[$rid])"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:embed="$rid"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>
"@
 [void]$p.AppendChild($fragment)
}
$entry.Delete();$e=$zip.CreateEntry('word/document.xml');$w=[IO.StreamWriter]::new($e.Open(),[Text.UTF8Encoding]::new($false));$w.Write($doc.OuterXml);$w.Dispose();$zip.Dispose()
'Refreshed seven figures and converted them to inline Word images to avoid overlapping text.'
