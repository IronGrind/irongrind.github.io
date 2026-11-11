$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = Split-Path $PSScriptRoot -Parent
$backup = Get-ChildItem (Join-Path $root 'Review Backups') -Directory -Filter 'toc-refresh-*' | Sort-Object Name -Descending | Select-Object -First 1
if (-not $backup) { throw 'Missing Word refresh backup.' }
$source = Join-Path $root 'Chapters 1-3 with Table of Contents.docx'
$original = Join-Path $backup.FullName 'Original.docx'
$refreshed = Join-Path $backup.FullName 'Refreshed.docx'
$stage = Join-Path $backup.FullName 'Verified.docx'
if ((Get-FileHash -LiteralPath $source).Hash -ne (Get-FileHash -LiteralPath $original).Hash) { throw 'Manuscript changed since Word refresh.' }
Copy-Item -LiteralPath $original -Destination $stage
function ReadXml($zip, $name) {
    $reader = [IO.StreamReader]::new($zip.GetEntry($name).Open())
    try { $doc = [Xml.XmlDocument]::new(); $doc.PreserveWhitespace = $true; $doc.LoadXml($reader.ReadToEnd()); return ,$doc } finally { $reader.Dispose() }
}
function HashEntry($entry) {
    $stream = $entry.Open(); $sha = [Security.Cryptography.SHA256]::Create()
    try { return [Convert]::ToBase64String($sha.ComputeHash($stream)) } finally { $stream.Dispose(); $sha.Dispose() }
}
$zip = [IO.Compression.ZipFile]::Open($stage, 'Update')
$wordZip = [IO.Compression.ZipFile]::OpenRead($refreshed)
$oldZip = [IO.Compression.ZipFile]::OpenRead($original)
$report = [Collections.Generic.List[string]]::new()
try {
    $doc = ReadXml $zip 'word/document.xml'
    $wordDoc = ReadXml $wordZip 'word/document.xml'
    $ns = [Xml.XmlNamespaceManager]::new($doc.NameTable); $ns.AddNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
    $query = '//w:p[w:pPr/w:pStyle[starts-with(@w:val,"TOC")]]'
    $entries = @($doc.SelectNodes($query, $ns)); $updated = @($wordDoc.SelectNodes($query, $ns))
    if ($entries.Count -eq 0 -or $updated.Count -ne $entries.Count) { throw 'TOC entry count changed; inspect headings before applying.' }
    $before = $doc.OuterXml
    $priorNumbers = @()
    $lastPage = 0
    for ($i = 0; $i -lt $entries.Count; $i++) {
        $texts = @($entries[$i].SelectNodes('.//w:t', $ns)); $newTexts = @($updated[$i].SelectNodes('.//w:t', $ns))
        $label = ($texts[0..($texts.Count - 2)] | ForEach-Object InnerText) -join ''
        $newLabel = ($newTexts[0..($newTexts.Count - 2)] | ForEach-Object InnerText) -join ''
        if ($label -cne $newLabel) { throw "TOC heading mismatch at $i" }
        $page = $newTexts[-1].InnerText
        if ($page -notmatch '^\d+$' -or [int]$page -lt $lastPage) { throw "Invalid refreshed page: $label / $page" }
        $lastPage = [int]$page
        $priorNumbers += $texts[-1].InnerText
        $texts[-1].InnerText = $page
        $report.Add("$label : $page")
        $anchor = $entries[$i].SelectSingleNode('.//w:hyperlink', $ns).GetAttribute('anchor', $ns.LookupNamespace('w'))
        if (-not $doc.SelectSingleNode('//w:bookmarkStart[@w:name="' + $anchor + '"]', $ns)) { throw "Missing destination: $anchor" }
    }
    # Only the existing cached page-reference values may change.
    $comparison = $doc.CloneNode($true)
    $compareEntries = @($comparison.SelectNodes($query, $ns))
    for ($i = 0; $i -lt $compareEntries.Count; $i++) { @($compareEntries[$i].SelectNodes('.//w:t', $ns))[-1].InnerText = $priorNumbers[$i] }
    if ($before -cne $comparison.OuterXml) { throw 'Unexpected body, field, formatting or section change.' }
    $zip.GetEntry('word/document.xml').Delete()
    $writer = [IO.StreamWriter]::new($zip.CreateEntry('word/document.xml').Open(), [Text.UTF8Encoding]::new($false))
    try { $doc.Save($writer) } finally { $writer.Dispose() }
    foreach ($entry in $oldZip.Entries) {
        if ($entry.FullName -eq 'word/document.xml') { continue }
        if ((HashEntry $entry) -ne (HashEntry $zip.GetEntry($entry.FullName))) { throw ('Unexpected package change: ' + $entry.FullName) }
    }
    $null = ReadXml $zip 'word/document.xml'
    $pageReader = [IO.StreamReader]::new($wordZip.GetEntry('docProps/app.xml').Open())
    try { $paginationProperties = [xml]$pageReader.ReadToEnd(); $wordPageCount = $paginationProperties.Properties.Pages } finally { $pageReader.Dispose() }
} finally { $zip.Dispose(); $wordZip.Dispose(); $oldZip.Dispose() }
if ((Get-FileHash -LiteralPath $source).Hash -ne (Get-FileHash -LiteralPath $original).Hash) { throw 'Manuscript changed during verification.' }
$replacement = Join-Path $backup.FullName ('Replacement-' + [guid]::NewGuid().ToString('N') + '.docx')
Copy-Item -LiteralPath $stage -Destination $replacement
try {
    [IO.File]::Replace($replacement, $source, (Join-Path $backup.FullName ('Before-replacement-' + [guid]::NewGuid().ToString('N') + '.docx')))
    $output = $source
} catch [IO.IOException] {
    $output = Join-Path $root 'Chapters 1-3 with Updated Table of Contents.docx'
    Copy-Item -LiteralPath $stage -Destination $output -Force
    $report.Add('Original manuscript is locked by another process; corrected manuscript saved separately.')
}
if ((Get-FileHash -LiteralPath $output).Hash -ne (Get-FileHash -LiteralPath $stage).Hash) { throw 'Saved manuscript does not match verified output.' }
$report.Insert(0, "PASS: $($entries.Count) TOC page references refreshed from desktop Word pagination; heading order and bookmark targets verified.")
$report.Insert(1, 'PASS: only cached page numbers changed. Body text, tables, styles, TOC formatting/fields, margins, section numbering, blank preliminary footers and media are preserved.')
$report.Add("Word refresh reported $wordPageCount pages. Final visual print-layout review remains separate.")
$report.Add('Backup: ' + $backup.FullName)
$report.Add('Saved manuscript: ' + $output)
$report | Set-Content -Encoding UTF8 (Join-Path $root 'Review Evidence/Manuscript TOC Refresh Verification.txt')
$report
