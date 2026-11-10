param([ValidateSet(1,2,3)][int[]]$Chapters=@(1,2,3),[string]$DocumentPath)
$ErrorActionPreference='Stop'
if($DocumentPath -and $Chapters.Count -ne 1){throw 'Specify one chapter when verifying an alternate document path.'}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$results=[Collections.Generic.List[string]]::new()
foreach($chapter in $Chapters){
 $chapterPath=if($DocumentPath){(Resolve-Path -LiteralPath $DocumentPath).Path}else{Join-Path (Split-Path $PSScriptRoot -Parent) "Chapter $chapter.docx"}
 $zip=[IO.Compression.ZipFile]::OpenRead($chapterPath)
 try{
  $reader=[IO.StreamReader]::new($zip.GetEntry('word/document.xml').Open());[xml]$doc=$reader.ReadToEnd();$reader.Dispose()
  $ns=[Xml.XmlNamespaceManager]::new($doc.NameTable);$ns.AddNamespace('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main');$ns.AddNamespace('a','http://schemas.openxmlformats.org/drawingml/2006/main');$ns.AddNamespace('r','http://schemas.openxmlformats.org/officeDocument/2006/relationships');$ns.AddNamespace('wp','http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing')
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
   if($doc.SelectNodes('//w:body/w:tbl',$ns).Count -ne 23){throw 'Expected five requirements tables and eighteen dictionary tables.'}
   $dictionary=@($doc.SelectNodes('//w:body/w:tbl',$ns)|Select-Object -Skip 5)
   $columns=0;foreach($table in $dictionary){$columns+=$table.SelectNodes('w:tr',$ns).Count-1}
   if($columns -ne 201){throw "Expected 201 documented fields, found $columns"}
   if(([regex]::Matches($all,'The eighteen application-owned tables comprise')).Count -ne 1){throw 'Duplicate or missing schema-count explanation.'}
   if($all.Contains('Figure 5. Public-Schema Entity Relationship Diagram') -or $all.Contains('public-schema ERD in Figure 5')){throw 'The simplified public-schema ERD should not appear in the paper.'}
   if(-not $all.Contains('Figure 5. Administrator Security Schema Supplement')){throw 'The administrator security-schema supplement was not retained as Figure 5.'}
   $securitySchemaImage=@($doc.SelectNodes('//wp:docPr',$ns)|Where-Object {$_.GetAttribute('name') -eq 'Figure 5. Administrator Security Schema Supplement'})
   if($securitySchemaImage.Count -ne 1){throw 'Expected one administrator security-schema figure in Chapter 3.'}
   $schema=Get-Content -Raw -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'Chapter 3 Diagrams/schema-visualizer.json')|ConvertFrom-Json
   $order=@('public.profiles','public.members','public.membership_applications','public.attendance','public.products','public.sales','public.sale_items','public.membership_history','public.activity_logs','public.mobile_attendance_pairing_policy','public.mobile_attendance_scan_sessions','public.mobile_attendance_scan_events','private.attendance_scan_requests','private.admin_login_attempts','private.account_sessions','private.admin_login_approvals','private.admin_trusted_devices','private.admin_device_sessions')
   $verifiedFKs=0;$verifiedUnique=0
   for($ti=0;$ti -lt $dictionary.Count;$ti++){
    $tableName=$order[$ti];$modelTable=$schema.Tables|Where-Object Name -EQ $tableName
    $heads=@($dictionary[$ti].SelectSingleNode('w:tr',$ns).SelectNodes('w:tc',$ns)|ForEach-Object {($_.SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join ''})
    if(($heads -join '|') -cne 'Name|Type|Constraints|Description'){throw "Incorrect four-column dictionary header: $tableName"}
    foreach($row in ($dictionary[$ti].SelectNodes('w:tr',$ns)|Select-Object -Skip 1)){
     $cells=$row.SelectNodes('w:tc',$ns);if($cells.Count -ne 4){throw "Dictionary row does not have four columns: $tableName"};$field=(($cells[0].SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join '').Trim()
     $description=(($cells[3].SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join '').Trim();if(-not $description){throw "Missing dictionary description: $tableName.$field"}
     $column=@($modelTable.Columns|Where-Object Name -EQ $field);if($column.Count -ne 1){throw "Unknown dictionary field $tableName.$field"};$column=$column[0]
     $actualType=(($cells[1].SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join '').Trim();if($actualType -cne $column.Type){throw "Incorrect declared type or size: $tableName.$field"}
     $details=($cells[2].SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join ''
     $keyMatch=[regex]::Match($details,'^((?:PK|FK|UQ)(?:, (?:PK|FK|UQ))*)\.\s');$actualKeys=@($keyMatch.Groups[1].Value -split ',\s*'|Where-Object {$_})
     if(@(Compare-Object @($column.Keys|Sort-Object) @($actualKeys|Sort-Object)).Count){throw "Incorrect dictionary keys: $tableName.$field"}
     $required=if($column.Required){'NOT NULL.'}else{'Nullable at column level.'};if(-not $details.Contains($required)){throw "Incorrect nullability: $tableName.$field"}
     foreach($fk in @($schema.Relations|Where-Object {$_.Child -eq $tableName -and $_.Field -eq $field})){
      if(-not $details.Contains('References '+$fk.Parent+'('+$fk.ParentField+'); ON DELETE '+$fk.Delete+'; ON UPDATE NO ACTION.')){throw "Missing FK target or rule: $tableName.$field"};$verifiedFKs++
     }
     if('UQ' -in $actualKeys){if($details -notmatch '(?i)must be unique'){throw "Missing uniqueness explanation: $tableName.$field"};$verifiedUnique++}
     if($tableName -eq 'private.account_sessions' -and $field -in @('user_id','session_scope') -and -not $details.Contains('Part of composite PK (user_id, session_scope)')){throw 'Scoped-session composite key explanation is missing.'}
     if($tableName -eq 'public.activity_logs' -and $field -eq 'id' -and -not $details.Contains('Identity (GENERATED ALWAYS).')){throw 'Activity-log identity generation is missing.'}
    }
   }
   if($verifiedFKs -ne 27 -or $verifiedUnique -ne 5){throw 'Incomplete FK or unique-key dictionary coverage.'}
   foreach($field in @('requesting_session_id','session_scope')){
    $row=@($dictionary[15].SelectNodes('w:tr',$ns)|Where-Object {(($_.SelectSingleNode('w:tc',$ns).SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join '').Trim() -eq $field})
    if($row.Count -ne 1 -or -not (($row[0].SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join '').Contains('Part of composite UQ (requesting_session_id, session_scope)')){throw 'Approval composite uniqueness is missing.'}
   }
   foreach($phrase in @('Figure 3. Simplified Data Flow Overview - Gane-Sarson','Figure 3a. Complete Level 1 DFD - All Nine Processes','Figure 3b. User Login - Additional Individual Security Stores','Approval alone does not authorize access.','Normal logout retains browser trust','not a fresh live-schema introspection')){if(-not $all.Contains($phrase)){throw "Current security documentation missing: $phrase"}}
   if(([regex]::Matches($all,'Figure 3a\. Complete Level 1 DFD - All Nine Processes')).Count -ne 1){throw 'Chapter 3 must contain exactly one complete Level 1 DFD caption.'}
   if(([regex]::Matches($all,'Figure 3\. Simplified Data Flow Overview - Gane-Sarson')).Count -ne 1){throw 'Chapter 3 must retain its prior simplified DFD overview.'}
   $overviewImage=@($doc.SelectNodes('//wp:docPr',$ns)|Where-Object {$_.GetAttribute('name') -eq 'Simplified data flow overview'})
   if($overviewImage.Count -ne 1){throw 'The prior simplified DFD overview image is missing.'}
   foreach($letter in 'b','c','d','e','f','g','h','i','j'){if($all.Contains("Figure 3$letter. Level 1 DFD - Process")){throw "Obsolete split DFD caption remains: Figure 3$letter."}}
   foreach($phrase in @('No new application table or column is introduced','Current-device approval and push notifications are not included in this increment','complete fifteen-table, 174-field','All fifteen application tables and twenty-one foreign keys')){if($all.Contains($phrase)){throw "Superseded security documentation: $phrase"}}
   $results.Add('Chapter 3: four-column dictionary with 201 descriptions and declared types; 27 FK targets/actions, five individually unique fields, approval composite UQ, identity generation and composite PK verified; simplified public-schema ERD omitted and administrator security-schema supplement retained as Figure 5.')
   $dfdSvg=Join-Path (Split-Path $PSScriptRoot -Parent) 'Chapter 3 Diagrams/03-dfd-complete-gane-sarson.svg'
   if(-not (Test-Path -LiteralPath $dfdSvg)){throw 'The standalone Level 1 DFD SVG is missing.'}
   [xml]$svg=Get-Content -Raw -LiteralPath $dfdSvg
   if($svg.DocumentElement.LocalName -ne 'svg' -or $svg.DocumentElement.GetAttribute('viewBox') -ne '0 0 3360 7434'){throw 'The standalone Level 1 DFD SVG is invalid.'}
   foreach($processId in 1..9){if(-not $svg.OuterXml.Contains("process-$processId")){throw "The standalone SVG is missing process $processId."}}
   $results.Add('Chapter 3: prior DFD figure layout retained: simplified overview Figure 3, complete nine-process Level 1 DFD Figure 3a, administrator security supplement Figure 3b, plus standalone SVG verified. 12 public and 6 private dictionary tables, 201 fields, and 23 total tables verified. Simplified public-schema ERD remains omitted. Security supplements retain nine main functions and distinguish live acceptance tests from deployment output.')
  }
  $results.Add("Chapter ${chapter}: XML opens; no unexpected body/data-row bold, stale approval wording, garbled punctuation, or missing figure links detected.")
 }finally{$zip.Dispose()}
}
[void][IO.Directory]::CreateDirectory((Join-Path (Split-Path $PSScriptRoot -Parent) 'Review Evidence'))
$report=if($Chapters.Count -eq 3){'Chapter Review Verification.txt'}else{'Chapter '+($Chapters -join '-')+' Review Verification.txt'}
$results|Set-Content -Encoding UTF8 (Join-Path (Split-Path $PSScriptRoot -Parent) ('Review Evidence/'+$report))
$results
