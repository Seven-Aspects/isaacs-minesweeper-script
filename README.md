|Русский|English|
|:---|:---|
|[Клик](ru/README_ru.md)|[Click](README.md)|

# Isaac's Minesweeper Script

An enhanced control panel for **Isaac's Minesweeper** in Roblox with a modern GUI and a collection of automation tools for working with the game board.

> Current version: **v10.1 Fast Hard**

## Features

### 🎨 Modern Interface

The panel uses a redesigned dark interface with:

- clean cards and tabs;
- consistent buttons and toggle styles;
- improved spacing and alignment;
- adaptive window positioning;
- a compact minimize button;
- settings grouped into dedicated functional tabs.

### ⚡ Player Speed

Allows you to change the character's movement speed with a dedicated slider.

- speed range: `8–100`;
- `Custom speed` toggle;
- `Reset` button for returning to the default speed;
- the selected speed is reapplied after the character respawns.

### 🚜 AFK Farm

Automatically searches for the nearest suitable unopened cell and moves the character toward it.

- selects the nearest available cell;
- does not use heavy `PathfindingService` for the main movement loop;
- keeps checking for new cells when there are no current targets;
- stops moving when the feature is disabled.

### 🚩 AutoFlag

Automatically places flags based on the current state of the board.

Two modes are available:

#### Smart Mode

Uses opened-cell information, mine counts, and neighboring cells to determine which cells can be safely flagged.

#### Hard Mode

A fast automatic flagging mode.

- operates within `WORK RADIUS`;
- selects the nearest detected mine;
- uses a cached mine list instead of rescanning the whole board on every step;
- reduces unnecessary delays between attempts;
- optimized for high-frequency flag placement.

### 🛡 Mine Protection

Automatically attempts to flag a detected mine when the character gets close to it.

The protection distance can be adjusted with a dedicated slider.

### 🧹 Remove Wrong Flags

Automatically removes flags from cells that are not mines.

### 💡 Flag Lights

Highlights cells with different colors depending on their state:

- red — detected mine;
- orange — flagged mine;
- purple — incorrect flag.

The highlights are rendered as a visual top layer above the tile.

### ⌨️ Macros

Allows hotkeys to be assigned to the main actions:

- show/hide the menu;
- toggle AutoFlag;
- toggle Flag Lights.

Keys can be changed directly from the `Macro` tab.

## Tabs

### Main

Main settings:

- Player Speed;
- AFK Farm;
- Work Radius;
- Mine Protection;
- Remove Wrong Flags.

### FlagLights

Configure tile highlighting and its hotkey.

### AutoFlag

Configure AutoFlag speed, Smart Delay, and Hard Mode.

### Macro

Configure keyboard shortcuts.

## Controls

The panel can be moved by dragging the top area of the window.

The `−` button minimizes the panel into a compact circular indicator. Clicking it again restores the main window.

Hotkeys can be configured from the `Macro` tab.

## Configuration

Main values are located near the top of the Lua script in the `SETTINGS` section.

You can adjust:

- work radius;
- AutoFlag speed;
- delays;
- Mine Protection distance;
- highlight colors;
- Player Speed parameters.

## Performance

Version `v10.1 Fast Hard` primarily focuses on optimizing `Hard Mode`.

The main optimization is avoiding a full scan of every tile on every iteration. Instead, the script keeps a cached list of detected mines and limits the search to the active work radius.

This reduces unnecessary operations when the game board becomes large.

## Important

The script relies on the game's specific structure and logic, including the `tiles` folder, tile attributes, and the remote used for flagging.

If the game changes object names, attributes, or remote-call behavior, the script may need to be adapted.

## Version

**v10.1 Fast Hard**

Version highlights:

- redesigned modern GUI;
- removed the game/player statistics panel;
- unified and improved controls;
- added Player Speed;
- added fast AFK Farm;
- optimized Hard Mode AutoFlag.
