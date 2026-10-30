# UI Asset Catalog 1.0 - Dark Classic Pixel Art

Production list for the UI art. Style: dark, classic, atmospheric pixel art for a direct
orthographic 2D top-down game - clear, compact, high contrast, not overloaded. Palette anchors come
from `UiTheme` (neutral panels `#23262c/#30343b/#191b20` since UI Visual Consistency 1.0, bronze `#c5ad85/#7d6c52/#4a4134`, parchment
`#eadcb8`, resonance cyan `#78b8c5`, warning `#d9b46a`, success `#9cbf7e`, danger `#d27461`).
**Only original assets or graphics explicitly licensed for this project.**

## How the art gets in (no code change per asset)
- Drop a PNG at `res://assets/ui/<id>.png` (id column below). `UiSkin` finds it; without the file
  the current procedural look stays. Hook = where the game already reads the id today.
- Sizes are **design px** (1920×1080 canvas). Author at 1×; the canvas scales: 1080p ×1, 1440p
  ×1.33, 4K ×2, UI scale ×1 / 1.25 / 1.5. Import with filter **Nearest** (project default), no
  mipmaps. Keep 1-px details ≥ 2 px where they must survive 1.33× (1440p) - test there first.
- Nine-patch: the "9P" value is the border (px) that never stretches; the centre stretches. Keep
  centres flat or tileable noise. Padding/layout comes from the code - art must not need more
  border than its 9P value.
- Text, numbers, key letters, counters, cooldown seconds and rarity pips stay code: never bake text.
- States in one sheet are **not** supported: one file per state (ids below).

Priority: **P1** = needed for a coherent first art pass; **P2** = strong improvement;
**P3** = polish.

## A. Menu icons (bottom-left menu bar)
Component `HudMenuBar.MenuIcon` (frame 40×40 drawn by code: inset / elevated on hover, bronze
2-px border when active). Art is drawn centred at **32×32**, slightly dimmed when idle, full when
hovered/active - one file per icon covers all states.

| Id | Purpose | Art px | Alpha | Anim | Prio | Fallback |
|---|---|---|---|---|---|---|
| `menu/inventory` | Inventory (I) - bag | 32×32 | yes | no | P1 | line bag |
| `menu/character` | Character (C) - bust | 32×32 | yes | no | P1 | head + shoulders |
| `menu/skills` | Skills & Talents (T) - spark seal (entry id `talents`, icon id in `HudMenuBar.ENTRIES`) | 32×32 | yes | no | P1 | 3-node tree |
| `menu/professions` | Professions (P) - hammer | 32×32 | yes | no | P1 | hammer |
| `menu/journal` | Journal (J) - book | 32×32 | yes | no | P1 | book |
| `menu/map` | Map (M) - folded map | 32×32 | yes | no | P1 | folded map |
| `menu/settings` | Options (O) - cog | 32×32 | yes | no | P1 | cog |

## B. Combat HUD (bottom centre)
Component `HudSlot` 64×64 (quick use 1/2, skills Q E R F). Key letter top-left and status word
at the bottom are code; keep the top-left 14×14 and the bottom 20 px calm.

| Id | Purpose / states | Px | Alpha | 9P | Anim | Prio | Fallback |
|---|---|---|---|---|---|---|---|
| `hud/slot_frame` | slot ready / usable | 64×64 | yes | - | no | P1 | dark panel + bronze 2-px frame |
| `hud/slot_frame_disabled` | not usable (cooldown, no resource, empty, locked) | 64×64 | yes | - | no | P1 | elevated-grey frame |
| `hud/cooldown` | darkening, cut from the top by the remaining share | 60×60 | yes (≈55 % black) | - | no (cut in code) | P2 | flat 55 % black |
| `bar/frame` / `bar/fill` | every bar: HP, resource, target, poise, EXP (`HudXpBar` too), window bars - frame + groove / tint mask | 3×3 / 4×6 ✅ | yes | 1 / top+bottom 1, sides 0 | no | P1 | 1-px bronze frame / flat fill |
| `skills/<skill id>` | skill icon (combat bar 1:1, class station slot cards and skill rows), all 21 active skills of Warrior / Arcanist / Shadowrunner | 40×40 ✅ | yes | - | no | P1 | coloured circle + letter |
| `combos/<form>_<inputs>[_<effect>]` | Weapons tab combo icons (grid 2x, details 3x), one per combo action shared by the families (`ComboIcons.icon_id`), 44 files | 40×40 ✅ | yes | - | no | P1 | - |
| `items/hearth_flask` | Hearth Flask in slot 1 | 40×40 | yes | - | no | P1 | bottle glyph |
| `items/<potion id>` | potion in slot 2 (same file as the inventory icon) | 40×40 | yes | - | no | P1 | round flask |
| *(not hooked)* `hud/resource_*` | health / resource / dash bars of `PlayerFrame` | 9P strips | yes | 3 | maybe pulse | P3 | flat bars |
| *(not hooked)* `status/<status id>` | buff/debuff icons of `EffectBar` | 16×16 | yes | - | no | P3 | text chips |

