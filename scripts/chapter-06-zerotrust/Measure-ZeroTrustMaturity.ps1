<#
.SYNOPSIS
    Script 6-6: Zero Trust Maturity Self-Assessment (CISA Model)
.DESCRIPTION
    Interactive 5-pillar CISA Zero Trust Maturity Model self-assessment.
    Pillars: Identity, Device, Network, Application, Data
    Scoring: Traditional (0) / Advanced (1) / Optimal (2) per control
    Outputs: Maturity JSON for trend tracking + priority roadmap
.NOTES
    Reference: CISA Zero Trust Maturity Model v2.0
    Chapter 6 §6.2 — CISA ZT Maturity Model
#>
[CmdletBinding()]
param(
    [string]$OutputJson = ".\ZTMaturity_$(Get-Date -Format 'yyyyMMdd').json",
    [switch]$NonInteractive  # Use preset answers for automation/demo
)

# Controls per pillar: [Description, Traditional, Advanced, Optimal]
$controls = @{
    Identity = @(
        @("MFA coverage for all users", "No MFA or partial", "MFA for most users", "Phishing-resistant MFA for all users")
        @("Centralized identity provider", "Multiple siloed IdPs", "Federated IdPs", "Single authoritative IdP with full lifecycle")
        @("Privileged access management", "Shared credentials, no PAM", "PAM tool, manual JIT", "Full JIT, no standing access, session recording")
        @("Conditional Access / risk-based auth", "No CA policies", "Basic CA (MFA, device)", "Risk-based CA with IP/behavior signals")
        @("Identity governance / access certifications", "Manual, infrequent", "Annual certifications", "Automated quarterly + just-in-time provisioning")
    )
    Device = @(
        @("Device inventory", "No authoritative inventory", "Partial MDM enrollment", "100% devices enrolled, real-time inventory")
        @("Device compliance enforcement", "No compliance checks", "Compliance checked at login", "Continuous compliance; non-compliant blocked in real time")
        @("Endpoint detection and response", "Antivirus only", "EDR on managed devices", "EDR on all devices + behavioral analytics + automated response")
        @("Patch management", "Manual, irregular", "Monthly patching cycle", "Automated patching, <7 day SLA for critical")
    )
    Network = @(
        @("Network segmentation", "Flat network / perimeter only", "VLAN segmentation", "Micro-segmentation, app-level controls")
        @("Encrypted traffic", "Internal traffic unencrypted", "HTTPS external only", "All traffic encrypted (mTLS internal)")
        @("Remote access model", "VPN (implicit trust)", "VPN + MFA", "ZTNA / App Proxy (verify every request)")
        @("Traffic inspection", "No inspection", "Perimeter inspection only", "All traffic inspected, east-west monitored")
    )
    Application = @(
        @("Application inventory", "No inventory", "Partial app catalog", "Full catalog with risk classification")
        @("Application authentication", "Mixed auth, many legacy", "SSO for most apps", "SSO for all + legacy apps via proxy")
        @("Least privilege access to apps", "Broad access groups", "Role-based groups", "ABAC / just-in-time app access")
        @("Application security testing", "No regular testing", "Annual pen test", "Continuous SAST/DAST + bug bounty")
    )
    Data = @(
        @("Data classification", "No classification", "Manual classification policy", "Automated classification + sensitivity labels")
        @("Data access controls", "File share permissions", "DLP policy (partial)", "Policy-enforced access based on classification + context")
        @("Data loss prevention", "No DLP", "Email DLP", "DLP across endpoints, cloud apps, email")
        @("Encryption at rest", "Selective encryption", "Encryption for sensitive data", "All data encrypted at rest with managed keys")
    )
}

$scores    = @{}
$allScores = @()
$now       = Get-Date

Write-Host "`n=== CISA Zero Trust Maturity Self-Assessment ===" -ForegroundColor Cyan
Write-Host "Rate each control: 0=Traditional, 1=Advanced, 2=Optimal`n"

foreach ($pillar in $controls.Keys) {
    Write-Host "`n--- PILLAR: $($pillar.ToUpper()) ---" -ForegroundColor Yellow
    $pillarScore = 0
    $pillarMax   = 0

    foreach ($control in $controls[$pillar]) {
        $desc        = $control[0]
        $traditional = $control[1]
        $advanced    = $control[2]
        $optimal     = $control[3]

        Write-Host "`n  Control: $desc"
        Write-Host "    0 = Traditional: $traditional" -ForegroundColor Red
        Write-Host "    1 = Advanced:    $advanced"    -ForegroundColor Yellow
        Write-Host "    2 = Optimal:     $optimal"     -ForegroundColor Green

        $score = $null
        if ($NonInteractive) {
            $score = 1   # Default to Advanced for demo
        } else {
            while ($null -eq $score) {
                $input = Read-Host "    Your score (0/1/2)"
                if ($input -in '0','1','2') { $score = [int]$input }
                else { Write-Host "    Enter 0, 1, or 2" -ForegroundColor Gray }
            }
        }

        $pillarScore += $score
        $pillarMax   += 2
        $allScores   += [PSCustomObject]@{
            Pillar  = $pillar
            Control = $desc
            Score   = $score
            Max     = 2
            Level   = switch ($score) { 0 { 'Traditional' } 1 { 'Advanced' } 2 { 'Optimal' } }
        }
    }

    $pillarPct = [math]::Round(($pillarScore / $pillarMax) * 100)
    $pillarLevel = if ($pillarPct -ge 80) { 'Optimal' } elseif ($pillarPct -ge 50) { 'Advanced' } else { 'Traditional' }
    $scores[$pillar] = @{ Score = $pillarScore; Max = $pillarMax; Pct = $pillarPct; Level = $pillarLevel }

    $color = if ($pillarPct -ge 80) { 'Green' } elseif ($pillarPct -ge 50) { 'Yellow' } else { 'Red' }
    Write-Host "`n  $pillar SCORE: $pillarScore/$pillarMax ($pillarPct%) — $pillarLevel" -ForegroundColor $color
}

# Overall score
$totalScore = ($scores.Values | ForEach-Object { $_.Score } | Measure-Object -Sum).Sum
$totalMax   = ($scores.Values | ForEach-Object { $_.Max }   | Measure-Object -Sum).Sum
$overallPct = [math]::Round(($totalScore / $totalMax) * 100)

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "  OVERALL ZT MATURITY: $overallPct% ($totalScore/$totalMax)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Priority roadmap: lowest-scoring controls
Write-Host "`nPRIORITY ROADMAP (lowest scores first):" -ForegroundColor Yellow
$allScores | Where-Object { $_.Score -lt 2 } | Sort-Object Score, Pillar |
    Select-Object -First 10 |
    ForEach-Object { Write-Host "  [$($_.Pillar)] $($_.Control) — currently: $($_.Level)" }

# Export JSON
$output = @{
    Timestamp    = $now.ToString('o')
    OverallScore = $overallPct
    TotalPoints  = "$totalScore/$totalMax"
    Pillars      = $scores
    Controls     = $allScores
}
$output | ConvertTo-Json -Depth 5 | Out-File $OutputJson -Encoding UTF8
Write-Host "`nJSON exported: $OutputJson (use for trend tracking across assessments)" -ForegroundColor Green
