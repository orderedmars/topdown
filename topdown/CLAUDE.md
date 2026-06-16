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
- **Combat (foundation):** Turn-based battle scene, Pokemon-style overlay.
  - **Triggers:** (1) Enemy contact via the `MeleeRange` Area2D on `enemy.tscn` (radius 28, mask=2). (2) Skill projectile (fireball/arrow) hits an enemy and the enemy survives the chip damage — `take_damage` runs first, then `BattleManager.start_battle(enemy)` if `enemy.health > 0`. If the skill kills the enemy outright, no battle (clean kill).
  - **`BattleManager`** (Autoload, `battle/battle_manager.gd`) — singleton. Pauses `SceneTree`, overlays `battle/battle_scene.tscn` as a `CanvasLayer` with `process_mode = PROCESS_MODE_ALWAYS` (the dungeon underneath freezes but stays in memory). On win → unpause + `enemy.die()` (existing loot path). On lose → `RunState.end_run()` → `change_scene_to_file("res://ui/character_creation.tscn")` (permadeath).
  - **`battle_scene.gd`** — reads `BattleManager.current_enemy` in `_ready` and snapshots both sides into Combatant dicts. Player stats sourced from `RunState.player_adventurer` (`dexterity` → initiative, `strength` → attack, `max_health` → HP) with fallbacks for direct-scene testing. Player HP is written back to the player node on victory.
  - **Initiative:** each side rolls `stat + d6`. Higher acts first; tie goes to the player.
  - **Status effects:** `enemy.effects: Array[Dictionary]` carries status into battle. Format: `{ "type": String, "turns": int, ... }`. Apply via `enemy.effects.append({...})` before triggering the battle (e.g., a future poison-tipped arrow). Only `"poison"` (with `damage_per_turn`) is wired; new types plug into `_tick_effects`.
  - **v1 scope (collaborator owns expansion):** Solo 1v1 only, Attack-only action menu (Skill/Item/Flee disabled), placeholder damage `base ± d4` floored at 1, no defense/to-hit/crit. Boss placeholder (`dungeon/boss_placeholder.gd`) is still instakill-on-touch — NOT routed through the battle system yet.
- **Skills:** Fireball and Arrow. Both `Area2D` projectiles. Fireball is AoE — chips everything in range, then starts a battle with the first surviving enemy (others stay in the dungeon at reduced HP, can be re-engaged separately).
- **Enemy AI:** Four-state machine: IDLE → SUSPICIOUS → CHASING → SEARCHING.
  - **IDLE:** Enemy slowly sweeps its vision cone left/right via `sin()` oscillation.
  - **SUSPICIOUS:** Triggered by hearing (player noise radius overlaps hearing zone). Enemy turns toward player and builds suspicion (`suspicion_time` 3.5s default). Vision while suspicious → immediate chase.
  - **CHASING:** Triggered by vision (LOS raycast) or full suspicion buildup. Tracks `last_known_position` every frame. Movement routed through `NavigationAgent2D` (NOT straight-line) so the enemy paths around corners through 64px corridors. When detection is lost, rushes to last known position for `chase_timeout` seconds before giving up.
  - **SEARCHING:** Arrived at last known position via nav agent, sweeps briefly, then returns to IDLE.
  - **Damage:** Always triggers immediate chase regardless of current state.
  - **Rotation rule (important):** Only `$VisionCone` rotates to face direction. The body never rotates — pixel-art sprites stay upright and should read `vision_cone.rotation` to pick a facing frame. Touching `rotation` on the root will tilt the sprite/health bar/labels and is the wrong knob.
  - **Pathing:** `NavigationAgent2D` child of `enemy.tscn`. The dungeon scene bakes a `NavigationPolygon` from FLOOR cells at `_ready` (via `NavigationServer2D.bake_from_source_geometry_data`, `agent_radius = 8`). All CHASE/SEARCH movement goes through `_steer_along_nav(target, speed, rot_lerp, delta)`.
  - **Detection geometry** is defined by CollisionShapes in the Inspector: `VisionCone/CollisionShape2D` (ConvexPolygon triangle, 320 long × 180 wide) and `DetectionZone/CollisionShape2D` (Circle, radius 280). The player's noise radius (layer 4) grows when sprinting, shrinks when crouching.
  - **Combat stats** (`@export` on `enemy.gd`, used by the battle scene): `display_name`, `max_health`, `attack_damage`, `combat_initiative`. Plus runtime `effects: Array[Dictionary]`.
  - **Melee trigger:** `MeleeRange` Area2D child. On `body_entered` with the player → `BattleManager.start_battle(self)`.
- **Traps:** Spike Trap (instant damage + stun). Sludge Trap (slow + damage over time). Trap damage on enemies bypasses the battle system (enemies can die to traps in the dungeon directly via `take_damage`).

## Coding Conventions
- **No magic numbers for enums.** Use named enum values (e.g. `player.SkillMode.FIREBALL`, not `1`).
- **No debug `print()` calls** in gameplay code paths (traps, skills, etc.).
- **NPC interaction labels** are shown/hidden via `_on_interaction_zone_body_entered/exited` signals wired in the `.tscn` file — always implement these methods in any NPC script.

