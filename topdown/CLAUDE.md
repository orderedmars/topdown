# TopDown RPG Project (Fear & Hunger x BG3)

## Project Overview
A dark fantasy top-down RPG featuring smooth omnidirectional movement, dangerous dungeons, and a multi-member party system.

## Technical Architecture
- **Movement:** Smooth 8-directional physics-based movement (`move_and_slide`).
- **Party System:** `PartyManager.gd` (Autoload). Uses a frame-based position history for a "Perfect Trail" effect.
  - **Chain Link:** Every follower records their own history, allowing the next member to follow them.
- **Dialogue System:** `DialogueManager` (Autoload). Supports branching choices and dynamic button generation.
- **NPC System:** All NPCs use `npc/npc_base.gd` (`class_name NPCBase`). NPCs live in subfolders (e.g., `npc/John/`) and each has its own `.tscn` scene file. Per-NPC data (name, dialogue text) is set via `@export` variables in the scene Inspector — no scripting needed for basic NPCs.
  - **Adding a new basic NPC:** Create a subfolder under `npc/`, make a new scene with the same node structure as John's, attach `npc_base.gd`, fill in `npc_name`/`greeting_idle`/`greeting_party` in the Inspector.
  - **Adding an NPC with unique behaviour** (vendor, quest giver): Create a new script that `extends NPCBase` and add only the extra logic. The wander/follow/dialogue base is inherited for free.
- **UI:** 
  - `HUD`: Shows Player stats and current Party Members list.
  - `DialogueUI`: Bottom-screen panel for NPC interactions.

## Current Systems
- **Player:** Health/Mana/Stamina. Sprint/Crouch mechanics. Position history recording.
- **Combat:** Basic detection and interaction systems. Fireball and Arrow skills.
- **Enemy AI:** Four-state machine: IDLE → SUSPICIOUS → CHASING → SEARCHING.
  - **IDLE:** Enemy slowly sweeps its vision cone left/right via `sin()` oscillation.
  - **SUSPICIOUS:** Triggered by hearing (player noise radius overlaps hearing zone). Enemy turns toward player and builds suspicion. Vision while suspicious → immediate chase.
  - **CHASING:** Triggered by vision (LOS raycast) or full suspicion buildup. Tracks `last_known_position` every frame. When detection is lost, rushes to last known position for `chase_timeout` seconds before giving up.
  - **SEARCHING:** Arrived at last known position, sweeps briefly, then returns to IDLE.
  - **Damage:** Always triggers immediate chase regardless of current state.
  - Detection geometry is defined by CollisionShapes in the Inspector, not script variables: `VisionCone/CollisionShape2D` (ConvexPolygon triangle) and `DetectionZone/CollisionShape2D` (Circle). The player's noise radius (layer 4) grows when sprinting, shrinks when crouching.
  - **Future:** When the enemy body contacts the player, this should trigger turn-based combat. A melee-range Area2D on the enemy will be needed for that trigger.
- **Traps:** Spike Trap (instant damage + stun). Sludge Trap (slow + damage over time).

## Coding Conventions
- **No magic numbers for enums.** Use named enum values (e.g. `player.SkillMode.FIREBALL`, not `1`).
- **No debug `print()` calls** in gameplay code paths (traps, skills, etc.).
- **NPC interaction labels** are shown/hidden via `_on_interaction_zone_body_entered/exited` signals wired in the `.tscn` file — always implement these methods in any NPC script.

## Inventory System
- **`InventoryManager.gd`** (Autoload) — single source of truth for all item and equipment state.
  - `main_inventory` — shared pool (all party members draw consumables from here).
  - `character_equipment` — per-character dict keyed by character name → 8 equipment slots.
  - `character_skills` — per-character Array[SkillData] of size 4. null = locked slot.
  - Characters must call `InventoryManager.register_character(name)` in `_ready()` (or on party join).
- **Equipment slots (8):** WEAPON, OFFHAND, HEAD, BODY, LEGGINGS, BOOTS, ACCESSORY, SOUL.
- **Soul items** — rare drops, go in SOUL slot, carry `soul_passive_type` + `soul_passive_value`. Stat application deferred until the combat/stat system is built.
- **`SkillData`** (Resource) — 4 slots per character. Skill unlock and battle use deferred to combat system.
- **Items as Resources** — all items are `.tres` files under `items/`. `ItemData` class_name. To add a new item: right-click in FileSystem → New Resource → ItemData, fill in the Inspector.
- **Loot system** — enemies have `@export var loot_table: LootTable`. On death, auto-pick drops spawn as `ItemPickup` (player walks over), container drops spawn as `LootContainer` (E to open). Assign a `LootTable` resource in the enemy Inspector.
- **`InventoryUI`** (Autoload CanvasLayer) — press `I` to open. Left panel = shared inventory. Right panel = equipment slots for selected character. Character tabs switch between party members.

## Future Plans
- **Combat System:** Turn-based battles triggered when enemy contacts player (melee-range Area2D needed on enemy). BG3-style mechanics. Consumables usable from inventory during battle.
- **Procedural Generation:** Dungeon floor generator.
- **Reputation System:** NPC prices and bounty hunters.
