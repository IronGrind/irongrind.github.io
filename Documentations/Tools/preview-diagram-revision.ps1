$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$evidence=Join-Path $root 'Review Evidence/diagram-recheck'
$previewCopy=Join-Path ([IO.Path]::GetTempPath()) ('chapter3-diagram-preview-'+[guid]::NewGuid().ToString('N')+'.docx')
Copy-Item -LiteralPath (Join-Path $root 'Chapter 3.docx') -Destination $previewCopy
$word=$null;$document=$null
try {
 $word=New-Object -ComObject Word.Application
 $word.Visible=$false;$word.DisplayAlerts=0
 # A local temporary copy avoids OneDrive reopening the source through its cloud URL.
 $document=$word.Documents.Open($previewCopy,$false,$true,$false)
 $document.Repaginate()
 $report=[Collections.Generic.List[string]]::new()
 $report.Add('Desktop Word read-only pagination and PDF export — November 11, 2026')
 $report.Add('Pages: '+$document.ComputeStatistics(2))
 foreach($value in @('Context Diagram','Figure 2. Context - Gane-Sarson','Use Case Diagram','Figure 4. Use Case Diagram','Entity Relationship Diagram','Figure 5. Public-schema Entity Relationship Diagram','Gantt Chart','Figure 33. Gantt Chart')){
  $range=$document.Content.Duplicate;$range.Find.ClearFormatting();$range.Find.Text=$value;$range.Find.MatchCase=$true;$range.Find.Wrap=0
  if(-not $range.Find.Execute()){throw "Word did not find: $value"}
  $report.Add($value+' — page '+$range.Information(3))
 }
 $document.ExportAsFixedFormat((Join-Path $evidence 'Chapter 3 revised preview.pdf'),17)
 $report | Set-Content -Encoding UTF8 (Join-Path $evidence 'Word pagination.txt')
 $report
} finally {
 if($document){$document.Close(0);[void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($document)}
 if($word){$word.Quit();[void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($word)}
 if(Test-Path -LiteralPath $previewCopy){Remove-Item -LiteralPath $previewCopy}
}
