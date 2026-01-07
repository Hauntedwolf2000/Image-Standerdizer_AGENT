# Requires PowerShell 5.1 or later on Windows with .NET Framework
# This script traverses subfolders, finds images inside '1x' directories, and normalizes them,
# presented within a Windows Forms GUI for better user experience and logging.

# --------------------------------------------------------------------------
# CRITICAL FIX: Ensure all required .NET assemblies are loaded immediately
# using the most reliable methods for Windows PowerShell.
# --------------------------------------------------------------------------
try {
    # Use Add-Type explicitly for robust loading
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Add-Type -AssemblyName System.Reflection -ErrorAction Stop
} catch {
    Write-Error "Failed to load required .NET assemblies. Ensure .NET Framework is fully installed."
    exit 1
}
# --------------------------------------------------------------------------

# --- Configuration ---
$Tolerance = 2 # Max allowed difference in pixels for width and height
$OutputFolderName = "Normalized_Images"
$RootOutputSubfolderName = "Root_Direct_Assets" # Used for Case 1 (Images in the root)
$QuestionAssetThreshold = 10 # Difference threshold for skipping "Question Assets"
$TargetSubfolderName = "1x" # The specific subfolder name for Case 3
# ---------------------

# --- Helper Functions ---

# Function to display a critical error message
function Show-ErrorDialog {
    param([string]$Message, [string]$Title = "Error")
    [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
}

# Helper function to append text to the log box
function Add-Log {
    param([string]$Text)
    # Ensure this function only runs when the logTextBox exists
    if ($script:logTextBox) {
        $script:logTextBox.AppendText("$Text`r`n")
    }
}

# --- GUI Setup ---

# Use script scope variables to make them accessible within the Add_Click block
$script:form = New-Object System.Windows.Forms.Form
$script:form.Text = "D-Normalizer"
$script:form.Size = New-Object System.Drawing.Size(700, 600)
$script:form.StartPosition = "CenterScreen"
$script:form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$script:form.MaximizeBox = $false
# Set a subtle background color for the form
$script:form.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240) # Light Gray

# Folder Path Label
$pathLabel = New-Object System.Windows.Forms.Label
$pathLabel.Text = "Folder Path:"
$pathLabel.Location = New-Object System.Drawing.Point(10, 15)
$pathLabel.Size = New-Object System.Drawing.Size(80, 20)
$script:form.Controls.Add($pathLabel)

# Folder Path Text Box
$script:pathTextBox = New-Object System.Windows.Forms.TextBox
$script:pathTextBox.Location = New-Object System.Drawing.Point(90, 10)
$script:pathTextBox.Size = New-Object System.Drawing.Size(480, 25)
$script:form.Controls.Add($script:pathTextBox)

# Browse Button
$browseButton = New-Object System.Windows.Forms.Button
$browseButton.Text = "Browse..."
$browseButton.Location = New-Object System.Drawing.Point(580, 10)
$browseButton.Size = New-Object System.Drawing.Size(90, 25)
$browseButton.BackColor = [System.Drawing.Color]::FromArgb(173, 216, 230) # Light Blue
$browseButton.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $result = $folderBrowser.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $script:pathTextBox.Text = $folderBrowser.SelectedPath
    }
})
$script:form.Controls.Add($browseButton)

# Run Button (Vibrant color)
$runButton = New-Object System.Windows.Forms.Button
$runButton.Text = "Run Full Scan & Normalization (All Cases)"
$runButton.Location = New-Object System.Drawing.Point(10, 45)
$runButton.Size = New-Object System.Drawing.Size(660, 35)
$runButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$runButton.BackColor = [System.Drawing.Color]::FromArgb(60, 179, 113) # Medium Sea Green
$runButton.ForeColor = [System.Drawing.Color]::White # White text for contrast
$script:form.Controls.Add($runButton)

# Output/Log Text Box (Read-Only - Console Look)
$script:logTextBox = New-Object System.Windows.Forms.TextBox
$script:logTextBox.Location = New-Object System.Drawing.Point(10, 90)
$script:logTextBox.Size = New-Object System.Drawing.Size(660, 400)
$script:logTextBox.MultiLine = $true
$script:logTextBox.ReadOnly = $true
$script:logTextBox.ScrollBars = "Vertical"
$script:logTextBox.Font = New-Object System.Drawing.Font("Consolas", 8) # Monospace font for table-like look
$script:logTextBox.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30) # Very Dark Gray/Black for log background
$script:logTextBox.ForeColor = [System.Drawing.Color]::FromArgb(153, 255, 153) # Light Green text for log content
$script:form.Controls.Add($script:logTextBox)