Empty slot = `hud/slot_frame_disabled` + status word "Empty"; locked = same frame + status text
(state is never told by dimming alone).

## C. Windows
Theme styles (`UiTheme.SKINNED`) - every `UiWindow` and component picks them up.

| Id | Used by | States | Suggested px | 9P | Alpha | Prio | Fallback |
|---|---|---|---|---|---|---|---|
| `window/panel` | every window (frame incl. corners; replaces the code brackets) | - | 48×48 | 12 | edge only | P1 | flat panel, bronze frame, corner brackets |
| `panel/hud` | HUD panels (player frame, tracker, minimap frame, loot rows, prompts) | - | 24×24 | 6 | yes (≈78 % bg) | P1 | translucent dark |
| `panel/card` / `panel/card_selected` | cards (quests, recipes, classes) / current one | normal, selected | 24×24 | 6 | no | P2 | elevated green, bronze / cyan frame |
| `panel/inset` | recessed areas (completed cards, lists) | - | 16×16 | 4 | no | P2 | darker inset |
| `tooltip/panel` | all tooltips (item, talent, slot) | - | 24×24 | 6 | no | P1 | near-black, dim bronze |
| `button/normal` `hover` `pressed` `disabled` | standard buttons | 4 states | 24×24 each | 4 | no | P1 | flat |
| `button/primary_normal` `_hover` `_pressed` | primary action (Craft, Restore, Claim) | 3 states | 24×24 each | 4 | no | P2 | bronze-framed |
| `tab/normal` `tab/hover` `tab/selected` | UiTabs (journal, map, options, inventory) | 3 states | 24×24 each | 4 | yes | P1 | underline tabs |
| `scroll/grabber` `scroll/track` | all scrollbars, vertical and horizontal (one image each) | grabber (hover / drag = tint), track | 10×10 / 10×10 ✅ | 3 | grabber chamfer | P2 | rounded bronze bar |
| `input/normal` `input/focus` `input/disabled` | LineEdit (recipe search, preset name) - normal, focus, read_only | 3 states | 24×24 each ✅ | 4 | chamfer | P2 | inset box, resonance focus border |
| `dropdown/arrow` `dropdown/radio_on|off|off_disabled` | OptionButton arrow, its list's radio marks | 4 | 12×12 / 16×16 ✅ | - | yes | P2 | Godot default icons |
| `check/on|off|on_disabled|off_disabled` | CheckButton / CheckBox / PopupMenu checks | 4 | 16×16 ✅ | - | yes | P2 | Godot default switch |
| `slider/fill` `slider/grabber|grabber_hover|grabber_disabled` | HSlider fill (9P 3) and handle | 4 | 10×10 / 16×16 ✅ | 3 / - | handle | P2 | flat fill, default round grabber |
| `chip/key` | KeyChip (key hints) | - | 12×12 ✅ | 3 | chamfer | P2 | elevated box, bronze border |
| `booktab/normal` `hover` `selected` | BookTabs (page registers of Class Station, Professions) | 3 | 24×24 ✅ | 4 | left corners cut, right open | P2 | flat leather registers |
| *(code)* section rule, title rule | headings | - | - | - | - | - | thin bronze line (keep) |

Header = window title text + rule (code); a decorative header ornament can be part of
`window/panel`'s top edge. Close is a normal button.

