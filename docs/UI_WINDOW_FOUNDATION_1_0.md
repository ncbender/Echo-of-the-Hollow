# UI Window Foundation 1.0 (UI-Paket 3)

Finishes the functional UI base before the Dark Classic pixel art is produced. Builds on
`docs/UI_DESIGN_SYSTEM.md` ("The Forgotten Chronicle"), `docs/UI_LAYOUT_LOCK_1_0.md` (HUD) and
`docs/MAP_AND_FOG_OF_WAR_1_0.md`. Asset list: `docs/UI_ASSET_CATALOG_1_0.md`.
No change to XP, talents, enemies, loot, gold, quests/rewards/progress, crafting, fog radius,
minimap range, camera zoom, map geometry, gates, Save v15, main story.

## 1. Journal categories
Tabs: **Main Story · Side Quests · Class Quests · Completed · Haven**.

| Page | Content |
|---|---|
| Main Story | Current main-story quests (steps done / now; later steps hidden) + "Earlier Chapters" (completed main-story quests with reward lines). |
| Side Quests | Active side quests as story cards (chapter "SIDE QUEST", description, step). "N completed - see Completed". |
| Class Quests | Active class quests (objectives with counters). Empty state names the class station. |
| Completed | Everything finished, grouped MAIN STORY / SIDE QUESTS / CLASS QUESTS. |
| Haven | Unchanged (ruins and stages). |

**Rule (data, not start event):** `StoryService.main_story_ids(db)` = every story quest reachable
from `FIRST_QUEST` through `next_quest_ids` (prologue → The First Signs → Beyond the Roots).
Every other story quest is a side quest. Checked against the data: the three side quests are not
in the chain and carry `chapter = "Side Quest"`; a quest with a start event inside the chain is
already a validation error. The quest tracker uses the same split (before: `start_event_id`).
No quest ids, rewards, events, progress, save data or gates changed.

## 2. Windows
All seven menu views stay `UiWindow` + `UiTheme`; no menu was rebuilt.
- Titles / close buttons name their own key: Inventory `[I / Esc]` (also C, same window, Overview
  page), **Skills & Talents `[T / Esc]`** (was "Character - Class, Talents & Skills" / `[G / C / Esc]`;
  at a class station: "Class Station" `[G / Esc]`), Professions `[P / Esc]`, Journal `[J / Esc]`,
  Map `[M / Esc]`, Options `[O / Esc]`.
- Tabbed windows (Journal, Map, Options) keep their largest page size while open
  (`UiWindow.keep_size_while_open`): switching tabs no longer makes the window jump.
- Focus frame: follows the selected tab (`UiTabs.select`); on opening, a selected choice in a
  toggle group (e.g. the current UI scale) takes the focus, not the first unselected option.
- Empty states: every journal page explains itself ("No side quests in progress ...").

## 3. Input & navigation
I C T P J M O unchanged; icon = key; same key closes; Esc closes; one window at a time
(tested for all seven). UI-Paket 1 input safety stays (HUD presses never attack; holds released
when a window opens). New: the HUD step-back is applied the moment a window opens/closes, and the
combat bar fades (layout kept) instead of hiding - a click right after closing lands on the real
slot, never on the playfield.

## 4. Map window
Function unchanged. Area tab: a real legend with the glyphs as drawn (You, Exit, Waystone, Silent
waystone, Resting place, Person, Landmark, Current goal, Explored, Unexplored) replaces the
sentence; labels at the picture's edge flip/clamp inside (were cut off). Region: unchanged since
UI-Paket 2 (no horizontal scrollbar; legend scrolls vertically at 150 %).

## 5. HUD while a window is open
Steps back: minimap/tracker column (content is in Map/Journal) and combat bar (nothing can be cast
while input is blocked). Stays: player frame (health - the world is not paused), target frame,
menu bar (navigation, lit icon), toasts, loot feed, save indicator. Dialogue rules unchanged
(bottom column and menu bar step back, tracker stays). Pause behaviour unchanged (open point).

## 6. Design system additions (`UiTheme`)
State tokens `STATE_HOVER_BORDER`, `STATE_SELECTED_BORDER/FILL`, `STATE_DISABLED_TEXT`,
`STATE_LOCKED_BORDER`; map tokens `MAP_EXIT/WAYSTONE/WAYSTONE_SILENT/REST/NPC/LANDMARK/GOAL/PLAYER`
(no more colour literals in `MapPainter`); sizes `BORDER_THIN` 1, `BORDER` 2, `BORDER_THICK` 3,
`SLOT_PADDING` 5, `ICON_SIZE` 40, `HUD_SLOT_SIZE` 64, `MENU_ICON_SIZE` 40. Rarity stays colour +
pips (`UiTheme.RARITY`). Meaning per colour: bronze = selected/active, dim bronze = hover,
resonance outline = keyboard focus, muted = disabled, lock mark = locked, WARNING = goals /
attention, SUCCESS = done / available reward, DANGER = destructive / errors.

## 7. Asset-ready components (`UiSkin`)
One hook, no data structure: asset id = path under `res://assets/ui/` without `.png`. Missing file
= procedural fallback (normal case today; no warning, no dependency).
- Theme styles (`UiTheme.SKINNED`): window, HUD/card/inset panels, tooltip, buttons (normal /
  primary), tabs, inventory slots, scrollbars → nine-patch `StyleBoxTexture` with `UiSkin.PATCH`
  border, content padding taken from the fallback (layout never moves). Window corner brackets are
  skipped when `window/panel` exists.
- `HudMenuBar` icons `menu/<id>`; `HudSlot` frame `hud/slot_frame(_disabled)`, cooldown
  `hud/cooldown`, icon `skills/<skill id>`, `items/hearth_flask`, `items/<potion id>`;
  `ItemIcon` `items/<item id>` (the existing `texture` field still wins);
  `MapPainter` `map/<kind>`, `map/waystone_silent`, `map/player` (turned to the facing).
- Rarity frames, key letters, counters, cooldown numbers stay code (text, never baked into art).

## 8. Measurements (real window, 1080p / 1440p / 4K × 100 / 125 / 150 %)
Canvas 1920×1080 / 1536×864 / 1280×720 - identical at every resolution. Journal (all pages):
796–806 px wide, 1009 / 832 / 688 px high, inside the canvas in all 36 combinations. Gallery
(inventory, tooltip, character, talents, professions, tooltip, journal, map, region, options):
270 layout checks OK.

## Tests
`tests/integration/test_ui_window_foundation.gd` (6). Adapted (layout assumptions only):
`test_world_ui` (empty class quests now under Class Quests), `test_gameplay_polish` (side quest
details on the Side Quests page), `test_class_ui` (title "Skills & Talents"),
`test_quest_turnin_mara_ui` (state compare ignores the fog: `_stand_at` teleports the player,
which explores - a UI-Paket 2 effect, not guidance).

## Open
- Pause while a window is open (playtest decision).
- The tracker lists class quests without their own caption (unchanged).
- Tall stable window on short journal pages (empty space instead of jumping).
