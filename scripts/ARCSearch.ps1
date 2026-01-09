param (
    [string]$Query
)

# --- Configuration ---
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$DataItemsDir = Join-Path $RepoRoot "data\items"
$DataQuestsDir = Join-Path $RepoRoot "arcraiders-data\quests"
$DataHideoutDir = Join-Path $RepoRoot "arcraiders-data\hideout"
$DataEventsFile = Join-Path $RepoRoot "arcraiders-data\map-events\map-events.json"

# --- Styling Engine ---

$Colors = @{
    # Rarity
    "Common"    = "108;108;108"
    "Uncommon"  = "38;191;87"
    "Rare"      = "0;168;242"
    "Epic"      = "204;48;153"
    "Legendary" = "255;198;0"
    
    # UI Theme
    "White"     = "220;220;220"
    "Gray"      = "130;130;140"
    "DarkGray"  = "60;65;70"
    "Border"    = "80;85;90"
    "Red"       = "210;90;90"
    "Green"     = "100;190;120"
    "Yellow"    = "220;200;100"
    "Cyan"      = "90;190;210"
    "Blue"      = "90;140;210"
}

$Sym = @{
    Curr    = "⦶"
    Weight  = "⚖️"
    Stack   = "📦"
    Craft   = "🛠️"
    Recycle = "♻️"
    Salvage = "🗑️"
    Time    = "🕒"
    Warn    = "⚠️"
}

function Get-Rgb {
    param ($Name)
    if ($Colors.ContainsKey($Name)) { return $Colors[$Name] }
    return $Colors["White"]
}

function Write-Rgb {
    param ($Text, $Rgb="White", [switch]$NoNewline)
    $Esc = [char]27
    if ($Colors.ContainsKey($Rgb)) { $Rgb = $Colors[$Rgb] }
    
    $Out = "$Esc[38;2;${Rgb}m$Text$Esc[0m"
    if ($NoNewline) { Write-Host $Out -NoNewline } else { Write-Host $Out }
}

function Get-Line { param($L, $C="-") return [string]::new($C, $L) }

# Box Drawing
$Box = @{
    H   = "─"; V   = "│"
    TL  = "┌"; TR  = "┐"
    BL  = "└"; BR  = "┘"
    L   = "├"; R   = "┤"
    C   = "┼"; T   = "┬"; B   = "┴"
}

function Write-Card {
    param (
        [string]$Title,
        [string]$SubtitleHighlight,
        [string]$SubtitleRest,
        [string[]]$Lines,
        [string]$Color = "White",
        [int]$Width = 60
    )
    
    $BorderColor = $Color
    $AnsiRegex = [regex]"\x1B\[[0-9;]*[a-zA-Z]"
    
    # Top
    Write-Rgb "$($Box.TL)$(Get-Line ($Width - 2) $Box.H)$($Box.TR)" $BorderColor
    
    # Title
    $TitleSpace = $Width - 4
    $T = if ($Title.Length -gt $TitleSpace) { $Title.Substring(0, $TitleSpace) } else { $Title }
    Write-Rgb "$($Box.V) " $BorderColor -NoNewline
    Write-Rgb $T.PadRight($TitleSpace).ToUpper() $Color -NoNewline
    Write-Rgb " $($Box.V)" $BorderColor
    
    # Subtitle
    if ($SubtitleHighlight -or $SubtitleRest) {
        Write-Rgb "$($Box.V) " $BorderColor -NoNewline
        $Used = 0
        if ($SubtitleHighlight) {
            Write-Rgb "$SubtitleHighlight" $Color -NoNewline
            $Used += $SubtitleHighlight.Length
        }
        if ($SubtitleRest) {
            if ($Used -gt 0) { Write-Rgb " " -NoNewline; $Used++ }
            Write-Rgb "$SubtitleRest" "Gray" -NoNewline
            $Used += $SubtitleRest.Length
        }
        $Pad = $TitleSpace - $Used
        if ($Pad -gt 0) { Write-Rgb (" " * $Pad) -NoNewline }
        Write-Rgb " $($Box.V)" $BorderColor
    }
    
    # Content
    foreach ($Line in $Lines) {
        if ($Line -eq "---") {
             Write-Rgb "$($Box.L)$(Get-Line ($Width - 2) $Box.H)$($Box.R)" $BorderColor
             continue
        }
        
        $CleanLine = $AnsiRegex.Replace($Line, "")
        
        if ($CleanLine.Length -gt $TitleSpace) {
             $CleanLine = $CleanLine.Substring(0, $TitleSpace-3) + "..."
        }
        
        Write-Rgb "$($Box.V) " $BorderColor -NoNewline
        Write-Rgb $Line -NoNewline
        
        $Pad = $TitleSpace - $CleanLine.Length
        if ($Pad -gt 0) { Write-Rgb (" " * $Pad) -NoNewline }
        
        Write-Rgb " $($Box.V)" $BorderColor
    }
    
    # Bottom
    Write-Rgb "$($Box.BL)$(Get-Line ($Width - 2) $Box.H)$($Box.BR)" $BorderColor
}

