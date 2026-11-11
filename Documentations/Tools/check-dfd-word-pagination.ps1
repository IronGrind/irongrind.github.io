$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$report=[Collections.Generic.List[string]]::new()
$word=$null;$document=$null
try{
 $word=New-Object -ComObject Word.Application;$word.Visible=$false;$word.DisplayAlerts=0;$word.AutomationSecurity=3
 foreach($name in @('Chapter 3','Chapters 1-3 with Table of Contents')){
  $temporary=Join-Path ([IO.Path]::GetTempPath()) ('dfd-landscape-'+[guid]::NewGuid().ToString('N')+'.docx')
  Copy-Item -LiteralPath (Join-Path $root ($name+'.docx')) -Destination $temporary
  Write-Output "Opening $name for pagination."
  $document=$word.Documents.Open($temporary,$false,$true,$false)
  Write-Output 'Repaginating.'
  $document.Repaginate()
  function FindText($text){$range=$document.Content.Duplicate;if(-not $range.Find.Execute($text)){throw "Missing text $text"};return $range}
  $caption=FindText 'Figure 3. Level 1 Data Flow Diagram - Gane-Sarson'
  $explanation=FindText 'Figure 3 reproduces the complete user-supplied'
  Write-Output 'Locating the DFD picture and explanation.'
  $dfdRange=$caption.Paragraphs.Item(1).Previous(1).Range
  Write-Output "DFD paragraph contains $($dfdRange.InlineShapes.Count) inline shapes."
  $picture=$null
  if($dfdRange.InlineShapes.Count -eq 1){$picture=$dfdRange.InlineShapes.Item(1)}
  if(-not $picture){throw 'Supplied SVG picture not located'}
  $imagePage=$picture.Range.Information(3);$captionPage=$caption.Information(3);$explanationPage=$explanation.Information(3)
  Write-Output "Pages: image=$imagePage caption=$captionPage explanation=$explanationPage"
  if($imagePage -ne $captionPage){throw "DFD and caption split: $imagePage / $captionPage"}
  if($explanationPage -ne $imagePage+1){throw "Explanation is not on the next page: $imagePage / $explanationPage"}
  if($picture.Range.Sections.Item(1).PageSetup.Orientation -ne 1){throw 'DFD is not landscape'}
  if($explanation.Sections.Item(1).PageSetup.Orientation -ne 0){throw 'Explanation is not portrait'}
  if([Math]::Abs($picture.Width-720) -gt 1){throw 'DFD width differs from 10 inches'}
  $report.Add("PASS $name : DFD and caption share page $imagePage (landscape); explanation starts page $explanationPage (portrait); image is 10 inches wide; document has $($document.ComputeStatistics(2)) pages.")
  $document.Close(0);[void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($document);$document=$null
 }
}finally{
 if($document){$document.Close(0);[void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($document)}
 if($word){$word.Quit();[void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($word)}
}
$report|Set-Content -Encoding UTF8 -LiteralPath (Join-Path $root 'Review Evidence/DFD Word Pagination Verification.txt')
$report
