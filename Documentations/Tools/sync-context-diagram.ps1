$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = Split-Path $PSScriptRoot -Parent
$diagram = Join-Path $root 'Chapter 3 Diagrams\02-context.png'
$docx = Join-Path $root 'Chapter 3.docx'
$backupDir = Join-Path $root 'Review Backups'
[void][IO.Directory]::CreateDirectory($backupDir)
$backup = Join-Path $backupDir ('Chapter 3 before context refresh ' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.docx')
Copy-Item -LiteralPath $docx -Destination $backup
$archive = [IO.Compression.ZipFile]::Open($docx,[IO.Compression.ZipArchiveMode]::Update)
try {
  $relsEntry = $archive.GetEntry('word/_rels/document.xml.rels')
  $reader = [IO.StreamReader]::new($relsEntry.Open())
  [xml]$rels = $reader.ReadToEnd(); $reader.Dispose()
  $relationship = $rels.Relationships.Relationship | Where-Object Id -EQ 'rId9'
  if (-not $relationship -or $relationship.Target -ne 'media/image2.png') { throw 'The expected Chapter 3 context image relationship rId9 was not found.' }

  $imageEntry = $archive.GetEntry('word/media/image2.png')
  if (-not $imageEntry) { throw 'The context image part is missing from Chapter 3.docx.' }
  $imageEntry.Delete()
  $newImage = $archive.CreateEntry('word/media/image2.png',[IO.Compression.CompressionLevel]::Optimal)
  $imageStream = $newImage.Open(); $bytes = [IO.File]::ReadAllBytes($diagram)
  $imageStream.Write($bytes,0,$bytes.Length); $imageStream.Dispose()

  $documentEntry = $archive.GetEntry('word/document.xml')
  $reader = [IO.StreamReader]::new($documentEntry.Open())
  $xml = [Xml.XmlDocument]::new(); $xml.PreserveWhitespace = $true; $xml.LoadXml($reader.ReadToEnd()); $reader.Dispose()
  $ns = [Xml.XmlNamespaceManager]::new($xml.NameTable)
  $ns.AddNamespace('a','http://schemas.openxmlformats.org/drawingml/2006/main')
  $ns.AddNamespace('r','http://schemas.openxmlformats.org/officeDocument/2006/relationships')
  $ns.AddNamespace('wp','http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing')
  $blip = $xml.SelectSingleNode('//a:blip[@r:embed="rId9"]',$ns)
  if (-not $blip) { throw 'The context image reference was not found in the Chapter 3 document.' }
  $drawingContainer = $blip
  while ($drawingContainer -and $drawingContainer.LocalName -notin @('inline','anchor')) { $drawingContainer = $drawingContainer.ParentNode }
  $extent = $drawingContainer.SelectSingleNode('./wp:extent',$ns)
  if (-not $extent) { throw 'The context figure dimensions were not found.' }
  $extent.SetAttribute('cx','5486400'); $extent.SetAttribute('cy','1895200')
  $documentEntry.Delete()
  $newDocument = $archive.CreateEntry('word/document.xml',[IO.Compression.CompressionLevel]::Optimal)
  $stream = $newDocument.Open(); $settings = [Xml.XmlWriterSettings]::new(); $settings.Encoding = [Text.UTF8Encoding]::new($false); $settings.Indent = $false
  $writer = [Xml.XmlWriter]::Create($stream,$settings); $xml.Save($writer); $writer.Dispose(); $stream.Dispose()
} finally { $archive.Dispose() }
Write-Output "Updated Chapter 3 context figure; backup: $backup"
