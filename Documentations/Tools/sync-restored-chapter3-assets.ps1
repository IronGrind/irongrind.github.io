param()
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$diagrams = Join-Path $root 'Documentations\Chapter 3 Diagrams'
$backupDir = Join-Path $root 'Documentations\Review Backups\old-layout-restore-before'
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

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
function Read-ZipXml([string]$archivePath, [string]$entryName) {
    $archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        $entry = $archive.GetEntry($entryName)
        if (-not $entry) { throw "Missing package entry $entryName" }
        $stream = $entry.Open()
        try { $doc = [Xml.XmlDocument]::new(); $doc.PreserveWhitespace = $true; $doc.Load($stream); return $doc } finally { $stream.Dispose() }
    } finally { $archive.Dispose() }
}
function Save-ZipXml([string]$archivePath, [string]$entryName, [Xml.XmlDocument]$doc) {
    $memory = [IO.MemoryStream]::new()
    try {
        $settings = [Xml.XmlWriterSettings]::new()
        $settings.Encoding = [Text.UTF8Encoding]::new($false)
        $settings.Indent = $false
        $writer = [Xml.XmlWriter]::Create($memory, $settings)
        try { $doc.Save($writer) } finally { $writer.Dispose() }
        Replace-ZipEntry $archivePath $entryName $memory.ToArray()
    } finally { $memory.Dispose() }
}

$chapter = Join-Path $root 'Documentations\Chapter 3.docx'
$chapterBackup = Join-Path $backupDir 'Chapter 3 before final DFD image sync.docx'
if (-not (Test-Path $chapterBackup)) { Copy-Item -LiteralPath $chapter -Destination $chapterBackup }
for ($i = 1; $i -le 5; $i++) {
    $src = Join-Path $diagrams "03-data-flow-$i.png"
    if (-not (Test-Path $src)) { throw "Missing rendered DFD panel $src" }
    Replace-ZipEntry $chapter "word/media/03-data-flow-$i.png" ([IO.File]::ReadAllBytes($src))
}

$pptx = Join-Path $root 'Documentations\Defense\Capstone Presentation.pptx'
$pptxBackup = Join-Path $backupDir 'Capstone Presentation before final figure sync.pptx'
if (-not (Test-Path $pptxBackup)) { Copy-Item -LiteralPath $pptx -Destination $pptxBackup }
$slidePath = 'ppt/slides/slide13.xml'
$slide = Read-ZipXml $pptx $slidePath
$ns = [Xml.XmlNamespaceManager]::new($slide.NameTable)
$ns.AddNamespace('a', 'http://schemas.openxmlformats.org/drawingml/2006/main')
$bullet = $slide.SelectNodes('//a:t', $ns) | Where-Object { $_.InnerText -in @('Keys, constraints and relationships support consistency', 'Figures 5a-c main relationships; Figure 5d security stores') } | Select-Object -First 1
if (-not $bullet) { throw 'Expected slide 13 data-model bullet was not found.' }
$bullet.InnerText = 'Figures 5a-c main relationships; Figure 5d security stores'
Save-ZipXml $pptx $slidePath $slide

$notes13Path = 'ppt/notesSlides/notesSlide13.xml'
$notes13 = Read-ZipXml $pptx $notes13Path
$ns = [Xml.XmlNamespaceManager]::new($notes13.NameTable)
$ns.AddNamespace('a', 'http://schemas.openxmlformats.org/drawingml/2006/main')
$old13 = $notes13.SelectNodes('//a:t', $ns) | Where-Object { $_.InnerText -match '^(The current Chapter 3 manuscript documents 18 application-owned tables|Chapter 3 uses the original figure layout)' } | Select-Object -First 1
if (-not $old13) { throw 'Expected Chapter 3 speaker note on slide 13 was not found.' }
$old13.InnerText = 'Chapter 3 uses the original figure layout, restored before the simplified ERD was introduced. The nine-process Level 1 DFD is shown in Figures 3a-e, with Figure 3f isolating administrator login-security stores D15-D17. Figures 5a-c show the original fifteen-table, twenty-one-foreign-key physical relationship model; Figure 5d adds the three administrator-security tables and six references to managed Auth tables. The simplified public-schema overview ERD remains omitted. The separate full Level 1 SVG is Documentations/Chapter 3 Diagrams/03-dfd-complete-gane-sarson.svg. The current dictionary covers eighteen application-owned tables, 201 fields and twenty-seven declared foreign keys. All twenty-three Word tables remain present. The five unique fields and approval composite unique pair remain documented. This documentation update does not change application or database behavior and has not been deployed. Final desktop Word pagination review remains pending. A separate member-device feature remains outside this chapter and is undeployed; user-supplied CLI output confirms admin trust deployment only, not live browser acceptance.'
Save-ZipXml $pptx $notes13Path $notes13

$notes15Path = 'ppt/notesSlides/notesSlide15.xml'
$notes15 = Read-ZipXml $pptx $notes15Path
$ns = [Xml.XmlNamespaceManager]::new($notes15.NameTable)
$ns.AddNamespace('a', 'http://schemas.openxmlformats.org/drawingml/2006/main')
$old15 = $notes15.SelectNodes('//a:t', $ns) | Where-Object { $_.InnerText -match 'Chapter 3 Figure 3 now opens with a simplified DFD overview|Chapter 3 has the original figure presentation' } | Select-Object -First 1
if (-not $old15) { throw 'Expected stale Chapter 3 speaker note on slide 15 was not found.' }
$old15.InnerText = 'Chapter 3 has the original figure presentation: Figures 3a-e contain the nine-process Level 1 DFD; Figure 3f isolates administrator security stores. Figures 5a-c show the main physical relationships and Figure 5d shows the administrator-security schema. The standalone full Level 1 SVG remains separate. Current Word tables and dictionary content are retained. Final desktop Word pagination review remains pending.'
Save-ZipXml $pptx $notes15Path $notes15

Write-Output 'Updated Word DFD image parts and synchronized presentation slide 13 and speaker notes 13 and 15.'