# Status Label (Dynamic color status area)
$script:statusLabel = New-Object System.Windows.Forms.Label
$script:statusLabel.Text = "Ready to run."
$script:statusLabel.Location = New-Object System.Drawing.Point(10, 500)
$script:statusLabel.Size = New-Object System.Drawing.Size(660, 40)
$script:statusLabel.AutoSize = $false
$script:statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$script:statusLabel.BackColor = [System.Drawing.Color]::FromArgb(230, 230, 250) # Lavender background
$script:statusLabel.ForeColor = [System.Drawing.Color]::DarkGreen # Initial ready color
# FIXED: Using integer 16 for ContentAlignment.MiddleLeft
$script:statusLabel.TextAlign = 16
$script:form.Controls.Add($script:statusLabel)

# --- Image Normalization Core Logic (Combined Processing) ---
$runButton.Add_Click({
    $runButton.Enabled = $false
    $script:logTextBox.Clear()
    $script:statusLabel.Text = "STATUS: Analyzing folder structure..."
    $script:statusLabel.ForeColor = [System.Drawing.Color]::DarkOrange # Status text color changes to orange while running
    $InitialFolderPath = $script:pathTextBox.Text
    Add-Log "Starting process for folder: $InitialFolderPath"
    
    # 1. Path Validation
    if (-not (Test-Path -Path $InitialFolderPath -PathType Container)) {
        Show-ErrorDialog "Folder path '$InitialFolderPath' is not valid or does not exist."
        $script:statusLabel.Text = "STATUS: Error - Invalid Path."
        $script:statusLabel.ForeColor = [System.Drawing.Color]::DarkRed
        $runButton.Enabled = $true
        return
    }
    
    # 2. Define the main output folder path and create it
    $MainOutputFolderPath = Join-Path -Path $InitialFolderPath -ChildPath $OutputFolderName
    if (-not (Test-Path -Path $MainOutputFolderPath -PathType Container)) {
        try {
            New-Item -Path $MainOutputFolderPath -ItemType Directory | Out-Null
            Add-Log "Created main output folder: $MainOutputFolderPath"
        } catch {
            Show-ErrorDialog "Error creating output folder: $($_.Exception.Message)"
            $script:statusLabel.Text = "STATUS: Error creating output folder."
            $script:statusLabel.ForeColor = [System.Drawing.Color]::DarkRed
            $runButton.Enabled = $true
            return
        }
    }
    
    # 3. Analyze and Compile All Target Folders
    # Case 3: Images in '1x' sub-sub-folders (Highest Priority to find first)
    $Target1xFolders = @(Get-ChildItem -Path $InitialFolderPath -Directory -Recurse | Where-Object { $_.Name -ceq $TargetSubfolderName })
    
    # Case 2: Images in immediate subfolders (Word names)
    $AllSubFolders = @(Get-ChildItem -Path $InitialFolderPath -Directory -Exclude $OutputFolderName -Recurse -Depth 1)

    # Filter Case 2: Get folders with images that are NOT parents of a 1x folder (to avoid duplicates)
    $Case2Folders = @()
    foreach ($Folder in $AllSubFolders) {
        $HasImages = (Get-ChildItem -Path $Folder.FullName -Filter "*.png" -File -ErrorAction SilentlyContinue).Count -gt 0
        $Has1xSubfolder = (Get-ChildItem -Path $Folder.FullName -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ceq $TargetSubfolderName }).Count -gt 0

        # We only want this folder if it has direct images AND does NOT contain a 1x folder (Case 3)
        if ($HasImages -and -not $Has1xSubfolder) {
            $Case2Folders += $Folder
        }
    }
    
    # Case 1: Images at the root (Lowest Priority)
    $Case1Folder = @()
    $RootImages = @(Get-ChildItem -Path $InitialFolderPath -Filter "*.png" -File -ErrorAction SilentlyContinue)
    # Only process root if it has images and no Case 2/Case 3 folder structures overlap with root-level image processing.
    if ($RootImages.Count -gt 0 -and $Target1xFolders.Count -eq 0 -and $Case2Folders.Count -eq 0) {
        $Case1Folder += [PSCustomObject]@{
            FullName = $InitialFolderPath;
            Name = (Split-Path -Path $InitialFolderPath -Leaf);
            Parent = $null; # Marker for root folder
        }
    }
    
    # Combine all folders into one array for sequential processing
    # Case 3 (1x) folders use the $TargetFolder.Parent.Name logic
    # Case 2 (Subfolder) and Case 1 (Root) folders use the $IsDirectMode logic
    $CombinedTargetGroups = @(
        @{ Folders = $Target1xFolders; IsDirect = $false; Name = "Case 3 ('1x' folders)" },
        @{ Folders = $Case2Folders; IsDirect = $true; Name = "Case 2 (Direct Subfolders)" },
        @{ Folders = $Case1Folder; IsDirect = $true; Name = "Case 1 (Root Folder)" }
    )
    $TotalGroups = $Target1xFolders.Count + $Case2Folders.Count + $Case1Folder.Count

    if ($TotalGroups -eq 0) {
        Add-Log "No PNG images found matching any of the three asset structures. Exiting."
        $script:statusLabel.Text = "STATUS: Complete - No target content found."
        $script:statusLabel.ForeColor = [System.Drawing.Color]::DarkBlue
        $runButton.Enabled = $true
        return
    }
    
    Add-Log "`n========================================`n Processing $TotalGroups Target Groups Found `n========================================"
    
    # Create a header for the log table
    Add-Log ""
    Add-Log "File Name              | Original Size | Target Size   | Action"
    Add-Log "-----------------------|---------------|---------------|-----------------------"
    
    # 4. Process all found groups sequentially
    foreach ($Group in $CombinedTargetGroups) {
        $IsDirectMode = $Group.IsDirect

        if ($Group.Folders.Count -eq 0) {
            Add-Log "`nSkipping $($Group.Name) (0 folders found)."
            continue
        }

        Add-Log "`n--- Starting Processing for: $($Group.Name) ---"

        foreach ($TargetFolder in $Group.Folders) {

            # Determine the desired output subfolder name
            if ($IsDirectMode) {
                # Case 1 (Root) or Case 2 (Subfolder)
                if (-not $TargetFolder.Parent) { # Case 1: Root folder
                    $OutputSubfolderName = $RootOutputSubfolderName
                    $DisplayFolderName = "$($TargetFolder.Name) (Root Direct)"
                } else { # Case 2: Subfolder
                    $OutputSubfolderName = $TargetFolder.Name
                    $DisplayFolderName = "$($OutputSubfolderName) (Direct Subfolder)"
                }
            } else {
                # Case 3: Original '1x' mode. Output folder is the PARENT of '1x'.
                $OutputSubfolderName = $TargetFolder.Parent.Name
                $DisplayFolderName = "$($OutputSubfolderName)\$($TargetFolder.Name)"
            }
            
            $CurrentOutputFolderPath = Join-Path -Path $MainOutputFolderPath -ChildPath $OutputSubfolderName
            
            # Create the specific subfolder inside Normalized_Images
            if (-not (Test-Path -Path $CurrentOutputFolderPath -PathType Container)) {
                New-Item -Path $CurrentOutputFolderPath -ItemType Directory | Out-Null
            }
            
            Add-Log "`n>>> Group: $DisplayFolderName <<<"
            
            # Get all PNG images in the current folder (which could be the root, subfolder, or '1x')
            $ImageFiles = Get-ChildItem -Path $TargetFolder.FullName -Filter "*.png" -File
            
            if (-not $ImageFiles) {
                Add-Log "No PNG images found in $($TargetFolder.FullName). Skipping."
                continue
            }
            
            # Array to hold image dimension data for the current group
            $ImageDimensions = @()
            
            # Read dimensions of all images
            foreach ($File in $ImageFiles) {
                try {
                    # Use a stream to prevent file lock issues
                    $stream = New-Object System.IO.FileStream($File.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
                    $Image = [System.Drawing.Image]::FromStream($stream)
                    $ImageDimensions += [PSCustomObject]@{
                        FullName = $File.FullName
                        FileName = $File.Name
                        Width = $Image.Width
                        Height = $Image.Height
                    }
                    $Image.Dispose()
                    $stream.Dispose()
                }
                catch {
                    Add-Log "Warning: Could not read '$($File.Name)'. Error: $($_.Exception.Message)"
                }
            }
            
            if (-not $ImageDimensions) {
                Add-Log "No valid dimensions read for this folder. Skipping."
                continue
            }
            
            # Group dimensions to find the most common size
            $DimensionGroups = $ImageDimensions | Group-Object -Property @{ Expression = { "$($_.Width)x$($_.Height)" } } | Sort-Object Count -Descending
            
            if (-not $DimensionGroups) {
                Add-Log "Could not determine a common size. Skipping."
                continue
            }
            
            $ReferenceDimensionString = $DimensionGroups[0].Name
            $ReferenceWidth = [int]($ReferenceDimensionString -split 'x')[0]
            $ReferenceHeight = [int]($ReferenceDimensionString -split 'x')[1]
            
            Add-Log "  Target Dimension (Most Common): ${ReferenceWidth}x${ReferenceHeight}"
            
            $GroupResizeCount = 0
            $GroupQuestionAssetCount = 0
            $GroupSkippedCount = 0
            
            # 5. Perform resizing/copying for images in the current folder
            foreach ($ImageInfo in $ImageDimensions) {
                $WidthDiff = [System.Math]::Abs($ImageInfo.Width - $ReferenceWidth)
                $HeightDiff = [System.Math]::Abs($ImageInfo.Height - $ReferenceHeight)
                $OriginalSize = "$($ImageInfo.Width)x$($ImageInfo.Height)"
                $TargetSize = "${ReferenceWidth}x${ReferenceHeight}"
                $OutputFilePath = Join-Path -Path $CurrentOutputFolderPath -ChildPath $ImageInfo.FileName
                
                # Truncate filename for table formatting
                $DisplayName = $ImageInfo.FileName
                if ($DisplayName.Length -gt 22) {
                    $DisplayName = $DisplayName.Substring(0, 19) + "..."
                }
                $Action = "Skipped (Not Close)" # Default action
                
                # Check for Question Asset condition (skip normalization, just copy)
                if ($WidthDiff -gt $QuestionAssetThreshold -or $HeightDiff -gt $QuestionAssetThreshold) {
                    $Action = "Skipped (Asset)"
                    $GroupQuestionAssetCount++
                    Copy-Item -Path $ImageInfo.FullName -Destination $OutputFilePath -Force | Out-Null
                }
                # Check if resizing is needed (within tolerance)
                elseif ($WidthDiff -le $Tolerance -or $HeightDiff -le $Tolerance) {

                    if ($WidthDiff -eq 0 -and $HeightDiff -eq 0) {
                        $Action = "Copied (Same Size)"
                        Copy-Item -Path $ImageInfo.FullName -Destination $OutputFilePath -Force | Out-Null
                    } else {
                        $Action = "Resized"
                        try {
                            # Open the image using a stream for better handling
                            $stream = New-Object System.IO.FileStream($ImageInfo.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
                            $OriginalImage = [System.Drawing.Image]::FromStream($stream)
                            $NewBitmap = New-Object System.Drawing.Bitmap($ReferenceWidth, $ReferenceHeight)
                            $Graphics = [System.Drawing.Graphics]::FromImage($NewBitmap)
                            $Graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                            $Graphics.DrawImage($OriginalImage, 0, 0, $ReferenceWidth, $ReferenceHeight)
                            $Graphics.Dispose()
                            $OriginalImage.Dispose()
                            $stream.Dispose()
                            $ImageFormat = [System.Drawing.Imaging.ImageFormat]::Png
                            $NewBitmap.Save($OutputFilePath, $ImageFormat)
                            $NewBitmap.Dispose()
                            $GroupResizeCount++
                        }
                        catch {
                            $Action = "ERROR Resizing"
                            $GroupSkippedCount++
                            # Fallback: Copy the original file
                            Copy-Item -Path $ImageInfo.FullName -Destination $OutputFilePath -Force | Out-Null
                        }
                    }
                }
                else {
                    # Not close enough, but not a "Question Asset" either. Just copy.
                    $GroupSkippedCount++
                    Copy-Item -Path $ImageInfo.FullName -Destination $OutputFilePath -Force | Out-Null
                }
                
                # Log the action in a table format
                $LogEntry = "{0,-22} | {1,-13} | {2,-13} | {3,-21}" -f $DisplayName, $OriginalSize, $TargetSize, $Action
                Add-Log $LogEntry
            }
            
            Add-Log " "
            Add-Log "--- Summary for $($OutputSubfolderName) (Total: $($ImageDimensions.Count)) ---"
            Add-Log "  Images Resized/Copied to Target:       $GroupResizeCount"
            Add-Log "  Images Skipped (Asset): $GroupQuestionAssetCount"
            Add-Log "  Images Skipped (Other): $GroupSkippedCount"
            Add-Log "-------------------------------------------------------------------"
        }
    }
    
    $script:statusLabel.Text = "STATUS: FINAL PROCESS COMPLETE. Images saved to: $MainOutputFolderPath"
    $script:statusLabel.ForeColor = [System.Drawing.Color]::DarkGreen # Status text color changes to green on completion
    $runButton.Enabled = $true
    Add-Log "`n--- FINAL PROCESS COMPLETE ---"
})

# Display the main form
[void]$script:form.ShowDialog()