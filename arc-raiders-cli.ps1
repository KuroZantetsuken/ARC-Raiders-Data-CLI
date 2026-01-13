<#
.SYNOPSIS
    ARC Raiders CLI - A command-line utility for exploring ARC Raiders game data.
    Provides quick access to items, quests, hideout modules, and more, powered by data from github.com/RaidTheory/arcraiders-data/.

.DESCRIPTION
    This tool provides a terminal-based interface to search and view the structured game data used by arctracker.io.
    It supports searching for:
    - Items (Stats, Recipes, Stash Space Delta, Costs, Values, etc.)
    - Quests (Objectives, Traders)
    - Hideout Workshops (Upgrades, Requirements)
    - Map Events (Upcoming Schedule)
    - ARCs (Threat levels, Weaknesses, Drops)
    - Project Requirements
    - Skill Nodes

.EXAMPLE
    arc Cat Bed
    Search for an item and view its details.

.EXAMPLE
    arc cat 0
    View the first result for 'cat'.

.EXAMPLE
    arc events
    Show the next occurrence for each event type.

.EXAMPLE
    arc update
    Check and install updates.

.EXAMPLE
    arc
    Display the help text.

.LINK
    https://github.com/KuroZantetsuken/ARC-Raiders-CLI
    https://github.com/RaidTheory/arcraiders-data
    https://arctracker.io
#>

param (
    [Parameter(Position=0, ValueFromRemainingArguments=$true)]
    [string[]]$InputArgs
)

# -----------------------------------------------------------------------------
# PREREQUISITES & ARGUMENTS
# -----------------------------------------------------------------------------

$RepoRoot = $PSScriptRoot
$DataDir  = Join-Path $RepoRoot "arcraiders-data"
$PathItems, $PathQuests, $PathHideout, $PathEvents, $PathBots, $PathProjects, $PathSkills, $PathTrades = @(
    "items", "quests", "hideout", "map-events\map-events.json", "bots.json", "projects.json", "skillNodes.json", "trades.json"
) | ForEach-Object { Join-Path $DataDir $_ }
$GlobalCache = Join-Path $RepoRoot ".cache"


# Parse Arguments
$Query = ""; $SelectIndex = -1
if ($InputArgs) {
    if ($InputArgs.Count -gt 1 -and $InputArgs[-1] -match '^\d+$') {
        $SelectIndex = [int]$InputArgs[-1]
        $Query = $InputArgs[0..($InputArgs.Count - 2)] -join " "
    } else {
        $Query = $InputArgs -join " "
    }
}

# -----------------------------------------------------------------------------
# CONFIGURATION & THEME
# -----------------------------------------------------------------------------

$CurrentVersion = "vDEV"

# Start background update check
$UpdateJob = if ($CurrentVersion -ne "vDEV") {
    Start-Job -Name "ArcUpdateCheck" -ScriptBlock {
        param($Ver, $DataDir)
        $Result = @{ Script = $null; Data = $null }
        try {
            # 1. Script Update Check
            $LatestScript = Invoke-RestMethod -Uri "https://api.github.com/repos/KuroZantetsuken/ARC-Raiders-CLI/releases/latest" -ErrorAction SilentlyContinue
            if ($LatestScript.tag_name -and $LatestScript.tag_name -ne $Ver) {
                $Result.Script = @{ Version = $LatestScript.tag_name; Url = $LatestScript.html_url }
            }
            
            # 2. Data Update Check
            $DataVerFile = Join-Path $DataDir ".version"
            $CurrentDataVer = if (Test-Path $DataVerFile) { (Get-Content $DataVerFile -Raw).Trim() } else { "" }
            # Use main branch commit SHA for data versioning
            $LatestData = Invoke-RestMethod -Uri "https://api.github.com/repos/RaidTheory/arcraiders-data/commits/main" -ErrorAction SilentlyContinue
            if ($LatestData.sha -and $LatestData.sha -ne $CurrentDataVer) {
                $Result.Data = @{ Version = $LatestData.sha.Substring(0, 7); FullSha = $LatestData.sha }
            }
        } catch {}
        return $Result
    } -ArgumentList $CurrentVersion, $DataDir
} else { $null }


# ANSI Escape Codes
$Theme = @{
    Reset       = "0"
    Bold        = "1"
    
    # Standard Colors
    Black       = "30"; Red         = "31"; Green       = "32"
    Yellow      = "33"; Blue        = "34"; Magenta     = "35"
    Cyan        = "36"; White       = "37"
    
    # Bright Colors
    BrBlack     = "90"; BrRed       = "91"; BrGreen     = "92"
    BrYellow    = "93"; BrBlue      = "94"; BrMagenta   = "95"
    BrCyan      = "96"; BrWhite     = "97"
}

# Semantic Color Mapping
$Palette = @{
    Text        = $Theme.Reset
    Subtext     = $Theme.BrBlack
    Border      = $Theme.BrBlack
    Accent      = $Theme.Yellow
    Success     = $Theme.Green
    Warning     = $Theme.BrYellow
    Error       = $Theme.Red
    
    # Rarity Mapping
    Common      = $Theme.BrBlack  # Grey for Common
    Uncommon    = $Theme.BrGreen
    Rare        = $Theme.BrCyan
    Epic        = $Theme.BrMagenta
    Legendary   = $Theme.BrYellow
    
    # Skill Categories
    CONDITIONING = $Theme.Green
    MOBILITY     = $Theme.Yellow
    SURVIVAL     = $Theme.Red
}

$Esc = [char]27

# Symbols
$Sym = @{
    Currency    = [char]0x29B6 # ⦶
    Creds       = [char]0x24D1 # ⓑ
    Weight      = "WGT"
    Stack       = "STK"
    Arrow       = "->"
    Box         = @{ 
        H = [char]0x2500
        V = [char]0x2502
        TL = [char]0x250C
        TR = [char]0x2510
        BL = [char]0x2514
        BR = [char]0x2518
        L = [char]0x251C
        R = [char]0x2524
        C = [char]0x253C
        T = [char]0x252C
        B = [char]0x2534
    }
}

# -----------------------------------------------------------------------------
# CORE UTILITIES
# -----------------------------------------------------------------------------

function Write-Ansi {
    param (
        [string]$Text,
        [string]$ColorCode = $Theme.Reset,
        [switch]$NoNewline
    )
    if ([string]::IsNullOrEmpty($Text)) { return }
    $Out = "$Esc[${ColorCode}m$Text$Esc[0m"
    if ($NoNewline) { Write-Host $Out -NoNewline } else { Write-Host $Out }
}

