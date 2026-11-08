$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$backup=Join-Path $PSScriptRoot ('Review Backups/'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
[void][IO.Directory]::CreateDirectory($backup)
$report=[Collections.Generic.List[string]]::new()
foreach($chapter in 1,2,3){
 $path=Join-Path $PSScriptRoot "Chapter $chapter.docx"
 [IO.File]::Copy($path,(Join-Path $backup "Chapter $chapter.docx"))
 $zip=[IO.Compression.ZipArchive]::new([IO.File]::Open($path,'Open','ReadWrite'),[IO.Compression.ZipArchiveMode]::Update)
 try{
  $entry=$zip.GetEntry('word/document.xml');$reader=[IO.StreamReader]::new($entry.Open());$d=[Xml.XmlDocument]::new();$d.PreserveWhitespace=$true;$d.LoadXml($reader.ReadToEnd());$reader.Dispose()
  $n=[Xml.XmlNamespaceManager]::new($d.NameTable);$n.AddNamespace('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main');$n.AddNamespace('wp','http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing')
  function Txt($p){return ($p.SelectNodes('.//w:t',$n)|ForEach-Object InnerText)-join ''}
  function Put($p,$text){$ts=$p.SelectNodes('.//w:t',$n);if($ts.Count){$ts[0].InnerText=$text;for($k=1;$k -lt $ts.Count;$k++){$ts[$k].InnerText=''}}}
  function Prop($parent,$name){$node=$parent.SelectSingleNode("w:$name",$n);if(-not $node){$node=$d.CreateElement('w',$name,$n.LookupNamespace('w'));[void]$parent.AppendChild($node)};return ,$node}
  function Attr($node,$name,$value){[void]$node.SetAttribute($name,$n.LookupNamespace('w'),[string]$value)}
  function AddAfter($anchor,$text){$p=$anchor.CloneNode($true);Put $p $text;[void]$anchor.ParentNode.InsertAfter($p,$anchor);return ,$p}
  foreach($p in @($d.SelectNodes('//w:p',$n))){
   $old=Txt $p;$text=$old
   $badApostrophe=[string][char]0xE2+[char]0x20AC+[char]0x2122
   $text=$text.Replace($badApostrophe,"'").Replace('`membership_history`','membership_history')
   $text=$text.Replace('online for administrator review','online for authorized staff or administrator review').Replace('each request required administrator approval','each request required approval by authorized staff or the administrator').Replace('awaits administrator review','awaits review by authorized staff or the administrator')
   $text=$text.Replace('plays crucial role','plays a crucial role').Replace('The Data Process Modelling illustrates','Data process modeling illustrates').Replace('Definition of terms','Definition of Terms').Replace('Table 6: profile','Table 6: profiles')
   $text=$text.Replace('Only administrators review online requests and approve or reject them.','Authorized staff and administrators review online requests and approve or reject them.').Replace('instead of granting staff online-review permission.','as a separate counter operation.').Replace('Administrators approve or reject these requests.','Authorized staff and administrators approve or reject these requests.').Replace('and do not grant staff permission to review online requests.','and are separate from the online Requests approval workflow.')
   $text=$text.Replace('which is then sent to the Admin for review','which is then sent to authorized staff or the administrator for review')
   $text=$text.Replace('The object model ensures','The use-case model identifies').Replace('ensures that all necessary functions are clearly defined, organized, and accessible only to authorized users to maintain security and accuracy.','the functions and actor permissions documented for the system.')
   $text=$text.Replace('The use-case model identifies that all necessary functions are clearly defined, organized, and accessible only to authorized users to maintain security and accuracy.','The use-case model identifies the documented functions and actor permissions.')
   $text=$text.Replace('D13 private attendance scan requests.','D13 private attendance scan requests, and D14 private account sessions.')
   $text=$text.Replace('twelve public-schema tables from two private supporting tables','twelve public-schema tables from three private supporting tables').Replace('same baseline rather than assuming','baseline and subsequent migrations rather than assuming')
   if($chapter -eq 1 -and $text.Trim().StartsWith('The primary users of the system were')){
    $text='The primary users of the system were the gym administrator, authorized staff, and registered gym members. The administrator could view member personal profiles without editing their personal details and manage membership operations, attendance, inventory, sales, staff accounts, phone pairings, activity logs, and reports. Authorized staff could record attendance, register walk-in members, process direct renewals and active-member plan changes using limited member lookup, record product sales, and review their own product-sale records. Both staff and administrators could approve or reject online registration and renewal requests, confirming in-person payment before approval. Staff could not view or edit existing member personal profiles. Members could view and update their own permitted personal details, access their membership status, attendance history and QR code, browse active products, and request renewal. Walk-in product purchases could be recorded without a member account.'
   }
   if($chapter -eq 2 -and $text.Trim().StartsWith('Gymdesk was founded')){
    $text='Gymdesk presents a commercial approach to centralized gym administration. Its founder account describes the development of the platform from a side project into a service used by gyms (Gymdesk, 2025). Its relevance to IronGrind lies in bringing membership and operational information into an organized system. IronGrind applies that principle to a single gym through linked member, attendance, inventory, and transaction records. Features offered by a commercial platform are points of comparison; they do not establish which functions IronGrind implements or demonstrate the performance of the local system.'
   }
   if($chapter -eq 2 -and $text.Trim().StartsWith('Villanueva, Sevilla, and Verecio')){
    $text='Villanueva, Sevilla, and Verecio (2025) examined manual attendance, subscription monitoring, sales recording, and reporting at Olympic Fitness Gym in Tacloban City. Their study proposed a management system integrating QR code technology to address limitations in manual records and monitoring. It is relevant to IronGrind because both projects concern organizing membership and attendance information in a gym setting. IronGrind uses operator-scanned member QR codes and stores attendance separately from current membership details. The comparison supports the choice of related functions; it does not establish measured improvements for IronGrind.'
   }
   if($chapter -eq 2 -and $text.Trim().StartsWith('Bulaclac, Pastorfide, Herrera, and Tambio')){
    $text='Bulaclac, Pastorfide, Herrera, and Tambio (2025) developed a QR-enabled cashless payment and product-monitoring system for a Philippine fitness enterprise. They reported an 80% reduction in average transaction time, 95% accuracy in financial and inventory tracking, and a mean System Usability Scale score of 88 out of 100. These are findings for their evaluated system. The study is relevant to IronGrind because it examines linked operational records and QR-supported gym services. IronGrind records payments made in person and does not implement the cashless payment process studied by these authors. Its own accuracy, efficiency, and usability must be evaluated separately.'
   }
   if($chapter -eq 2 -and $text.Trim().StartsWith('Babili (2026) developed GymFlow')){
    $text='Babili (2026) presents GymFlow in an author-posted project report on an integrated fitness-center management system. The report describes membership administration, QR attendance, workout planning, payment recording, and progress analytics. It reports QR accuracy of 98.7%, processing time of 1.2 seconds, support for 200 concurrent users, and a System Usability Scale score of 85.6. These figures are author-reported results for GymFlow, not independently verified findings or results for IronGrind. The report provides a comparison for combining membership and attendance functions, while its workout planning, analytics, and simulated payment gateway differ from the scope of IronGrind. The author-posted report should be distinguished from a peer-reviewed journal article.'
   }
   if($chapter -eq 3 -and $text.Trim().StartsWith('The physical ERD in Figure 5a-c')){$text=$text.Replace('checked-in database migration baseline','database baseline and subsequent session-security migrations')}
   if($chapter -eq 3 -and $text.Trim().StartsWith('The physical model also includes')){
    $addition='The fifteen application-owned tables comprise twelve public and three private tables, including private.account_sessions for separate dashboard and attendance-scanner session ownership.'
    if(-not $text.Contains($addition)){$text=$text.Replace('managed Auth internals are outside the application-owned table count.','managed Auth internals are outside the application-owned table count. '+$addition)}
    while($text.Contains($addition+' '+$addition)){$text=$text.Replace($addition+' '+$addition,$addition)}
   }
   if($text -cne $old){Put $p $text}
  }
  if($chapter -eq 3){
   $paragraphs=@($d.SelectNodes('//w:body/w:p',$n))
   $seenErd=$false;$previousText=''
   foreach($p in $paragraphs){$text=(Txt $p).Trim()
    if($text -eq 'Entity Relationship Diagram'){if($seenErd){[void]$p.ParentNode.RemoveChild($p);continue};$seenErd=$true}
    if($text -and $text -eq $previousText -and $text.StartsWith('The Length / Precision / Scale')){[void]$p.ParentNode.RemoveChild($p);continue}
    if($text){$previousText=$text}
   }
   $staff=$d.SelectNodes('//w:body/w:p',$n)|Where-Object {(Txt $_).Trim().StartsWith('Staff use cases are limited')}|Select-Object -First 1
   if($staff){$text=Txt $staff;$counter=$text.IndexOf('The staff Renewal action');$requests=$text.IndexOf('The Requests approval tab');if($counter -ge 0 -and $requests -gt $counter){Put $staff $text.Substring(0,$counter).Trim();$next=AddAfter $staff $text.Substring($counter,$requests-$counter).Trim();[void](AddAfter $next $text.Substring($requests).Trim())}}
   $anchor=$d.SelectNodes('//w:body/w:p',$n)|Where-Object {(Txt $_).Trim().StartsWith('Supabase Auth verifies credentials.') }|Select-Object -First 1
   if($anchor -and -not $d.OuterXml.Contains('Dashboard sessions and attendance-scanner sessions are tracked separately.')){
    [void](AddAfter $anchor 'Usernames and email addresses are checked for duplicates without regard to capitalization or surrounding spaces. Registration shows availability feedback and rejects account identifiers already in use. Server-side account and database checks support this validation. Dashboard sessions and attendance-scanner sessions are tracked separately. A new dashboard login replaces the earlier dashboard session without closing a staff or administrator attendance scanner; a new scanner login replaces the earlier scanner session without closing the dashboard. The older online page checks session ownership about every five seconds and returns to sign-in when replaced. Offline or suspended pages check when they resume or reconnect.')
   }
   $anchor=$d.SelectNodes('//w:body/w:p',$n)|Where-Object {(Txt $_).Trim().StartsWith('5.0 Record and View Attendance.') }|Select-Object -First 1
   if($anchor -and -not (Txt $anchor).Contains('thirty days')){Put $anchor ((Txt $anchor)+' A phone without an active pairing displays Phone not paired and must scan an administrator-generated pairing QR before member attendance scanning. The setup QR expires after ten minutes; successful pairing lasts thirty days from pairing time unless removed earlier. Reopening the camera does not renew that period. Missing check-outs from a previous Philippine calendar date are labeled Incomplete; current-day open visits remain checked in. The display does not invent a check-out time.')}
   if(-not $d.OuterXml.Contains('Table 20: private.account_sessions')){
    $tables=@($d.SelectNodes('//w:body/w:tbl',$n));$table=$tables[-1].CloneNode($true)
    $rows=@($table.SelectNodes('w:tr',$n));$template=$rows[1].CloneNode($true)
    foreach($row in $rows|Select-Object -Skip 1){[void]$table.RemoveChild($row)}
    $fields=@(
     @('user_id','uuid','N/A','PK, FK','Identifies the Auth account; references auth.users(id). Required.'),
     @('session_id','uuid','N/A','','Identifies the accepted Auth session. Required.'),
     @('session_created_at','timestamptz','N/A','','Records session creation time for replacement ordering. Required.'),
     @('session_scope','text','Not declared','PK','Separates dashboard and attendance sessions; CHECK limits values to dashboard or attendance. Required.')
    )
    foreach($field in $fields){$row=$template.CloneNode($true);$cells=$row.SelectNodes('w:tc',$n);for($k=0;$k -lt 5;$k++){Put $cells[$k] $field[$k]};[void]$table.AppendChild($row)}
    $anchor=$tables[-1];$caption=$d.CreateElement('w','p',$n.LookupNamespace('w'));$run=$d.CreateElement('w','r',$n.LookupNamespace('w'));$t=$d.CreateElement('w','t',$n.LookupNamespace('w'));$t.InnerText='Table 20: private.account_sessions';[void]$run.AppendChild($t);[void]$caption.AppendChild($run);[void]$anchor.ParentNode.InsertAfter($caption,$anchor);[void]$caption.ParentNode.InsertAfter($table,$caption)
    $description=$caption.CloneNode($true);Put $description 'Stores the active dashboard and attendance-scanner sessions. The composite primary key is user_id and session_scope.';[void]$table.ParentNode.InsertAfter($description,$table)
   }
  }
  $removed=0;$body=$d.SelectSingleNode('//w:body',$n)
  foreach($p in @($body.SelectNodes('w:p',$n))){if(-not (Txt $p).Trim() -and -not $p.SelectSingleNode('.//w:drawing | .//w:pict | .//w:object | .//w:sectPr | .//w:br | .//w:fldChar | .//w:instrText',$n) -and -not $p.SelectSingleNode('w:pPr/w:pageBreakBefore',$n)){[void]$body.RemoveChild($p);$removed++}}
  $headingCount=0;$bodyCount=0
  foreach($p in $d.SelectNodes('//w:p',$n)){
   $ts=$p.SelectNodes('.//w:t',$n);if($ts.Count){$ts[0].InnerText=$ts[0].InnerText.TrimStart();$ts[$ts.Count-1].InnerText=$ts[$ts.Count-1].InnerText.TrimEnd();foreach($t in $ts){$t.InnerText=$t.InnerText -replace '[\t ]{2,}',' '}}
   $text=(Txt $p).Trim();$pr=$p.SelectSingleNode('w:pPr',$n);if(-not $pr){$pr=$d.CreateElement('w','pPr',$n.LookupNamespace('w'));[void]$p.PrependChild($pr)}
   $inTable=$p.SelectSingleNode('ancestor::w:tc',$n);$style=$pr.SelectSingleNode('w:pStyle',$n)
   $chapterTitle=$text -match '^Chapter [123]$|^INTRODUCTION$|^RESEARCH METHODOLOGY$|^REVIEW OF RELATED LITERATURE AND STUDIES$'
   $caption=$text -match '^(Figure|Table)\s+\d'
   $heading=(-not $inTable -and -not $caption -and (($style -and $style.val -match '^Heading' -and $text.Length -lt 120) -or $text -eq 'Overall Description' -or $text -match '^\d+\.0 [^.]{1,60}$' -or $text -eq '1. Authenticate Account'))
   $image=$p.SelectSingleNode('.//w:drawing | .//w:pict',$n)
   foreach($tag in @('spacing','jc','ind','keepNext')){foreach($old in @($pr.SelectNodes("w:$tag",$n))){[void]$pr.RemoveChild($old)}}
   $sp=Prop $pr 'spacing';$jc=Prop $pr 'jc';$ind=Prop $pr 'ind';Attr $sp 'lineRule' 'auto'
   $bold=$false
   if($inTable){$row=$p.SelectSingleNode('ancestor::w:tr',$n);$bold=-not $row.SelectSingleNode('preceding-sibling::w:tr',$n);Attr $sp 'line' 240;Attr $sp 'after' 40;Attr $jc 'val' 'left';Attr $ind 'firstLine' 0}
   elseif($chapterTitle){$bold=$true;Attr $jc 'val' 'center';Attr $sp 'line' 360;Attr $sp 'after' 120;Attr $ind 'firstLine' 0;[void](Prop $pr 'keepNext');$headingCount++}
   elseif($heading){$bold=$true;Attr $jc 'val' 'left';Attr $sp 'line' 240;Attr $sp 'before' 200;Attr $sp 'after' 80;Attr $ind 'firstLine' 0;[void](Prop $pr 'keepNext');$headingCount++}
   elseif($caption -or $image){Attr $jc 'val' $(if($text.StartsWith('Table')){'left'}else{'center'});Attr $sp 'line' 240;Attr $sp 'before' 80;Attr $sp 'after' 100;Attr $ind 'firstLine' 0;if($text.StartsWith('Table')){[void](Prop $pr 'keepNext')}}
   else{Attr $jc 'val' 'both';Attr $sp 'line' 360;Attr $sp 'before' 0;Attr $sp 'after' 100;if(-not $pr.SelectSingleNode('w:numPr',$n)){Attr $ind 'firstLine' 720};$bodyCount++}
   [void](Prop $pr 'widowControl')
   $allProperties=@((Prop $pr 'rPr'))
   foreach($run in $p.SelectNodes('.//w:r',$n)){$rp=$run.SelectSingleNode('w:rPr',$n);if(-not $rp){$rp=$d.CreateElement('w','rPr',$n.LookupNamespace('w'));[void]$run.PrependChild($rp)};$allProperties+=,$rp}
   foreach($rp in $allProperties){foreach($tag in 'b','bCs'){Attr (Prop $rp $tag) 'val' $(if($bold){'1'}else{'0'})}}
  }
  $entry.Delete();$entry=$zip.CreateEntry('word/document.xml');$writer=[IO.StreamWriter]::new($entry.Open(),[Text.UTF8Encoding]::new($false));$writer.Write($d.OuterXml);$writer.Dispose()
  $report.Add("Chapter ${chapter}: $headingCount headings; $bodyCount body paragraphs; $removed empty spacer paragraphs removed.")
 }finally{$zip.Dispose()}
}
$report.Add("Backups: $backup")
$report|Set-Content -Encoding UTF8 (Join-Path $PSScriptRoot 'Chapter Formatting Verification.txt')
$report
