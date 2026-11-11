$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=Split-Path $PSScriptRoot -Parent
$target=Join-Path $root 'Chapters 1-3 (MAO NA JUD NI).docx'
$backup=Join-Path $root ('Review Backups/main-wording-before-correction-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $backup|Out-Null
Copy-Item -LiteralPath $target -Destination (Join-Path $backup 'Chapters 1-3 (MAO NA JUD NI).docx') -Force
$stage=Join-Path $backup 'main staged.docx';Copy-Item -LiteralPath $target -Destination $stage -Force

# XML text-node replacements preserve paragraph, table, drawing, page, and run formatting.
$changes=[ordered]@{
 'A fitness Gym Membership and Operations Management System'='A Fitness Gym Membership and Operations Management System'
 'successful replacement revokes the previous trust and dashboard/scanner scopes.'='successful replacement revokes the previous trust and website dashboard scope.'
 'To develop a QR code-based attendance monitoring feature that allows authorized staff to record member check-ins and check-outs.'='To develop a QR code-based attendance monitoring feature that allows authorized administrators and staff to record member check-ins and check-outs.'
 'Separates dashboard login from attendance-scanner login. NOT NULL. CHECK dashboard or attendance. Part of composite UQ (requesting_session_id, session_scope); the pair must be unique, not either column individually.'='The schema permits dashboard or attendance labels. Current administrator trusted-browser approval is for the website dashboard only; attendance-scanner handoff uses private.scanner_login_approvals. NOT NULL. CHECK dashboard or attendance. Part of composite UQ (requesting_session_id, session_scope); the pair must be unique, not either column individually.'
 'Identifies the application scope being authorized. NOT NULL. CHECK dashboard or attendance.'='Identifies the application scope label stored by the table. The schema permits dashboard or attendance, but the current administrator trusted-browser flow authorizes the website dashboard only; scanner authorization uses separate private scanner tables. NOT NULL. CHECK dashboard or attendance.'
 'The migration and required functions were recorded as deployed; controlled member browser-acceptance testing remained pending.'='The checked-in migration and required functions document this design; controlled member browser-acceptance testing remained pending.'
}
$expectedCounts=@{'A fitness Gym Membership and Operations Management System'=2}
$zip=[IO.Compression.ZipFile]::Open($stage,'Update')
try{
 $entry=$zip.GetEntry('word/document.xml');$reader=[IO.StreamReader]::new($entry.Open());try{[xml]$doc=$reader.ReadToEnd()}finally{$reader.Dispose()}
 $n=[Xml.XmlNamespaceManager]::new($doc.NameTable);$n.AddNamespace('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main')
 $all=($doc.SelectNodes('//w:t',$n)|ForEach-Object InnerText)-join "`n"
 $counts=[ordered]@{}
 foreach($old in $changes.Keys){$count=([regex]::Matches($all,[regex]::Escape($old))).Count;$expected=if($expectedCounts.ContainsKey($old)){$expectedCounts[$old]}else{1};if($count -ne $expected){throw "Expected $expected text occurrence(s) for: $old. Found $count."};$counts[$old]=$count}
 foreach($node in $doc.SelectNodes('//w:t',$n)) {foreach($old in $changes.Keys){if($node.InnerText.Contains($old)){$node.InnerText=$node.InnerText.Replace($old,$changes[$old])}}}
 $updated=($doc.SelectNodes('//w:t',$n)|ForEach-Object InnerText)-join "`n"
 foreach($new in $changes.Values){if(-not $updated.Contains($new)){throw "Missing replacement: $new"}}
 $entry.Delete();$writer=[IO.StreamWriter]::new($zip.CreateEntry('word/document.xml').Open(),[Text.UTF8Encoding]::new($false));try{$doc.Save($writer)}finally{$writer.Dispose()}
}finally{$zip.Dispose()}
$lock=[IO.File]::Open($target,'Open','ReadWrite','None');$lock.Dispose();Copy-Item -LiteralPath $stage -Destination $target -Force
$report=@('PASS: seven wording corrections applied directly to the designated main manuscript.','PASS: paragraph, table, drawing, image, margin, section, and page-layout properties were not edited.','Backup: '+$backup)
$report|Set-Content -LiteralPath (Join-Path $root 'Review Evidence/Main Manuscript Wording Correction Verification.txt') -Encoding utf8
$report
