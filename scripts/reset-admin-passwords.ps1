# Run locally from the project owner/developer's terminal, never from the website.
# Values entered with Read-Host -AsSecureString are not echoed or saved to a file.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectUrl = 'https://nttsrdassmzvtaamyogi.supabase.co'
$adminIds = @(
    'f52fe049-c815-467b-bbe7-42dbbee549d4',
    '978dd48a-7b9f-4592-9d1e-a70fb621812d'
)
$secrets = @{}
$headers = $null
$serviceKey = $null
$failed = $false

function Convert-SecretToText([Security.SecureString]$Secret) {
    $buffer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secret)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($buffer) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($buffer) }
}

try {
    Write-Host 'Project: nttsrdassmzvtaamyogi (IronGrind)'
    Write-Host 'This changes the passwords of the ADMIN and Jamaica admin accounts.'
    $keyInput = Read-Host 'Enter this project''s service_role key (hidden)' -AsSecureString
    try { $serviceKey = Convert-SecretToText $keyInput } finally { $keyInput.Dispose() }
    if ([string]::IsNullOrWhiteSpace($serviceKey)) { throw 'No service_role key was entered.' }
    $headers = @{ apikey = $serviceKey; Authorization = "Bearer $serviceKey" }

    # Check both identities before making either password change.
    $idFilter = $adminIds -join ','
    $profiles = @(Invoke-RestMethod -Uri "$projectUrl/rest/v1/profiles?select=id,full_name,username,role&id=in.($idFilter)" -Headers $headers -TimeoutSec 30)
    foreach ($accountId in $adminIds) {
        $matches = @($profiles | Where-Object { $_.id -eq $accountId -and $_.role -eq 'admin' })
        if ($matches.Count -ne 1) { throw "Account $accountId is missing or is not an admin. No passwords changed." }
        $authAccount = Invoke-RestMethod -Uri "$projectUrl/auth/v1/admin/users/$accountId" -Headers $headers -TimeoutSec 30
        if ($authAccount.id -ne $accountId) { throw 'Auth account verification failed. No passwords changed.' }
        $label = $matches[0].full_name
        $username = $matches[0].username
        if ([string]::IsNullOrWhiteSpace($username)) { $username = '(no username assigned)' }
        Write-Host "Verified: $label / $username / $accountId"
    }

    foreach ($accountId in $adminIds) {
        $profile = $profiles | Where-Object { $_.id -eq $accountId }
        $password = Read-Host "New password for $($profile.full_name) (hidden)" -AsSecureString
        $confirmation = Read-Host 'Enter it again (hidden)' -AsSecureString
        $plainPassword = $null
        $plainConfirmation = $null
        try {
            $plainPassword = Convert-SecretToText $password
            $plainConfirmation = Convert-SecretToText $confirmation
            if ($plainPassword.Length -lt 12) { throw 'Use at least 12 characters. No passwords changed.' }
            if ($plainPassword -cne $plainConfirmation) { throw 'Passwords did not match. No passwords changed.' }
            $secrets[$accountId] = $password.Copy()
        } finally {
            $password.Dispose()
            $confirmation.Dispose()
            $plainPassword = $null
            $plainConfirmation = $null
        }
    }

    foreach ($accountId in $adminIds) {
        $profile = $profiles | Where-Object { $_.id -eq $accountId }
        $requestBody = $null
        $newPassword = $null
        try {
            $newPassword = Convert-SecretToText $secrets[$accountId]
            $requestBody = @{ password = $newPassword } | ConvertTo-Json -Compress
            Invoke-RestMethod -Method Put -Uri "$projectUrl/auth/v1/admin/users/$accountId" -Headers $headers -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($requestBody)) -TimeoutSec 30 | Out-Null
            Write-Host "Password updated: $($profile.full_name)"
        } catch {
            $failed = $true
            Write-Warning "Could not confirm password update for $($profile.full_name). Check Supabase Auth logs and password requirements. Other updates are reported separately."
        } finally { $newPassword = $null; $requestBody = $null }
    }
} catch {
    $failed = $true
    # Avoid printing HTTP exceptions or request objects that might contain secrets.
    Write-Warning 'Stopped. Verify the project service_role key, both admin accounts, and matching passwords of at least 12 characters. If updates began, use the per-account results above.'
} finally {
    foreach ($secret in $secrets.Values) { $secret.Dispose() }
    $secrets.Clear()
    if ($headers) { $headers.Clear() }
    $serviceKey = $null
}
if ($failed) { exit 1 }
Write-Host 'Done. Sign in with each account''s username and its new password.'
