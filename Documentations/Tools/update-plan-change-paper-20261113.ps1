$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = Split-Path $PSScriptRoot -Parent
$source = Join-Path $root 'Chapters 1-3 (MAO NA JUD NI).docx'
$backup = Join-Path $root ('Review Backups/plan-change-paper-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $backup | Out-Null
Copy-Item -LiteralPath $source -Destination (Join-Path $backup 'Chapters 1-3 (MAO NA JUD NI).docx') -Force

$replacements = [ordered]@{
  'To address these concerns, the proponents developed IronGrind:' = 'To address these concerns, the proponents developed IronGrind: A Fitness Gym Membership and Operations Management System. The system provides online membership registration, membership application review and approval, membership status monitoring, renewal requests, and active-member plan-change requests. Plan changes are submitted by members, paid for at the gym, and applied only after staff or administrator approval. It also incorporates QR code-based attendance monitoring, allowing authorized administrators and staff to record member check-ins and check-outs. Members can access their dashboard to view their membership status, remaining membership period, attendance history, and QR code.'
  'The system organizes member profiles, membership plans, membership dates, and membership status.' = 'The system organizes member profiles, membership plans, membership dates, and membership status. It allows applicants to submit registration details online for authorized staff or administrator review and allows existing members to submit renewal or active-member plan-change requests. A plan change is paid for at the gym and takes effect only after authorized staff or administrator approval. An approved renewal carries forward unused time from an active membership''s current expiry date; an expired membership restarts on the approval date.'
  'To develop online registration and renewal request features' = 'To develop online registration, renewal, and active-member plan-change request features that allow authorized staff and administrators to review, approve, or reject requests after confirming in-person payment. Members may submit renewal requests at any time; active members may also request a different plan. Renewals take effect only after approval: an active membership carries forward unused time, while an expired membership restarts on the approval date. An approved plan change replaces the current plan and membership dates from the approval date.'
  'The primary users of the system were the gym administrator' = 'The primary users of the system were the gym administrator, authorized staff, and registered gym members. The administrator could view member personal profiles without editing their personal details and manage membership operations, attendance, inventory, sales, staff accounts, phone pairings, activity logs, and reports. Authorized staff could record attendance, register walk-in members, process direct renewals and active-member plan changes using limited member lookup, record product sales, and review their own product-sale records. Both staff and administrators could approve or reject online registration, renewal, and active-member plan-change requests after confirming in-person payment. Staff could not view or edit existing member personal profiles. Members could view and update their own permitted personal details, access their membership status, attendance history and QR code, browse active products, and request renewal or an active-member plan change. Walk-in product purchases could be recorded without a member account.'
  'Gym Members. Members benefited from access' = 'Gym Members. Members benefited from access to their membership information, membership-period progress, attendance history, and QR code through the member dashboard. They could submit renewal requests and, while active, request a different membership plan online. A plan-change request required payment at the gym and staff or administrator approval before it changed the membership.'
  'Authorized Staff. A user assigned a staff account' = 'Authorized Staff. A user assigned a staff account to record attendance, register walk-in members, process direct membership renewals and plan changes, approve or reject online registration, renewal, and member plan-change requests after confirming in-person payment, and record in-person product sales within the access allowed by the system.'
  'The prototype represents the designed workflows through browser-based pages.' = 'The prototype represents the designed workflows through browser-based pages. Applicants submit registration details, while members view their membership, attendance, QR code, profile, catalog, and renewal or plan-change request options. Members must pay for a plan change at the gym and wait for staff or administrator approval. Administrators view member profiles without editing personal details, review online requests, perform membership operations, and handle inventory, sales, staff access, phone pairing, activity logs, and reports. Staff use a separate portal for attendance, walk-in registration, direct membership renewals and active-member plan changes, product sales, their own product-sale records, and online registration, renewal, and plan-change request approval. The system records in-person transactions without providing receipts to customers. Supabase Auth, database policies, functions, and authorized Edge Functions support the implemented operations.'
  'The system uses registration, profile, renewal, member, inventory' = 'The system uses registration, profile, renewal, member plan-change, inventory, sales, staff-account, and phone-pairing forms. Members submit online registration or renewal information and may request an active-member plan change while maintaining their permitted profile details. Administrators review online requests, maintain products and stock, and manage staff and pairing access. Authorized staff use counter forms for walk-in registration, direct renewal, active-member plan change, and product purchases, and use Requests approval for online registration, renewal, and plan-change decisions after confirming in-person payment. Attendance uses camera scanning under an authorized operator account. Completed payments and purchases are recorded as transactions; receipts are not provided to customers. Required fields, validation, and server-side role checks support consistent data entry.'
  'The Create Staff Account form collects first name' = 'The Create Staff Account form collects first name, optional middle initial, and last name in separate inputs. It formats a supplied initial with a period and combines the parts into the existing full_name value; separate name columns are not introduced. The form also checks username and Gmail availability, phone format, password strength, and matching confirmation. Staff directory access and activation controls remain administrator-only. The Requests approval view separately presents pending online registration, renewal, and member plan-change summaries for authorized staff and administrator decisions, with in-person payment confirmation before approval.'
  'Table 8: membership_applications' = 'Table 8: membership_applications'
  'Stores submitted registration and renewal requests with the information provided by the applicant.' = 'Stores submitted registration, renewal, and active-member plan-change requests with the information provided by the applicant/member. Review status, reviewer, and timestamps track each request through processing.'
  'Distinguishes an initial registration application from a membership renewal request.' = 'Identifies whether a membership application represents an initial registration, a renewal, or an active-member plan-change request. NOT NULL. CHECK: registration, renewal, or plan_change.'
  'Figure 5 presents the public-schema Entity Relationship Diagram (ERD) for IronGrind.' = 'Figure 5 presents the public-schema Entity Relationship Diagram (ERD) for IronGrind. It is a structural view of the database: each entity box represents a table; PK identifies the primary key; FK identifies a field that references another table; UQ identifies a value that must be unique; and each connector represents a declared foreign-key relationship. The diagram shows the primary keys, foreign keys, unique constraints, and selected descriptive attributes needed to read the main relationships. The data dictionary provides the complete field definitions, data types, lengths, precision values, and validation rules. The auth.users card is a Supabase-managed identity reference and is not counted as an application-owned public table. The application_type field on the existing membership_applications table allows registration, renewal, or plan_change; this value constraint adds no table, field, or relationship to the ERD.'
  '4.0 Review Online Renewals.' = '4.0 Review Online Renewals and Plan-Change Requests.'
  'Members submit renewal requests to membership_applications.' = 'Members submit renewal requests or active-member plan-change requests to membership_applications. Authorized staff and administrators approve or reject these requests after confirming payment at the gym. An approved renewal preserves unused time by extending an active membership from its current expiry date; an expired membership restarts on approval. An approved plan change replaces the current plan and membership dates from the approval date. Approval updates the member, history, application status, and membership transaction records. Direct counter renewals and direct staff plan changes belong to process 3.0 and are separate from the online Requests approval workflow.'
}

function Get-Text($paragraph, $ns) {
  return (($paragraph.SelectNodes('.//w:t', $ns) | ForEach-Object InnerText) -join '')
}

function Set-Text($paragraph, $value, $ns) {
  $runs = @($paragraph.SelectNodes('.//w:t', $ns))
  if ($runs.Count -eq 0) { throw 'The target paragraph has no text run.' }
  $runs[0].InnerText = $value
  foreach ($run in $runs | Select-Object -Skip 1) { $run.InnerText = '' }
}

$stage = Join-Path $backup 'manuscript-staged.docx'
Copy-Item -LiteralPath $source -Destination $stage -Force
$zip = [IO.Compression.ZipFile]::Open($stage, 'Update')
try {
  $entry = $zip.GetEntry('word/document.xml')
  $reader = [IO.StreamReader]::new($entry.Open())
  try { [xml]$document = $reader.ReadToEnd() } finally { $reader.Dispose() }
  $ns = [Xml.XmlNamespaceManager]::new($document.NameTable)
  $ns.AddNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
  $paragraphs = @($document.SelectNodes('//w:body//w:p', $ns))
  foreach ($prefix in $replacements.Keys) {
    $matches = @($paragraphs | Where-Object { (Get-Text $_ $ns).Trim().StartsWith($prefix) })
    if ($matches.Count -ne 1) { throw "Expected one paragraph beginning '$prefix'; found $($matches.Count)." }
    if ($prefix -eq 'Table 8: membership_applications') { continue }
    Set-Text $matches[0] $replacements[$prefix] $ns
  }
  $entry.Delete()
  $writer = [IO.StreamWriter]::new($zip.CreateEntry('word/document.xml').Open(), [Text.UTF8Encoding]::new($false))
  try { $document.Save($writer) } finally { $writer.Dispose() }
} finally {
  $zip.Dispose()
}

Copy-Item -LiteralPath $stage -Destination $source -Force
Write-Output "Updated member plan-change descriptions in $source"
Write-Output "Backup: $backup"
