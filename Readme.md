# BulkVMDownloadsCleaner

Automatically cleans the `Downloads` folder across all Azure VMs in a Resource Group when disk usage on the C: drive exceeds **75%**. Runs remotely via **Azure Automation** + **Run Command** — no RDP or agent required.

---

## How It Works

1. Authenticates to Azure using **Managed Identity** (no credentials stored).
2. Retrieves all VMs in the specified Resource Group.
3. For each VM, uses `Invoke-AzVMRunCommand` to execute an inline PowerShell script that:
   - Checks C: drive usage via `Win32_LogicalDisk`.
   - If usage is **≥ 75%**, deletes all files and folders inside every user's `Downloads` folder (skipping system accounts like `Public`, `Default`).
   - Outputs the result per VM to the Automation Job log.

---

## Prerequisites

| Requirement | Details |
|---|---|
| Azure Automation Account | With a **System-assigned Managed Identity** enabled |
| Managed Identity RBAC | `Virtual Machine Contributor` (or `Contributor`) on the Resource Group |
| Az PowerShell modules | `Az.Accounts`, `Az.Compute` — import into the Automation Account |
| Target VMs | Windows VMs with C: drive, reachable via Run Command |

---

## Usage

### Run from Azure Automation Runbook

1. Import `CleanupDownloadsOnAzureVMs.ps1` as a PowerShell Runbook.
2. Enable **System-assigned Managed Identity** on the Automation Account.
3. Grant the Managed Identity `Virtual Machine Contributor` on the target Resource Group.
4. Import `Az.Accounts` and `Az.Compute` modules into the Automation Account.
5. Set the `resourceGroupName` parameter when running the job:

```
resourceGroupName = "your-resource-group-name"
```

### Run Locally (with Az CLI authenticated)

```powershell
.\CleanupDownloadsOnAzureVMs.ps1 -resourceGroupName "your-resource-group-name"
```

> Make sure you are logged in via `Connect-AzAccount` and have the required permissions.

---

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `resourceGroupName` | `"name of your resource group"` | The Azure Resource Group containing the target VMs |

---

## Threshold

The cleanup threshold is set to 75% disk usage on C:. To change it, edit line 35 of the script:

```powershell
if ($usedPercent -ge 75) {
```

---

## Output Example

```
Using subscription: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Running cleanup check on VM: vm-prod-01
Disk usage on C: is 82.31%
Disk usage exceeds 75%. Proceeding with Downloads folder cleanup.
Deleted contents in: C:\Users\AdminUser\Downloads
Running cleanup check on VM: vm-prod-02
Disk usage on C: is 61.10%
Disk usage is below threshold. No cleanup performed.
```

---

## Security Notes

- Uses **Managed Identity** — no passwords or secrets in the script.
- Skips system profiles (`Public`, `Default`, `Default User`, `All Users`).
- Errors on individual VMs are caught and logged as warnings without stopping the entire run.

---

## Author

**Siddhant Bisht** — [GitHub](https://github.com/siddhantbisht9)
