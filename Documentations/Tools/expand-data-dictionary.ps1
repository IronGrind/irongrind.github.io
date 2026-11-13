$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression
$path=Join-Path (Get-Location) 'Documentations\Chapter 3.docx'
$z=[IO.Compression.ZipArchive]::new([IO.File]::Open($path,'Open','ReadWrite'),[IO.Compression.ZipArchiveMode]::Update)
try {
$e=$z.GetEntry('word/document.xml');$r=[IO.StreamReader]::new($e.Open());$d=[Xml.XmlDocument]::new();$d.PreserveWhitespace=$true;$d.LoadXml($r.ReadToEnd());$r.Dispose()
$n=[Xml.XmlNamespaceManager]::new($d.NameTable);$n.AddNamespace('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main')
function Txt($node){return ($node.SelectNodes('.//w:t',$n)|ForEach-Object {$_.InnerText}) -join ''}
function Put($node,$text){$ts=$node.SelectNodes('.//w:t',$n);if($ts.Count -eq 0){$paragraph=$node.SelectSingleNode('w:p',$n);if(-not $paragraph){$paragraph=$d.CreateElement('w','p',$n.LookupNamespace('w'));[void]$node.AppendChild($paragraph)};$run=$d.CreateElement('w','r',$n.LookupNamespace('w'));$value=$d.CreateElement('w','t',$n.LookupNamespace('w'));$value.InnerText=$text;[void]$run.AppendChild($value);[void]$paragraph.AppendChild($run);return};$ts[0].InnerText=$text;for($j=1;$j -lt $ts.Count;$j++){$ts[$j].InnerText=''}}
$purposes=@{
'created_by'='Identifies the Auth account of the administrator who created the phone-pairing session. This attribution is separate from the authorized operator account that later records a member attendance scan.';
'id'='Uniquely identifies this record so that the system can retrieve it and relate it to other operational information without relying on a person or product name.';
'full_name'='Stores the complete name submitted for the account, application, or member. It supports identification and authorized record retrieval; storing a name does not grant administrators or staff permission to edit an existing personal profile.';
'email'='Stores the email address associated with the account or submitted record. It supports account identification and communication details, with a database limit that remains separate from email-format validation in the interface.';
'username'='Stores the application username used to identify an account within supported sign-in and member-lookup workflows. Its character limit does not by itself enforce permitted characters or uniqueness, which are separate validation and index concerns.';
'role'='Identifies the account role as admin, staff, or member. The role is evaluated by authorization checks to distinguish administrator operations, limited staff duties, and member self-service.';
'account_status'='Stores the account-state value as pending, active, or disabled according to its database check constraint. This state is distinct from the membership period and from the separate is_active flag.';
'is_active'='Indicates whether the account or catalog record is enabled for its applicable workflow. This Boolean value is not a personal-profile editing permission and does not replace role-based authorization.';
'phone_number'='Stores contact information for the account. Staff provisioning accepts ten Philippine mobile digits after the +63 prefix and stores the country-prefixed value; this workflow rule is not a declared text-column length.';
'gender'='Stores the gender value supplied for an account through the supported form. The staff provisioning service validates its permitted choices separately from the database text type.';
'mobile'='Stores a Philippine mobile contact number for the member or applicant. The database permits up to eleven characters; relevant forms validate either a local 09-prefixed number or ten digits entered after a displayed +63 prefix.';
'date_of_birth'='Records the person’s birth date for registration and personal-information records. A date value is stored as a calendar date rather than as a character string with a user-defined length.';
'age'='Stores the recorded age value associated with the person. This numeric value is separate from date_of_birth and may be captured or recalculated by the applicable workflow.';
'sex'='Stores the sex value submitted in the member or application form. The character limit controls storage size, while available form choices are handled separately by the interface.';
'height'='Stores the submitted height measurement as a decimal number. The meaning of the measurement depends on the accompanying height_unit field rather than on a unit embedded in the number.';
'height_unit'='Identifies the unit associated with the height measurement. The database permits cm, in, or ft when a value is supplied.';
'weight'='Retains a compatibility weight measurement used by earlier or supporting data paths. It is documented separately from weight_kg because both columns remain in the physical schema.';
'weight_kg'='Stores the person’s weight in kilograms as a decimal measurement. It is the explicit kilogram field used by the supported personal-information workflow.';
'emergency_contact'='Stores emergency-contact information. Its physical representation depends on the table: members stores structured JSON, while membership_applications retains a text compatibility field.';
'emergency_contact_data'='Stores the structured emergency-contact payload associated with an application. It is a JSON object rather than a single fixed-length contact-name or phone-number column.';
'emergency_name'='Retains the emergency contact person’s name submitted with an application. This compatibility text field has no declared database character limit in the checked-in baseline.';
'emergency_relationship'='Retains the applicant’s relationship to the emergency contact person. A form may restrict its input length even though this compatibility text column has no declared character limit.';
'plan'='Stores the name of the membership plan associated with the record. The selected plan is used by membership operations to determine the applicable period and payment information.';
'plan_price'='Stores the monetary amount associated with the selected membership plan. Precision and scale control the total number of stored digits and the number of decimal places; supported plan prices are validated separately by the workflow.';
'paid'='Stores the recorded membership payment amount as a number. In the current baseline this column is numeric, not a Boolean indicator of whether payment occurred.';
'start_date'='Records the starting calendar date of the requested or current membership period. It is evaluated with the corresponding end or expiry date by the applicable membership workflow.';
'end_date'='Stores the membership end date retained by current and compatibility operations. In members, expiry_date may be preferred while end_date remains available as a fallback.';
'expiry_date'='Stores the explicit expiration date of the member’s recorded membership period. It supports expiration display, renewal handling, and attendance validation.';
'status'='Stores the lifecycle or transaction state of the record. Permitted values depend on the table and must not be assumed to be identical for memberships, applications, and sales.';
'registration_source'='Identifies the workflow through which the member record was created, such as online application or an authorized counter registration. It distinguishes the origin of a record from the member’s current status.';
'fitness_goals'='Stores the selected fitness-goal entries as an array of text values. The column does not declare a maximum array length or a character limit for each element.';
'health_conditions'='Stores declared health-condition entries as an array of text values. These records support the gym’s stated registration purposes and do not constitute a diagnosis or automated medical advice.';
'other_medical_conditions'='Stores additional health-condition details supplied by the person. The online registration textarea limits entry to 500 characters, but the database text column itself does not declare that limit.';
'signature_data'='Retains signature data submitted through the registration workflow. Because this is a text storage field for signature content, it should not be assigned an invented short name-style limit.';
'signature_path'='Stores a signature reference or payload used by the applicable workflow. The column name alone does not guarantee that every stored value is a file path.';
'created_at'='Records when the database record was created. A timestamp with time zone represents a point in time; display formatting and the Manila timezone are interface concerns rather than character-length restrictions.';
'updated_at'='Records the timestamp used to identify the latest update to the record. The applicable operation or database mechanism must maintain this value; the column name alone does not guarantee automatic refresh.';
'auth_user_id'='Links the record to a managed Supabase Auth account. A UUID identifies the account; it is not the person’s display name, email address, or password.';
'application_id'='Links a member record to the associated registration application when one exists. Direct counter registration can create a member without a linked online application.';
'member_id'='Identifies the member related to this operational record. Whether it is required or nullable depends on the specific table and its declared relationship.';
'application_type'='Identifies an initial registration, member renewal, or active-member plan-change request. The database restricts this value to registration, renewal, or plan_change.';
'reviewed_by'='Identifies the profile of the administrator who reviewed the application. It records responsibility for the decision rather than granting the applicant or staff permission to approve a request.';
'reviewed_at'='Records when the administrator reviewed the request. It may remain empty while the request is pending.';
'submitted_at'='Records the submission timestamp associated with an application. It supports the ordering and retrieval of submitted requests.';
'date'='Stores the date associated with the attendance row. It is a separate physical column from the precise time_in and time_out timestamps.';
'time_in'='Records when the visit began. The attendance workflow uses this timestamp with the latest visit and duplicate-request controls when processing QR scans.';
'time_out'='Records when the visit ended. An empty value can indicate that the attendance record remains open or that a check-out has not been recorded.';
'recorded_by'='Identifies the Auth account responsible for recording the attendance or history event. It supports operator attribution without implying that the operator can edit the member’s personal profile.';
'checked_out_by'='Identifies the Auth account that recorded check-out. It is stored separately from recorded_by because different authorized operators may handle the two events.';
'name'='Stores the product’s catalog name used in inventory and product selection. Historical sale lines retain their own item-name snapshots so that transaction descriptions do not depend entirely on the current catalog label.';
'category'='Classifies the product or sale line for the appropriate operational behavior. Products distinguish supplements and merchandise, while sale lines can additionally represent membership charges.';
'price'='Retains the product price field declared in the physical schema. It is distinct from price_per_unit, which records the explicit unit-based pricing information used by applicable workflows.';
'price_per_unit'='Stores the product price for the configured pricing unit. Quantity conversion and product form determine how a selected sale unit relates to this price.';
'stock'='Stores the available product quantity using the configured inventory unit. The numeric field supports fractional quantities for compatible weight or volume products and is not restricted to merchandise alone.';
'stock_unit'='Identifies the unit in which inventory quantities are recorded. Permitted units depend on the product category and supplement form, including compatible weight, volume, piece, box, or item units.';
'unit'='Identifies the unit associated with a product price or sale-line quantity. The permitted unit depends on the product form or line category; a character limit does not itself establish compatibility between units.';
'size'='Stores an optional size or package description used to distinguish applicable merchandise or products. An empty value is permitted where size is not relevant.';
'archived_at'='Records when a product was archived, when applicable. Product archival is distinct from deleting historical sales information.';
'image_path'='Stores the catalog image reference associated with the product. The database does not declare a fixed character limit for this reference.';
'merch_type'='Identifies the merchandise classification, such as apparel, accessories, drinkware, gym_gear, or other. The database’s category-related checks distinguish merchandise from supplement records.';
'supplement_form'='Identifies the supplement form as powder, drinkable, capsule, tablet, or other where applicable. The form determines the compatible inventory and pricing units.';
'supplement_type'='Classifies a supplement as protein, creatine, pre_workout, vitamins, amino_acids, or other. This classification is separate from its physical form and inventory unit.';
'receipt_number'='Stores the existing internal transaction reference under its retained database column name. The documented gym process records transactions without providing customer receipts.';
'customer_type'='Stores the customer classification recorded for the sale. The string length limits storage and should not be mistaken for a documented fixed list of allowed values unless a separate check enforces that list.';
'customer_name'='Preserves the customer name supplied for the transaction. Current product-sale recording accepts a customer name without requiring a member-profile selection.';
'items'='Retains a JSON transaction-item payload in the sales header. Normalized transaction lines are also represented separately in sale_items.';
'total'='Stores the complete transaction amount in the sale header. It is separate from the quantity, unit price, and line total retained for each individual sale line.';
'sold_at'='Records the transaction timestamp. Reporting workflows use this value to identify transactions within the selected period.';
'processed_by'='Identifies the Auth account of the authorized operator who recorded the transaction. This reference supports transaction attribution and role-restricted sales review.';
'sale_id'='Links each sale line to its transaction header. The declared cascading deletion rule removes related line items when the parent sale is deleted.';
'product_id'='Links a sale line to its catalog product when applicable. It may be empty for membership charges or after an associated product reference is removed.';
'item_name'='Preserves the product or membership label as it was recorded for the transaction line. This snapshot supports historical record readability if the catalog description later changes.';
'quantity'='Stores the quantity charged for a sale line, including fractional amounts where supported. The unit field identifies how the quantity is interpreted.';
'unit_price'='Stores the price charged per recorded sale unit. It is retained with the transaction rather than being inferred from the product’s current catalog price.';
'line_total'='Stores the amount charged for an individual sale line. It provides the line-level monetary value associated with the recorded quantity and unit price.';
'event_type'='Identifies the membership-history event as expired, renewal, or plan_change. The row preserves the relevant membership values before and after the event.';
'previous_plan'='Records the plan before the membership-history event. It may be empty when the earlier value is not applicable or was not captured.';
'new_plan'='Records the plan associated with the membership after the recorded event. It supports comparison with previous_plan.';
'previous_price'='Stores the membership price before the recorded event. This historical value is not replaced by the member’s current plan price.';
'new_price'='Stores the membership price after the recorded event. It supports an auditable comparison of the recorded membership change.';
'previous_start_date'='Preserves the membership start date before the history event. It supports review of how the recorded membership period changed.';
'previous_expiry_date'='Preserves the membership expiry date before the history event. Renewal and plan-change review can compare it with the new recorded dates.';
'new_start_date'='Records the start date after the membership-history event. Its meaning depends on whether the event was a renewal or plan change.';
'new_expiry_date'='Records the expiry date after the membership-history event. It preserves the historical result even when the member later renews again.';
'notes'='Stores supporting context about the membership-history event. It is free-form text without a declared database character limit.';
'recorded_at'='Records when the membership-history event was saved. It is separate from the membership period’s start and expiry dates.';
'occurred_at'='Records when the activity entry was captured. The log viewer uses timestamps for ordering and date-based filtering.';
'actor_id'='Retains the identifier of the account responsible for the logged operation. In the baseline it is a stored identifier without a declared foreign-key constraint.';
'actor_name'='Preserves the actor name captured with the activity entry. It helps identify the recorded operator without requiring a current profile lookup.';
'actor_role'='Preserves the role captured when the activity was recorded. It describes the event’s actor and does not itself grant access to the log viewer.';
'action'='Identifies the recorded action, such as creation, update, approval, check-in, or a phone-pairing event. Activity Logs reads this value for display and filtering.';
'entity_type'='Identifies the system area or table associated with the logged action. It supports filtering records by operational area.';
'entity_id'='Stores the identifier of the affected record when one is available. It is retained as text so that different operational identifier forms can be represented.';
'record_label'='Stores a readable label for the affected record. It helps the administrator understand a logged event without editing the underlying record.';
'changed_fields'='Stores the field names associated with a recorded change as a text array. It identifies changed attributes without acting as a control for changing those values.';
'details'='Stores a descriptive account of the logged action. The Activity Logs interface displays recorded information and does not use this field to perform the operation.';
'singleton'='Identifies the single configuration row for the phone-pairing policy. Its database check requires the value to be true.';
'max_pairs'='Stores the maximum number of paired attendance phones permitted by the policy. The database check allows values from 2 through 50.';
'updated_by'='Identifies the Auth account responsible for the recorded policy update. It provides attribution for administrator-managed configuration changes.';
'pairing_password_hash'='Stores the hashed pairing password used by the authorized phone-pairing workflow. It is a credential hash rather than a field intended for unrestricted display.';
'pairing_removal_pin_hash'='Stores the hashed PIN used to authorize pairing removal. No arbitrary character maximum is documented because the schema declares text without a length parameter.';
'session_id'='Links a retained scan-event record to its associated phone-pairing session. Its existence in the physical schema does not establish an active scan-event review interface.';
'qr_payload'='Stores the QR payload retained in the scan-event table. The database check requires a length of at least 1 and at most 500 characters; this is an explicit check limit on a text column.';
'token_hash'='Stores the hashed pairing token associated with the phone session. The raw pairing credential is not represented as a public display field.';
'paired_device'='Stores the descriptive label of the paired phone. The registration function trims the label to at most 100 characters, although the text column has no declared character limit.';
'paired_at'='Records when the phone was paired. It may remain empty for a pairing session that has been created but not completed.';
'expires_at'='Records when the pairing session expires. The pairing workflow checks this timestamp before accepting the session.';
'remember_phone'='Indicates whether the pairing was created with the remembered-phone option. The supported workflow uses this flag when determining the duration of a successful pairing.';
'request_id'='Stores the unique request identifier used for duplicate attendance-request protection. A repeated request can return its saved result instead of toggling attendance again.';
'operator_id'='Identifies the Auth account that submitted the attendance request. Duplicate-result retrieval checks the operator associated with the saved request.';
'result'='Stores the saved attendance-processing result as structured JSON. This supports consistent responses when the same attendance request is retried.';
'bucket'='Identifies the grouping used by the private administrator-login attempt tracker. It is a text primary key without a declared maximum character count.';
'window_start'='Records the beginning of the attempt-tracking window. It is used by the authentication-protection workflow rather than by member profile management.';
'attempts'='Stores the number of attempts recorded for the associated tracking window. The integer type has a fixed numeric range rather than a character-length parameter.'
}
$tables=@($d.SelectNodes('//w:body/w:tbl',$n))
$names=@('profiles','members','membership_applications','attendance','products','sales','sale_items','membership_history','activity_logs','mobile_attendance_pairing_policy','mobile_attendance_scan_sessions','mobile_attendance_scan_events','attendance_scan_requests','admin_login_attempts')
$sql=Get-Content -Raw 'supabase\migrations\20261105043517_remote_schema.sql';$count=0
for($ti=0;$ti -lt $names.Count;$ti++){
 $name=$names[$ti];$schema=if($ti -ge 12){'private'}else{'public'};$definition=[regex]::Match($sql,('CREATE TABLE IF NOT EXISTS "'+$schema+'"\."'+$name+'" \(([\s\S]*?)\n\);')).Groups[1].Value
 $rows=@($tables[$ti+5].SelectNodes('w:tr',$n));$head=$rows[0].SelectNodes('w:tc',$n);Put $head[2] 'Length / Precision / Scale';Put $head[4] 'Description and Validation Details'
 foreach($row in $rows|Select-Object -Skip 1){$cells=$row.SelectNodes('w:tc',$n);$col=(Txt $cells[0]).Trim();$decl=[regex]::Match($definition,('(?m)^\s+"'+[regex]::Escape($col)+'"\s+([^\r\n]+)')).Groups[1].Value;if(-not $decl){throw "Missing declaration $name.$col"}
 $purpose=$purposes[$col];if(-not $purpose){throw "Missing field explanation $name.$col"}
 $type=(Txt $cells[1]).Trim();$size='';$notes=''
 if($type -eq 'character varying'){$size=[regex]::Match($decl,'character varying\((\d+)\)').Groups[1].Value;$notes=" The database allows a maximum of $size characters."}
 elseif($type -eq 'numeric'){$m=[regex]::Match($decl,'numeric\((\d+),(\d+)\)');$precision=[int]$m.Groups[1].Value;$scale=[int]$m.Groups[2].Value;$size="$precision,$scale";$notes=" The declaration permits $precision total digits, including $scale decimal places, leaving $($precision-$scale) digits before the decimal point."}
 elseif($type -eq 'text' -or $type -eq 'text[]' -or $type -eq 'jsonb'){$size='Not declared';$notes=' No maximum character count is declared by this column type; any separate check or workflow limit is described independently.'}
 else{$size='N/A';$notes=' This type does not use a user-declared character-length parameter.'}
 $required=if($decl -match 'NOT NULL'){'The column is required at database level.'}else{'The column permits NULL when the value is not applicable or has not yet been recorded.'}
 $fk=[regex]::Match($sql,('ALTER TABLE ONLY "'+$schema+'"\."'+$name+'"\s+ADD CONSTRAINT "[^"]+" FOREIGN KEY \("'+[regex]::Escape($col)+'"\) REFERENCES "([^"]+)"\."([^"]+)"\("([^"]+)"\)([^;]*);'))
 $relationship=if($fk.Success){$rule=$fk.Groups[4].Value.Trim();if(-not $rule){$rule='the default NO ACTION referential rule applies'};" It references $($fk.Groups[1].Value).$($fk.Groups[2].Value).$($fk.Groups[3].Value); $rule."}else{''}
 if($name -eq 'members' -and $col -eq 'status'){$purpose+=' The database permits active, expired, suspended, or inactive.'}
 if($name -eq 'membership_applications' -and $col -eq 'status'){$purpose+=' The database permits pending, approved, or rejected.'}
 if($name -eq 'sales' -and $col -eq 'status'){$purpose+=' The baseline requires a nonempty normalized lowercase value rather than declaring a fixed status enumeration.'}
 if($name -eq 'membership_applications' -and $col -eq 'age'){$purpose+=' The database check permits ages from 1 through 120.'}
 if($name -eq 'membership_applications' -and $col -eq 'email'){$purpose+=' The online registration input currently permits 300 characters, which exceeds the database maximum of 254; the two validation layers are therefore not aligned.'}
 if($col -eq 'qr_payload'){$size='1-500 (CHECK)'}
 if($name -eq 'members' -and $col -eq 'emergency_contact'){$purpose+=' The supported payload contains the contact name, relationship, and contact number.'}
 Put $cells[2] $size;Put $cells[4] ($purpose+$notes+' '+$required+$relationship);$count++
 }
}
foreach($p in $d.SelectNodes('//w:body/w:p',$n)){$text=Txt $p
 if($text -like '*The data dictionary lists application and supporting database tables*'){Put $p '         The data dictionary describes the physical database structures used by IronGrind, including each column’s purpose, PostgreSQL type, declared length or numeric precision and scale, key relationship, required or optional state, and relevant validation. It covers twelve public-schema tables and two private supporting tables from the checked-in migration baseline. The private tables support administrator-login protection and duplicate attendance-request handling; they are distinguished from the twelve public application tables. Managed Supabase Auth internals are not reproduced as application-owned structures.'}
 if($text -like '*Each entry identifies a column*' -or $text -like '*Each table in the database represents a specific entity*'){Put $p '         The Length / Precision / Scale column reports declared storage limits rather than invented form limits. For character varying(n), n is the maximum character count. For numeric(p,s), p is the total digit precision and s is the number of decimal places; for example, numeric(12,2) allows ten digits before and two digits after the decimal point. Not declared indicates a text, text-array, or JSON column without a declared character maximum, while N/A identifies a type such as UUID, date, timestamp, Boolean, or integer that does not use a character-length parameter. Separate database checks and verified form or function limits are explained in the description. A UUID’s conventional displayed format is not a varchar length, and the number of characters used to display a date is not a database date-column length.'}
}
# Add the limits explanation if the current introduction lacks the expected second paragraph.
$hasExplanation=$d.SelectNodes('//w:body/w:p',$n)|Where-Object {(Txt $_) -like '*The Length / Precision / Scale column reports*'}
if(-not $hasExplanation){$intro=$d.SelectNodes('//w:body/w:p',$n)|Where-Object {(Txt $_) -like '*The data dictionary describes the physical database structures*'}|Select-Object -First 1;$p=$intro.CloneNode($true);Put $p '         Length values describe declared database limits. A character varying(n) column permits at most n characters; numeric(p,s) specifies total digits and decimal places. For example, numeric(12,2) permits ten digits before and two after the decimal point. Not declared marks text, text-array, or JSON columns without a declared character maximum. N/A marks UUID, date, timestamp, Boolean, and integer types that do not use a character-length parameter. Explicit database checks and verified input limits are described separately; a form limit is not automatically a database constraint.';[void]$intro.ParentNode.InsertAfter($p,$intro)}
$e.Delete();$e=$z.CreateEntry('word/document.xml');$w=[IO.StreamWriter]::new($e.Open(),[Text.UTF8Encoding]::new($false));$w.Write($d.OuterXml);$w.Dispose()
"Expanded $count field descriptions with database lengths, numeric precision/scale, NULLability, and relationship details."
} finally {$z.Dispose()}
