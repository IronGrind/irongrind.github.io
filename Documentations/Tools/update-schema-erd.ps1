param([string]$DocumentPath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'Chapter 3.docx'),[switch]$SeparatePanels)
$ErrorActionPreference='Stop'
if(-not $SeparatePanels){
 & (Join-Path $PSScriptRoot 'build-erd-one-page.ps1') -PublicOnly
 & (Join-Path $PSScriptRoot 'update-public-schema-erd.ps1') -DocumentPath $DocumentPath
 return
}
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.Drawing
$work=Join-Path ([IO.Path]::GetTempPath()) ('chapter3-schema-'+[guid]::NewGuid().ToString('N')+'.docx')
Copy-Item -LiteralPath $DocumentPath -Destination $work
try {
 $zip=[IO.Compression.ZipArchive]::new([IO.File]::Open($work,'Open','ReadWrite'),[IO.Compression.ZipArchiveMode]::Update)
 try {
  function LoadXmlPart($name){$r=[IO.StreamReader]::new($zip.GetEntry($name).Open());try{$xml=[Xml.XmlDocument]::new();$xml.PreserveWhitespace=$true;$xml.LoadXml($r.ReadToEnd());return ,$xml}finally{$r.Dispose()}}
  function SaveXmlPart($name,$xml){$entry=$zip.GetEntry($name);$s=$entry.Open();$s.SetLength(0);$w=[IO.StreamWriter]::new($s,[Text.UTF8Encoding]::new($false));try{$xml.Save($w)}finally{$w.Dispose()}}
  $doc=LoadXmlPart 'word/document.xml';$rels=LoadXmlPart 'word/_rels/document.xml.rels'
  $ns=[Xml.XmlNamespaceManager]::new($doc.NameTable)
  $ns.AddNamespace('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main');$ns.AddNamespace('a','http://schemas.openxmlformats.org/drawingml/2006/main');$ns.AddNamespace('r','http://schemas.openxmlformats.org/officeDocument/2006/relationships');$ns.AddNamespace('wp','http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing')
  function ParagraphFor($rid){$node=$doc.SelectSingleNode("//a:blip[@r:embed='$rid']",$ns);if(-not $node){throw "Missing image $rid"};while($node.LocalName -ne 'p'){$node=$node.ParentNode};return ,$node}
  function SetText($p,$text){$runs=$p.SelectNodes('.//w:t',$ns);if(-not $runs.Count){throw 'Paragraph has no text run.'};$runs[0].InnerText=$text;for($i=1;$i -lt $runs.Count;$i++){$runs[$i].InnerText=''}}
  $rid4='rIdSchemaErd4';$rel=$rels.DocumentElement.ChildNodes|Where-Object Id -EQ $rid4
  if($SeparatePanels -and -not $rel){
   $rel=$rels.CreateElement('Relationship',$rels.DocumentElement.NamespaceURI);$rel.SetAttribute('Id',$rid4);$rel.SetAttribute('Type','http://schemas.openxmlformats.org/officeDocument/2006/relationships/image');$rel.SetAttribute('Target','media/schema-erd-4.png');[void]$rels.DocumentElement.AppendChild($rel)
   $last=ParagraphFor 'rId18';$new=$last.CloneNode($true);$new.SelectSingleNode('.//a:blip',$ns).SetAttribute('embed',$ns.LookupNamespace('r'),$rid4)|Out-Null
   $newId=1+[int](($doc.SelectNodes('//wp:docPr',$ns)|ForEach-Object {[int]$_.GetAttribute('id')}|Measure-Object -Maximum).Maximum)
   $pr=$new.SelectSingleNode('.//wp:docPr',$ns);$pr.SetAttribute('id',"$newId");$pr.SetAttribute('name','Physical Schema ERD Panel 4')
   [void]$last.ParentNode.InsertAfter($new,$last)
  }
  if($SeparatePanels){$images=@{rId16='05-erd-1.png';rId17='05-erd-2.png';rId18='05-erd-3.png';rIdSchemaErd4='05-erd-4.png'}}
  else{
   $images=@{rId16='05-erd-combined.png'}
   foreach($rid in @('rId17','rId18','rIdSchemaErd4')){
    $node=$doc.SelectSingleNode("//a:blip[@r:embed='$rid']",$ns)
    if($node){$p=ParagraphFor $rid;[void]$p.ParentNode.RemoveChild($p)}
   }
  }
  foreach($rid in $images.Keys){
   $relationship=$rels.DocumentElement.ChildNodes|Where-Object Id -EQ $rid;$part='word/'+$relationship.GetAttribute('Target')
   $old=$zip.GetEntry($part);if($old){$old.Delete()};$entry=$zip.CreateEntry($part);$stream=$entry.Open()
   $file=Join-Path (Split-Path $PSScriptRoot -Parent) ('Chapter 3 Diagrams/'+$images[$rid]);$bytes=[IO.File]::ReadAllBytes($file);$stream.Write($bytes,0,$bytes.Length);$stream.Dispose()
   $p=ParagraphFor $rid;$im=[Drawing.Image]::FromFile($file);$cx=[long]5486400;$cy=[long]($cx*$im.Height/$im.Width);$im.Dispose()
   foreach($extent in $p.SelectNodes('.//wp:extent | .//a:xfrm/a:ext',$ns)){$extent.SetAttribute('cx',"$cx");$extent.SetAttribute('cy',"$cy")}
   if($rid -ne 'rId16'){
    $pPr=$p.SelectSingleNode('w:pPr',$ns);if(-not $pPr){$pPr=$doc.CreateElement('w','pPr',$ns.LookupNamespace('w'));[void]$p.PrependChild($pPr)}
    if(-not $pPr.SelectSingleNode('w:pageBreakBefore',$ns)){
     $pb=$doc.CreateElement('w','pageBreakBefore',$ns.LookupNamespace('w'));$preceding=$pPr.SelectNodes('w:pStyle | w:keepNext | w:keepLines',$ns)
     if($preceding.Count){[void]$pPr.InsertAfter($pb,$preceding[$preceding.Count-1])}else{[void]$pPr.PrependChild($pb)}
    }
   }
  }
  foreach($p in $doc.SelectNodes('//w:body/w:p',$ns)){
   $text=($p.SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join ''
   if($text -match '^Figure 5a-[cd]\.'){SetText $p 'Figure 5a-d. Physical database schema in schema-visualizer form'}
   elseif($text.StartsWith('The physical ERD in Figure 5')){SetText $p 'The physical ERD in Figure 5a-d presents the database in schema-visualizer form. It contains the fifteen application-owned tables, their 174 columns, and all 21 declared foreign-key connections, using the project pgAdmin schema export checked against the migration baseline and subsequent session-security changes. Figure 5a shows applications and members; Figure 5b shows profiles, membership history, account sessions, and audit storage; Figure 5c shows attendance and mobile scanner pairing; and Figure 5d shows products, sales, and sale items. Each table card identifies its schema and lists its actual column names and data types. PK denotes a primary-key column, FK a foreign-key column, UQ a unique constraint or index, and an asterisk a NOT NULL column. Varchar and timestamptz abbreviate character varying and timestamp with time zone. Repeated reference cards display only the referenced id column of an existing table; they do not add tables to the database. Managed auth.users is shown only as an authentication reference, and its internal columns are outside the application-owned dictionary.'}
   elseif($text.StartsWith('Cardinality describes the number')){SetText $p 'The connecting lines join referenced keys to the corresponding foreign-key columns rather than representing an operational sequence. A foreign key marked with an asterisk requires one referenced parent; a nullable foreign key permits zero or one parent. A parent may have multiple child records unless a primary key or unique constraint restricts the referencing column. For example, members.application_id is nullable and unique, so a member may reference at most one application and an application may be referenced by at most one member through that column. The separate membership_applications.member_id connection permits multiple requests for a member. The unique members.auth_user_id index permits at most one member record per non-null authentication identifier, while profiles.id is both its primary key and an authentication foreign key. The composite primary key of private.account_sessions consists of user_id and session_scope; user_id alone is not a unique key. Required attendance member references and optional sale member or sale-item product references retain their different nullability.'}
   elseif($text.StartsWith('The physical model also includes supporting') -or $text.StartsWith('The physical model includes twelve')){SetText $p 'The physical model includes supporting account, phone-pairing, logging, and attendance-request storage. The fifteen application-owned tables comprise twelve public and three private tables; the private tables are admin_login_attempts, attendance_scan_requests, and account_sessions. Activity logs preserve actor and record details, attendance scan requests support duplicate-request protection, and account sessions store session ownership by user and scope. The retained mobile_attendance_scan_events table is represented because it exists in the physical database; its inclusion does not establish that a corresponding review interface is available. UUID columns do not automatically establish relationships: activity_logs.actor_id and mobile_attendance_scan_sessions.paired_device_id have no declared foreign keys, so no relationship lines are drawn for them. The independently keyed admin_login_attempts table likewise has no declared foreign-key connection. The export confirms the documented deletion actions: CASCADE deletes dependent rows, SET NULL clears nullable references, and RESTRICT or NO ACTION can prevent deletion of a referenced parent. Database keys describe storage integrity, while role checks and authorization policies determine which records each actor may access. The data dictionary following the figures provides field-purpose descriptions and declared lengths or precision.'}
  }
  if(-not $SeparatePanels){
   foreach($p in $doc.SelectNodes('//w:body/w:p',$ns)){
    $text=($p.SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join ''
    if($text -match '^Figure 5(?:a-d)?\.'){SetText $p 'Figure 5. Physical database schema in schema-visualizer form'}
    elseif($text.StartsWith('The physical ERD in Figure 5')){
     $text=$text.Replace('Figure 5a-d presents the database in schema-visualizer form.','Figure 5 presents the database in schema-visualizer form as one combined image with four labeled panels.')
     $text=$text.Replace('Figure 5a shows','The upper-left panel (a) shows').Replace('Figure 5b shows','the upper-right panel (b) shows').Replace('Figure 5c shows','the lower-left panel (c) shows').Replace('Figure 5d shows','the lower-right panel (d) shows')
     SetText $p $text
    }
   }
  }
  SaveXmlPart 'word/document.xml' $doc;SaveXmlPart 'word/_rels/document.xml.rels' $rels
 }finally{$zip.Dispose()}
 Copy-Item -LiteralPath $work -Destination $DocumentPath -Force
 if($SeparatePanels){'Inserted four separate schema-style ERD panels.'}else{'Inserted one combined schema-style ERD image and updated Figure 5 caption and explanation.'}
}finally{if(Test-Path -LiteralPath $work){Remove-Item -LiteralPath $work -Force}}
