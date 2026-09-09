$ErrorActionPreference = "Stop"
$runbook = Join-Path $PSScriptRoot "../morning-start.ps1"
$subscription = "00000000-0000-0000-0000-000000000001"
$targets = '[{"name":"legacy","resourceGroup":"legacy-rg","kind":"legacy","origin":"https://legacy.test"},{"name":"modern","resourceGroup":"modern-rg","kind":"modern","origin":"https://modern.test"}]'
$encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($targets))
. $runbook -SubscriptionId $subscription -TargetsBase64 $encoded -FunctionsOnly

foreach ($case in @(
    @{ utc = "2026-09-09T09:59:59Z"; expected = $false },
    @{ utc = "2026-09-09T10:00:00Z"; expected = $true },
    @{ utc = "2026-09-09T10:59:59Z"; expected = $true },
    @{ utc = "2026-09-09T11:00:00Z"; expected = $false },
    @{ utc = "2026-09-10T02:00:00Z"; expected = $false },
    @{ utc = "2026-09-12T10:00:00Z"; expected = $true }
)) {
    if ((Test-MorningWindow ([datetime]$case.utc)) -ne $case.expected) {
        throw "REQ-113: incorrect Brasilia window for $($case.utc)"
    }
}
if (@(Get-Targets).Count -ne 2) { throw "Target validation failed." }
$invalid = '[{"name":"x","resourceGroup":"rg","kind":"legacy","origin":"https://x.test"},{"name":"y","resourceGroup":"rg","kind":"legacy","origin":"https://y.test"}]'
$TargetsBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($invalid))
$rejected = $false
try { Get-Targets | Out-Null } catch { $rejected = $true }
if (-not $rejected) { throw "Duplicate targets were accepted." }
foreach ($code in @("ProvisioningState/succeeded", "ComponentStatus/StdOut/succeeded")) {
    $result = [pscustomobject]@{ value = @([pscustomobject]@{
        code = $code
        message = "Enable succeeded:`n[stdout]`nSIFAP_STARTUP_VALIDATION=OK`n[stderr]`n"
    }) }
    if (-not (Test-GuestReadiness $result)) { throw "REQ-114: valid guest result was rejected." }
}
$failed = [pscustomobject]@{ value = @([pscustomobject]@{
    code = "ProvisioningState/succeeded"
    message = "Enable succeeded:`n[stderr]`nDatabase health failed."
}) }
if (Test-GuestReadiness $failed) { throw "REQ-114: guest failure was accepted." }
Write-Output "11 runbook time-window, target and guest-result tests passed."
