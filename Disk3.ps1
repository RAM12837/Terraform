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

    $HouseKeepingLog = [System.Collections.Generic.List[object]]::new()
    $RemovedProfiles = @()

    # -----------------------------------------------------
    # RECYCLE BIN CLEANUP
    # -----------------------------------------------------

    try {

        $RecycleItems = Get-ChildItem "C:\`$Recycle.Bin" `
            -Force -Recurse -ErrorAction SilentlyContinue

        foreach($Item in $RecycleItems)
        {
            $HouseKeepingLog.Add(
                [PSCustomObject]@{
                    Category = "RecycleBin"
                    Path     = $Item.FullName
                    SizeMB   = :Round(($Item.Length / 1MB),2)
                }
            )
        }

        $RecycleItems |
            Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

        Write-Output "Recycle Bin cleanup completed."
    }
    catch {
        Write-Output "Recycle Bin cleanup failed."
    }

    # -----------------------------------------------------
    # WINDOWS TEMP CLEANUP
    # -----------------------------------------------------

    try {

        $TempItems = Get-ChildItem "C:\Windows\Temp" `
            -Force -Recurse -ErrorAction SilentlyContinue

        foreach($Item in $TempItems)
        {
            $HouseKeepingLog.Add(
                [PSCustomObject]@{
                    Category = "WindowsTemp"
                    Path     = $Item.FullName
                    SizeMB   = :Round(($Item.Length / 1MB),2)
                }
            )
        }

        $TempItems |
            Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

        Write-Output "Windows Temp cleanup completed."
    }
    catch {
        Write-Output "Windows Temp cleanup failed."
    }

    # -----------------------------------------------------
    # SOFTWARE DISTRIBUTION CLEANUP
    # -----------------------------------------------------

    try {

        $SCCMServer = Get-Service SMS_EXECUTIVE `
            -ErrorAction SilentlyContinue

        if (-not $SCCMServer)
        {
            $SoftwareDist =
              "C:\Windows\SoftwareDistribution\Download"

            if(Test-Path $SoftwareDist)
            {
                $FilesToDelete =
                    Get-ChildItem $SoftwareDist `
                    -Recurse -Force `
                    -ErrorAction SilentlyContinue |
                    Where-Object {
                        -not $_.PSIsContainer -and
                        $_.LastWriteTime -lt (Get-Date).AddDays(-30)
                    }

                foreach($Item in $FilesToDelete)
                {
                    $HouseKeepingLog.Add(
                        [PSCustomObject]@{
                            Category = "SoftwareDistribution"
                            Path     = $Item.FullName
                            SizeMB   = :Round(($Item.Length / 1MB),2)
                        }
                    )
                }

                $FilesToDelete |
                    Remove-Item -Force `
                    -ErrorAction SilentlyContinue
            }
        }

        Write-Output "SoftwareDistribution cleanup completed."
    }
    catch {
        Write-Output "SoftwareDistribution cleanup failed."
    }

    # -----------------------------------------------------
    # UNKNOWN PROFILE CLEANUP
    # -----------------------------------------------------

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
                    Translate(
                       [System.Security.Principal.NTAccount]
                    ) | Out-Null
                }
                catch {

                    $RemovedProfiles += [PSCustomObject]@{
                        SID       = $SID
                        LocalPath = $_.LocalPath
                    }

                    $HouseKeepingLog.Add(
                        [PSCustomObject]@{
                            Category = "UnknownProfile"
                            SID      = $SID
                            Path     = $_.LocalPath
                        }
                    )

                    Remove-CimInstance $_ -ErrorAction Stop
                }
            }
            catch {
                Write-Output "Failed to remove profile $($_.LocalPath)"
            }
        }

        Write-Output "Unknown profile cleanup completed."
    }
    catch {
        Write-Output "Unknown profile cleanup failed."
    }

    Write-Output "Housekeeping completed."

    return [PSCustomObject]@{
        Actions         = $HouseKeepingLog
        RemovedProfiles = $RemovedProfiles
    }
}

# function Invoke-HouseKeeping {

#     Write-Output "Starting housekeeping..."
#     $LogFile = "C:\Temp\HouseKeeping_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

#     if (!(Test-Path "C:\Temp")) {
#         New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null
#     }

#     # Recycle Bin
#     try {

#         "===== RECYCLE BIN CONTENT =====" | Out-File $LogFile -Append

#         $RecycleItems = Get-ChildItem "C:\`$Recycle.Bin" -Force -Recurse -ErrorAction SilentlyContinue

#         $RecycleItems | Select-Object FullName,
#         @{Name="SizeMB";Expression={"{0:N2}" -f ($_.Length/1MB)}} |
#         Format-Table -AutoSize |
#         Out-String |
#         Out-File $LogFile -Append

#         $RecycleItems | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

#         Write-Output "Recycle Bin cleanup completed."
#     }
#     catch {
#         Write-Output "Recycle Bin cleanup failed."
#     }

#     # Windows Temp
#     try {

#         "===== WINDOWS TEMP CONTENT =====" | Out-File $LogFile -Append

#         $TempItems = Get-ChildItem "C:\Windows\Temp" -Force -Recurse -ErrorAction SilentlyContinue

#         $TempItems | Select-Object FullName,
#         @{Name="SizeMB";Expression={"{0:N2}" -f ($_.Length/1MB)}} |
#         Format-Table -AutoSize |
#         Out-String |
#         Out-File $LogFile -Append

#         $TempItems | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

#         Write-Output "Windows Temp cleanup completed."
#     }
#     catch {
#         Write-Output "Windows Temp cleanup failed."
#     }

#     # Software Distribution
#     try {

#         $SCCMServer = Get-Service SMS_EXECUTIVE -ErrorAction SilentlyContinue

