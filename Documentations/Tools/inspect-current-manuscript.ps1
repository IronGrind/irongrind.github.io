$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=Split-Path $PSScriptRoot -Parent
$output=Join-Path $root 'Review Evidence/Current Manuscript Review'
New-Item -ItemType Directory -Path $output -Force | Out-Null
foreach($name in @('Chapter 1','Chapter 2','Chapter 3','Chapters 1-3 with Table of Contents')) {
 $path=Join-Path $root ($name+'.docx')
 $zip=[IO.Compression.ZipFile]::OpenRead($path)
 try {
  $reader=[IO.StreamReader]::new($zip.GetEntry('word/document.xml').Open())
  try {[xml]$doc=$reader.ReadToEnd()}finally{$reader.Dispose()}
  $ns=[Xml.XmlNamespaceManager]::new($doc.NameTable)
  $ns.AddNamespace('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main')
  $lines=[Collections.Generic.List[string]]::new();$i=0
  foreach($p in $doc.SelectNodes('//w:body//w:p',$ns)) {
   $i++;$text=($p.SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join ''
   if($text.Trim()){$lines.Add(('P{0:D4}: {1}' -f $i,$text))}
  }
  [IO.File]::WriteAllLines((Join-Path $output ($name+'.txt')),$lines,[Text.UTF8Encoding]::new($false))
  Write-Output "$name : $($lines.Count) nonempty paragraphs; $($zip.Entries.Count) package parts"
 }finally{$zip.Dispose()}
}
$svgSource='C:/Users/mycah/Downloads/final dfd2.drawio (1).svg'
$svgTarget=Join-Path $root 'Chapter 3 Diagrams/03-user-supplied-dfd.svg'
Copy-Item -LiteralPath $svgSource -Destination $svgTarget
$settings=[Xml.XmlReaderSettings]::new();$settings.DtdProcessing='Ignore';$settings.XmlResolver=$null
$reader=[Xml.XmlReader]::Create($svgSource,$settings)
try{$svg=[Xml.XmlDocument]::new();$svg.Load($reader)}finally{$reader.Dispose()}
[xml]$graph=$svg.DocumentElement.GetAttribute('content')
$graph.Save((Join-Path $root 'Chapter 3 Diagrams/03-user-supplied-dfd.drawio'))
$cells=$graph.SelectNodes('//mxCell')
$labels=[Collections.Generic.List[string]]::new()
foreach($cell in $cells){
 $label=[Net.WebUtility]::HtmlDecode(($cell.value -replace '<[^>]+>',' ')) -replace '\s+',' '
 if($label.Trim() -or $cell.edge -eq '1'){$labels.Add("$($cell.id) | $label | source=$($cell.source) target=$($cell.target) edge=$($cell.edge)")}
}
[IO.File]::WriteAllLines((Join-Path $output 'Supplied DFD cells.txt'),$labels,[Text.UTF8Encoding]::new($false))
Write-Output "DFD: $($cells.Count) cells; $($svg.DocumentElement.GetAttribute('width')) x $($svg.DocumentElement.GetAttribute('height'))"