## Dungeon Generation
- **`DungeonGenerator`** (`dungeon/dungeon_generator.gd`) — pure-data generator. Takes a `FloorData` and returns `{ cells, rooms, corridors, bounds }`. Growing-tree placement + 2-wide L-corridors (length 8-14 tiles, tuned so there's a visible "approach" between rooms) + cellular-automata cave shapes (over the full room rect — corridor tiles and room centers are locked as FLOOR so the room is always traversable).
- **`dungeon/dungeon_floor.gd`** — scene controller on `scenes/dungeon.tscn` root. At `_ready`: generates layout, paints cells via `Node2D._draw()` (block-out — real tileset deferred), builds merged wall collision, **bakes a `NavigationPolygon`** from FLOOR cells, spawns the player at the entry room, spawns the entry-room return portal, and reveals the entry room. Per-frame: handles fog-of-war room reveals and spawns enemies/minibosses on first reveal.
- **Per-floor data** lives in `dungeon/floors/floor_<N>.tres` (e.g., `floor_1.tres` — `FloorData` resource). `_default_floor_data()` auto-loads `res://dungeon/floors/floor_<RunState.current_floor>.tres`, falling back to a blank resource if missing. The Inspector `floor_data` export on the dungeon scene overrides the auto-load (use for testing).
  - **To author a new floor:** right-click `dungeon/floors/` → New Resource → `FloorData` → save as `floor_<N>.tres` → fill in `enemy_pool` / `miniboss_pool` / `loot_pool` / `encounter_pool` / room counts / per-floor visuals in the Inspector.
- **Enemy/miniboss spawning:** On first reveal of an `ENEMY` or `MINIBOSS` room, picks `enemies_per_room_min..max` (or `minibosses_per_room_min..max`) random scenes from the floor's pool and instantiates them on random FLOOR tiles inside the room (excludes the room center / corridor entry tile, enforces 3-tile minimum spacing). Reveal-time spawn matches the boss pattern and avoids the enemy's hearing-cone Area2D triggering through walls before the room is lit.
- **Navigation polygon:** Baked once per floor in `_build_navigation_region()` via `NavigationServer2D.bake_from_source_geometry_data`. Each FLOOR cell contributes a 1-tile-square traversable outline; the baker merges and adds holes for CA-carved walls. `agent_radius = 8` keeps paths off wall edges so the 32px enemy box doesn't clip in 64px corridors. The `NavigationRegion2D` is added as a child of the dungeon node — `NavigationAgent2D`s on enemies pick it up via the world's default nav map.
- **Magic-circle portals** (`dungeon/magic_circle_portal.gd`) — `Area2D` (non-blocking) painted as a pulsing ring on the floor. Two flavors: gold gate in the entry room (returns to town) and purple gate spawned in the boss room after boss defeat (advances to next floor). **Both set `collision_mask = 2` because the player is on `collision_layer = 2`.**
- **`dungeon/boss_placeholder.gd`** — stub boss (Area2D, walk-into-it to defeat). Combat-system collaborator can replace or hook into the `defeated` signal. Spawned **on first reveal of the boss room** so a fast-moving player can't bump into an invisible boss. **NOT yet routed through the battle scene** — currently an instakill placeholder.
- **Fog of war:**
  - Rooms reveal when the player tile is inside their rect, OR when within `REVEAL_BUFFER = 3` tiles of the rect AND the player is in a corridor that endpoints to that room (pre-reveal buffer for "see what's coming"). The corridor-endpoint gate prevents revealing through walls toward an unrelated room that happens to be spatially close.
  - Corridors are hidden until at least one endpoint room is discovered. Walls bounding a corridor are mapped to that corridor (1-tile ring) and hide/show together. Wall collision is built for the full layout, so hidden walls are real obstacles.

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
- **`InventoryUI`** (Autoload CanvasLayer) — press `Tab` to open. Left panel = shared inventory. Right panel = equipment slots for selected character. Character tabs switch between party members.

## Future Plans
- **Combat expansion** (collaborator-owned): Skill catalog usable in battle (drawing from `learned_skills`/`equipped_skill_slots` on the active adventurer); item consumables from inventory; multi-target & party combat (turn queue extension); BG3-style action economy; status effect catalog beyond poison; defense/dodge/to-hit/crit formulas; boss placeholder → battle-scene integration.
- **Distinct enemy types:** Floor 1 will have zombies, goblins, orcs (etc.) — visually and behaviorally different, NOT color clones. Each new enemy `extends Enemy` (or extends `enemy.gd` via inheritance / a strategy hook) and overrides AI tweaks; the base machine, vision/hearing geometry, nav agent, and melee trigger come for free.
- **Procedural Generation:** Floors 2–10 — author `floor_<N>.tres` per floor with theme, enemy/miniboss/loot/encounter pools.
- **Reputation System:** NPC prices and bounty hunters.
