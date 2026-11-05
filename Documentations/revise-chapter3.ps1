$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression
$path=Join-Path (Get-Location) 'Documentations\Chapter 3.docx'
$zip=[IO.Compression.ZipArchive]::new([IO.File]::Open($path,'Open','ReadWrite'),[IO.Compression.ZipArchiveMode]::Update)
$entry=$zip.GetEntry('word/document.xml');$reader=[IO.StreamReader]::new($entry.Open());$doc=[Xml.XmlDocument]::new();$doc.PreserveWhitespace=$true;$doc.LoadXml($reader.ReadToEnd());$reader.Dispose()
$ns=[Xml.XmlNamespaceManager]::new($doc.NameTable);$ns.AddNamespace('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main');$ns.AddNamespace('a','http://schemas.openxmlformats.org/drawingml/2006/main');$ns.AddNamespace('wp','http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing');$ns.AddNamespace('r','http://schemas.openxmlformats.org/officeDocument/2006/relationships')
$body=$doc.SelectSingleNode('//w:body',$ns);$p=@($body.SelectNodes('w:p',$ns));$tables=@($body.SelectNodes('w:tbl',$ns))
function SetText($node,$text){$ts=$node.SelectNodes('.//w:t',$ns);if($ts.Count -eq 0){return};$ts[0].InnerText=$text;for($i=1;$i -lt $ts.Count;$i++){$ts[$i].InnerText=''}}
function NewParagraph($text,$template=$p[103]){$node=$template.CloneNode($true);foreach($drawing in @($node.SelectNodes('.//w:drawing',$ns))){[void]$drawing.ParentNode.RemoveChild($drawing)};SetText $node $text;return ,$node}
$changes=@{
10='          Requirements planning identifies separate workflows for applicants, members, administrators, and authorized staff. Requirements cover online applications subject to administrator review, direct counter registration and membership changes, QR attendance, product inventory, transaction recording, reporting, staff accounts, phone pairing, and activity logs. Acceptance criteria include role permissions, required inputs, stock and membership updates, and rejection of unauthorized operations. These criteria guide each development increment.';
14='          The prototype represents the designed workflows through browser-based pages. Applicants submit registration details, while members view their membership, attendance, QR code, profile, catalog, and renewal requests. Administrators review online requests and manage membership records, inventory, sales, staff access, phone pairing, activity logs, and reports. Staff use a separate portal for attendance, walk-in registration, direct membership renewals and active-member plan changes, product sales, and their own product-sale records. The system records in-person transactions without providing receipts to customers. Supabase Auth, database policies, functions, and authorized Edge Functions support the implemented operations.';
22='                Functional requirements distinguish applicants and members from administrators and authorized staff. Online registration and renewal requests are reviewed by administrators. Staff have assigned counter and attendance operations, while stock maintenance, staff account controls, phone pairing administration, activity-log review, and reports remain administrator functions.';
39='          The hardware requirements describe practical development and operating equipment rather than benchmarked minimum performance. A browser-capable computer and stable internet connection support the main system; a supported camera-enabled phone or computer supports QR attendance. Printing is optional for operational reports. A dedicated POS terminal or receipt printer is not required.';
49='    Figure 2 is the context diagram. It contains one process, numbered 0, representing IronGrind and three external actor groups: Member / Applicant, Administrator, and Authorized Staff. Databases, authentication services, and phone-pairing storage remain internal to the system boundary.';
51='The Administrator provides application review decisions, membership and inventory updates, sales entries, staff account controls, phone-pairing administration, and report or activity-log queries.';
52='The system returns the corresponding records, status confirmations, account information, activity logs, and reports. Authorized staff provide attendance scans, walk-in registration details, direct renewal and plan-change inputs, and product sales entries; they receive only the confirmations and records permitted for their role.';
55='            Figure 2 shows the exchange of data between the three actor groups and the whole system. Unlike the Level 1 DFD, the context diagram does not expose internal processes or data stores. Walk-in customers transact through an administrator or staff operator and do not access a member account solely to make a product purchase.';
56='           The Member / Applicant submits credentials, registration details, renewal requests, and profile changes and receives their own application status, membership information, attendance history, QR code, and active catalog. Administrator and staff inputs differ according to their assigned permissions. Transaction confirmations refer to saved system records; they do not represent receipts issued to customers.';
60='       Figure 3 decomposes the system into eight processes. Repeated actor and store references describe the same logical actors and data stores in separate lanes. D1 is profiles; D2, membership_applications; D3, members; D4, attendance; D5, products; D6, sales; D7, sale_items; D8, membership_history; and D9, activity_logs. D10 groups the phone-pairing policy, session, and retained scan-event tables. Supabase Auth manages credentials separately from D1. Operational mutations and logging functions also create activity records. Supporting private scan-request storage prevents duplicate scan processing.';
62='1.0 Authenticate and Authorize';
63='       Supabase Auth verifies credentials and establishes the user session. The system reads the profile role and active-account state to route the account to the administrator, staff, or member interface. Authorization is enforced through database policies, role-checked functions, and Edge Functions, rather than relying on page visibility alone.';
64='2.0 Review Online Applications. Applicants submit registration details and health declarations to membership_applications. Only administrators review online requests and approve or reject them. Approval creates or links the member record, updates application and account states, and records the applicable membership payment through sales and sale_items. Direct walk-in registration follows process 3.0 instead of granting staff online-review permission.';
65='3.0 Manage Memberships. Administrators manage member records. Authorized administrators and staff can register walk-in members through the role-checked account-creation function, record direct membership renewals, and change a plan within the access permitted by the system. Staff plan changes require an active member; renewal search can include members who need renewal. Membership changes update members and membership_history and record membership charges in sales and sale_items. Account creation uses Supabase Auth through a server-side Edge Function.';
66='4.0 Review Online Renewals. Members submit renewal requests to membership_applications. Administrators approve or reject these requests. An approved renewal preserves unused time by extending an active membership from its current expiry date; an expired membership restarts on approval. Approval updates the member, history, application status, and membership transaction records. Direct counter renewals by an administrator or staff operator belong to process 3.0 and do not grant staff permission to review online requests.';
67='5.0 Record QR Attendance. An authorized administrator or staff operator scans a member QR code with a supported computer or phone camera. The database validates the operator and member, checks for an open visit, and records check-in or check-out in attendance. recorded_by and checked_out_by identify the operators for each event. Private attendance_scan_requests records support duplicate-request protection. Paired phones additionally use administrator-managed pairing sessions and policy; pairing does not replace operator authentication.';
68='6.0 Manage Inventory and Catalog. Administrators maintain product details, prices, stock, product forms, and active or archived state. Powder supplements support weight units; drinkable supplements support volume units; capsules and tablets use pieces or boxes; other supplements and merchandise use items. Sale processing converts compatible quantities and deducts stock using the configured inventory units. Members browse active products, and staff obtain the permitted catalog needed for sales; these read operations do not grant inventory-maintenance permission.';
70='            Administrators and staff record in-person product purchases for members or walk-in customers. The sale operation validates quantities and product status, writes sales and sale_items, and deducts product stock. Membership charges are recorded through the membership operations in processes 2.0 to 4.0. The database retains the existing receipt_number field as an internal transaction identifier. The documented operating process does not provide customers with receipts.';
71='8.0 Reports and Administration';
72='            Administrators request operational reports and review the relevant membership, attendance, inventory, sales, and history records. Reports support preview, printing, individual PDF output, and combined export. Date-based reports use the selected period, while current-state reports show current data. Administrator functions also control staff accounts, phone-pairing settings and sessions, and activity-log review. Staff account provisioning uses an administrator-authorized Edge Function, and activity logs record actor and operation information.';
75='                Figure 4 distinguishes the Member / Applicant, Authorized Staff, and Administrator actors. Each column associates one actor with its available use cases inside the IronGrind system boundary. Repeated shared use cases, such as authentication and attendance recording, refer to the same system function.';
78='                Administrator and staff permissions are shown separately. Staff do not inherit administrator access to online application review, inventory maintenance, staff account controls, phone-pairing administration, reports, or activity logs.';
80='                Administrators review online applications and renewal requests and manage membership records, products, stock, staff access, phone pairings, activity logs, and reports. Staff record attendance, register walk-in members, perform permitted direct membership changes, record product sales, and review their own product-sale records.';
84='              Supabase Auth verifies credentials. The profile role and active-account state determine administrator, staff, or member access, with protected operations checked by server-side authorization.';
87='4. Create or Link Member Account. Administrator approval links an online application to the approved member record. Direct walk-in registration by an authorized administrator or staff operator uses a server-side Edge Function to create the appropriate Auth, profile, member, and payment records.';
91='8. Record Membership Attendance. An administrator or authorized staff operator scans a member QR code using a supported computer or phone camera. The system records a check-in or check-out and the responsible operator.';
96='13. Record Product Sale. An administrator or staff operator records an in-person product purchase, with validated quantities, saved sales and line items, and corresponding stock deduction. Staff can review their own product-sale records. No receipt provision is included in the documented operating process.';
100='17. Staff, Phone, and Activity Administration. Administrators create and control staff access, manage authorized phone pairings and pairing limits, and review activity logs. Staff accounts have separate counter and attendance use cases, including direct membership renewal and active-member plan change. Business email notifications for application approval, renewal approval, or expiration are not included as implemented use cases.';
102='Figure 5a-c. Physical entity relationships';
103='The physical ERD in Figure 5a-c follows declared foreign keys in the current database migration baseline. Each panel presents parent-to-child relationships, foreign-key fields, cardinalities, and deletion actions. Repeated boxes refer to the same table. The model includes application tables and supporting phone-pairing and private attendance-request tables. Managed Supabase Auth internals are outside the application schema shown here.';
106='2. profiles Entity. Each profile shares its primary key with auth.users and records the administrator, staff, or member role, account status, active flag, name, username, email, phone number, gender, and timestamps.';
109='5. attendance Entity. Each visit references a member and stores its date and check-in and optional check-out timestamps. recorded_by and checked_out_by independently reference the Auth accounts responsible for the two attendance events.';
110='6. products Entity. Products store category, price, stock, stock and sale units, supplement form and type, merchandise type, size, active or archived state, and image reference. Stock is numeric and supports product-appropriate weight, volume, piece, box, or item units.';
111='7. sales Entity. Each row stores a transaction total, customer details, optional member reference, status, sold_at timestamp, and processing Auth account. The retained receipt_number column is an internal transaction reference; its technical name does not mean that a receipt is provided to the customer.';
112='8. sale_items Entity. Each line belongs to one sale and optionally references a product. It preserves the item or membership label, category, quantity, unit, price, and line total. Membership charges have no product reference, and historical item labels remain available if a product reference becomes NULL.';
113='9. membership_history Entity. History records reference a member and optionally the responsible Auth account. They retain renewal, plan-change, or expiry events and the membership values before and after the event.';
114='Auth Users to Profiles and Members. An Auth account can have at most one profile and at most one linked member record. Each profile requires an Auth account; a member record can exist without an Auth link. Administrator, staff, and pending-applicant accounts need not have a linked member record.';
121='Supporting Relationships. Online application reviewed_by references profiles, while attendance and transaction operator fields reference auth.users. Phone sessions reference their creator, scan events reference their session, and pairing policy optionally references its updating Auth user. Private attendance_scan_requests references an operator and member. activity_logs.actor_id is a stored actor identifier without a declared foreign key; it is not drawn as an enforced relationship.';
123='            The ERD includes core membership and transaction relationships and supporting identity and phone-attendance relationships. Nullable references permit walk-in sales without a member, membership charges without a product, and membership records without an Auth account. Referential actions follow the baseline: attendance.member_id cascades on member deletion, while membership_history.member_id restricts deletion. The dictionary below lists actual column types, NULLability, and declared keys from the same baseline rather than assuming that similarly named fields have identical types.';
125='         The data dictionary lists application and supporting database tables from the current checked-in migration baseline. Each entry identifies a column, its PostgreSQL type and size, declared key, and NULLability or purpose. Physical fields retained for compatibility are listed even when current forms prefer a newer field. Supabase Auth tables are managed by the authentication service and are not reproduced as an application-owned dictionary.';
128='Stores account-facing profile details, administrator/staff/member roles, account status, active-account controls, contact details, and timestamps.';
133='Table 8: membership_applications';
143='Stores one transaction header with customer details, amount, status, optional member reference, internal transaction identifier, and processing operator.';
153='The system uses registration, profile, renewal, member, inventory, sales, staff-account, and phone-pairing forms. Members submit online registration or renewal information and maintain their permitted profile details. Administrators review online requests, maintain products and stock, and manage staff and pairing access. Authorized staff use counter forms for walk-in registration, direct renewal, active-member plan change, and product purchases. Attendance uses camera scanning under an authorized operator account. Completed payments and purchases are recorded as transactions; receipts are not provided to customers. Required fields, validation, and server-side role checks support consistent data entry.';
168='Login. Members, staff, and administrators sign in through the supported account workflow. Applicants can register, and account holders can access password recovery.';
246='Store and Inventory. Administrators add, update, restock, or archive products. Authorized staff can record product sales from their permitted catalog but cannot maintain inventory records.';
265='                Membership Sales. Administrators review recorded membership income and transaction counts for the selected period and plan. The transaction identifier supports internal record retrieval; customer receipt provision is outside the documented process.';
280='Product Sales. Administrators review product-income totals and transaction records and record new purchases. Staff record product purchases through their own portal and review their own product-sale records.';
388='Figure 20. Staff operations and access';
389='Staff Operations. Figure 20 summarizes staff attendance and counter functions and distinguishes administrator-only controls. It is a workflow illustration rather than a captured interface. The earlier receipt illustration has been replaced to match the stated transaction-recording scope.'
}
foreach($key in $changes.Keys){SetText $p[$key] $changes[$key]}
# Update requirement tables while retaining their original Word formatting.
$req=@{
'User Login'='Role-based authentication for administrators, staff, and members using Supabase Auth and profile access checks.';
'Manage Membership'='Administrators manage member records. Authorized administrators and staff register walk-in members and perform permitted direct renewals and active-member plan changes.';
'Products & Inventory'='Administrators maintain product data and stock using weight, volume, piece, box, or item units appropriate to each product. Staff read the permitted sales catalog.';
'Sales'='Authorized operators record in-person product transactions and stock deductions; membership charges are recorded through membership workflows. No receipts are provided.';
'QR Attendance'='Authorized operators record check-in and check-out using supported computer or phone cameras; operator accounts are retained for each event.'
}
foreach($table in $tables[0..2]){foreach($row in $table.SelectNodes('w:tr',$ns)){$cells=$row.SelectNodes('w:tc',$ns);if($cells.Count -lt 2){continue};$name=(($cells[0].SelectNodes('.//w:t',$ns)|ForEach-Object {$_.InnerText}) -join '').Trim();if($req.ContainsKey($name)){SetText $cells[1] $req[$name]}}}
function AddRow($table,$values){$template=$table.SelectNodes('w:tr',$ns)[1];$row=$template.CloneNode($true);$cells=$row.SelectNodes('w:tc',$ns);for($i=0;$i -lt $values.Count;$i++){SetText $cells[$i] $values[$i]};[void]$table.AppendChild($row)}
foreach($table in $tables[0..2]){AddRow $table @('Staff Accounts, Phone Pairing, and Activity Logs','Administrator-only controls provision or disable staff access, manage paired attendance phones, and review recorded activity. Inputs are authorized account/settings changes and log queries; outputs are saved states, confirmations, and filtered records.')}
foreach($row in $tables[4].SelectNodes('w:tr',$ns)){$cells=$row.SelectNodes('w:tc',$ns);if($cells.Count -lt 4){continue};$name=(($cells[0].SelectNodes('.//w:t',$ns)|ForEach-Object {$_.InnerText}) -join '').Trim();switch($name){
'POS System / Terminal' {SetText $cells[0] 'Front-desk Device';SetText $cells[1] 'Browser-capable computer';SetText $cells[2] 'Computer with supported camera';SetText $cells[3] 'Used for membership, attendance, and transaction recording; dedicated POS hardware is not required.'}
'Printer' {SetText $cells[1] 'Optional';SetText $cells[2] 'Available office printer';SetText $cells[3] 'Optional printing of operational reports; receipt printing is not a requirement.'}
'Camera/Scanner' {SetText $cells[1] 'Supported camera-enabled device';SetText $cells[2] 'Clear-focus phone camera or webcam';SetText $cells[3] 'Camera permission and a secure browser context support QR scanning. Paired phone use remains subject to operator authorization.'}
}}
# Replace dictionary rows with exact declared columns and types from the migration baseline.
$sql=Get-Content -Raw 'supabase\migrations\20261105043517_remote_schema.sql'
$schemaTables=@('profiles','members','membership_applications','attendance','products','sales','sale_items','membership_history','activity_logs','mobile_attendance_pairing_policy','mobile_attendance_scan_sessions','mobile_attendance_scan_events','attendance_scan_requests','admin_login_attempts')
$descriptions=@{
'paid'='Recorded membership payment amount; not a Boolean flag.';
'receipt_number'='Internal transaction reference retained under its existing schema name; no customer receipt is provided.';
'stock'='Product quantity on hand in the configured stock unit; supports supplements and merchandise.';
'stock_unit'='Configured inventory unit for quantity on hand.';
'unit'='Configured quantity unit; allowed values depend on the product or sale-line category.';
'checked_out_by'='Auth account responsible for check-out.';
'recorded_by'='Auth account responsible for recording the event.';
'processed_by'='Auth account responsible for processing the transaction.';
'actor_id'='Recorded actor identifier; no declared foreign key.';
'token_hash'='Hashed pairing credential; not a raw pairing token.';
'pairing_password_hash'='Hashed phone-pairing password.';
'pairing_removal_pin_hash'='Hashed pairing-removal PIN.';
'request_id'='Idempotency key identifying a processed attendance request.';
'items'='Stored JSON transaction-item payload; normalized line items are also represented in sale_items.';
'emergency_contact_data'='Structured emergency-contact payload.';
'signature_data'='Compatibility signature data field.';
'weight'='Compatibility weight measurement; weight_kg is also retained.'
}
for($ti=0;$ti -lt $schemaTables.Count;$ti++){
 $name=$schemaTables[$ti];$schema=if($ti -ge 12){'private'}else{'public'}
 $m=[regex]::Match($sql,('CREATE TABLE IF NOT EXISTS "'+$schema+'"\."'+$name+'" \(([\s\S]*?)\n\);'))
 if(-not $m.Success){throw "Missing table $name"}
 if($ti -lt 8){$table=$tables[$ti+5]}else{
  $heading=NewParagraph ("Table $($ti+6): $schema.$name") $p[127];[void]$body.InsertBefore($heading,$p[151])
  $table=$tables[5].CloneNode($true);[void]$body.InsertBefore($table,$p[151])
 }
 $rows=@($table.SelectNodes('w:tr',$ns));$rowTemplate=$rows[1].CloneNode($true)
 foreach($row in $rows|Select-Object -Skip 1){[void]$table.RemoveChild($row)}
 foreach($line in ($m.Groups[1].Value -split "`n")){
  $cm=[regex]::Match($line,'^\s+"([^"]+)"\s+(.+?)(?:,)?\s*$');if(-not $cm.Success){continue}
  $col=$cm.Groups[1].Value;$decl=$cm.Groups[2].Value
  $type=([regex]::Split($decl,'\s+(?:DEFAULT|NOT NULL|GENERATED)\b'))[0].Trim().TrimEnd(',').Replace('"','')
  $size='';if($type -match '\(([^)]+)\)'){$size=$Matches[1];$type=$type -replace '\([^)]+\)',''}
  if($type -eq 'timestamp with time zone'){$type='timestamptz'}
  $key='';if($sql -match ('ALTER TABLE ONLY "'+$schema+'"\."'+$name+'"\s+ADD CONSTRAINT "[^"]+" PRIMARY KEY \("'+$col+'"\)')){$key='PK'}
  $fk=[regex]::Match($sql,('ALTER TABLE ONLY "'+$schema+'"\."'+$name+'"\s+ADD CONSTRAINT "[^"]+" FOREIGN KEY \("'+$col+'"\) REFERENCES "([^"]+)"\."([^"]+)"\("([^"]+)"\)'))
  if($fk.Success){$key=if($key){'PK, FK'}else{'FK'}}
  $nullable=if($decl -match 'NOT NULL'){'Required.'}else{'Nullable.'};$desc=$nullable
  if($fk.Success){$desc+=" References $($fk.Groups[1].Value).$($fk.Groups[2].Value).$($fk.Groups[3].Value)."}
  if($descriptions.ContainsKey($col)){$desc+=' '+$descriptions[$col]}
  $row=$rowTemplate.CloneNode($true);$cells=$row.SelectNodes('w:tc',$ns);$values=@($col,$type,$size,$key,$desc);for($j=0;$j -lt 5;$j++){SetText $cells[$j] $values[$j]};[void]$table.AppendChild($row)
 }
}
# Replace embedded figures and remove old SVG alternatives to prevent Word showing stale diagrams.
$relEntry=$zip.GetEntry('word/_rels/document.xml.rels');$r=[IO.StreamReader]::new($relEntry.Open());[xml]$rels=$r.ReadToEnd();$r.Dispose()
function ReplaceImage($rid,$file,$paragraph){
 $rel=$rels.DocumentElement.ChildNodes|Where-Object {$_.Id -eq $rid};$part='word/'+$rel.Target
 $old=$zip.GetEntry($part);if($null -ne $old){$old.Delete()};$new=$zip.CreateEntry($part);$stream=$new.Open();$data=[IO.File]::ReadAllBytes((Join-Path (Get-Location) "Documentations\Chapter 3 Diagrams\$file"));$stream.Write($data,0,$data.Length);$stream.Dispose()
 foreach($ext in @($paragraph.SelectNodes('.//a:extLst',$ns))){[void]$ext.ParentNode.RemoveChild($ext)}
 $img=[Drawing.Image]::FromFile((Join-Path (Get-Location) "Documentations\Chapter 3 Diagrams\$file"));$cx=[long]5486400;$cy=[long]($cx*$img.Height/$img.Width);if($cy -gt 7406640){$cy=7406640;$cx=[long]($cy*$img.Width/$img.Height)};$img.Dispose()
 foreach($extent in $paragraph.SelectNodes('.//wp:extent | .//a:xfrm/a:ext',$ns)){$extent.SetAttribute('cx',"$cx");$extent.SetAttribute('cy',"$cy")}
}
Add-Type -AssemblyName System.Drawing
ReplaceImage 'rId12' '02-context.png' $p[53]
ReplaceImage 'rId13' '03-data-flow.png' $p[58]
ReplaceImage 'rId14' '04-use-cases.png' $p[73]
ReplaceImage 'rId16' '05-erd-1.png' $p[101]
# Add the two continuation panels using their own image relationships.
for($panel=2;$panel -le 3;$panel++){
 $rid="rIdChapter3Erd$panel";$rel=$rels.CreateElement('Relationship',$rels.DocumentElement.NamespaceURI);$rel.SetAttribute('Id',$rid);$rel.SetAttribute('Type','http://schemas.openxmlformats.org/officeDocument/2006/relationships/image');$rel.SetAttribute('Target',"media/chapter3-erd-$panel.png");[void]$rels.DocumentElement.AppendChild($rel)
 $node=$p[101].CloneNode($true);$blip=$node.SelectSingleNode('.//a:blip',$ns);$blip.SetAttribute('embed',$ns.LookupNamespace('r'),$rid)
 foreach($idNode in $node.SelectNodes('.//wp:docPr',$ns)){$idNode.SetAttribute('id',"$($panel+1000)");$idNode.SetAttribute('name',"ERD panel $panel")}
 ReplaceImage $rid "05-erd-$panel.png" $node
 [void]$body.InsertBefore($node,$p[102])
}
# Replace the obsolete receipt prototype image with the staff-role workflow figure.
ReplaceImage 'rId33' '04-use-cases.png' $p[377]
$relEntry.Delete();$new=$zip.CreateEntry('word/_rels/document.xml.rels');$w=[IO.StreamWriter]::new($new.Open(),[Text.UTF8Encoding]::new($false));$w.Write($rels.OuterXml);$w.Dispose()
$entry.Delete();$new=$zip.CreateEntry('word/document.xml');$w=[IO.StreamWriter]::new($new.Open(),[Text.UTF8Encoding]::new($false));$w.Write($doc.OuterXml);$w.Dispose();$zip.Dispose()
'Updated Chapter 3 narrative, requirement tables, physical dictionary, and embedded diagrams.'
