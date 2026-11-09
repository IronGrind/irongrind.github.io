$ErrorActionPreference='Stop'
# Context/DFD output from this older generator is superseded by Chapter 3 Diagrams/gane-sarson.ps1.
# Run the dedicated Gane-Sarson generator afterward to refresh those figures and their Word embeddings.
Add-Type -AssemblyName System.Drawing
$out=Join-Path (Get-Location) 'Documentations\Chapter 3 Diagrams'
[void][IO.Directory]::CreateDirectory($out)
$script:font=[Drawing.Font]::new('Arial',23)
$script:bold=[Drawing.Font]::new('Arial',21,[Drawing.FontStyle]::Bold)
$script:small=[Drawing.Font]::new('Arial',20)
$script:ink=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(25,40,60))
$script:pen=[Drawing.Pen]::new([Drawing.Color]::FromArgb(65,85,110),3)
function Canvas($title,$subtitle,$height=2250) {
 $script:bmp=[Drawing.Bitmap]::new(1800,$height);$script:g=[Drawing.Graphics]::FromImage($bmp);$g.Clear([Drawing.Color]::White);$g.SmoothingMode='AntiAlias';$g.TextRenderingHint='AntiAliasGridFit'
 $g.DrawString($title,[Drawing.Font]::new('Arial',34,[Drawing.FontStyle]::Bold),$ink,60,35)
 $g.DrawString($subtitle,$small,$ink,[Drawing.RectangleF]::new(60,100,1680,120))
}
function Box($x,$y,$w,$h,$title,$text,$ellipse=$false) {
 $brush=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(240,245,250));$rect=[Drawing.RectangleF]::new($x,$y,$w,$h)
 if($ellipse){$g.FillEllipse($brush,$rect);$g.DrawEllipse($pen,$rect)}elseif($title -match '^\d+\.\d|^0\.'){
 $shape=[Drawing.Drawing2D.GraphicsPath]::new();$shape.AddArc($x,$y,30,30,180,90);$shape.AddArc($x+$w-30,$y,30,30,270,90);$shape.AddArc($x+$w-30,$y+$h-30,30,30,0,90);$shape.AddArc($x,$y+$h-30,30,30,90,90);$shape.CloseFigure();$g.FillPath($brush,$shape);$g.DrawPath($pen,$shape);$shape.Dispose()
 }elseif($title -eq 'Read / write stores'){$g.FillRectangle($brush,$rect);$g.DrawLine($pen,$x,$y,$x+$w,$y);$g.DrawLine($pen,$x,$y+$h,$x+$w,$y+$h);$g.DrawLine($pen,$x,$y,$x,$y+$h)}else{$g.FillRectangle($brush,$rect);$g.DrawRectangle($pen,$x,$y,$w,$h)}
 $g.DrawString($title,$bold,$ink,[Drawing.RectangleF]::new($x+18,$y+14,$w-36,70))
 $g.DrawString($text,$font,$ink,[Drawing.RectangleF]::new($x+18,$y+80,$w-36,$h-90));$brush.Dispose()
}
function Arrow($x1,$y1,$x2,$y2,$label='') {
 $ap=[Drawing.Pen]::new([Drawing.Color]::FromArgb(65,85,110),3);$ap.CustomEndCap=[Drawing.Drawing2D.AdjustableArrowCap]::new(6,7);$g.DrawLine($ap,$x1,$y1,$x2,$y2);$ap.Dispose()
 if($label){$g.DrawString($label,$small,$ink,[Drawing.RectangleF]::new([Math]::Min($x1,$x2)+5,[Math]::Min($y1,$y2)-35,[Math]::Max(160,[Math]::Abs($x2-$x1)-10),75))}
}
function Finish($file){$bmp.Save((Join-Path $out $file),[Drawing.Imaging.ImageFormat]::Png);$g.Dispose();$bmp.Dispose()}
Canvas 'Figure 2. Context diagram' 'Three external actors exchange data with process 0. Internal databases and services are inside the system boundary.' 1600
Box 1100 220 630 1110 '0. IronGrind' "Membership and operations`n`nWeb interface`nSupabase Auth`nDatabase + authorized functions`n`nRole-checked data access"
Box 60 220 600 250 'Member / Applicant' "Credentials, applications, renewal requests, profile changes"
Box 60 650 600 250 'Administrator' "Review decisions, operational updates, account controls, report queries"
Box 60 1080 600 250 'Authorized Staff' "Walk-in registration, direct renewal / plan change, QR scans, product sales"
$inputs=@('Account / membership inputs','Review / operational inputs','Counter / attendance inputs')
$outputs=@('Own status, membership, visits, catalog','Records, account states, logs, reports','Confirmations and permitted records')
for($i=0;$i -lt 3;$i++){$y=220+$i*430;Arrow 660 ($y+90) 1100 ($y+90);Arrow 1100 ($y+185) 660 ($y+185);$g.DrawString($inputs[$i],$small,$ink,[Drawing.RectangleF]::new(680,$y+20,395,70));$g.DrawString($outputs[$i],$small,$ink,[Drawing.RectangleF]::new(680,$y+195,395,100))}
$g.DrawString('Walk-in customers transact through an operator; they are not direct software actors. No receipt is issued.',$font,$ink,[Drawing.RectangleF]::new(100,1470,1600,100))
Finish '02-context.png'
$rows=@(
@('All account holders','Credentials / session request','1.0 Authenticate and authorize','Auth users; D1 profiles','Identity, role, active-account result'),
@('Applicant; Administrator','Application / review decision','2.0 Review online applications','D2 applications; D3 members; D6 sales; D7 sale_items','Application status; member + paid transaction'),
@('Administrator; Staff','Walk-in registration / direct membership change','3.0 Manage memberships','D3 members; D8 history; D6 sales; D7 sale_items; Auth users','Member record; dates; transaction confirmation'),
@('Member; Administrator','Renewal request / admin decision','4.0 Review online renewals','D2 applications; D3 members; D8 history; D6 sales; D7 sale_items','Review status; updated membership and transaction'),
@('Administrator; Staff','Member QR / operator session','5.0 Record QR attendance','D3 members; D4 attendance; D10 phone pairing','Check-in / check-out confirmation'),
@('Administrator; Member / Staff','Product / stock update; catalog query','6.0 Manage inventory and catalog','D5 products','Admin: stock updates; other roles: permitted catalog'),
@('Administrator; Staff','Product selection; quantity; payment record','7.0 Record product sale','D3 members (optional); D5 products; D6 sales; D7 sale_items','Saved sale; stock deduction; no issued receipt'),
@('Administrator','Report query / activity filters','8.0 Reports and administration','Auth users; D1-D9; D10 for phone administration','Reports; staff controls; phone settings; activity records')
)
Canvas 'Figure 3. Level 1 data-flow diagram' 'Read each lane as actor input -> numbered process -> data stores. Return arrows represent retrieved data. Auth is managed by Supabase Auth.' 2580
for($i=0;$i -lt $rows.Count;$i++){$y=220+$i*265;$r=$rows[$i];Box 45 $y 430 205 $r[0] $r[1];Box 650 $y 490 205 $r[2] $r[4];Box 1310 $y 445 205 'Read / write stores' $r[3];Arrow 475 ($y+65) 650 ($y+65);Arrow 650 ($y+155) 475 ($y+155);Arrow 1140 ($y+65) 1310 ($y+65);Arrow 1310 ($y+155) 1140 ($y+155);$flowFont=[Drawing.Font]::new('Arial',14);$g.DrawString('Input data',$flowFont,$ink,485,$y+30);$g.DrawString('Results',$flowFont,$ink,485,$y+165);$g.DrawString('Query / update',$flowFont,$ink,1145,$y+30);$g.DrawString('Stored data',$flowFont,$ink,1145,$y+165);$flowFont.Dispose()}
$g.DrawString("D1 profiles; D2 membership_applications; D3 members; D4 attendance; D5 products; D6 sales; D7 sale_items; D8 membership_history; D9 activity_logs; D10 mobile pairing tables.`nMutation triggers / logging functions also write D9. Staff and phone operations use authorized functions. Staff and administrators review online requests; only administrators maintain inventory.",$small,$ink,[Drawing.RectangleF]::new(60,2360,1680,200))
Finish '03-data-flow.png'
Canvas 'Figure 4. Use-case diagram' 'Actor associations are grouped by role inside the IronGrind boundary. Repeated shared use cases represent the same function.' 2400
$roles=@(
@('Member / Applicant',@('Authenticate account','Submit registration application','View application status','View own membership and QR','View own attendance','Update own profile','Request membership renewal','Browse active catalog')),
@('Authorized Staff',@('Authenticate account','Record QR attendance','View permitted attendance','Register walk-in member','Direct membership renewal','Change active member plan','Review online requests','Record product sale','View own product sales')),
@('Administrator',@('Authenticate account','Review online applications / renewals','View member profiles','Register walk-in / renew / change plan','Record QR attendance','Record product sale','Manage products and stock','Manage staff accounts','Manage phone pairings','Generate reports','View activity logs'))
)
$g.DrawRectangle($pen,35,445,1730,1825)
for($col=0;$col -lt 3;$col++){$x=65+$col*575;$role=$roles[$col];$g.DrawString($role[0],$bold,$ink,$x+35,225);$g.DrawEllipse($pen,$x+245,285,45,45);$g.DrawLine($pen,$x+267,330,$x+267,385);$g.DrawLine($pen,$x+230,350,$x+304,350);$g.DrawLine($pen,$x+267,385,$x+240,415);$g.DrawLine($pen,$x+267,385,$x+295,415)
for($i=0;$i -lt $role[1].Count;$i++){$y=470+$i*155;$g.DrawEllipse($pen,$x+25,$y,475,135);$g.DrawString($role[1][$i],$font,$ink,[Drawing.RectangleF]::new($x+65,$y+30,400,100));$g.DrawLine($pen,$x+10,350,$x+10,$y+67);$g.DrawLine($pen,$x+10,$y+67,$x+25,$y+67)};$g.DrawLine($pen,$x+10,350,$x+230,350)}
$g.DrawString('Admin views member profiles; members alone edit their own profiles. Staff have no profile access or editing, inventory-maintenance, or administrator-report permissions.',$small,$ink,[Drawing.RectangleF]::new(75,2300,1650,90))
Finish '04-use-cases.png'
Canvas 'Figure 20. Staff workflow and access limits' 'After active-staff authentication, the staff portal offers four operational paths. Payment is received at the gym; IronGrind records the transaction.' 2260
Box 65 245 470 175 '1. Sign in' 'Staff enters assigned username and password.'
Box 665 245 470 175 '2. Validate account' 'Auth verifies credentials; the profile must be active staff.'
Box 1265 245 470 175 '3. Staff workspace' 'Attendance, counter work, request review, and sales.'
Arrow 535 330 665 330;Arrow 1135 330 1265 330
$cardPen=[Drawing.Pen]::new([Drawing.Color]::FromArgb(65,85,110),3)
function StaffCard($x,$y,$title,$lines){$r=[Drawing.RectangleF]::new($x,$y,820,680);$b=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(247,249,252));$g.FillRectangle($b,$r);$g.DrawRectangle($cardPen,$x,$y,820,680);$g.DrawString($title,$bold,$ink,[Drawing.RectangleF]::new($x+24,$y+20,770,60));$g.DrawString(($lines -join "`n`n"),$font,$ink,[Drawing.RectangleF]::new($x+28,$y+105,760,570));$b.Dispose()}
StaffCard 65 510 'A. Record QR attendance' @('1. Open Attendance and scan the member QR. A phone must already be paired by an administrator; pairing does not replace staff sign-in.','2. The service checks the active operator, member, QR/session, and prior open visit.','3. No open visit: save check-in. Open visit: save check-out. Store each event time and responsible operator; return the result.','4. Duplicate-request protection prevents a retried scan from recording the same request twice. Staff can read only permitted attendance records.')
StaffCard 915 510 'B. Review online requests' @('1. Load pending registration and renewal summaries; staff do not open member profiles.','2. Confirm that payment was received at the gym, then choose approve or reject.','3. The server checks the active staff role, locks the pending request, and blocks repeat review.','4. Rejection saves its status and reviewer. Approval creates the member from a registration or extends a renewal, records the membership transaction and applicable history, and saves the decision.')
StaffCard 65 1200 'C. Counter membership service' @('1. Search using the limited details returned for the counter operation; this is not a member-profile page.','2. For a walk-in, submit separate name fields, contact and membership details. The server service creates the Auth account, profile, member, and transaction records.','3. For a direct renewal or active-plan change, select the member and plan. The authorized function updates membership dates and values and records history and the transaction.','4. Staff cannot view or edit existing member personal profiles.')
StaffCard 915 1200 'D. Record and review product sales' @('1. Read the permitted catalog; enter customer name, product, quantity, and sale unit.','2. The server validates product status, supported units, and stock, calculates the amount, saves the sale and line item, and deducts stock.','3. The transaction is recorded as paid in person. IronGrind does not issue a customer receipt.','4. Staff can review their own product sales; inventory maintenance is administrator-only.')
$g.DrawString('Staff role boundary: no member-profile viewing or editing, product/stock maintenance, staff-account administration, phone-pairing controls, administrator reports, or activity-log viewer.',[Drawing.Font]::new('Arial',18,[Drawing.FontStyle]::Bold),$ink,[Drawing.RectangleF]::new(65,1930,1670,190))
$cardPen.Dispose();Finish '20-staff-operations.png'
# Extract the physical schema and its declared foreign keys from the current baseline.
$sql=Get-Content -Raw 'supabase\migrations\20261105043517_remote_schema.sql'
$sql=$sql.Replace('    "paired_device" "text",','    "paired_device" "text",'+"`n"+'    "paired_device_id" "uuid",')
$sql+=@'

