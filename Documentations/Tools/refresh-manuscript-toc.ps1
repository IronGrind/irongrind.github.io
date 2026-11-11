$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$source = Join-Path $root 'Chapters 1-3 with Table of Contents.docx'
$backup = Join-Path $root ('Review Backups/toc-refresh-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
[void][IO.Directory]::CreateDirectory($backup)
Copy-Item -LiteralPath $source -Destination (Join-Path $backup 'Original.docx')
$local = Join-Path ([IO.Path]::GetTempPath()) ('irongrind-toc-' + [guid]::NewGuid().ToString('N') + '.docx')
Copy-Item -LiteralPath $source -Destination $local
$word = $null; $document = $null
try {
    Write-Output ('Backup: ' + $backup)
    Write-Output 'Starting hidden Word automation on a temporary local copy.'
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false; $word.DisplayAlerts = 0; $word.AutomationSecurity = 3
    Write-Output 'Opening manuscript.'
    $document = $word.Documents.Open($local, $false, $false, $false)
    if ($document.TablesOfContents.Count -ne 1) { throw 'Expected exactly one table of contents.' }
    Write-Output 'Repaginating and updating contents.'
    $document.Repaginate()
    $toc = $document.TablesOfContents.Item(1)
    $toc.Update()
    $document.Repaginate()
    $toc.UpdatePageNumbers()
    $document.Save()
    Write-Output ('Pages: ' + $document.ComputeStatistics(2))
    $document.Close(0); [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($document); $document = $null
    Copy-Item -LiteralPath $local -Destination (Join-Path $backup 'Refreshed.docx')
    Write-Output ('Staged for preservation verification: ' + (Join-Path $backup 'Refreshed.docx'))
} finally {
    if ($document) { $document.Close(0); [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($document) }
    if ($word) { $word.Quit(); [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($word) }
}