function Get-DisplayLength {
    param ([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return 0 }
    if ($Text.IndexOf([char]27) -lt 0) { return $Text.Length }
    # Remove ANSI codes (CSI and OSC) to calculate visual length
    $T = $Text -replace "\x1B\[[0-9;]*[a-zA-Z]", ""
    $T = $T -replace "\x1B\].*?\x1B\\", ""
    return $T.Length
}

function ConvertTo-Hashtable {
    param ($Object)
    if ($null -eq $Object) { return @{} }
    if ($Object -is [hashtable]) { return $Object }
    $H = @{}
    if ($null -ne $Object -and $null -ne $Object.PSObject) {
        foreach ($P in $Object.PSObject.Properties) { $H[$P.Name] = $P.Value }
    }
    return $H
}

function Import-JsonFast {
    param ([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    try {
        $Content = [System.IO.File]::ReadAllText($Path)
        $Data = $Content | ConvertFrom-Json -ErrorAction Stop
        
        # Handle PowerShell's occasional 'value' property wrapping for collections
        if ($null -ne $Data -and $null -ne $Data.PSObject.Properties['value'] -and $null -ne $Data.PSObject.Properties['Count']) {
            return $Data.value
        }
        return $Data
    } catch {
        # Only warn if the file isn't empty (empty files are common for new caches)
        if ((Get-Item $Path).Length -gt 0) {
            Write-Ansi "Warning: Failed to parse JSON at $Path`: $($_.Exception.Message)" $Palette.Warning
        }
        return $null
    }
}

function Save-Cache {
    param ($Cache)
    try {
        # Ensure we save a clean object to avoid PSCustomObject 'value' nesting issues
        $CleanCache = ConvertTo-Hashtable $Cache
        ConvertTo-Json -InputObject $CleanCache -Depth 20 -Compress | Set-Content $GlobalCache -ErrorAction Stop
    } catch {
        # Silent failure for cache saving is acceptable, but we don't want to crash
    }
}

function Get-WrappedText {
    param (
        [string]$Text,
        [int]$Width = 55,
        [string]$Indent = " "
    )
    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
    
    $Lines = @()
    # Sanitize newlines to ensure clean wrapping
    $CleanText = $Text -replace "`r`n", " " -replace "`n", " "
    $Words = $CleanText -split ' '
    $CurrentLine = ""
    
    foreach ($Word in $Words) {
        if ([string]::IsNullOrWhiteSpace($Word)) { continue }
        
        # Calculate length (ignoring ANSI for safety if mixed, though normally text is plain here)
        $WordLen = (Get-DisplayLength $Word)
        $LineLen = (Get-DisplayLength $CurrentLine)
        $SpaceLen = if ($LineLen -gt 0) { 1 } else { 0 }
        
        if (($LineLen + $SpaceLen + $WordLen) -le $Width) {
            if ($SpaceLen -eq 1) { $CurrentLine += " " }
            $CurrentLine += $Word
        } else {
            if ($LineLen -gt 0) { $Lines += ($Indent + $CurrentLine) }
            $CurrentLine = $Word
            
            # Force split very long words
            while ((Get-DisplayLength $CurrentLine) -gt $Width) {
                $BreakPoint = $Width
                $Segment = $CurrentLine.Substring(0, $Width)
                # For URLs or long paths, try to break at natural delimiters (/ , ? &)
                $LastDelim = $Segment.LastIndexOfAny(@('/', '?', '&', '='))
                if ($LastDelim -gt 15) { $BreakPoint = $LastDelim + 1 }
                
                $Lines += ($Indent + $CurrentLine.Substring(0, $BreakPoint))
                $CurrentLine = $CurrentLine.Substring($BreakPoint)
            }
        }
    }
    if ((Get-DisplayLength $CurrentLine) -gt 0) { $Lines += ($Indent + $CurrentLine) }
    
    return $Lines
}

# -----------------------------------------------------------------------------
# UPDATE SYSTEM
# -----------------------------------------------------------------------------

function Show-UpdateBanner {
    param ($UpdateInfo)
    $Lines = @()
    
    if ($UpdateInfo.Script) {
        $Lines += "CLI Update: $($UpdateInfo.Script.Version)"
        $Lines += "  URL: $($UpdateInfo.Script.Url)"
        $Lines += ""
    }
    
    if ($UpdateInfo.Data) {
        $Lines += "Data Update: $($UpdateInfo.Data.Version)"
        $Lines += ""
    }
    
    $Lines += "Run 'arc update' to install."
    
    Show-Card -Title "UPDATE AVAILABLE" -Content $Lines -ThemeColor $Palette.Warning -BorderColor $Palette.Warning
}

function Update-Data {
    param ([switch]$Silent)
    if (-not $Silent) { Write-Ansi "Checking for data updates..." $Palette.Accent }
    
    try {
        $DataRepo = "RaidTheory/arcraiders-data"
        $Latest = Invoke-RestMethod -Uri "https://api.github.com/repos/$DataRepo/commits/main" -ErrorAction Stop
        
        $DataVerFile = Join-Path $DataDir ".version"
        $CurrentDataVer = if (Test-Path $DataVerFile) { (Get-Content $DataVerFile -Raw).Trim() } else { "" }
        
        if ($Latest.sha -eq $CurrentDataVer) {
            if (-not $Silent) { Write-Ansi "Data is already up to date." $Palette.Success }
            return
        }

        if (-not $Silent) { Write-Ansi "Updating game data to $($Latest.sha.Substring(0,7))..." $Palette.Accent }

        $FilesToDownload = @()
        $FilesToDelete = @()

        if ([string]::IsNullOrWhiteSpace($CurrentDataVer)) {
            # 1. Fresh install: Get all files via Tree API
            if (-not $Silent) { Write-Ansi "Fetching data tree..." $Palette.Subtext }
            $Tree = Invoke-RestMethod -Uri "https://api.github.com/repos/$DataRepo/git/trees/main?recursive=1" -ErrorAction Stop
            $FilesToDownload = if ($null -ne $Tree -and $null -ne $Tree.tree) { $Tree.tree | Where-Object { $_.path -like "*.json" -or $_.path -eq "LICENSE" } | ForEach-Object { $_.path } } else { @() }
        } else {
            # 2. Incremental update: Get changes via Compare API
            if (-not $Silent) { Write-Ansi "Calculating changes..." $Palette.Subtext }
            $Compare = Invoke-RestMethod -Uri "https://api.github.com/repos/$DataRepo/compare/$CurrentDataVer...main" -ErrorAction Stop
            
            # If there are too many changes, the Compare API might be truncated (limit 300)
            if ($Compare.total_commits -gt 0 -and (-not $Compare.files -or $Compare.files.Count -eq 0)) {
                 # Fallback to Tree API if Compare API is insufficient
                 $Tree = Invoke-RestMethod -Uri "https://api.github.com/repos/$DataRepo/git/trees/main?recursive=1" -ErrorAction Stop
                 $FilesToDownload = if ($null -ne $Tree -and $null -ne $Tree.tree) { $Tree.tree | Where-Object { $_.path -like "*.json" -or $_.path -eq "LICENSE" } | ForEach-Object { $_.path } } else { @() }
            } else {
                foreach ($F in $Compare.files) {
                    if ($F.filename -like "*.json" -or $F.filename -eq "LICENSE") {
                        if ($F.status -eq "removed") { $FilesToDelete += $F.filename }
                        else {
                            $FilesToDownload += $F.filename
                            if ($F.status -eq "renamed") { $FilesToDelete += $F.previous_filename }
                        }
                    }
                }
            }
        }

        if ($FilesToDownload.Count -eq 0 -and $FilesToDelete.Count -eq 0) {
            $Latest.sha | Set-Content $DataVerFile -Force
            if (-not $Silent) { Write-Ansi "Data is already up to date." $Palette.Success }
            return
        }

        # Perform deletions
        foreach ($Path in $FilesToDelete) {
            $LocalPath = Join-Path $DataDir $Path
            if (Test-Path $LocalPath) { Remove-Item $LocalPath -Force }
        }

        # Perform downloads
        $Total = $FilesToDownload.Count
        if ($Total -gt 0) {
            # Pre-create directory structure to avoid race conditions in parallel mode
            $FilesToDownload | ForEach-Object {
                $Dest = Join-Path $DataDir $_
                $DestFolder = Split-Path $Dest -Parent
                if (-not (Test-Path $DestFolder)) { New-Item -Path $DestFolder -ItemType Directory -Force | Out-Null }
            }

            if ($PSVersionTable.PSVersion.Major -ge 7) {
                # Modern PowerShell: High-speed parallel downloads
                if (-not $Silent) { Write-Ansi "Downloading $Total files in parallel..." $Palette.Subtext }
                $FilesToDownload | ForEach-Object -ThrottleLimit 20 -Parallel {
                    $Path = $_
                    $DataDir = $using:DataDir
                    $DataRepo = $using:DataRepo
                    
                    $Dest = Join-Path $DataDir $Path
                    $Url = "https://raw.githubusercontent.com/$DataRepo/main/$Path"
                    
                    if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
                        # Using curl if available as it's often faster than Invoke-WebRequest
                        curl.exe -s -L -f -o "$Dest" "$Url"
                    } else {
                        Invoke-WebRequest -Uri $Url -OutFile $Dest -ErrorAction Stop
                    }
                }
            } else {
                # Legacy PowerShell: Sequential downloads with progress
                $Count = 0
                foreach ($Path in $FilesToDownload) {
                    $Count++
                    if (-not $Silent) {
                        $Percent = [math]::Round(($Count / $Total) * 100)
                        Write-Progress -Activity "Downloading Game Data" -Status "Fetching $Path ($Count/$Total)" -PercentComplete $Percent
                    }

                    $Dest = Join-Path $DataDir $Path
                    $Url = "https://raw.githubusercontent.com/$DataRepo/main/$Path"
                    
                    if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
                        curl.exe -s -L -f -o "$Dest" "$Url"
                    } else {
                        Invoke-WebRequest -Uri $Url -OutFile $Dest -ErrorAction Stop
                    }
                }
            }
        }

        if (-not $Silent) { Write-Progress -Activity "Downloading Game Data" -Completed }

        # Write version file
        $Latest.sha | Set-Content $DataVerFile -Force
        
        # Invalidate cache
        if (Test-Path $GlobalCache) { Remove-Item $GlobalCache -Force -ErrorAction SilentlyContinue }
        
        if (-not $Silent) { Write-Ansi "Data update complete! ($Total files updated)" $Palette.Success }
    } catch {
        if (-not $Silent) { Write-Progress -Activity "Downloading Game Data" -Completed }
        Write-Ansi "Data update failed: $($_.Exception.Message)" $Palette.Error
    }
}

function Confirm-Data {
    if (-not (Test-Path $PathItems)) {
        if ($CurrentVersion -eq "vDEV") {
            Write-Host "`n[!] Data missing. Since you are in vDEV mode, please run:" -ForegroundColor Yellow
            Write-Host "    git submodule update --init --recursive" -ForegroundColor Cyan
        } else {
            Write-Host "`n[!] Data missing. Downloading latest game data..." -ForegroundColor Yellow
            Update-Data
            if (Test-Path $PathItems) { Write-Host "[+] Data initialized.`n" -ForegroundColor Green }
            else { Write-Host "[!] Failed to download data. Please check your connection and run 'arc update'." -ForegroundColor Red }
        }
        if (-not (Test-Path $PathItems)) { exit }
    }
}

function Update-ArcRaidersCLI {
    if ($CurrentVersion -eq "vDEV") {
        Write-Ansi "Update is disabled in vDEV mode." $Palette.Warning
        return
    }

    Write-Ansi "Starting system update..." $Palette.Accent
    
    # 1. Update Script
    try {
        $Repo = "KuroZantetsuken/ARC-Raiders-CLI"
        $Url  = "https://api.github.com/repos/$Repo/releases/latest"
        $Latest = Invoke-RestMethod -Uri $Url -ErrorAction Stop
        
        if ($Latest.tag_name -ne $CurrentVersion) {
            Write-Ansi "Updating script to $($Latest.tag_name)..." $Palette.Accent
            
            $Asset = $Latest.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1
            if ($Asset) {
                # Display Changelog
                if ($Latest.body) {
                    $ChangelogLines = @()
                    $RawLines = $Latest.body -split "`r?`n"
                    $NoteIdx = -1
                    for ($i = $RawLines.Count - 1; $i -ge 0; $i--) {
                        if ($RawLines[$i] -like "*[!NOTE]*") { $NoteIdx = $i; break }
                    }
                    if ($NoteIdx -ne -1) { $RawLines = $RawLines[0..($NoteIdx - 1)] }
                    foreach ($Line in $RawLines) {
                        if ([string]::IsNullOrWhiteSpace($Line)) { $ChangelogLines += ""; continue }
                        $ChangelogLines += Get-WrappedText -Text $Line -Indent " "
                    }
                    Show-Card -Title "RELEASE NOTES" -Content $ChangelogLines -ThemeColor $Palette.Accent -BorderColor $Palette.Border
                }

                $TempDir = Join-Path $RepoRoot ".update_tmp"
                try {
                    if (Test-Path $TempDir) { Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue }
                    New-Item -Path $TempDir -ItemType Directory -Force | Out-Null
                    
                    $ZipPath = Join-Path $TempDir "update.zip"
                    $ExtPath = Join-Path $TempDir "extracted"
                    
                    $Url = $Asset.browser_download_url
                    if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
                        curl.exe -s -L -f -o "$ZipPath" "$Url"
                    } else {
                        Invoke-WebRequest -Uri $Url -OutFile $ZipPath -ErrorAction Stop
                    }
                    Expand-Archive -Path $ZipPath -DestinationPath $ExtPath -Force -ErrorAction Stop

                    if (Test-Path (Join-Path $ExtPath "arc-raiders-cli.ps1")) {
                        $BackupFile = Join-Path $RepoRoot "arc-raiders-cli.ps1.bak"
                        Copy-Item -Path $PSCommandPath -Destination $BackupFile -Force
                        
                        try {
                            $UpdateFiles = Get-ChildItem -Path $ExtPath -Recurse
                            foreach ($File in $UpdateFiles) {
                                $RelativePath = $File.FullName.Substring($ExtPath.Length + 1)
                                $Dest = Join-Path $RepoRoot $RelativePath
                                if ($File.PSIsContainer) {
                                    if (-not (Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force | Out-Null }
                                } else {
                                    if ($File.Name -eq ".cache" -or $File.Name -eq ".gitignore" -or $File.Name -eq ".gitmodules" -or $RelativePath.StartsWith("arcraiders-data")) {
                                        continue
                                    }
                                    if (Test-Path $Dest) {
                                        $TempFile = $Dest + ".old"
                                        Move-Item -Path $Dest -Destination $TempFile -Force -ErrorAction SilentlyContinue
                                        Copy-Item -Path $File.FullName -Destination $Dest -Force
                                        Remove-Item $TempFile -Force -ErrorAction SilentlyContinue
                                    } else {
                                        Copy-Item -Path $File.FullName -Destination $Dest -Force
                                    }
                                }
                            }
                            Remove-Item $BackupFile -Force -ErrorAction SilentlyContinue
                            Write-Ansi "Script update successful." $Palette.Success
                        } catch {
                            if (Test-Path $BackupFile) { Move-Item -Path $BackupFile -Destination $PSCommandPath -Force }
                            throw $_
                        }
                    }
                } finally {
                    Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        } else {
            Write-Ansi "Script is already up to date ($CurrentVersion)." $Palette.Success
        }
    } catch {
        Write-Ansi "Script update failed: $($_.Exception.Message)" $Palette.Error
    }

    # 2. Update Data
    Update-Data
    
    Write-Ansi "`nUpdate process complete!" $Palette.Success
    Write-Ansi "Please restart your terminal session." $Palette.Subtext
}

# -----------------------------------------------------------------------------
# UI COMPONENTS
# -----------------------------------------------------------------------------

function Write-BoxRow {
    param (
        [string]$Left,
        [string]$Middle,
        [string]$Right,
        [string]$Color = $Palette.Border,
        [int]$Width = 60
    )
    $Fill = if ($Width -gt 2) { [string]::new($Middle[0], $Width - 2) } else { "" }
    Write-Ansi "$Left$Fill$Right" $Color
}

function Write-ContentRow {
    param (
        [string]$Text,
        [string]$TextColor = $Palette.Text,
        [string]$BorderColor = $Palette.Border,
        [int]$Width = 60,
        [string]$Align = "Left"
    )
    $VisLen = Get-DisplayLength $Text
    if ($VisLen -gt ($Width - 2)) {
        $Text = $Text.Substring(0, [math]::Max(0, $Width - 5)) + "..."
        $VisLen = Get-DisplayLength $Text
    }
    $PadTotal = [math]::Max(0, $Width - 2 - $VisLen)
    
    $PadL = switch ($Align) { "Right" { $PadTotal }; "Center" { [math]::Floor($PadTotal / 2) }; default { 0 } }
    $PadR = $PadTotal - $PadL
    
    Write-Ansi $Sym.Box.V $BorderColor -NoNewline
    Write-Ansi "$(' '*$PadL)$Text$(' '*$PadR)" $TextColor -NoNewline
    Write-Ansi $Sym.Box.V $BorderColor
}

function Show-Card {
    param (
        [string]$Title,
        [string]$Subtitle,
        [string[]]$Content,
        [string]$ThemeColor = $Palette.Text,
        [string]$BorderColor = $Palette.Border,
        [int]$Width = 60
    )
    
    Write-BoxRow $Sym.Box.TL $Sym.Box.H $Sym.Box.TR $BorderColor $Width
    
    if ($Title) {
        $T = $Title.ToUpper()
        if ((Get-DisplayLength $T) -gt ($Width-4)) { $T = $T.Substring(0, $Width-7) + "..." }
        Write-ContentRow -Text $T -TextColor $ThemeColor -BorderColor $BorderColor -Width $Width
    }
    
    if ($Subtitle) {
        $SubLines = Get-WrappedText -Text $Subtitle -Width ($Width - 4) -Indent ""
        foreach ($SL in $SubLines) {
            if ($null -ne $SL) {
                Write-ContentRow -Text $SL.Trim() -TextColor $Palette.Subtext -BorderColor $BorderColor -Width $Width
            }
        }
    }
    
    foreach ($Line in $Content) {
        if ($Line -eq "---") {
            Write-BoxRow $Sym.Box.L $Sym.Box.H $Sym.Box.R $BorderColor $Width
        } else {
            $RowColor = if ($Line -match "\x1B\[") { $Theme.Reset } else { $Palette.Text }
            Write-ContentRow -Text $Line -TextColor $RowColor -BorderColor $BorderColor -Width $Width
        }
    }
    
    Write-BoxRow $Sym.Box.BL $Sym.Box.H $Sym.Box.BR $BorderColor $Width
}


# -----------------------------------------------------------------------------
# DATA ENGINE
# -----------------------------------------------------------------------------

$Global:Data = @{
    Items    = @{}
    Quests   = @()
    Hideout  = @()
    Bots     = @()
    Projects = @()
    Skills   = @()
    Trades   = @()
}
$Global:DataLoaded = $false

function Initialize-Data {
    param ([switch]$ShowStatus)

    if ($Global:DataLoaded) { return }
    Confirm-Data

    # Check Cache Validity
    $NeedsRebuild = $true
    $Cache = if (Test-Path $GlobalCache) { Import-JsonFast $GlobalCache } else { @{} }
    $Cache = ConvertTo-Hashtable $Cache
    
    if ($Cache.ContainsKey("Data") -and $null -ne $Cache.Data) {
        $CacheTime = (Get-Item $GlobalCache).LastWriteTime
        
        # Fast check: check data sources and the script itself for changes
        $NeedsRebuild = (Get-Item $PSCommandPath).LastWriteTime -gt $CacheTime
        
        if (-not $NeedsRebuild) {
            # Check for any modified JSON files in the data directory recursively
            try {
                $LatestDataTime = [DateTime]::MinValue
                $DataFiles = [System.IO.Directory]::GetFiles($DataDir, "*.json", [System.IO.SearchOption]::AllDirectories)
                foreach ($File in $DataFiles) {
                    $Time = [System.IO.File]::GetLastWriteTime($File)
                    if ($Time -gt $LatestDataTime) { $LatestDataTime = $Time }
                }
                if ($LatestDataTime -gt $CacheTime) { $NeedsRebuild = $true }
            } catch {
                # Fallback to rebuild if file inspection fails
                $NeedsRebuild = $true
            }
        }
        
        # If data sources haven't changed, we trust the cache
        if (-not $NeedsRebuild) {
            $Global:Data = $Cache.Data
            $Global:Data.Items = ConvertTo-Hashtable $Global:Data.Items
            $Global:DataLoaded = $true
        }
    }

    if ($ShowStatus) {
        $HasData = $Cache.ContainsKey("Data") -and $null -ne $Cache.Data
        $StatusMsg = if ($NeedsRebuild -and -not $HasData) { " (building cache)" } elseif ($NeedsRebuild) { " (updating cache)" } else { "" }
        Write-Ansi "Searching$StatusMsg..." $Palette.Subtext
    }

    if ($NeedsRebuild) {
        # Completely wipe the cache object to avoid structure conflicts
        $Cache = @{}

        # Load from files
        if (Test-Path $PathItems) {
            $Files = [System.IO.Directory]::GetFiles($PathItems, "*.json")
            foreach ($File in $Files) {
                $J = Import-JsonFast $File
                if ($J -and $null -ne $J.id) { $Global:Data.Items[$J.id] = $J }
            }
        }
        if (Test-Path $PathQuests) {
            $Files = [System.IO.Directory]::GetFiles($PathQuests, "*.json")
            $List = [System.Collections.Generic.List[psobject]]::new()
            foreach ($File in $Files) {
                $J = Import-JsonFast $File
                if ($J) { $List.Add($J) }
            }
            $Global:Data.Quests = $List.ToArray()
        }
        if (Test-Path $PathHideout) {
            $Files = [System.IO.Directory]::GetFiles($PathHideout, "*.json")
            $List = [System.Collections.Generic.List[psobject]]::new()
            foreach ($File in $Files) {
                $J = Import-JsonFast $File
                if ($J) { $List.Add($J) }
            }
            $Global:Data.Hideout = $List.ToArray()
        }
        
        $Global:Data.Bots     = @(Import-JsonFast $PathBots)
        $Global:Data.Projects = @(Import-JsonFast $PathProjects)
        $Global:Data.Skills   = @(Import-JsonFast $PathSkills)
        $Global:Data.Trades   = @(Import-JsonFast $PathTrades)

        # Update cache
        $Cache["Data"] = $Global:Data
        Save-Cache -Cache $Cache
        $Global:DataLoaded = $true
    }
}

function Get-ItemName {
    param ($Id)
    if ([string]::IsNullOrWhiteSpace($Id)) { return "" }
    $Item = $Global:Data.Items."$Id"
    if ($null -ne $Item -and $null -ne $Item.name -and $null -ne $Item.name.en) { return $Item.name.en }
    $Str = [string]$Id
    return $Str -replace "_", " " -replace "\b\w", { if ($args[0]) { $args[0].Value.ToUpper() } else { "" } }
}

function Get-ItemValue {
    param ($Id)
    if ([string]::IsNullOrWhiteSpace($Id)) { return 0 }
    if ($Id -eq "coins" -or $Id -eq "creds") { return 1 }
    $Item = $Global:Data.Items."$Id"
    if ($null -ne $Item -and $null -ne $Item.value) { return [int]$Item.value }
    return 0
}

function Get-ItemSlotUsage {
    param ($Id, $Quantity)
    $Item = $Global:Data.Items.$Id
    if (-not $Item) { return 0 }
    $StackSize = $Item.stackSize
    if (-not $StackSize -or $StackSize -eq 0) { $StackSize = 1 }
    return $Quantity / $StackSize
}

function Get-StashSpaceDelta {
    param ($Item)
    if (-not $Item.recipe) { return $null }
    $IngSlots = 0
    $Item.recipe.PSObject.Properties | ForEach-Object {
        $IngSlots += (Get-ItemSlotUsage -Id $_.Name -Quantity $_.Value)
    }
    $Yield = if ($Item.craftQuantity) { $Item.craftQuantity } else { 1 }
    $ResSlots = Get-ItemSlotUsage -Id $Item.id -Quantity $Yield
    return $ResSlots - $IngSlots
}

function Get-FormattedBadge {
    param ($Text, $ColorKey)
    $C = if ($Palette.ContainsKey($ColorKey)) { $Palette[$ColorKey] } else { $Palette.Common }
    $Bg = [int]$C + 10
    return "$Esc[${Bg};30m $Text $Esc[0m"
}

function Format-DiffString {
    param ([int]$Value, [switch]$Invert)
    if ($Value -eq 0) { return "" }
    $S = if ($Value -gt 0) { "+" } else { "" }
    if ($Invert) {
        $C = if ($Value -gt 0) { $Palette.Error } else { $Palette.Success }
    } else {
        $C = if ($Value -gt 0) { $Palette.Success } else { $Palette.Error }
    }
    return "($Esc[${C}m$S$Value$Esc[0m)"
}

# -----------------------------------------------------------------------------
# DISPLAY LOGIC
# -----------------------------------------------------------------------------

function Show-Item {
    param ($Item)
    $Color = if ($Palette.ContainsKey($Item.rarity)) { $Palette[$Item.rarity] } else { $Palette.Common }
    $Lines = @(" $(Get-FormattedBadge $Item.type $Item.rarity) $(Get-FormattedBadge $Item.rarity $Item.rarity)")
    if ($Item.description.en) { $Lines += (Get-WrappedText $Item.description.en -Indent " ") }
    
    # Effects
    if ($Item.effects) {
        $Effs = foreach ($K in $Item.effects.PSObject.Properties.Name) {
            if ($K -eq "Durability") { continue }
            $E = $Item.effects.$K; $L = if ($E.en) { $E.en } else { $K }
            if ($E.value) { " $($L): $($E.value)" }
        }
        if ($Effs) { $Lines += "---"; $Lines += $Effs }
    }
    
    # Stats
    $Lines += "---"
    $Stats = @()
    if ($Item.stackSize) { $Stats += "$($Sym.Stack) $($Item.stackSize)" }
    if ($Item.weightKg)  { $Stats += "$($Sym.Weight) $($Item.weightKg)kg" }
    $Val = [int]$Item.value; $Stats += "$($Sym.Currency) $Val"
    $Lines += " $($Stats -join '   ')"
    
    # Recipe
    if ($Item.recipe) {
        $Lines += "---"; $Lines += " RECIPE:"; $Cost = 0
        foreach ($P in $Item.recipe.PSObject.Properties) {
            $Lines += (Get-WrappedText " - $($P.Value)x $(Get-ItemName $P.Name)" -Indent " ")
            $Cost += ($P.Value * (Get-ItemValue $P.Name))
        }
        $Lines += " COST: $($Sym.Currency) $Cost $(Format-DiffString ($Val - $Cost))"
        $Delta = Get-StashSpaceDelta -Item $Item
        if ($null -ne $Delta) {
            $DeltaColor = if ($Delta -le 0) { $Palette.Success } else { $Palette.Error }
            $Lines += " SPACE: $Esc[${DeltaColor}m{0:0.##}$Esc[0m slots $(Format-DiffString (-$Delta))" -f $Delta
        }
    }
    
    # Recycling & Salvaging
    foreach ($K in @("recyclesInto", "salvagesInto")) {
        if ($Item.$K -and $Item.$K.PSObject.Properties.Count -gt 0) {
            $Lines += "---"; $Lines += " $($K.Replace('Into', '').ToUpper())S INTO:"; $PVal = 0
            foreach ($P in $Item.$K.PSObject.Properties) {
                $Lines += "  - $($P.Value)x $(Get-ItemName $P.Name)"
                $PVal += ($P.Value * (Get-ItemValue $P.Name))
            }
            $Lines += " VALUE: $($Sym.Currency) $PVal $(Format-DiffString ($PVal - $Val))"
        }
    }

    # Sources
    $Sources = @()
    if ($Item.foundIn -and ($Item.foundIn -ne "ARC")) { $Sources += " - $($Item.foundIn)" }
    $Bots = $Global:Data.Bots | Where-Object { $_.drops -contains $Item.id }
    if ($Bots) { if ($Bots.Count -gt 4) { $Sources += " - Various ARCs ($($Bots.Count))" } else { $Bots | ForEach-Object { $Sources += " - $($_.name) (ARC)" } } }
    $Quests = $Global:Data.Quests | Where-Object { $_.grantedItemIds.itemId -contains $Item.id }
    if ($Quests) { if ($Quests.Count -gt 3) { $Sources += " - Various Quests ($($Quests.Count))" } else { $Quests | ForEach-Object { $Sources += " - $($_.name.en) (Quest)" } } }
    if ($Sources) { $Lines += "---"; $Lines += " FOUND IN:"; $Lines += $Sources }

    # Trades
    $Trades = $Global:Data.Trades | Where-Object { $_.itemId -eq $Item.id }
    if ($Trades) {
        $Market = ($Trades | Where-Object { $_.cost.itemId -eq "coins" } | Select-Object -First 1).cost.quantity
        $Lines += "---"; $Lines += " SOLD BY:"
        foreach ($T in $Trades) {
            $Limit = if ($T.dailyLimit) { "$($T.dailyLimit)x " } else { "" }
            $Lines += " - $Limit$($T.trader)"
            $CId = $T.cost.itemId; $CQty = $T.cost.quantity
            if ($CId -eq "coins") { $Lines += " PRICE: $($Sym.Currency) $CQty $(Format-DiffString ($CQty - $Val) -Invert)" }
            elseif ($CId -eq "creds") {
                $Rate = if ($Market) { "($($Sym.Creds) 1 = $($Sym.Currency) $([math]::Round($Market/$CQty, 2)))" } else { "" }
                $Lines += " PRICE: $($Sym.Creds) $CQty $Rate"
            } else { $Lines += " PRICE: ${CQty}x $(Get-ItemName $CId) $(Format-DiffString ($CQty * (Get-ItemValue $CId) - $Val) -Invert)" }
        }
    }
    Show-Card -Title $Item.name.en -Subtitle "Item" -Content $Lines -ThemeColor $Color -BorderColor $Color
}

function Show-Bot {
    param ($Bot)
    $ThreatColors = @{ "Low"="Success"; "Moderate"="Warning"; "High"="Error"; "Critical"="Error"; "Extreme"="Error" }
    $ThColor = if ($ThreatColors.ContainsKey($Bot.threat)) { $ThreatColors[$Bot.threat] } else { "Text" }
    
    $Indent = " "
    $Lines = @()
    
    # Badges
    $B1 = Get-FormattedBadge -Text $Bot.type -ColorKey $ThColor
    $B2 = Get-FormattedBadge -Text $Bot.threat -ColorKey $ThColor
    $Lines += ($Indent + "$B1 $B2")
    
    # Desc
    if ($Bot.description) { $Lines += (Get-WrappedText $Bot.description -Indent $Indent) }
    
    # Weakness
    if ($Bot.weakness) {
        $Lines += "---"
        $Lines += ($Indent + "WEAKNESS:")
        $Lines += (Get-WrappedText $Bot.weakness -Indent $Indent)
    }
    
    # Loot / Drops
    if ($Bot.drops) {
        $Lines += "---"
        $Lines += ($Indent + "DROPS:")
        foreach ($D in $Bot.drops) {
            $Lines += ($Indent + " - $(Get-ItemName $D)")
        }
    }
    
    # Maps
    if ($Bot.maps) {
        $Lines += "---"
        $Lines += ($Indent + "LOCATIONS:")
        foreach ($M in $Bot.maps) {
            $MName = (Get-Culture).TextInfo.ToTitleCase(($M -replace "_", " "))
            $Lines += ($Indent + " - $MName")
        }
    }
    
    Show-Card -Title $Bot.name -Subtitle "ARC" -Content $Lines -ThemeColor $Palette[$ThColor] -BorderColor $Palette[$ThColor]
}

function Show-Project {
    param ($Proj)
    $Indent = " "
    $Lines = @()
    
    if ($Proj.description.en) {
        $Lines += (Get-WrappedText $Proj.description.en -Indent $Indent)
    }
    
    if ($Proj.phases) {
        foreach ($Phase in $Proj.phases) {
            $Lines += "---"
            $PName = if ($Phase.name.en) { $Phase.name.en } else { "Phase $($Phase.phase)" }
            $Lines += ($Indent + "PHASE $($Phase.phase): $PName")
            
            if ($Phase.description.en) {
                $Lines += (Get-WrappedText $Phase.description.en -Indent $Indent)
            }
            
            if ($Phase.requirementItemIds) {
                $Lines += ($Indent + "REQUIREMENTS:")
                foreach ($Req in $Phase.requirementItemIds) {
                    $Lines += ($Indent + " - $($Req.quantity)x $(Get-ItemName $Req.itemId)")
                }
            }
            if ($Phase.requirementCategories) {
                foreach ($Req in $Phase.requirementCategories) {
                    $Lines += ($Indent + " - $($Sym.Currency) $($Req.valueRequired) in $($Req.category)")
                }
            }
        }
    }
    
    Show-Card -Title $Proj.name.en -Subtitle "Project" -Content $Lines -ThemeColor $Palette.Accent
}

function Show-Skill {
    param ($Skill)
    $Indent = " "
    $Lines = @()
    
    $CatColorKey = $Skill.category
    $CatColor = if ($Palette.ContainsKey($CatColorKey)) { $Palette[$CatColorKey] } else { $Palette.Accent }

    # Badge
    $Lines += ($Indent + (Get-FormattedBadge -Text $Skill.category -ColorKey $CatColorKey))
    
    if ($Skill.description.en) {
        $Lines += (Get-WrappedText $Skill.description.en -Indent $Indent)
    }
    
    $Lines += "---"
    if ($Skill.impactedSkill.en) {
        $Lines += ($Indent + "IMPACTS: $($Skill.impactedSkill.en)")
    }
    if ($Skill.maxPoints) {
        $Lines += ($Indent + "MAX POINTS: $($Skill.maxPoints)")
    }
    
    Show-Card -Title $Skill.name.en -Subtitle "Skill" -Content $Lines -ThemeColor $CatColor -BorderColor $CatColor
}

function Show-Quest {
    param ($Quest)
    $Lines = @("TRADER: $($Quest.trader)", "---")
    if ($Quest.objectives) {
        $Lines += "OBJECTIVES:"
        foreach ($O in $Quest.objectives) {
            if ($O.en) { $Lines += (Get-WrappedText "[ ] $($O.en)" -Indent " ") }
        }
    }
    if ($Quest.grantedItemIds) {
        $Lines += "---"
        $Lines += "REWARDS:"
        foreach ($R in $Quest.grantedItemIds) {
            $Lines += " - $($R.quantity)x $(Get-ItemName $R.itemId)"
        }
    }
    Show-Card -Title $Quest.name.en -Subtitle "Quest" -Content $Lines -ThemeColor $Palette.Accent
}

function Show-Hideout {
    param ($Hideout)
    $Lines = @()
    foreach ($L in $Hideout.levels) {
        if ($Lines.Count -gt 0) { $Lines += "---" }
        $Lines += "LEVEL $($L.level):"
        if ($L.requirementItemIds) {
            foreach ($Req in $L.requirementItemIds) {
                $Lines += " - $($Req.quantity)x $(Get-ItemName $Req.itemId)"
            }
        }
    }
    Show-Card -Title $Hideout.name.en -Subtitle "Hideout" -Content $Lines -ThemeColor $Palette.Accent
}

function Get-UpcomingEvents {
    param ($Sched, $Types)
    if ($null -eq $Sched -or $null -eq $Types) { return @() }
    $BaseTime = [DateTime]::UtcNow.Date.AddHours([DateTime]::UtcNow.Hour)
    $NextEvents = @{}
    
    for ($i = 0; $i -lt 24; $i++) {
        $TargetTime = $BaseTime.AddHours($i)
        $Hour = $TargetTime.Hour
        
        foreach ($MapKey in $Sched.PSObject.Properties.Name) {
            foreach ($Cat in @("major", "minor")) {
                $Category = try { $Sched.$MapKey.$Cat } catch { $null }
                if ($null -eq $Category) { continue }
                $Key = $Category."$Hour"
                if ($null -ne $Key -and $null -ne $Types.$Key -and -not $Types.$Key.disabled) {
                    $Name = $Types.$Key.displayName
                    if (-not $NextEvents.ContainsKey($Name)) {
                        $NextEvents[$Name] = [PSCustomObject]@{
                            Name     = $Name
                            MapKey   = $MapKey
                            Cat      = $Cat
                            TimeSort = $i
                            TimeStr  = if ($i -eq 0) { "NOW" } else { $TargetTime.ToLocalTime().ToString("HH:mm") }
                        }
                    }
                }
            }
        }
    }
    return $NextEvents.Values | Group-Object TimeSort | Sort-Object { [int]$_.Name }
}

function Show-Events {
    Confirm-Data
    if (-not (Test-Path $PathEvents)) { Write-Ansi "Event data missing." $Palette.Error; return }
    $Data = Import-JsonFast $PathEvents
    $Groups = Get-UpcomingEvents -Sched $Data.schedule -Types $Data.eventTypes
    
    $W_Time = 7; $W_Events = 60; $W_Total = $W_Time + $W_Events + 3
    $MapColors = @{
        "blue-gate" = @{ T="34"; B="44" }; "buried-city" = @{ T="33"; B="43" }; "dam-battleground" = @{ T="90"; B="100" }
        "the-spaceport" = @{ T="31"; B="41" }; "stella-montis" = @{ T="36"; B="46" }
    }
    
    Write-BoxRow $Sym.Box.TL $Sym.Box.H $Sym.Box.TR $Palette.Border $W_Total
    Write-ContentRow " UPCOMING SCHEDULE " -TextColor "7" -Width $W_Total -Align Center
    Write-Ansi "$($Sym.Box.L)$([string]::new($Sym.Box.H, $W_Time))$($Sym.Box.T)$([string]::new($Sym.Box.H, $W_Events))$($Sym.Box.R)" $Palette.Border

    $First = $true
    foreach ($Grp in $Groups) {
        if (-not $First) { Write-Ansi "$($Sym.Box.L)$([string]::new($Sym.Box.H, $W_Time))$($Sym.Box.C)$([string]::new($Sym.Box.H, $W_Events))$($Sym.Box.R)" $Palette.Border }
        $First = $false
        
        $Events = $Grp.Group | Sort-Object @{Expression="Cat"; Descending=$false}, "Name"
        $Strings = foreach ($E in $Events) {
            $C = if ($MapColors.ContainsKey($E.MapKey)) { $MapColors[$E.MapKey] } else { @{ T="37"; B="40" } }
            if ($E.Cat -eq "major") { "$Esc[$($C.B);30m $($E.Name) $Esc[0m" } else { "$Esc[$($C.T)m$($E.Name)$Esc[0m" }
        }
        
        $Lines = @(); $Buffer = @(); $Len = 0
        foreach ($S in $Strings) {
            $Sep = if ($Buffer.Count -gt 0) { 2 } else { 0 }
            $CLen = (Get-DisplayLength $S) + $Sep
            if (($Len + $CLen) -gt ($W_Events - 2)) { $Lines += ($Buffer -join ", "); $Buffer = @($S); $Len = (Get-DisplayLength $S) }
            else { $Buffer += $S; $Len += $CLen }
        }
        if ($Buffer.Count -gt 0) { $Lines += ($Buffer -join ", ") }
        
        for ($i=0; $i -lt $Lines.Count; $i++) {
            $T = if ($i -eq 0) { $Grp.Group[0].TimeStr } else { "" }
            Write-Ansi $Sym.Box.V $Palette.Border -NoNewline
            Write-Ansi $T.PadRight($W_Time) $Theme.Reset -NoNewline
            Write-Ansi $Sym.Box.V $Palette.Border -NoNewline
            $Content = $Lines[$i]; $Pad = [math]::Max(0, $W_Events - (Get-DisplayLength $Content))
            Write-Ansi "$Content$(' '*$Pad)" $Theme.Reset -NoNewline
            Write-Ansi $Sym.Box.V $Palette.Border
        }
    }
    Write-Ansi "$($Sym.Box.BL)$([string]::new($Sym.Box.H, $W_Time))$($Sym.Box.B)$([string]::new($Sym.Box.H, $W_Events))$($Sym.Box.BR)" $Palette.Border
}

# -----------------------------------------------------------------------------
# MAIN CONTROLLER
# -----------------------------------------------------------------------------

function Invoke-DisplayResult {
    param ($Result)
    $T = $Result
    switch ($T.Type) {
        "Item"    { Show-Item $T.Data }
        "ARC"     { Show-Bot $T.Data }
        "Project" { Show-Project $T.Data }
        "Skill"   { Show-Skill $T.Data }
        "Quest"   { Show-Quest $T.Data }
        "Hideout" { Show-Hideout $T.Data }
        default {
            Write-Ansi "Unknown result type: $($T.Type)" $Palette.Error
        }
    }
}

function Show-Help {
    param ($Width = 60)
    Write-BoxRow $Sym.Box.TL $Sym.Box.H $Sym.Box.TR $Palette.Border $Width
    Write-ContentRow " ARC RAIDERS CLI " -TextColor "7" -Width $Width -Align Center
    Write-BoxRow $Sym.Box.L $Sym.Box.H $Sym.Box.R $Palette.Border $Width
    $Help = @(
        "Usage: arc <Query> [Index]", "",
        "COMMANDS:",
        "  update       Check and install updates",
        "  events       Check event rotation",
        "  <Query>      Search game data", "",
        "EXAMPLES:",
        "  arc          Display this help text",
        "  arc update   Check and install updates",
        "  arc events   Check event rotation",
        "  arc Cat Bed  Search for 'Cat Bed'",
        "  arc cat 0    View first result for 'cat'", "",
        "TIPS:",
        "  - Use 'arc' from anywhere after install",
        "  - Selection: number keys (0-9) or index arg",
        "  - Multi-word searches don't need quotes"
    )
    foreach ($L in $Help) { Write-ContentRow $L -Width $Width }
    Write-BoxRow $Sym.Box.BL $Sym.Box.H $Sym.Box.BR $Palette.Border $Width
}

if ([string]::IsNullOrWhiteSpace($Query)) {
    Show-Help
} elseif ($Query -eq "update") {
    if ($null -ne $UpdateJob) {
        Remove-Job -Job $UpdateJob -Force
        $UpdateJob = $null
    }
    Update-ArcRaidersCLI
} elseif ($Query -eq "events") {
    Show-Events
} else {
    Initialize-Data -ShowStatus
    $Results = @()

    # Generic Search
    $SearchConfig = @(
        @{ Data = $Global:Data.Items.Values; Type = "Item";    Name = { $args[0].name.en }; Id = "id" }
        @{ Data = $Global:Data.Quests;       Type = "Quest";   Name = { $args[0].name.en } }
        @{ Data = $Global:Data.Hideout;      Type = "Hideout"; Name = { $args[0].name.en } }
        @{ Data = $Global:Data.Bots;         Type = "ARC";     Name = { $args[0].name } }
        @{ Data = $Global:Data.Projects;     Type = "Project"; Name = { $args[0].name.en } }
        @{ Data = $Global:Data.Skills;       Type = "Skill";   Name = { $args[0].name.en } }
    )

    $Results = foreach ($Cfg in $SearchConfig) {
        $GetName = $Cfg.Name
        $HasId = $null -ne $Cfg.Id
        $IdProp = $Cfg.Id
        foreach ($Obj in $Cfg.Data) {
            $Val = & $GetName $Obj
            if ($Val -and ($Val -like "*$Query*" -or ($HasId -and $Obj.$IdProp -eq $Query))) {
                [PSCustomObject]@{ Type = $Cfg.Type; Name = $Val; Data = $Obj }
            }
        }
    }

    # Sort Results Alphabetically
    $Results = @($Results | Sort-Object Name)

    # Result Handling
    if ($Results.Count -eq 0) {
        Write-Ansi "No results found." $Palette.Error
    } elseif ($Results.Count -eq 1) {
        Invoke-DisplayResult $Results[0]
    } else {
        # Check for Auto-Select Argument
        if ($SelectIndex -ge 0 -and $SelectIndex -lt $Results.Count) {
            $Idx = $SelectIndex
        } else {
            $ResLines = for ($i=0; $i -lt $Results.Count; $i++) {
                if ($i -ge 20) { "---"; " ... and more"; break }
                " [$i] $($Results[$i].Name) ($($Results[$i].Type))"
            }
            Show-Card -Title "SEARCH RESULTS" -Content $ResLines -ThemeColor $Palette.Accent
            Write-Ansi "`nSelect (0-$($Results.Count - 1)): " $Palette.Accent -NoNewline
            
            try {
                if ($Results.Count -le 10) {
                    # Fast selection for single-digit results
                    $Host.UI.RawUI.FlushInputBuffer()
                    $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    if ($Key.Character -match "[0-9]") {
                        $Idx = [int][string]$Key.Character
                        Write-Host $Idx # Echo the selection
                    }
                } else {
                    # Multi-digit support for larger result sets
                    $Selection = Read-Host
                    if ($Selection -match '^\d+$') {
                        $Idx = [int]$Selection
                    }
                }
            } catch {
                Write-Ansi "Invalid selection." $Palette.Error
            }
        }

        if ($null -ne $Idx -and $Idx -lt $Results.Count) {
            Invoke-DisplayResult $Results[$Idx]
        }
    }
}

# -----------------------------------------------------------------------------
# POST-SEARCH ACTIONS
# -----------------------------------------------------------------------------

# Check for Updates (Wait for background job)
if ($null -ne $UpdateJob) {
    $WaitStartTime = [DateTime]::Now
    $Notified = $false
    
    while ($UpdateJob.State -eq "Running" -and ([DateTime]::Now - $WaitStartTime).TotalSeconds -lt 2.0) {
        if (-not $Notified) {
            Write-Ansi "Checking for updates..." $Palette.Subtext -NoNewline
            $Notified = $true
        }
        Start-Sleep -Milliseconds 100
    }

    if ($UpdateJob.State -eq "Completed") {
        $UpdateInfo = Receive-Job -Job $UpdateJob
        if ($UpdateInfo) {
            # Re-verify Data version to avoid redundant notices if we just updated during this session (Confirm-Data)
            if ($UpdateInfo.Data) {
                $DataVerFile = Join-Path $DataDir ".version"
                $CurrentDataVer = if (Test-Path $DataVerFile) { (Get-Content $DataVerFile -Raw).Trim() } else { "" }
                if ($CurrentDataVer -eq $UpdateInfo.Data.FullSha) {
                    $UpdateInfo.Data = $null
                }
            }

            if ($UpdateInfo.Script -or $UpdateInfo.Data) {
                if ($Notified) { Write-Host "" }
                Show-UpdateBanner -UpdateInfo $UpdateInfo
            } elseif ($Notified) {
                # Clear the "Checking for updates..." line if no update found
                Write-Host "`r$([char]27)[K" -NoNewline
            }
        } elseif ($Notified) {
            # Clear the "Checking for updates..." line if no update found
            Write-Host "`r$([char]27)[K" -NoNewline
        }
    } else {
        if ($Notified) { Write-Ansi " (timed out)" $Palette.Subtext }
    }
    
    # Cleanup background job
    Remove-Job -Job $UpdateJob -Force
}

# Auto-pause if running in a transient terminal window (e.g. from a launcher)
# This prevents the window from closing immediately before the user can read the results.
try {
    $CurrentProc = Get-Process -Id $PID
    $ParentProc = $CurrentProc.Parent
    
    # If called via arc.bat, the parent is 'cmd', so we check one level higher
    if ($ParentProc.Name -eq "cmd") {
        $ParentProc = $ParentProc.Parent
    }
    
    # Common persistent shell and terminal names
    $ShellNames = "powershell|pwsh|cmd|wt|windowsterminal|bash|zsh|fish"
    
    if ($ParentProc.Name -notmatch $ShellNames) {
        Write-Ansi "`nPress any key to exit..." $Palette.Subtext
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
} catch {
    # Fallback to silent exit if process inspection fails
}
