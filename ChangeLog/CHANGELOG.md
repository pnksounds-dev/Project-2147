# 🚀 New2DGame – Unified Changelog

> This file unifies the previous game changelogs (core, main menu, and reference project) into a single history focused on **version 3.x.x and above**.

---

## 📌 Version Overview

- **1.x.x – Foundation**  
  Core engine, player, HUD, basic weapons, menus, and economy.

- **2.x.x – Combat & Systems**  
  Advanced weapons (Phaser, companions), inventory, skills, AI, and spawning.

- **3.x.x – World & Trading**  
  Infinite world, territories, ARK Trading, backgrounds, and environment systems.

- **4.x.x – Advanced UI & Performance**  
  Radar HUD, debug tools, collision/physics improvements.

- **5.x.x – Polish & Optimization**  
  UI polish, HUD variants, cleanup, and performance tuning.

Current focus: **3.x.x+ world/trading, Phaser flow, audio, and main menu overhaul**.

---

## 🌍 3.x.x – World, Trading & Environment

### 3.0.0 – World Systems Update
- **Infinite World**: Seed-based procedural universe.
- **Territory Control**: Faction-owned regions with context-aware spawns.
- **Navigation**: Coordinate and chunk systems for stable positioning.

**Key Systems**
- `CoordinateSystem.gd`, `ChunkManager.gd`, `SeedManager.gd`  
- `TerritoryManager.gd`, `FactionManager.gd`, `TerritorySpawner.gd`

---

### 3.1.0 – ARK Trading System (Released)
- **ARK Trading**: Press **F** near ARK stations to open trading.
- **Coin System**: Persistent currency, integrated with inventory and trading.
- **Buy & Sell**: Weapons, upgrades, consumables, and resources.
- **Interaction Prompts**: Clear "Press F to Trade" prompts near stations.

**Files**
- `TraderHub.gd`, `ItemDatabase.gd`, `TradingPanel.gd`  
- `InteractionPrompt.gd`, `Ark.gd` (updated), `Player.gd` (F-key integration)

---

### 3.2.0 – Environment & Backgrounds
- **Dynamic Backgrounds**: Procedural space backgrounds tied to world state.
- **Background Renderer**: High-quality parallax / layered rendering.
- **Star Field**: Procedural star systems with motion and depth.
- **Environment Events**: Deep space warnings and dimensional transitions.

**Files**
- `DynamicBackground.gd`, `BackgroundRenderer.gd`, `StarField.gd`  
- `DeepSpaceWarning.gd`, `DimensionTravel.gd`

---

### 3.3.x – Spawning, Radar & Debug (Reference Systems)
> Integrated conceptually from the reference project; implementation details may differ.

- **3.3.0 – Enemy Spawning**  
  Faction-aware spawning, chunk-based world sectors, debug tools.

- **3.3.1 – Spawn Fixes & Debug**  
  Reliable enemy spawning with proper hitboxes, health bars, and cleanup.

- **3.3.2 – Chunk-Based Zoom & Radar Integration**  
  Chunk-based zoom controls, dynamic spawn distance, Radar HUD integration.

Key ideas adopted:
- Chunk/territory-based spawning tuned to zoom level.  
- Radar/zoom APIs for HUD.

---

## ⚔️ Phaser, Combat & Weapon Flow Updates

### 3.x – Phaser & Weapon System Refinements
- **Phaser Weapon Flow**: Cleaned up weapon firing, cooldown, and targeting.
- **Scout Phaser**: Improved behavior and targeting stability.
- **Weapon Library Cleanup** (from reference):
  - Removed broken weapon definitions.
  - Ensured all listed weapons load cleanly.

Impact:
- More predictable combat behavior.  
- Less runtime noise from weapon load failures.

---

## 🎵 Audio & Performance Updates

### 3.x – Audio Manager & Mixing
- **Menu & In-Game Music Paths**: Stable track routing (e.g. `bounce_orbits` for main menu).
- **Volume Defaults**: Fixed defaults so audio starts at sane levels instead of muted.
- **Loop Stability**: Addressed crashes from bad loop flags when returning to menu.

Concepts pulled from the reference project’s performance work:
- Avoid excessive logging or polling in audio callbacks.  
- Keep audio initialization centralized in `AudioManager.gd`.

---

## 🏠 Main Menu & Ship Selection Overhaul (3.2.x+)

> These are your most recent UI changes and are the focus of the **Updates** tab.

### 3.2.0 – Main Menu Layout Refresh
- **Top Navigation**: Start, Updates, Gallery, Settings, Credits, Ships, Saves, Quit.
- **Content Regions**: Middle/right panels for screenshots, MOTD, and feature panels.
- **Discord & Social Links**: Quick access from bottom bar.

### 3.2.1 – Main Menu Shell & Ship Selection Overhaul (Current)
- **Main Menu Shell**:
  - Unified gray top and bottom bars with glass central panel.
  - Flat, sharp-cornered StyleBoxes shared between main menu and inventory.
  - Clean separation between navigation/header controls and content panels.
- **Ship Selection & New Game Flow**:
  - `MainMenuShipBuilder.gd` + `ShipBuilderPanel.tscn` for ship selection.
  - Card-based ship grid with ship stats and details.
  - Start Game integration via selected ship and New Game flow.
  - In-menu notifications for invalid actions (e.g. no ship selected).

### 3.2.2 – Resolution-Independent UI Scaling
- **Base Resolution**: 1920×1080.
- **Dynamic UI Scale**: Automatically scales between 0.5x and 2.0x based on viewport.
- **Scaled Elements**:
  - Ship cards (size, borders, corner radius, shadows).
  - Fonts (header, titles, stats, details, buttons).
  - Spacing and grid gaps.
- **Result**: Ship selection UI looks consistent and readable from 720p to 4K.

### 3.2.3 – Main Menu Polish
- **Removed Blue Tab Underline**: Tabs now rely on button states only (hover/pressed styles).
- **Tab Logic Cleanup**: Centralized tab handling and safer underline code paths.
- **Updates Tab**: Now dedicated to this unified changelog.

---

## 🧭 Updates Tab – What You’re Seeing Here

The **Updates** tab in the main menu now renders this file:

- Path: `res://ChangeLog/CHANGELOG.md`  
- Loader: `ChangelogPanel.gd` (markdown → RichTextLabel formatting)
- Content: Unified view of versions **1.x.x → 3.x.x+**, with emphasis on:
  - Trading & ARK systems (3.1.x)
  - World & environment (3.2.x)
  - Phaser/weapon and audio stability work
  - New main menu and ship selection overhaul (3.2.x+)

---

## 🔮 Planned Next Steps (4.x.x+)

> High-level roadmap; details may evolve.

### 4.0.0 – Advanced UI & Radar
- Radar HUD with chunk/territory awareness.
- Advanced debug tools and overlays.
- Deeper integration between world systems and UI.

### 4.1.0 – Collision & Physics Polish
- Collision edge calculator integration.
- Physics performance and stability tuning.

### 5.x.x – Full Polish & Optimization Pass
- HUD simplification where needed.
- Old UI cleanup and deprecation.
- System-wide performance audit.

---

**Current Game Version**: **3.2.1** (World + Trading + Main Menu/Ship Builder Overhaul)  
**Changelog Source**: Unified from `CHANGELOG-latest.md`, `MAIN_MENU_CHANGELOG.md`, and reference project docs.
