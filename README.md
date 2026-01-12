# D-Normalizer: Image Standardization Tool

## Overview

D-Normalizer is an automated PowerShell-based tool designed to solve pixel dimension inconsistencies in exported image assets. It identifies and normalizes PNG images that have minor size variations, ensuring all assets conform to the most common dimensions within their respective groups.

## What It Does

The tool intelligently processes three types of image asset structures:

**Case 1: Root-Level Assets**
- Processes PNG images located directly in the root folder
- Useful for standalone asset collections

**Case 2: Word-Named Subfolders**
- Handles images in immediate subfolders (typically named after words/concepts)
- Processes direct subfolder content without nested structures

**Case 3: 1x Folder Structure (Priority)**
- Targets images within '1x' subdirectories nested in parent folders
- Common in design systems with resolution-specific folders

### Key Features

- **Automatic Size Detection**: Identifies the most common dimension as the target size
- **Smart Tolerance System**: Only normalizes images within 2 pixels of the target (configurable)
- **Asset Protection**: Preserves images with significant size differences (>10px threshold) as intentional "Question Assets"
- **Batch Processing**: Handles multiple folders and nested structures in one operation
- **Non-Destructive**: Creates a separate `Normalized_Images` output folder, preserving originals
- **Visual Feedback**: Windows GUI with real-time logging and color-coded status updates

## Technical Architecture

### Development Approach

1. **Framework Selection**: Built on PowerShell 5.1+ with .NET Framework integration
2. **GUI Implementation**: Uses Windows Forms for user-friendly interface
3. **Image Processing**: Leverages System.Drawing for high-quality bicubic interpolation
4. **Error Handling**: Comprehensive try-catch blocks with stream-based file access to prevent locks

### Processing Logic

```
1. Scan folder structure → Identify all three asset cases
2. Group by priority → 1x folders > Subfolders > Root
3. Analyze dimensions → Find most common size per group
4. Apply tolerance rules → Resize within 2px, skip >10px differences
5. Output organized → Maintain folder hierarchy in output directory
```

### Key Technical Decisions

- **Stream-based image loading** prevents file lock issues during batch processing
- **High-quality bicubic interpolation** ensures visual fidelity during resizing
- **Case-sensitive folder matching** (`-ceq`) for precise '1x' folder detection
- **Duplicate prevention logic** avoids processing the same assets through multiple cases

## Installation

### Prerequisites
- Windows OS
- .NET Framework (included in Windows)
- PowerShell 5.1 or later (pre-installed on Windows 10/11)

### Setup Steps

1. **Run the Installer**
   - Double-click the provided `.exe` or `.bat` installer file
   - The installer creates a desktop shortcut automatically

2. **Verify Installation**
   - Look for "D-Normalizer" shortcut on your desktop
   - No additional dependencies required

## How to Use

### Basic Workflow

1. **Launch the Application**
   - Double-click the D-Normalizer shortcut

2. **Select Folder**
   - Click "Browse..." button
   - Navigate to your root assets folder containing exported Photoshop images

3. **Run Processing**
   - Click "Run Full Scan & Normalization (All Cases)"
   - Monitor real-time progress in the console-style log window

4. **Review Results**
   - Find normalized images in `[YourFolder]/Normalized_Images/`
   - Check the detailed log for resizing actions and skipped files

### Understanding the Output

```
Normalized_Images/
├── Root_Direct_Assets/     (Case 1: Root images)
├── WordFolder1/            (Case 2: Subfolder images)
├── WordFolder2/            (Case 3: Parent of '1x' folders)
└── ...
```

### Log Table Format

```
File Name              | Original Size | Target Size   | Action
-----------------------|---------------|---------------|-----------------------
icon_small.png         | 128x126       | 128x128       | Resized
logo_main.png          | 256x256       | 256x256       | Copied (Same Size)
banner_wide.png        | 512x200       | 256x256       | Skipped (Asset)
```

## Configuration

Adjustable parameters (edit script if needed):

- **Tolerance**: `$Tolerance = 2` - Maximum pixel difference for normalization
- **Asset Threshold**: `$QuestionAssetThreshold = 10` - Skip images beyond this difference
- **Target Folder**: `$TargetSubfolderName = "1x"` - Specific subfolder name to target

## Limitations

1. **File Format**: Only processes PNG images (most common for UI assets)
2. **Windows Only**: Relies on Windows Forms and .NET Framework
3. **Single Execution**: No batch file processing across multiple root folders simultaneously
4. **Memory Usage**: Large image collections may require significant RAM during processing
5. **Manual Review**: "Question Assets" (>10px difference) require designer verification
6. **No Undo**: Changes cannot be reverted (originals remain untouched in source folder)

## Troubleshooting

**Issue**: "Failed to load required .NET assemblies"
- **Solution**: Ensure .NET Framework is fully installed, restart system

**Issue**: No images found
- **Solution**: Verify folder structure matches one of the three supported cases

**Issue**: Some images not resized
- **Solution**: Check log for "Skipped (Asset)" - these exceed the 10px threshold intentionally

## Best Practices

- **Backup First**: Always maintain original Photoshop exports before normalization
- **Review Logs**: Check the detailed output for any unexpected skips or errors
- **Verify Assets**: Manually inspect "Skipped (Asset)" files to confirm they're intentionally different sizes
- **Test Small**: Run on a small folder subset first to verify expected behavior

## Use Case Context

This tool was created to address a specific workflow issue where Photoshop-exported assets from a graphics team had minor pixel inconsistencies (±1-2px) that caused alignment problems in implementation. D-Normalizer automates the tedious manual correction process while preserving intentionally different-sized assets.

---
