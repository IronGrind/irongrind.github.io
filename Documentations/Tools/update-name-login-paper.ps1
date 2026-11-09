$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path (Split-Path $PSScriptRoot -Parent) "Review Backups/name-login-$stamp"
[void][IO.Directory]::CreateDirectory($backupDir)
$changed = [Collections.Generic.List[string]]::new()

function Get-ParagraphText($paragraph, $namespace) {
    return ($paragraph.SelectNodes('.//w:t', $namespace) | ForEach-Object InnerText) -join ''
}

function Replace-Paragraph($document, $namespace, $prefix, $replacement, $chapter) {
    $matches = @($document.SelectNodes('//w:body/w:p', $namespace) | Where-Object { (Get-ParagraphText $_ $namespace).Contains($prefix) })
    if ($matches.Count -ne 1) {
        $diagnostic = @($document.SelectNodes('//w:body/w:p', $namespace) | ForEach-Object { Get-ParagraphText $_ $namespace } | Where-Object { $_ -match 'stored and organized|renewal requests|Auth verifies|Register and Submit Membership' })
        throw "Chapter $chapter expected one paragraph containing '$prefix'; found $($matches.Count). Candidate paragraphs: $($diagnostic -join ' | ')"
    }
    $nodes = $matches[0].SelectNodes('.//w:t', $namespace)
    if (-not $nodes.Count) { throw "Chapter $chapter paragraph has no text nodes: $prefix" }
    $nodes[0].InnerText = $replacement
    for ($i = 1; $i -lt $nodes.Count; $i++) { $nodes[$i].InnerText = '' }
}

function Update-Chapter($chapter, $edits) {
    $path = Join-Path (Split-Path $PSScriptRoot -Parent) "Chapter $chapter.docx"
    [IO.File]::Copy($path, (Join-Path $backupDir "Chapter $chapter.docx"))
    $zip = [IO.Compression.ZipFile]::Open($path, [IO.Compression.ZipArchiveMode]::Update)
    try {
        $entry = $zip.GetEntry('word/document.xml')
        if (-not $entry) { throw "Chapter $chapter is missing word/document.xml." }
        $reader = [IO.StreamReader]::new($entry.Open())
        $document = [Xml.XmlDocument]::new()
        $document.PreserveWhitespace = $true
        $document.LoadXml($reader.ReadToEnd())
        $reader.Dispose()
        $namespace = [Xml.XmlNamespaceManager]::new($document.NameTable)
        $namespace.AddNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
        foreach ($edit in $edits) { Replace-Paragraph $document $namespace $edit.Prefix $edit.Text $chapter }
        $xml = $document.OuterXml
        $entry.Delete()
        $replacement = $zip.CreateEntry('word/document.xml', [IO.Compression.CompressionLevel]::Optimal)
        $stream = $replacement.Open()
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes($xml)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Dispose()
        $changed.Add("Chapter $chapter updated; XML text and existing document parts preserved.")
    } finally { $zip.Dispose() }
}

Update-Chapter 3 @(
    @{ Prefix = 'Supabase Auth verifies credentials.'; Text = 'Supabase Auth verifies credentials. Members sign in with the email address on their account; staff and administrators use their assigned usernames. Member registration collects an email and password, not a separate username, and the member dashboard displays the member''s full name. The profile role and active-account state determine administrator, staff, or member access, with protected operations checked by server-side authorization. New member registration uses a visible password-strength indicator and blocks passwords that do not meet the Strong requirements: 8 to 128 characters, uppercase and lowercase letters, at least one digit, and at least one symbol. Confirmation must match the selected password. Auth and the member-creation service enforce the password policy on the server; staff-account creation uses a minimum of 12 characters with the same character requirements. Existing sign-in forms continue to accept account credentials without imposing registration validation on login.' },
    @{ Prefix = '2. Register and Submit Membership Application'; Text = '2. Register and Submit Membership Application. This function allows a member to create an account using an email address and password, then submit personal and health information for review by authorized staff or the administrator. Name fields accept names containing letters and reject numeric characters.' },
    @{ Prefix = '3. Review Membership Applications'; Text = '3. Review Membership Applications. Authorized staff and the administrator review pending application summaries and approve or reject requests according to the gym''s criteria, confirming in-person payment before approval.' }
)

$changed | Set-Content -Encoding UTF8 (Join-Path (Split-Path $PSScriptRoot -Parent) 'Review Evidence/Name and Login Paper Update.txt')
$changed
