# Setup.ps1 - Install or Uninstall the ARC Raiders CLI

param (
    [switch]$Uninstall
)

$ScriptPath = $PSScriptRoot
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
$BatchPath = Join-Path $ScriptPath "arc.bat"

function Write-Color {
    param($Text, $Color = "White")
    Write-Host $Text -ForegroundColor $Color
}

Write-Color "ARC Raiders CLI - Setup" "Cyan"
Write-Color "-----------------------" "DarkGray"

# -----------------------------------------------------------------------------
# UNINSTALL ROUTINE
# -----------------------------------------------------------------------------
if ($Uninstall) {
    Write-Color "[*] Uninstalling..." "Yellow"

    # 1. Remove from PATH
    if ($UserPath -like "*$ScriptPath*") {
        # Split, filter out our path, and rejoin
        $PathParts = $UserPath -split ";"
        $NewParts = $PathParts | Where-Object { $_ -ne $ScriptPath -and $_ -ne "" }
        $CleanPath = $NewParts -join ";"
        
        try {
            [Environment]::SetEnvironmentVariable("Path", $CleanPath, "User")
            Write-Color "[-] Removed '$ScriptPath' from PATH." "Green"
        } catch {
            Write-Color "[!] Failed to remove from PATH. Try running as Admin." "Red"
        }
    } else {
        Write-Color "[-] Directory not found in PATH (Clean)." "Gray"
    }

    # 2. Remove Batch Alias
    if (Test-Path $BatchPath) {
        Remove-Item $BatchPath -Force
        Write-Color "[-] Removed 'arc.bat' alias." "Green"
    }

    Write-Color "`nUninstallation Complete." "Cyan"
    Write-Color "You may delete this folder now." "Gray"
    exit
}

# -----------------------------------------------------------------------------
# INSTALL ROUTINE
# -----------------------------------------------------------------------------

# 1. Check for Git Submodule
if (-not (Test-Path "$ScriptPath\arcraiders-data\items")) {
    Write-Color "[*] Initializing data submodule..." "Yellow"
    try {
        Start-Process git -ArgumentList "submodule update --init --recursive" -WorkingDirectory $ScriptPath -Wait -NoNewWindow
        Write-Color "[+] Data downloaded successfully." "Green"
    } catch {
        Write-Color "[!] Failed to download data. Ensure git is installed." "Red"
        exit
    }
} else {
    Write-Color "[+] Data submodule already present." "Green"
}

# 2. Add to PATH
if ($UserPath -like "*$ScriptPath*") {
    Write-Color "[+] Current directory is already in PATH." "Green"
} else {
    Write-Color "[*] Adding '$ScriptPath' to User PATH..." "Yellow"
    try {
        [Environment]::SetEnvironmentVariable("Path", "$UserPath;$ScriptPath", "User")
        Write-Color "[+] PATH updated successfully." "Green"
        Write-Color "[!] NOTE: You must restart your terminal for this to take effect." "Magenta"
    } catch {
        Write-Color "[!] Failed to update PATH. Try running as Administrator." "Red"
    }
}

# 3. Create 'arc.bat' alias
$BatchContent = "@echo off`r`npowershell -ExecutionPolicy Bypass -File `"%~dp0ARCSearch.ps1`" %*"
try {
    Set-Content -Path $BatchPath -Value $BatchContent
    Write-Color "[+] Created 'arc' command alias." "Green"
} catch {
    Write-Color "[!] Failed to create alias." "Red"
}

Write-Color "`nSetup Complete!" "Cyan"
Write-Color "You can now type 'arc <query>' from any new terminal window." "White"
Write-Color "To uninstall: .\Setup.ps1 -Uninstall" "Gray"
