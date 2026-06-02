<#
.SYNOPSIS
    Script 5-4: PowerShell Enhanced Logging Configuration
.DESCRIPTION
    Configures Script Block Logging (Event 4104), Module Logging (4103),
    and Transcription via registry. Event 4104 captures every PowerShell
    script block executed — critical for detecting living-off-the-land attacks.
.NOTES
    Requires: Local Administrator
    Deploy via GPO in production: Computer Config > Admin Templates > Windows Components > PowerShell
    Chapter 5 §5.5 — PowerShell Logging and Visibility
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Configure,          # Apply settings (default: report only)
    [string]$TranscriptPath = "C:\PSTranscripts",
    [switch]$EnableTranscription = $false
)

$psRegPath    = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell"
$sbLogPath    = "$psRegPath\ScriptBlockLogging"
$modLogPath   = "$psRegPath\ModuleLogging"
$transcPath   = "$psRegPath\Transcription"

function Get-RegistryValue {
    param([string]$Path, [string]$Name)
    try { return (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name }
    catch { return $null }
}

Write-Host "`n=== PowerShell Enhanced Logging Audit ===" -ForegroundColor Cyan
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

# --- Current State ---
Write-Host "CURRENT STATE:" -ForegroundColor Yellow

$sbEnabled  = Get-RegistryValue -Path $sbLogPath -Name "EnableScriptBlockLogging"
$sbInverted = Get-RegistryValue -Path $sbLogPath -Name "EnableScriptBlockInvocationLogging"
$modEnabled = Get-RegistryValue -Path $modLogPath -Name "EnableModuleLogging"
$txEnabled  = Get-RegistryValue -Path $transcPath -Name "EnableTranscripting"

function Show-Setting { param([string]$Name, $Value, $Target = 1)
    $status = if ($Value -eq $Target) { "[OK]" } else { "[MISSING]" }
    $color  = if ($Value -eq $Target) { 'Green' } else { 'Red' }
    Write-Host "  $status $Name = $(if ($null -eq $Value) { 'not set' } else { $Value })" -ForegroundColor $color
}

Show-Setting "Script Block Logging (Event 4104)"         $sbEnabled
Show-Setting "Script Block Invocation Logging (verbose)" $sbInverted
Show-Setting "Module Logging (Event 4103)"               $modEnabled
Show-Setting "Transcription"                             $txEnabled

# Event Log Size
$psLog = Get-WinEvent -ListLog "Microsoft-Windows-PowerShell/Operational" -ErrorAction SilentlyContinue
if ($psLog) {
    $logSizeMB = [math]::Round($psLog.MaximumSizeInBytes / 1MB, 0)
    $sizeColor = if ($logSizeMB -ge 50) { 'Green' } else { 'Yellow' }
    Write-Host "  PS Operational Log size: $logSizeMB MB (recommend: 100+ MB)" -ForegroundColor $sizeColor
}

# --- Apply Configuration ---
if ($Configure -and $PSCmdlet.ShouldProcess("Registry", "Configure PowerShell logging")) {
    Write-Host "`nAPPLYING CONFIGURATION..." -ForegroundColor Yellow

    # Script Block Logging
    New-Item -Path $sbLogPath -Force | Out-Null
    Set-ItemProperty -Path $sbLogPath -Name "EnableScriptBlockLogging"           -Value 1 -Type DWord
    Set-ItemProperty -Path $sbLogPath -Name "EnableScriptBlockInvocationLogging" -Value 1 -Type DWord
    Write-Host "  [SET] Script Block Logging enabled" -ForegroundColor Green

    # Module Logging (log all modules)
    New-Item -Path $modLogPath -Force | Out-Null
    Set-ItemProperty -Path $modLogPath -Name "EnableModuleLogging" -Value 1 -Type DWord
    New-Item -Path "$modLogPath\ModuleNames" -Force | Out-Null
    Set-ItemProperty -Path "$modLogPath\ModuleNames" -Name "*" -Value "*" -Type String
    Write-Host "  [SET] Module Logging enabled for all modules" -ForegroundColor Green

    # Transcription (optional)
    if ($EnableTranscription) {
        New-Item -Path $transcPath -Force | Out-Null
        Set-ItemProperty -Path $transcPath -Name "EnableTranscripting"        -Value 1 -Type DWord
        Set-ItemProperty -Path $transcPath -Name "OutputDirectory"            -Value $TranscriptPath -Type String
        Set-ItemProperty -Path $transcPath -Name "EnableInvocationHeader"     -Value 1 -Type DWord
        New-Item -Path $TranscriptPath -ItemType Directory -Force | Out-Null
        Write-Host "  [SET] Transcription enabled: $TranscriptPath" -ForegroundColor Green
    }

    # Increase event log size
    wevtutil sl "Microsoft-Windows-PowerShell/Operational" /ms:104857600  # 100 MB
    Write-Host "  [SET] PS Operational log size: 100 MB" -ForegroundColor Green

    Write-Host "`n[OK] Configuration applied. Test with: Get-WinEvent -LogName 'Microsoft-Windows-PowerShell/Operational' -MaxEvents 5" -ForegroundColor Green
} elseif (-not $Configure) {
    Write-Host "`nRun with -Configure to apply settings." -ForegroundColor Gray
    Write-Host "GPO Path (production): Computer Config > Admin Templates > Windows Components > Windows PowerShell" -ForegroundColor Gray
}

Write-Host "`nKey Event IDs for detection:" -ForegroundColor Yellow
Write-Host "  4103 - Module logging (parameter details)"
Write-Host "  4104 - Script block logging (full script content) [MOST VALUABLE]"
Write-Host "  4105/4106 - Script block invocation start/stop"
Write-Host "  800  - Pipeline execution details (legacy)"
