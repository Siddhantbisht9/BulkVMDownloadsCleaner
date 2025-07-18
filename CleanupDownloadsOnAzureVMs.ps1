param (
    [string]$resourceGroupName = "Siddhant"
    #please change the name of the resource group as I was doing it in my enivroment I added my resource group name
)

# Authenticate using Managed Identity
Connect-AzAccount -Identity

# Get subscription ID from environment
$subscriptionId = (Get-AzContext).Subscription.Id
if (-not $subscriptionId) {
    throw "Subscription ID could not be retrieved. Make sure Managed Identity has Reader rights on the subscription."
}

Set-AzContext -SubscriptionId $subscriptionId

Write-Output "Using subscription: $subscriptionId"

# Get all VMs in the resource group
$vms = Get-AzVM -ResourceGroupName $resourceGroupName

foreach ($vm in $vms) {
    Write-Output "Running cleanup check on VM: $($vm.Name)"

    $scriptToRun = @'
# Get disk usage for C drive
$disk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'"
$usedPercent = (($disk.Size - $disk.FreeSpace) / $disk.Size) * 100

Write-Output "Disk usage on C: is $([math]::Round($usedPercent, 2))%"

# Here I have kept the disk usage is greater than or equal to 75% as the threshold for cleanup
# You can change this value as per your requirement  

if ($usedPercent -ge 75) {
    Write-Output "Disk usage exceeds 90%. Proceeding with Downloads folder cleanup."

    $users = Get-ChildItem -Path "C:\Users" -Directory | Where-Object { $_.Name -notin @("Public", "Default", "Default User", "All Users") }

    foreach ($user in $users) {
        $downloads = Join-Path $user.FullName "Downloads"
        if (Test-Path $downloads) {
            Get-ChildItem -Path $downloads -Recurse -Force | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            Write-Output "Deleted contents in: $downloads"
        } else {
            Write-Output "No Downloads folder found for: $($user.Name)"
        }
    }
} else {
    Write-Output "Disk usage is below threshold. No cleanup performed."
}
'@

    try {
        $result = Invoke-AzVMRunCommand `
            -ResourceGroupName $resourceGroupName `
            -Name $vm.Name `
            -CommandId 'RunPowerShellScript' `
            -ScriptString $scriptToRun

        foreach ($output in $result.Value) {
            Write-Output $output.Message
        }
    }
    catch {
        Write-Warning "[$($vm.Name)] Failed to run script: $_"
    }
}
