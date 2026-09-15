param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern("^[0-9a-fA-F-]{36}$")]
    [string] $SubscriptionId,
    [Parameter(Mandatory = $true)]
    [ValidateLength(1, 4096)]
    [string] $TargetsBase64,
    [ValidateSet("Scheduled", "ValidateOnly", "Daytime")]
    [string] $Mode = "Scheduled",
    [switch] $FunctionsOnly
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$managementEndpoint = "https://management.azure.com"
$apiVersion = "2024-07-01"

function Get-BrasiliaTime {
    param([datetime] $UtcNow = [datetime]::UtcNow)
    try {
        $zone = [TimeZoneInfo]::FindSystemTimeZoneById("America/Sao_Paulo")
    } catch [TimeZoneNotFoundException] {
        $zone = [TimeZoneInfo]::FindSystemTimeZoneById("E. South America Standard Time")
    }
    return [TimeZoneInfo]::ConvertTimeFromUtc(
        [datetime]::SpecifyKind($UtcNow, [DateTimeKind]::Utc), $zone
    )
}

function Test-MorningWindow {
    param([datetime] $UtcNow = [datetime]::UtcNow)
    $local = Get-BrasiliaTime $UtcNow
    return ($local.Hour -eq 6 -and $local.Minute -ge 30) -or $local.Hour -eq 7
}

function Test-DaytimeWindow {
    param([datetime] $UtcNow = [datetime]::UtcNow)
    $local = Get-BrasiliaTime $UtcNow
    return $local.Hour -ge 7 -and $local.Hour -lt 19
}

function Test-StartWindow {
    param([datetime] $UtcNow = [datetime]::UtcNow)
    if ($Mode -eq "Daytime") { return Test-DaytimeWindow $UtcNow }
    return Test-MorningWindow $UtcNow
}

function Get-Targets {
    $json = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($TargetsBase64))
    # PowerShell 5.1 preserva o array JSON como um unico objeto no pipeline.
    $parsed = ConvertFrom-Json -InputObject $json
    $targets = @($parsed | ForEach-Object { $_ })
    if ($targets.Count -ne 2) { throw "Exactly two application targets are required." }
    $kinds = @{}
    foreach ($target in $targets) {
        if ($target.name -notmatch "^[a-zA-Z0-9-]{1,64}$" -or
            $target.resourceGroup -notmatch "^[a-zA-Z0-9._-]{1,90}$" -or
            $target.kind -notin @("legacy", "modern") -or
            $target.origin -notmatch "^https://[a-zA-Z0-9.-]+$") {
            throw "Invalid configured target."
        }
        if ($kinds.ContainsKey($target.kind)) { throw "Duplicate target kind." }
        $kinds[$target.kind] = $true
    }
    return $targets
}

function Get-ManagedIdentityToken {
    if (-not $env:IDENTITY_ENDPOINT -or -not $env:IDENTITY_HEADER) {
        throw "Azure Automation managed identity is unavailable."
    }
    $resource = [Uri]::EscapeDataString("$managementEndpoint/")
    $token = Invoke-RestMethod -Method Get -TimeoutSec 20 `
        -Uri "$($env:IDENTITY_ENDPOINT)?resource=$resource&api-version=2019-08-01" `
        -Headers @{ "X-IDENTITY-HEADER" = $env:IDENTITY_HEADER; "Metadata" = "True" }
    if (-not $token.access_token) { throw "Managed identity returned no token." }
    return $token.access_token
}

function Invoke-Arm {
    param([string] $Method, [string] $Uri, [string] $Body = "")
    if (-not $Uri.StartsWith("$managementEndpoint/")) { throw "Untrusted ARM operation URL." }
    if ([datetime]::UtcNow -gt $script:Deadline) { throw "Morning validation exceeded its 25-minute deadline." }
    if ([datetime]::UtcNow -gt $script:TargetDeadline) {
        throw "Readiness deadline exceeded for $($script:TargetName)."
    }
    $options = @{
        Method = $Method; Uri = $Uri; Headers = $script:ArmHeaders
        TimeoutSec = 45; UseBasicParsing = $true; ErrorAction = "Stop"
    }
    if ($Body) { $options.Body = $Body; $options.ContentType = "application/json" }
    return Invoke-WebRequest @options
}

