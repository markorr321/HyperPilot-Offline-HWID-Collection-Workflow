# HyperPilot AutoPilot HWID Collection Workflow
# Complete workflow for collecting AutoPilot HWID from HyperPilot VMs
# This script handles the entire process:
# 1. Copy batch scripts TO VM
# 2. Wait for you to run the scripts on the VM
# 3. Copy generated CSV files FROM VM

param(
    [Parameter(Mandatory=$false)]
    [string]$VMName,
    
    [Parameter(Mandatory=$false)]
    [string[]]$FilesToCopy = @(
        "C:\Autopilot HWID Collection\AutoPilotHWID-Collection.bat"
    ),
    
    [Parameter(Mandatory=$false)]
    [string]$SearchPattern = "AutoPilotHWID*",
    
    [Parameter(Mandatory=$false)]
    [string]$SourceFolder = "HWID",
    
    [Parameter(Mandatory=$false)]
    [string]$DestinationPath = "C:\Autopilot HWID Collection"
)

# Separator line
$separator = "=" * 80

# Auto-elevate to Administrator if not already
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Elevating to Administrator..." -ForegroundColor Yellow
    
    # Detect PowerShell version and use appropriate executable
    $psExe = if ($PSVersionTable.PSEdition -eq "Core") { "pwsh.exe" } else { "powershell.exe" }
    
    # Build argument list for parameters
    $argList = @("-NoExit", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
    if ($VMName) { $argList += @("-VMName", "`"$VMName`"") }
    if ($SearchPattern -ne "AutoPilotHWID*") { $argList += @("-SearchPattern", "`"$SearchPattern`"") }
    if ($SourceFolder -ne "HWID") { $argList += @("-SourceFolder", "`"$SourceFolder`"") }
    if ($DestinationPath -ne "C:\Autopilot HWID Collection") { $argList += @("-DestinationPath", "`"$DestinationPath`"") }
    
    # Relaunch as administrator with same PowerShell version
    Start-Process $psExe -ArgumentList $argList -Verb RunAs
    
    # Force close the non-admin window
    [Environment]::Exit(0)
}

Write-Host "`n$separator" -ForegroundColor Cyan
Write-Host "  HyperPilot HWID Collection Workflow" -ForegroundColor Cyan
Write-Host "$separator" -ForegroundColor Cyan

# ============================================================================
# STEP 1: SELECT VM
# ============================================================================

if (-not $VMName) {
    $vms = Get-VM | Select-Object Name, State, CPUUsage, MemoryAssigned, Uptime
    
    if ($vms.Count -eq 0) {
        Write-Error "No VMs found"
        exit 1
    }
    
    Write-Host "`nAvailable VMs:" -ForegroundColor Cyan
    Write-Host "$separator" -ForegroundColor Cyan
    
    for ($i = 0; $i -lt $vms.Count; $i++) {
        $vm = $vms[$i]
        $memoryGB = [math]::Round($vm.MemoryAssigned / 1GB, 2)
        Write-Host ("  [{0}] {1,-30} State: {2,-10} CPU: {3}% Memory: {4}GB" -f 
            ($i + 1), 
            $vm.Name, 
            $vm.State, 
            $vm.CPUUsage, 
            $memoryGB) -ForegroundColor Yellow
    }
    
    Write-Host "$separator" -ForegroundColor Cyan
    
    do {
        $selection = Read-Host "`nSelect VM number (1-$($vms.Count))"
        $selectionNum = 0
        $validSelection = [int]::TryParse($selection, [ref]$selectionNum) -and 
                         $selectionNum -ge 1 -and 
                         $selectionNum -le $vms.Count
        
        if (-not $validSelection) {
            Write-Host "Invalid selection. Please enter a number between 1 and $($vms.Count)" -ForegroundColor Red
        }
    } while (-not $validSelection)
    
    $VMName = $vms[$selectionNum - 1].Name
    Write-Host "Selected: $VMName" -ForegroundColor Green
}

# Verify VM exists
$vm = Get-VM -Name $VMName -ErrorAction SilentlyContinue
if (-not $vm) {
    Write-Error "VM '$VMName' not found"
    exit 1
}

Write-Host "`n$separator" -ForegroundColor Cyan
Write-Host "  PHASE 1: Copy Scripts TO VM" -ForegroundColor Cyan
Write-Host "$separator" -ForegroundColor Cyan
Write-Host "Target VM: $VMName" -ForegroundColor Green
Write-Host "VM State: $($vm.State)" -ForegroundColor Yellow

# ============================================================================
# STEP 2: COPY FILES TO VM
# ============================================================================

# Check if VM needs to be started
if ($vm.State -ne "Running") {
    Write-Host "`nStarting VM..." -ForegroundColor Yellow
    
    # Handle "Starting" state - wait for it to finish starting
    if ($vm.State -eq "Starting") {
        Write-Host "VM is already starting, waiting for it to be ready..." -ForegroundColor Yellow
        $waitTime = 0
        while ((Get-VM -Name $VMName).State -eq "Starting" -and $waitTime -lt 60) {
            Start-Sleep -Seconds 2
            $waitTime += 2
        }
        $vm = Get-VM -Name $VMName
    } else {
        # VM is Off or other state, start it
        Start-VM -Name $VMName
    }
    
    # Wait for VM to be fully running
    Write-Host "Waiting for VM to start" -NoNewline
    $vmStartTimeout = 60
    $vmStartElapsed = 0
    while ((Get-VM -Name $VMName).State -ne "Running" -and $vmStartElapsed -lt $vmStartTimeout) {
        Start-Sleep -Seconds 1
        Write-Host "." -NoNewline
        $vmStartElapsed++
    }
    Write-Host ""
    
    if ((Get-VM -Name $VMName).State -eq "Running") {
        Write-Host "✓ VM is running" -ForegroundColor Green
        Write-Host "Waiting for VM to fully initialize (30 seconds)..." -ForegroundColor Yellow
        Start-Sleep -Seconds 30
        Write-Host "✓ VM ready" -ForegroundColor Green
    } else {
        Write-Warning "VM did not fully start"
    }
} else {
    Write-Host "`n✓ VM is already running and ready" -ForegroundColor Green
}

# Enable Guest Services if not already enabled
Write-Host "`nEnabling Guest Services..." -ForegroundColor Cyan
try {
    Enable-VMIntegrationService -VMName $VMName -Name "Guest Service Interface" -ErrorAction SilentlyContinue
    Write-Host "✓ Guest Services enabled" -ForegroundColor Green
} catch {
    Write-Warning "Could not enable Guest Services: $_"
}

# Wait a moment for services to initialize
Start-Sleep -Seconds 2

# Verify Guest Services status
$guestService = Get-VMIntegrationService -VMName $VMName -Name "Guest Service Interface"
if ($guestService.Enabled -and $guestService.PrimaryOperationalStatus -eq "Ok") {
    Write-Host "✓ Guest Services operational" -ForegroundColor Green
} else {
    Write-Warning "Guest Services may not be fully operational"
}

# Copy each file
Write-Host "`nCopying files to VM..." -ForegroundColor Cyan
$successCount = 0
$failCount = 0

foreach ($sourceFile in $FilesToCopy) {
    if (Test-Path $sourceFile) {
        $fileName = Split-Path $sourceFile -Leaf
        $destPath = "C:\$fileName"
        
        try {
            Write-Host "  Copying: $fileName" -ForegroundColor Yellow
            Copy-VMFile -Name $VMName -SourcePath $sourceFile -DestinationPath $destPath -FileSource Host -CreateFullPath -Force -ErrorAction Stop
            Write-Host "  ✓ Success: $fileName" -ForegroundColor Green
            $successCount++
        } catch {
            Write-Host "  ✗ Failed: $fileName - $($_.Exception.Message)" -ForegroundColor Red
            $failCount++
        }
    } else {
        Write-Host "  ✗ File not found: $sourceFile" -ForegroundColor Red
        $failCount++
    }
}

Write-Host "`n✓ Phase 1 Complete: $successCount files copied to VM" -ForegroundColor Green

if ($failCount -gt 0) {
    Write-Host "⚠ Warning: $failCount files failed to copy" -ForegroundColor Yellow
}

# ============================================================================
# STEP 3: USER RUNS SCRIPT ON VM
# ============================================================================

$batFileName = Split-Path $FilesToCopy[0] -Leaf
Write-Host "`n✓ Script copied to VM: C:\$batFileName" -ForegroundColor Green
Write-Host "Run the .bat file on the Hyper-V VM, then press Enter to continue" -ForegroundColor Yellow

Read-Host "`nPress Enter to continue"

# ============================================================================
# STEP 4: COPY FILES FROM VM
# ============================================================================

Write-Host "`n$separator" -ForegroundColor Cyan
Write-Host "  PHASE 3: Collect Files FROM VM" -ForegroundColor Cyan
Write-Host "$separator" -ForegroundColor Cyan

# Get VHD path
Write-Host "`nGetting VHD path..." -ForegroundColor Cyan
$vm = Get-VM -Name $VMName
$vhdPath = ($vm | Select-Object -ExpandProperty HardDrives).Path
if (-not $vhdPath) {
    Write-Error "Could not determine VHD path"
    exit 1
}
Write-Host "VHD Path: $vhdPath" -ForegroundColor Yellow

# Stop VM if running
if ($vm.State -eq "Running") {
    Write-Host "`nStopping VM..." -ForegroundColor Yellow
    Stop-VM -Name $VMName -Force
    
    # Wait for VM to fully stop with progress indicator
    $timeout = 60
    $elapsed = 0
    Write-Host "Waiting for VM to shut down" -NoNewline
    while ((Get-VM -Name $VMName).State -ne "Off" -and $elapsed -lt $timeout) {
        Start-Sleep -Seconds 1
        Write-Host "." -NoNewline
        $elapsed++
    }
    Write-Host ""
    
    if ((Get-VM -Name $VMName).State -ne "Off") {
        Write-Error "VM did not stop within timeout period"
        exit 1
    }
    
    # Additional delay to ensure VM resources are fully released
    Write-Host "VM stopped, waiting for resources to release..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    Write-Host "✓ VM stopped and ready" -ForegroundColor Green
}

# Mount VHD
Write-Host "`nMounting VHD (read-only)..." -ForegroundColor Cyan
$mountRetries = 3
$mountSuccess = $false

for ($i = 1; $i -le $mountRetries; $i++) {
    try {
        Mount-VHD -Path $vhdPath -ReadOnly -ErrorAction Stop
        Write-Host "✓ VHD mounted" -ForegroundColor Green
        $mountSuccess = $true
        break
    } catch {
        if ($i -lt $mountRetries) {
            Write-Host "Mount attempt $i failed, retrying in 2 seconds..." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        } else {
            Write-Error "Failed to mount VHD after $mountRetries attempts: $_"
            exit 1
        }
    }
}

if (-not $mountSuccess) {
    Write-Error "Could not mount VHD"
    exit 1
}

# Assign drive letter
Write-Host "`nAssigning drive letter..." -ForegroundColor Cyan
$driveLetter = $null
try {
    $vhdFileName = Split-Path $vhdPath -Leaf
    $disk = Get-Disk | Where-Object {$_.Location -like "*$vhdFileName*"}
    $partition = $disk | Get-Partition | Where-Object {$_.Size -gt 50GB} | Select-Object -First 1
    
    if ($partition) {
        # Find available drive letter
        $usedLetters = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Name
        $availableLetter = (67..90 | ForEach-Object {[char]$_} | Where-Object {$_ -notin $usedLetters}) | Select-Object -First 1
        
        if ($availableLetter) {
            Set-Partition -InputObject $partition -NewDriveLetter $availableLetter
            $driveLetter = $availableLetter
            Write-Host "Drive letter assigned: ${driveLetter}:" -ForegroundColor Yellow
            
            # Wait for drive to be accessible
            Write-Host "Waiting for drive to be ready" -NoNewline
            $driveReady = $false
            $maxWait = 15
            for ($w = 0; $w -lt $maxWait; $w++) {
                Start-Sleep -Seconds 1
                Write-Host "." -NoNewline
                try {
                    $testPath = "${driveLetter}:\"
                    $null = Get-Item $testPath -ErrorAction Stop
                    $driveReady = $true
                    break
                } catch {
                    # Drive not ready yet
                }
            }
            Write-Host ""
            
            if (-not $driveReady) {
                throw "Drive ${driveLetter}: assigned but not accessible after $maxWait seconds"
            }
            
            Write-Host "✓ Drive ${driveLetter}:\ is ready" -ForegroundColor Green
        } else {
            throw "No available drive letters"
        }
    } else {
        throw "Could not find suitable partition"
    }
} catch {
    Write-Error "Failed to assign drive letter: $_"
    Dismount-VHD -Path $vhdPath -ErrorAction SilentlyContinue
    exit 1
}

# Search for files
Write-Host "`nSearching for files..." -ForegroundColor Cyan
$sourcePath = "${driveLetter}:\"
if ($SourceFolder) {
    $searchPath = Join-Path $sourcePath $SourceFolder
    if (Test-Path $searchPath) {
        $sourcePath = $searchPath
    }
}

$files = Get-ChildItem -Path $sourcePath -Filter $SearchPattern -Recurse -File -ErrorAction SilentlyContinue | 
    Sort-Object LastWriteTime -Descending

if ($files.Count -eq 0) {
    Write-Warning "No files matching `"$SearchPattern`" found in $sourcePath"
    Write-Host "`nListing root directory contents:" -ForegroundColor Yellow
    Get-ChildItem "${driveLetter}:\" | Format-Table Name, LastWriteTime, Length
    $collectedCount = 0
} else {
    Write-Host "Found $($files.Count) file(s) (sorted by newest first):" -ForegroundColor Green
    $files | ForEach-Object { 
        Write-Host "  - $($_.Name) (Modified: $($_.LastWriteTime))" -ForegroundColor Yellow 
    }
    
    # Get only the newest file
    $newestFile = $files[0]
    Write-Host "`nNewest file: $($newestFile.Name) - $($newestFile.LastWriteTime)" -ForegroundColor Cyan
    
    # Create destination folder if needed
    if (-not (Test-Path $DestinationPath)) {
        New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
        Write-Host "Created destination folder: $DestinationPath" -ForegroundColor Green
    }
    
    # Copy only the newest file
    Write-Host "`nCopying newest file..." -ForegroundColor Cyan
    $collectedCount = 0
    try {
        $destFile = Join-Path $DestinationPath $newestFile.Name
        Copy-Item -Path $newestFile.FullName -Destination $destFile -Force
        Write-Host "  ✓ Copied: $($newestFile.Name)" -ForegroundColor Green
        $collectedCount = 1
    } catch {
        Write-Host "  ✗ Failed: $($newestFile.Name) - $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Dismount VHD
Write-Host "`nDismounting VHD..." -ForegroundColor Cyan
try {
    Dismount-VHD -Path $vhdPath -ErrorAction Stop
    Write-Host "✓ VHD dismounted" -ForegroundColor Green
} catch {
    Write-Warning "Failed to dismount VHD: $_"
    Write-Warning "You may need to manually dismount: Dismount-VHD -Path `"$vhdPath`""
}

# Restart VM
Write-Host "`nRestarting VM..." -ForegroundColor Cyan
Start-VM -Name $VMName

# Wait for VM to be fully running
Write-Host "Waiting for VM to start" -NoNewline
$startTimeout = 60
$startElapsed = 0
while ((Get-VM -Name $VMName).State -ne "Running" -and $startElapsed -lt $startTimeout) {
    Start-Sleep -Seconds 1
    Write-Host "." -NoNewline
    $startElapsed++
}
Write-Host ""

if ((Get-VM -Name $VMName).State -eq "Running") {
    Write-Host "✓ VM is running" -ForegroundColor Green
    # Additional delay for VM to fully initialize
    Write-Host "Waiting for VM to fully initialize (30 seconds)..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
    Write-Host "✓ VM initialization complete" -ForegroundColor Green
} else {
    Write-Warning "VM did not start within timeout period"
}

# ============================================================================
# FINAL SUMMARY
# ============================================================================

Write-Host "`n$separator" -ForegroundColor Cyan
Write-Host "  WORKFLOW COMPLETE" -ForegroundColor Cyan
Write-Host "$separator" -ForegroundColor Cyan
Write-Host "VM Name:              $VMName"
Write-Host "Files Copied TO VM:   $successCount" -ForegroundColor Green
Write-Host "Files Collected:      $collectedCount" -ForegroundColor Green
if ($collectedCount -gt 0) {
    Write-Host "Collection Location:  $DestinationPath" -ForegroundColor Green
}
Write-Host "VM Status:            Running" -ForegroundColor Green
Write-Host "$separator" -ForegroundColor Cyan

if ($collectedCount -gt 0) {
    Write-Host "`n✓ SUCCESS: Workflow completed successfully!" -ForegroundColor Green
    Write-Host "Your HWID files are ready at: $DestinationPath" -ForegroundColor White
} else {
    Write-Host "`n⚠ WARNING: No files were collected from the VM" -ForegroundColor Yellow
    Write-Host "Please verify the scripts ran successfully on the VM" -ForegroundColor White
}

Read-Host "`nPress Enter to exit"
[Environment]::Exit(0)
