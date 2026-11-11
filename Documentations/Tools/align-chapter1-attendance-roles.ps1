$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=Split-Path $PSScriptRoot -Parent
$path=Join-Path $root 'Chapters 1-3 (MAO NA JUD NI).docx'
$backup=Join-Path $root ('Review Backups/chapter1-attendance-role-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $backup|Out-Null
Copy-Item -LiteralPath $path -Destination (Join-Path $backup 'main-before.docx')
$stage=Join-Path $backup 'main-staged.docx';Copy-Item -LiteralPath $path -Destination $stage
$zip=[IO.Compression.ZipFile]::Open($stage,'Update')
try{
 $entry=$zip.GetEntry('word/document.xml');$reader=[IO.StreamReader]::new($entry.Open())
 try{[xml]$doc=$reader.ReadToEnd()}finally{$reader.Dispose()}
 $ns=[Xml.XmlNamespaceManager]::new($doc.NameTable);$ns.AddNamespace('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main')
 $pairs=@(
  @{Old='It also incorporates QR code-based attendance monitoring, allowing authorized staff to record member check-ins and check-outs.';New='It also incorporates QR code-based attendance monitoring, allowing authorized administrators and staff to record member check-ins and check-outs.'},
  @{Old='Authorized staff can scan the code to record a member';New='Authorized administrators and staff can scan the code to record a member'}
 )
 foreach($pair in $pairs){
  $matches=@($doc.SelectNodes('//w:body//w:p',$ns)|Where-Object{(($_.SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join '').Contains($pair.Old)})
  if($matches.Count -ne 1){throw "Expected one matching paragraph. Found $($matches.Count)."}
  $texts=@($matches[0].SelectNodes('.//w:t',$ns));$full=($texts|ForEach-Object InnerText)-join ''
  $texts[0].InnerText=$full.Replace($pair.Old,$pair.New)
  foreach($text in $texts|Select-Object -Skip 1){$text.InnerText=''}
 }
 $entry.Delete();$writer=[IO.StreamWriter]::new($zip.CreateEntry('word/document.xml').Open(),[Text.UTF8Encoding]::new($false))
 try{$doc.Save($writer)}finally{$writer.Dispose()}
}finally{$zip.Dispose()}
$lock=[IO.File]::Open($path,'Open','ReadWrite','None');$lock.Dispose()
Copy-Item -LiteralPath $stage -Destination $path -Force
$z=[IO.Compression.ZipFile]::OpenRead($path)
try{$reader=[IO.StreamReader]::new($z.GetEntry('word/document.xml').Open());try{[xml]$check=$reader.ReadToEnd()}finally{$reader.Dispose()};$ns=[Xml.XmlNamespaceManager]::new($check.NameTable);$ns.AddNamespace('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main');$all=(@($check.SelectNodes('//w:body//w:p',$ns)|ForEach-Object{($_.SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join ''})-join "`n");foreach($phrase in @('allowing authorized administrators and staff to record member check-ins and check-outs.','Authorized administrators and staff can scan the code to record a member')){if(-not $all.Contains($phrase)){throw "Verification failed: $phrase"}}}finally{$z.Dispose()}
'PASS: Chapter 1 now explicitly includes administrators and staff as attendance operators. Layout elements were not edited.'
