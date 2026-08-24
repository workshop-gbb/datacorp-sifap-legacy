param(
    [Parameter(Mandatory = $true)]
    [string] $SubscriptionId,
    [Parameter(Mandatory = $true)]
    [string] $ResourceGroup,
    [Parameter(Mandatory = $true)]
    [string] $VirtualMachineNames
)

$ErrorActionPreference = "Stop"

$vmNames = $VirtualMachineNames.Split(
    ",",
    [System.StringSplitOptions]::RemoveEmptyEntries
) | ForEach-Object { $_.Trim() }
if ($vmNames.Count -eq 0) {
    throw "VirtualMachineNames contains no VM names."
}

$apiVersion = "2024-07-01"
$managementEndpoint = "https://management.azure.com"
$expectedState = "PowerState/running"
$maxAttempts = 40
$pollSeconds = 15

function Get-ManagedIdentityToken {
    if (-not $env:IDENTITY_ENDPOINT -or -not $env:IDENTITY_HEADER) {
        throw "Azure Automation did not expose the managed identity endpoint."
    }

    $resource = [Uri]::EscapeDataString("$managementEndpoint/")
    $tokenUri = "$($env:IDENTITY_ENDPOINT)?resource=$resource&api-version=2019-08-01"
    $token = Invoke-RestMethod `
        -Method Get `
        -Uri $tokenUri `
        -Headers @{
            "X-IDENTITY-HEADER" = $env:IDENTITY_HEADER
            "Metadata" = "True"
        }

    if (-not $token.access_token) {
        throw "The managed identity endpoint returned no access token."
    }
    return $token.access_token
}

function Get-VmPowerState {
    param(
        [Parameter(Mandatory = $true)]
        [string] $VmName,
        [Parameter(Mandatory = $true)]
        [hashtable] $Headers
    )

    $uri = "$managementEndpoint/subscriptions/$SubscriptionId/resourceGroups/" +
        "$ResourceGroup/providers/Microsoft.Compute/virtualMachines/$VmName/" +
        "instanceView?api-version=$apiVersion"
    $view = Invoke-RestMethod -Method Get -Uri $uri -Headers $Headers
    $status = $view.statuses |
        Where-Object { $_.code -like "PowerState/*" } |
        Select-Object -First 1

    if (-not $status.code) {
        # During a start transition Azure can return a valid instanceView with
        # no PowerState entry for a few seconds. Treat that as a state to poll,
        # not as a failed GET. A missing VM or denied request still throws from
        # Invoke-RestMethod above.
        return "PowerState/unknown"
    }
    return $status.code
}

function Start-Vm {
    param(
        [Parameter(Mandatory = $true)]
        [string] $VmName,
        [Parameter(Mandatory = $true)]
        [hashtable] $Headers
    )

    $uri = "$managementEndpoint/subscriptions/$SubscriptionId/resourceGroups/" +
        "$ResourceGroup/providers/Microsoft.Compute/virtualMachines/$VmName/" +
        "start?api-version=$apiVersion"
    Invoke-RestMethod `
        -Method Post `
        -Uri $uri `
        -Headers $Headers `
        -ContentType "application/json" `
        -Body "{}" | Out-Null
}

$accessToken = Get-ManagedIdentityToken
$headers = @{ "Authorization" = "Bearer $accessToken" }

foreach ($vmName in $vmNames) {
    $state = Get-VmPowerState -VmName $vmName -Headers $headers
    if ($state -eq $expectedState) {
        Write-Output "$vmName is already running."
        continue
    }

    Write-Output "$vmName is $state; requesting start."
    Start-Vm -VmName $vmName -Headers $headers
}

for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
    $states = @{}
    $allRunning = $true

    foreach ($vmName in $vmNames) {
        $state = Get-VmPowerState -VmName $vmName -Headers $headers
        $states[$vmName] = $state
        if ($state -ne $expectedState) {
            $allRunning = $false
        }
    }

    if ($allRunning) {
        Write-Output "Verified running: $($vmNames -join ', ')"
        return
    }

    Write-Output (
        "Attempt $attempt/${maxAttempts}: " +
        (($vmNames | ForEach-Object { "$_=$($states[$_])" }) -join ", ")
    )
    if ($attempt -lt $maxAttempts) {
        Start-Sleep -Seconds $pollSeconds
    }
}

throw "One or more SIFAP lab VMs did not reach $expectedState."
