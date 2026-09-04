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

    $Drive = $Drive.TrimEnd("\")

    $disk = Get-CimInstance Win32_LogicalDisk |
            Where-Object { $_.DeviceID -eq $Drive }

    if (-not $disk) {
        throw "Unable to find drive $Drive"
    }

    [PSCustomObject]@{
        Drive       = $Drive
        SizeGB      = ($disk.Size / 1GB)
        FreeGB      = ($disk.FreeSpace / 1GB)
        UsedPercent = ((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100)
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
    @{Name="SizeGB";Expression={"{0:N2}" -f ($_.Length / 1GB)}}
}

# ==========================================
# Create Work Notes
# ==========================================

function New-WorkNote {

    param(
        [string]$Stage,
        [decimal]$Utilization,
        [object]$TopFolders,
        [object]$TopFiles
    )

    $Note = @"
Stage : $Stage
Drive : C:
Utilization : $('{0:N2}' -f $Utilization) %

Top 10 Folders:

"@

    foreach ($Folder in $TopFolders) {
        $Note += "$($Folder.Name) - $($Folder.SizeGB) GB`r`n"
    }

    $Note += "`r`nTop 10 Files:`r`n"

    foreach ($File in $TopFiles) {
        $Note += "$($File.FullName) - $($File.SizeGB) GB`r`n"
    }

    return $Note
}

# ==========================================
# Housekeeping
# ==========================================

function Invoke-HouseKeeping {

    $DeletedProfiles = @()

    Write-Output "Starting housekeeping..."

    # Recycle Bin

    try {
        Get-ChildItem "C:\`$Recycle.Bin" -Force -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    catch {}

    # Windows Temp

    try {
        Get-ChildItem "C:\Windows\Temp" -Force -Recurse -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    catch {}

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
    catch {}

    # Unknown Profiles Cleanup

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

                    $DeletedProfiles += [PSCustomObject]@{
                        SID       = $SID
                        LocalPath = $_.LocalPath
                    }

                    Remove-CimInstance $_ -ErrorAction Stop
                }
            }
            catch {}
        }
    }
    catch {}

    return $DeletedProfiles
}

# ==========================================
# MAIN
# ==========================================

try {

    # STEP 1 - Validate Drive

    if ($Drive.TrimEnd("\").ToUpper() -ne "C:")
    {
        $Result = [PSCustomObject]@{
            Drive           = $Drive
            Status          = "REASSIGN_TO_GCC"
            AssignmentGroup = "GCC Team"
            WorkNote        = "Non-C drive detected. Incident reassigned to GCC Team."
        }

        $Result | ConvertTo-Json -Depth 50
        return
    }

    # STEP 2 - Get Current Utilization

    $Usage = Get-DiskUsage -Drive "C:"

    # STEP 3 - Below Threshold

    if ($Usage.UsedPercent -lt $Threshold)
    {
        $Result = [PSCustomObject]@{
            Drive              = "C:"
            InitialUtilization = ('{0:N2}' -f $Usage.UsedPercent)
            Status             = "RESOLVED"
            WorkNote           = @"
Drive : C:
Current Utilization : $('{0:N2}' -f $Usage.UsedPercent) %

Utilization is below threshold ($Threshold%).

Incident resolved automatically.
"@
        }

        $Result | ConvertTo-Json -Depth 50
        return
    }

    # STEP 4 - TOP 10 BEFORE HOUSEKEEPING

    $TopFoldersBefore = Get-TopFolders -Path "C:\" -Top 10
    $TopFilesBefore   = Get-TopFiles -Path "C:\" -Top 10

    $WorkNoteBefore = New-WorkNote `
        -Stage "Before Housekeeping" `
        -Utilization $Usage.UsedPercent `
        -TopFolders $TopFoldersBefore `
        -TopFiles $TopFilesBefore

    # Update ServiceNow Work Notes Here

    # STEP 5 - HOUSEKEEPING

    $DeletedProfiles = Invoke-HouseKeeping

    Start-Sleep -Seconds 30

    # STEP 6 - POST VALIDATION

    $NewUsage = Get-DiskUsage -Drive "C:"

    # STEP 7 - RESOLVE

    if ($NewUsage.UsedPercent -lt $Threshold)
    {
        $WorkNoteAfter = @"
Housekeeping completed successfully.

Utilization Before : $('{0:N2}' -f $Usage.UsedPercent) %
Utilization After  : $('{0:N2}' -f $NewUsage.UsedPercent) %

Deleted Unknown Profiles:

$($DeletedProfiles | Format-Table -AutoSize | Out-String)

Incident resolved automatically.
"@

        $Result = [PSCustomObject]@{
            Drive              = "C:"
            InitialUtilization = ('{0:N2}' -f $Usage.UsedPercent)
            FinalUtilization   = ('{0:N2}' -f $NewUsage.UsedPercent)
            DeletedProfiles    = $DeletedProfiles
            Status             = "RESOLVED"
            WorkNoteBefore     = $WorkNoteBefore
            WorkNoteAfter      = $WorkNoteAfter
        }

        $Result | ConvertTo-Json -Depth 50
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

    $Result = [PSCustomObject]@{
        Drive              = "C:"
        InitialUtilization = ('{0:N2}' -f $Usage.UsedPercent)
        FinalUtilization   = ('{0:N2}' -f $NewUsage.UsedPercent)
        DeletedProfiles    = $DeletedProfiles
        Status             = "REASSIGN_TO_GCC"
        AssignmentGroup    = "GCC Team"
        WorkNoteBefore     = $WorkNoteBefore
        WorkNoteAfter      = $WorkNoteAfter
    }

    $Result | ConvertTo-Json -Depth 50
}
catch {

    [PSCustomObject]@{
        Drive           = $Drive
        Status          = "REASSIGN_TO_GCC"
        AssignmentGroup = "GCC Team"
        WorkNote        = "Automation failed. Error: $($_.Exception.Message)"
    } | ConvertTo-Json -Depth 50
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
    LargestProfiles    = $LargestProfiles
    WorkNoteBefore     = $WorkNoteBefore
    WorkNoteAfter      = $WorkNoteAfter
}

$Result | ConvertTo-Json -Depth 50 | Out-File "C:\Users\Administrator\Desktop\Terraform\DiskUtilizationResult3.json" -Encoding UTF8