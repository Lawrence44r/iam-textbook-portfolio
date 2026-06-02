<#
.SYNOPSIS
    Script 5-5: Suspicious PowerShell Command Detection
.DESCRIPTION
    Analyzes Script Block Logging (Event 4104) for known attack tool signatures.
    Detects: mimikatz, PowerSploit, AMSI bypass, encoded commands, credential access.
.NOTES
    Requires: Event log access, Script Block Logging must be enabled (Script 5-4)
    Chapter 5 §5.5 — Threat Detection via PowerShell Logging
#>
[CmdletBinding()]
param(
    [int]$LookbackHours  = 24,
    [string[]]$Computers = @($env:COMPUTERNAME),
    [string]$OutputPath  = ".\SuspiciousPSEvents_$(Get-Date -Format 'yyyyMMdd').csv"
)

# Attack signatures: pattern → description → severity
$signatures = @(
    @{ Pattern = 'mimikatz|Invoke-Mimikatz|sekurlsa|lsadump';         Desc = 'Mimikatz / LSASS dump';          Severity = 'CRITICAL' }
    @{ Pattern = 'Invoke-ReflectivePEInjection|Invoke-Shellcode';    Desc = 'Reflective PE injection';         Severity = 'CRITICAL' }
    @{ Pattern = 'amsiInitFailed|AmsiScanBuffer|amsi\.dll';           Desc = 'AMSI bypass attempt';            Severity = 'CRITICAL' }
    @{ Pattern = 'Net\.WebClient.*DownloadString|IEX.*Net\.WebClient';Desc = 'Download + execute cradle';      Severity = 'HIGH' }
    @{ Pattern = 'Get-GPPPassword|Get-CachedGPPPassword';            Desc = 'GPP credential extraction';      Severity = 'HIGH' }
    @{ Pattern = 'Invoke-Kerberoast|Invoke-ASREPRoast';              Desc = 'Kerberoast / AS-REP roast';      Severity = 'HIGH' }
    @{ Pattern = 'DCSync|Get-DomainController.*replication';         Desc = 'DCSync attempt';                 Severity = 'CRITICAL' }
    @{ Pattern = '-EncodedCommand|-enc[^r]';                         Desc = 'Base64 encoded command';         Severity = 'MEDIUM' }
    @{ Pattern = 'Invoke-BloodHound|SharpHound';                     Desc = 'BloodHound AD reconnaissance';  Severity = 'HIGH' }
    @{ Pattern = 'Invoke-SMBExec|Invoke-WMIExec|psexec';            Desc = 'Lateral movement tool';          Severity = 'HIGH' }
    @{ Pattern = 'net\.exe.*user|net\.exe.*group|net\.exe.*localgroup';Desc = 'net.exe user enumeration';    Severity = 'MEDIUM' }
    @{ Pattern = 'vaultcmd|credential.*vault|Windows Vault';         Desc = 'Windows Credential Vault access';Severity = 'HIGH' }
    @{ Pattern = 'ConvertTo-SecureString.*AsPlainText';              Desc = 'Plaintext credential in script'; Severity = 'MEDIUM' }
    @{ Pattern = '\[System\.Runtime\.InteropServices\.Marshal\]';     Desc = 'Memory marshaling (inject)';    Severity = 'HIGH' }
)

Write-Host "`n=== Suspicious PowerShell Command Detection ===" -ForegroundColor Cyan
Write-Host "Lookback: $LookbackHours hours | Signatures: $($signatures.Count) | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

$startTime = (Get-Date).AddHours(-$LookbackHours)
$allFindings = @()

foreach ($computer in $Computers) {
    Write-Host "Scanning: $computer" -ForegroundColor Gray
    try {
        $events = Get-WinEvent -ComputerName $computer -FilterHashtable @{
            LogName   = 'Microsoft-Windows-PowerShell/Operational'
            Id        = 4104
            StartTime = $startTime
        } -ErrorAction SilentlyContinue

        if (-not $events) { Write-Host "  No Event 4104 entries (Script Block Logging may not be enabled)" -ForegroundColor Gray; continue }
        Write-Host "  $($events.Count) script block events to analyze"

        foreach ($event in $events) {
            $xml        = [xml]$event.ToXml()
            $scriptText = $xml.Event.EventData.Data | Where-Object { $_.Name -eq 'ScriptBlockText' } | Select-Object -ExpandProperty '#text'
            $path       = $xml.Event.EventData.Data | Where-Object { $_.Name -eq 'Path' } | Select-Object -ExpandProperty '#text'

            foreach ($sig in $signatures) {
                if ($scriptText -match $sig.Pattern) {
                    $finding = [PSCustomObject]@{
                        Computer    = $computer
                        TimeCreated = $event.TimeCreated
                        Severity    = $sig.Severity
                        Detection   = $sig.Desc
                        ScriptPath  = $path
                        ScriptHash  = (Get-FileHash -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($scriptText)))).Hash
                        ScriptSnip  = ($scriptText -replace "`n",' ').Substring(0, [Math]::Min(200, $scriptText.Length))
                        EventId     = $event.Id
                    }
                    $allFindings += $finding

                    $color = switch ($sig.Severity) { 'CRITICAL' { 'Red' } 'HIGH' { 'Yellow' } default { 'White' } }
                    Write-Host "  [$($sig.Severity)] $($sig.Desc) at $($event.TimeCreated)" -ForegroundColor $color
                    Write-Host "  Path: $path" -ForegroundColor Gray
                    break  # One finding per event; avoid duplicate alerts for same block
                }
            }
        }
    } catch {
        Write-Host "  [ERROR] $computer`: $_" -ForegroundColor Red
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Total findings: $($allFindings.Count)"
$allFindings | Group-Object Severity | ForEach-Object {
    $color = switch ($_.Name) { 'CRITICAL' { 'Red' } 'HIGH' { 'Yellow' } default { 'White' } }
    Write-Host "  $($_.Name): $($_.Count)" -ForegroundColor $color
}

if ($allFindings.Count -gt 0) {
    $allFindings | Sort-Object TimeCreated -Descending | Export-Csv -Path $OutputPath -NoTypeInformation
    Write-Host "`nExported: $OutputPath" -ForegroundColor Green
}
