$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Drawing
$root=Split-Path $PSScriptRoot -Parent
$backup=Join-Path $root ('Review Backups/member-schema-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
[void][IO.Directory]::CreateDirectory($backup)
foreach($i in 1..3){Copy-Item -LiteralPath (Join-Path $root "Chapter $i.docx") -Destination $backup}
$model=Get-Content -Raw -Encoding UTF8 (Join-Path $root 'Chapter 3 Diagrams/_Sources/member-paper-model.json')|ConvertFrom-Json
$drawing=Get-Content -Raw -Encoding UTF8 (Join-Path $root 'Chapter 3 Diagrams/_Sources/member-erd-render.json')|ConvertFrom-Json
$bmp=[Drawing.Bitmap]::new(1800,[int]$drawing.H);$g=[Drawing.Graphics]::FromImage($bmp);$font=[Drawing.Font]::new('Arial',22,[Drawing.FontStyle]::Regular,[Drawing.GraphicsUnit]::Pixel)
$png=Join-Path $root 'Chapter 3 Diagrams/05b-member-security-schema.png'
try{
 $g.Clear([Drawing.Color]::White);$g.SmoothingMode='AntiAlias';$g.TextRenderingHint='AntiAliasGridFit'
 foreach($line in $drawing.lines){$points=[Drawing.PointF[]]@($line|ForEach-Object {[Drawing.PointF]::new([single]$_[0],[single]$_[1])});$g.DrawLines([Drawing.Pens]::Black,$points)}
 foreach($p in $drawing.items){$g.FillRectangle([Drawing.Brushes]::White,[single]$p.x,[single]$p.y,[single]$p.w,[single]$p.h);$g.DrawRectangle([Drawing.Pens]::Black,[single]$p.x,[single]$p.y,[single]$p.w,[single]$p.h);$i=0;foreach($line in ($p.text -split "`n")){$g.DrawString($line,$font,[Drawing.Brushes]::Black,[single]($p.x+12),[single]($p.y+8+32*$i));$i++}}
 $bmp.Save($png,[Drawing.Imaging.ImageFormat]::Png)
}finally{$g.Dispose();$font.Dispose();$bmp.Dispose()}
foreach($chapter in 1..3){
 $path=Join-Path $root "Chapter $chapter.docx"
 $z=[IO.Compression.ZipFile]::Open($path,[IO.Compression.ZipArchiveMode]::Update)
 try{
  function ReadXml($name){$r=[IO.StreamReader]::new($z.GetEntry($name).Open());try{$xml=[Xml.XmlDocument]::new();$xml.PreserveWhitespace=$true;$xml.LoadXml($r.ReadToEnd());return ,$xml}finally{$r.Dispose()}}
  function SaveXml($name,$xml){$s=$z.GetEntry($name).Open();$s.SetLength(0);$wr=[IO.StreamWriter]::new($s,[Text.UTF8Encoding]::new($false));try{$xml.Save($wr)}finally{$wr.Dispose()}}
  $d=ReadXml 'word/document.xml';$n=[Xml.XmlNamespaceManager]::new($d.NameTable);$w='http://schemas.openxmlformats.org/wordprocessingml/2006/main';$n.AddNamespace('w',$w);$n.AddNamespace('wp','http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing');$n.AddNamespace('a','http://schemas.openxmlformats.org/drawingml/2006/main');$n.AddNamespace('r','http://schemas.openxmlformats.org/officeDocument/2006/relationships')
  function Txt($p){return ($p.SelectNodes('.//w:t',$n)|ForEach-Object InnerText)-join ''}
  function Put($p,$text){$ts=$p.SelectNodes('.//w:t',$n);if(-not $ts.Count){$para=$p.SelectSingleNode('w:p',$n);if(-not $para){$para=$p};$run=$d.CreateElement('w','r',$w);$value=$d.CreateElement('w','t',$w);$value.InnerText=[string]$text;[void]$run.AppendChild($value);[void]$para.AppendChild($run);return};$ts[0].InnerText=[string]$text;foreach($t in @($ts|Select-Object -Skip 1)){$t.InnerText=''}}
  function Para($template,$text){$p=$template.CloneNode($true);Put $p $text;return ,$p}
  $body=$d.SelectSingleNode('//w:body',$n)
  if($chapter -eq 1){
   $anchor=@($body.SelectNodes('w:p',$n)|Where-Object {(Txt $_).StartsWith('The activity-log implementation covered')})[0]
   $p=Para $anchor 'Member account access also included browser registration and approval. The system stored one registered browser per member account and required a new browser to obtain approval from the currently signed-in registered browser when that browser was available. Browser public keys, session challenges, and approval requests were maintained in separate private tables. These records were distinct from member profiles and phone-camera pairings. The migration and required functions were recorded as deployed; controlled member browser-acceptance testing remained pending.'
   if(-not (Txt $body).Contains('Member account access also included browser registration and approval.')){[void]$body.InsertAfter($p,$anchor)}
  }elseif($chapter -eq 2){
   $anchor=@($body.SelectNodes('w:p',$n)|Where-Object {(Txt $_).StartsWith('The additional technical literature supports')})[0]
   $p=Para $anchor 'These concepts also informed the separation of operational records from supporting security records. In IronGrind, member browser registration, session challenges, and approval requests were maintained in private tables, while membership, attendance, inventory, and sales records remained in the public application schema. The member browser-approval workflow extended account authorization without introducing another main system function. This design application did not establish measured improvements in security or usability; controlled browser-acceptance testing remained necessary.'
   if(-not (Txt $body).Contains('These concepts also informed the separation of operational records')){[void]$body.InsertAfter($p,$anchor)}
  }else{
   foreach($p in $body.SelectNodes('w:p',$n)){
    $t=Txt $p
    if($t.StartsWith('The eighteen application-owned tables comprise')){Put $p 'The twenty-one application-owned tables comprise twelve public and nine private tables, with 224 fields and thirty-three declared foreign keys in the documented target schema. The twelve public tables contain 162 fields and eighteen foreign keys; the nine private tables contain sixty-two fields and fifteen foreign keys. The private tables are attendance_scan_requests, admin_login_attempts, account_sessions, admin_login_approvals, admin_trusted_devices, admin_device_sessions, member_trusted_devices, member_device_sessions and member_device_approvals. Managed auth.users and auth.sessions are referenced structures, not additional application-owned tables. Counts reconcile the supplied public-schema export with migrations through 20261110000006; this is not a fresh live-schema introspection. UUID fields do not automatically imply relationships: activity_logs.actor_id, paired_device_id and the trusted-device snapshot/candidate identifiers have no declared foreign keys.'}
    elseif($t.StartsWith('The documented target schema comprises')){Put $p 'The documented target schema comprises twelve public and nine private application-owned tables, 224 fields, and thirty-three declared foreign keys. Figures 5a-c show the existing fifteen-table physical relationship model and its twenty-one foreign keys; Figure 5d adds the three administrator-security tables and six foreign keys to managed Auth tables. Figure 5e adds the three member-security tables and their six foreign keys. The dictionary below describes all twenty-one application-owned tables and their declared types, constraints, nullability, referential actions, and operational purpose. Relationships do not grant permissions; server authorization controls access. The retained receipt_number field is an internal transaction reference and does not establish customer receipt issuance.'}
    elseif($t.StartsWith('Figures 5a-c show the fifteen existing')){Put $p ($t.Replace('completing the eighteen-table, twenty-seven-foreign-key schema documented in the dictionary.','while Figure 5e adds the member-security tables and six further foreign keys, completing the twenty-one-table, thirty-three-foreign-key schema documented in the dictionary.'))}
   }
   $tables=@($body.SelectNodes('w:tbl',$n));if($tables.Count -ne 23){throw 'Expected unchanged original 23 tables'}
   $template=$tables[-1];$anchor=$template
   $titleTemplate=@($body.SelectNodes('w:p',$n)|Where-Object {(Txt $_).Trim().StartsWith('Table 23:')})[0];$purposeTemplate=$titleTemplate.NextSibling
   for($ti=0;$ti -lt $model.tables.Count;$ti++){
    $table=$model.tables[$ti];$title=Para $titleTemplate ('Table '+(24+$ti)+': '+$table.Name);[void]$body.InsertAfter($title,$anchor);$purpose=Para $purposeTemplate $table.Purpose;[void]$body.InsertAfter($purpose,$title)
    $new=$template.CloneNode($true);$rows=@($new.SelectNodes('w:tr',$n));$rowTemplate=$rows[1];foreach($r in @($rows|Select-Object -Skip 1)){[void]$new.RemoveChild($r)}
    foreach($c in $table.Columns){$row=$rowTemplate.CloneNode($true);$cells=$row.SelectNodes('w:tc',$n);$details=$c.Description+' Constraints: '+$(if($c.Required){'NOT NULL. '}else{'Nullable at column level. '});foreach($fk in @($model.relations|Where-Object {$_.Child -eq $table.Name -and $_.Field -eq $c.Name})){$details+='References '+$fk.Parent+'('+$fk.ParentField+'); ON DELETE '+$fk.Delete+'; ON UPDATE NO ACTION. '};$details+=$c.Extra
     $texts=@($c.Name,$c.Type,$(if($c.Type -in @('text','jsonb')){'Not declared'}else{'N/A'}),($c.Keys -join ', '),$details.Trim());for($j=0;$j -lt 5;$j++){Put $cells[$j] $texts[$j]};[void]$new.AppendChild($row)
    };[void]$body.InsertAfter($new,$purpose);$anchor=$new
   }
   $caption=@($body.SelectNodes('w:p',$n)|Where-Object {(Txt $_).Trim() -eq 'Figure 5d. Administrator Security Schema Supplement'})[0];$image=$caption.NextSibling
   while($image -and -not $image.SelectSingleNode('.//a:blip',$n)){$image=$image.NextSibling};if(-not $image){throw 'Missing security image template'}
   $note=@($body.SelectNodes('w:p',$n)|Where-Object {(Txt $_).StartsWith('Figure 5d shows the three')})[0];$picture=$image.CloneNode($true);$newCaption=Para $caption 'Figure 5e. Member Security Schema Supplement';$newNote=Para $note 'Figure 5e shows the three member-security tables and their six foreign keys to managed Supabase Auth tables. Repeated Auth cards represent the same managed tables. The primary key on member_trusted_devices.user_id permits at most one registered browser per member; member_device_sessions.session_id permits at most one challenge record per Auth session. The requesting_session_id column in member_device_approvals is individually unique. The optional approver_session_id uses ON DELETE SET NULL; the other five references use CASCADE. Device_id and public_key are compared by the security functions and have no declared foreign keys. These tables support member login and browser replacement, separate from administrator trust and attendance phone pairing. The migration and required functions are recorded as deployed in the implementation guide; controlled member browser-acceptance testing remains pending.'
   $rels=ReadXml 'word/_rels/document.xml.rels';$rid='rIdMemberSchema';$rel=$rels.CreateElement('Relationship',$rels.DocumentElement.NamespaceURI);$rel.SetAttribute('Id',$rid);$rel.SetAttribute('Type','http://schemas.openxmlformats.org/officeDocument/2006/relationships/image');$rel.SetAttribute('Target','media/member-security-schema.png');[void]$rels.DocumentElement.AppendChild($rel)
   $picture.SelectSingleNode('.//a:blip',$n).SetAttribute('embed',$n.LookupNamespace('r'),$rid)|Out-Null
   $info=$picture.SelectSingleNode('.//wp:docPr',$n);$max=($d.SelectNodes('//wp:docPr',$n)|ForEach-Object {[int]$_.GetAttribute('id')}|Measure-Object -Maximum).Maximum;$info.SetAttribute('id',[string]($max+1));$info.SetAttribute('name','Figure 5e. Member Security Schema Supplement')
   foreach($ext in $picture.SelectNodes('.//wp:extent | .//a:xfrm/a:ext',$n)){$cx=[long]$ext.GetAttribute('cx');$ext.SetAttribute('cy',[string][long]($cx*$drawing.H/1800))}
   [void]$body.InsertAfter($newCaption,$note);[void]$body.InsertAfter($picture,$newCaption);[void]$body.InsertAfter($newNote,$picture)
   $entry=$z.CreateEntry('word/media/member-security-schema.png');$s=$entry.Open();$bytes=[IO.File]::ReadAllBytes($png);$s.Write($bytes,0,$bytes.Length);$s.Dispose();SaveXml 'word/_rels/document.xml.rels' $rels
  }
  SaveXml 'word/document.xml' $d
 }finally{$z.Dispose()}
}
Write-Output "Updated Chapters 1-3; original formatting cloned. Backups: $backup"