function Get-VmUri {
    param($Target)
    return "$managementEndpoint/subscriptions/$SubscriptionId/resourceGroups/" +
        "$($Target.resourceGroup)/providers/Microsoft.Compute/virtualMachines/$($Target.name)"
}

function Get-PowerState {
    param($Target)
    $response = Invoke-Arm -Method Get -Uri "$(Get-VmUri $Target)/instanceView?api-version=$apiVersion"
    $view = $response.Content | ConvertFrom-Json
    $power = @($view.statuses | Where-Object { $_.code -like "PowerState/*" })
    if ($power.Count -eq 0) { return "PowerState/unknown" }
    return $power[0].code
}

function Test-GuestReadiness {
    param($Result, [string] $ValidationId)
    $viewProperty = $Result.properties.PSObject.Properties["instanceView"]
    if (-not $viewProperty -or -not $viewProperty.Value) { return $false }
    $view = $viewProperty.Value
    if ($view.executionState -ne "Succeeded" -or $view.exitCode -ne 0) { return $false }
    return $view.output -match "(?m)^SIFAP_STARTUP_VALIDATION=OK\s*$" -and
        $view.output -match "(?m)^SIFAP_VALIDATION_ID=$([regex]::Escape($ValidationId))\s*$"
}

function Test-PublicEndpoints {
    param($Target, [int] $Attempts = 6)
    $paths = if ($Target.kind -eq "modern") { @("/healthz", "/actuator/health") } else { @("/healthz") }
    foreach ($path in $paths) {
        $healthy = $false
        for ($attempt = 0; $attempt -lt $Attempts -and -not $healthy; $attempt++) {
            if ([datetime]::UtcNow -gt $script:Deadline -or [datetime]::UtcNow -gt $script:TargetDeadline) {
                return $false
            }
            try {
                $probe = Invoke-WebRequest -Uri "$($Target.origin)$path" -Method Get -TimeoutSec 15 -UseBasicParsing
                $healthy = $probe.StatusCode -eq 200
            } catch [System.Net.WebException] {
                Write-Warning "Public readiness not available yet for $($Target.name)."
            }
            if (-not $healthy) { Start-Sleep -Seconds 10 }
        }
        if (-not $healthy) { return $false }
    }
    return $true
}

function Invoke-Validation {
    param($Target)
    $scriptPath = if ($Target.kind -eq "legacy") {
        "/opt/sifap/provisioning/verify-startup.sh"
    } else {
        "/opt/sifap-modern/infra/runtime/verify-startup.sh"
    }
    $checkOnly = if ($Mode -eq "ValidateOnly") { " --check-only" } else { "" }
    $validationId = [guid]::NewGuid().ToString("N")
    $expires = ([DateTimeOffset]$script:TargetDeadline).ToUnixTimeSeconds()
    $command = "set -eu; test `$(date +%s) -lt $expires; test -r '$scriptPath'; " +
        "timeout 600 bash '$scriptPath'$checkOnly; printf '\nSIFAP_VALIDATION_ID=$validationId\n'"
    $vm = (Invoke-Arm -Method Get -Uri "$(Get-VmUri $Target)?api-version=$apiVersion").Content | ConvertFrom-Json
    $uri = "$(Get-VmUri $Target)/runCommands/sifap-morning-readiness?api-version=$apiVersion"
    $payload = @{
        location = $vm.location
        properties = @{
            source = @{ script = $command }
            asyncExecution = $true
            timeoutInSeconds = 600
        }
    } | ConvertTo-Json -Depth 5 -Compress
    Invoke-Arm -Method Put -Uri $uri -Body $payload | Out-Null
    Write-Output "Requested guest readiness: $($Target.name)."
    do {
        Start-Sleep -Seconds 10
        $result = (Invoke-Arm -Method Get -Uri "$uri&`$expand=instanceView").Content | ConvertFrom-Json
        $ready = Test-GuestReadiness $result $validationId
        $viewProperty = $result.properties.PSObject.Properties["instanceView"]
        if ($viewProperty -and $viewProperty.Value -and -not $ready) {
            $view = $viewProperty.Value
            if ($view.executionState -in @("Failed", "Canceled", "TimedOut")) {
                throw "Application/database readiness failed for $($Target.name); inspect its managed Run Command."
            }
        }
    } until ($ready)
    if (-not (Test-PublicEndpoints $Target)) {
        throw "Public HTTPS validation failed for $($Target.name)."
    }
    Write-Output "Verified application and database: $($Target.name)."
}