# --- Helper Functions ---

function Get-JsonContent {
    param ($Path)
    try {
        Get-Content -Path $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        return $null
    }
}

$ItemDB = @{}

function Initialize-ItemDatabase {
    $Files = Get-ChildItem $DataItemsDir -Filter "*.json"
    foreach ($File in $Files) {
        try {
            $Json = Get-JsonContent $File.FullName
            if ($Json) { $ItemDB[$Json.id] = $Json }
        } catch {}
    }
}

function Get-ItemName {
    param ($Id)
    if ($ItemDB.ContainsKey($Id)) { return $ItemDB[$Id].name.en }
    return $Id
}

function Get-ItemValue {
    param ($Id)
    if ($ItemDB.ContainsKey($Id)) { if ($ItemDB[$Id].value) { return $ItemDB[$Id].value } }
    return 0
}

# --- Display Handlers ---

function Show-Item {
    param ($Item)
    $Color = if ($Item.rarity) { $Item.rarity } else { "Common" }
    
    $Content = @()
    
    # Stats Row
    $Stats = @()
    if ($Item.weightKg) { $Stats += "$($Sym.Weight) $($Item.weightKg)kg" }
    if ($Item.stackSize) { $Stats += "$($Sym.Stack) $($Item.stackSize)" }
    $SellValue = if ($Item.value) { $Item.value } else { 0 }
    $Stats += "$($Sym.Curr) $SellValue"
    
    $Content += ($Stats -join "   ")
    $Content += "---"
    
    # Craft Cost
    if ($Item.recipe) {
        $CraftCost = 0
        $Item.recipe.PSObject.Properties | ForEach-Object {
            $Qty = $_.Value; $IngId = $_.Name
            $CraftCost += ($Qty * (Get-ItemValue $IngId))
        }
        $Profit = $SellValue - $CraftCost
        $ProfitStr = if ($Profit -ge 0) { "+$Profit" } else { "$Profit" }
        
        $Content += "$($Sym.Craft) Craft Cost: $($Sym.Curr) $CraftCost ($ProfitStr)"
    }
    
    # Recycle (Hideout)
    if ($Item.recyclesInto) {
        $RecycleVal = 0
        $Item.recyclesInto.PSObject.Properties | ForEach-Object {
            $Qty = $_.Value; $ResId = $_.Name
            $RecycleVal += ($Qty * (Get-ItemValue $ResId))
        }
        $Diff = $RecycleVal - $SellValue
        $Content += "$($Sym.Recycle) Recycle Value: $($Sym.Curr) $RecycleVal ($Diff)"
    }
    
    # Salvage (Raid)
    if ($Item.salvagesInto) {
        $SalvageVal = 0
        $Item.salvagesInto.PSObject.Properties | ForEach-Object {
            $Qty = $_.Value; $ResId = $_.Name
            $SalvageVal += ($Qty * (Get-ItemValue $ResId))
        }
        $Diff = $SalvageVal - $SellValue
        $Content += "$($Sym.Salvage) Salvage Value: $($Sym.Curr) $SalvageVal ($Diff)"
    }
    
    if ($null -ne $Item.stashSavings) {
        $Val = "{0:N4}" -f $Item.stashSavings
        $Sign = if ($Item.stashSavings -gt 0) { "+" } else { "" }
        $Content += "Stash Savings: $Sign$Val slots"
    }
    
    # Lists
    if ($Item.recipe) {
        $Content += "---"
        $Content += "$($Sym.Craft) RECIPE:"
        $Item.recipe.PSObject.Properties | ForEach-Object {
            $Content += " - $($_.Value)x $(Get-ItemName $_.Name)"
        }
    }
    
    if ($Item.recyclesInto) {
        $Content += "---"
        $Content += "$($Sym.Recycle) RECYCLES INTO:"
        $Item.recyclesInto.PSObject.Properties | ForEach-Object {
            $Content += " - $($_.Value)x $(Get-ItemName $_.Name)"
        }
    }
    
    if ($Item.salvagesInto) {
        $Content += "---"
        $Content += "$($Sym.Salvage) SALVAGES INTO:"
        $Item.salvagesInto.PSObject.Properties | ForEach-Object {
            $Content += " - $($_.Value)x $(Get-ItemName $_.Name)"
        }
    }
    
    if ($Item.description.en) {
        $Content += "---"
        $Desc = $Item.description.en
        # Wrap logic inside loop
        $MaxLen = 56
        $Offset = 0
        while ($Offset -lt $Desc.Length) {
            $Len = [math]::Min($MaxLen, $Desc.Length - $Offset)
            $Content += $Desc.Substring($Offset, $Len)
            $Offset += $Len
        }
    }
    
    Write-Card -Title $Item.name.en -SubtitleHighlight $Item.rarity -SubtitleRest $Item.type -Lines $Content -Color $Color
}

