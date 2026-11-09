$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$replacements=[ordered]@{
 'a server-side Edge Function that checks the administrator role'='a server-side Edge Function that checks for an active administrator or staff role and restricts staff to permitted registration operations'
 'only after administrator approval'='only after approval by authorized staff or the administrator'
 'Applicants submit registration requests; administrators review and approve or reject them.'='Applicants submit registration requests; authorized staff and administrators review and approve or reject them.'
 'Members request renewal; administrators review online requests.'='Members request renewal; authorized staff and administrators review online requests.'
 'The Admin can view the submitted applications and make a decision to either approve or reject them based on the gym''s criteria.'='Authorized staff and the administrator review pending application summaries and approve or reject requests according to the gym''s criteria, confirming in-person payment before approval.'
 'reviewed by the admin before it takes effect'='reviewed by authorized staff or the administrator before it takes effect'
 'online for admin review'='online for authorized staff or administrator review'
 'only after admin approval'='only after authorized staff or administrator approval'
 'allow administrators to review, approve, or reject applications'='allow authorized staff and administrators to review, approve, or reject applications'
 'subject to administrator approval'='subject to approval by authorized staff or the administrator'
 'awaiting admin review'='awaiting review by authorized staff or the administrator'
 'the admin who reviewed it (reviewed_by)'='the staff member or administrator who reviewed it (reviewed_by)'
 'the profile of the administrator who reviewed the application'='the profile of the staff member or administrator who reviewed the application'
 'when the administrator reviewed the request'='when the staff member or administrator reviewed the request'
 'Submissions go to the admin for review.'='Submissions go to authorized staff or the administrator for review.'
 'online applications subject to administrator review'='online applications subject to authorized staff or administrator review'
 'Online registration and renewal requests are reviewed by administrators.'='Authorized staff and administrators can approve or reject online registration and renewal requests.'
 'and do not inherit administrator access to online application review, inventory maintenance'='and do not inherit administrator access to inventory maintenance'
 'Administrator approval links an online application'='Approval by an authorized staff member or administrator links an online application'
 'product sales, and their own product-sale records.'='product sales, their own product-sale records, and online registration and renewal request approval.'
 'direct renewal and plan-change inputs, and product sales entries'='direct renewal and plan-change inputs, online request decisions, and product sales entries'
 'Authorized staff use counter forms for walk-in registration, direct renewal, active-member plan change, and product purchases.'='Authorized staff use counter forms for walk-in registration, direct renewal, active-member plan change, and product purchases, and use Requests approval for online registration and renewal decisions.'
 'Staff Operations. Figure 20 summarizes staff attendance and counter functions and distinguishes administrator-only controls.'='Staff Operations. Figure 20 summarizes staff attendance, counter registration, direct subscription renewal, active-member plan change, online registration and renewal request approval, product sales, and own-sales review, while distinguishing administrator-only controls.'
 'administrator-approved membership applications and renewals'='membership applications and renewals approved by authorized staff or the administrator'
 'Online applications and renewal requests remained subject to administrator review.'='Authorized staff and the administrator could approve or reject online registration applications and renewal requests after verifying in-person payment for approvals.'
 'Direct counter processing is separate from approval of an online application or renewal request, which is currently assigned to the administrator.'='Direct counter processing is separate from online request review. Authorized staff and the administrator can also approve or reject submitted registration applications and renewal requests through Requests approval, without granting staff access to existing member personal profiles.'
 'process direct membership renewals and plan changes, and record in-person product sales within the access allowed by the system.'='process direct membership renewals and plan changes, approve or reject online registration and renewal requests, and record in-person product sales within the access allowed by the system.'
 'Staff cannot view or edit member profiles, review online applications, maintain inventory'='Staff can approve or reject online applications and renewal requests using limited request information. They cannot view or edit member profiles, maintain inventory'
 'Online review and inventory maintenance are administrator-only.'='Online request review is available to authorized staff and the administrator; inventory maintenance is administrator-only.'
 'Administrator use cases cover online review, the permitted operational controls'='Both staff and administrator use cases include online registration and renewal review. Administrator use cases additionally cover the permitted operational controls'
 'are distinct from the administrator-only review of submitted online requests.'='are distinct from online request review, which is also available to authorized staff and the administrator.'
 'administrator-only review'='staff and administrator review'
 'Only administrators review online requests or maintain inventory.'='Staff and administrators review online requests; only administrators maintain inventory.'
 'online applications and renewals are reviewed only by the administrator'='online applications and renewals are reviewed by authorized staff or the administrator'
}
foreach($chapter in 1,2,3){
 $path=Join-Path (Split-Path $PSScriptRoot -Parent) "Chapter $chapter.docx"
 $zip=[IO.Compression.ZipArchive]::new([IO.File]::Open($path,'Open','ReadWrite'),[IO.Compression.ZipArchiveMode]::Update)
 try{
  $entry=$zip.GetEntry('word/document.xml');$reader=[IO.StreamReader]::new($entry.Open());$doc=[Xml.XmlDocument]::new();$doc.PreserveWhitespace=$true;$doc.LoadXml($reader.ReadToEnd());$reader.Dispose()
  $ns=[Xml.XmlNamespaceManager]::new($doc.NameTable);$ns.AddNamespace('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main')
  foreach($p in @($doc.SelectNodes('//w:p',$ns))){
   $texts=$p.SelectNodes('.//w:t',$ns);if(-not $texts.Count){continue};$old=($texts|ForEach-Object InnerText)-join '';$new=$old
   foreach($key in $replacements.Keys){$new=$new.Replace($key,$replacements[$key])}
   if($chapter -eq 3 -and $new.Trim().StartsWith('Supabase Auth verifies credentials.') -and $new -notmatch 'strength indicator'){
    $new+=' New member registration uses a visible password-strength indicator and blocks passwords that do not meet the Strong requirements: 8 to 128 characters, uppercase and lowercase letters, at least one digit, and at least one symbol. Confirmation must match the selected password. Auth and the member-creation service enforce the password policy on the server; staff-account creation uses a minimum of 12 characters with the same character requirements. Existing sign-in forms continue to accept account credentials without imposing registration validation on login.'
   }
   if($chapter -eq 3 -and $new.Trim().StartsWith('Staff use cases are limited') -and $new -notmatch 'atomic review'){
    $new+=' The Requests approval tab presents pending registration and renewal requests using only the applicant name, request type, selected plan, price, and submission time. The operator confirms payment received at the gym before approval, or rejects the request. An atomic review function verifies the active operator role, locks the request, and rejects repeat processing. Approval creates a new member from the submitted application or extends the linked subscription, records the payment and renewal history when applicable, and saves the reviewer and decision time. Staff cannot use this function to edit existing personal-profile details. The same function is used by the administrator, preventing competing reviews from recording the same request twice.'
   }
   if($new -cne $old){$texts[0].InnerText=$new;for($i=1;$i -lt $texts.Count;$i++){$texts[$i].InnerText=''}}
  }
  $s=$entry.Open();$s.SetLength(0);$w=[IO.StreamWriter]::new($s);$doc.Save($w);$w.Dispose()
 }finally{$zip.Dispose()}
 Write-Output "Updated Chapter $chapter staff review permissions."
}
