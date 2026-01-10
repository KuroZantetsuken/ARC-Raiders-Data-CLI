# ARC Raiders CLI

A command-line utility for looking up game data from ARC Raiders.

![Demo Video](.assets/demo.webp)

## Features

- **Quick Search**: Look up items, ARCs, quests, hideout upgrades, and skills.
- **Crafting & Stash Analysis**: 
  - Calculates total ingredient costs for recipes.
  - Shows net stash space changes (slots gained/saved) when crafting.
  - Compares item value against recycling or salvaging yields.
- **Trader Data**: View which traders sell an item, including barter requirements and daily limits.
- **Event Schedule**: Displays upcoming map events in your local time, color-coded by map.
- **Smart Selection**: Interactive search results with quick number-key selection or direct index access.
- **Automatic Updates**: Built-in update command to keep the tool up to date.

## Installation

### From Release
1. Download the [latest release](https://github.com/KuroZantetsuken/ARC-Raiders-CLI/releases/latest/download/arc-raiders-cli.zip).
2. Extract the ZIP to a folder.
3. Double-click `install.bat` to run it.
4. Restart your terminal to enable the `arc` command.

### From Source (Git)
1. Clone the repository with submodules:
   ```powershell
   git clone --recursive https://github.com/KuroZantetsuken/ARC-Raiders-CLI.git
   cd ARC-Raiders-CLI
   ```
2. Run `.\Setup.ps1` to configure the environment.

## Usage

Run `arc` followed by your search query.

```powershell
arc heavy        # List items/data matching "Heavy"
arc "to earth"   # Search for exact phrases
arc events       # View the map event schedule
arc update       # Check for and install software updates
```

- **Selection**: If multiple results are found, press `0`-`9` to select one.
- **Direct Access**: Skip selection by adding the index: `arc shield 0`.

## Updating Data

If you installed from source using Git, you can update the game data separately:
```powershell
git submodule update --remote
```
For release builds, use `arc update` to update the entire tool including data.

## Uninstallation

To remove the tool from your system PATH and delete the command alias, run `uninstall.bat`.

## Credits
This tool uses game data provided by the [RaidTheory/arcraiders-data](https://github.com/RaidTheory/arcraiders-data) project.
Special thanks to the team at [arctracker.io](https://arctracker.io) for their work in compiling and maintaining this resource.