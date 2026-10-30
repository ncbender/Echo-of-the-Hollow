# Map & Fog of War 1.0 (UI-Paket 2)

Working minimap, large area map (M), spoiler-free region overview, persistent fog of war per map.
Builds on UI Layout Lock 1.0 (`docs/UI_LAYOUT_LOCK_1_0.md`). No change to XP, talents, enemies,
bosses, loot, quests, rewards, crafting, camera zoom, map sizes, story or Region 2. Save v15 unchanged.

## Parts

| Script | Role |
|---|---|
| `scripts/world/area_map.gd` (`AreaMap`) | Simplified map picture, 1 px per 8 world px, built once from the scene's real geometry: every `ArenaFloor` (floor, `SidePaths`, `MainRoad`/`Road*`/`Path*`/`Aisle` as road) and every visible `WallBlock` (forest, walls, closed story barriers). `is_solid(world)`. Bounds = `GameMap.camera_bounds`, else the union of the floors, else `spawn_area`. |
| `scripts/world/map_fog.gd` (`MapFog`) | Fog grid of 32 px cells, one bit per cell, its own small overlay texture. |
| `scripts/world/map_markers.gd` (`MapMarkers`) | Collects markers from the scene, explored cells only. |
| `scripts/world/map_landmark.gd` (`MapLandmark`) | Optional named spot (Marker2D + `label`), purely for the map. |
| `scripts/ui/hud/area_minimap.gd` (`AreaMinimap`) | Minimap in the top-right `MinimapFrame`. |
| `scripts/ui/map_painter.gd` (`MapPainter`) | Shared drawing (picture + fog, markers, player arrow) for minimap and area map. |
| `scripts/ui/world_map_panel.gd` (`WorldMapPanel`) | Map window: tabs **Area** (default) and **Region**. |
| `scripts/world/game_map.gd` | Builds `area_map`/`fog` in `_ready` (before the HUD binds), explores on cell change, rebuilds the picture after story changes. |

## Minimap
- 200 × 200 design px (168 × 168 at 150 % UI), north up, `VIEW_WORLD` = 1024 world px wide.
- Follows the player; at the map edge the view stops (`AreaMinimap.view_rect`) and the arrow moves
  off-centre. A map smaller than the view is centred.
- Arrow = `Player.aim_direction` (facing). A faint ring shows the current near range (transient).
- Markers are re-collected every 0.25 s; the picture is only redrawn, never rebuilt per frame.

## Area map (M, Area tab)
> **Superseded by Map UX 2.0** (`docs/MAP_UX_2_0.md`): readable whole-pixel scale, opens centred on the player, drag /
> arrow keys / centre button, compact symbol legend. Fog, markers and the rules below are unchanged.

- The whole current map, scaled to fit the window (max 900 × 540 design px, smaller on small
  canvases), same picture, fog and markers as the minimap, with labels for exits, waystones, NPCs
  and landmarks. M / Esc / Close button close it. Like every window it blocks player input
  (attacks included); the world is **not** paused (same as all windows except the pause menu).

## Region tab
> **Superseded by Map UX 2.0** (`docs/MAP_UX_2_0.md`): compact place network, waystone state on the nodes, the
> separate waystone list and the text legend replaced by the place details and a help "?"; spoiler rules unchanged.

- The existing schematic (`MapGraph`): visited places, paths, unknown neighbours as a nameless "?".
- **Spoiler fix:** the legend no longer lists every waystone with "undiscovered". It lists only
  `WorldMapPanel.known_waystones`: awake ones, and those on places already visited (as "silent").
- Legend sits below the schematic; column spacing narrows to 180 px on a 1280-px canvas (150 % UI),
  so nothing scrolls sideways. At 150 % the legend is reached by scrolling down.

## Fog of war
- Three looks: unexplored = dark; explored = map picture dimmed; near range = ring on the minimap
  only (not saved).
