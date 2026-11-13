$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = Split-Path $PSScriptRoot -Parent
$source = Join-Path $root 'Chapters 1-3 (MAO NA JUD NI).docx'
$backup = Join-Path $root ('Review Backups/plan-change-paper-followup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $backup | Out-Null
Copy-Item -LiteralPath $source -Destination (Join-Path $backup 'Chapters 1-3 (MAO NA JUD NI).docx') -Force

$replacements = [ordered]@{
  'The system stored member profiles and membership information' = 'The system stored member profiles and membership information, including plans, membership dates, and status. Applicants could submit online registration details for authorized staff or administrator review. Members could submit online renewal requests and, while active, request a different plan. A plan-change request required payment at the gym and approval by authorized staff or an administrator. An approved renewal extended an active subscription from its current expiry date; an expired subscription restarted on the approval date. An approved plan change replaced the current plan and membership dates from the approval date. Direct counter renewals and plan changes remained separate operator transactions.'
  'Functional requirements distinguish applicants and members' = 'Functional requirements distinguish applicants and members from administrators and authorized staff. Authorized staff and administrators can approve or reject online registration, renewal, and active-member plan-change requests after confirming in-person payment. Staff have assigned counter and attendance operations, while stock maintenance, staff account controls, phone pairing administration, activity-log review, and reports remain administrator functions.'
  'Members request renewal; authorized staff and administrators review online requests.' = 'Members may request renewal or an active-member plan change; authorized staff and administrators review online requests after confirming the applicable in-person payment. Direct staff counter renewals and plan changes are covered under User Management.'
  'The data-process model follows information from an actor' = 'The data-process model follows information from an actor, through an authorized system function, to the records it reads or changes. Applicant registration, member renewal, and active-member plan-change requests are reviewed before they create or update member and payment records. Attendance scans are checked against the member and any open visit before timestamps and operator identities are stored. Product sales read catalog and stock data, then save transaction lines and deduct stock. Reports and activity logs are separate read operations with different access rules.'
  'The Member/Applicant provides inputs such as sign-in credentials' = 'The Member/Applicant provides inputs such as sign-in credentials, registration details, membership applications, renewal or active-member plan-change requests, and profile updates. A plan change is paid for at the gym and requires staff or administrator approval. In return, the system provides outputs including authentication results, application statuses, membership details, attendance history, the active product catalog, and account information.'
  'The Member / Applicant entity combines two stages' = 'The Member / Applicant entity combines two stages of the customer relationship: a person applying for membership and an existing member using personal account services. Its incoming flow consists of credentials, registration details, renewal and plan-change requests, and permitted profile changes. A member may request a plan change only while the membership is active; the member pays at the gym, and the change takes effect only after authorized review. Registration details describe the information submitted for review; submission alone does not mean that membership has been approved. Renewal requests concern an existing membership and must be reviewed before their result is applied. Permitted profile changes concern the signed-in member''s own editable personal information and do not include authority to approve requests, alter product stock, record sales, or modify another member''s account.'
  'The Authorized Staff entity exchanges credentials, counter details' = 'The Authorized Staff entity exchanges credentials, counter details, request-review decisions, QR scans, and product-sale entries. After staff identity and active-account status have been verified, the permitted tasks include walk-in member registration, limited member lookup for counter transactions, direct renewal, active-member plan changes, review of online registration, renewal, and plan-change requests after confirming payment at the gym, attendance scanning, and product-sale recording. A member lookup supplies the limited details needed to select the correct person for an authorized transaction; it is not general access to the member''s personal profile. Staff review decisions are based on the request information made available by the staff interface. The QR scan flow submits a member identifier for the system to validate and record the applicable attendance result.'
}

function Get-Text($paragraph, $ns) { return (($paragraph.SelectNodes('.//w:t', $ns) | ForEach-Object InnerText) -join '') }
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
    Set-Text $matches[0] $replacements[$prefix] $ns
  }
  $entry.Delete()
  $writer = [IO.StreamWriter]::new($zip.CreateEntry('word/document.xml').Open(), [Text.UTF8Encoding]::new($false))
  try { $document.Save($writer) } finally { $writer.Dispose() }
} finally { $zip.Dispose() }
Copy-Item -LiteralPath $stage -Destination $source -Force
Write-Output "Updated remaining plan-change workflow descriptions in $source"
Write-Output "Backup: $backup"
