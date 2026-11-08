$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression
$out=Join-Path (Get-Location) 'Documentations\Chapter 3 Diagrams'
$ink=[Drawing.Brushes]::Black;$pen=[Drawing.Pen]::new([Drawing.Color]::Black,3)
$font=[Drawing.Font]::new('Arial',22);$bold=[Drawing.Font]::new('Arial',24,[Drawing.FontStyle]::Bold);$small=[Drawing.Font]::new('Arial',17);$flowFont=[Drawing.Font]::new('Arial',15)
function StartFigure($title,$height){$script:bmp=[Drawing.Bitmap]::new(1800,$height);$script:g=[Drawing.Graphics]::FromImage($bmp);$g.Clear([Drawing.Color]::White);$g.SmoothingMode='AntiAlias';$g.TextRenderingHint='AntiAliasGridFit';$g.DrawString($title,[Drawing.Font]::new('Arial',30,[Drawing.FontStyle]::Bold),$ink,45,30)}
function Label($text,$x,$y,$w,$h,$f=$font){$g.DrawString($text,$f,$ink,[Drawing.RectangleF]::new($x,$y,$w,$h))}
function Entity($x,$y,$w,$h,$name){$g.DrawRectangle($pen,$x,$y,$w,$h);Label $name ($x+20) ($y+25) ($w-40) ($h-40) $bold}
function Process($x,$y,$w,$h,$number,$name){$shape=[Drawing.Drawing2D.GraphicsPath]::new();$shape.AddArc($x,$y,36,36,180,90);$shape.AddArc($x+$w-36,$y,36,36,270,90);$shape.AddArc($x+$w-36,$y+$h-36,36,36,0,90);$shape.AddArc($x,$y+$h-36,36,36,90,90);$shape.CloseFigure();$g.DrawPath($pen,$shape);$shape.Dispose();$g.DrawLine($pen,$x,$y+65,$x+$w,$y+65);Label $number ($x+20) ($y+15) ($w-40) 45 $bold;Label $name ($x+30) ($y+100) ($w-60) ($h-120) $bold}
function Store($x,$y,$w,$h,$id,$name){$g.DrawLine($pen,$x,$y,$x+$w,$y);$g.DrawLine($pen,$x,$y+$h,$x+$w,$y+$h);$g.DrawLine($pen,$x,$y,$x,$y+$h);$g.DrawLine($pen,$x+83,$y,$x+83,$y+$h);Label $id ($x+8) ($y+22) 75 40 $small;Label $name ($x+98) ($y+12) ($w-105) ($h-12) $small}
function Flow($x1,$x2,$y,$text,$above=$true){$ap=[Drawing.Pen]::new([Drawing.Color]::Black,3);$ap.CustomEndCap=[Drawing.Drawing2D.AdjustableArrowCap]::new(5,6);$g.DrawLine($ap,$x1,$y,$x2,$y);$ap.Dispose();$x=[Math]::Min($x1,$x2);$w=[Math]::Abs($x2-$x1);$ly=if($above){$y-48}else{$y+8};Label $text ($x+10) $ly ($w-20) 48 $flowFont}
function StoreFlow($x1,$x2,$y,$text){$ap=[Drawing.Pen]::new([Drawing.Color]::Black,3);$ap.CustomEndCap=[Drawing.Drawing2D.AdjustableArrowCap]::new(5,6);$g.DrawLine($ap,$x1,$y,$x2,$y);$ap.Dispose();$f=[Drawing.Font]::new('Arial',13);Label $text 1070 ($y-37) 285 36 $f;$f.Dispose()}
function SaveFigure($name){$bmp.Save((Join-Path $out $name),[Drawing.Imaging.ImageFormat]::Png);$g.Dispose();$bmp.Dispose()}
StartFigure 'Figure 2. Context diagram - Gane-Sarson' 1500
Label 'One system process; external entities and named data flows. Internal stores are omitted.' 45 100 1700 70 $small
Process 1130 240 600 1030 '0' 'IronGrind Membership and Operations Management System'
$actors=@('Member / Applicant','Administrator','Authorized Staff')
$inputs=@('Credentials; application, renewal and profile data','Review decisions; membership/stock changes; profile queries; staff controls; report queries','Credentials; counter details; request decisions; QR scans; sales')
$outputs=@('Access result; own membership, status, visits and catalog','Access result; operational records, staff states, logs and reports','Access result; pending requests; review, counter and scan results; own sales')
for($i=0;$i -lt 3;$i++){$y=240+$i*390;Entity 50 $y 420 250 $actors[$i];Flow 470 1130 ($y+95) $inputs[$i];Flow 1130 470 ($y+190) $outputs[$i] $false}
Label 'Walk-in customers transact through an operator. Transaction records do not represent receipts issued to customers.' 50 1400 1700 80 $small
SaveFigure '02-context.png'
# Stores use stable identifiers across all continuation panels. The pairs are write/read data flows; blank means no arrow in that direction.
$processes=@(
 @{Id='1.0';Name='Authenticate and authorize';Actor='Member / Applicant; Administrator; Authorized Staff';Input='Credentials / session details';Output='Access result and permitted role';Stores=@(@('D0','Auth accounts','Account / session data','Identity / session state'),@('D1','profiles','','Role and active status'),@('D14','private account sessions','Selected session scope','Session ownership'),@('D9','activity_logs','Session event',''))},
 @{Id='2.0';Name='Review online applications';Actor='Applicant; Administrator; Authorized Staff';Input='Registration details / operator decision';Output='Application status / approved member';Stores=@(@('D2','membership_applications','Application / review status','Submitted application'),@('D3','members','Approved member','Linked member record'),@('D0','Auth accounts','Applicant account',''),@('D1','profiles','Applicant profile','Account record'),@('D6','sales','Membership transaction',''),@('D7','sale_items','Membership charge',''),@('D9','activity_logs','Review / change event',''))},
 @{Id='3.0';Name='User management';Actor='Administrator; Authorized Staff; Member';Input='Walk-in registration / renewal / active-plan change';Output='Limited lookup and counter confirmation';Stores=@(@('D0','Auth accounts','New member / staff account',''),@('D1','profiles','Own name / account provisioning','Own / permitted account'),@('D3','members','Own edits / membership operations','Own record / limited lookup'),@('D8','membership_history','Renewal / plan-change event',''),@('D6','sales','Membership transaction',''),@('D7','sale_items','Membership charge',''),@('D9','activity_logs','Operator change event',''))},
 @{Id='4.0';Name='Review online renewals';Actor='Member; Administrator; Authorized Staff';Input='Renewal request / operator decision';Output='Request status / new membership dates';Stores=@(@('D2','membership_applications','Renewal / review status','Renewal request'),@('D3','members','Renewed membership','Current dates and status'),@('D8','membership_history','Renewal event',''),@('D6','sales','Membership transaction',''),@('D7','sale_items','Membership charge',''),@('D9','activity_logs','Review / renewal event',''))},
 @{Id='5.0';Name='Record and view attendance';Actor='Administrator; Authorized Staff; Member';Input='Operator QR / own attendance query';Output='Scan result / permitted attendance history';Stores=@(@('D3','members','','Member and status'),@('D4','attendance','Visit and operator timestamps','Open visit'),@('D10','pairing policy','Admin pairing settings','Phone-pairing policy'),@('D11','pairing sessions','Paired-device details','Paired phone authorization'),@('D13','private scan requests','Processed scan result','Previous request result'),@('D9','activity_logs','Attendance event',''))},
 @{Id='6.0';Name='Manage inventory and read catalog';Actor='Administrator; Member; Authorized Staff';Input='Admin product update / permitted catalog query';Output='Catalog / stock and low-stock information';Stores=@(@('D5','products','Admin product / stock update','Permitted catalog / stock'),@('D9','activity_logs','Product mutation event',''))},
 @{Id='7.0';Name='Record product sale';Actor='Administrator; Authorized Staff';Input='Products, quantities, customer and payment details';Output='Saved transaction / own staff sales';Stores=@(@('D5','products','Deducted stock','Products, units and prices'),@('D6','sales','Product transaction','Permitted transaction records'),@('D7','sale_items','Item quantities and amounts','Permitted line items'),@('D9','activity_logs','Sale event',''))},
 @{Id='8.0';Name='Generate reports';Actor='Administrator';Input='Report type / period';Output='Report preview / PDF / ZIP';Stores=@(@('D2-D8','Operational stores','','Report source records'))},
 @{Id='9.0';Name='Activity logs';Actor='Administrator';Input='Activity filters / page request';Output='Filtered recorded actions';Stores=@(@('D9','activity_logs','','Filtered activity records'))}
)
$actorFlows=@{
'1.0'=@(@('Member / Applicant','Credentials / session','Own access result'),@('Administrator','Credentials / session','Administrator access result'),@('Authorized Staff','Credentials / session','Staff access result'));
'2.0'=@(@('Applicant','Registration details','Own application status'),@('Administrator','Review decision','Pending application / result'),@('Authorized Staff','Approve / reject request','Limited pending request / result'));
'3.0'=@(@('Administrator','Profile query / counter or staff controls','Read-only profiles / operation states'),@('Authorized Staff','Walk-in / renewal / active-plan change','Limited lookup / counter result'),@('Member','Own profile query / personal changes','Own member / profile details'));
'4.0'=@(@('Member','Own renewal request','Own renewal status'),@('Administrator','Renewal review decision','Pending request / result'),@('Authorized Staff','Approve / reject renewal','Limited pending request / result'));
'5.0'=@(@('Administrator','QR / attendance / pairing controls','Visits / pairing states / results'),@('Authorized Staff','QR / permitted log query','Permitted visits / scan result'),@('Member','Own attendance query','Own attendance history'));
'6.0'=@(@('Administrator','Product / stock changes','Catalog, stock and alerts'),@('Authorized Staff','Sales catalog query','Permitted product catalog'),@('Member','Active catalog query','Active product catalog'));
'7.0'=@(@('Administrator','Product sale / transaction query','Transaction records / result'),@('Authorized Staff','Product sale / own sales query','Sale result / own sales only'));
'8.0'=@(@('Administrator','Report type / selected period','Report preview / PDF / ZIP'));
'9.0'=@(@('Administrator','Action / area / actor / date filters','Filtered recorded activity'))
}
foreach($process in $processes){if($process.Stores[0] -is [string]){$process.Stores=,@($process.Stores)}}
$processes|ConvertTo-Json -Depth 8|Set-Content (Join-Path $out '03-gane-sarson-flows.json') -Encoding UTF8
for($panel=0;$panel -lt 5;$panel++){
 StartFigure "Figure 3$([char](97+$panel)). Level 1 DFD - Gane-Sarson" 2050
 Label 'Rectangles: external entities. Numbered rounded boxes: processes. Open-ended divided boxes: data stores.' 45 100 1700 80 $small
 for($row=0;$row -lt 2;$row++){
  $index=$panel*2+$row;if($index -ge $processes.Count){continue};$p=$processes[$index];$y=210+$row*850
  Process 670 $y 390 735 $p.Id $p.Name
  $associations=$actorFlows[$p.Id]
  if($associations[0] -is [string]){$associations=,@($associations)}
  for($ai=0;$ai -lt $associations.Count;$ai++){$a=$associations[$ai];$ay=$y+90+$ai*220;Entity 40 $ay 350 175 $a[0];Flow 390 670 ($ay+60) $a[1];Flow 670 390 ($ay+115) $a[2] $false}
  for($si=0;$si -lt $p.Stores.Count;$si++){$s=$p.Stores[$si];$sy=$y+$si*105;Store 1370 $sy 400 85 $s[0] $s[1];if($s[2]){StoreFlow 1060 1370 ($sy+27) $s[2]};if($s[3]){StoreFlow 1370 1060 ($sy+65) $s[3]}}
 }
 Label 'Each actor has its own labeled flows. Admin views member profiles; only members edit their own profiles. Staff have no profile access. New walk-in account rows are created by the server service. Online review: authorized staff and admin. Inventory maintenance: admin only.' 45 1940 1710 100 $small
 SaveFigure "03-data-flow-$($panel+1).png"
}
# Keep the familiar standalone filename as the first continuation panel.
[IO.File]::Copy((Join-Path $out '03-data-flow-1.png'),(Join-Path $out '03-data-flow.png'),$true)
# Update Word images and insert the additional DFD continuation panels once.
& (Join-Path $PSScriptRoot '../refresh-review-diagrams.ps1')