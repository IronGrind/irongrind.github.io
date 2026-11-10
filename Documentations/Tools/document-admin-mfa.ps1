$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=Split-Path $PSScriptRoot -Parent
$backup=Join-Path $root ('Review Backups/admin-mfa-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $backup -Force|Out-Null
foreach($chapter in @(1,3)) {
 $file=Join-Path $root "Chapter $chapter.docx"
 Copy-Item -LiteralPath $file -Destination (Join-Path $backup "Chapter $chapter original.docx")
 $work=Join-Path $backup "Chapter $chapter updated.docx";Copy-Item -LiteralPath $file -Destination $work
 $zip=[IO.Compression.ZipFile]::Open($work,'Update')
 try {
  $r=[IO.StreamReader]::new($zip.GetEntry('word/document.xml').Open());try{[xml]$doc=$r.ReadToEnd()}finally{$r.Dispose()}
  $n=[Xml.XmlNamespaceManager]::new($doc.NameTable);$n.AddNamespace('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main')
  $paragraphs=@($doc.SelectNodes('//w:body/w:p',$n))
  $prefix=if($chapter -eq 1){'Account creation included validation'}else{'Supabase Auth verifies credentials.'}
  $anchor=@($paragraphs|Where-Object {(($_.SelectNodes('.//w:t',$n)|ForEach-Object InnerText)-join '').Trim().StartsWith($prefix)})
  if($anchor.Count -ne 1){throw "MFA documentation anchor ambiguous in Chapter $chapter"}
  $text=if($chapter -eq 1){
   'Administrator MFA revision. The November 10, 2026 source increment adds time-based authenticator verification for administrator accounts, including administrator operator sign-in on the phone scanner. Administrators must verify a second factor before dashboard or scanner session activation and protected data access. Staff and member account flows retain their existing role checks. Enrollment is performed by the genuine administrator on a trusted device, while lost-factor recovery requires verified project-owner assistance. This increment is distinct from proposed current-device approval notifications, which are not implemented. No new application table is required because Supabase Auth manages the factors and server-side functions enforce the assurance check. Production activation and physical authenticator validation remain separate deployment tasks.'
  }else{
   'Administrator multi-factor authentication. After password authentication, the web client calls the own-account admin_mfa_required function, which exposes only whether the signed-in active account is an administrator. The shared admin-mfa.js module enrolls an authenticator when no verified TOTP factor exists or challenges an existing factor; successful verification raises the session from AAL1 to AAL2 before application session activation. The PostgreSQL migration adds assurance checks to the existing RLS/session guard, dashboard and scanner activation functions, and the preserved API pre-request guard. Therefore hiding the dialog or directly calling a protected table/RPC does not grant an AAL1 administrator access. Caller-profile checks used by protected Edge Functions also pass through this server enforcement. No new application table or column is introduced, so the existing ERD and data dictionary remain structurally applicable. Supabase manages the factor secret, while the setup QR and manual key are temporary enrollment material excluded from documentation and custom logs. First enrollment must be controlled; a password alone cannot establish genuine ownership before any factor exists. Recovery is a verified project-owner process rather than a password-only bypass. Current-device approval and push notifications are not included in this increment. The local automated MFA fixtures cover enrollment/challenge presentation, cancellation, AAL1 denial and AAL2 access; hosted TOTP enablement, coordinated deployment and actual-device verification remain pending until separately performed. Supabase TOTP integration guidance: https://supabase.com/docs/guides/auth/auth-mfa/totp.'
  }
  if(-not (($doc.SelectNodes('//w:t',$n)|ForEach-Object InnerText)-join '').Contains('Administrator MFA revision.') -and -not (($doc.SelectNodes('//w:t',$n)|ForEach-Object InnerText)-join '').Contains('Administrator multi-factor authentication. After password')){
   $p=$anchor[0].CloneNode($true)
   foreach($bookmark in @($p.SelectNodes('.//w:bookmarkStart|.//w:bookmarkEnd',$n))){[void]$bookmark.ParentNode.RemoveChild($bookmark)}
   $runs=@($p.SelectNodes('.//w:t',$n));$runs[0].InnerText=$text;foreach($run in @($runs|Select-Object -Skip 1)){$run.InnerText=''}
   [void]$anchor[0].ParentNode.InsertAfter($p,$anchor[0])
  }
  $stream=$zip.GetEntry('word/document.xml').Open();$stream.SetLength(0);$writer=[IO.StreamWriter]::new($stream,[Text.UTF8Encoding]::new($false));try{$doc.Save($writer)}finally{$writer.Dispose()}
 }finally{$zip.Dispose()}
}
foreach($chapter in @(1,3)){$s=[IO.File]::Open((Join-Path $root "Chapter $chapter.docx"),'Open','ReadWrite','None');$s.Dispose()}
foreach($chapter in @(1,3)){Copy-Item -LiteralPath (Join-Path $backup "Chapter $chapter updated.docx") -Destination (Join-Path $root "Chapter $chapter.docx") -Force}
"MFA addenda applied. Originals: $backup"