function Show-Quest {
    param ($Quest)
    $Content = @()
    $Content += "TRADER: $($Quest.trader)"
    $Content += "---"
    
    if ($Quest.objectives) {
        $Content += "OBJECTIVES:"
        foreach ($Obj in $Quest.objectives) {
            if ($Obj.en) { $Content += " [ ] $($Obj.en)" }
        }
        $Content += "---"
    }
    
    if ($Quest.rewardItemIds) {
        $Content += "REWARDS:"
        foreach ($R in $Quest.rewardItemIds) {
             $Content += " - $($R.quantity)x $(Get-ItemName $R.itemId)"
        }
    }
    
    Write-Card -Title $Quest.name.en -SubtitleHighlight "Quest" -Lines $Content -Color "Cyan"
}

function Show-Hideout {
    param ($Hideout)
    $Content = @()
    
    if ($Hideout.levels) {
        $Content += "UPGRADES:"
        foreach ($Lvl in $Hideout.levels) {
            if ($Lvl.requirementItemIds.Count -gt 0) {
                $Content += " Level $($Lvl.level):"
                foreach ($Req in $Lvl.requirementItemIds) {
                    $Content += "   - $($Req.quantity)x $(Get-ItemName $Req.itemId)"
                }
            } else {
                $Content += " Level $($Lvl.level): Free"
            }
            if ($Lvl.level -lt $Hideout.maxLevel) { $Content += "" }
        }
    }
    
    Write-Card -Title $Hideout.name.en -SubtitleHighlight "Hideout" -SubtitleRest "(Max Lvl $($Hideout.maxLevel))" -Lines $Content -Color "Yellow"
}

