param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern("^[0-9a-fA-F-]{36}$")]
    [string] $SubscriptionId,
    [Parameter(Mandatory = $true)]
    [ValidateLength(1, 4096)]
    [string] $TargetsBase64,
    [ValidateSet("Scheduled", "ValidateOnly")]
    [string] $Mode = "Scheduled",
    [switch] $FunctionsOnly
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$managementEndpoint = "https://management.azure.com"
$apiVersion = "2024-07-01"

function Test-MorningWindow {
    param([datetime] $UtcNow = [datetime]::UtcNow)
    try {
        $zone = [TimeZoneInfo]::FindSystemTimeZoneById("America/Sao_Paulo")
    } catch [TimeZoneNotFoundException] {
        $zone = [TimeZoneInfo]::FindSystemTimeZoneById("E. South America Standard Time")
    }
    $local = [TimeZoneInfo]::ConvertTimeFromUtc(
        [datetime]::SpecifyKind($UtcNow, [DateTimeKind]::Utc), $zone
    )
    return $local.Hour -eq 7
}

function Get-Targets {
    $json = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($TargetsBase64))
    $targets = @($json | ConvertFrom-Json)
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

function Invoke-Validation {
    param($Target)
    $scriptPath = if ($Target.kind -eq "legacy") {
        "/opt/sifap/provisioning/verify-startup.sh"
    } else {
        "/opt/sifap-modern/infra/runtime/verify-startup.sh"
    }
    $checkOnly = if ($Mode -eq "ValidateOnly") { " --check-only" } else { "" }
    $command = "set -eu; test -r '$scriptPath'; timeout 600 bash '$scriptPath'$checkOnly"
    $payload = @{ commandId = "RunShellScript"; script = @($command) } | ConvertTo-Json -Compress
    $response = Invoke-Arm -Method Post -Uri "$(Get-VmUri $Target)/runCommand?api-version=$apiVersion" -Body $payload
    $location = [string](@($response.Headers["Location"])[0])
    $async = [string](@($response.Headers["Azure-AsyncOperation"])[0])
    if ($response.StatusCode -eq 202) {
        if (-not $location -or -not $async) { throw "Run Command did not provide result locations." }
        do {
            Start-Sleep -Seconds 10
            $operation = (Invoke-Arm -Method Get -Uri $async).Content | ConvertFrom-Json
            if ($operation.status -in @("Failed", "Canceled")) {
                throw "Guest validation operation failed for $($Target.name)."
            }
        } until ($operation.status -eq "Succeeded")
        $response = Invoke-Arm -Method Get -Uri $location
    }
    $result = $response.Content | ConvertFrom-Json
    $stdout = ($result.value | Where-Object { $_.code -like "*/StdOut/*" } |
        ForEach-Object { $_.message }) -join "`n"
    if ($stdout -notmatch "(?m)^SIFAP_STARTUP_VALIDATION=OK\s*$") {
        throw "Application/database readiness failed for $($Target.name); inspect its Run Command."
    }
    foreach ($path in @("/healthz", $(if ($Target.kind -eq "modern") { "/actuator/health" } else { "/healthz" })) | Select-Object -Unique) {
        $healthy = $false
        for ($attempt = 0; $attempt -lt 6 -and -not $healthy; $attempt++) {
            if ([datetime]::UtcNow -gt $script:Deadline) { throw "Public readiness deadline exceeded." }
            try {
                $probe = Invoke-WebRequest -Uri "$($Target.origin)$path" -Method Get -TimeoutSec 15 -UseBasicParsing
                $healthy = $probe.StatusCode -eq 200
            } catch [System.Net.WebException] {
                Write-Warning "Public readiness not available yet for $($Target.name)."
            }
            if (-not $healthy) { Start-Sleep -Seconds 10 }
        }
        if (-not $healthy) { throw "Public HTTPS validation failed for $($Target.name)." }
    }
    Write-Output "Verified application and database: $($Target.name)."
}

if ($FunctionsOnly) { return }
$targets = @(Get-Targets)
if ($Mode -eq "Scheduled" -and -not (Test-MorningWindow)) {
    throw "Outside the 07:00-08:00 Brasilia start window; no start requested."
}
$script:Deadline = [datetime]::UtcNow.AddMinutes(25)
$accessToken = Get-ManagedIdentityToken
$script:ArmHeaders = @{}
$script:ArmHeaders.Add("Authorization", [string]::Concat("Bearer ", $accessToken))
try {
    foreach ($target in $targets) {
        $state = Get-PowerState $target
        if ($state -eq "PowerState/running") {
            Write-Output "$($target.name) is already running; no restart requested."
        } elseif ($Mode -eq "ValidateOnly") {
            throw "$($target.name) is not running; ValidateOnly never starts a stopped VM."
        } elseif ($state -in @("PowerState/deallocated", "PowerState/stopped")) {
            if (-not (Test-MorningWindow)) { throw "Morning start window ended." }
            Invoke-Arm -Method Post -Uri "$(Get-VmUri $target)/start?api-version=$apiVersion" -Body "{}" | Out-Null
            Write-Output "Requested morning start: $($target.name)."
        } elseif ($state -notin @("PowerState/starting", "PowerState/unknown")) {
            throw "Unexpected VM state; refusing to interfere with a shutdown."
        }
    }
    foreach ($target in $targets) {
        while ((Get-PowerState $target) -ne "PowerState/running") {
            Start-Sleep -Seconds 15
        }
        if ($Mode -eq "Scheduled" -and -not (Test-MorningWindow)) { throw "Morning validation window ended." }
        Invoke-Validation $target
    }
    Write-Output "SIFAP_MORNING_VALIDATION=OK"
} finally {
    $accessToken = $null
    $script:ArmHeaders.Clear()
}
