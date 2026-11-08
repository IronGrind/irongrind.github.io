$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
$root = $PSScriptRoot
foreach ($chapter in 1,3) {
    $path = Join-Path $root "Chapter $chapter.docx"
    $stream = [IO.File]::Open($path, 'Open', 'ReadWrite', 'None')
    $zip = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Update)
    try {
        $entry = $zip.GetEntry('word/document.xml')
        $reader = [IO.StreamReader]::new($entry.Open())
        $doc = [Xml.XmlDocument]::new()
        $doc.PreserveWhitespace = $true
        $doc.LoadXml($reader.ReadToEnd())
        $reader.Dispose()
        $ns = [Xml.XmlNamespaceManager]::new($doc.NameTable)
        $ns.AddNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
        $changed = 0
        foreach ($p in @($doc.SelectNodes('//w:body/w:p', $ns))) {
            $nodes = $p.SelectNodes('.//w:t', $ns)
            $text = ($nodes | ForEach-Object InnerText) -join ''
            $extra = ''
            if ($chapter -eq 1 -and $text -match 'The primary users of the system were' -and $text -notmatch 'These staff membership services') {
                $extra = ' These staff membership services include searching by member name or email, selecting the applicable membership plan, and recording the renewal or plan-change transaction. They concern subscription processing and do not permit staff to view or edit member personal profiles. Direct counter processing is separate from approval of an online application or renewal request, which is currently assigned to the administrator.'
            }
            if ($chapter -eq 3 -and $text.Trim().StartsWith('Staff use cases are limited') -and $text -notmatch 'The staff Renewal action') {
                $extra = ' The staff Renewal action allows an operator to find a member, choose the paid renewal plan, and complete the subscription transaction. The Change Plan action allows the operator to find a member and save the selected replacement plan with its price and membership dates. The system records the membership change and associated transaction history. These direct counter actions do not require staff to open a member personal profile and are distinct from the administrator-only review of submitted online requests.'
            }
            if ($extra -and $nodes.Count) {
                $nodes[0].InnerText = $text + $extra
                for ($i=1; $i -lt $nodes.Count; $i++) { $nodes[$i].InnerText = '' }
                $changed++
            }
        }
        if ($changed) {
            $writer = [IO.StreamWriter]::new($entry.Open())
            $writer.BaseStream.SetLength(0)
            $doc.Save($writer)
            $writer.Dispose()
        }
        Write-Output "Chapter ${chapter}: $changed paragraph(s) clarified."
    } finally { $zip.Dispose(); $stream.Dispose() }
}