## D. Inventory / items
| Id | Purpose | States | Px | 9P | Alpha | Prio | Fallback |
|---|---|---|---|---|---|---|---|
| `slot/normal` `slot/hover` `slot/selected` `slot/disabled` | inventory / equipment / stash slot (`InventorySlot` buttons) | 4 | 24×24 each | 4 | no | P1 | dark inset, bronze frame |
| `items/<item id>` | item icon, e.g. `items/iron_sword` (bag, paper doll, tooltips, HUD slot 2) | one | 30×30 visible (drawn into the 40×40 cell inset 5 px) | - | yes | P1 for starting gear, potions, materials of Region 1; P2 rest | glyph by slot kind |
| *(code)* rarity frame | colour **and** 0-4 pips along the bottom edge (`UiTheme.RARITY`) | 7 rarities | - | - | - | - | keep in code (accessible) |
| *(not hooked)* `category/<all/equipment/materials/consumables/quest>` | bag filter tabs | - | 16×16 | - | yes | P3 | text tabs |

Keep the icon's bottom 6 px and top-right 10×10 calm: rarity pips, equipped marker, favourite /
lock marks and stack counts are drawn there.

## E. Map (minimap 200×200 / 168×168 at 150 %, area map up to 900×540)
| Id | Purpose | States | Px | Alpha | Anim | Prio | Fallback |
|---|---|---|---|---|---|---|---|
| `map/player` | player arrow, drawn **pointing up**, turned to the facing in 90° steps | - | 16×16 ✅ (drawn 1:1 everywhere) | yes | no | P1 | cyan triangle |
| `map/exit` | known exit | - | 16×16 ✅ | yes | no | P1 | purple diamond |
| `map/waystone` / `map/waystone_silent` | awake / silent waystone | 2 files | 16×16 ✅ | yes | no | P1 | cyan / grey bar |
| `map/rest` | resting place (fire) | - | 16×16 ✅ | yes | maybe flicker (P3) | P2 | orange dot |
| `map/npc` | person | - | 16×16 ✅ | yes | no | P2 | green dot |
| `map/landmark` | named landmark | - | 16×16 ✅ | yes | no | P2 | bronze square |
| `map/quest` | current goal (the gold goal ring is still drawn by code around any marker) | - | 16×16 ✅ | yes | no | P1 | gold ring |
| `hud/minimap_frame` *(id reserved, not hooked)* | ornament around the minimap | - | 24×24 | 6 | yes | P3 | `panel/hud` |
| Fog | unexplored = `MapFog.DARK`, explored = picture under 32 % black | - | code | - | - | - | keep in code (per-cell image) |
| Map picture | floor / side path / road / wall classes, 1 px = 8 world px | - | code | - | - | - | keep in code |

## F. Feedback
All feedback panels use `panel/hud`; the items below are small accents for later hooks.

| Id | Purpose | Px | Alpha | Anim | Prio | Hook / fallback |
|---|---|---|---|---|---|---|
| `items/<id>` | loot feed row icon (same item icons) | 30×30 | yes | slide-in in code | P1 (via D) | already via ItemIcon |
| `feedback/toast` *(not hooked)* | toast accent (quest updated, crafted ...) | 16×16 | yes | no | P3 | text |
| `feedback/quest_complete` *(not hooked)* | quest completed toast / journal | 24×24 | yes | short shine (P3) | P2 | text + SUCCESS colour |
| `feedback/reward` *(not hooked)* | "reward available" (tracker, NPC) | 16×16 | yes | soft pulse (P3) | P2 | "?" marker + SUCCESS text |
| `feedback/save` *(not hooked)* | save indicator | 16×16 | yes | spin / quill (P3) | P2 | text "Saving..." |
| `feedback/error` *(not hooked)* | error / warning toast | 16×16 | yes | no | P3 | DANGER / WARNING text |

"Not hooked" = no code reads the id yet; adding the hook is a one-line `UiSkin.texture(...)` in
that component when the art exists (deliberately not built ahead).

## Prerequisites for the pixel-art production
1. Decide the pixel grid: 1 art px = 1 design px (recommended) - then 4K shows each pixel as 2×2,
   1440p as 1.33 (check readability there).
2. Font: decided (UI Font Integration 1.0) - IBM Plex Mono Regular (text) + Silkscreen (headings);
   see `docs/UI_FONT_INTEGRATION_1_0.md`.
3. Produce P1 first: window/panel, tooltip, buttons, tabs, slots, HUD slot frames, 7 menu icons,
   skill icons of the three classes, Region-1 item icons, map player/exit/waystone/goal.
4. Check each batch with `ui_gallery.gd` at `--res=1920x1080,2560x1440,3840x2160 --scale=1.0,1.25,1.5`.
