$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$snapshot=Join-Path $root ('Review Backups/combined-chapters-'+$stamp)
[void][IO.Directory]::CreateDirectory($snapshot)
$local=Join-Path ([IO.Path]::GetTempPath()) ('irongrind-combined-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($local)
foreach($chapter in 1..3){Copy-Item -LiteralPath (Join-Path $root "Chapter $chapter.docx") -Destination (Join-Path $snapshot "Chapter $chapter.docx");Copy-Item -LiteralPath (Join-Path $snapshot "Chapter $chapter.docx") -Destination (Join-Path $local "Chapter $chapter.docx")}
$output=Join-Path $root 'Chapters 1-3 with Table of Contents.docx'
if(Test-Path -LiteralPath $output){Copy-Item -LiteralPath $output -Destination (Join-Path $snapshot 'Previous combined manuscript.docx')}
$word=$null;$document=$null
try {
 Write-Output 'Starting an independent Word instance on temporary local copies.'
 $word=New-Object -ComObject Word.Application;$word.Visible=$false;$word.DisplayAlerts=0;$word.AutomationSecurity=3
 Write-Output 'Creating the combined document.'
 $document=$word.Documents.Add()
 $document.PageSetup.LeftMargin=108;$document.PageSetup.RightMargin=72;$document.PageSetup.TopMargin=72;$document.PageSetup.BottomMargin=72
 $range=$document.Range(0,0);$range.Text="TABLE OF CONTENTS`r`r"
 $range=$document.Paragraphs.Item(1).Range;$range.Font.Name='Times New Roman';$range.Font.Size=12;$range.Font.Bold=1;$range.ParagraphFormat.Alignment=1;$range.ParagraphFormat.LineSpacingRule=1
 $range=$document.Range($document.Content.End-1,$document.Content.End-1);$range.InsertBreak(2)
 foreach($chapter in 1..3){
  Write-Output "Inserting Chapter $chapter."
  $range=$document.Range($document.Content.End-1,$document.Content.End-1)
  $range.InsertFile((Join-Path $local "Chapter $chapter.docx"),'',$false,$false,$false)
  if($chapter -lt 3){$range=$document.Range($document.Content.End-1,$document.Content.End-1);$range.InsertBreak(2)}
 }
 Write-Output 'Adding a linked, three-level table of contents.'
 $range=$document.Paragraphs.Item(2).Range;$range.Collapse(1)
 $toc=$document.TablesOfContents.Add($range,$true,1,3,$false,'',$true,$true,'',$true,$true,$true)
 foreach($styleName in @('TOC 1','TOC 2','TOC 3')){try{$style=$document.Styles.Item($styleName);$style.Font.Name='Times New Roman';$style.Font.Size=12;$style.ParagraphFormat.LineSpacingRule=1}catch{throw "Cannot format $styleName"}}
 # Keep chapter sections and orientations, applying the agreed margins everywhere.
 foreach($section in $document.Sections){$section.PageSetup.LeftMargin=108;$section.PageSetup.RightMargin=72;$section.PageSetup.TopMargin=72;$section.PageSetup.BottomMargin=72;$section.PageSetup.Gutter=0}
 $temporary=Join-Path $local 'Chapters 1-3 with Table of Contents.docx'
 Write-Output 'Saving the merged document before pagination.'
 $document.SaveAs2($temporary,16)
 Copy-Item -LiteralPath $temporary -Destination $output -Force
 Write-Output 'Updating pagination and table-of-contents page numbers.'
 $document.Repaginate();$toc.Update();$toc.UpdatePageNumbers();$document.Save()
 Write-Output ('Word pages: '+$document.ComputeStatistics(2))
 $document.Close(0);[void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($document);$document=$null
 Copy-Item -LiteralPath $temporary -Destination $output -Force
 Write-Output ('Saved: '+$output)
 Write-Output ('Input snapshots: '+$snapshot)
} finally {
 if($document){$document.Close(0);[void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($document)}
 if($word){$word.Quit();[void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($word)}
}
