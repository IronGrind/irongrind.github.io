// Mock all requests/prompts in a child PowerShell process. Never contacts Supabase.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, unlinkSync, rmdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
const script = fileURLToPath(new URL('../reset-admin-passwords.ps1', import.meta.url)).replaceAll("'", "''");
const temp = mkdtempSync(join(tmpdir(), 'ig-password-mock-'));
const runner = join(temp, 'test.ps1');
try {
    for (const scenario of ['success', 'unauthorized', 'missing-account', 'mismatch', 'partial']) {
        writeFileSync(runner, `
$script:testScenario = '${scenario}'
$script:promptIndex = 0
$script:mockWrites = 0
function Read-Host {
    param($Prompt, [switch]$AsSecureString)
    $script:promptIndex++
    $value = 'FAKE-TEST-PASSWORD-123'
    if ($script:promptIndex -eq 1) { $value = 'FAKE-TEST-KEY' }
    if ($script:testScenario -eq 'mismatch' -and $script:promptIndex -eq 3) { $value = 'MISMATCH-PASSWORD' }
    return (ConvertTo-SecureString $value -AsPlainText -Force)
}
function Invoke-RestMethod {
    param($Uri, $Headers, $TimeoutSec, $Method, $ContentType, $Body)
    if ($script:testScenario -eq 'unauthorized') {
        $problem = [System.Exception]::new('Sensitive raw request FAKE-TEST-KEY')
        $problem | Add-Member -NotePropertyName Response -NotePropertyValue ([pscustomobject]@{StatusCode=401})
        throw $problem
    }
    if ($Uri -match '/rest/v1/profiles') {
        $profiles = @([pscustomobject]@{id='f52fe049-c815-467b-bbe7-42dbbee549d4';role='admin';full_name='ADMIN';username='admin01'})
        if ($script:testScenario -ne 'missing-account') { $profiles += [pscustomobject]@{id='978dd48a-7b9f-4592-9d1e-a70fb621812d';role='admin';full_name='Jamaica';username='admin02'} }
        # Invoke-RestMethod can return an array as a single pipeline object.
        Write-Output -NoEnumerate $profiles
        return
    }
    if ($Method -eq 'Put') {
        $decoded = [Text.Encoding]::UTF8.GetString($Body) | ConvertFrom-Json
        if ($decoded.password -cne 'FAKE-TEST-PASSWORD-123') { throw 'Incorrect test payload' }
        $script:mockWrites++
        if ($script:testScenario -eq 'partial' -and $script:mockWrites -eq 2) {
            $problem = [System.Exception]::new('Sensitive raw request FAKE-TEST-PASSWORD-123')
            $problem | Add-Member -NotePropertyName Response -NotePropertyValue ([pscustomobject]@{StatusCode=422})
            throw $problem
        }
        return @{}
    }
    return [pscustomobject]@{id=($Uri -split '/')[-1]}
}
$global:LASTEXITCODE = 0
& '${script}'
$resultCode = $LASTEXITCODE
Write-Host "MOCK_WRITES=$script:mockWrites"
exit $resultCode
`.replaceAll('$script:', '$global:'), 'utf8');
        const result = spawnSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', runner], { encoding: 'utf8' });
        const output = result.stdout + result.stderr;
        assert.ok(!output.includes('FAKE-TEST-KEY') && !output.includes('FAKE-TEST-PASSWORD-123'), 'Secrets must not appear in output');
        assert.equal(result.status, scenario === 'success' ? 0 : 1, `${scenario}: ${output}`);
        if (scenario === 'success') {
            assert.match(output, /Password updated: ADMIN/);
            assert.match(output, /Password updated: Jamaica/);
            assert.match(output, /MOCK_WRITES=2/);
        } else if (scenario === 'unauthorized') {
            assert.match(output, /HTTP 401/);
            assert.match(output, /loading the two admin profiles/);
            assert.match(output, /MOCK_WRITES=0/);
        } else if (scenario === 'missing-account') {
            assert.match(output, /missing or is not an admin/);
            assert.match(output, /MOCK_WRITES=0/);
        } else if (scenario === 'mismatch') {
            assert.match(output, /Passwords did not match/);
            assert.match(output, /MOCK_WRITES=0/);
        } else {
            assert.match(output, /Password updated: ADMIN/);
            assert.match(output, /HTTP 422/);
            assert.ok(!output.includes('Password updated: Jamaica'));
        }
        console.log(`Passed: ${scenario}`);
    }
} finally { unlinkSync(runner); rmdirSync(temp); }
