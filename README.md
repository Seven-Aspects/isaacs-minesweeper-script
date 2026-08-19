|Русский|English|
|:---|:---|
|[Клик](ru/README_ru.md)|[Click](README.md)|

# Isaac's Minesweeper Script

A control panel for **Isaac's Minesweeper** on Roblox with a modern GUI and a set of tools for automating interaction with the game board.

> **Script version:** 10.1

## Features

### Modern UI

- modern dark design;
- `Main`, `FlagLights`, `AutoFlag`, and `Macro` tabs;
- consistent buttons and toggles;
- adaptive main window positioning;
- compact minimize button;
- scrollable content for smaller screens.

### Player Speed

Changes the character's movement speed with a slider.

- range: `8–100`;
- `Custom speed` toggle;
- `Reset` to restore the default speed;
- the selected speed is reapplied after respawning during the current session.

### AFK Farm

Automatically selects the nearest suitable unopened safe cell and moves the character toward it.

- searches for the nearest unopened cell;
- does not use `PathfindingService` in the main movement loop;
- keeps checking for new targets when no suitable cells remain;
- stops the character when disabled.

### AutoFlag

Automatically places flags based on the current state of the game board.

#### Smart Mode

Uses opened-cell information, mine counts, and neighboring cells to determine cells that can be flagged.

#### Hard Mode

A faster automatic flagging mode.

- limits the search to `WORK RADIUS`;
- selects the nearest detected mine;
- uses a cached mine list;
- refreshes the cache only when the board changes;
- reduces unnecessary delays between flag attempts.

### Mine Protection

Automatically attempts to flag a detected mine when the player gets close to it.

The protection distance can be adjusted with a dedicated slider.

### Remove Wrong Flags

Automatically removes flags from cells that are not mines.

### Flag Lights

Highlights tiles according to their state:

- red — detected mine;
- orange — flagged mine;
- purple — incorrect flag.

### Macro

Allows hotkeys to be assigned to the main actions:

- show/hide the menu;
- toggle AutoFlag;
- toggle Flag Lights.

## How to use

### 1. Open Roblox and join Isaac's Minesweeper

Start the game and wait until the game board has loaded.

### 2. Run the Lua script

The script is located in the repository root:

`isaacs-minesweeper-script.lua`

The current version is available at:

```text
https://raw.githubusercontent.com/Seven-Aspects/isaacs-minesweeper-script/refs/heads/main/isaacs-minesweeper-script.lua
```

In an environment that supports `loadstring`, the raw version can be loaded with:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Seven-Aspects/isaacs-minesweeper-script/refs/heads/main/isaacs-minesweeper-script.lua"))()
```

> The script requires an environment capable of executing the loaded Lua code and interacting with the Roblox API. Do not use third-party loaders you do not trust.

### 3. Open the menu

After execution, the **Isaac's Minesweeper** panel will appear.

By default, the menu can be shown or hidden with `RightControl`.

### 4. Configure Player Speed

In the `Main` tab:

1. move the slider to the desired speed;
2. enable `Custom speed`;
3. press `Reset` to restore the default value.

### 5. Configure AFK Farm

Enable `AFK Farm` in the `Main` tab.

The script will search for the nearest suitable unopened cells. When there are no available targets, the character stops and keeps checking until new cells appear.

### 6. Configure AutoFlag

Open the `AutoFlag` tab.

You can configure:

- operating speed;
- `Smart Delay`;
- `Hard Mode`.

For the fastest flag-placement mode, use `Hard Mode`.

### 7. Configure protection

The `Main` tab provides:

- `Mine protection`;
- `Remove wrong flags`;
- `Mine Protection` distance.

### 8. Configure tile highlighting

Open `FlagLights` to enable highlighting and change the colors used by the overlay.

### 9. Configure hotkeys

Open `Macro`, click the action you want to rebind, and then press the desired key.

## Main settings

Key parameters are located near the top of the Lua file, including:

- `WORK_RADIUS`;
- `MINE_PROTECTION_DISTANCE`;
- `AUTOFLAG_SPEED`;
- `AUTOFLAG_SMART_DELAY`;
- `AUTOFLAG_HARD_MODE`;
- Player Speed settings;
- highlight colors.

## Interface overview

### Main

- `Player Speed`;
- `AFK Farm`;
- `Work Radius`;
- `Mine Protection`;
- `Remove Wrong Flags`.

### FlagLights

- toggle highlighting;
- hotkey;
- mine, flagged-mine, and incorrect-flag colors.

### AutoFlag

- AutoFlag toggle;
- speed;
- Smart Delay;
- Hard Mode.

### Macro

- hotkey configuration.

## Performance

Hard Mode is optimized for frequent board updates. Instead of rescanning every tile on every iteration, it maintains a cached mine list and refreshes it when relevant objects or attributes change.

The search is also limited to the current `WORK_RADIUS`, reducing the number of checks on large boards.

## Requirements and compatibility

The script depends on the game's specific structure, including:

- the `workspace.tiles` folder;
- tile attributes such as `mine`, `flagged`, `cleared`, and `mines`;
- the remote used for placing and removing flags.

If the game developers change object names, attributes, or remote events, the script may need to be updated.

## Safety

Do not paste code from unknown sources into third-party loaders. To verify the current script, use the Lua source in the repository and the official raw URL above.

## License

This project is distributed under the **MIT** license. See `LICENSE` for details.