#         if (-not $SCCMServer) {

#             $SoftwareDist = "C:\Windows\SoftwareDistribution\Download"

#             if (Test-Path $SoftwareDist) {

#                 "===== SOFTWARE DISTRIBUTION FILES =====" | Out-File $LogFile -Append

#                 $FilesToDelete = Get-ChildItem $SoftwareDist -Recurse -Force -ErrorAction SilentlyContinue |
#                 Where-Object {
#                     -not $_.PSIsContainer -and
#                     $_.LastWriteTime -lt (Get-Date).AddDays(-30)
#                 }

#                 $FilesToDelete | Select-Object FullName,
#                 LastWriteTime,
#                 @{Name="SizeMB";Expression={"{0:N2}" -f ($_.Length/1MB)}} |
#                 Format-Table -AutoSize |
#                 Out-String |
#                 Out-File $LogFile -Append

#                 $FilesToDelete | Remove-Item -Force -ErrorAction SilentlyContinue
#             }
#         }

#     }
#     catch {
#         Write-Output "SoftwareDistribution cleanup failed."
#     }

#     # Remove Unknown Profiles
#     $RemovedProfiles = @()

#     try {

#         Get-CimInstance Win32_UserProfile |
#         Where-Object {
#             $_.Special -eq $false -and
#             $_.Loaded -eq $false
#         } |
#         ForEach-Object {

#             try {

#                 $SID = $_.SID

#                 try {
#                     ([System.Security.Principal.SecurityIdentifier]$SID).
#                         Translate([System.Security.Principal.NTAccount]) | Out-Null
#                 }
#                 catch {

#                     $RemovedProfiles += [PSCustomObject]@{
#                         SID       = $SID
#                         LocalPath = $_.LocalPath
#                     }

#                     "===== UNKNOWN PROFILE =====" | Out-File $LogFile -Append
#                     "$($_.LocalPath) | $SID" | Out-File $LogFile -Append

#                     Remove-CimInstance $_ -ErrorAction Stop
#                 }
#             }
#             catch {
#                 Write-Output "Failed to remove profile $($_.LocalPath)"
#             }
#         }

#         if ($RemovedProfiles.Count -gt 0) {

#             "===== REMOVED UNKNOWN PROFILES =====" | Out-File $LogFile -Append
#             Write-Output "Removed Account Unknown Profiles:"

#             $RemovedProfiles | ForEach-Object {
#                 Write-Output "$($_.LocalPath) - $($_.SID)"
#             }
#         }
#         else {
#             Write-Output "No Account Unknown profiles found."
#         }
#     }
#     catch {
#         Write-Output "Account Unknown profile cleanup failed : $($_.Exception.Message)"
#     }

#     Write-Output "Housekeeping completed."
#     return $LogFile
# }

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

    $WorkNoteBefore = New-WorkNote -Stage "Before Housekeeping" -Utilization $Usage.UsedPercent -TopFolders $TopFoldersBefore -TopFiles $TopFilesBefore

    # Update SNOW Work Notes Here
    Write-Output $WorkNoteBefore

    # STEP 5 - Housekeeping
    $CleanupResult = Invoke-HouseKeeping
    $HouseKeepingData = $CleanupResult.Actions
    $WorkNoteBefore += @"
    Housekeeping Actions Performed
    ==============================
    Total Actions : $($HouseKeepingData.Count)
    "@

    foreach($Action in $HouseKeepingData)
    {
        $WorkNoteBefore +=
            "$($Action.Category) | $($Action.Path)`r`n"
    }

    # $CleanupLogFile = Invoke-HouseKeeping

    # if (Test-Path $CleanupLogFile) {
    #     $HouseKeepingData = Get-Content $CleanupLogFile -Raw

    #     $WorkNoteBefore += @"

    # Housekeeping Actions Performed
    # ================================

    # $HouseKeepingData

    # "@
    # }    

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

    $LargestProfiles = Get-TopUserProfiles

    $WorkNoteAfter = New-WorkNote -Stage "After Housekeeping" -Utilization $NewUsage.UsedPercent -TopFolders $TopFoldersAfter -TopFiles $TopFilesAfter
    $WorkNoteAfter += "`r`nTop 10 User Profiles:`r`n"

    foreach($Profile in $LargestProfiles)
    {
        $WorkNoteAfter += "$($Profile.UserName) - $($Profile.SizeGB) GB - $($Profile.LocalPath)`r`n"
    }
    Write-Output $WorkNoteAfter

    [PSCustomObject]@{
        Drive              = $Drive
        InitialUtilization = $Usage.UsedPercent
        FinalUtilization   = $NewUsage.UsedPercent
        Status             = "REASSIGN_TO_GCC"
        AssignmentGroup    = "GCC Team"
        LargestProfiles    = $LargestProfiles
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

    Drive               = $Drive
    InitialUtilization  = $Usage.UsedPercent
    FinalUtilization    = $NewUsage.UsedPercent
    Status              = $Status
    AssignmentGroup     = "GCC Team"

    TopFoldersBefore    = $TopFoldersBefore
    TopFilesBefore      = $TopFilesBefore

    CleanupActions      = $CleanupResult.Actions
    RemovedProfiles     = $CleanupResult.RemovedProfiles

    TopFoldersAfter     = $TopFoldersAfter
    TopFilesAfter       = $TopFilesAfter
    LargestProfiles     = $LargestProfiles

    WorkNoteBefore      = $WorkNoteBefore
    WorkNoteAfter       = $WorkNoteAfter
}

$Result | ConvertTo-Json -Depth 50 | Out-File "C:\Users\Administrator\Desktop\Terraform\DiskUtilizationResult3.json" -Encoding UTF8