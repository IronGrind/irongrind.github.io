param([string]$DocumentPath=(Join-Path $PSScriptRoot 'Chapter 3.docx'))
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.Drawing
$work=Join-Path ([IO.Path]::GetTempPath()) ('chapter3-public-erd-'+[guid]::NewGuid().ToString('N')+'.docx')
Copy-Item -LiteralPath $DocumentPath -Destination $work
try{
 $z=[IO.Compression.ZipArchive]::new([IO.File]::Open($work,'Open','ReadWrite'),[IO.Compression.ZipArchiveMode]::Update)
 try{
  function ReadXml($name){$r=[IO.StreamReader]::new($z.GetEntry($name).Open());try{$xml=[Xml.XmlDocument]::new();$xml.PreserveWhitespace=$true;$xml.LoadXml($r.ReadToEnd());return ,$xml}finally{$r.Dispose()}}
  $d=ReadXml 'word/document.xml';$rels=ReadXml 'word/_rels/document.xml.rels';$w='http://schemas.openxmlformats.org/wordprocessingml/2006/main';$n=[Xml.XmlNamespaceManager]::new($d.NameTable)
  $n.AddNamespace('w',$w);$n.AddNamespace('a','http://schemas.openxmlformats.org/drawingml/2006/main');$n.AddNamespace('r','http://schemas.openxmlformats.org/officeDocument/2006/relationships');$n.AddNamespace('wp','http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing')
  function Txt($p){return ($p.SelectNodes('.//w:t',$n)|ForEach-Object InnerText)-join ''}
  function Put($p,$text){$ts=$p.SelectNodes('.//w:t',$n);if(-not $ts.Count){throw 'Missing paragraph text.'};$ts[0].InnerText=$text;for($i=1;$i -lt $ts.Count;$i++){$ts[$i].InnerText=''}}
  function Attr($node,$name,$value){[void]$node.SetAttribute($name,$w,$value)}
  function NextPageSection($landscape=$false){
   $section=$d.SelectSingleNode('//w:body/w:sectPr',$n).CloneNode($true);$type=$section.SelectSingleNode('w:type',$n)
   if(-not $type){$type=$d.CreateElement('w','type',$w);[void]$section.InsertBefore($type,$section.SelectSingleNode('w:pgSz',$n))};Attr $type 'val' 'nextPage'
   if($landscape){$size=$section.SelectSingleNode('w:pgSz',$n);Attr $size 'w' '15840';Attr $size 'h' '12240';Attr $size 'orient' 'landscape';$margins=$section.SelectSingleNode('w:pgMar',$n);foreach($name in @('top','bottom','left','right')){Attr $margins $name '720'}}
   return ,$section
  }
  $tablesBefore=(@($d.SelectNodes('//w:tbl',$n)|ForEach-Object OuterXml))-join "`n"
  $body=$d.SelectSingleNode('//w:body',$n);$paras=@($body.SelectNodes('w:p',$n));$heading=@($paras|Where-Object {(Txt $_).Trim() -eq 'Entity Relationship Diagram'});$caption=@($paras|Where-Object {(Txt $_).Trim() -match '^Figure 5(?:a-[cd])?\.'})
  if($heading.Count -ne 1 -or $caption.Count -ne 1){throw 'Cannot identify the ERD figure section.'}
  $pictures=[Collections.Generic.List[object]]::new();$node=$heading[0].NextSibling
  while($node -and -not [object]::ReferenceEquals($node,$caption[0])){if($node.SelectSingleNode('.//a:blip',$n)){$pictures.Add($node)};$node=$node.NextSibling}
  if(-not $node -or -not $pictures.Count){throw 'Missing figure or caption ordering.'}
  $picture=$pictures[0];foreach($old in @($pictures|Select-Object -Skip 1)){[void]$body.RemoveChild($old)}
  $rid=$picture.SelectSingleNode('.//a:blip',$n).GetAttribute('embed',$n.LookupNamespace('r'));$rel=$rels.DocumentElement.ChildNodes|Where-Object Id -EQ $rid
  $part='word/'+$rel.GetAttribute('Target');$z.GetEntry($part).Delete();$imageEntry=$z.CreateEntry($part);$s=$imageEntry.Open();$png=Join-Path $PSScriptRoot 'Chapter 3 Diagrams/05-public-schema-erd.png';$bytes=[IO.File]::ReadAllBytes($png);$s.Write($bytes,0,$bytes.Length);$s.Dispose()
  # A landscape section applies only to the figure; the following section uses
  # the document's original portrait settings and margin values.
  $boundary=$heading[0].PreviousSibling
  if(-not $boundary -or -not $boundary.SelectSingleNode('w:bookmarkStart[@w:name="_PublicERDSection"]',$n)){
   $boundary=$d.CreateElement('w','p',$w);$pr=$d.CreateElement('w','pPr',$w);$spacing=$d.CreateElement('w','spacing',$w);Attr $spacing 'before' '0';Attr $spacing 'after' '0';Attr $spacing 'line' '1';Attr $spacing 'lineRule' 'exact';[void]$pr.AppendChild($spacing);[void]$pr.AppendChild((NextPageSection));[void]$boundary.AppendChild($pr)
   $ids=@($d.SelectNodes('//w:bookmarkStart',$n)|ForEach-Object {[int]$_.GetAttribute('id',$w)});$id=if($ids.Count){1+($ids|Measure-Object -Maximum).Maximum}else{1}
   $start=$d.CreateElement('w','bookmarkStart',$w);Attr $start 'id' "$id";Attr $start 'name' '_PublicERDSection';[void]$boundary.AppendChild($start);$end=$d.CreateElement('w','bookmarkEnd',$w);Attr $end 'id' "$id";[void]$boundary.AppendChild($end);[void]$body.InsertBefore($boundary,$heading[0])
  }
  foreach($item in @(@{P=$heading[0];Kind='heading'},@{P=$picture;Kind='picture'},@{P=$caption[0];Kind='caption'})){
   $p=$item.P;$old=$p.SelectSingleNode('w:pPr',$n);$pr=$d.CreateElement('w','pPr',$w)
   if($item.Kind -eq 'heading'){$style=$d.CreateElement('w','pStyle',$w);Attr $style 'val' 'Heading3';[void]$pr.AppendChild($style)}
   if($item.Kind -ne 'caption'){[void]$pr.AppendChild($d.CreateElement('w','keepNext',$w))};[void]$pr.AppendChild($d.CreateElement('w','keepLines',$w))
   $spacing=$d.CreateElement('w','spacing',$w);Attr $spacing 'before' '0';Attr $spacing 'after' $(if($item.Kind -eq 'caption'){'0'}else{'80'});Attr $spacing 'line' '240';Attr $spacing 'lineRule' 'auto';[void]$pr.AppendChild($spacing)
   $indent=$d.CreateElement('w','ind',$w);foreach($name in @('left','right','firstLine')){Attr $indent $name '0'};[void]$pr.AppendChild($indent)
   $align=$d.CreateElement('w','jc',$w);Attr $align 'val' $(if($item.Kind -eq 'heading'){'left'}else{'center'});[void]$pr.AppendChild($align)
   if($old -and $old.SelectSingleNode('w:rPr',$n)){[void]$pr.AppendChild($old.SelectSingleNode('w:rPr',$n).CloneNode($true))}
   if($item.Kind -eq 'caption'){[void]$pr.AppendChild((NextPageSection $true))}
   if($old){[void]$p.ReplaceChild($pr,$old)}else{[void]$p.PrependChild($pr)}
   foreach($cached in @($p.SelectNodes('.//w:lastRenderedPageBreak',$n))){[void]$cached.ParentNode.RemoveChild($cached)}
  }
  $after=$caption[0].NextSibling;$pb=$after.SelectSingleNode('w:pPr/w:pageBreakBefore',$n);if($pb){[void]$pb.ParentNode.RemoveChild($pb)}
  $cx=[long](9.5*914400);$cy=[long]($cx*2480/3508);foreach($ext in $picture.SelectNodes('.//wp:extent | .//a:xfrm/a:ext',$n)){$ext.SetAttribute('cx',"$cx");$ext.SetAttribute('cy',"$cy")}
  $info=$picture.SelectSingleNode('.//wp:docPr',$n);$info.SetAttribute('name','Public-Schema ERD');$info.SetAttribute('descr','All twelve public tables, an auth.users reference, and all eighteen public foreign keys. Selected attributes; complete field details remain in the data dictionary.')
  $order=@{profiles=1;membership_applications=2;members=3;attendance=4;products=5;sales=6;sale_items=7;membership_history=8}
  foreach($p in @($body.SelectNodes('w:p',$n))){
   $t=(Txt $p).Trim()
   if($t -match '^Figure 5(?:a-[cd])?\.'){Put $p 'Figure 5. Public-Schema Entity Relationship Diagram'}
   elseif($t.StartsWith('Figure 5 presents the core business') -or $t.StartsWith('The public-schema ERD in Figure 5')){Put $p 'The public-schema ERD in Figure 5 includes all twelve public application tables: profiles, membership_applications, members, attendance, membership_history, products, sales, sale_items, activity_logs, mobile_attendance_pairing_policy, mobile_attendance_scan_sessions, and mobile_attendance_scan_events. It also displays auth.users as a managed identity reference, not as a thirteenth public table. All eighteen foreign keys declared on public tables are represented. The diagram includes every primary-key and foreign-key column and selected descriptive attributes to keep the overview readable. Complete definitions of the 162 public fields, including the fields omitted from the overview, remain in the data dictionary. This figure replaces the earlier seven-table core-business view.'}
   elseif($t.StartsWith('The connecting lines in Figure 5') -or $t.StartsWith('The connecting lines join referenced') -or $t.StartsWith('In Figure 5, the connecting lines')){Put $p 'In Figure 5, the connecting lines join referenced primary keys to their foreign-key columns. They describe stored relationships rather than a sequence of program operations. PK identifies a primary key, FK a foreign key, and UQ a unique constraint or index. An asterisk marks a NOT NULL column. A required foreign key requires one referenced parent for each child record; a nullable foreign key permits zero or one parent. A parent can have zero or many referencing child records unless a unique or primary-key constraint restricts the child foreign key to at most one record. Gaps distinguish crossing lines and do not represent database junctions. Varchar and timestamptz abbreviate character varying and timestamp with time zone; the dictionary retains declared lengths and precision.'}
   elseif($t.StartsWith('The full physical model includes supporting') -or $t.StartsWith('The complete application schema includes')){Put $p 'The complete application schema includes the twelve public tables in Figure 5 and three private supporting tables. The fifteen application-owned tables comprise twelve public and three private tables; the private tables are account_sessions, admin_login_attempts, and attendance_scan_requests. These three tables are outside the public-schema figure and remain documented in the complete fifteen-table, 174-field data dictionary. Their three foreign keys, together with the eighteen public foreign keys, give twenty-one application foreign keys in the full schema. Supabase manages auth.users separately, so its internal columns are outside the application-owned dictionary. UUID fields do not automatically establish relationships: activity_logs.actor_id and mobile_attendance_scan_sessions.paired_device_id have no declared foreign keys. The activity_logs card therefore has no enforced relationship line.'}
   elseif($t.StartsWith('Supporting account entity: profiles.')){Put $p ($t.Replace('Supporting account entity: profiles.','1. profiles Entity.'))}
   elseif($t -match '^\d+\. (membership_applications|members|attendance|products|sales|sale_items|membership_history) Entity'){$entity=$Matches[1];Put $p ([regex]::Replace($t,'^\d+\.',$order[$entity].ToString()+'.'))}
   elseif($t.StartsWith('Members to Membership Applications.')){Put $p 'Members to Membership Applications. The figure shows two different foreign keys between these tables. Members.application_id references membership_applications.id and is nullable and unique: a member may refer to zero or one source application, and an application can be referenced by zero or one member through that column. Separately, membership_applications.member_id references members.id and is nullable without a unique constraint, allowing a member to have zero or many requests and a request to have zero or one linked member. Online renewals use the request member reference to identify the existing member. A new registration may exist without a member_id, while the resulting member can retain the source application through application_id.'}
   elseif($t.StartsWith('Supporting Relationships.') -or $t.StartsWith('Additional Public Relationships.')){Put $p 'Additional Public Relationships. Profiles.id shares its primary key with auth.users.id, and membership_applications.reviewed_by references profiles.id. Public attendance, membership-history, sales, phone-session, and pairing-policy operator fields reference auth.users as specified in the dictionary. Mobile_attendance_scan_events.session_id requires one scanner session, while a session may have zero or many retained scan-event rows. Mobile_attendance_pairing_policy.updated_by is optional. The figure includes these public identity and scanner links; private attendance-request and scoped-session relationships remain documented separately.'}
   elseif($t.StartsWith('Figure 5 concentrates on the seven core business') -or $t.StartsWith('Figure 5 covers all twelve public')){Put $p 'Figure 5 covers all twelve public tables and their eighteen foreign-key relationships, with auth.users included only as a referenced identity table. All fifteen application tables and twenty-one foreign keys remain documented in the dictionary. Its Key(s) and Description / Constraints columns provide detailed primary, foreign, unique and composite-key information, referenced columns, nullability, deletion/update actions, and relevant checks. For example, attendance.member_id uses ON DELETE CASCADE while membership_history.member_id uses ON DELETE RESTRICT. The retained receipt_number column is an internal transaction reference; it does not establish customer receipt issuance. A relationship line does not grant permission to view or modify records, because role checks, policies, and authorized functions control access.'}
  }
  $history=@($body.SelectNodes('w:p',$n)|Where-Object {(Txt $_).Trim().StartsWith('8. membership_history Entity.')});if($history.Count -ne 1){throw 'Cannot locate membership-history entity description.'}
  $descriptions=@(
   '9. activity_logs Entity. The log preserves event time, actor labels, action, entity details, changed field names, and descriptive information for administrator review. Its id is an identity primary key. Actor_id is nullable UUID data without a declared foreign key, so the figure correctly leaves this table without an enforced identity relationship. Logging data describes recorded operations and does not itself authorize them.',
   '10. mobile_attendance_scan_sessions Entity. A scanner session stores its token hash, creating Auth account, creation and expiry times, pairing details, and remembered-phone state. Created_by is a required foreign key to auth.users. Paired_device_id is retained UUID data without a declared foreign key. The session and token support the paired attendance workflow; a pairing does not replace the required operator authentication.',
   '11. mobile_attendance_scan_events Entity. Each retained scan event requires one scanner session through session_id and records a QR payload and creation time. Its presence in the physical schema does not establish that a dedicated scan-event review interface is part of the current frontend. The dictionary records the payload length check and the session deletion rule.',
   '12. mobile_attendance_pairing_policy Entity. The singleton primary key and its true-value check identify one policy row. The table stores the pairing limit, update time, optional updating Auth account, and credential hashes used for pairing administration. Its max_pairs check allows values from 2 through 50. The configured capacity counts paired phones and unexpired pending QR reservations according to the implemented pairing workflow.'
  )
  $anchor=$history[0]
  foreach($text in $descriptions){$prefix=$text.Substring(0,$text.IndexOf(' Entity.'));$existing=@($body.SelectNodes('w:p',$n)|Where-Object {(Txt $_).Trim().StartsWith($prefix+' Entity.')})
   if($existing.Count -gt 1){throw 'Duplicate public entity description.'}
   if($existing.Count){Put $existing[0] $text;$anchor=$existing[0]}else{$p=$d.CreateElement('w','p',$w);$pPr=$history[0].SelectSingleNode('w:pPr',$n);if($pPr){[void]$p.AppendChild($pPr.CloneNode($true))};$run=$d.CreateElement('w','r',$w);$rPr=$history[0].SelectSingleNode('w:r/w:rPr',$n);if($rPr){[void]$run.AppendChild($rPr.CloneNode($true))};$t=$d.CreateElement('w','t',$w);$t.InnerText=$text;[void]$run.AppendChild($t);[void]$p.AppendChild($run);[void]$body.InsertAfter($p,$anchor);$anchor=$p}
   foreach($run in $anchor.SelectNodes('w:r',$n)){
    $old=$run.SelectSingleNode('w:rPr',$n);$rp=$d.CreateElement('w','rPr',$w);$fonts=$d.CreateElement('w','rFonts',$w)
    foreach($name in @('ascii','hAnsi','cs','eastAsia')){Attr $fonts $name 'Times New Roman'};[void]$rp.AppendChild($fonts)
    $size=$d.CreateElement('w','sz',$w);Attr $size 'val' '24';[void]$rp.AppendChild($size)
    if($old){[void]$run.ReplaceChild($rp,$old)}else{[void]$run.PrependChild($rp)}
   }
  }
  if($tablesBefore -cne ((@($d.SelectNodes('//w:tbl',$n)|ForEach-Object OuterXml))-join "`n")){throw 'Data dictionary or requirements tables changed unexpectedly.'}
  $all=(@($body.SelectNodes('w:p',$n)|ForEach-Object {Txt $_}))-join ' '
  if($all -match 'Core Business Entity Relationship Diagram|seven core business entities and seven|Link A represents|links marked A and B'){throw 'Obsolete seven-table figure explanation remains.'}
  $s=$z.GetEntry('word/document.xml').Open();$s.SetLength(0);$writer=[IO.StreamWriter]::new($s,[Text.UTF8Encoding]::new($false));try{$d.Save($writer)}finally{$writer.Dispose()}
 }finally{$z.Dispose()}
 Copy-Item -LiteralPath $work -Destination $DocumentPath -Force
 'Inserted the twelve-public-table ERD on one landscape figure page; updated its scope and entity descriptions; all data dictionary tables preserved.'
}finally{if(Test-Path -LiteralPath $work){Remove-Item -LiteralPath $work -Force}}
