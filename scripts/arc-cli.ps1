param (
    [string]$SearchTerm
)

$ItemsDir = Join-Path $PSScriptRoot "..\data\items"

if (-not (Test-Path $ItemsDir)) {
    Write-Host "Error: Items directory not found at $ItemsDir" -ForegroundColor Red
    exit 1
}

if ([string]::IsNullOrWhiteSpace($SearchTerm)) {
    Write-Host "Usage: .\arc-cli.ps1 <SearchTerm>"
    exit
}

Write-Host "Searching for '$SearchTerm'..."

$Items = Get-ChildItem -Path $ItemsDir -Filter "*.json"
$FoundItems = @()

foreach ($File in $Items) {
    try {
        $Item = Get-Content -Path $File.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        
        # Search by ID or Name (EN)
        # Using simple substring match, case-insensitive
        if ($Item.id -match "$SearchTerm" -or $Item.name.en -match "$SearchTerm") {
            $FoundItems += $Item
        }
    }
    catch {
        # Ignore read errors
    }
}

if ($FoundItems.Count -eq 0) {
    Write-Host "No items found matching '$SearchTerm'." -ForegroundColor Yellow
}
elseif ($FoundItems.Count -gt 1) {
    Write-Host "Found $($FoundItems.Count) items:" -ForegroundColor Cyan
    foreach ($Match in $FoundItems) {
        Write-Host " - $($Match.name.en) ($($Match.id))"
    }
    Write-Host "`nPlease be more specific."
}
else {
    $Item = $FoundItems[0]
    Write-Host "--------------------------------"
    Write-Host "Name: $($Item.name.en)" -ForegroundColor Green
    Write-Host "ID: $($Item.id)"
    Write-Host "Type: $($Item.type)"
    Write-Host "Rarity: $($Item.rarity)"
    Write-Host "Stack Size: $($Item.stackSize)"
    
    if ($null -ne $Item.stashSavings) {
        $Savings = $Item.stashSavings
        $SavingsText = "{0:N4}" -f $Savings
        $Color = if ($Savings -gt 0) { "Green" } else { "Red" }
        Write-Host "Stash Savings: $SavingsText slots" -ForegroundColor $Color
    } else {
        Write-Host "Stash Savings: N/A" -ForegroundColor Gray
    }
    
    if ($null -ne $Item.recipe) {
        Write-Host "Recipe:"
        $Item.recipe.PSObject.Properties | ForEach-Object {
            Write-Host " - $($_.Name): $($_.Value)"
        }
    }
    
    Write-Host "Description: $($Item.description.en)"
    Write-Host "--------------------------------"
}
