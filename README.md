# ARC Raiders CLI

A command-line utility for looking up game data from ARC Raiders.

![Demo Video](.assets/demo.webp)

## What it does

I hate having to keep a browser open while playing just to look up trivial information about the game, so I made a CLI utility to do it through a terminal.

This tool searches the database maintained by [RaidTheory/arcraiders-data](https://github.com/RaidTheory/arcraiders-data) (the same data used by [arctracker.io](https://arctracker.io)).

- **Search Almost Everything**: Returns information about:
    - Quests
    - Items
    - Skill Nodes
    - Hideout Modules
    - Projects
    - ARCs
- **Calculates additional information for items**:
    - Value delta when salvaging or recycling
    - Price comparison when purchasing from a trader (including Credits-to-Coins conversion rates)
    - Stash space gained or lost compared to recipe requirements
- **Event Schedule**: Displays upcoming map events in your local time, color-coded by map.
- **Interactive Selection**: If multiple results are found, you can quickly select with number keys.
- **Automatic Updates**: Built-in `arc update` command to keep the tool and data up to date.

## PowerToys Run
My primary way of using this is with **PowerToys Run**. Depending on your setup, you can hit `ALT+SPACE` at any time and type `>arc <query>` to get results from anywhere.

## Feedback & Testing

**I am actively looking for feedback**

If you find any bugs or have any suggestions, please don't hesitate to open an issue!

---

## Installation

### From Release
1. Download the [latest release](https://github.com/KuroZantetsuken/ARC-Raiders-CLI/releases/latest/download/arc-raiders-cli.zip).
2. Extract the ZIP to a folder.
3. Double-click `install.bat` to run it.
   - **Note**: Do not move the folder after running the install script. If you want to move it, uninstall first!
4. Restart your terminal to enable the `arc` command.

### From Source
1. Clone the repository with submodules:
   ```powershell
   git clone --recursive https://github.com/KuroZantetsuken/ARC-Raiders-CLI.git
   cd ARC-Raiders-CLI
   ```
2. Run `.\install.bat` to configure the environment.

## Usage

Run `arc` followed by your search query.

```powershell
arc cat          # List data matching "Cat"
arc cat 0        # Immediately display the first result for "Cat"
arc cat bed      # Multi-word searches work without quotes
arc events       # View the map event schedule
arc update       # Check for and install software updates
```

- **Selection**: Press `0`-`9` to select from multiple results.
- **Direct Access**: Skip selection by adding the index: `arc shield 0`.

## Updating Data

If you installed from source using Git, you can update the game data separately:
```powershell
git submodule update --remote
```
For release builds, use `arc update` to update the entire tool including data. The tool also performs periodic background checks and will notify you when new game data or script updates are available.

## Uninstallation

To undo changes made by the install script, run `uninstall.bat`.

## Credits
This tool uses game data provided by the [RaidTheory/arcraiders-data](https://github.com/RaidTheory/arcraiders-data) project.
Special thanks to the team at [arctracker.io](https://arctracker.io) for their work in compiling and maintaining this resource.
