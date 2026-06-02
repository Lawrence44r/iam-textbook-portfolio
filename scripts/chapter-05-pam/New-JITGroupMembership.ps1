<#
.SYNOPSIS
    Script 5-3: JIT Group Membership with Auto-Expiry
.DESCRIPTION
    Grants time-bounded AD group membership with automatic scheduled revocation.
    Adds group membership, creates a scheduled task to remove at expiry, and logs all actions.
.PARAMETER User          SamAccountName of the user
.PARAMETER Group         SamAccountName of the group
.PARAMETER DurationHours Hours of access (1-24)
.PARAMETER Justification Business justification (required for audit log)
.PARAMETER TicketNumber  ITSM ticket number
.NOTES
    Requires: ActiveDirectory module; local admin on machine running the scheduled task
    Chapter 5 §5.4 — JIT Access Models
.EXAMPLE
    .\New-JITGroupMembership.ps1 -User jsmith -Group "Tier1-Admins" -DurationHours 4 `
        -Justification "Password reset for Finance server" -TicketNumber "INC0012345"
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$User,
    [Parameter(Mandatory)][string]$Group,
    [Parameter(Mandatory)][ValidateRange(1,24)][int]$DurationHours,
    [Parameter(Mandatory)][string]$Justification,
    [Parameter(Mandatory)][string]$TicketNumber
)

Import-Module ActiveDirectory -ErrorAction Stop

$expiry   = (Get-Date).AddHours($DurationHours)
$logFile  = "C:\Logs\JIT\JIT_$(Get-Date -Format 'yyyyMMdd').log"
$taskName = "JIT-Revoke-$User-$Group-$(Get-Date -Format 'HHmmss')"

function Write-AuditLog {
    param([string]$Message)
    $entry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [JIT] $Message"
    Write-Host $entry
    $null = New-Item -Path (Split-Path $logFile) -ItemType Directory -Force
    Add-Content -Path $logFile -Value $entry
}

# Validate objects exist
$adUser  = Get-ADUser -Identity $User  -ErrorAction Stop
$adGroup = Get-ADGroup -Identity $Group -ErrorAction Stop

Write-Host "`n=== JIT Group Membership Grant ===" -ForegroundColor Cyan
Write-Host "User:        $User ($($adUser.Name))"
Write-Host "Group:       $Group"
Write-Host "Duration:    $DurationHours hours"
Write-Host "Expiry:      $($expiry.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host "Ticket:      $TicketNumber"
Write-Host "Reason:      $Justification"

if (-not $PSCmdlet.ShouldProcess("$User -> $Group", "Add to group for $DurationHours hours")) { return }

# Check not already a member
$isMember = (Get-ADGroupMember -Identity $Group -Recursive | Where-Object { $_.SamAccountName -eq $User }).Count -gt 0
if ($isMember) {
    Write-Host "[WARNING] $User is already a member of $Group" -ForegroundColor Yellow
    Write-AuditLog "SKIP: $User already member of $Group (Ticket: $TicketNumber)"
    return
}

# Grant membership
Add-ADGroupMember -Identity $Group -Members $User
Write-AuditLog "GRANT: User=$User Group=$Group Duration=${DurationHours}h Expiry=$($expiry.ToString('o')) Ticket=$TicketNumber Reason='$Justification' Operator=$env:USERNAME"

# Create revocation scheduled task
$removeScript = @"
Import-Module ActiveDirectory
Remove-ADGroupMember -Identity '$Group' -Members '$User' -Confirm:`$false
`$logEntry = "[`$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [JIT] REVOKE: User=$User Group=$Group Ticket=$TicketNumber"
Add-Content -Path '$logFile' -Value `$logEntry
Unregister-ScheduledTask -TaskName '$taskName' -Confirm:`$false
"@

$action  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NonInteractive -Command `"$removeScript`""
$trigger = New-ScheduledTaskTrigger -Once -At $expiry
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings `
    -RunLevel Highest -User "SYSTEM" -Description "JIT auto-revoke: $User from $Group (Ticket: $TicketNumber)" | Out-Null

Write-Host "`n[OK] Membership granted. Auto-revocation scheduled at $($expiry.ToString('HH:mm:ss')) via task '$taskName'" -ForegroundColor Green
Write-AuditLog "TASK_CREATED: $taskName scheduled at $($expiry.ToString('o'))"

Write-Host "`nIMPORTANT: The user must sign out and back in (or run 'klist purge') to get updated Kerberos tickets." -ForegroundColor Yellow
