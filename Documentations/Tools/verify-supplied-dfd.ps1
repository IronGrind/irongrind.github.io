$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=Split-Path $PSScriptRoot -Parent
$backup=Get-ChildItem (Join-Path $root 'Review Backups') -Directory -Filter 'supplied-dfd-*'|Sort-Object Name -Descending|Select-Object -First 1
$results=[Collections.Generic.List[string]]::new()
function EntryHash($entry){$s=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create();try{return [Convert]::ToBase64String($sha.ComputeHash($s))}finally{$s.Dispose();$sha.Dispose()}}
function DocXml($zip){$rd=[IO.StreamReader]::new($zip.GetEntry('word/document.xml').Open());try{return ,([xml]$rd.ReadToEnd())}finally{$rd.Dispose()}}
function StripDfd($doc){
 $ns=[Xml.XmlNamespaceManager]::new($doc.NameTable);$ns.AddNamespace('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main')
 $inside=$false
 foreach($p in @($doc.SelectNodes('//w:body/w:p',$ns))){
  $t=($p.SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join ''
  if($t -eq 'Data Flow Diagram'){$inside=$true}
  if($t.StartsWith('Figure 3')){$inside=$false}
  if(($inside -and $p.SelectSingleNode('.//w:drawing',$ns)) -or $t.StartsWith('Figures 3a-e expand') -or $t.StartsWith('Figure 3 expands') -or $t.StartsWith('Figure 3 reproduces') -or $t.StartsWith('Figure 3a-e') -or $t.StartsWith('Figure 3. Level 1') -or $t.StartsWith('Store identifiers remain consistent across the panels.') -or $t.StartsWith('The supplied drawing labels D1')){[void]$p.ParentNode.RemoveChild($p)}
 }
 return $doc.DocumentElement.OuterXml
}
foreach($name in @('Chapter 3','Chapters 1-3 with Table of Contents')){
 $old=[IO.Compression.ZipFile]::OpenRead((Join-Path $backup.FullName ($name+'.docx')))
 $new=[IO.Compression.ZipFile]::OpenRead((Join-Path $root ($name+'.docx')))
 try {
  $a=DocXml $old;$b=DocXml $new
  if((StripDfd $a) -cne (StripDfd $b)){throw "Unexpected non-DFD document change in $name"}
  foreach($part in $old.Entries){if($part.FullName -notin @('word/document.xml','word/_rels/document.xml.rels','[Content_Types].xml')){if((EntryHash $part) -ne (EntryHash $new.GetEntry($part.FullName))){throw "Unexpected package-part change: $($part.FullName)"}}}
  $svgSourceHash=(Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $root 'Chapter 3 Diagrams/03-user-supplied-dfd.svg')).Hash
  $stream=$new.GetEntry('word/media/user-supplied-dfd.svg').Open();$sha=[Security.Cryptography.SHA256]::Create();try{$embeddedHash=([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','')}finally{$stream.Dispose();$sha.Dispose()}
  if($embeddedHash -ne $svgSourceHash){throw 'Embedded SVG differs from source'}
  $results.Add("PASS $name : body outside the five old/one new DFD pictures and four DFD text paragraphs preserved; unrelated package parts byte-identical; supplied SVG bytes match source.")
 }finally{$old.Dispose();$new.Dispose()}
}
$results|Set-Content -Encoding UTF8 -LiteralPath (Join-Path $root 'Review Evidence/Current Manuscript Review/DFD Preservation Verification.txt')
$results