- Explored only by the player's real position (`GameMap._update_fog` when the player enters a new
  cell). Quest starts, dialogues, travel targets never explore anything.
- Reveal: breadth-first search from the player's cell, radius 6 cells (192 px ≈ the near half of
  the 512 × 288 view at zoom 3.75). A step between two cells is blocked when the line between their
  centres touches a wall, a closed barrier or void; the blocked cell itself is revealed (it is the
  wall you see), the search never continues behind it.
- **Limits (no line of sight):** around a corner the search follows free cells up to the radius;
  a wall thinner than ~8 px between two floors may let one cell through; a room behind a wall stays
  dark only if every path to it within the radius crosses a wall. Tested: closed Tangled-Wood
  shortcut, part of the Heart of the Roots seen from the road below.
- Story barriers: the picture is rebuilt on the next frame after any world-flag or quest change
  (after `StoryConditional` refreshed); an opened barrier disappears, a closed one is solid.
- Fog exists only on maps with `MapDefinition.show_on_map` (trials/grounds have none).

## Storage
- `WorldState.map_states[<map>]["fog"] = "v1:<w>x<h>:<base64 bits>"`, written on every explored
  cell into the character, saved with the next regular save (no extra saves, no autosave trigger).
- No schema change: Save v15 stays; `map_states` already accepted strings.
- Old save without fog: the map starts dark and reveals the player's surroundings on arrival.
- Invalid data (unknown format, other grid size after a map rebuild, broken base64, wrong length):
  discarded as a whole with `push_warning`, the map starts dark - never half applied, no crash.

## Markers (explored cells only)
Player · known exits (only while their `StoryConditional` is open - a sealed exit is never shown) ·
waystones (awake / "(silent)") · resting places (`Checkpoint`) · NPCs (with "!"/"?") · landmarks
(`MapLandmark`) · quest goals only if the current objective names them (gold ring) **and** their
cell is explored. Never: enemies, resources, loot. Root marks / Lost-Hunter clues are therefore not
shown before the player has been there - the map never solves those quests.

Landmarks added (4 per map, open ground, tested): Whisper Forest - Split Oak, Forager's Path, The
Old Trail, Warden's Clearing; Tangled Wood - Root Arch, Heart of the Roots, The Hollow, Sunken
Grove; Chapel - Chapel Yard, The Nave, Cloister, Shelter; Warden's Rest - Forecourt, Watch Post,
Guard Hut, Barracks.

## Performance (headless, this machine)
| Map | Picture | Fog grid | Build | Reveal per cell change | Markers (every 0.25 s) |
|---|---|---|---|---|---|
| Whisper Forest | 328 × 188 (240 KB) | 82 × 47 | 0.8 ms | 0.05 ms | 0.6 ms |
| Tangled Wood | 296 × 224 (259 KB) | 74 × 56 | 0.8 ms | 0.23 ms | 0.5 ms |
| Chapel | 208 × 152 (123 KB) | 52 × 38 | 0.4 ms | 0.36 ms | 0.3 ms |
| Warden's Rest | 168 × 136 (89 KB) | 42 × 34 | 0.3 ms | 0.42 ms | 0.2 ms |

## Tests
`tests/integration/test_map_fog.gd` (8): minimap view/edges/north/rebind, dark start + movement +
no reveal by quest start, walls and closed/opened barrier, markers only explored + no sealed exit,
save/load + travel + Save v15, old/broken fog, map window M/Esc/Area/Region/no spoiler/no pause at
100/125/150 %, landmarks on open ground + picture sizes. Screenshots (real window, 1080p/1440p/4K ×
100/125/150 %) only in the session scratchpad.

## Open / playtest points
- Readability of the provisional glyphs and colours (no final art).
- Whether the world should pause while the map is open (currently not, like all windows).
- Fog radius 6 cells and minimap range 1024 px: feel-test.
- Region schematic reserves the whole region's grid even when little is known (empty space).
