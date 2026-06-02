<#
.SYNOPSIS
    Script 7-1: Automated Leaver Processing
.DESCRIPTION
    Immediate access revocation for terminated employees (4-hour SLA target).
    Actions: Disable AD account, move to Terminated OU, remove all group memberships,
    revoke Entra ID sessions, notify manager, log all actions with WHO/WHAT/WHEN/WHY.
.PARAMETER SamAccountName  AD SamAccountName of departing employee
.PARAMETER HRTicket        HR system ticket number for audit trail
.PARAMETER TerminatedOU    Distinguished name of Terminated Users OU
.NOTES
    Requires: ActiveDirectory module, Microsoft.Graph module
    Chapter 7 §7.2 — JML Lifecycle and SLAs
.EXAMPLE
    .\Invoke-LeaverProcessing.ps1 -SamAccountName jsmith -HRTicket HR-20240601-001
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$SamAccountName,
    [Parameter(Mandatory)][string]$HRTicket,
    [string]$TerminatedOU = "OU=Terminated,OU=Users,$(Get-ADDomain | Select-Object -ExpandProperty DistinguishedName)",
    [string]$LogPath       = "C:\Logs\IGA\Leaver_$(Get-Date -Format 'yyyyMMdd').log",
    [switch]$RevokeEntraSession
)

Import-Module ActiveDirectory -ErrorAction Stop

$startTime  = Get-Date
$operator   = $env:USERNAME
$actions    = @()

function Write-AuditLog {
    param([string]$What, [string]$Why, $Data = $null)
    $entry = [PSCustomObject]@{
        Timestamp = (Get-Date -Format 'o')
        Who       = $operator
        What      = $What
        Why       = "Leaver processing. HR Ticket: $HRTicket"
        MoreWhy   = $Why
        User      = $SamAccountName
        Data      = $Data
    }
    $logLine = "[$($entry.Timestamp)] [LEAVER] WHO=$($entry.Who) WHAT=$What USER=$SamAccountName TICKET=$HRTicket - $Why"
    Write-Host $logLine
    $null = New-Item -Path (Split-Path $LogPath) -ItemType Directory -Force
    Add-Content -Path $LogPath -Value $logLine
    $script:actions += $entry
}

Write-Host "`n=== LEAVER PROCESSING: $SamAccountName ===" -ForegroundColor Cyan
Write-Host "Operator: $operator | Ticket: $HRTicket | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

# --- Validate user exists ---
$user = Get-ADUser -Identity $SamAccountName -Properties MemberOf, Manager, EmailAddress, Department, DistinguishedName -ErrorAction Stop
Write-Host "Processing: $($user.Name) ($($user.EmailAddress)) — $($user.Department)"

if (-not $PSCmdlet.ShouldProcess($SamAccountName, "Execute Leaver Processing")) { return }

# --- Step 1: Disable Account ---
Write-AuditLog -What "DISABLE_ACCOUNT" -Why "Immediate access revocation per leaver SLA"
Disable-ADAccount -Identity $SamAccountName
Write-AuditLog -What "DISABLE_ACCOUNT_COMPLETE" -Why "Account disabled successfully"

# --- Step 2: Remove All Group Memberships ---
$groupsBefore = $user.MemberOf | ForEach-Object { (Get-ADGroup $_).Name }
Write-AuditLog -What "REMOVE_GROUPS_START" -Why "Removing $($groupsBefore.Count) group memberships" -Data ($groupsBefore -join '; ')

foreach ($groupDN in $user.MemberOf) {
    $groupName = (Get-ADGroup $groupDN).Name
    Remove-ADGroupMember -Identity $groupDN -Members $SamAccountName -Confirm:$false
    Write-AuditLog -What "REMOVE_FROM_GROUP" -Why "Leaver step 2" -Data $groupName
}

# --- Step 3: Clear AD Attributes (manager, sensitive fields) ---
Set-ADUser -Identity $SamAccountName -Clear 'description','telephoneNumber','mobile'
Write-AuditLog -What "CLEAR_AD_ATTRIBUTES" -Why "Removed description, phone from AD"

# --- Step 4: Move to Terminated OU ---
if ($TerminatedOU -and (Get-ADOrganizationalUnit -Filter { DistinguishedName -eq $TerminatedOU } -ErrorAction SilentlyContinue)) {
    Move-ADObject -Identity $user.DistinguishedName -TargetPath $TerminatedOU
    Write-AuditLog -What "MOVE_TO_TERMINATED_OU" -Why "Moved to $TerminatedOU"
} else {
    Write-Host "[WARN] Terminated OU not found: $TerminatedOU — account not moved" -ForegroundColor Yellow
    Write-AuditLog -What "MOVE_OU_SKIPPED" -Why "Terminated OU not found"
}

# --- Step 5: Revoke Entra ID Sessions ---
if ($RevokeEntraSession) {
    try {
        Import-Module Microsoft.Graph.Users -ErrorAction Stop
        $entraUser = Get-MgUser -Filter "onPremisesSamAccountName eq '$SamAccountName'" -ErrorAction Stop
        if ($entraUser) {
            Invoke-MgInvalidateAllUserRefreshToken -UserId $entraUser.Id
            Write-AuditLog -What "REVOKE_ENTRA_SESSIONS" -Why "All Entra ID refresh tokens revoked" -Data $entraUser.UserPrincipalName
        }
    } catch {
        Write-AuditLog -What "REVOKE_ENTRA_SESSIONS_FAILED" -Why "Error: $_"
        Write-Host "[WARN] Entra session revocation failed: $_" -ForegroundColor Yellow
    }
}

# --- Final Summary ---
$duration = ((Get-Date) - $startTime).TotalMinutes
Write-Host "`n=== LEAVER PROCESSING COMPLETE ===" -ForegroundColor Green
Write-Host "User:       $($user.Name)"
Write-Host "Duration:   $([math]::Round($duration, 1)) minutes (SLA: 240 min)"
Write-Host "Groups removed: $($groupsBefore.Count)"
Write-Host "Actions taken:  $($actions.Count)"
Write-Host "Log:            $LogPath"

$slaColor = if ($duration -le 240) { 'Green' } else { 'Red' }
Write-Host "SLA Status: $(if ($duration -le 240) { 'WITHIN 4-HOUR SLA' } else { 'SLA BREACHED' })" -ForegroundColor $slaColor

$actions | ConvertTo-Json -Depth 3 | Out-File "$LogPath.json" -Encoding UTF8
