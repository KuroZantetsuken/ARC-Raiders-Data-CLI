param (
    [string]$Query
)

# --- Configuration ---
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$DataItemsDir = Join-Path $RepoRoot "data\items"
$DataQuestsDir = Join-Path $RepoRoot "arcraiders-data\quests"
$DataHideoutDir = Join-Path $RepoRoot "arcraiders-data\hideout"
$DataEventsFile = Join-Path $RepoRoot "arcraiders-data\map-events\map-events.json"

# --- Helper Functions ---

function Get-JsonContent {
    param ($Path)
    try {
        Get-Content -Path $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Write-Color {
    param ($Text, $Color="White", [switch]$NoNewline)
    if ($NoNewline) {
        Write-Host $Text -ForegroundColor $Color -NoNewline
    } else {
        Write-Host $Text -ForegroundColor $Color
    }
}

# --- Event Logic ---

function Show-Events {
    if (-not (Test-Path $DataEventsFile)) {
        Write-Color "Event data not found at $DataEventsFile" "Red"
        return
    }
    
    $EventsData = Get-JsonContent $DataEventsFile
    $Schedule = $EventsData.schedule
    $EventTypes = $EventsData.eventTypes
    $Maps = $EventsData.maps
    
    $UtcNow = [DateTime]::UtcNow
    $LocalNow = [DateTime]::Now
    $CurrentUtcHour = $UtcNow.Hour
    
    Write-Color "`n=== ARC Raiders Event Schedule ===" "Cyan"
    Write-Color "Current Time: $($LocalNow.ToString('g'))" "Gray"
    
    # 1. Active Events Summary
    Write-Color "`n[Active Now]" "Yellow"
    $AnyActive = $false
    
    foreach ($MapKey in $Schedule.PSObject.Properties.Name) {
        $MapName = if ($Maps.$MapKey.displayName) { $Maps.$MapKey.displayName } else { $MapKey }
        $MapSchedule = $Schedule.$MapKey
        
        $ActiveMajor = $null
        $ActiveMinor = $null
        
        if ($MapSchedule.major."$CurrentUtcHour") {
            $Id = $MapSchedule.major."$CurrentUtcHour"
            $ActiveMajor = $EventTypes.$Id.displayName
        }
        
        if ($MapSchedule.minor."$CurrentUtcHour") {
            $Id = $MapSchedule.minor."$CurrentUtcHour"
            $ActiveMinor = $EventTypes.$Id.displayName
        }
        
        if ($ActiveMajor -or $ActiveMinor) {
            $AnyActive = $true
            $MajorStr = if ($ActiveMajor) { $ActiveMajor } else { "-" }
            $MinorStr = if ($ActiveMinor) { $ActiveMinor } else { "-" }
            
            # Align output
            # Map Name : Major, Minor
            $MapStr = "$MapName".PadRight(20)
            Write-Color "  $MapStr : $MajorStr (Major), $MinorStr (Minor)" "Green"
        }
    }
    
    if (-not $AnyActive) {
        Write-Color "  No major/minor events currently active." "DarkGray"
    }

    # 2. Upcoming Schedule (Global per Event Type)
    $UpcomingEvents = @()
    
    foreach ($EventKey in $EventTypes.PSObject.Properties.Name) {
        if ($EventKey -eq "none") { continue }
        $EventInfo = $EventTypes.$EventKey
        if ($EventInfo.disabled) { continue }
        
        # Find next occurrence across all maps
        $BestTimeSpan = [TimeSpan]::MaxValue
        $NextOccurrence = $null
        
        foreach ($MapKey in $Schedule.PSObject.Properties.Name) {
            $MapSchedule = $Schedule.$MapKey
            # Check major and minor
            foreach ($Cat in @("major", "minor")) {
                if (-not $MapSchedule.$Cat) { continue }
                $Sched = $MapSchedule.$Cat
                
                # Iterate 0..23 to find match
                # 0 means starts NOW (Current hour). 
                # Use 1..24 to find NEXT if current is ignored? 
                # User said "even if an event is long into the future... next possible instance".
                # If active now, showing "Active Now" in upcoming list is redundant?
                # But user wants "next occurrence". If active, next is usually "Now".
                # I'll include Now.
                
                for ($h = 0; $h -lt 24; $h++) {
                    $CheckHour = ($CurrentUtcHour + $h) % 24
                    if ($Sched."$CheckHour" -eq $EventKey) {
                        # Found one
                        if ($h -lt $BestTimeSpan.TotalHours) {
                            $BestTimeSpan = [TimeSpan]::FromHours($h)
                            
                            # Exact time
                            $FutureUtc = $UtcNow.AddHours($h)
                            $ExactTimeUtc = Get-Date -Date $FutureUtc -Minute 0 -Second 0
                            
                            $NextOccurrence = @{
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
        
        if ($NextOccurrence) {
            $UpcomingEvents += [PSCustomObject]$NextOccurrence
        }
    }
    
    # Sort and Display
    $UpcomingEvents = $UpcomingEvents | Sort-Object Time
    
    foreach ($Cat in @("major", "minor")) {
        $Title = ($Cat.Substring(0,1).ToUpper() + $Cat.Substring(1))
        Write-Color "`n[Upcoming $Title Events]" "Yellow"
        
        $List = $UpcomingEvents | Where-Object { $_.Category -eq $Cat }
        if ($List) {
            foreach ($Ev in $List) {
                if ($Ev.HoursAway -eq 0) {
                    # It's active now. Show as "Active Now"?
                    # Or just show time?
                    # Since we have "Active Now" section above, listing it here again confirms it's the "next" occurrence.
                    # But user said "next upcoming one...". "Upcoming" usually excludes "Active".
                    # However, if I exclude Active, and the next one is in 12 hours, I should show that?
                    # "Launch Tower Loot" -> Active Now. Next one is tomorrow.
                    # Showing "Active Now" is safer so user knows it's available.
                    
                    Write-Color "  ACTIVE NOW   - $($Ev.Name) ($($Ev.Map))" "Green"
                } else {
                    $TimeStr = $Ev.Time.ToString("HH:mm")
                    $DayStr = if ($Ev.Time.Date -ne $LocalNow.Date) { " (Tomorrow)" } else { "" }
                    
                    Write-Color "  $($TimeStr)$($DayStr) - $($Ev.Name) ($($Ev.Map))" "White"
                }
            }
        } else {
            Write-Color "  None found in schedule." "DarkGray"
        }
    }
}

# --- Display Handlers ---

function Show-Item {
    param ($Item)
    Write-Color "`n=== Item: $($Item.name.en) ===" "Cyan"
    Write-Color "Type: $($Item.type)" "Gray"
    if ($Item.rarity) { Write-Color "Rarity: $($Item.rarity)" "White" }
    
    if ($null -ne $Item.stashSavings) {
        $Savings = $Item.stashSavings
        $Color = if ($Savings -gt 0) { "Green" } else { "Red" }
        Write-Color "Stash Savings: $( "{0:N4}" -f $Savings ) slots" $Color
    }
    
    if ($Item.recipe) {
        Write-Color "Recipe:" "Yellow"
        $Item.recipe.PSObject.Properties | ForEach-Object {
            Write-Color "  - $($_.Name): $($_.Value)" "White"
        }
    }
    
    if ($Item.description.en) {
        Write-Color "`n$($Item.description.en)" "Gray"
    }
}

function Show-Quest {
    param ($Quest)
    Write-Color "`n=== Quest: $($Quest.name.en) ===" "Cyan"
    Write-Color "Trader: $($Quest.trader)" "Yellow"
    
    if ($Quest.description.en) {
        Write-Color "`n$($Quest.description.en)" "Gray"
    }
    
    if ($Quest.objectives) {
        Write-Color "`nObjectives:" "White"
        foreach ($Obj in $Quest.objectives) {
            if ($Obj.en) {
                Write-Color "  [ ] $($Obj.en)" "White"
            }
        }
    }
    
    if ($Quest.rewardItemIds) {
        Write-Color "`nRewards:" "Green"
        foreach ($Reward in $Quest.rewardItemIds) {
            Write-Color "  - $($Reward.quantity)x $($Reward.itemId)" "Green"
        }
    }
}

function Show-Hideout {
    param ($Hideout)
    Write-Color "`n=== Hideout: $($Hideout.name.en) ===" "Cyan"
    Write-Color "Max Level: $($Hideout.maxLevel)" "Gray"
    
    if ($Hideout.levels) {
        Write-Color "`nUpgrades:" "White"
        foreach ($Lvl in $Hideout.levels) {
            if ($Lvl.requirementItemIds.Count -gt 0) {
                Write-Color "  Level $($Lvl.level):" "Yellow"
                foreach ($Req in $Lvl.requirementItemIds) {
                    Write-Color "    - $($Req.quantity)x $($Req.itemId)" "White"
                }
            } else {
                Write-Color "  Level $($Lvl.level): Free / Base" "DarkGray"
            }
        }
    }
}

# --- Main Search ---

if ([string]::IsNullOrWhiteSpace($Query)) {
    Write-Color "Usage: ARCSearch <Query>" "Red"
    Write-Color "Examples:" "Gray"
    Write-Color "  ARCSearch herbal" "Gray"
    Write-Color "  ARCSearch events" "Gray"
    exit
}

if ($Query -eq "events") {
    Show-Events
    exit
}

Write-Color "Searching for '$Query'..." "DarkGray"

$Results = @()

# 1. Search Items
$ItemFiles = Get-ChildItem $DataItemsDir -Filter "*.json"
foreach ($File in $ItemFiles) {
    try {
        $Json = Get-JsonContent $File.FullName
        if ($null -eq $Json) { continue }
        
        if ($Json.id -like "*$Query*" -or $Json.name.en -like "*$Query*") {
            $Results += [PSCustomObject]@{
                Type = "Item"
                Name = $Json.name.en
                ID = $Json.id
                Data = $Json
            }
        }
    } catch {}
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
    Write-Color "No results found." "Red"
} elseif ($Results.Count -eq 1) {
    $Target = $Results[0]
    if ($Target.Type -eq "Item") { Show-Item $Target.Data }
    elseif ($Target.Type -eq "Quest") { Show-Quest $Target.Data }
    elseif ($Target.Type -eq "Hideout") { Show-Hideout $Target.Data }
} else {
    # Multiple results
    Write-Color "Multiple results found:" "Cyan"
    $Index = 0
    foreach ($Res in $Results) {
        if ($Index -gt 9) { break }
        Write-Color "[$Index] $($Res.Name) ($($Res.Type))" "White"
        $Index++
    }
    
    if ($Results.Count -gt 10) {
        Write-Color "... and more." "DarkGray"
    }
    
    Write-Color "`nSelect (0-$($Index-1)): " "Yellow" -NoNewline
    
    # Interactive Key Press
    try {
        $Host.UI.RawUI.FlushInputBuffer()
        $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        $Char = [string]$Key.Character
        if ($Char -match "[0-9]") {
            $Selection = [int]$Char
            Write-Host $Selection # Echo the number
            
            if ($Selection -lt $Index) {
                $Target = $Results[$Selection]
                if ($Target.Type -eq "Item") { Show-Item $Target.Data }
                elseif ($Target.Type -eq "Quest") { Show-Quest $Target.Data }
                elseif ($Target.Type -eq "Hideout") { Show-Hideout $Target.Data }
            } else {
                Write-Color "`nInvalid selection." "Red"
            }
        } else {
            Write-Color "`nCancelled." "Red"
        }
    } catch {
        Write-Host "`nInteractive mode not supported or error reading key."
    }
}
