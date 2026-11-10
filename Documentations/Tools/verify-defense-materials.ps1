$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=Split-Path $PSScriptRoot -Parent
$folder=Join-Path $root 'Defense'
foreach($name in @('Capstone Study and Defense Notes.md','Capstone Presentation.md','Source Code Map.md','Admin MFA Setup and Deployment Guide.md')){
 if(-not (Test-Path -LiteralPath (Join-Path $folder $name))){throw "Missing $name"}
}
$zip=[IO.Compression.ZipFile]::OpenRead((Join-Path $folder 'Capstone Presentation.pptx'))
try {
 $xmlCount=0;$notesCount=0;$slidesCount=0
 foreach($entry in $zip.Entries){
  if($entry.FullName -notmatch '\.(xml|rels)$'){continue}
  $reader=[IO.StreamReader]::new($entry.Open());try{[xml]$xml=$reader.ReadToEnd()}finally{$reader.Dispose()};$xmlCount++
  if($entry.FullName -match '^ppt/slides/slide\d+\.xml$'){$slidesCount++}
  if($entry.FullName -match '^ppt/notesSlides/notesSlide\d+\.xml$'){
   $notesCount++
   $texts=$xml.SelectNodes('//*[local-name()="t"]')
   if(-not $texts.Count -or ($texts.InnerText -join '').Length -lt 50){throw 'Missing speaker notes'}
  }
  if($entry.FullName.EndsWith('.rels')){
   $base=if($entry.FullName -eq '_rels/.rels'){''}else{$entry.FullName -replace '_rels/[^/]+$',''}
   foreach($rel in $xml.Relationships.Relationship){
    if($rel.TargetMode -eq 'External'){continue}
    $uri=[Uri]::new([Uri]('https://package.invalid/'+$base),[string]$rel.Target)
    $target=$uri.AbsolutePath.TrimStart('/')
    if(-not $zip.GetEntry($target)){throw "Broken PPTX relationship: $($entry.FullName) -> $target"}
   }
  }
 }
 if($slidesCount -ne 18 -or $notesCount -ne 18){throw 'Expected eighteen slides with notes'}
 $message="Passed: editable PowerPoint has 18 slides, 18 populated speaker-note parts, $xmlCount parseable XML/relationship parts and no missing relationship targets. Supporting notes/source map/setup guide exist. Visual PowerPoint review remains separate."
 $message|Set-Content -Encoding UTF8 (Join-Path $root 'Review Evidence/Defense Materials Verification.txt')
 $message
}finally{$zip.Dispose()}
