$ErrorActionPreference = "Stop"
$runbook = Join-Path $PSScriptRoot "../morning-start.ps1"
$subscription = "00000000-0000-0000-0000-000000000001"
$targets = '[{"name":"legacy","resourceGroup":"legacy-rg","kind":"legacy","origin":"https://legacy.test"},{"name":"modern","resourceGroup":"modern-rg","kind":"modern","origin":"https://modern.test"}]'
$encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($targets))
. $runbook -SubscriptionId $subscription -TargetsBase64 $encoded -FunctionsOnly

foreach ($case in @(
    @{ utc = "2026-09-09T09:29:59Z"; expected = $false },
    @{ utc = "2026-09-09T09:30:00Z"; expected = $true },
    @{ utc = "2026-09-09T09:59:59Z"; expected = $true },
    @{ utc = "2026-09-09T10:00:00Z"; expected = $true },
    @{ utc = "2026-09-09T10:59:59Z"; expected = $true },
    @{ utc = "2026-09-09T11:00:00Z"; expected = $false },
    @{ utc = "2026-09-10T02:00:00Z"; expected = $false },
    @{ utc = "2026-09-12T09:30:00Z"; expected = $true },
    @{ utc = "2026-09-13T09:30:00Z"; expected = $true },
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
$validationId = "11111111111111111111111111111111"
$result = [pscustomobject]@{ properties = [pscustomobject]@{
    provisioningState = "Creating"
    instanceView = [pscustomobject]@{
        executionState = "Succeeded"
        exitCode = 0
        output = "SIFAP_STARTUP_VALIDATION=OK`nSIFAP_VALIDATION_ID=$validationId`n"
    }
} }
if (-not (Test-GuestReadiness $result $validationId)) {
    throw "REQ-114: successful execution with pending provisioning was rejected."
}
if (Test-GuestReadiness $result "22222222222222222222222222222222") {
    throw "REQ-114: stale execution was accepted."
}
$result.properties.instanceView.exitCode = 1
if (Test-GuestReadiness $result $validationId) { throw "REQ-114: nonzero exit code was accepted." }
$result.properties.instanceView.exitCode = 0
$result.properties.instanceView.executionState = "Running"
if (Test-GuestReadiness $result $validationId) { throw "REQ-114: running execution was accepted." }
$result.properties.instanceView.executionState = "Succeeded"
$result.properties.instanceView.output = "SIFAP_VALIDATION_ID=$validationId`n"
if (Test-GuestReadiness $result $validationId) { throw "REQ-114: missing health marker was accepted." }
$missing = [pscustomobject]@{ properties = [pscustomobject]@{} }
if (Test-GuestReadiness $missing $validationId) { throw "REQ-114: missing instance view was accepted." }

$TargetsBase64 = $encoded
$Mode = "ValidateOnly"
$script:Deadline = [datetime]::UtcNow.AddMinutes(25)
$script:validatedTargets = @()
function Get-PowerState { param($Target) return "PowerState/running" }
function Invoke-Validation {
    param($Target)
    $script:validatedTargets += $Target.kind
    if ($Target.kind -eq "legacy") { throw "Simulated legacy timeout." }
}
$failed = $false
try { Invoke-Targets @(Get-Targets) | Out-Null } catch { $failed = $true }
if (-not $failed -or ($script:validatedTargets -join ",") -ne "legacy,modern") {
    throw "REQ-114: a legacy failure prevented the modern readiness check or passed the job."
}
function Get-PowerState { param($Target) return "PowerState/deallocated" }
function Invoke-Arm { throw "REQ-115: ValidateOnly attempted an ARM mutation." }
$script:validatedTargets = @()
$failed = $false
try { Invoke-Targets @(Get-Targets) | Out-Null } catch { $failed = $true }
if (-not $failed -or $script:validatedTargets.Count -ne 0) {
    throw "REQ-115: a stopped target was validated or passed the job."
}

foreach ($case in @(
    @{ utc = "2026-09-09T09:59:59Z"; expected = $false },
    @{ utc = "2026-09-09T10:00:00Z"; expected = $true },
    @{ utc = "2026-09-09T21:59:59Z"; expected = $true },
    @{ utc = "2026-09-09T22:00:00Z"; expected = $false },
    @{ utc = "2026-09-10T05:00:00Z"; expected = $false },
    @{ utc = "2026-09-12T14:00:00Z"; expected = $true },
    @{ utc = "2026-09-13T16:00:00Z"; expected = $true }
)) {
    if ((Test-DaytimeWindow ([datetime]$case.utc)) -ne $case.expected) {
        throw "REQ-116: incorrect daytime window for $($case.utc)"
    }
}
$Mode = "Daytime"
if (Test-StartWindow ([datetime]"2026-09-09T05:00:00Z")) {
    throw "REQ-116: daytime recovery would start a VM overnight."
}
if (-not (Test-StartWindow ([datetime]"2026-09-09T16:00:00Z"))) {
    throw "REQ-116: daytime recovery refused a valid working-hours restart."
}
$Mode = "Scheduled"
if (Test-StartWindow ([datetime]"2026-09-09T16:00:00Z")) {
    throw "REQ-113: scheduled startup must stay inside the morning window."
}

$Mode = "Daytime"
$script:Deadline = [datetime]::UtcNow.AddMinutes(25)
function Test-DaytimeWindow { param([datetime] $UtcNow = [datetime]::UtcNow) return $true }
function Get-PowerState {
    param($Target)
    $script:powerCalls++
    if ($script:powerCalls -le 2) { return "PowerState/deallocated" }
    return "PowerState/running"
}
function Invoke-Arm {
    param([string] $Method, [string] $Uri, [string] $Body = "")
    $script:startedTargets += $Uri
    return $null
}
function Invoke-Validation { param($Target) $script:validatedTargets += $Target.kind }
$script:powerCalls = 0
$script:validatedTargets = @()
$script:startedTargets = @()
Invoke-Targets @(Get-Targets) | Out-Null
if (($script:validatedTargets -join ",") -ne "legacy,modern" -or $script:startedTargets.Count -ne 2) {
    throw "REQ-116: a mid-day outage did not restart and revalidate both systems."
}
function Test-DaytimeWindow { param([datetime] $UtcNow = [datetime]::UtcNow) return $false }
$script:powerCalls = 0
$script:validatedTargets = @()
$script:startedTargets = @()
$failed = $false
try { Invoke-Targets @(Get-Targets) | Out-Null } catch { $failed = $true }
if (-not $failed -or $script:startedTargets.Count -ne 0) {
    throw "REQ-116: a stopped VM was started outside the daytime window."
}
Write-Output "Runbook window, target, guest-result, failure-isolation and daytime-recovery tests passed."
