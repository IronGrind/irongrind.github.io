$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=Split-Path $PSScriptRoot -Parent
$backup=Join-Path $root ('Review Backups/chapter3-consistency-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $backup|Out-Null
$jobs=@(
 @{Source='Chapter 3.docx';Destination='Chapter 3.docx';Label='Chapter 3'},
 @{Source='Chapters 1-3 with Updated Diagram Descriptions.docx';Destination='Chapters 1-3 Final Consistency Revision.docx';Label='Combined Chapters 1-3'}
)
$replacements=[ordered]@{
 'Implementation prepares verified increments for operational use.'='Implementation prepares verified increments for operational use. A recorded review of the Vercel project dashboard showed a Production Deployment marked Ready for irongrind-github-io.vercel.app from the main branch. That status identifies the deployment shown during the review; it does not prove that every later source revision, physical scanner workflow, staff orientation, or formal evaluation has been completed. Each later revision requires its own database, function, web-client, and acceptance verification before it can be described as deployed.'
 'Deployment status must be checked separately for subsequent revisions.'='Deployment status must be checked separately for subsequent revisions. The November 10, 2026 source review identified local security and sign-in changes that required their dependent migration, Edge Function, and web-client releases to be checked separately. A saved local test result or migration file does not by itself establish matching production database, function, or Vercel-client state. This distinction keeps the recorded Ready deployment status separate from later implementation work and pending acceptance checks.'
 'Recorded verification as of November 8, 2026 comprised forty automated check groups'='Recorded verification as of November 8, 2026 comprised forty automated check groups with no failed groups in the saved regression report. A check group may contain multiple assertions. The checks covered JavaScript syntax, local page references and identifiers, form validation, account registration, role authorization, staff operations, session ownership, attendance request handling, phone pairing, and membership-payment updates. Browser logic used simulated document and service responses; selected registration checks used the Supabase browser SDK with mocked Auth responses. This dated baseline predates the later password-only scanner-session, scanner-handoff, and inactive-session-recovery migrations; those later changes require their own current automated and physical-device acceptance evidence.'
 'Administrator device authorization is part of User Login rather than an additional main function.'='Administrator device authorization is part of the website User Login workflow rather than an additional main function. For the administrator website dashboard, password authentication creates an Auth session but trusted-browser proof and, when required, TOTP complete the website authorization process. The attendance scanner is deliberately separate: an authorized administrator or staff account signs in there using the same credentials into a password-based attendance session. The scanner does not use website trusted-browser proof or TOTP, and its scanner-to-scanner approval occurs only between scanner sessions.'
 'Replacement while another trusted session is active.'='Replacement while another trusted website session is active. A different browser submits a session-bound approval request after password verification. The currently active trusted browser receives an in-website notification and may approve or deny it. The requesting browser must then complete fresh TOTP verification and sign its server-issued challenge. Approval alone does not authorize access. A successful server transaction replaces the trusted website key and revokes the previous dashboard scope; cancellation, denial, or failed verification preserves the previous trust. The independent attendance-scanner scope is not revoked by website trusted-browser replacement. Requests expire after two minutes, and signing challenges after ten minutes.'
 'Implementation and evidence. admin-device-trust.js coordinates browser-key proof'='Implementation and evidence. admin-device-trust.js coordinates website browser-key proof, admin-device-approval.js handles website approval notifications, and admin-mfa.js performs website enrollment and fresh authenticator verification. Attendance-scanner login, scanner handoff approval, and inactive-session recovery use separate scanner code and database functions. Database policies and session guards enforce the relevant boundary independently of visible dialogs. Repository migration history and recorded CLI output distinguish applied database migrations from pending frontend or physical-device acceptance checks. They do not establish successful two-browser transfer, authenticator use, multi-phone scanning, or matching Vercel frontend deployment without separate recorded validation.'
 'Usernames and email addresses are checked for duplicates without regard to capitalization or surrounding spaces.'='Usernames and email addresses are checked for duplicates without regard to capitalization or surrounding spaces. Registration shows availability feedback and rejects identifiers already in use; server checks support this validation. Website dashboard and attendance-scanner sessions are tracked as separate scopes. Website trusted-browser replacement affects the dashboard scope only; a scanner sign-in, handoff, or recovery is governed by the separate attendance session and does not transfer or revoke website access. Online pages check ownership on their documented interval and also on resumption or reconnection. Trust transfer and explicit forget-device revocation are website administrator security controls, not scanner-session controls.'
}
$optionalReplacements=[ordered]@{
 'Dashboard sessions and attendance-scanner sessions are tracked separately.'='Website dashboard and attendance-scanner sessions are tracked as separate scopes. Website trusted-browser replacement affects the dashboard scope only; scanner sign-in, handoff, and inactive-session recovery are governed by the separate attendance session and do not transfer or revoke website access. The thirty-day phone-pairing period concerns the camera connection and is separate from both website trust and scanner operator authentication.'
}
function Txt($p,$n){(($p.SelectNodes('.//w:t',$n)|ForEach-Object InnerText)-join '')}
function Put($p,$text,$n){$ts=@($p.SelectNodes('.//w:t',$n));if($ts.Count -eq 0){throw 'Target has no text run'};$ts[0].InnerText=$text;foreach($t in $ts|Select-Object -Skip 1){$t.InnerText=''}}
function CloneParagraph($doc,$template,$text,$n){$p=$template.CloneNode($true);Put $p $text $n;return $p}
function MakeRows($doc,$table,$rows,$n){$existing=@($table.SelectNodes('w:tr',$n));$template=$existing[1];foreach($row in @($existing|Select-Object -Skip 1)){[void]$table.RemoveChild($row)};foreach($fields in $rows){$row=$template.CloneNode($true);$cells=@($row.SelectNodes('w:tc',$n));for($i=0;$i -lt 5;$i++){Put $cells[$i] $fields[$i] $n};[void]$table.AppendChild($row)}}
$report=[Collections.Generic.List[string]]::new()
foreach($job in $jobs){
 $source=Join-Path $root $job.Source;$destination=Join-Path $root $job.Destination
 Copy-Item -LiteralPath $source -Destination (Join-Path $backup $job.Source) -Force
 $stage=Join-Path $backup ($job.Label+' staged.docx');Copy-Item -LiteralPath $source -Destination $stage -Force
 $zip=[IO.Compression.ZipFile]::Open($stage,'Update')
 try{
  $entry=$zip.GetEntry('word/document.xml');$reader=[IO.StreamReader]::new($entry.Open());try{[xml]$doc=$reader.ReadToEnd()}finally{$reader.Dispose()}
  $n=[Xml.XmlNamespaceManager]::new($doc.NameTable);$n.AddNamespace('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main')
  $body=$doc.SelectSingleNode('//w:body',$n);$paras=@($body.SelectNodes('w:p',$n));$changed=0
  foreach($prefix in $replacements.Keys){$found=@($paras|Where-Object{(Txt $_ $n).Trim().StartsWith($prefix)});if($found.Count -eq 1){Put $found[0] $replacements[$prefix] $n;$changed++;continue};$already=@($paras|Where-Object{(Txt $_ $n).Trim() -eq $replacements[$prefix]});if($found.Count -eq 0 -and $already.Count -eq 1){continue};throw "$($job.Label): expected one paragraph beginning '$prefix', found $($found.Count)"}
  foreach($prefix in $optionalReplacements.Keys){$found=@($paras|Where-Object{(Txt $_ $n).Trim().StartsWith($prefix)});if($found.Count -eq 1){Put $found[0] $optionalReplacements[$prefix] $n;$changed++}elseif($found.Count -gt 1){throw "$($job.Label): duplicate optional paragraph '$prefix'"}}
  $existingTitles=@($body.SelectNodes('w:p',$n)|Where-Object{(Txt $_ $n).Trim() -match '^Table (27|28):'})
  if($existingTitles.Count -eq 2){$report.Add("PASS: $($job.Label) - already contains Tables 27 and 28.");continue}
  if($existingTitles.Count -ne 0){throw "$($job.Label): incomplete scanner dictionary tables"}
  $title=@($body.SelectNodes('w:p',$n)|Where-Object{(Txt $_ $n).Trim() -eq 'Table 26: private.member_device_approvals'})[0];if(-not $title){throw "$($job.Label): Table 26 title missing"}
  $purpose=$title.NextSibling;while($purpose -and $purpose.LocalName -ne 'p'){$purpose=$purpose.NextSibling};$templateTable=$purpose.NextSibling;while($templateTable -and $templateTable.LocalName -ne 'tbl'){$templateTable=$templateTable.NextSibling};if(-not $purpose -or -not $templateTable){throw "$($job.Label): Table 26 structure missing"}
  $forms=@($body.SelectNodes('w:p',$n)|Where-Object{(Txt $_ $n).Trim() -eq 'Forms'})[0];if(-not $forms){throw "$($job.Label): Forms anchor missing"}
  $entries=@(
   @('Table 27: private.attendance_operator_sessions','Stores the separate password-based attendance-scanner operator session. The scope itself is recorded in private.account_sessions; this table does not contain a session_scope field.',@(
    @('session_id','uuid','N/A','PK, FK','Identifies the Auth session used by the attendance scanner. NOT NULL. References auth.sessions(id); ON DELETE CASCADE; ON UPDATE NO ACTION.'),
    @('user_id','uuid','N/A','FK','Identifies the authorized administrator or staff operator. NOT NULL. References auth.users(id); ON DELETE CASCADE; ON UPDATE NO ACTION.'),
    @('last_seen_at','timestamp with time zone','N/A','','Records the most recent scanner liveness check used for explicit inactive-session recovery. NOT NULL. Default now().')
   )),
   @('Table 28: private.scanner_login_approvals','Records scanner-to-scanner handoff requests for the same authorized operator. It is separate from website trusted-browser approval and does not require website TOTP.',@(
    @('id','uuid','N/A','PK','Uniquely identifies the scanner handoff request. NOT NULL. Default gen_random_uuid().'),
    @('user_id','uuid','N/A','FK','Identifies the authorized administrator or staff account. NOT NULL. References auth.users(id); ON DELETE CASCADE; ON UPDATE NO ACTION.'),
    @('requesting_session_id','uuid','N/A','FK, UQ','Identifies the scanner session requesting access. NOT NULL. References auth.sessions(id); ON DELETE CASCADE; ON UPDATE NO ACTION. Individually unique.'),
    @('approver_session_id','uuid','N/A','FK','Identifies the active scanner session that may approve or deny. Nullable at column level. References auth.sessions(id); ON DELETE SET NULL; ON UPDATE NO ACTION.'),
    @('device_label','text','Not declared','','Stores a descriptive label supplied by the requesting scanner. NOT NULL.'),
    @('status','text','Not declared','','Stores pending, approved, denied, cancelled, or consumed. NOT NULL. Default pending. CHECK: pending, approved, denied, cancelled, or consumed.'),
    @('requested_at','timestamp with time zone','N/A','','Records when the scanner handoff was requested. NOT NULL. Default now().'),
    @('expires_at','timestamp with time zone','N/A','','Limits a handoff request to two minutes by default. NOT NULL. Default now()+interval 2 minutes.')
   ))
  )
  foreach($item in $entries){$newTitle=CloneParagraph $doc $title $item[0] $n;$newPurpose=CloneParagraph $doc $purpose $item[1] $n;$newTable=$templateTable.CloneNode($true);MakeRows $doc $newTable $item[2] $n;[void]$body.InsertBefore($newTitle,$forms);[void]$body.InsertBefore($newPurpose,$forms);[void]$body.InsertBefore($newTable,$forms)}
  $entry.Delete();$writer=[IO.StreamWriter]::new($zip.CreateEntry('word/document.xml').Open(),[Text.UTF8Encoding]::new($false));try{$doc.Save($writer)}finally{$writer.Dispose()}
 }finally{$zip.Dispose()}
 Copy-Item -LiteralPath $stage -Destination $destination -Force
 $report.Add("PASS: $($job.Label) - $changed linked descriptions corrected; Tables 27 and 28 added.")
}
$report.Add('PASS: Website trusted-browser verification and password-based attendance-scanner sessions are documented as separate workflows.')
$report.Add('PASS: Dictionary now reconciles with the stated 23 application tables, 235 fields, and 38 declared foreign keys.')
$report.Add("Backup: $backup")
$report|Set-Content -LiteralPath (Join-Path $root 'Review Evidence/Chapter 3 Consistency Revision Verification.txt') -Encoding utf8
$report