CREATE TABLE IF NOT EXISTS "private"."account_sessions" (
    "user_id" "uuid" NOT NULL,
    "session_id" "uuid" NOT NULL,
    "session_created_at" timestamp with time zone NOT NULL,
    "session_scope" "text" DEFAULT 'dashboard'::text NOT NULL
);
ALTER TABLE ONLY "private"."account_sessions"
    ADD CONSTRAINT "account_sessions_pkey" PRIMARY KEY ("user_id", "session_scope");
ALTER TABLE ONLY "private"."account_sessions"
    ADD CONSTRAINT "account_sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;
'@
$fks=@([regex]::Matches($sql,'ALTER TABLE ONLY "([^"]+)"\."([^"]+)"\s+ADD CONSTRAINT "([^"]+)" FOREIGN KEY \("([^"]+)"\) REFERENCES "([^"]+)"\."([^"]+)"\("([^"]+)"\)([^;]*);')|ForEach-Object { [pscustomobject]@{Child="$($_.Groups[1].Value).$($_.Groups[2].Value)";Field=$_.Groups[4].Value;Parent="$($_.Groups[5].Value).$($_.Groups[6].Value)";ParentField=$_.Groups[7].Value;Rule=$_.Groups[8].Value.Trim()} })
$fks|ConvertTo-Json -Depth 5|Set-Content (Join-Path $out 'schema-foreign-keys.json') -Encoding UTF8
$mmd=[Collections.Generic.List[string]]::new();$mmd.Add('erDiagram')
foreach($fk in $fks){$parent=$fk.Parent.Replace('.','_');$child=$fk.Child.Replace('.','_');$optional=($sql -notmatch ('"'+[regex]::Escape(($fk.Child -split '\.')[1])+'" \([\s\S]*?"'+[regex]::Escape($fk.Field)+'" "uuid" NOT NULL'))
 $tableName=($fk.Child -split '\.')[1];$definition=[regex]::Match($sql,('CREATE TABLE IF NOT EXISTS "[^" ]+"\."'+[regex]::Escape($tableName)+'" \(([\s\S]*?)\n\);')).Groups[1].Value
 $required=$definition -match ('"'+[regex]::Escape($fk.Field)+'" "uuid" NOT NULL')
 $card=if($fk.Child -eq 'public.profiles'){'||--o|'}elseif($fk.Child -eq 'public.members' -and $fk.Field -in @('auth_user_id','application_id')){'|o--o|'}elseif($required){'||--o{'}else{'|o--o{'}
 $mmd.Add("    $parent $card $child : $($fk.Field)")
}
$mmd.Add('    auth_users {');$mmd.Add('        uuid id PK');$mmd.Add('    }')
foreach($definition in [regex]::Matches($sql,'CREATE TABLE IF NOT EXISTS "(public|private)"\."([^"]+)" \(([\s\S]*?)\n\);')){
 $schema=$definition.Groups[1].Value;$table=$definition.Groups[2].Value;$entity=$schema+'_'+$table;$mmd.Add("    $entity {")
 foreach($line in ($definition.Groups[3].Value -split "`n")){$column=[regex]::Match($line,'^\s+"([^"]+)"\s+(.+?)(?:,)?\s*$');if(-not $column.Success){continue};$name=$column.Groups[1].Value;$type=([regex]::Split($column.Groups[2].Value,'\s+(?:DEFAULT|NOT NULL|GENERATED)\b'))[0].Trim().TrimEnd(',').Replace('"','');$type=$type -replace '\([^)]*\)','' -replace ' ','_';$keys=@();if($sql -match ('ALTER TABLE ONLY "'+$schema+'"\."'+$table+'"\s+ADD CONSTRAINT "[^"]+" PRIMARY KEY \("'+$name+'"\)')){$keys+='PK'};if(@($fks|Where-Object {$_.Child -eq "$schema.$table" -and $_.Field -eq $name}).Count){$keys+='FK'};$suffix=if($keys.Count){' '+($keys -join ',')}else{''};$mmd.Add("        $type $name$suffix")};$mmd.Add('    }')
}
$insideSessions=$false
for($mi=0;$mi -lt $mmd.Count;$mi++){
 if($mmd[$mi] -eq '    private_account_sessions {'){$insideSessions=$true;continue}
 if($insideSessions -and $mmd[$mi] -eq '    }'){$insideSessions=$false}
 if($insideSessions){$mmd[$mi]=$mmd[$mi].Replace('uuid user_id FK','uuid user_id PK,FK').Replace('text session_scope','text session_scope PK')}
}
$mmd|Set-Content (Join-Path $out '05-erd.mmd') -Encoding UTF8
for($page=0;$page -lt 3;$page++){
 $subset=@($fks|Select-Object -Skip ($page*7) -First 7)
 Canvas "Figure 5$([char](97+$page)). Physical ERD relationships" 'Each row is an ER relationship. Repeated entity boxes denote the same table. Child FK NULLability and deletion actions follow the baseline and session migrations.' 2180
 for($i=0;$i -lt $subset.Count;$i++){$fk=$subset[$i];$y=220+$i*250
 $tableName=($fk.Child -split '\.')[1];$match=[regex]::Match($sql,('CREATE TABLE IF NOT EXISTS "[^" ]+"\."'+[regex]::Escape($tableName)+'" \(([\s\S]*?)\n\);'));$required=$match.Groups[1].Value -match ('"'+[regex]::Escape($fk.Field)+'" "uuid" NOT NULL')
 $parentCount=if($required){'1'}else{'0..1'};$childCount=if($fk.Child -eq 'private.account_sessions'){'0..2'}elseif($fk.Child -eq 'public.profiles' -or ($fk.Child -eq 'public.members' -and $fk.Field -in @('auth_user_id','application_id'))){'0..1'}else{'0..*'}
 Box 55 $y 575 185 $fk.Parent "PK: $($fk.ParentField)";Box 1120 $y 625 185 $fk.Child "FK: $($fk.Field)"
 Arrow 630 ($y+95) 1120 ($y+95) "$parentCount                  $childCount"
 $g.DrawString($fk.Rule,$small,$ink,[Drawing.RectangleF]::new(655,$y+120,440,80))
 }
 $g.DrawString('Cardinality labels: parent records per child (left); child records per parent (right). FK relationships only; activity_logs.actor_id is a recorded identifier without a declared FK. Auth internals are outside this application ERD.',$small,$ink,[Drawing.RectangleF]::new(60,2020,1680,140))
 Finish "05-erd-$($page+1).png"
}
'Generated context, DFD, role use cases, and three physical ERD panels.'
