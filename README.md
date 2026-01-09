# ARC Raiders Data CLI & Stash Optimizer

A powerful, fast, and easy-to-use CLI tool for **ARC Raiders** players. Instantly look up items, crafting recipes, quest objectives, and check the live map event schedule directly from your terminal.

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Platform](https://img.shields.io/badge/platform-Windows-blue)

## Features

*   **Instant Search**: Zero-latency lookup for Items, Bots, Projects, Skills, and Quests.
*   **Stash Optimizer**: Automatically calculates "Stash Savings" to tell you if crafting an item saves or costs space.
*   **Event Schedule**: Live schedule of Map Events (Major & Minor) converted to your local time.
*   **Trade Profit**: Shows if a trade is profitable based on market values.
*   **Rich UI**: Beautiful terminal output with colors, badges, and card-based layouts.

## Quick Start (Windows)

1.  **Clone the Repo**:
    ```powershell
    git clone https://github.com/KuroZantetsuken/ARC-Raiders-Data-CLI.git
    cd ARC-Raiders-Data-CLI
    ```

2.  **Run Setup**:
    ```powershell
    .\Setup.ps1
    ```
    *   Downloads the game data automatically.
    *   Adds the tool to your system `PATH`.
    *   Creates the `arc` shortcut command.

3.  **Restart Terminal**: Close and reopen your terminal (or VS Code).

4.  **You're Ready!**:
    ```powershell
    arc herbal     # Search for "Herbal Bandage"
    arc events     # See the map schedule
    ```

## Usage Guide

### 1. Searching
Type `arc` followed by any keyword.
```powershell
arc heavy        # Lists results matching "Heavy"
arc scrapper     # Shows bot stats for "Scrapper"
arc "to earth"   # Finds quest "Down To Earth"
```
*   **Selection**: If multiple results are found, simply press `0`-`9` to view one instantly.
*   **Direct Access**: You can also specify the index directly in the command.
    ```powershell
    arc shield 0     # Immediately opens the first result for "shield"
    ```

### 2. Event Schedule
View the upcoming rotation for all maps.
```powershell
arc events
```
*   Shows the **Next Occurrence** of every event type.
*   Times are in **Your Local Time**.
*   **Yellow/Blue** highlights for different maps.

### 3. Understanding Item Cards
When you view an item, you'll see advanced stats:
*   **Cost**: Total cost of ingredients vs. Item Value.
*   **Space**: `(Green)` means crafting this saves stash slots. `(Red)` means it takes up more space.
*   **Sold By**: Shows which traders sell it and if it's a good deal.

### 4. Integration (PowerToys Run)
Since `Setup.ps1` adds the folder to your PATH, you can use **PowerToys Run** (Alt+Space):
1.  Type `> arc events`
2.  Hit Enter to see the schedule immediately.

## Updates
Game data changes often. To update to the latest values:
```powershell
cd ARC-Raiders-Data-CLI
git submodule update --remote
```

## Uninstalling
To cleanly remove the tool and all system changes:
```powershell
.\Setup.ps1 -Uninstall
```
*   Removes the folder from your `PATH`.
*   Deletes the `arc` alias.
*   You can then safely delete the project folder.

## Project Structure
*   `ARCSearch.ps1`: The core PowerShell engine.
*   `arc.bat`: Wrapper for easy invocation.
*   `arcraiders-data/`: Linked submodule containing raw JSON data.
