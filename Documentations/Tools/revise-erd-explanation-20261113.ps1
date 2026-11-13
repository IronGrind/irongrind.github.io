$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = Split-Path $PSScriptRoot -Parent
$source = Join-Path $root 'Chapters 1-3 (MAO NA JUD NI).docx'
$backup = Join-Path $root ('Review Backups/erd-explanation-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $backup | Out-Null
Copy-Item -LiteralPath $source -Destination (Join-Path $backup 'Chapters 1-3 (MAO NA JUD NI).docx') -Force

$replacements = [ordered]@{
  'Figure 5 presents the public-schema relationship overview for IronGrind.' = 'Figure 5 presents the public-schema Entity Relationship Diagram (ERD) for IronGrind. It is a structural view of the database: each entity box represents a table; PK identifies the primary key; FK identifies a field that references another table; UQ identifies a value that must be unique; and each connector represents a declared foreign-key relationship. The diagram shows the primary keys, foreign keys, unique constraints, and selected descriptive attributes needed to read the main relationships. The data dictionary provides the complete field definitions, data types, lengths, precision values, and validation rules. The auth.users card is a Supabase-managed identity reference and is not counted as an application-owned public table.'
  'This figure intentionally covers the public schema rather than the entire application-owned database.' = 'This figure presents the public schema, which stores the core membership and operational records. The complete application-owned database also includes eleven private supporting tables for authentication and device-security workflows. The checked-in migration model documents twenty-three application tables, 235 fields, and thirty-eight declared foreign keys: twelve public tables and eleven private supporting tables. The private structures support scanner sessions and handoff approvals, attendance requests, login attempts, scoped account sessions, and administrator and member device authorization. Their definitions are documented in the data dictionary and separate security reference material. The ERD describes stored relationships; it does not represent role permissions or prove production deployment. Its schema baseline comes from the checked-in migrations and supplied schema material, rather than a new live-database inspection.'
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
    if ($matches.Count -ne 1) { throw "Expected one ERD paragraph beginning '$prefix'; found $($matches.Count)." }
    Set-Text $matches[0] $replacements[$prefix] $ns
  }
  $entry.Delete()
  $writer = [IO.StreamWriter]::new($zip.CreateEntry('word/document.xml').Open(), [Text.UTF8Encoding]::new($false))
  try { $document.Save($writer) } finally { $writer.Dispose() }
} finally {
  $zip.Dispose()
}

Copy-Item -LiteralPath $stage -Destination $source -Force
Write-Output "Updated ERD explanation in $source"
Write-Output "Backup: $backup"
