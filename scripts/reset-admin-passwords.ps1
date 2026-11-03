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
$stage = 'reading the service_role key'
$safeFailureReason = $null

function Convert-SecretToText([Security.SecureString]$Secret) {
    $buffer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secret)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($buffer) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($buffer) }
}

function Get-RequestFailureHint($Failure) {
    $response = $Failure.Exception.Response
    if ($null -ne $response) {
        $httpStatus = [int]$response.StatusCode
        switch ($httpStatus) {
            401 { return 'HTTP 401: Supabase rejected the key. Copy the service_role key from this exact project and try again.' }
            403 { return 'HTTP 403: The supplied key does not have permission for this operation. Use this project''s service_role key.' }
            404 { return 'HTTP 404: The requested account or API resource was not found in this project.' }
            429 { return 'HTTP 429: Too many requests. Wait a few minutes before retrying.' }
            default { return "HTTP $httpStatus. Check the project status and Supabase Auth logs. The request contents have been hidden." }
        }
    }
    return "Request or script failure ($($Failure.Exception.GetType().Name), line $($Failure.InvocationInfo.ScriptLineNumber)). Check the connection and project settings."
}

try {
    Write-Host 'Project: nttsrdassmzvtaamyogi (IronGrind)'
    Write-Host 'This changes the passwords of the ADMIN and Jamaica admin accounts.'
    $keyInput = Read-Host 'Enter this project''s service_role key (hidden)' -AsSecureString
    try { $serviceKey = (Convert-SecretToText $keyInput).Trim() } finally { $keyInput.Dispose() }
    if ([string]::IsNullOrWhiteSpace($serviceKey)) { $safeFailureReason = 'No service_role key was entered.'; throw $safeFailureReason }
    $headers = @{ apikey = $serviceKey; Authorization = "Bearer $serviceKey" }

    # Check both identities before making either password change.
    $stage = 'loading the two admin profiles'
    $idFilter = $adminIds -join ','
    $profileResponse = Invoke-RestMethod -Uri "$projectUrl/rest/v1/profiles?select=id,full_name,username,role&id=in.($idFilter)" -Headers $headers -TimeoutSec 30
    $profiles = @($profileResponse | ForEach-Object { $_ })
    foreach ($accountId in $adminIds) {
        $stage = "verifying admin account $accountId"
        $matchedProfiles = @($profiles | Where-Object { $_.id -eq $accountId -and $_.role -eq 'admin' })
        if ($matchedProfiles.Count -ne 1) { $safeFailureReason = "Account $accountId is missing or is not an admin. No passwords changed."; throw $safeFailureReason }
        $authAccount = Invoke-RestMethod -Uri "$projectUrl/auth/v1/admin/users/$accountId" -Headers $headers -TimeoutSec 30
        if ($authAccount.id -ne $accountId) { $safeFailureReason = 'Auth account verification failed. No passwords changed.'; throw $safeFailureReason }
        $label = $matchedProfiles[0].full_name
        $username = $matchedProfiles[0].username
        if ([string]::IsNullOrWhiteSpace($username)) { $username = '(no username assigned)' }
        Write-Host "Verified: $label / $username / $accountId"
    }

    foreach ($accountId in $adminIds) {
        $profile = $profiles | Where-Object { $_.id -eq $accountId }
        $stage = "checking the new password for $($profile.full_name)"
        $password = Read-Host "New password for $($profile.full_name) (hidden)" -AsSecureString
        $confirmation = Read-Host 'Enter it again (hidden)' -AsSecureString
        $plainPassword = $null
        $plainConfirmation = $null
        try {
            $plainPassword = Convert-SecretToText $password
            $plainConfirmation = Convert-SecretToText $confirmation
            if ($plainPassword.Length -lt 12) { $safeFailureReason = 'Use at least 12 characters. No passwords changed.'; throw $safeFailureReason }
            if ($plainPassword -cne $plainConfirmation) { $safeFailureReason = 'Passwords did not match. No passwords changed.'; throw $safeFailureReason }
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
            $stage = "updating the password for $($profile.full_name)"
            $newPassword = Convert-SecretToText $secrets[$accountId]
            $requestBody = @{ password = $newPassword } | ConvertTo-Json -Compress
            Invoke-RestMethod -Method Put -Uri "$projectUrl/auth/v1/admin/users/$accountId" -Headers $headers -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($requestBody)) -TimeoutSec 30 | Out-Null
            Write-Host "Password updated: $($profile.full_name)"
        } catch {
            $failed = $true
            Write-Warning "Could not confirm password update for $($profile.full_name). $(Get-RequestFailureHint $_) Other updates are reported separately."
        } finally { $newPassword = $null; $requestBody = $null }
    }
} catch {
    $failed = $true
    # Avoid printing HTTP exceptions or request objects that might contain secrets.
    $hint = if ($safeFailureReason) { $safeFailureReason } else { Get-RequestFailureHint $_ }
    Write-Warning "Stopped while $stage. $hint"
} finally {
    foreach ($secret in $secrets.Values) { $secret.Dispose() }
    $secrets.Clear()
    if ($headers) { $headers.Clear() }
    $serviceKey = $null
}
if ($failed) { exit 1 }
Write-Host 'Done. Sign in with each account''s username and its new password.'
