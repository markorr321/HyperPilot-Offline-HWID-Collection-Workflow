# 🚀 HyperPilot HWID Collection Workflow

Automated workflow for collecting AutoPilot Hardware ID (HWID) files from Hyper-V virtual machines. 💻✨

## 📋 Overview

This PowerShell-based automation tool streamlines the process of collecting AutoPilot HWID CSV files from VMs running in Hyper-V. It handles the entire workflow from copying scripts to the VM, waiting for execution, and retrieving the generated CSV files.

## ✨ Features

- 📤 **Automated Script Deployment** - Copies HWID collection batch scripts directly to VMs via Hyper-V Guest Services
- 🖱️ **Interactive VM Selection** - Displays all available VMs with their current state, CPU usage, and memory allocation
- 🔐 **Automatic Elevation** - Self-elevates to Administrator privileges when needed
- 🎮 **Smart VM Management** - Automatically starts, stops, and restarts VMs as required
- 💾 **VHD Mounting** - Safely mounts VM virtual hard drives in read-only mode to extract files
- 🔧 **PowerShell Version Detection** - Works with both Windows PowerShell and PowerShell 7
- 🛡️ **Comprehensive Error Handling** - Includes retry logic and detailed status messages throughout the process

## 📦 Requirements

- 🪟 Windows OS with Hyper-V enabled
- 🔑 Administrator privileges (script will auto-elevate)
- ⚡ PowerShell 5.1 or higher (PowerShell 7 recommended)
- 🔌 Hyper-V Guest Services enabled on target VMs
- 📄 AutoPilot HWID Collection batch script (`AutoPilotHWID-Collection.bat`)

## 📥 Installation

1. Clone this repository:
   ```powershell
   git clone https://github.com/yourusername/HyperPilot-HWID-Workflow.git
   cd HyperPilot-HWID-Workflow
   ```

2. Ensure you have the AutoPilot HWID collection script:
   ```
   C:\Autopilot HWID Collection\AutoPilotHWID-Collection.bat
   ```

## 📂 Output Folder Configuration

By default, collected HWID files are saved to:
```
C:\Autopilot HWID Collection
```

You have two options to set this up:

### Option 1: Create the Default Folder ✅ (Recommended)

Simply create the folder before running the script:
```powershell
New-Item -Path "C:\Autopilot HWID Collection" -ItemType Directory -Force
```

Or manually create the folder `Autopilot HWID Collection` in your C:\ drive.

### Option 2: Customize the Output Path 🔧

Modify the script to use a different location by editing line 24 in `HyperPilot-HWID-Workflow.ps1`:

```powershell
# Change this line:
[string]$DestinationPath = "C:\Autopilot HWID Collection"

# To your preferred path:
[string]$DestinationPath = "C:\YourCustomFolder"
```

Or use the `-DestinationPath` parameter when running the script (see Advanced Usage below).

> **Note:** The script will automatically create the destination folder if it doesn't exist, but you may want to pre-create it with appropriate permissions.

## 🎯 Usage

### ⚡ Quick Start (Batch File)

Simply double-click `HyperPilot-HWID-Workflow.bat` to launch the workflow with default settings.

### 💻 PowerShell Direct

```powershell
.\HyperPilot-HWID-Workflow.ps1
```

### 🔧 Advanced Usage with Parameters

```powershell
# Specify a specific VM
.\HyperPilot-HWID-Workflow.ps1 -VMName "Windows11-VM"

# Customize file search pattern
.\HyperPilot-HWID-Workflow.ps1 -SearchPattern "HWID*.csv"

# Specify custom source folder on VM
.\HyperPilot-HWID-Workflow.ps1 -SourceFolder "Documents"

# Custom destination path for collected files
.\HyperPilot-HWID-Workflow.ps1 -DestinationPath "D:\CollectedHWID"

# Combine multiple parameters
.\HyperPilot-HWID-Workflow.ps1 -VMName "TestVM" -DestinationPath "C:\Output"
```

## 🔄 Workflow Process

The script performs the following steps automatically:

### 📤 Phase 1: Copy Scripts TO VM
1. Lists all available VMs (if no VM name provided)
2. Displays VM status, CPU usage, and memory
3. Starts the VM if not already running
4. Enables Hyper-V Guest Services
5. Copies the HWID collection script(s) to the VM

### ⏸️ Phase 2: Manual Execution
- Pauses and prompts you to run the batch file on the VM
- Wait for the script to complete on the VM
- Press Enter to continue to Phase 3

### 📥 Phase 3: Collect Files FROM VM
1. Stops the VM safely
2. Mounts the VM's VHD in read-only mode
3. Assigns a temporary drive letter
4. Searches for HWID CSV files
5. Copies the newest HWID file to the destination
6. Dismounts the VHD
7. Restarts the VM

## ⚙️ Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `VMName` | String | _(Interactive)_ | Name of the target VM. If not provided, displays a selection menu |
| `FilesToCopy` | String[] | `AutoPilotHWID-Collection.bat` | Array of files to copy to the VM |
| `SearchPattern` | String | `AutoPilotHWID*` | File search pattern for collecting files from VM |
| `SourceFolder` | String | `HWID` | Folder on the VM to search for HWID files |
| `DestinationPath` | String | `C:\Autopilot HWID Collection` | Local destination for collected files |

## 📊 Output

Upon successful completion, the script displays:
- Number of files copied to the VM
- Number of files collected from the VM
- Location of collected HWID files
- Final VM status

Example:
```
================================================================================
  WORKFLOW COMPLETE
================================================================================
VM Name:              Windows11-Dev
Files Copied TO VM:   1
Files Collected:      1
Collection Location:  C:\Autopilot HWID Collection
VM Status:            Running
================================================================================

✓ SUCCESS: Workflow completed successfully!
Your HWID files are ready at: C:\Autopilot HWID Collection
```

## 🛡️ Error Handling

The script includes comprehensive error handling:
- **VM Not Found** - Validates VM exists before proceeding
- **Guest Services** - Automatically enables and verifies Hyper-V Guest Services
- **VHD Mount Retries** - Attempts VHD mounting up to 3 times with delays
- **Drive Letter Assignment** - Finds available drive letters and verifies accessibility
- **Timeout Protection** - Includes timeouts for VM start/stop operations

## 🔍 Troubleshooting

### 🔌 Guest Services Issues
If files fail to copy to the VM:
1. Ensure Hyper-V Guest Services are enabled on the VM
2. Verify the VM is fully booted and responsive
3. Check that the VM has sufficient disk space

### 💾 VHD Mount Failures
If VHD mounting fails:
1. Ensure no other processes are accessing the VHD
2. Wait a few seconds and retry
3. Manually dismount stuck VHDs: `Dismount-VHD -Path "path\to\disk.vhdx"`

### 📁 No Files Found
If no HWID files are found:
1. Verify the AutoPilot script ran successfully on the VM
2. Check the `SourceFolder` parameter matches where files were saved
3. Confirm the `SearchPattern` matches your file naming

## 📜 License

This project is provided as-is for AutoPilot HWID collection workflows.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 👨‍💻 Author

Created for streamlining AutoPilot HWID collection in Hyper-V environments.
