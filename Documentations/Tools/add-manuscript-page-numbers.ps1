$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = Split-Path $PSScriptRoot -Parent
$target = Join-Path $root 'Chapters 1-3 with Table of Contents.docx'
$backup = Join-Path $root ('Review Backups/page-numbering-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
[void](New-Item -ItemType Directory -Path $backup)
$original = Join-Path $backup 'Original.docx'
$stage = Join-Path $backup 'Numbered.docx'
Copy-Item -LiteralPath $target -Destination $original
Copy-Item -LiteralPath $target -Destination $stage
$initialHash = (Get-FileHash -LiteralPath $target).Hash
$w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
$r = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
function ReadXml($zip, $name) {
    $reader = [IO.StreamReader]::new($zip.GetEntry($name).Open())
    try { $xml = [Xml.XmlDocument]::new(); $xml.PreserveWhitespace = $true; $xml.LoadXml($reader.ReadToEnd()); return ,$xml } finally { $reader.Dispose() }
}
function SaveXml($zip, $name, $xml) {
    $entry = $zip.GetEntry($name); if ($entry) { $entry.Delete() }
    $writer = [IO.StreamWriter]::new($zip.CreateEntry($name).Open(), [Text.UTF8Encoding]::new($false))
    try { $xml.Save($writer) } finally { $writer.Dispose() }
}
function HashEntry($entry) {
    $stream = $entry.Open(); $sha = [Security.Cryptography.SHA256]::Create()
    try { return [Convert]::ToBase64String($sha.ComputeHash($stream)) } finally { $stream.Dispose(); $sha.Dispose() }
}
$zip = [IO.Compression.ZipFile]::Open($stage, 'Update')
$old = [IO.Compression.ZipFile]::OpenRead($original)
try {
    $doc = ReadXml $zip 'word/document.xml'
    $ns = [Xml.XmlNamespaceManager]::new($doc.NameTable); $ns.AddNamespace('w', $w)
    $before = $doc.OuterXml
    $rels = ReadXml $zip 'word/_rels/document.xml.rels'
    $types = ReadXml $zip '[Content_Types].xml'
    $sections = @($doc.SelectNodes('//w:sectPr', $ns))
    $chapter = @($doc.SelectNodes('//w:body/w:p', $ns) | Where-Object { (($_.SelectNodes('.//w:t', $ns) | ForEach-Object InnerText) -join '').Trim() -eq 'Chapter 1' })
    if ($chapter.Count -ne 1) { throw 'Cannot uniquely locate Chapter 1.' }
    $frontCount = $chapter[0].SelectNodes('preceding-sibling::w:p/w:pPr/w:sectPr', $ns).Count
    if ($frontCount -lt 1) { throw 'Preliminary pages need a separate section.' }
    $parts = @('word/footerCountedBlank.xml', 'word/footerCountedNumber.xml')
    $ids = @('rIdCountedBlank', 'rIdCountedNumber')
    for ($i = 0; $i -lt 2; $i++) {
        if ($zip.GetEntry($parts[$i]) -or @($rels.DocumentElement.ChildNodes | Where-Object Id -eq $ids[$i]).Count) { throw 'Page numbering already installed; inspect before rerunning.' }
        $footer = [Xml.XmlDocument]::new()
        $content = if ($i -eq 1) { '<w:fldSimple w:instr=" PAGE "><w:r><w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/><w:sz w:val="24"/></w:rPr><w:t> </w:t></w:r></w:fldSimple>' } else { '' }
        $footer.LoadXml('<w:ftr xmlns:w="' + $w + '"><w:p><w:pPr><w:spacing w:before="0" w:after="0"/><w:jc w:val="center"/></w:pPr>' + $content + '</w:p></w:ftr>')
        SaveXml $zip $parts[$i] $footer
        $rel = $rels.CreateElement('Relationship', $rels.DocumentElement.NamespaceURI)
        $rel.SetAttribute('Id', $ids[$i]); $rel.SetAttribute('Type', $r + '/footer'); $rel.SetAttribute('Target', $parts[$i].Substring(5)); [void]$rels.DocumentElement.AppendChild($rel)
        $type = $types.CreateElement('Override', $types.DocumentElement.NamespaceURI)
        $type.SetAttribute('PartName', '/' + $parts[$i]); $type.SetAttribute('ContentType', 'application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml'); [void]$types.DocumentElement.AppendChild($type)
    }
    for ($i = 0; $i -lt $sections.Count; $i++) {
        $section = $sections[$i]
        foreach ($node in @($section.SelectNodes('w:footerReference|w:pgNumType', $ns))) { [void]$section.RemoveChild($node) }
        $index = if ($i -lt $frontCount) { 0 } else { 1 }
        foreach ($kind in @('default', 'first', 'even')) {
            $ref = $doc.CreateElement('w', 'footerReference', $w)
            [void]$ref.SetAttribute('type', $w, $kind); [void]$ref.SetAttribute('id', $r, $ids[$index]); [void]$section.PrependChild($ref)
        }
        $num = $doc.CreateElement('w', 'pgNumType', $w); [void]$num.SetAttribute('fmt', $w, 'decimal')
        if ($i -eq 0) { [void]$num.SetAttribute('start', $w, '1') }
        $anchor = $section.SelectSingleNode('w:cols|w:formProt|w:vAlign|w:noEndnote|w:titlePg|w:textDirection|w:bidi|w:rtlGutter|w:docGrid|w:printerSettings|w:sectPrChange', $ns)
        if ($anchor) { [void]$section.InsertBefore($num, $anchor) } else { [void]$section.AppendChild($num) }
    }
    # Compare with only the authorized section metadata removed from each version.
    $prior = [Xml.XmlDocument]::new(); $prior.PreserveWhitespace = $true; $prior.LoadXml($before)
    $check = $doc.CloneNode($true)
    foreach ($xml in @($prior, $check)) { foreach ($node in @($xml.SelectNodes('//w:sectPr/w:footerReference|//w:sectPr/w:pgNumType', $ns))) { [void]$node.ParentNode.RemoveChild($node) } }
    if ($prior.OuterXml -cne $check.OuterXml) { throw 'Unexpected document content or layout change.' }
    SaveXml $zip 'word/document.xml' $doc
    SaveXml $zip 'word/_rels/document.xml.rels' $rels
    SaveXml $zip '[Content_Types].xml' $types
    foreach ($entry in $old.Entries) {
        if ($entry.FullName -in @('word/document.xml', 'word/_rels/document.xml.rels', '[Content_Types].xml')) { continue }
        if ((HashEntry $entry) -ne (HashEntry $zip.GetEntry($entry.FullName))) { throw ('Unexpected package change: ' + $entry.FullName) }
    }
    foreach ($entry in @($zip.Entries | Where-Object FullName -Match '\.xml$')) { $null = ReadXml $zip $entry.FullName }
} finally { $zip.Dispose(); $old.Dispose() }
if ((Get-FileHash -LiteralPath $target).Hash -ne $initialHash) { throw 'Source changed during processing.' }
Copy-Item -LiteralPath $stage -Destination $target -Force
$report = @(
    "PASS: $frontCount preliminary sections use blank footers; remaining $($sections.Count - $frontCount) sections use centered PAGE fields for default, first and even pages.",
    'PASS: numbering starts at 1 in the first preliminary section and continues without restart through all subsequent sections.',
    'PASS: original body content, tables, TOC fields, section layouts, styles and media preserved; all XML parts parse.',
    'LIMIT: desktop Word pagination, rendered footer placement and TOC refresh remain pending. No numeric page count or first chapter page number is assumed.',
    "Backup: $backup"
)
$report | Set-Content -Encoding UTF8 (Join-Path $root 'Review Evidence/Manuscript Page Numbering Verification.txt')
$report
