param(
    [string]$DocumentPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'Chapter 3.docx'),
    [string]$ReferencePath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'Review Backups/20261108-212839/Chapter 3.docx')
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Drawing

$root = Split-Path $PSScriptRoot -Parent
$diagrams = Join-Path $root 'Chapter 3 Diagrams'
$backupDir = Join-Path $root 'Review Backups/old-layout-restore-before'
if (-not (Test-Path -LiteralPath $DocumentPath)) { throw "Chapter 3 was not found: $DocumentPath" }
if (-not (Test-Path -LiteralPath $ReferencePath)) { throw "Historical layout reference was not found: $ReferencePath" }
$backupFile = Join-Path $backupDir 'Chapter 3 before old-layout restoration.docx'
if (-not (Test-Path -LiteralPath $backupFile)) {
    [void][IO.Directory]::CreateDirectory($backupDir)
    Copy-Item -LiteralPath $DocumentPath -Destination $backupFile
} elseif ((Get-FileHash -LiteralPath $DocumentPath).Hash -ne (Get-FileHash -LiteralPath $backupFile).Hash) {
    throw "The existing backup does not match the current Chapter 3 file: $backupFile"
}

$sourceZip = [IO.Compression.ZipFile]::OpenRead((Resolve-Path $ReferencePath).Path)
$work = Join-Path ([IO.Path]::GetTempPath()) ('chapter3-old-layout-' + [guid]::NewGuid().ToString('N') + '.docx')
Copy-Item -LiteralPath $DocumentPath -Destination $work
$file = [IO.File]::Open($work, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
$zip = [IO.Compression.ZipArchive]::new($file, [IO.Compression.ZipArchiveMode]::Update)

try {
    function Read-XmlPart($archive, [string]$name) {
        $entry = $archive.GetEntry($name)
        if (-not $entry) { throw "Missing document package part: $name" }
        $reader = [IO.StreamReader]::new($entry.Open())
        try { $xml = [Xml.XmlDocument]::new(); $xml.PreserveWhitespace = $true; $xml.LoadXml($reader.ReadToEnd()); return ,$xml }
        finally { $reader.Dispose() }
    }
    function Write-XmlPart($archive, [string]$name, $xml) {
        $old = $archive.GetEntry($name)
        if ($old) { $old.Delete() }
        $entry = $archive.CreateEntry($name)
        $stream = $entry.Open()
        $writer = [IO.StreamWriter]::new($stream, [Text.UTF8Encoding]::new($false))
        try { $xml.Save($writer) } finally { $writer.Dispose() }
    }
    function Text-Of($paragraph, $ns) { return (($paragraph.SelectNodes('.//w:t', $ns) | ForEach-Object InnerText) -join '') }
    function Set-Text($paragraph, [string]$value, $ns) {
        $runs = $paragraph.SelectNodes('.//w:t', $ns)
        if (-not $runs.Count) { throw 'Cannot update a paragraph without text runs.' }
        $runs[0].InnerText = $value
        for ($i = 1; $i -lt $runs.Count; $i++) { $runs[$i].InnerText = '' }
    }
    function Target-Of($paragraph, $rels, $ns) {
        $blip = $paragraph.SelectSingleNode('.//a:blip', $ns)
        if (-not $blip) { return $null }
        $rid = $blip.GetAttribute('embed', $ns.LookupNamespace('r'))
        $rel = @($rels.Relationships.Relationship | Where-Object Id -EQ $rid | Select-Object -First 1)[0]
        if (-not $rel) { throw "Missing relationship for image $rid" }
        return $rel.GetAttribute('Target')
    }
    function Add-ImageRelationship($rels, [string]$rid, [string]$filename) {
        if ($rels.DocumentElement.ChildNodes | Where-Object { $_.Id -eq $rid }) { throw "Duplicate image relationship: $rid" }
        $rel = $rels.CreateElement('Relationship', $rels.DocumentElement.NamespaceURI)
        $rel.SetAttribute('Id', $rid)
        $rel.SetAttribute('Type', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image')
        $rel.SetAttribute('Target', "media/$filename")
        [void]$rels.DocumentElement.AppendChild($rel)
    }
    function Add-ImagePart($archive, [string]$filename, [string]$sourcePath) {
        $part = "word/media/$filename"
        if ($archive.GetEntry($part)) { $archive.GetEntry($part).Delete() }
        $entry = $archive.CreateEntry($part)
        $stream = $entry.Open()
        $bytes = [IO.File]::ReadAllBytes($sourcePath)
        try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
    }
    function Fit-Image($paragraph, [string]$sourcePath, $ns) {
        $image = [Drawing.Image]::FromFile($sourcePath)
        try {
            $cx = [long](6.0 * 914400)
            $cy = [long]($cx * $image.Height / $image.Width)
            foreach ($extent in $paragraph.SelectNodes('.//wp:extent | .//a:xfrm/a:ext', $ns)) {
                $extent.SetAttribute('cx', [string]$cx)
                $extent.SetAttribute('cy', [string]$cy)
            }
        } finally { $image.Dispose() }
    }

    $doc = Read-XmlPart $zip 'word/document.xml'
    $rels = Read-XmlPart $zip 'word/_rels/document.xml.rels'
    $oldDoc = Read-XmlPart $sourceZip 'word/document.xml'
    $oldRels = Read-XmlPart $sourceZip 'word/_rels/document.xml.rels'
    $ns = [Xml.XmlNamespaceManager]::new($doc.NameTable)
    $ns.AddNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
    $ns.AddNamespace('a', 'http://schemas.openxmlformats.org/drawingml/2006/main')
    $ns.AddNamespace('r', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships')
    $ns.AddNamespace('wp', 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing')
    $oldNs = [Xml.XmlNamespaceManager]::new($oldDoc.NameTable)
    $oldNs.AddNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
    $oldNs.AddNamespace('a', 'http://schemas.openxmlformats.org/drawingml/2006/main')
    $oldNs.AddNamespace('r', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships')
    $oldNs.AddNamespace('wp', 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing')

    $body = $doc.SelectSingleNode('//w:body', $ns)
    $oldBody = $oldDoc.SelectSingleNode('//w:body', $oldNs)
    $currentParagraphs = @($body.SelectNodes('w:p', $ns))
    $sectionHeading = @($currentParagraphs | Where-Object { (Text-Of $_ $ns).Trim() -eq 'Data Flow Diagram' } | Select-Object -First 1)[0]
    $processHeading = @($currentParagraphs | Where-Object { (Text-Of $_ $ns).Trim() -eq '1.0 Authenticate and Authorize' } | Select-Object -First 1)[0]
    if (-not $sectionHeading -or -not $processHeading) { throw 'Could not locate the Chapter 3 DFD section boundaries.' }

    $oldParagraphs = @($oldBody.SelectNodes('w:p', $oldNs))
    $oldDfdStart = -1; $oldDfdEnd = -1
    for ($i = 0; $i -lt $oldParagraphs.Count; $i++) {
        $value = (Text-Of $oldParagraphs[$i] $oldNs).Trim()
        if ($value -eq 'Data Flow Diagram') { $oldDfdStart = $i }
        if ($oldDfdStart -ge 0 -and $value -eq '1.0 Authenticate and Authorize') { $oldDfdEnd = $i; break }
    }
    if ($oldDfdStart -lt 0 -or $oldDfdEnd -lt 0) { throw 'Could not locate the historical DFD layout block.' }

    $oldDfdImages = @{}
    for ($i = $oldDfdStart + 1; $i -lt $oldDfdEnd; $i++) {
        $paragraph = $oldParagraphs[$i]
        $target = Target-Of $paragraph $oldRels $oldNs
        if ($target -match '^media/image([3-7])\.png$') { $oldDfdImages[[int]$Matches[1] - 2] = $paragraph }
    }
    if ($oldDfdImages.Count -ne 5) { throw "Expected five historical DFD panels, found $($oldDfdImages.Count)." }
    $oldDfdBlock = [Collections.Generic.List[object]]::new()
    for ($i = $oldDfdStart + 1; $i -lt $oldDfdEnd; $i++) { $oldDfdBlock.Add($oldParagraphs[$i]) }
    $figureCaption = @($oldDfdBlock | Where-Object { (Text-Of $_ $oldNs).Trim().StartsWith('Figure 3a-e.') } | Select-Object -First 1)[0]
    $figureNote = @($oldDfdBlock | Where-Object { (Text-Of $_ $oldNs).Trim().StartsWith('Figure 3a-e expands') } | Select-Object -First 1)[0]
    $storeNote = @($oldDfdBlock | Where-Object { (Text-Of $_ $oldNs).Trim().StartsWith('Store identifiers remain consistent') } | Select-Object -First 1)[0]
    if (-not $figureCaption -or -not $figureNote -or -not $storeNote) { throw 'Historical DFD caption or explanation is missing.' }

    $securityDfdImage = @($currentParagraphs | Where-Object { $pr = $_.SelectSingleNode('.//wp:docPr', $ns); $pr -and $pr.GetAttribute('name').StartsWith('Figure 3a. User Login - Additional Individual Security Stores') } | Select-Object -First 1)[0]
    $securityDfdNote = @($currentParagraphs | Where-Object { (Text-Of $_ $ns).Trim().StartsWith('Figure 3b expands the security-storage view') } | Select-Object -First 1)[0]
    if (-not $securityDfdImage -or -not $securityDfdNote) { throw 'The current administrator login security supplement is missing.' }
    $dfdCaption = $doc.ImportNode($figureCaption, $true)
    Set-Text $dfdCaption 'Figure 3f. User Login - Additional Individual Security Stores' $ns
    $securityDfdImage = $securityDfdImage.CloneNode($true)
    $securityDfdImage.SelectSingleNode('.//wp:docPr', $ns).SetAttribute('name', 'Figure 3f. User Login - Additional Individual Security Stores')
    $securityNote = $securityDfdNote.CloneNode($true)
    Set-Text $securityNote 'Figure 3f expands the security-storage view of Process 1.0 without adding a tenth main function. D15 records session-bound approval requests and decisions; D16 records the trusted browser public key and trust period; D17 records candidate challenges and authorized session boundaries. The separate stores support the approval and trusted-device workflow. Existing Auth identity, profile, and account-scope exchanges appear in the five Level 1 panels. The requesting and approving administrator sessions remain subject to server-side verification.' $ns

    $replacementDfd = [Collections.Generic.List[object]]::new()
    for ($i = $oldDfdStart + 1; $i -lt $oldDfdEnd; $i++) {
        $sourceParagraph = $oldParagraphs[$i]
        $target = Target-Of $sourceParagraph $oldRels $oldNs
        if ($target -match '^media/image([3-7])\.png$') {
            $panel = [int]$Matches[1] - 2
            $paragraph = $doc.ImportNode($oldDfdImages[$panel], $true)
            $filename = "03-data-flow-$panel.png"
            $rid = "rIdRestoredDfd$panel"
            $blip = $paragraph.SelectSingleNode('.//a:blip', $ns)
            $blip.SetAttribute('embed', $ns.LookupNamespace('r'), $rid)
            Add-ImageRelationship $rels $rid $filename
            Add-ImagePart $zip $filename (Join-Path $diagrams $filename)
            Fit-Image $paragraph (Join-Path $diagrams $filename) $ns
            $info = $paragraph.SelectSingleNode('.//wp:docPr', $ns)
            $info.SetAttribute('id', [string](500 + $panel))
            $info.SetAttribute('name', "Level 1 DFD panel 3$([char](96+$panel))")
            $info.SetAttribute('descr', "Updated Gane-Sarson Level 1 DFD continuation panel $panel of five; includes current process and store flows.")
            $replacementDfd.Add($paragraph)
        } elseif ((Text-Of $sourceParagraph $oldNs).Trim().StartsWith('Figure 3a-e.')) {
            $paragraph = $doc.ImportNode($sourceParagraph, $true)
            $replacementDfd.Add($paragraph)
        } elseif ((Text-Of $sourceParagraph $oldNs).Trim().StartsWith('Figure 3a-e expands')) {
            $paragraph = $doc.ImportNode($sourceParagraph, $true)
            Set-Text $paragraph "Figure 3a-e expands the context process into the system's nine functional processes using Gane-Sarson notation. The five panels continue one Level 1 model. Rectangles identify external actors, rounded boxes identify numbered processes, and divided symbols identify individually named data stores. Every arrow is directional and labeled. Processes 1.0 and 5.0 include the current device-approval and mobile-scanner stores; Figure 3f isolates the administrator security stores for easier reading." $ns
            $replacementDfd.Add($paragraph)
        } elseif ((Text-Of $sourceParagraph $oldNs).Trim().StartsWith('Store identifiers remain consistent')) {
            $paragraph = $doc.ImportNode($sourceParagraph, $true)
            Set-Text $paragraph 'Store identifiers remain consistent across the panels. D0 represents managed Auth accounts; D1 profiles; D2 membership applications; D3 members; D4 attendance; D5 products; D6 sales; D7 sale items; D8 membership history; D9 activity logs; D10 mobile attendance pairing policy; D11 mobile attendance scan sessions; D13 private attendance scan requests; D14 private account sessions; and D15-D17 administrator approval, trusted-device, and device-session stores. D12 identifies the retained mobile scan-event table and is not shown as an active frontend dependency. Report inputs from D2, D3, D4, D5, D6, D7, and D8 are drawn separately.' $ns
            $replacementDfd.Add($paragraph)
        } else {
            $replacementDfd.Add($doc.ImportNode($sourceParagraph, $true))
        }
    }
    $replacementDfd.Add($dfdCaption)
    $replacementDfd.Add($securityDfdImage)
    $replacementDfd.Add($securityNote)

    $node = $sectionHeading.NextSibling
    while ($node -and -not [object]::ReferenceEquals($node, $processHeading)) {
        $next = $node.NextSibling
        [void]$body.RemoveChild($node)
        $node = $next
    }
    foreach ($paragraph in $replacementDfd) { [void]$body.InsertBefore($paragraph, $processHeading) }

    # Restore the older physical relationship panels for the original 15 tables;
    # the current administrator-security figure supplies the three new tables.
    $currentParagraphs = @($body.SelectNodes('w:p', $ns))
    $securitySchemaImage = @($currentParagraphs | Where-Object { $pr = $_.SelectSingleNode('.//wp:docPr', $ns); $pr -and $pr.GetAttribute('name').StartsWith('Figure 5. Administrator Security Schema Supplement') } | Select-Object -First 1)[0]
    $securitySchemaNote = @($currentParagraphs | Where-Object { (Text-Of $_ $ns).Trim().StartsWith('Figure 5 shows all columns of the three new private security tables') } | Select-Object -First 1)[0]
    $dictionaryHeading = @($currentParagraphs | Where-Object { (Text-Of $_ $ns).Trim() -eq 'Data Dictionary' } | Select-Object -First 1)[0]
    $schemaSummary = @($currentParagraphs | Where-Object { (Text-Of $_ $ns).Trim().StartsWith('The documented target schema comprises twelve public') } | Select-Object -First 1)[0]
    if (-not $securitySchemaImage -or -not $securitySchemaNote -or -not $dictionaryHeading -or -not $schemaSummary) { throw 'Could not locate the current schema figure or dictionary boundary.' }

    $securitySchemaImage = $securitySchemaImage.CloneNode($true)
    $securitySchemaImage.SelectSingleNode('.//wp:docPr', $ns).SetAttribute('name', 'Figure 5d. Administrator Security Schema Supplement')
    $securitySchemaNote = $securitySchemaNote.CloneNode($true)
    Set-Text $securitySchemaNote 'Figure 5d shows the three administrator-security tables and their six foreign keys to managed Supabase Auth tables. Repeated auth.users and auth.sessions cards represent the same managed tables, repeated only to keep connectors readable. The requesting and approving session references use the declared deletion rules. The trusted-device primary key allows at most one trusted row per administrator; it does not require every administrator to have one. The approval pair (requesting_session_id, session_scope) is unique as a pair. The data dictionary records identifiers that intentionally do not have foreign keys.' $ns

    Set-Text $schemaSummary 'The documented target schema comprises twelve public and six private application-owned tables, 201 fields, and twenty-seven declared foreign keys. Figures 5a-c show the existing fifteen-table physical relationship model and its twenty-one foreign keys; Figure 5d adds the three administrator-security tables and six foreign keys to managed Auth tables. The dictionary below describes all eighteen application-owned tables and their declared types, constraints, nullability, referential actions, and operational purpose. Relationships do not grant permissions; server authorization controls access. The retained receipt_number field is an internal transaction reference and does not establish customer receipt issuance.' $ns

    $oldErdImages = @{}
    $oldCaption = $null; $oldErdNote = $null
    for ($i = 0; $i -lt $oldParagraphs.Count; $i++) {
        $paragraph = $oldParagraphs[$i]
        $target = Target-Of $paragraph $oldRels $oldNs
        if ($target -match '^media/image(9|10|11)\.png$') { $oldErdImages[$target] = $paragraph }
        $value = (Text-Of $paragraph $oldNs).Trim()
        if ($value.StartsWith('Figure 5a-c. Physical entity relationships')) { $oldCaption = $paragraph }
        if ($value.StartsWith('The physical ERD in Figure 5a-c')) { $oldErdNote = $paragraph }
    }
    if ($oldErdImages.Count -ne 3 -or -not $oldCaption -or -not $oldErdNote) { throw 'Historical physical ERD panels or captions are missing.' }

    # The legacy ERD images are also kept as diagram assets for future reference.
    foreach ($image in @(@{Target='media/image9.png';Name='05-erd-1.png'},@{Target='media/image10.png';Name='05-erd-2.png'},@{Target='media/image11.png';Name='05-erd-3.png'})) {
        $entry = $sourceZip.GetEntry('word/' + $image.Target)
        $destination = Join-Path $diagrams $image.Name
        $input = $entry.Open(); $output = [IO.File]::Create($destination)
        try { $input.CopyTo($output) } finally { $input.Dispose(); $output.Dispose() }
    }

    $erdCaption = $doc.ImportNode($oldCaption, $true)
    $erdNote = $doc.ImportNode($oldErdNote, $true)
    Set-Text $erdNote 'Figures 5a-c show the fifteen existing application-owned tables and their twenty-one declared foreign-key relationships. Repeated entity cards represent the same table. Each row identifies the referenced key, child foreign key, cardinality, and deletion rule. Figure 5d supplements these panels with the three administrator-security tables and their six additional references to managed Auth tables, completing the eighteen-table, twenty-seven-foreign-key schema documented in the dictionary.' $ns
    $erdBlock = [Collections.Generic.List[object]]::new()
    foreach ($target in @('media/image9.png','media/image10.png','media/image11.png')) {
        $panel = [int]([regex]::Match($target,'image(\d+)').Groups[1].Value) - 8
        $filename = "05-erd-$panel.png"
        $rid = "rIdRestoredErd$panel"
        $paragraph = $doc.ImportNode($oldErdImages[$target], $true)
        $paragraph.SelectSingleNode('.//a:blip', $ns).SetAttribute('embed', $ns.LookupNamespace('r'), $rid)
        Add-ImageRelationship $rels $rid $filename
        Add-ImagePart $zip $filename (Join-Path $diagrams $filename)
        Fit-Image $paragraph (Join-Path $diagrams $filename) $ns
        $info = $paragraph.SelectSingleNode('.//wp:docPr', $ns)
        $info.SetAttribute('id', [string](510 + $panel))
        $info.SetAttribute('name', "Physical ERD panel 5$([char](96+$panel))")
        $info.SetAttribute('descr', "Original-format physical ERD relationship panel $panel; covers the existing schema relationships.")
        $erdBlock.Add($paragraph)
    }
    $erdBlock.Add($erdCaption); $erdBlock.Add($erdNote)
    $securityCaption = $doc.ImportNode($oldCaption, $true)
    Set-Text $securityCaption 'Figure 5d. Administrator Security Schema Supplement' $ns
    $erdBlock.Add($securityCaption); $erdBlock.Add($securitySchemaImage); $erdBlock.Add($securitySchemaNote)

    $currentParagraphs = @($body.SelectNodes('w:p', $ns))
    foreach ($paragraph in $currentParagraphs) {
        $value = (Text-Of $paragraph $ns).Trim()
        $pr = $paragraph.SelectSingleNode('.//wp:docPr', $ns)
        $imageName = if ($pr) { $pr.GetAttribute('name') } else { '' }
        if ($value -eq 'Figure 5. Administrator Security Schema Supplement' -or
            $value.StartsWith('Figure 5 shows all columns of the three new private security tables') -or
            $imageName.StartsWith('Figure 5. Administrator Security Schema Supplement')) {
            [void]$body.RemoveChild($paragraph)
        }
    }
    foreach ($paragraph in $erdBlock) { [void]$body.InsertBefore($paragraph, $dictionaryHeading) }

    # Refresh the context figure using the same historical Gane-Sarson drawing style.
    $contextParagraph = @($body.SelectNodes('w:p', $ns) | Where-Object { $pr = $_.SelectSingleNode('.//wp:docPr', $ns); $pr -and $pr.GetAttribute('name') -eq '02-context.png' } | Select-Object -First 1)[0]
    if (-not $contextParagraph) { throw 'Context diagram image is missing.' }
    $contextRel = $rels.DocumentElement.ChildNodes | Where-Object { $_.Id -eq ($contextParagraph.SelectSingleNode('.//a:blip', $ns).GetAttribute('embed', $ns.LookupNamespace('r'))) } | Select-Object -First 1
    Add-ImagePart $zip $contextRel.GetAttribute('Target').Substring(6) (Join-Path $diagrams '02-context.png')
    Fit-Image $contextParagraph (Join-Path $diagrams '02-context.png') $ns

    foreach ($paragraph in $body.SelectNodes('w:p', $ns)) {
        $value = Text-Of $paragraph $ns
        if ($value.Contains('Figure 3 expands the system into nine functions, and Figure 3b identifies')) {
            Set-Text $paragraph 'Figures 3a-e expand the system into nine processes; Figure 3f identifies the additional administrator login-security stores supporting User Login.' $ns
        }
    }
    foreach ($paragraph in $body.SelectNodes('w:p', $ns)) {
        $value = Text-Of $paragraph $ns
        if ($value.StartsWith('Figure 3a expands the security-storage view')) { Set-Text $paragraph ($value.Replace('Figure 3a','Figure 3f').Replace('Figure 3a-e','Figure 3a-e')) $ns }
    }

    # Ensure the DFD image metadata and schema summary describe the restored panels.
    $dfdImages = @($body.SelectNodes('//wp:docPr',$ns) | Where-Object { $_.GetAttribute('name') -match '^Level 1 DFD panel 3[a-e]$' })
    $erdImages = @($body.SelectNodes('//wp:docPr',$ns) | Where-Object { $_.GetAttribute('name') -match '^Physical ERD panel 5[a-c]$' })
    if ($dfdImages.Count -ne 5 -or $erdImages.Count -ne 3) { throw 'Restored figure counts are incomplete.' }

    Write-XmlPart $zip 'word/document.xml' $doc
    Write-XmlPart $zip 'word/_rels/document.xml.rels' $rels
} finally {
    $zip.Dispose()
    $sourceZip.Dispose()
}

$lock = [IO.File]::Open($DocumentPath, 'Open', 'ReadWrite', 'None')
$lock.Dispose()
Copy-Item -LiteralPath $work -Destination $DocumentPath -Force
Remove-Item -LiteralPath $work -Force
"Restored the five-panel Level 1 DFD and three-panel physical ERD layout. Current tables remain intact. Backup: $backupDir"
