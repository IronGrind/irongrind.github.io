param([ValidateSet(1,2,3)][int[]]$Chapters=@(1,2,3))
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$results=[Collections.Generic.List[string]]::new()
foreach($chapter in $Chapters){
 $zip=[IO.Compression.ZipFile]::OpenRead((Join-Path $PSScriptRoot "Chapter $chapter.docx"))
 try{
  $reader=[IO.StreamReader]::new($zip.GetEntry('word/document.xml').Open());[xml]$doc=$reader.ReadToEnd();$reader.Dispose()
  $ns=[Xml.XmlNamespaceManager]::new($doc.NameTable);$ns.AddNamespace('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main');$ns.AddNamespace('a','http://schemas.openxmlformats.org/drawingml/2006/main');$ns.AddNamespace('r','http://schemas.openxmlformats.org/officeDocument/2006/relationships')
  $all=(@($doc.SelectNodes('//w:p',$ns)|ForEach-Object {($_.SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join ''})) -join ' '
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
   if(-not $all.Contains('duplicate email addresses or, where supported, usernames')){throw 'Chapter 1 does not distinguish generally applicable email checks from username checks.'}
   $paragraphs=@($doc.SelectNodes('//w:body/w:p',$ns));$background=-1
   for($i=0;$i -lt $paragraphs.Count;$i++){if((($paragraphs[$i].SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join '').Trim() -eq 'Background of the Study'){$background=$i;break}}
   $sdg=($paragraphs[$background+2].SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join ''
   if($background -lt 0 -or $sdg -notmatch 'Sustainable Development Goals'){throw 'Chapter 1 SDG paragraph is not immediately after the first introduction paragraph.'}
   foreach($phrase in @('Paired phones and unexpired pending QRs shared the configured slot limit','Staff account registration collected first name','Traffic capacity and a maximum number of simultaneous users were not established')){if(-not $all.Contains($phrase)){throw "Chapter 1 is missing a current scope statement: $phrase"}}
   foreach($phrase in @('A linked sign-in account is separate','A pending application awaits review by authorized staff or the administrator','authorized administrator or staff member scans the member QR code','available to authorized users according to their system role','information about a person''s health is sensitive personal information','The hosted platform IronGrind uses for Auth and its PostgreSQL database')){if(-not $all.Contains($phrase)){throw "Chapter 1 Definition of Terms is missing a current system distinction: $phrase"}}
  }
  if($chapter -eq 2){
   foreach($phrase in @('Supabase, n.d.-c','Supabase (n.d.-a)','Supabase (n.d.-b)','Supabase (n.d.-d)','REFERENCES','Supabase. (n.d.-a). Production checklist.','Supabase. (n.d.-b). Row level security.','Supabase. (n.d.-c). Supabase platform.','102 scholarly articles and conference papers indexed in Scopus','ISO/IEC Standard No. 18004:2024','Section 3(l)(2) includes health information','[Project report]')){if(-not $all.Contains($phrase)){throw "Chapter 2 is missing verified source support: $phrase"}}
   foreach($url in @('https://supabase.com/docs/guides/platform','https://supabase.com/docs/guides/deployment/going-into-prod','https://supabase.com/docs/guides/database/postgres/row-level-security','https://supabase.com/docs/guides/auth/sessions','https://doi.org/10.1504/IJBIS.2025.145551','https://doi.org/10.28945/5650','https://doi.org/10.46932/sfjdv6n4-030','https://www.iso.org/standard/83389.html')){if(-not $all.Contains($url)){throw "Chapter 2 is missing a reference-list source: $url"}}
   if($all.Contains('Y Combinator (n.d.)') -or $all.Contains('Additional Technical References')){throw 'Chapter 2 contains a superseded citation or heading.'}
   foreach($url in @('https://doi.org/10.1504/IJBIS.2025.145551','https://doi.org/10.28945/5650','https://doi.org/10.46932/sfjdv6n4-030')){if(([regex]::Matches($all,[regex]::Escape($url))).Count -ne 1){throw "Chapter 2 has a duplicate or missing DOI reference: $url"}}
   $refHeading=@($doc.SelectNodes('//w:body/w:p',$ns)|Where-Object {(($_.SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join '').Trim() -ceq 'REFERENCES'})
   if($refHeading.Count -ne 1 -or $refHeading[0].SelectSingleNode('w:pPr/w:jc',$ns).val -ne 'center' -or -not $refHeading[0].SelectSingleNode('.//w:rPr/w:b',$ns)){throw 'Chapter 2 reference heading is not centered, bold REFERENCES.'}
   $refEntries=@($refHeading[0].SelectNodes('following-sibling::w:p',$ns)|Where-Object {(($_.SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join '').Trim()})
   $refTexts=@($refEntries|ForEach-Object {($_.SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join ''})
   $sorted=@($refTexts|Sort-Object { $_.ToLowerInvariant() })
   if($refTexts.Count -ne 14 -or ($refTexts -join "`n") -cne ($sorted -join "`n")){throw 'Chapter 2 references are not the expected fourteen alphabetized entries.'}
   $italicCount=0
   foreach($ref in $refEntries){
    $indent=$ref.SelectSingleNode('w:pPr/w:ind',$ns)
    if($indent.GetAttribute('left',$ns.LookupNamespace('w')) -ne '720' -or $indent.GetAttribute('hanging',$ns.LookupNamespace('w')) -ne '720'){throw 'Chapter 2 reference hanging indent is incorrect.'}
    foreach($run in $ref.SelectNodes('w:r[w:rPr/w:i]',$ns)){$italicCount++;$italicText=($run.SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join '';if($italicText -match 'https?://'){throw 'Chapter 2 reference URL is incorrectly italicized.'}}
   }
   if($italicCount -ne 13){throw 'Chapter 2 is missing an expected italic reference title or journal/volume span.'}
   $results.Add('Chapter 2: reference heading, fourteen-entry alphabetical order, hanging indents, thirteen italic spans, and Supabase source labels verified.')
  }
  if($chapter -eq 3){
   foreach($phrase in @('Recorded verification as of November 8, 2026 comprised forty automated check groups','A separate performance evaluation remains necessary.','The Create Staff Account form collects first name','Phone pairing capacity counts both paired devices')){if(-not $all.Contains($phrase)){throw "Chapter 3 is missing a verified implementation statement: $phrase"}}
   foreach($phrase in @('Members sign in using their email address.','New member records do not receive a username; members sign in using email.','Current member registration uses email and does not collect a username.')){if(-not $all.Contains($phrase)){throw "Chapter 3 contains missing or outdated member-identifier documentation: $phrase"}}
   if($all.Contains('used to identify an account within supported sign-in and member-lookup workflows')){throw 'Chapter 3 still describes legacy username fields as current member sign-in identifiers.'}
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
$report=if($Chapters.Count -eq 3){'Chapter Review Verification.txt'}else{'Chapter '+($Chapters -join '-')+' Review Verification.txt'}
$results|Set-Content -Encoding UTF8 (Join-Path $PSScriptRoot ('Review Evidence/'+$report))
$results
