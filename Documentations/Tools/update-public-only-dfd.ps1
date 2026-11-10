$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$chapter = Join-Path $root 'Documentations\Chapter 3.docx'
$diagrams = Join-Path $root 'Documentations\Chapter 3 Diagrams'
$backupDir = Join-Path $root 'Documentations\Review Backups\public-only-dfd-20261111'
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
$backup = Join-Path $backupDir 'Chapter 3 before public-only DFD.docx'
if (-not (Test-Path $backup)) { Copy-Item -LiteralPath $chapter -Destination $backup }

function Read-ZipXml([string]$archivePath, [string]$entryName) {
    $archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        $entry = $archive.GetEntry($entryName)
        if (-not $entry) { throw "Missing package entry $entryName" }
        $stream = $entry.Open()
        try { $doc = [Xml.XmlDocument]::new(); $doc.PreserveWhitespace = $true; $doc.Load($stream); return $doc } finally { $stream.Dispose() }
    } finally { $archive.Dispose() }
}
function Replace-ZipEntry([string]$archivePath, [string]$entryName, [byte[]]$bytes) {
    $archive = [IO.Compression.ZipFile]::Open($archivePath, [IO.Compression.ZipArchiveMode]::Update)
    try {
        $old = $archive.GetEntry($entryName)
        if ($old) { $old.Delete() }
        $entry = $archive.CreateEntry($entryName, [IO.Compression.CompressionLevel]::Optimal)
        $stream = $entry.Open()
        try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
    } finally { $archive.Dispose() }
}
function Save-ZipXml([string]$archivePath, [string]$entryName, [Xml.XmlDocument]$doc) {
    $memory = [IO.MemoryStream]::new()
    try {
        $settings = [Xml.XmlWriterSettings]::new(); $settings.Encoding = [Text.UTF8Encoding]::new($false); $settings.Indent = $false
        $writer = [Xml.XmlWriter]::Create($memory, $settings)
        try { $doc.Save($writer) } finally { $writer.Dispose() }
        Replace-ZipEntry $archivePath $entryName $memory.ToArray()
    } finally { $memory.Dispose() }
}

for ($i = 1; $i -le 5; $i++) {
    $source = Join-Path $diagrams "03-data-flow-$i.png"
    if (-not (Test-Path $source)) { throw "Missing public-only DFD panel $source" }
    Replace-ZipEntry $chapter "word/media/03-data-flow-$i.png" ([IO.File]::ReadAllBytes($source))
}

$doc = Read-ZipXml $chapter 'word/document.xml'
$ns = [Xml.XmlNamespaceManager]::new($doc.NameTable)
$ns.AddNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
$paragraphs = @($doc.SelectNodes('//w:body/w:p', $ns))
foreach ($paragraph in $paragraphs) {
    $text = ($paragraph.SelectNodes('.//w:t', $ns) | ForEach-Object InnerText) -join ''
    if ($text -eq 'Figures 3a-e expand the system into nine processes; Figure 3f identifies the additional administrator login-security stores supporting User Login.') {
        $paragraph.SelectNodes('.//w:t', $ns)[0].InnerText = 'Figures 3a-e expand the system into nine processes. The DFD data-store symbols identify public application tables only; authentication records and private security stores are outside this view.'
    }
    if ($text -eq "Figure 3a-e expands the context process into the system's nine functional processes using Gane-Sarson notation. The five panels continue one Level 1 model. Rectangles identify external actors, rounded boxes identify numbered processes, and divided symbols identify individually named data stores. Every arrow is directional and labeled. Processes 1.0 and 5.0 include the current device-approval and mobile-scanner stores; Figure 3f isolates the administrator security stores for easier reading.") {
        $paragraph.SelectNodes('.//w:t', $ns)[0].InnerText = "Figure 3a-e expands the context process into nine functional processes using Gane-Sarson notation. The five panels continue one Level 1 model. Rectangles identify external actors, rounded boxes identify numbered processes, and divided symbols identify individually named public application tables. Every arrow is directional and labeled. Authentication and private security records support implementation workflows but are intentionally omitted from the DFD data-store symbols."
    }
    if ($text -like 'Figure 3f. User Login - Additional Individual Security Stores*') {
        $imageParagraph = $paragraph.SelectSingleNode('following-sibling::w:p[1]', $ns)
        $descriptionParagraph = $imageParagraph.SelectSingleNode('following-sibling::w:p[1]', $ns)
        if ($imageParagraph) { $imageParagraph.ParentNode.RemoveChild($imageParagraph) | Out-Null }
        if ($descriptionParagraph) { $descriptionParagraph.ParentNode.RemoveChild($descriptionParagraph) | Out-Null }
        $paragraph.ParentNode.RemoveChild($paragraph) | Out-Null
    }
}
Save-ZipXml $chapter 'word/document.xml' $doc
Write-Output 'Updated Chapter 3 DFD panel images and removed the private-store DFD supplement.'