function Show-Events {
    if (-not (Test-Path $DataEventsFile)) {
        Write-Rgb "Event data not found." "Red"
        return
    }
    
    $EventsData = Get-JsonContent $DataEventsFile
    $Schedule = $EventsData.schedule
    $EventTypes = $EventsData.eventTypes
    $Maps = $EventsData.maps
    
    $UtcNow = [DateTime]::UtcNow
    $LocalNow = [DateTime]::Now
    $CurrentUtcHour = $UtcNow.Hour
    
    # 60 chars wide table (inner)
    $W = 60
    
    # Header
    Write-Rgb "$($Box.TL)$([string]$Box.H * $W)$($Box.TR)" "Cyan"
    $T = "EVENT SCHEDULE"
    $Pad = ($W - $T.Length) / 2
    Write-Rgb "$($Box.V)$(' '*[math]::Floor($Pad))$T$(' '*[math]::Ceiling($Pad))$($Box.V)" "Cyan"
    Write-Rgb "$($Box.L)$([string]$Box.H * $W)$($Box.R)" "Cyan"
    
    # Active
    $ActTxt = " ACTIVE NOW ($($LocalNow.ToString('HH:mm')))"
    $PadAct = $W - $ActTxt.Length
    if ($PadAct -lt 0) { $PadAct = 0 }
    Write-Rgb "$($Box.V)$ActTxt$(' '*$PadAct)$($Box.V)" "Green"
    Write-Rgb "$($Box.L)$([string]$Box.H * $W)$($Box.R)" "DarkGray"
    
    foreach ($MapKey in $Schedule.PSObject.Properties.Name) {
        $MapName = if ($Maps.$MapKey.displayName) { $Maps.$MapKey.displayName } else { $MapKey }
        $MapSchedule = $Schedule.$MapKey
        
        $ActiveMajor = if ($MapSchedule.major."$CurrentUtcHour") { $EventTypes.($MapSchedule.major."$CurrentUtcHour").displayName } else { $null }
        $ActiveMinor = if ($MapSchedule.minor."$CurrentUtcHour") { $EventTypes.($MapSchedule.minor."$CurrentUtcHour").displayName } else { $null }
        
        if ($ActiveMajor -or $ActiveMinor) {
             # Map Name Line
             $MapLine = " $MapName"
             $PadMap = $W - $MapLine.Length
             Write-Rgb "$($Box.V)$MapLine$(' '*$PadMap)$($Box.V)" "White"
             
             if ($ActiveMajor) { 
                 $L = "   Major: $ActiveMajor"
                 $PadL = $W - $L.Length
                 Write-Rgb "$($Box.V)$L$(' '*$PadL)$($Box.V)" "Cyan" 
             }
             if ($ActiveMinor) { 
                 $L = "   Minor: $ActiveMinor"
                 $PadL = $W - $L.Length
                 Write-Rgb "$($Box.V)$L$(' '*$PadL)$($Box.V)" "Yellow" 
             }
             Write-Rgb "$($Box.L)$([string]$Box.H * $W)$($Box.R)" "DarkGray"
        }
    }
    
    # Upcoming
    $UpTxt = " UPCOMING SCHEDULE"
    $PadUp = $W - $UpTxt.Length
    Write-Rgb "$($Box.V)$UpTxt$(' '*$PadUp)$($Box.V)" "Yellow"
    
    # Table Header
    # 7 | 30 | 21
    # 7 + 1 + 30 + 1 + 21 = 60
    
    $SepLine = "$($Box.L)$([string]$Box.H * 7)$($Box.C)$([string]$Box.H * 30)$($Box.C)$([string]$Box.H * 21)$($Box.R)"
    Write-Rgb $SepLine "DarkGray"
    
    $UpcomingEvents = @()
    foreach ($EventKey in $EventTypes.PSObject.Properties.Name) {
        if ($EventKey -eq "none" -or $EventTypes.$EventKey.disabled) { continue }
        $EventInfo = $EventTypes.$EventKey
        
        $BestH = 999; $NextOcc = $null
        foreach ($MapKey in $Schedule.PSObject.Properties.Name) {
            foreach ($Cat in @("major", "minor")) {
                $Sched = $Schedule.$MapKey.$Cat
                if (-not $Sched) { continue }
                for ($h = 0; $h -lt 24; $h++) {
                    if ($Sched."$(($CurrentUtcHour + $h) % 24)" -eq $EventKey) {
                        if ($h -lt $BestH) {
                            $BestH = $h
                            $FutureUtc = $UtcNow.AddHours($h)
                            $ExactTimeUtc = Get-Date -Date $FutureUtc -Minute 0 -Second 0
                            $NextOcc = @{
                                Name = $EventInfo.displayName
                                Map = if ($Maps.$MapKey.displayName) { $Maps.$MapKey.displayName } else { $MapKey }
                                Time = $ExactTimeUtc.ToLocalTime()
                                Category = $EventInfo.category
                                HoursAway = $h
                            }
                        }
                    }
                }
            }
        }
        if ($NextOcc) { $UpcomingEvents += [PSCustomObject]$NextOcc }
    }
    
    $UpcomingEvents = $UpcomingEvents | Sort-Object Time
    
    for ($i = 0; $i -lt $UpcomingEvents.Count; $i++) {
        $Ev = $UpcomingEvents[$i]
        $TimeStr = $Ev.Time.ToString("HH:mm")
        if ($Ev.HoursAway -eq 0) { $TimeStr = " NOW " }
        
        $Color = if ($Ev.Category -eq "major") { "Cyan" } else { "White" }
        
        Write-Rgb "$($Box.V)" "DarkGray" -NoNewline
        Write-Rgb "$($TimeStr.PadRight(7))" "Yellow" -NoNewline
        
        Write-Rgb "$($Box.V)" "DarkGray" -NoNewline
        # Truncate Name to 30
        $N = $Ev.Name; if ($N.Length -gt 30) { $N = $N.Substring(0, 27) + "..." }
        Write-Rgb "$($N.PadRight(30))" $Color -NoNewline
        
        Write-Rgb "$($Box.V)" "DarkGray" -NoNewline
        # Truncate Map to 21
        $M = $Ev.Map; if ($M.Length -gt 21) { $M = $M.Substring(0, 18) + "..." }
        Write-Rgb "$($M.PadRight(21))" "Gray" -NoNewline
        
        Write-Rgb "$($Box.V)" "DarkGray"
        
        if ($i -lt $UpcomingEvents.Count - 1) {
            Write-Rgb $SepLine "DarkGray"
        }
    }
    
    # Bottom
    Write-Rgb "$($Box.BL)$([string]$Box.H * 7)$($Box.B)$([string]$Box.H * 30)$($Box.B)$([string]$Box.H * 21)$($Box.BR)" "DarkGray"
}

