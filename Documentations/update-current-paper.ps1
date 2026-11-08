$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$backup=Join-Path $PSScriptRoot ('Review Backups/paper-update-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
[void][IO.Directory]::CreateDirectory($backup)
# Check all write locks before changing any chapter.
foreach($chapter in 1,2,3){$s=[IO.File]::Open((Join-Path $PSScriptRoot "Chapter $chapter.docx"),'Open','ReadWrite','None');$s.Dispose()}
$testReport=Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot 'Review Evidence/System Regression Results.json')|ConvertFrom-Json
if($testReport.failed -ne 0 -or $testReport.passed -ne 40){throw 'Review the recorded regression results before reporting them in the paper.'}
foreach($chapter in 1,2,3){
 $path=Join-Path $PSScriptRoot "Chapter $chapter.docx";[IO.File]::Copy($path,(Join-Path $backup "Chapter $chapter.docx"))
 $zip=[IO.Compression.ZipArchive]::new([IO.File]::Open($path,'Open','ReadWrite'),[IO.Compression.ZipArchiveMode]::Update)
 try{
  $entry=$zip.GetEntry('word/document.xml');$r=[IO.StreamReader]::new($entry.Open());$doc=[Xml.XmlDocument]::new();$doc.PreserveWhitespace=$true;$doc.LoadXml($r.ReadToEnd());$r.Dispose()
  $n=[Xml.XmlNamespaceManager]::new($doc.NameTable);$n.AddNamespace('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main')
  function Txt($node){return ($node.SelectNodes('.//w:t',$n)|ForEach-Object InnerText)-join ''}
  function Put($node,$text){$ts=$node.SelectNodes('.//w:t',$n);if(-not $ts.Count){throw 'Paragraph text target is empty.'};$ts[0].InnerText=$text;for($i=1;$i -lt $ts.Count;$i++){$ts[$i].InnerText=''}}
  function Find($prefix){return ,($doc.SelectNodes('//w:body/w:p',$n)|Where-Object {(Txt $_).Trim().StartsWith($prefix)}|Select-Object -First 1)}
  function After($anchor,$template,$text){$p=$template.CloneNode($true);Put $p $text;[void]$anchor.ParentNode.InsertAfter($p,$anchor);return ,$p}
  function HeadingAfter($anchor,$text){$template=Find $(if($chapter -eq 2){'Related Literature'}else{'Requirements Planning'});return ,(After $anchor $template $text)}
  if($chapter -eq 1){
   $attendance=Find 'The system included a QR code-based attendance monitoring feature.'
   Put $attendance 'The system included QR code-based attendance monitoring. Authorized administrators and staff could record member check-ins and check-outs using a supported computer or phone camera. A phone required an authorized operator sign-in and an administrator-managed pairing. Each phone browser installation used its own pairing QR and record. A setup QR expired after ten minutes; successful phone pairing remained valid for thirty days unless removed earlier. Paired phones and unexpired pending QRs shared the configured slot limit, initially set to two. A pending QR reserved one slot until paired, ended, or expired. Attendance without a check-out from a previous Philippine calendar date was displayed as Incomplete; an open visit from the current day remained checked in. The system did not invent a missing check-out timestamp.'
   $membership=Find 'The system stored and organized member profiles and membership information'
   Put $membership 'The system stored member profiles and membership information, including plans, membership dates, and status. Applicants could submit online registration details for authorized staff or administrator review. Members could submit online renewal requests at any time, with approval required before a request took effect. Approval of an online renewal extended an active subscription from its current expiry date; an expired subscription restarted on the approval date. Direct counter renewal and active-member plan changes were separate operator transactions using the permitted plan, price, and membership dates.'
   $anchor=Find 'The primary users of the system were'
   if(-not (Find 'Account creation included validation')){
    $anchor=After $anchor $anchor 'Account creation included validation of required information, matching password confirmation, password-strength requirements, and duplicate usernames and email addresses. Staff account registration collected first name, optional middle initial, and last name separately and combined them into the existing full-name record. Administrator and staff accounts had to be active to use their protected functions. Members remained restricted to their own permitted personal information.'
    $anchor=After $anchor $anchor 'Dashboard sessions and attendance-scanner sessions were tracked separately. A new dashboard sign-in replaced the previous dashboard session for that account without closing its attendance scanner. A new scanner sign-in replaced the previous scanner session without closing the dashboard. Online pages checked session ownership about every five seconds; suspended or offline pages checked when they resumed or reconnected. The thirty-day pairing period applied to the phone connection and did not replace operator authentication.'
   }
   $limit=Find 'The system was limited to Iron Grind Fitness Gym.'
   if(-not (Txt $limit).Contains('Traffic capacity')){Put $limit ((Txt $limit)+' Traffic capacity and a maximum number of simultaneous users were not established by the available functional checks. A separate controlled load test and documented physical multi-phone validation remained necessary before making such performance claims.')}
   $terms=@(
    'Incomplete Attendance. A visit without a check-out whose check-in date is earlier than the current Philippine calendar date.',
    'Input Validation. Checks applied to submitted information, such as required fields, permitted formats, password requirements, and duplicate account identifiers.',
    'Pending Pairing QR. An unexpired administrator-issued QR that reserves one phone-pairing slot until pairing is completed, ended, or expires.',
    'Phone Pairing. The administrator-authorized connection of a phone browser installation to attendance scanning for the recorded pairing period.',
    'User Session. The authenticated access period associated with a particular account sign-in and its permitted dashboard or attendance-scanner scope.'
   )
   $definition=Find 'Definition of Terms';$template=Find 'Authentication.'
   foreach($term in $terms){$label=$term.Split('.')[0]+'.';if(Find $label){continue};$cursor=$definition.NextSibling;$inserted=$false
    while($cursor -and $cursor.LocalName -eq 'p'){$text=(Txt $cursor).Trim();if($text -and [string]::Compare($text,$term,[StringComparison]::OrdinalIgnoreCase) -gt 0){$p=$template.CloneNode($true);Put $p $term;[void]$cursor.ParentNode.InsertBefore($p,$cursor);$inserted=$true;break};$cursor=$cursor.NextSibling}
    if(-not $inserted){$p=$template.CloneNode($true);Put $p $term;[void]$definition.ParentNode.InsertBefore($p,$doc.SelectSingleNode('//w:body/w:sectPr',$n))}
   }
  }
  if($chapter -eq 2){
   $anchor=Find 'The National Privacy Commission was constituted'
   if(-not (Find 'Supabase (n.d.-b) describes Row Level Security')){
    $anchor=After $anchor $anchor 'Supabase (n.d.-b) describes Row Level Security as a database mechanism for restricting access to rows through policies. Its documentation shows how an authenticated identity can be used in read and write conditions. This provides a technical basis for separating identity verification from permission checks. In IronGrind, validation checks account inputs, while database policies and role-checked functions control permitted operations. Required fields, duplicate-account checks, and password confirmation complement authorization but do not themselves establish permission to read or modify another user''s information.'
    $anchor=After $anchor $anchor 'Supabase (n.d.-c) explains that an Auth access token includes a session identifier associated with an Auth session record. Session identity is therefore relevant when an application needs to distinguish sign-ins rather than treating every valid account login as interchangeable. IronGrind applies a project-specific ownership rule with separate dashboard and attendance-scanner scopes. This separation allows an authorized operator to use a dashboard and a phone scanner together. The implementation''s scope rules and polling interval are design choices of IronGrind, not claims that the platform automatically provides that exact behavior.'
    [void](After $anchor $anchor 'Supabase (n.d.-a) recommends reviewing query indexes and performing load testing, preferably in a staging environment, before production use. This supports distinguishing functional verification from measured traffic capacity. A working registration or attendance function does not establish how many simultaneous users the full system can support. For IronGrind, controlled measurements of response times, error rates, database behavior, and concurrent scanning are needed before reporting a capacity limit. These performance measurements are separate from the reported functional regression checks.')
   }
   if(-not (Find 'The additional technical literature supports')){
    $synthesis=Find 'Taken together, the reviewed literature'
    [void](After $synthesis $synthesis 'The additional technical literature supports explicit input validation, active-role authorization, session management, and a clear distinction between verification and performance evaluation. In the system design, online request review remains available to authorized staff and administrators, phone-pairing reservations share the configured capacity, and attendance states reflect whether a check-out was recorded. These are implemented workflow rules whose correctness must be checked against the source code and database. The literature provides context for these choices without establishing that IronGrind has completed a load test or achieved measured gains in efficiency or usability.')
   }
   if(-not (Find 'Additional Technical References')){
    $anchor=@($doc.SelectNodes('//w:body/w:p',$n))[-1];$anchor=HeadingAfter $anchor 'Additional Technical References'
    $body=Find 'Supabase (n.d.-b) describes Row Level Security'
    foreach($reference in @(
     'Supabase. (n.d.-a). Production checklist. Retrieved November 8, 2026, from https://supabase.com/docs/guides/deployment/going-into-prod',
     'Supabase. (n.d.-b). Row level security. Retrieved November 8, 2026, from https://supabase.com/docs/guides/database/postgres/row-level-security',
     'Supabase. (n.d.-c). User sessions. Retrieved November 8, 2026, from https://supabase.com/docs/guides/auth/sessions'
    )){$anchor=After $anchor $body $reference}
   }
  }
  if($chapter -eq 3){
   if(-not (Find 'Recorded verification as of November 8, 2026')){
    $anchor=Find 'Implementation prepares the verified increments'
    $body=$anchor;$anchor=HeadingAfter $anchor 'Verification and Evaluation'
    $anchor=After $anchor $body 'Recorded verification as of November 8, 2026 comprised forty automated check groups with no failed groups in the saved regression report. A check group may contain multiple assertions. The checks covered JavaScript syntax, local page references and identifiers, form validation, account registration, role authorization, staff operations, session ownership, attendance request handling, phone pairing, and membership-payment updates. Browser logic used simulated document and service responses; selected registration checks used the Supabase browser SDK with mocked Auth responses.'
    $anchor=After $anchor $body 'Database behavior was tested in isolated PostgreSQL fixtures using PGlite. Scenarios included rejection of unauthorized operations, duplicate requests, transaction rollback, numeric membership-payment updates, separate dashboard and scanner sessions, device-specific pairing records, pairing expiry, and the combined paired-plus-pending slot limit. Functional test writes did not create transactions in the gym''s production member records. The linked database lint check reported no errors after the corrections. The saved regression report and database lint result describe the tested code and configuration at that review date.'
    $anchor=After $anchor $body 'A separate performance evaluation remains necessary. The available regression checks do not establish a maximum number of concurrent users, a load-response-time target, or a throughput guarantee. A controlled staging test should exercise logins, dashboard reads, registrations, and simultaneous attendance scans while recording response-time distributions, error rates, and database behavior. The reported user capacity should be based on those measurements and the actual hosting configuration, consistent with the production-testing guidance discussed in Chapter 2.'
    [void](After $anchor $body 'Successful physical multi-phone operation and complete visual browser behavior require separate recorded validation. The available automated artifacts do not establish completion of that end-to-end validation. Prototype figures illustrate interface structure and roles; they should not be treated as evidence of current production screenshots or measured usability. Formal usability or stakeholder-evaluation results should be reported only after the corresponding evaluation has been conducted and documented.')
   }
   $attendance=Find '5.0 Record and View Attendance.'
   if(-not (Find 'Phone pairing capacity counts both paired devices')){
    [void](After $attendance $attendance 'Phone pairing capacity counts both paired devices and unexpired pending QR reservations. At the initial two-slot limit, the permitted combinations are two paired phones, one paired phone plus one pending QR, or two pending QRs. Scanning a reserved QR completes that reservation without allocating another slot. Creating a further QR is blocked at capacity, while an existing pending QR remains available to scan. Each browser installation has its own identifier; another installation cannot take over an assigned QR. The device label is descriptive information and does not provide hardware attestation. An expired, removed, or unsuccessful pairing is not counted as a completed device connection.')
   }
   $forms=Find 'The system uses registration, profile, renewal'
   if(-not (Find 'The Create Staff Account form collects')){
    [void](After $forms $forms 'The Create Staff Account form collects first name, optional middle initial, and last name in separate inputs. It formats a supplied initial with a period and combines the parts into the existing full_name value; separate name columns are not introduced. The form also checks username and Gmail availability, phone format, password strength, and matching confirmation. Staff directory access and activation controls remain administrator-only. The Requests approval view separately presents pending online registration and renewal summaries for authorized staff and administrator decisions, with in-person payment confirmation before approval.')
   }
   foreach($table in $doc.SelectNodes('//w:body/w:tbl',$n)){
    foreach($row in $table.SelectNodes('w:tr',$n)){$cells=$row.SelectNodes('w:tc',$n);if($cells.Count -ne 5){continue};$field=(Txt $cells[0]).Trim()
     if($field -eq 'max_pairs'){Put $cells[4] 'Limits paired phones plus unexpired pending QR reservations. Required.'}
     if($field -eq 'remember_phone'){Put $cells[4] 'Retains the original remembered-phone preference. Current successful pairings last thirty days. Required.'}
    }
   }
  }
  $entry.Delete();$entry=$zip.CreateEntry('word/document.xml');$writer=[IO.StreamWriter]::new($entry.Open(),[Text.UTF8Encoding]::new($false));$writer.Write($doc.OuterXml);$writer.Dispose()
  Write-Output "Updated Chapter $chapter with current scope, technical support, workflow rules, and recorded evidence."
 }finally{$zip.Dispose()}
}
Write-Output "Original copies saved in $backup"
