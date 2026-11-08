$ErrorActionPreference='Stop'
$out=Join-Path $PSScriptRoot 'Review Previews'
[void][IO.Directory]::CreateDirectory($out)
$word=$null
try{
 $word=New-Object -ComObject Word.Application
 $word.Visible=$false;$word.DisplayAlerts=0;$word.AutomationSecurity=3
 foreach($chapter in 1,2,3){
  $document=$null
  try{
   $document=$word.Documents.Open((Join-Path $PSScriptRoot "Chapter $chapter.docx"),$false,$true,$false)
   $document.Repaginate()
   $pages=$document.ComputeStatistics(2)
   $document.ExportAsFixedFormat((Join-Path $out "Chapter $chapter.pdf"),17)
   Write-Output "Chapter ${chapter}: Word opened successfully; $pages pages; PDF review copy exported."
  }finally{if($document){$document.Close(0);[void][Runtime.InteropServices.Marshal]::ReleaseComObject($document)}}
 }
}finally{if($word){$word.Quit(0);[void][Runtime.InteropServices.Marshal]::ReleaseComObject($word)}}
