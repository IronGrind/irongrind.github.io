$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=Split-Path $PSScriptRoot -Parent
$path=Join-Path $root 'Chapters 1-3 (MAO NA JUD NI).docx'
$backup=Join-Path $root ('Review Backups/chapter1-admin-operations-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $backup|Out-Null
Copy-Item -LiteralPath $path -Destination (Join-Path $backup 'main-before.docx')
$stage=Join-Path $backup 'main-staged.docx';Copy-Item -LiteralPath $path -Destination $stage
$zip=[IO.Compression.ZipFile]::Open($stage,'Update')
try{
 $entry=$zip.GetEntry('word/document.xml');$reader=[IO.StreamReader]::new($entry.Open())
 try{[xml]$doc=$reader.ReadToEnd()}finally{$reader.Dispose()}
 $ns=[Xml.XmlNamespaceManager]::new($doc.NameTable);$ns.AddNamespace('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main')
 $old='Through the IronGrind system, the gym admin can manage member information, review applications and renewal requests, record attendance and in-person transactions, monitor inventory, and review reports.'
 $new='Through IronGrind, the gym administrator can review and approve or reject online membership applications and renewal requests; register walk-in members; process direct renewals and active-member plan changes; record attendance and in-person sales; manage inventory, staff accounts, and phone pairings; and review activity logs and reports. Administrative access to existing member personal profiles is read-only.'
 $matches=@($doc.SelectNodes('//w:body//w:p',$ns)|Where-Object{(($_.SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join '').Contains($old)})
 if($matches.Count -ne 1){throw "Expected one administrator summary paragraph; found $($matches.Count)."}
 $texts=@($matches[0].SelectNodes('.//w:t',$ns));$full=($texts|ForEach-Object InnerText)-join '';$texts[0].InnerText=$full.Replace($old,$new);foreach($text in $texts|Select-Object -Skip 1){$text.InnerText=''}
 $entry.Delete();$writer=[IO.StreamWriter]::new($zip.CreateEntry('word/document.xml').Open(),[Text.UTF8Encoding]::new($false));try{$doc.Save($writer)}finally{$writer.Dispose()}
}finally{$zip.Dispose()}
$lock=[IO.File]::Open($path,'Open','ReadWrite','None');$lock.Dispose();Copy-Item -LiteralPath $stage -Destination $path -Force
'PASS: Chapter 1 administrator summary now explicitly covers approvals, walk-in registration, direct renewal, plan changes, attendance, sales, inventory, staff/pairing administration, activity logs, and reports. Layout retained.'
