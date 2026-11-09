param([string]$DocumentPath=(Join-Path $PSScriptRoot 'Chapter 3.docx'))
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.Drawing
$out=Join-Path $PSScriptRoot 'Chapter 3 Diagrams'
$model=Get-Content -Raw -LiteralPath (Join-Path $out 'schema-visualizer.json')|ConvertFrom-Json
$baseline=Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot '../supabase/migrations/20261105043517_remote_schema.sql')
$scopeSql=Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot '../supabase/migrations/20261108000006_separate_attendance_sessions.sql')
$checks=@{}
function Check($table,$field,$constraint,$text){
 if(-not ($baseline.Contains('"'+$constraint+'"') -or $scopeSql.Contains($constraint))){throw "Unverified check constraint: $constraint"}
 $key=$table+'.'+$field;if(-not $checks.ContainsKey($key)){$checks[$key]=[Collections.Generic.List[string]]::new()};$checks[$key].Add($text)
}
Check 'public.profiles' 'role' 'profiles_role_check' 'CHECK: admin, staff, or member.'
Check 'public.profiles' 'account_status' 'profiles_account_status_check' 'CHECK: pending, active, or disabled.'
Check 'public.members' 'height_unit' 'members_height_unit_check' 'CHECK: cm, in, or ft when not NULL.'
Check 'public.members' 'paid' 'members_paid_check' 'CHECK: at least 0.'
Check 'public.members' 'status' 'members_status_check' 'CHECK: active, expired, suspended, or inactive.'
Check 'public.membership_applications' 'age' 'membership_applications_age_check' 'CHECK: 1-120 when not NULL.'
Check 'public.membership_applications' 'application_type' 'membership_applications_application_type_check' 'CHECK: registration or renewal.'
Check 'public.membership_applications' 'height_unit' 'membership_applications_height_unit_check' 'CHECK: cm, in, or ft when not NULL.'
Check 'public.membership_applications' 'plan_price' 'membership_applications_plan_price_check' 'CHECK: at least 0.'
Check 'public.membership_applications' 'status' 'membership_applications_status_check' 'CHECK: pending, approved, or rejected.'
Check 'public.membership_history' 'event_type' 'membership_history_event_type_check' 'CHECK: expired, renewal, or plan_change.'
Check 'public.membership_history' 'previous_price' 'membership_history_previous_price_check' 'CHECK: at least 0 when not NULL.'
Check 'public.membership_history' 'new_price' 'membership_history_new_price_check' 'CHECK: at least 0 when not NULL.'
Check 'public.mobile_attendance_pairing_policy' 'singleton' 'mobile_attendance_pairing_policy_singleton_check' 'CHECK: true; the primary key permits only one policy row.'
Check 'public.mobile_attendance_pairing_policy' 'max_pairs' 'mobile_attendance_pairing_policy_max_pairs_check' 'CHECK: 2-50.'
Check 'public.mobile_attendance_scan_events' 'qr_payload' 'mobile_attendance_scan_events_qr_payload_check' 'CHECK: length 1-500 characters.'
Check 'public.products' 'category' 'products_category_check' 'CHECK: supplement or merchandise.'
Check 'public.products' 'price' 'products_price_check' 'CHECK: at least 0.'
Check 'public.products' 'stock' 'products_stock_check' 'CHECK: at least 0.'
Check 'public.products' 'unit' 'products_category_unit_check' 'CHECK: gram for powder, milliliter for drinkable, piece/box matching stock_unit for capsule/tablet, and item for other supplements or merchandise.'
Check 'public.products' 'stock_unit' 'products_stock_unit_check' 'CHECK: gram/kilogram/ounce/pound for powder; milliliter/liter/fluid_ounce for drinkable; piece/box for capsule/tablet; item for other supplements or merchandise.'
Check 'public.products' 'merch_type' 'products_merch_type_check' 'CHECK: when supplied for merchandise, apparel, accessories, drinkware, gym_gear, or other; must be NULL for supplements.'
Check 'public.products' 'supplement_form' 'products_supplement_form_check' 'CHECK: required for supplements with powder, drinkable, capsule, tablet, or other; must be NULL for merchandise.'
Check 'public.products' 'supplement_type' 'products_supplement_type_check' 'CHECK: when supplied for supplements, protein, creatine, pre_workout, vitamins, amino_acids, or other; must be NULL for merchandise.'
Check 'public.sale_items' 'category' 'sale_items_category_check' 'CHECK: supplement, merchandise, or membership.'
Check 'public.sale_items' 'quantity' 'sale_items_quantity_check' 'CHECK: greater than 0.'
Check 'public.sale_items' 'unit_price' 'sale_items_unit_price_check' 'CHECK: at least 0.'
Check 'public.sale_items' 'line_total' 'sale_items_line_total_check' 'CHECK: at least 0.'
Check 'public.sale_items' 'unit' 'sale_items_unit_check' 'CHECK: gram, kilogram, ounce, pound, milliliter, liter, fluid_ounce, item, piece, box, or membership.'
Check 'public.sales' 'total' 'sales_total_check' 'CHECK: at least 0.'
Check 'public.sales' 'status' 'sales_status_check' 'CHECK: nonempty normalized lowercase text (trimmed); no fixed status enumeration is declared.'
Check 'private.account_sessions' 'session_scope' 'account_sessions_scope_check' 'CHECK: dashboard or attendance.'
$work=Join-Path ([IO.Path]::GetTempPath()) ('chapter3-core-erd-'+[guid]::NewGuid().ToString('N')+'.docx')
Copy-Item -LiteralPath $DocumentPath -Destination $work
try{
 $zip=[IO.Compression.ZipArchive]::new([IO.File]::Open($work,'Open','ReadWrite'),[IO.Compression.ZipArchiveMode]::Update)
 try{
  function ReadXml($name){$r=[IO.StreamReader]::new($zip.GetEntry($name).Open());try{$xml=[Xml.XmlDocument]::new();$xml.PreserveWhitespace=$true;$xml.LoadXml($r.ReadToEnd());return ,$xml}finally{$r.Dispose()}}
  function SaveXml($name,$xml){$s=$zip.GetEntry($name).Open();$s.SetLength(0);$writer=[IO.StreamWriter]::new($s,[Text.UTF8Encoding]::new($false));try{$xml.Save($writer)}finally{$writer.Dispose()}}
  $d=ReadXml 'word/document.xml';$rels=ReadXml 'word/_rels/document.xml.rels';$ns=[Xml.XmlNamespaceManager]::new($d.NameTable)
  $ns.AddNamespace('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main');$ns.AddNamespace('a','http://schemas.openxmlformats.org/drawingml/2006/main');$ns.AddNamespace('r','http://schemas.openxmlformats.org/officeDocument/2006/relationships');$ns.AddNamespace('wp','http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing')
  function Txt($node){return ($node.SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join ''}
  function Put($node,$text){
   $ts=$node.SelectNodes('.//w:t',$ns)
   if(-not $ts.Count){
    if(-not $text){return};$p=if($node.LocalName -eq 'p'){$node}else{$node.SelectSingleNode('.//w:p',$ns)}
    if(-not $p){throw 'Text container missing.'}
    $run=$d.CreateElement('w','r',$ns.LookupNamespace('w'));$t=$d.CreateElement('w','t',$ns.LookupNamespace('w'));$t.InnerText=$text;[void]$run.AppendChild($t);[void]$p.AppendChild($run);return
   }
   $ts[0].InnerText=$text;for($i=1;$i -lt $ts.Count;$i++){$ts[$i].InnerText=''}
  }
  foreach($rid in @('rId17','rId18','rIdSchemaErd4')){
   $node=$d.SelectSingleNode("//a:blip[@r:embed='$rid']",$ns);if($node){while($node.LocalName -ne 'p'){$node=$node.ParentNode};[void]$node.ParentNode.RemoveChild($node)}
  }
  $rel=$rels.DocumentElement.ChildNodes|Where-Object Id -EQ 'rId16';if(-not $rel){throw 'Missing Figure 5 image relationship.'}
  $part='word/'+$rel.GetAttribute('Target');$zip.GetEntry($part).Delete();$entry=$zip.CreateEntry($part);$s=$entry.Open();$file=Join-Path $out '05-core-business-erd.png';$bytes=[IO.File]::ReadAllBytes($file);$s.Write($bytes,0,$bytes.Length);$s.Dispose()
  $pic=$d.SelectSingleNode('//a:blip[@r:embed="rId16"]',$ns);while($pic.LocalName -ne 'p'){$pic=$pic.ParentNode}
  $image=[Drawing.Image]::FromFile($file);$cx=[long]5486400;$cy=[long]($cx*$image.Height/$image.Width);$image.Dispose();foreach($extent in $pic.SelectNodes('.//wp:extent | .//a:xfrm/a:ext',$ns)){$extent.SetAttribute('cx',"$cx");$extent.SetAttribute('cy',"$cy")}
  $pr=$pic.SelectSingleNode('.//wp:docPr',$ns);if($pr){$pr.SetAttribute('name','Core Business ERD');$pr.SetAttribute('descr','Seven core business entities and seven enforced relationships. Selected attributes; complete schema constraints are documented in the data dictionary.')}
  foreach($p in $d.SelectNodes('//w:body/w:p',$ns)){
   $t=(Txt $p).Trim()
   if($t -match '^Figure 5(?:a-[cd])?\.'){Put $p 'Figure 5. Core Business Entity Relationship Diagram'}
   elseif($t.StartsWith('The physical ERD in Figure 5') -or $t.StartsWith('Figure 5 presents the core business')){Put $p 'Figure 5 presents the core business entities and their stored relationships in a simplified ERD. It shows seven public-schema tables: membership_applications, members, membership_history, attendance, products, sales, and sale_items. The selected attributes include the primary keys and foreign keys linking these core entities, together with descriptive fields needed to understand their operational purposes. PK identifies a primary key, FK identifies a foreign key, and UQ identifies a unique constraint or index. The figure uses abbreviated data types for readability; declared character limits, numeric precision and scale, nullability, foreign-key targets, and relevant constraints are recorded in the data dictionary. This is a scoped view of the physical database rather than an illustration of every application table or column.'}
   elseif($t.StartsWith('The connecting lines join referenced') -or $t.StartsWith('The connecting lines in Figure 5')){Put $p 'The connecting lines in Figure 5 express relationships between entities, not a sequence of program operations. At a relationship end, a circle permits zero related records, a bar denotes one, and a crow''s foot denotes many. Combining these symbols distinguishes optional zero-or-one links, required one-parent links, and zero-or-many child records. A required foreign key makes its referenced parent mandatory for the child; a nullable foreign key permits no parent reference. A unique referencing column limits each parent to at most one child through that column. The optional links marked A and B between applications and members represent two different foreign keys and must be read separately. Cardinalities follow the actual key and nullability constraints; successful business operations may impose additional requirements beyond the minimum allowed by the table structure.'}
   elseif($t.StartsWith('The physical model includes supporting') -or $t.StartsWith('The full physical model includes supporting')){Put $p 'The full physical model includes supporting identity, account, phone-pairing, logging, and attendance-request storage outside the simplified figure. The fifteen application-owned tables comprise twelve public and three private tables. The eight application tables omitted from Figure 5 are public.profiles, public.activity_logs, public.mobile_attendance_pairing_policy, public.mobile_attendance_scan_sessions, public.mobile_attendance_scan_events, private.attendance_scan_requests, private.admin_login_attempts, and private.account_sessions. Managed auth.users is an additional external identity reference and is outside that fifteen-table application count. All fifteen application tables, their 174 fields, and all 21 declared foreign keys remain documented in the data dictionary. Identity and reviewer links omitted from the core diagram remain genuine constraints; their omission from this view does not remove them from the database. UUID fields such as activity_logs.actor_id and mobile_attendance_scan_sessions.paired_device_id have no declared foreign-key constraints. Their types alone do not establish relationships.'}
   elseif($t.StartsWith('1. auth.users Entity.')){Put $p ($t.Replace('1. auth.users Entity.','Supporting identity entity: auth.users.'))}
   elseif($t.StartsWith('2. profiles Entity.')){Put $p ($t.Replace('2. profiles Entity.','Supporting account entity: profiles.'))}
   elseif($t.StartsWith('3. membership_applications Entity.')){Put $p ($t.Replace('3. membership_applications Entity.','1. membership_applications Entity.'))}
   elseif($t.StartsWith('4. members Entity')){Put $p '2. members Entity. The members table stores current personal details, membership plan, dates, status, and registration source. It may link to the original registration application and to an authentication account. Walk-in registration by an administrator or authorized staff member can create a member without a source online application. Current member information is separated from prior membership events retained in membership_history.'}
   elseif($t.StartsWith('5. attendance Entity.')){Put $p ($t.Replace('5. attendance Entity.','3. attendance Entity.'))}
   elseif($t.StartsWith('6. products Entity.')){Put $p ($t.Replace('6. products Entity.','4. products Entity.'))}
   elseif($t.StartsWith('7. sales Entity.')){Put $p ($t.Replace('7. sales Entity.','5. sales Entity.'))}
   elseif($t.StartsWith('8. sale_items Entity.')){Put $p ($t.Replace('8. sale_items Entity.','6. sale_items Entity.'))}
   elseif($t.StartsWith('9. membership_history Entity.')){Put $p ($t.Replace('9. membership_history Entity.','7. membership_history Entity.'))}
   elseif($t.StartsWith('Members to Membership Applications.')){Put $p 'Members to Membership Applications. Link A represents members.application_id referencing membership_applications.id. This foreign key is nullable and unique, so each member may refer to zero or one source application and each application may be referenced by zero or one member through A. Link B represents membership_applications.member_id referencing members.id. A member can have zero or many requests through B, while each request may reference zero or one member. Online renewal requests use B to identify an existing member; a new registration normally has no member_id until its registration workflow is processed. These links have different purposes and are not one duplicated relationship.'}
   elseif($t.StartsWith('Members to Attendance.')){Put $p 'Members to Attendance. A member can have zero or many visit records, while each attendance row requires exactly one member through attendance.member_id. Each visit stores a check-in and may later store a check-out. Operator references recorded_by and checked_out_by are documented as separate authentication foreign keys in the dictionary; they are outside this core relationship line.'}
   elseif($t.StartsWith('Members to Sales.')){Put $p 'Members to Sales. A member can be associated with zero or many transaction headers. Because sales.member_id is nullable, an individual sale can reference zero or one member; a walk-in customer therefore does not require an existing member row. The transaction retains its customer label, total, status, timestamp, and internal reference independently of whether a member is linked.'}
   elseif($t.StartsWith('Members to Membership History.')){Put $p 'Members to Membership History. Each history record requires one member through membership_history.member_id. A member can have zero or many historical events. The record preserves applicable prior and resulting plans, prices, and dates so that changes can be interpreted separately from the current member values. The referenced member cannot be deleted while a restricting history reference remains.'}
   elseif($t.StartsWith('Sales to Sale_Items.')){Put $p 'Sales to Sale_Items. Every sale_items row requires exactly one sales row through sale_id. A sale can be referenced by zero or many line rows at the foreign-key level; this schema minimum does not establish that the sale-recording workflow accepts an empty transaction. The header records the transaction total and customer information, while the lines preserve each product or membership charge, quantity, unit price, and line total. ON DELETE CASCADE removes dependent line rows when their parent sale is deleted.'}
   elseif($t.StartsWith('Products to Sale_Items.')){Put $p 'Products to Sale_Items. A catalog product can appear in zero or many sale lines. Each line may reference zero or one product because product_id is nullable. Membership charges do not require a product reference. The saved item label and price preserve transaction details, and ON DELETE SET NULL clears the product reference rather than deleting the historical line when the referenced product is removed.'}
   elseif($t.StartsWith('The ERD includes core membership and transaction')){Put $p 'Figure 5 concentrates on the seven core business entities and seven foreign-key relationships to keep the presentation readable. The full schema artifacts and the dictionary cover the supporting tables and identity references. The dictionary Key(s) column identifies PK, FK, and UQ roles, and its description/constraints column states required or nullable status, referenced schema/table/column, deletion and update actions, unique-value requirements, composite-key membership, and relevant checks. For example, attendance.member_id uses ON DELETE CASCADE, while membership_history.member_id uses ON DELETE RESTRICT; similarly named fields therefore do not automatically have identical behavior. A database relationship does not grant permission to view or modify records: role checks, database policies, and authorized functions still govern access.'}
  }
  $order=@('public.profiles','public.members','public.membership_applications','public.attendance','public.products','public.sales','public.sale_items','public.membership_history','public.activity_logs','public.mobile_attendance_pairing_policy','public.mobile_attendance_scan_sessions','public.mobile_attendance_scan_events','private.attendance_scan_requests','private.admin_login_attempts','private.account_sessions')
  $dictionary=@($d.SelectNodes('//w:body/w:tbl',$ns)|Select-Object -Skip 5);if($dictionary.Count -ne 15){throw 'Expected fifteen data dictionary tables.'}
  $fields=0;$fkCount=0;$uqCount=0
  for($i=0;$i -lt $dictionary.Count;$i++){
   $name=$order[$i];$table=$model.Tables|Where-Object Name -EQ $name;$rows=@($dictionary[$i].SelectNodes('w:tr',$ns));$heads=$rows[0].SelectNodes('w:tc',$ns);Put $heads[3] 'Key(s)';Put $heads[4] 'Description / Constraints'
   if($rows.Count-1 -ne $table.Columns.Count){throw "Column count differs for $name"}
   $seen=[Collections.Generic.List[string]]::new()
   foreach($row in ($rows|Select-Object -Skip 1)){
    $cells=$row.SelectNodes('w:tc',$ns);$field=(Txt $cells[0]).Trim();$col=@($table.Columns|Where-Object Name -EQ $field)
    if($col.Count -ne 1 -or $field -in $seen){throw "Unknown/duplicate dictionary field $name.$field"};$seen.Add($field);$col=$col[0]
    $purpose=(Txt $cells[4]) -replace '\s+Constraints:.*$','' -replace '\s+(Required|Nullable)\.$',''
    if($name -eq 'private.account_sessions' -and $field -eq 'user_id'){$purpose='Identifies the Auth account owning the scoped session.'}
    $keys=@(@('PK','FK','UQ')|Where-Object {$_ -in $col.Keys});Put $cells[3] ($keys-join ', ')
    $notes=[Collections.Generic.List[string]]::new();$notes.Add($(if($col.Required){'NOT NULL.'}else{'NULL allowed.'}))
    $fk=@($model.Relations|Where-Object {$_.Child -eq $name -and $_.Field -eq $field})
    if($fk.Count -gt 1){throw 'Unexpected multiple foreign keys on one column.'}
    if($fk.Count){$notes.Add('References '+$fk[0].Parent+'('+$fk[0].ParentField+'); ON DELETE '+$fk[0].Delete+'; ON UPDATE NO ACTION.');$fkCount++}
    if('UQ' -in $keys){$notes.Add($(if($col.Required){'Values must be unique.'}else{'Non-NULL values must be unique.'}));$uqCount++}
    $pk=@($table.Columns|Where-Object {'PK' -in $_.Keys})
    if('PK' -in $keys -and $pk.Count -gt 1){$notes.Add('Part of composite PK ('+(($pk.Name)-join ', ')+'); this column alone is not declared unique.')}
    $key=$name+'.'+$field;if($checks.ContainsKey($key)){foreach($check in $checks[$key]){$notes.Add($check)}}
    if($key -in @('public.activity_logs.actor_id','public.mobile_attendance_scan_sessions.paired_device_id','private.account_sessions.session_id')){$notes.Add('No foreign key is declared on this UUID column.')}
    $type=$col.Type;$limit='N/A'
    if($type -match '^varchar\((\d+)\)$'){$limit=$Matches[1];$type='character varying'}
    elseif($type -match '^numeric\((\d+),(\d+)\)$'){$limit=$Matches[1]+','+$Matches[2];$type='numeric'}
    elseif($type -in @('text','text[]','jsonb')){$limit='Not declared'}
    if($key -eq 'public.mobile_attendance_scan_events.qr_payload'){$limit='1-500 (CHECK)'}
    Put $cells[1] $type;Put $cells[2] $limit;Put $cells[4] ($purpose+' Constraints: '+($notes-join ' '));$fields++
   }
  }
  if($fields -ne 174 -or $fkCount -ne 21 -or $uqCount -ne 5){throw "Unexpected dictionary coverage: $fields fields / $fkCount FKs / $uqCount unique fields."}
  $all=(@($d.SelectNodes('//w:body/w:p',$ns)|ForEach-Object {Txt $_}))-join ' '
  if($all -match 'Figure 5a-d|all 21 declared foreign-key connections, using|The ERD includes core membership and transaction relationships and supporting'){throw 'Outdated full-figure claim remains.'}
  foreach($expected in @('The fifteen application-owned tables comprise','Note. The Agile approach was informed by')){if(-not $all.Contains($expected)){throw "Required prior content missing: $expected"}}
  SaveXml 'word/document.xml' $d
 }finally{$zip.Dispose()}
 $checkZip=[IO.Compression.ZipArchive]::new([IO.File]::OpenRead($work));try{$r=[IO.StreamReader]::new($checkZip.GetEntry('word/document.xml').Open());$checkXml=[Xml.XmlDocument]::new();$checkXml.LoadXml($r.ReadToEnd());$r.Dispose()}finally{$checkZip.Dispose()}
 Copy-Item -LiteralPath $work -Destination $DocumentPath -Force
 'Updated Figure 5 to the seven-table Core Business ERD; explanations revised; all 174 dictionary fields include verified key roles and nullability, with 21 FK targets/actions and five unique-value fields.'
}finally{if(Test-Path -LiteralPath $work){Remove-Item -LiteralPath $work -Force}}
