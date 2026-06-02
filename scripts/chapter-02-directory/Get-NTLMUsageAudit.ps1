<#
.SYNOPSIS
    Script 2-7: NTLM Usage and Restriction Audit
.DESCRIPTION
    Measures NTLM usage in the environment and verifies restriction settings.
    Target: LmCompatibilityLevel = 5 (NTLMv2 only, refuse LM and NTLMv1).
    Reads Event ID 8004 from Security log for NTLM authentication volume.
.NOTES
    Requires: ActiveDirectory module; Event log read access
    Chapter 2 §2.5 — NTLM Restriction
#>
[CmdletBinding()]
param(
    [string[]]$DomainControllers = @((Get-ADDomain).PDCEmulator),
    [int]$EventLookbackHours = 24
)

Import-Module ActiveDirectory -ErrorAction Stop

Write-Host "`n=== NTLM Usage and Restriction Audit ===" -ForegroundColor Cyan
Write-Host "Lookback: $EventLookbackHours hours | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

# --- LmCompatibilityLevel Check ---
Write-Host "1. LmCompatibilityLevel Registry Check" -ForegroundColor Yellow
Write-Host "   Target: 5 = Send NTLMv2 only, refuse LM and NTLMv1"
Write-Host "   Value:  0=LM+NTLM, 1=LM+NTLM+NTLMv2, 3=NTLMv2 only, 5=NTLMv2+refuse LM/NTLMv1"

foreach ($dc in $DomainControllers) {
    try {
        $regVal = Invoke-Command -ComputerName $dc -ScriptBlock {
            Get-ItemPropertyValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' `
                -Name 'LmCompatibilityLevel' -ErrorAction SilentlyContinue
        } -ErrorAction Stop

        $status = switch ($regVal) {
            5       { "[OK] Level 5 — NTLMv2 only, LM/NTLMv1 refused" }
            4       { "[WARN] Level 4 — NTLMv2 only (client), DC refuses LM but accepts NTLMv1" }
            3       { "[WARN] Level 3 — NTLMv2 only (client), DC still accepts all" }
            default { "[RISK] Level $regVal — Weak NTLM versions permitted" }
        }
        $color = if ($regVal -eq 5) { 'Green' } elseif ($regVal -ge 3) { 'Yellow' } else { 'Red' }
        Write-Host "   $dc`: $status" -ForegroundColor $color

    } catch {
        Write-Host "   $dc`: [ERROR] Cannot read registry - $_" -ForegroundColor Red
    }
}

# --- Event ID 8004: NTLM Authentication Events ---
Write-Host "`n2. NTLM Authentication Event Volume (Event 8004)" -ForegroundColor Yellow
Write-Host "   Event 8004 = NTLM pass-through auth; generated on DCs when NTLM is used"

$startTime = (Get-Date).AddHours(-$EventLookbackHours)
$ntlmEvents = @()

foreach ($dc in $DomainControllers) {
    try {
        $events = Get-WinEvent -ComputerName $dc -FilterHashtable @{
            LogName   = 'Microsoft-Windows-NTLM/Operational'
            Id        = 8004
            StartTime = $startTime
        } -ErrorAction SilentlyContinue

        if ($events) {
            Write-Host "   $dc`: $($events.Count) NTLM auth events in last $EventLookbackHours hours" -ForegroundColor Yellow

            # Parse source machines from event XML
            $events | ForEach-Object {
                $xml = [xml]$_.ToXml()
                $ntlmEvents += [PSCustomObject]@{
                    DC            = $dc
                    TimeCreated   = $_.TimeCreated
                    SourceMachine = $xml.Event.EventData.Data | Where-Object { $_.Name -eq 'WorkstationName' } | Select-Object -ExpandProperty '#text'
                    UserName      = $xml.Event.EventData.Data | Where-Object { $_.Name -eq 'UserName' } | Select-Object -ExpandProperty '#text'
                }
            }
        } else {
            Write-Host "   $dc`: 0 NTLM events (or NTLM Operational log not enabled)" -ForegroundColor Green
        }
    } catch {
        Write-Host "   $dc`: [SKIP] Cannot query NTLM Operational log — enable via GPO first" -ForegroundColor Gray
    }
}

if ($ntlmEvents.Count -gt 0) {
    Write-Host "`n   Top NTLM-generating machines:" -ForegroundColor Yellow
    $ntlmEvents | Group-Object SourceMachine | Sort-Object Count -Descending | Select-Object -First 10 |
        ForEach-Object { Write-Host "   $($_.Count.ToString().PadLeft(5)) events from: $($_.Name)" }

    $ntlmEvents | Export-Csv -Path ".\NTLMEvents_$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation
    Write-Host "`n   Exported: NTLMEvents_$(Get-Date -Format 'yyyyMMdd').csv" -ForegroundColor Green
}

# --- GPO Recommendation ---
Write-Host "`n3. Recommended GPO Settings" -ForegroundColor Yellow
Write-Host "   Computer Configuration > Windows Settings > Security Settings > Local Policies > Security Options"
Write-Host "   'Network security: LAN Manager authentication level' = Send NTLMv2 response only. Refuse LM & NTLM"
Write-Host "   'Network security: Restrict NTLM: NTLM authentication in this domain' = Deny all"
Write-Host "   Enable NTLM Operational Event Log: HKLM\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters"
Write-Host "   DBFlag = 0x2080FFFF for verbose NTLM auditing (temporary — rotate off after audit)"