# --- Main Search ---

if ([string]::IsNullOrWhiteSpace($Query)) {
    Write-Rgb " Usage: ARCSearch <Query>" "Red"
    exit
}

# Load DB logic needed for everything now
# Write-Rgb " Loading..." "DarkGray" # Quiet loading
Initialize-ItemDatabase

if ($Query -eq "events") {
    Show-Events
    exit
}

Write-Rgb " Searching for '$Query'..." "DarkGray"

$Results = @()

# 1. Search Items
# Filter ItemDB (faster than file IO if already loaded?)
# ItemDB is loaded. Iterate values.
foreach ($Item in $ItemDB.Values) {
    if ($Item.id -like "*$Query*" -or $Item.name.en -like "*$Query*") {
        $Results += [PSCustomObject]@{
            Type = "Item"
            Name = $Item.name.en
            ID = $Item.id
            Data = $Item
        }
    }
}

# 2. Search Quests
if (Test-Path $DataQuestsDir) {
    $QuestFiles = Get-ChildItem $DataQuestsDir -Filter "*.json"
    foreach ($File in $QuestFiles) {
        try {
            $Json = Get-JsonContent $File.FullName
            if ($null -eq $Json) { continue }
            
            if ($Json.name.en -like "*$Query*") {
                $Results += [PSCustomObject]@{
                    Type = "Quest"
                    Name = $Json.name.en
                    ID = $Json.id
                    Data = $Json
                }
            }
        } catch {}
    }
}

# 3. Search Hideouts
if (Test-Path $DataHideoutDir) {
    $HideoutFiles = Get-ChildItem $DataHideoutDir -Filter "*.json"
    foreach ($File in $HideoutFiles) {
        try {
            $Json = Get-JsonContent $File.FullName
            if ($null -eq $Json) { continue }
            
            if ($Json.name.en -like "*$Query*" -or $Json.id -like "*$Query*") {
                $Results += [PSCustomObject]@{
                    Type = "Hideout"
                    Name = $Json.name.en
                    ID = $Json.id
                    Data = $Json
                }
            }
        } catch {}
    }
}

# --- Selection Logic ---

if ($Results.Count -eq 0) {
    Write-Rgb " No results found." "Red"
} elseif ($Results.Count -eq 1) {
    $Target = $Results[0]
    if ($Target.Type -eq "Item") { Show-Item $Target.Data }
    elseif ($Target.Type -eq "Quest") { Show-Quest $Target.Data }
    elseif ($Target.Type -eq "Hideout") { Show-Hideout $Target.Data }
} else {
    Write-Rgb " SEARCH RESULTS" "Cyan"
    $Index = 0
    foreach ($Res in $Results) {
        if ($Index -gt 9) { break }
        Write-Rgb " [$Index] " "Yellow" -NoNewline
        Write-Rgb "$($Res.Name)" "White" -NoNewline
        Write-Rgb " ($($Res.Type))" "Gray"
        $Index++
    }
    
    if ($Results.Count -gt 10) {
        Write-Rgb " ... and more." "DarkGray"
    }
    
    Write-Rgb ""
    Write-Rgb " Select (0-$($Index-1)): " "Yellow" -NoNewline
    
    try {
        $Host.UI.RawUI.FlushInputBuffer()
        $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        $Char = [string]$Key.Character
        if ($Char -match "[0-9]") {
            $Selection = [int]$Char
            Write-Host $Selection
            
            if ($Selection -lt $Index) {
                $Target = $Results[$Selection]
                if ($Target.Type -eq "Item") { Show-Item $Target.Data }
                elseif ($Target.Type -eq "Quest") { Show-Quest $Target.Data }
                elseif ($Target.Type -eq "Hideout") { Show-Hideout $Target.Data }
            } else {
                Write-Rgb " Invalid selection." "Red"
            }
        } else {
            Write-Rgb " Cancelled." "Red"
        }
    } catch {
        Write-Host "`nInteractive mode not supported."
    }
}
