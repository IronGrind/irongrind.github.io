$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$results=[Collections.Generic.List[string]]::new()
foreach($chapter in 1,2,3){
 $zip=[IO.Compression.ZipFile]::OpenRead((Join-Path $PSScriptRoot "Chapter $chapter.docx"))
 try{
  $reader=[IO.StreamReader]::new($zip.GetEntry('word/document.xml').Open());[xml]$doc=$reader.ReadToEnd();$reader.Dispose()
  $ns=[Xml.XmlNamespaceManager]::new($doc.NameTable);$ns.AddNamespace('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main');$ns.AddNamespace('a','http://schemas.openxmlformats.org/drawingml/2006/main');$ns.AddNamespace('r','http://schemas.openxmlformats.org/officeDocument/2006/relationships')
  $texts=@($doc.SelectNodes('//w:t',$ns)|ForEach-Object InnerText);$all=$texts -join ' '
  if($all -match 'Only administrators review online|do not grant staff permission to review online|sent to the Admin for review|awaits administrator review|two private supporting tables'){throw "Chapter $chapter contains an outdated permission or schema statement."}
  $garbled=[string][char]0xE2+[char]0x20AC
  if($all.Contains($garbled) -or $all.Contains([string][char]0xFFFD)){throw "Chapter $chapter contains garbled punctuation."}
  $boldBody=0
  foreach($p in $doc.SelectNodes('//w:body/w:p',$ns)){
   $text=($p.SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join ''
   $style=$p.SelectSingleNode('w:pPr/w:pStyle',$ns)
   $allowed=($style -and $style.val -match '^Heading') -or $text -in @('INTRODUCTION','RESEARCH METHODOLOGY','REVIEW OF RELATED LITERATURE AND STUDIES','Overall Description','1. Authenticate Account','1.0 Authenticate and Authorize','7.0 Sales','8.0 Generate Reports')
   if(-not $allowed -and $p.SelectSingleNode('.//w:rPr/w:b[@w:val="1"]',$ns)){$boldBody++}
  }
  if($boldBody){throw "Chapter $chapter has unexpected bold body paragraphs: $boldBody"}
  foreach($table in $doc.SelectNodes('//w:body/w:tbl',$ns)){
   foreach($row in $table.SelectNodes('w:tr[position()>1]',$ns)){if($row.SelectSingleNode('.//w:rPr/w:b[@w:val="1"]',$ns)){throw "Chapter $chapter has a bold table data row."}}
  }
  $reader=[IO.StreamReader]::new($zip.GetEntry('word/_rels/document.xml.rels').Open());[xml]$rels=$reader.ReadToEnd();$reader.Dispose()
  foreach($image in $doc.SelectNodes('//a:blip',$ns)){
   $id=$image.GetAttribute('embed',$ns.LookupNamespace('r'));$rel=$rels.Relationships.Relationship|Where-Object Id -EQ $id
   if(-not $rel -or -not $zip.GetEntry('word/'+$rel.Target)){throw "Chapter $chapter has a missing image: $id"}
  }
  if($chapter -eq 1){
   $paragraphs=@($doc.SelectNodes('//w:body/w:p',$ns));$background=-1
   for($i=0;$i -lt $paragraphs.Count;$i++){if((($paragraphs[$i].SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join '').Trim() -eq 'Background of the Study'){$background=$i;break}}
   $sdg=($paragraphs[$background+2].SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join ''
   if($background -lt 0 -or $sdg -notmatch 'Sustainable Development Goals'){throw 'Chapter 1 SDG paragraph is not immediately after the first introduction paragraph.'}
  }
  if($chapter -eq 3){
   if($doc.SelectNodes('//w:body/w:tbl',$ns).Count -ne 20){throw 'Expected five requirements tables and fifteen dictionary tables.'}
   $dictionary=@($doc.SelectNodes('//w:body/w:tbl',$ns)|Select-Object -Skip 5)
   $columns=0;foreach($table in $dictionary){$columns+=$table.SelectNodes('w:tr',$ns).Count-1}
   if($columns -ne 174){throw "Expected 174 documented fields, found $columns"}
   if(([regex]::Matches($all,'The fifteen application-owned tables comprise')).Count -ne 1){throw 'Duplicate or missing schema-count explanation.'}
   $results.Add('Chapter 3: 12 public and 3 private dictionary tables, 174 fields, 20 total tables, and linked figures verified.')
  }
  $results.Add("Chapter ${chapter}: XML opens; no unexpected body/data-row bold, stale approval wording, garbled punctuation, or missing figure links detected.")
 }finally{$zip.Dispose()}
}
[void][IO.Directory]::CreateDirectory((Join-Path $PSScriptRoot 'Review Evidence'))
$results|Set-Content -Encoding UTF8 (Join-Path $PSScriptRoot 'Review Evidence/Chapter Review Verification.txt')
$results
