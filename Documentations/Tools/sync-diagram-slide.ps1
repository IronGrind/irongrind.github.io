$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=Split-Path $PSScriptRoot -Parent
$path=Join-Path $root 'Defense/Capstone Presentation.pptx'
$backup=Join-Path $root 'Review Backups/non-dfd-diagrams-20261111/Capstone Presentation.pptx'
if(-not(Test-Path $backup)){Copy-Item -LiteralPath $path -Destination $backup}
$markdown=[IO.File]::ReadAllText((Join-Path $root 'Defense/Capstone Presentation.md'))
$section=[regex]::Match($markdown,'(?ms)^## Slide 13 [^\r\n]+\r?\n(.*?)(?=^## )').Groups[1].Value
$bullets=@([regex]::Matches($section.Split(@('Speaker notes:'),[StringSplitOptions]::None)[0],'(?m)^- (.+)$')|ForEach-Object {$_.Groups[1].Value.Trim()})
$notes=$section.Substring($section.IndexOf('Speaker notes:')+14).Trim()
if($bullets.Count -ne 5 -or $notes.Length -lt 100){throw 'Unexpected slide source'}
$zip=[IO.Compression.ZipFile]::Open($path,'Update')
try{
 foreach($part in @('ppt/slides/slide13.xml','ppt/notesSlides/notesSlide13.xml')){
  $reader=[IO.StreamReader]::new($zip.GetEntry($part).Open());$xml=[Xml.XmlDocument]::new();$xml.PreserveWhitespace=$true;$xml.LoadXml($reader.ReadToEnd());$reader.Dispose()
  $ns=[Xml.XmlNamespaceManager]::new($xml.NameTable);$ns.AddNamespace('p','http://schemas.openxmlformats.org/presentationml/2006/main');$ns.AddNamespace('a','http://schemas.openxmlformats.org/drawingml/2006/main')
  $shape=if($part -match '/slides/'){$xml.SelectNodes('//p:sp',$ns)|Where-Object {($_.SelectNodes('.//a:t',$ns).InnerText -join '') -match 'Twelve public|Figure 5 shows twelve'}}else{$xml.SelectNodes('//p:sp',$ns)|Where-Object {$_.SelectSingleNode('p:nvSpPr/p:nvPr/p:ph[@type="body"]',$ns)}}
  if(@($shape).Count -ne 1){throw "Ambiguous slide text: $part"}
  $body=$shape.SelectSingleNode('p:txBody',$ns);$paragraphs=@($body.SelectNodes('a:p',$ns));$template=$paragraphs[0].CloneNode($true);foreach($p in $paragraphs){[void]$body.RemoveChild($p)}
  $values=if($part -match '/slides/'){$bullets}else{@($notes)}
  foreach($value in $values){$p=$template.CloneNode($true);$ts=@($p.SelectNodes('.//a:t',$ns));if(-not $ts.Count){throw 'Missing text template'};$ts[0].InnerText=$value;foreach($t in @($ts|Select-Object -Skip 1)){$t.InnerText=''};[void]$body.AppendChild($p)}
  $entry=$zip.GetEntry($part);$entry.Delete();$stream=$zip.CreateEntry($part).Open();$writer=[IO.StreamWriter]::new($stream,[Text.UTF8Encoding]::new($false));$xml.Save($writer);$writer.Dispose()
 }
}finally{$zip.Dispose()}
'Synchronized slide 13 and its speaker notes; other slide parts preserved.'