function Invoke-Targets {
    param($Targets)
    $failures = @()
    $started = @()
    foreach ($target in $Targets) {
        $script:TargetName = $target.name
        $script:TargetDeadline = $script:Deadline
        try {
            $state = Get-PowerState $target
            if ($state -eq "PowerState/running") {
                Write-Output "$($target.name) is already running; no restart requested."
            } elseif ($Mode -eq "ValidateOnly") {
                throw "$($target.name) is not running; ValidateOnly never starts a stopped VM."
            } elseif ($state -in @("PowerState/deallocated", "PowerState/stopped")) {
                if (-not (Test-StartWindow)) { throw "Start window ended; no start requested." }
                Invoke-Arm -Method Post -Uri "$(Get-VmUri $target)/start?api-version=$apiVersion" -Body "{}" | Out-Null
                $started += $target.name
                Write-Output "Requested start: $($target.name)."
            } elseif ($state -notin @("PowerState/starting", "PowerState/unknown")) {
                throw "Unexpected VM state; refusing to interfere with a shutdown."
            }
        } catch {
            $failures += $target.name
            Write-Warning "Start check failed for $($target.name): $($_.Exception.Message)"
        }
    }
    foreach ($target in $Targets) {
        if ($target.name -in $failures) { continue }
        $script:TargetName = $target.name
        $script:TargetDeadline = [datetime]::UtcNow.AddMinutes(11)
        try {
            while ((Get-PowerState $target) -ne "PowerState/running") {
                Start-Sleep -Seconds 15
            }
            if ($Mode -ne "ValidateOnly" -and -not (Test-StartWindow)) { throw "Availability window ended." }
            if ($Mode -eq "Daytime" -and $target.name -notin $started -and
                (Test-PublicEndpoints $target -Attempts 2)) {
                Write-Output "$($target.name) is serving its public endpoints; no recovery needed."
            } else {
                Invoke-Validation $target
            }
        } catch {
            $failures += $target.name
            Write-Warning "Readiness failed for $($target.name): $($_.Exception.Message)"
        }
    }
    if ($failures.Count -gt 0) { throw "SIFAP readiness failed: $($failures -join ', ')." }
}

if ($FunctionsOnly) { return }
$targets = @(Get-Targets)
if ($Mode -eq "Scheduled" -and -not (Test-MorningWindow)) {
    throw "Outside the 06:30-08:00 Brasilia start window; no start requested."
}
if ($Mode -eq "Daytime" -and -not (Test-DaytimeWindow)) {
    Write-Output "Outside the 07:00-19:00 Brasilia daytime window; the nightly shutdown is preserved."
    return
}
$script:Deadline = [datetime]::UtcNow.AddMinutes(25)
$accessToken = Get-ManagedIdentityToken
$script:ArmHeaders = @{}
$script:ArmHeaders.Add("Authorization", [string]::Concat("Bearer ", $accessToken))
try {
    Invoke-Targets $targets
    Write-Output "SIFAP_MORNING_VALIDATION=OK"
} finally {
    $accessToken = $null
    $script:ArmHeaders.Clear()
}
