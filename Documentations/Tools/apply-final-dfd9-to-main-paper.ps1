$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$paper = Join-Path $root 'Documentations\Chapters 1-3 (MAO NA JUD NI).docx'
$diagramFolder = Join-Path $root 'Documentations\Chapter 3 Diagrams'
$sourceSvg = 'C:\Users\mycah\Downloads\final dfd9.drawio.svg'
$backup = Get-ChildItem (Join-Path $root 'Documentations\Review Backups') -Directory -Filter 'dfd9-application-*' |
    Sort-Object Name -Descending | Select-Object -First 1
if (-not $backup) { throw 'Expected the pre-application DFD9 backup folder.' }
$fallbackPng = Join-Path $backup.FullName 'dfd9-fallback-3200.png'
if (-not (Test-Path -LiteralPath $sourceSvg)) { throw "Missing supplied DFD9 SVG: $sourceSvg" }
if (-not (Test-Path -LiteralPath $fallbackPng)) { throw "Missing rendered PNG fallback: $fallbackPng" }

$stage = Join-Path $backup.FullName 'main-paper-staged.docx'
Copy-Item -LiteralPath $paper -Destination $stage -Force

function Get-EntryBytes($zip, [string]$name) {
    $entry = $zip.GetEntry($name)
    if (-not $entry) { throw "Missing DOCX package part: $name" }
    $stream = $entry.Open()
    try {
        $memory = [IO.MemoryStream]::new()
        try { $stream.CopyTo($memory); return ,$memory.ToArray() }
        finally { $memory.Dispose() }
    } finally { $stream.Dispose() }
}

function Replace-EntryBytes($zip, [string]$name, [byte[]]$bytes) {
    $old = $zip.GetEntry($name)
    if (-not $old) { throw "Missing DOCX media part: $name" }
    $old.Delete()
    $entry = $zip.CreateEntry($name, [IO.Compression.CompressionLevel]::Optimal)
    $stream = $entry.Open()
    try { $stream.Write($bytes, 0, $bytes.Length) }
    finally { $stream.Dispose() }
}

function Paragraph-Text($paragraph, $ns) {
    return (($paragraph.SelectNodes('.//w:t', $ns) | ForEach-Object InnerText) -join '')
}

function Set-ParagraphText($paragraph, [string]$text, $ns) {
    $runs = @($paragraph.SelectNodes('.//w:t', $ns))
    if (-not $runs.Count) { throw 'A targeted DFD paragraph contains no text run.' }
    $runs[0].InnerText = $text
    foreach ($run in ($runs | Select-Object -Skip 1)) { $run.InnerText = '' }
}

$newParagraphs = [ordered]@{
    'Figure 3 expands the system into nine processes' = 'Figure 3 shows IronGrind''s nine-process Level 1 DFD in Gane-Sarson notation. It presents the main external users, system functions, and D1-D12 data stores. Supabase Auth and private authorization, attendance-request, and session-support records are outside this public data-flow view.'
    'Figure 3 is the supplied Level 1 Data Flow Diagram.' = 'Read each flow by its visible arrowhead. A flow from an actor to a process carries a request or submitted information; a flow from a process to an actor returns a result. A process-to-store flow writes or updates a record, while a store-to-process flow supplies data for a process. Rectangles identify external actors, numbered rounded boxes identify system processes, and open-ended symbols identify data stores. Repeated store symbols refer to the same logical store. The DFD explains information movement, not screen order or the implementation of authorization checks.'
    'The supplied drawing labels D1 profiles' = 'The labels D1-D12 refer to these public tables: D1 profiles; D2 membership_applications; D3 members; D4 attendance; D5 products; D6 sales; D7 sale_items; D8 membership_history; D9 activity_logs; D10 mobile_attendance_pairing_policy; D11 mobile_attendance_scan_sessions; and D12 mobile_attendance_scan_events. D10-D12 represent attendance-phone support stores. D12 appears in the supplied drawing as paired-device history; its presence does not establish that current scanner code writes every pairing or scan event there. Check-in and check-out records are stored in D4, while private scanner-session and retry-protection records are implementation details outside this public-store view.'
    'The actor-specific arrows are essential to interpreting User Management and attendance correctly.' = 'The membership flow begins with registration details from Member / Applicant and a review decision from authorized Staff or Admin. Process 2.0 writes the application outcome to D2 and, when approved, the resulting member record to D3; its labeled membership transaction and charge flows support the associated transaction records. Process 3.0 handles profile queries and permitted changes, limited counter lookup, walk-in registration, and direct membership operations. Administrators'' member-profile queries are read-only; members may change only their own permitted details; staff receive limited lookup. The diagram routes the review, profile/user-management, renewal, attendance, inventory, and sales events shown to D9.'
    'Processes 8.0 and 9.0 must be read separately.' = 'Processes 8.0 and 9.0 are separate read paths. Generate Reports reads selected operational records from D2-D8 and returns a requested report or preview to Admin. Activity Logs reads event records from D9 using the administrator''s filters and page query, then returns filtered results. The log viewer does not execute membership, attendance, inventory, sales, profile, or pairing operations; their originating processes perform those actions and send the event flows shown to D9. The DFD illustrates information exchange, while role checks, database policies, and authorized services enforce actual permissions.'
}

