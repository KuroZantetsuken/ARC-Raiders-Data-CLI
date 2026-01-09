# ARC Raiders Data CLI & Stash Optimizer

This utility helps players of ARC Raiders optimize their stash space by calculating whether it's more efficient to store raw materials or crafted items. It also provides a CLI tool to quickly look up item information.

## Features

- **Stash Savings Calculation**: Automatically calculates the net stash space gained or lost by crafting items based on stack sizes and recipes.
- **Local Data Mirror**: Maintains a local copy of item data with added `stashSavings` values.
- **CLI Lookup Tool**: A PowerShell script to search for items and view their details, including recipes and stash savings.

## Setup

1.  **Clone the Repository**:
    ```bash
    git clone https://github.com/KuroZantetsuken/ARC-Raiders-Data-CLI.git
    cd ARC-Raiders-Data-CLI
    ```

2.  **Initialize Data Source**:
    This project uses the [RaidTheory/arcraiders-data](https://github.com/RaidTheory/arcraiders-data) repository as a data source.
    ```bash
    git submodule update --init --recursive
    ```

3.  **Run Calculation Script**:
    This script reads the source data, calculates stash savings, and populates the `data/items` directory.
    ```bash
    python scripts/calculate_savings.py
    ```

## Usage

### CLI Lookup Tool

Use the PowerShell script to search for items.

```powershell
./scripts/arc-cli.ps1 "Item Name"
```

Example:
```powershell
./scripts/arc-cli.ps1 "Durable Cloth"
```

Output:
- **Name**: Durable Cloth
- **Stash Savings**: 0.1800 slots (Positive means you save space by crafting!)
- **Recipe**: fabric: 14
- ...

### Updating Data

If the game data changes or you want to fetch the latest updates from RaidTheory:

1.  Update the submodule:
    ```bash
    git submodule update --remote
    ```
2.  Rerun the calculation script:
    ```bash
    python scripts/calculate_savings.py
    ```

## Project Structure

- `arcraiders-data`: Submodule containing original game data.
- `data/items`: Generated data with `stashSavings` added.
- `scripts/calculate_savings.py`: Python script for processing data.
- `scripts/arc-cli.ps1`: PowerShell CLI tool.
