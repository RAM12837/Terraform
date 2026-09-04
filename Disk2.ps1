# ==========================================
# Disk Utilization Auto Remediation Script
# Version: 1.0
# ==========================================

param(
    [string]$Drive = "C:",
    [int]$Threshold = 75
)

# ==========================================
# Get Disk Usage
# ==========================================

function Get-DiskUsage {

    param([string]$Drive)

    $disk = Get-CimInstance Win32_LogicalDisk |
            Where-Object { $_.DeviceID -eq $Drive }

    if (-not $disk) {
        throw "Unable to find drive $Drive"
    }

    [PSCustomObject]@{
        Drive       = $Drive
        SizeGB      = "{0:N2}" -f ($disk.Size / 1GB)
        FreeGB      = "{0:N2}" -f ($disk.FreeSpace / 1GB)
        UsedPercent = "{0:N2}" -f ((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100)
    }
}

# ==========================================
# Get Top Folders
# ==========================================

function Get-TopFolders {

    param(
        [string]$Path,
        [int]$Top = 10
    )

    Get-ChildItem $Path -Directory -ErrorAction SilentlyContinue |
    ForEach-Object {

        $size = (
            Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue |
            Measure-Object Length -Sum
        ).Sum

        [PSCustomObject]@{
            Name   = $_.FullName
            SizeGB = "{0:N2}" -f ($size / 1GB)
        }
    } |
    Sort-Object SizeGB -Descending |
    Select-Object -First $Top
}

# ==========================================
# Get Top Files
# ==========================================

function Get-TopFiles {

    param(
        [string]$Path,
        [int]$Top = 10
    )

    Get-ChildItem $Path -File -Recurse -Force -ErrorAction SilentlyContinue |
    Sort-Object Length -Descending |
    Select-Object -First $Top FullName,
    @{Name="SizeGB";Expression={"{0:N2}" -f (($_.Length/1GB))}}
}

# ==========================================
# Get Largest Profiles
# ==========================================

function Get-TopUserProfiles {

    Get-CimInstance Win32_UserProfile |
    Where-Object {
        $_.Special -eq $false
    } |
    ForEach-Object {

        $ProfilePath = $_.LocalPath

        $Size = 0

        if (Test-Path $ProfilePath) {

            $Size = (
                Get-ChildItem $ProfilePath -Recurse -Force -ErrorAction SilentlyContinue |
                Measure-Object Length -Sum
            ).Sum
        }

        try {

            $UserName = (
                [System.Security.Principal.SecurityIdentifier]$_.SID
            ).Translate(
                [System.Security.Principal.NTAccount]
            ).Value

        }
        catch {

            $UserName = "Account Unknown"
        }

        [PSCustomObject]@{

            UserName   = $UserName
            SID        = $_.SID
            LocalPath  = $_.LocalPath
            Loaded     = $_.Loaded
            LastUsed   = $_.LastUseTime
            SizeGB     = "{0:N2}" -f ($Size / 1GB)
        }
    } |
    Sort-Object { [double]$_.SizeGB } -Descending |
    Select-Object -First 10
}

# ==========================================
# Create Work Note
# ==========================================

function New-WorkNote {

    param(
        [string]$Stage,
        [decimal]$Utilization,
        [object]$TopFolders = $null,
        [object]$TopFiles = $null
    )

    $Note = @"
Stage : $Stage
Drive : C:
Utilization : $Utilization %

"@

    if ($TopFolders) {

        $Note += "Top 10 Folders:`r`n"

        foreach ($Folder in $TopFolders) {
            $Note += "$($Folder.Name) - $($Folder.SizeGB) GB`r`n"
        }

        $Note += "`r`n"
    }

    if ($TopFiles) {

        $Note += "Top 10 Files:`r`n"

        foreach ($File in $TopFiles) {
            $Note += "$($File.FullName) - $($File.SizeGB) GB`r`n"
        }

        $Note += "`r`n"
    }

    return $Note
}

# ==========================================
# Housekeeping
# ==========================================

function Invoke-HouseKeeping {

    Write-Output "Starting housekeeping..."

    # Recycle Bin
    try {

        Get-ChildItem "C:\`$Recycle.Bin" -Force -ErrorAction SilentlyContinue |
        Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

        Write-Output "Recycle Bin cleanup completed."
    }
    catch {
        Write-Output "Recycle Bin cleanup failed."
    }

    # Windows Temp
    try {

        Get-ChildItem "C:\Windows\Temp" -Force -Recurse -ErrorAction SilentlyContinue |
        Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

        Write-Output "Windows Temp cleanup completed."
    }
    catch {
        Write-Output "Windows Temp cleanup failed."
    }

    # Software Distribution
    try {

        $SCCMServer = Get-Service SMS_EXECUTIVE -ErrorAction SilentlyContinue

        if (-not $SCCMServer) {

            $SoftwareDist = "C:\Windows\SoftwareDistribution\Download"

            if (Test-Path $SoftwareDist) {

                Get-ChildItem $SoftwareDist -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object {
                    -not $_.PSIsContainer -and
                    $_.LastWriteTime -lt (Get-Date).AddDays(-30)
                } |
                Remove-Item -Force -ErrorAction SilentlyContinue
            }
        }

    }
    catch {
        Write-Output "SoftwareDistribution cleanup failed."
    }

    # Remove Unknown Profiles
    $RemovedProfiles = @()

    try {

        Get-CimInstance Win32_UserProfile |
        Where-Object {
            $_.Special -eq $false -and
            $_.Loaded -eq $false
        } |
        ForEach-Object {

            try {

                $SID = $_.SID

                try {
                    ([System.Security.Principal.SecurityIdentifier]$SID).
                        Translate([System.Security.Principal.NTAccount]) | Out-Null
                }
                catch {

                    $RemovedProfiles += [PSCustomObject]@{
                        SID       = $SID
                        LocalPath = $_.LocalPath
                    }

                    Remove-CimInstance $_ -ErrorAction Stop
                }
            }
            catch {
                Write-Output "Failed to remove profile $($_.LocalPath)"
            }
        }

        if ($RemovedProfiles.Count -gt 0) {

            Write-Output "Removed Account Unknown Profiles:"

            $RemovedProfiles | ForEach-Object {
                Write-Output "$($_.LocalPath) - $($_.SID)"
            }
        }
        else {
            Write-Output "No Account Unknown profiles found."
        }
    }
    catch {
        Write-Output "Account Unknown profile cleanup failed : $($_.Exception.Message)"
    }

    Write-Output "Housekeeping completed."
}

# ==========================================
# MAIN LOGIC
# ==========================================

try {

    # STEP 1 - Validate Drive
    if ($Drive.ToUpper() -ne "C:")
    {
        [PSCustomObject]@{
            Drive           = $Drive
            Status          = "REASSIGN_TO_GCC"
            AssignmentGroup = "GCC Team"
            WorkNotes       = "Non-C drive incident detected. Reassigned to GCC Team."
        } | ConvertTo-Json -Depth 20

        return
    }

    # STEP 2 - Current Utilization
    $Usage = Get-DiskUsage -Drive $Drive

    # STEP 3 - Resolve if below threshold
    if ($Usage.UsedPercent -lt $Threshold)
    {
        [PSCustomObject]@{
            Drive              = $Drive
            InitialUtilization = $Usage.UsedPercent
            Status             = "RESOLVED"
            WorkNotes          = @"
Drive : $Drive
Current Utilization : $($Usage.UsedPercent)%

Threshold : $Threshold%

Utilization is below threshold.

Incident auto resolved.
"@
        } | ConvertTo-Json -Depth 20

        return
    }

    # STEP 4 - Capture Top Consumers BEFORE Housekeeping

    $TopFoldersBefore = Get-TopFolders -Path "C:\" -Top 10
    $TopFilesBefore   = Get-TopFiles -Path "C:\" -Top 10

    $WorkNoteBefore = New-WorkNote `
        -Stage "Before Housekeeping" `
        -Utilization $Usage.UsedPercent `
        -TopFolders $TopFoldersBefore `
        -TopFiles $TopFilesBefore

    # Update SNOW Work Notes Here
    Write-Output $WorkNoteBefore

    # STEP 5 - Housekeeping

    Invoke-HouseKeeping

    Start-Sleep -Seconds 30

    # STEP 6 - Verify Utilization Again

    $NewUsage = Get-DiskUsage -Drive $Drive

    # STEP 7 - RESOLVED

    if ($NewUsage.UsedPercent -lt $Threshold)
    {
        $WorkNoteAfter = @"
Housekeeping completed successfully.

Before Utilization : $($Usage.UsedPercent)%
After Utilization  : $($NewUsage.UsedPercent)%

Actions Performed:
1. Recycle Bin Cleanup
2. Windows Temp Cleanup
3. SoftwareDistribution Cleanup (>30 Days)
4. Unknown User Profile Cleanup

Utilization is below threshold.

Incident resolved automatically.
"@

        Write-Output $WorkNoteAfter

        [PSCustomObject]@{
            Drive              = $Drive
            InitialUtilization = $Usage.UsedPercent
            FinalUtilization   = $NewUsage.UsedPercent
            Status             = "RESOLVED"
            WorkNoteBefore     = $WorkNoteBefore
            WorkNoteAfter      = $WorkNoteAfter
        } | ConvertTo-Json -Depth 20

        return
    }

    # STEP 8 - STILL ABOVE THRESHOLD

    $TopFoldersAfter = Get-TopFolders -Path "C:\" -Top 10
    $TopFilesAfter   = Get-TopFiles -Path "C:\" -Top 10

    $WorkNoteAfter = New-WorkNote `
        -Stage "After Housekeeping" `
        -Utilization $NewUsage.UsedPercent `
        -TopFolders $TopFoldersAfter `
        -TopFiles $TopFilesAfter

    Write-Output $WorkNoteAfter

    [PSCustomObject]@{
        Drive              = $Drive
        InitialUtilization = $Usage.UsedPercent
        FinalUtilization   = $NewUsage.UsedPercent
        Status             = "REASSIGN_TO_GCC"
        AssignmentGroup    = "GCC Team"
        LargestProfiles    = Get-TopUserProfiles
        WorkNoteBefore     = $WorkNoteBefore
        WorkNoteAfter      = $WorkNoteAfter
    } | ConvertTo-Json -Depth 20
}
catch {

    [PSCustomObject]@{
        Drive           = $Drive
        Status          = "REASSIGN_TO_GCC"
        AssignmentGroup = "GCC Team"
        WorkNotes       = "Automation failed. Error: $($_.Exception.Message)"
    } | ConvertTo-Json -Depth 20
}


$Result = [PSCustomObject]@{
    Drive           = $Drive
    InitialUtilization = $Usage.UsedPercent
    FinalUtilization   = $NewUsage.UsedPercent
    Status             = $Status
    AssignmentGroup    = $AssignmentGroup
    TopFoldersBefore   = $TopFoldersBefore
    TopFilesBefore     = $TopFilesBefore
    TopFoldersAfter    = $TopFoldersAfter
    TopFilesAfter      = $TopFilesAfter
    LargestProfiles    = Get-TopUserProfiles
    WorkNoteBefore     = $WorkNoteBefore
    WorkNoteAfter      = $WorkNoteAfter
}

$Result | ConvertTo-Json -Depth 50 | Out-File "C:\Users\Administrator\Desktop\Terraform\DiskUtilizationResult3.json" -Encoding UTF8