$zip = [IO.Compression.ZipFile]::Open($stage, [IO.Compression.ZipArchiveMode]::Update)
try {
    $documentBytes = Get-EntryBytes $zip 'word/document.xml'
    $docText = [Text.Encoding]::UTF8.GetString($documentBytes)
    [xml]$doc = $docText
    $ns = [Xml.XmlNamespaceManager]::new($doc.NameTable)
    $ns.AddNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
    $ns.AddNamespace('wp', 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing')
    $ns.AddNamespace('a', 'http://schemas.openxmlformats.org/drawingml/2006/main')
    $ns.AddNamespace('pic', 'http://schemas.openxmlformats.org/drawingml/2006/picture')
    $ns.AddNamespace('r', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships')
    $ns.AddNamespace('asvg', 'http://schemas.microsoft.com/office/drawing/2016/SVG/main')

    $paragraphs = @($doc.SelectNodes('//w:body//w:p', $ns))
    foreach ($prefix in $newParagraphs.Keys) {
        $stablePrefix = switch -Exact ($prefix) {
            'Figure 3 expands the system into nine processes' { 'Figure 3 shows IronGrind' }
            'Figure 3 is the supplied Level 1 Data Flow Diagram.' { 'Read each flow by its visible arrowhead' }
            'The supplied drawing labels D1 profiles' { 'The labels D1' }
            'The actor-specific arrows are essential to interpreting User Management and attendance correctly.' { 'The membership flow begins' }
            'Processes 8.0 and 9.0 must be read separately.' { 'Processes 8.0 and 9.0 are separate read paths' }
        }
        $matches = @($paragraphs | Where-Object {
            $currentText = (Paragraph-Text $_ $ns).Trim()
            $currentText.StartsWith($prefix) -or $currentText.StartsWith($stablePrefix)
        })
        if ($matches.Count -ne 1) { throw "Expected one DFD paragraph starting '$prefix'; found $($matches.Count)." }
        Set-ParagraphText $matches[0] $newParagraphs[$prefix] $ns
    }

    $figure = $doc.SelectSingleNode('//wp:docPr[@name="Level 1 DFD panel 3a" or @name="Figure 3. Level 1 Data Flow Diagram"]', $ns)
    if (-not $figure) { throw 'Could not find the existing Level 1 DFD image in the main paper.' }
    $drawing = $figure.ParentNode
    while ($drawing -and $drawing.LocalName -notin @('inline', 'anchor')) { $drawing = $drawing.ParentNode }
    if (-not $drawing) { throw 'Could not locate the existing DFD image frame.' }
    $wpExtent = $drawing.SelectSingleNode('wp:extent', $ns)
    $transformExtent = $drawing.SelectSingleNode('.//pic:spPr/a:xfrm/a:ext', $ns)
    $bitmap = $drawing.SelectSingleNode('.//a:blip', $ns)
    $svgBlip = $drawing.SelectSingleNode('.//asvg:svgBlip', $ns)
    if (-not $wpExtent -or -not $transformExtent -or -not $bitmap -or -not $svgBlip) { throw 'The DFD picture is missing an expected SVG/PNG relationship or extent.' }

    [xml]$suppliedSvg = Get-Content -LiteralPath $sourceSvg -Raw
    $viewBox = $suppliedSvg.DocumentElement.GetAttribute('viewBox') -split '\s+'
    if ($viewBox.Count -ne 4 -or [double]$viewBox[2] -le 0 -or [double]$viewBox[3] -le 0) { throw 'The supplied SVG has no valid viewBox.' }
    $cx = [long]$wpExtent.GetAttribute('cx')
    $cy = [long][Math]::Round($cx * ([double]$viewBox[3] / [double]$viewBox[2]))
    foreach ($extent in @($wpExtent, $transformExtent)) {
        $extent.SetAttribute('cx', [string]$cx)
        $extent.SetAttribute('cy', [string]$cy)
    }
    $figure.SetAttribute('name', 'Figure 3. Level 1 Data Flow Diagram')
    $figure.SetAttribute('descr', 'Supplied DFD9 Level 1 diagram showing nine processes, external actors, and data stores D1 through D12.')
    $pictureName = $drawing.SelectSingleNode('.//pic:cNvPr', $ns)
    if ($pictureName) { $pictureName.SetAttribute('name', 'Figure 3. Level 1 Data Flow Diagram') }

    $relsXml = [Text.Encoding]::UTF8.GetString((Get-EntryBytes $zip 'word/_rels/document.xml.rels'))
    [xml]$rels = $relsXml
    $pngRid = $bitmap.GetAttribute('embed', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships')
    $svgRid = $svgBlip.GetAttribute('embed', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships')
    $pngRel = $rels.Relationships.Relationship | Where-Object { $_.Id -eq $pngRid }
    $svgRel = $rels.Relationships.Relationship | Where-Object { $_.Id -eq $svgRid }
    if (-not $pngRel -or -not $svgRel) { throw 'Could not resolve the DFD PNG/SVG package relationships.' }
    $pngPart = 'word/' + $pngRel.Target.Replace('\', '/')
    $svgPart = 'word/' + $svgRel.Target.Replace('\', '/')

    $svgBytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $sourceSvg).Path)
    $pngBytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $fallbackPng).Path)
    if ($pngBytes.Length -lt 24 -or [Text.Encoding]::ASCII.GetString($pngBytes, 1, 3) -ne 'PNG') { throw 'The rendered PNG fallback is not a valid PNG.' }
    Replace-EntryBytes $zip $pngPart $pngBytes
    Replace-EntryBytes $zip $svgPart $svgBytes

    $entry = $zip.GetEntry('word/document.xml')
    $entry.Delete()
    $out = $zip.CreateEntry('word/document.xml', [IO.Compression.CompressionLevel]::Optimal).Open()
    try {
        $writer = [IO.StreamWriter]::new($out, [Text.UTF8Encoding]::new($false))
        try { $doc.Save($writer) } finally { $writer.Dispose() }
    } finally { if ($out) { $out.Dispose() } }
} finally { $zip.Dispose() }

# Keep the editable diagram source and the SVG asset beside the manuscript.
$suppliedMxFile = [xml]$suppliedSvg.DocumentElement.GetAttribute('content')
[IO.File]::WriteAllText((Join-Path $diagramFolder '03-user-supplied-dfd.drawio'), $suppliedMxFile.DocumentElement.OuterXml, [Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath $sourceSvg -Destination (Join-Path $diagramFolder '03-user-supplied-dfd.svg') -Force
Copy-Item -LiteralPath $fallbackPng -Destination (Join-Path $diagramFolder '03-user-supplied-dfd.png') -Force

# Copy the staged package over only the selected main manuscript.
Copy-Item -LiteralPath $stage -Destination $paper -Force

"Applied supplied DFD9 to: $paper"
"Preserved landscape figure section and resized the vector proportionally to ${cx}x${cy} EMU."
"Updated the DFD explanation paragraphs and synchronized the SVG/PNG/editable source assets."
"Backup: $($backup.FullName)"
