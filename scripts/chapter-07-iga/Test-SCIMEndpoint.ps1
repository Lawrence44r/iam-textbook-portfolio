<#
.SYNOPSIS
    Script 7-3: SCIM 2.0 Endpoint Validation
.DESCRIPTION
    Validates a SCIM 2.0 endpoint by running a full Create/Read/Patch/Delete lifecycle test.
    Verifies HTTP status codes, SCIM schema compliance, and externalId round-trip.
.NOTES
    Chapter 7 §7.3 — SCIM 2.0 Protocol
    RFC 7644: SCIM 2.0 Protocol
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BaseUrl,      # e.g. https://api.example.com/scim/v2
    [Parameter(Mandatory)][string]$BearerToken,
    [string]$TestExternalId = "scim-test-$(Get-Random)"
)

$headers = @{
    Authorization  = "Bearer $BearerToken"
    'Content-Type' = 'application/scim+json'
    Accept         = 'application/scim+json'
}

function Invoke-SCIM {
    param([string]$Method, [string]$Path, [hashtable]$Body = $null)
    $uri    = "$BaseUrl$Path"
    $params = @{ Method = $Method; Uri = $uri; Headers = $headers; ErrorAction = 'Stop' }
    if ($Body) { $params.Body = ($Body | ConvertTo-Json -Depth 5) }
    try {
        $response = Invoke-WebRequest @params
        return @{ Status = [int]$response.StatusCode; Body = $response.Content | ConvertFrom-Json }
    } catch [System.Net.WebException] {
        $code = [int]$_.Exception.Response.StatusCode
        return @{ Status = $code; Body = $null; Error = $_.Exception.Message }
    }
}

function Assert-Result {
    param([string]$Test, [hashtable]$Result, [int]$ExpectedStatus, [scriptblock]$AdditionalCheck = $null)
    $statusOk = ($Result.Status -eq $ExpectedStatus)
    $addlOk   = if ($AdditionalCheck) { & $AdditionalCheck $Result } else { $true }
    $pass     = $statusOk -and $addlOk
    $icon     = if ($pass) { '[PASS]' } else { '[FAIL]' }
    $color    = if ($pass) { 'Green' } else { 'Red' }
    Write-Host "$icon $Test (HTTP $($Result.Status), expected $ExpectedStatus)" -ForegroundColor $color
    if (-not $statusOk) { Write-Host "       Error: $($Result.Error)" -ForegroundColor Red }
    return $pass
}

Write-Host "`n=== SCIM 2.0 Endpoint Validation ===" -ForegroundColor Cyan
Write-Host "Endpoint: $BaseUrl | ExternalId: $TestExternalId`n"

$allPass = $true
$userId  = $null

# --- Step 1: Discover ServiceProviderConfig ---
Write-Host "DISCOVERY" -ForegroundColor Yellow
$spConfig = Invoke-SCIM -Method GET -Path "/ServiceProviderConfig"
$pass = Assert-Result "GET /ServiceProviderConfig" $spConfig 200
$allPass = $allPass -and $pass
if ($spConfig.Body) {
    Write-Host "  Supported: PATCH=$(if ($spConfig.Body.patch.supported) {'yes'} else {'NO'}), ETag=$(if ($spConfig.Body.etag.supported) {'yes'} else {'no'}), Sort=$(if ($spConfig.Body.sort.supported) {'yes'} else {'no'})"
}

# --- Step 2: Create User ---
Write-Host "`nCREATE" -ForegroundColor Yellow
$createBody = @{
    schemas    = @("urn:ietf:params:scim:schemas:core:2.0:User")
    externalId = $TestExternalId
    userName   = "scim.testuser.$TestExternalId@example.com"
    name       = @{ givenName = "SCIM"; familyName = "TestUser" }
    emails     = @(@{ value = "scim.test.$TestExternalId@example.com"; primary = $true; type = "work" })
    active     = $true
}

$created = Invoke-SCIM -Method POST -Path "/Users" -Body $createBody
$pass = Assert-Result "POST /Users (create)" $created 201 { param($r) $r.Body.id -ne $null }
$allPass = $allPass -and $pass

if ($created.Body) {
    $userId = $created.Body.id
    Write-Host "  Created ID: $userId"

    # Verify externalId round-trip
    $externalIdMatch = ($created.Body.externalId -eq $TestExternalId)
    $icon = if ($externalIdMatch) { '[PASS]' } else { '[FAIL]' }
    $color = if ($externalIdMatch) { 'Green' } else { 'Red' }
    Write-Host "$icon externalId round-trip: expected '$TestExternalId', got '$($created.Body.externalId)'" -ForegroundColor $color
    $allPass = $allPass -and $externalIdMatch
}

# --- Step 3: Read User ---
Write-Host "`nREAD" -ForegroundColor Yellow
if ($userId) {
    $read = Invoke-SCIM -Method GET -Path "/Users/$userId"
    $pass = Assert-Result "GET /Users/$userId (read by ID)" $read 200 { param($r) $r.Body.id -eq $userId }
    $allPass = $allPass -and $pass

    # Filter by externalId
    $filter = Invoke-SCIM -Method GET -Path "/Users?filter=externalId eq `"$TestExternalId`""
    $pass = Assert-Result "GET /Users?filter=externalId (filter)" $filter 200 { param($r) $r.Body.totalResults -ge 1 }
    $allPass = $allPass -and $pass
}

# --- Step 4: Patch User ---
Write-Host "`nPATCH" -ForegroundColor Yellow
if ($userId) {
    $patchBody = @{
        schemas    = @("urn:ietf:params:scim:api:messages:2.0:PatchOp")
        Operations = @(@{
            op    = "replace"
            path  = "displayName"
            value = "SCIM Test User (patched)"
        })
    }
    $patched = Invoke-SCIM -Method PATCH -Path "/Users/$userId" -Body $patchBody
    $pass = Assert-Result "PATCH /Users/$userId (update)" $patched 200 { param($r) $r.Body.displayName -match 'patched' }
    $allPass = $allPass -and $pass
}

# --- Step 5: Deactivate (PATCH active=false) ---
Write-Host "`nDEACTIVATE" -ForegroundColor Yellow
if ($userId) {
    $deactivateBody = @{
        schemas    = @("urn:ietf:params:scim:api:messages:2.0:PatchOp")
        Operations = @(@{ op = "replace"; path = "active"; value = $false })
    }
    $deactivated = Invoke-SCIM -Method PATCH -Path "/Users/$userId" -Body $deactivateBody
    $pass = Assert-Result "PATCH /Users/$userId active=false (deactivate)" $deactivated 200
    $allPass = $allPass -and $pass
}

# --- Step 6: Delete User ---
Write-Host "`nDELETE" -ForegroundColor Yellow
if ($userId) {
    $deleted = Invoke-SCIM -Method DELETE -Path "/Users/$userId"
    $pass = Assert-Result "DELETE /Users/$userId" $deleted 204
    $allPass = $allPass -and $pass
}

# --- Summary ---
Write-Host "`n==========================================" -ForegroundColor Cyan
if ($allPass) {
    Write-Host "  RESULT: ALL TESTS PASSED — SCIM endpoint is compliant" -ForegroundColor Green
} else {
    Write-Host "  RESULT: SOME TESTS FAILED — Review failures above before go-live" -ForegroundColor Red
}
Write-Host "==========================================" -ForegroundColor Cyan
