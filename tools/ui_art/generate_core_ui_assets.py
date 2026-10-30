"""Core UI Asset Prototype 1.0 - reproducible generator of the UI PNGs (eight at first, now 35 with
UI Scrollbars & Input Fields 1.0: scroll/track, scroll/grabber, input/normal|focus|disabled; 48 with
Secondary Controls 1.0: dropdown/*, check/*, slider/*, chip/key; 51 with BookTabs Visual Integration 1.0:
booktab/normal|hover|selected; 53 with HUD Bars Visual Integration 1.0: bar/frame, bar/fill; 61 with Map Markers Pixel Art 1.0: map/player|exit|waystone|waystone_silent|rest|npc|landmark|quest; 82 with Skill Icons Pixel Art 1.0: skills/<id>; 126 with Skills & Talents UX 2.0 Phase 1: combos/<action>; 128 with Menu UX Polish 1.0: window/backdrop,
window/page; 136 with Combat HUD UX 2.0: hud/vessel_*, hud/vessel_fill_*, hud/flask[_fill], hud/potion[_fill]).

Dark Classic pixel art: hard pixels, ~2 px contours, light from the top left, one universal style.
Frames are built from a cross-section profile (colour by distance to the nearest edge), so every
nine-patch edge is uniform along its length by construction and the centre is flat; ornaments live
only inside the corner squares. Icons are drawn as shapes, then outlined and shaded by rule.

    py -3 tools/ui_art/generate_core_ui_assets.py            # writes missing files only
    py -3 tools/ui_art/generate_core_ui_assets.py --force    # replaces the eight files
    py -3 tools/ui_art/generate_core_ui_assets.py --preview DIR   # also 8x preview sheets

Ids, sizes and nine-patch borders: docs/UI_ASSET_CATALOG_1_0.md, scripts/ui/ui_skin.gd (PATCH).
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "ui"

T = (0, 0, 0, 0)


def rgb(hex_code: str, alpha: int = 255) -> tuple[int, int, int, int]:
    hex_code = hex_code.lstrip("#")
    return (int(hex_code[0:2], 16), int(hex_code[2:4], 16), int(hex_code[4:6], 16), alpha)


# Working palette (task) and the few derived shades the frames and icons need.
CHARCOAL = rgb("191B20")
SLATE = rgb("30343B")
STEEL = rgb("777C83")
PARCHMENT = rgb("C7BDAA")
OLD_GOLD = rgb("B39A70")
INK = rgb("0E0F12")          # outline, darker than charcoal
PLATE = rgb("111216")        # key plate of the HUD slot
SLATE_LIGHT = rgb("3A3F47")
SLATE_DARK = rgb("24272D")
STEEL_LIGHT = rgb("8E939A")
STEEL_DARK = rgb("50555C")
GOLD_LIGHT = rgb("CDB68A")
GOLD_DARK = rgb("7A6748")
PARCHMENT_DARK = rgb("9C9384")
PARCHMENT_LIGHT = rgb("DAD1BF")
HOVER_FILL = rgb("383C44")
HOVER_BEVEL = rgb("454A53")
HOVER_SHADOW = rgb("2B2E35")
HUD_FILL = rgb("191B20", 232)  # the one intended partial alpha: HUD slot interior over the world
# UI Panels & Primary Controls 1.0
BG_DEEP = rgb("16181C")         # = UiTheme.BG: tooltip ground
HUD_PANEL_FILL = rgb("16181C", 200)   # HUD panels over the world (~78 % like the procedural HudPanel)
WARM_FILL = rgb("3B372F")       # primary action fill (= UiTheme.COLOR_BUTTON_PRESSED, bronze-leaning)
WARM_HOVER = rgb("46413A")
WARM_PRESSED = rgb("2E2B25")
BRONZE_DARK = rgb("4A4134")     # = UiTheme.BRONZE_DARK: the faint rim of a disabled primary action
# UI Scrollbars & Input Fields 1.0: keyboard focus speaks the theme's resonance (never gold = selection)
FOCUS_LIGHT = rgb("78B8C5")     # = UiTheme.RESONANCE (COLOR_FOCUS)
FOCUS_DARK = rgb("4D7A83")      # = UiTheme.RESONANCE_DIM
# Menu UX Polish 1.0: the main-window ground - a quiet grain on the window tone (luma 31), lit and sunk pixels
# only a few steps away (37 / 27), so it reads as surface, never as noise behind text.
WINDOW_GROUND = rgb("1D1F24")   # = UiTheme.COLOR_WINDOW
WINDOW_GRAIN = rgb("23262C")    # = UiTheme.PANEL

PALETTE = {CHARCOAL, SLATE, STEEL, PARCHMENT, OLD_GOLD, INK, PLATE, SLATE_LIGHT, SLATE_DARK, STEEL_LIGHT,
           STEEL_DARK, GOLD_LIGHT, GOLD_DARK, PARCHMENT_DARK, PARCHMENT_LIGHT, HOVER_FILL, HOVER_BEVEL, HOVER_SHADOW,
           HUD_FILL, BG_DEEP, HUD_PANEL_FILL, WARM_FILL, WARM_HOVER, WARM_PRESSED, BRONZE_DARK, FOCUS_LIGHT, FOCUS_DARK,
           WINDOW_GROUND, WINDOW_GRAIN,   # Menu UX Polish 1.0
           # Map Markers Pixel Art 1.0: the map's meaning colours (UiTheme.MAP_*) and their shades
           rgb("A680FF"), rgb("6E50B0"), rgb("FF8C26"), rgb("9CBF7E"), rgb("6F8C58"), rgb("C5AD85"), rgb("D9B46A"), rgb("9C7E44"),
           # Skill Icons Pixel Art 1.0: the skills' own accent colours (SkillDefinition.color) and their shades
           *[rgb(code) for code in ("DB4C38", "8E2A20", "FFA64D", "B36A26", "CC1F33", "7A1220", "FF4D1A", "E6BF66", "B880FF",
                                    "6E48B0", "DCC2FF", "F2E68C", "B0A050", "99E6FF", "4A8CB0", "9E80E6", "5A4690", "F05A66",
                                    "9A2E38", "8C8C9E", "5C5C6A", "FFD959", "B39433")],
           rgb("8A6A44"), rgb("5E4630")}   # Skills & Talents UX 2.0: bow wood (combo icons)


# --- frames ---------------------------------------------------------------------------------------

def profile_frame(size: int, profile: list[tuple], fill: tuple, chamfer: int = 0) -> Image.Image:
    """profile[d] = (top/left colour, bottom/right colour) at distance d from the nearest edge."""
    image = Image.new("RGBA", (size, size), T)
    last = size - 1
    for y in range(size):
        for x in range(size):
            distances = {"top": y, "left": x, "bottom": last - y, "right": last - x}
            side = min(distances, key=lambda k: (distances[k], k in ("bottom", "right")))
            d = distances[side]
            if d < len(profile):
                light, dark = profile[d]
                colour = light if side in ("top", "left") else dark
            else:
                colour = fill
            image.putpixel((x, y), colour)
    if chamfer:
        cut_corners(image, chamfer)
    return image


def cut_corners(image: Image.Image, chamfer: int) -> None:
    """Transparent stair at the four outer corners; the outline follows the cut."""
    w, h = image.size
    for cx, cy, sx, sy in ((0, 0, 1, 1), (w - 1, 0, -1, 1), (0, h - 1, 1, -1), (w - 1, h - 1, -1, -1)):
        for i in range(chamfer):
            for j in range(chamfer - i):
                image.putpixel((cx + sx * i, cy + sy * j), T)
        for i in range(chamfer + 1):   # re-close the outline along the diagonal
            image.putpixel((cx + sx * i, cy + sy * (chamfer - i)), INK)


def window_panel() -> Image.Image:
    """48 x 48, nine-patch 12: ink outline, bevelled steel band, ink, 1 px gold line, ink, slate mat,
    flat charcoal centre; gold corner brackets with a stud inside the 12 px corners."""
    profile = [(INK, INK), (INK, INK), (STEEL_LIGHT, STEEL), (STEEL, STEEL_DARK), (INK, INK),
               (OLD_GOLD, GOLD_DARK), (INK, INK), (SLATE, SLATE), (SLATE_DARK, SLATE_DARK)]
    image = profile_frame(48, profile, CHARCOAL, chamfer=2)
    for flip_x in (False, True):
        for flip_y in (False, True):
            corner_bracket(image, flip_x, flip_y)
    return image


def corner_bracket(image: Image.Image, flip_x: bool, flip_y: bool) -> None:
    w, h = image.size

    def put(x: int, y: int, colour: tuple) -> None:
        image.putpixel((w - 1 - x if flip_x else x, h - 1 - y if flip_y else y), colour)

    # an L of gold over the steel band (rows/cols 2..3), 10 px long, closed by ink at its ends
    for i in range(2, 11):
        top = GOLD_LIGHT if not flip_y else OLD_GOLD
        left = GOLD_LIGHT if not flip_x else OLD_GOLD
        put(i, 2, top)
        put(i, 3, GOLD_DARK)
        put(2, i, left)
        put(3, i, GOLD_DARK)
    put(11, 2, INK)
    put(11, 3, INK)
    put(2, 11, INK)
    put(3, 11, INK)
    put(2, 2, GOLD_LIGHT)
    # a 3 x 3 stud in the corner of the mat (cols/rows 7..9), ink ring
    for y in range(6, 11):
        for x in range(6, 11):
            put(x, y, INK)
    for y in range(7, 10):
        for x in range(7, 10):
            put(x, y, OLD_GOLD)
    put(7, 7, GOLD_LIGHT)
    put(9, 9, GOLD_DARK)


## Button states (24 x 24, nine-patch 4, identical geometry): ink, rim, bevel, flat fill.
## pressed: the bevel inverted (dark top/left, light bottom/right) and a bronze rim - pressed and
## toggled-on buttons share the theme's "selected = bronze"; disabled: flat, dim steel rim.
BUTTON_STATES = {
    "normal": ([(INK, INK), (STEEL, STEEL_DARK), (SLATE_LIGHT, SLATE_DARK)], SLATE),
    "hover": ([(INK, INK), (STEEL_LIGHT, STEEL), (HOVER_BEVEL, HOVER_SHADOW)], HOVER_FILL),
    "pressed": ([(INK, INK), (GOLD_DARK, OLD_GOLD), (SLATE_DARK, SLATE_LIGHT)], HOVER_SHADOW),
    "disabled": ([(INK, INK), (STEEL_DARK, STEEL_DARK), (SLATE_DARK, SLATE_DARK)], SLATE_DARK),
}


def button(state: str) -> Image.Image:
    profile, fill = BUTTON_STATES[state]
    return profile_frame(24, profile, fill, chamfer=1)


## Slot states (24 x 24, nine-patch 4, identical geometry): a recessed well - ink, rim, inner
## shadow, flat fill. The item icon covers the centre, so every state lives in the 6 px ring.
## selected: 2 px old-gold rim; hover: a brighter steel rim and a slightly lighter well (never
## gold - selected stays unmistakable); disabled: the rim sinks into the dark, a darker well.
SLOT_STATES = {
    "normal": ([(INK, INK), (STEEL_DARK, STEEL_DARK), (INK, SLATE_DARK)], CHARCOAL),
    "selected": ([(INK, INK), (GOLD_LIGHT, OLD_GOLD), (OLD_GOLD, GOLD_DARK)], CHARCOAL),
    "hover": ([(INK, INK), (STEEL, STEEL_DARK), (INK, SLATE_DARK)], SLATE_DARK),
    "disabled": ([(INK, INK), (SLATE_DARK, SLATE_DARK), (INK, INK)], PLATE),
}


def slot(state: str) -> Image.Image:
    profile, fill = SLOT_STATES[state]
    return profile_frame(24, profile, fill, chamfer=1)


## Tab states (24 x 24, nine-patch 4, identical geometry): a plate with cut top corners, a 3 px
## underline (rows 20-22) on the window rule - 3 px so at least one row survives the 0.75 UI scale
## (a 2 px line vanished there). hover: lighter plate, steel underline; selected: the lightest plate
## and an old-gold underline (the label turns bronze through the theme).
TAB_STATES = {
    "normal": ([(INK, INK), (SLATE, SLATE_DARK)], SLATE_DARK, (STEEL_DARK, STEEL_DARK, STEEL_DARK)),
    "hover": ([(INK, INK), (SLATE_LIGHT, SLATE_DARK)], SLATE, (STEEL, STEEL, STEEL_DARK)),
    "selected": ([(INK, INK), (HOVER_BEVEL, HOVER_SHADOW)], HOVER_FILL, (GOLD_LIGHT, OLD_GOLD, GOLD_DARK)),
}


def tab(state: str) -> Image.Image:
    profile, fill, underline = TAB_STATES[state]
    image = profile_frame(24, profile, fill)
    for x in range(1, 23):
        for row, colour in zip((20, 21, 22), underline):
            image.putpixel((x, row), colour)
    for corner in ((0, 0), (23, 0)):   # cut top corners; the bottom stands square on the rule
        image.putpixel(corner, T)
    return image


## Primary action (24 x 24, nine-patch 4, identical geometry): a double gold frame on a warm fill
## with a raised bevel - never confused with a pressed standard button (single bronze rim, dark
## fill, inverted bevel). hover: the gold lights up; pressed: bevel inverted, darker warm fill;
## disabled: a faint bronze trace on slate - still the "main action", clearly inactive.
PRIMARY_STATES = {
    "normal": ([(INK, INK), (GOLD_LIGHT, OLD_GOLD), (GOLD_DARK, GOLD_DARK)], WARM_FILL),
    "hover": ([(INK, INK), (GOLD_LIGHT, GOLD_LIGHT), (OLD_GOLD, GOLD_DARK)], WARM_HOVER),
    "pressed": ([(INK, INK), (GOLD_DARK, OLD_GOLD), (INK, GOLD_DARK)], WARM_PRESSED),
    "disabled": ([(INK, INK), (BRONZE_DARK, BRONZE_DARK), (SLATE_DARK, SLATE_DARK)], SLATE_DARK),
}


def primary_button(state: str) -> Image.Image:
    profile, fill = PRIMARY_STATES[state]
    return profile_frame(24, profile, fill, chamfer=1)


def corner_ticks(image: Image.Image, colour: tuple, depth: int = 1, length: int = 3) -> None:
    """A small L of `colour` on ring `depth` in each corner - the sparse ornament of the panels,
    kept inside the corner squares so no stretched edge carries it."""
    w, h = image.size
    for flip_x in (False, True):
        for flip_y in (False, True):
            for i in range(depth, depth + length):
                for x, y in ((i, depth), (depth, i)):
                    image.putpixel((w - 1 - x if flip_x else x, h - 1 - y if flip_y else y), colour)


def panel_hud() -> Image.Image:
    """24 x 24, nine-patch 6: a thin ink line and a dark steel rim around a see-through deep fill
    (HUD panels over the world); dark-gold corner ticks."""
    image = profile_frame(24, [(INK, INK), (STEEL_DARK, SLATE_DARK)], HUD_PANEL_FILL, chamfer=1)
    corner_ticks(image, GOLD_DARK)
    return image


def panel_card(selected: bool) -> Image.Image:
    """24 x 24, nine-patch 6, identical geometry: ink, rim, inner light, flat dark slate. Selected: the
    rim turns old gold over a dark-gold inner line, light corner ticks - a clear, quiet selection."""
    if selected:
        profile = [(INK, INK), (GOLD_LIGHT, OLD_GOLD), (GOLD_DARK, GOLD_DARK)]
        ticks = GOLD_LIGHT
    else:
        profile = [(INK, INK), (STEEL_DARK, STEEL_DARK), (SLATE, SLATE_DARK)]
        ticks = GOLD_DARK
    image = profile_frame(24, profile, SLATE_DARK, chamfer=1)
    corner_ticks(image, ticks)
    return image


def panel_inset() -> Image.Image:
    """16 x 16, nine-patch 4: a recessed well - dark top/left, a lit lower lip, flat charcoal."""
    return profile_frame(16, [(INK, SLATE_LIGHT), (PLATE, SLATE_DARK)], CHARCOAL, chamfer=1)


def tooltip_panel() -> Image.Image:
    """24 x 24, nine-patch 6: a quiet frame (ink, dim steel) around the deepest ground - highest text
    contrast; tiny dark-gold corner ticks only."""
    image = profile_frame(24, [(INK, INK), (STEEL_DARK, STEEL_DARK), (INK, INK)], BG_DEEP, chamfer=1)
    corner_ticks(image, GOLD_DARK)
    return image


def hud_slot_frame(disabled: bool = False) -> Image.Image:
    """64 x 64, drawn whole (no nine-patch): ink, bevelled steel, ink, a slightly see-through charcoal
    well; gold corner brackets; a darker key plate top left for the key letter (HudSlot label at 5, 1).
    Disabled: same geometry and key plate; the steel sinks to dark steel/slate, the brackets to dark
    gold - inactive at a glance, while the key letter and the (greyed) skill icon stay readable."""
    if disabled:
        profile = [(INK, INK), (STEEL_DARK, SLATE_LIGHT), (SLATE_LIGHT, SLATE_DARK), (INK, INK)]
        bracket_light, bracket_mid, bracket_dark = GOLD_DARK, GOLD_DARK, SLATE_DARK
    else:
        profile = [(INK, INK), (STEEL_LIGHT, STEEL), (STEEL, STEEL_DARK), (INK, INK)]
        bracket_light, bracket_mid, bracket_dark = GOLD_LIGHT, OLD_GOLD, GOLD_DARK
    image = profile_frame(64, profile, HUD_FILL, chamfer=2)
    w = 64
    for flip_x in (False, True):
        for flip_y in (False, True):
            for i in range(1, 7):
                for x, y in ((i, 1), (1, i)):
                    px = w - 1 - x if flip_x else x
                    py = w - 1 - y if flip_y else y
                    image.putpixel((px, py), bracket_light if not (flip_x or flip_y) else bracket_mid)
                for x, y in ((i, 2), (2, i)):
                    px = w - 1 - x if flip_x else x
                    py = w - 1 - y if flip_y else y
                    image.putpixel((px, py), bracket_dark)
            for x, y in ((7, 1), (7, 2), (1, 7), (2, 7)):
                image.putpixel((w - 1 - x if flip_x else x, w - 1 - y if flip_y else y), INK)
    # key plate (x 4..16, y 4..18) with a steel-dark lip right and below
    for y in range(4, 19):
        for x in range(4, 17):
            image.putpixel((x, y), PLATE)
    for y in range(4, 20):
        image.putpixel((17, y), STEEL_DARK)
    for x in range(4, 18):
        image.putpixel((x, 19), STEEL_DARK)
    return image


## UI Scrollbars & Input Fields 1.0. Scroll parts (10 x 10, nine-patch 3, point-symmetric rings, no
## ornament - the same image serves the vertical and the horizontal bar): the track is a quiet recessed
## groove (ink, dark lip, flat charcoal); the grabber a raised steel bar (ink, light top/left, dark
## bottom/right, flat steel) - the brightest thing in the bar, still a steel band at 0.75 UI scale.
def scroll_track() -> Image.Image:
    return profile_frame(10, [(INK, INK), (PLATE, SLATE_DARK), (CHARCOAL, CHARCOAL)], CHARCOAL)


def scroll_grabber() -> Image.Image:
    return profile_frame(10, [(INK, INK), (STEEL_LIGHT, STEEL_DARK), (STEEL, STEEL)], STEEL, chamfer=1)


## Input field states (24 x 24, nine-patch 4, identical geometry): a recessed writing well - ink, rim,
## inner shadow top/left, flat charcoal (parchment text and the resonance caret read best on it).
## focus: the rim turns resonance (keyboard focus everywhere, never gold); disabled: the rim sinks into
## the dark and the well darkens to the key-plate tone.
INPUT_STATES = {
    "normal": ([(INK, INK), (STEEL_DARK, STEEL_DARK), (PLATE, SLATE_DARK)], CHARCOAL),
    "focus": ([(INK, INK), (FOCUS_LIGHT, FOCUS_DARK), (PLATE, SLATE_DARK)], CHARCOAL),
    "disabled": ([(INK, INK), (SLATE_DARK, SLATE_DARK), (INK, INK)], PLATE),
}


def input_field(state: str) -> Image.Image:
    profile, fill = INPUT_STATES[state]
    return profile_frame(24, profile, fill, chamfer=1)


## Secondary Controls 1.0. Sizes are the theme slots Godot really draws (default theme: OptionButton
## `arrow` 12 x 12, PopupMenu `radio_*` 16 x 16, CheckBox / CheckButton `checked` 16 x 16 (CheckButton's
## own default is a 32 x 16 switch - the options use it as a check box), HSlider `grabber*` 16 x 16); icons
## are drawn 1:1 in design px. Gold = on / selected, steel = off, dim = disabled; focus stays the
## separate resonance outline of the button styles (never on the icons), so focus and "on" never mix.

def dropdown_arrow() -> Image.Image:
    """12 x 12: a 10 x 5 parchment chevron pointing down with an ink outline (solid at the 0.75 scale)."""
    image = Image.new("RGBA", (12, 12), T)
    body = set()
    for row, (x0, x1) in enumerate(((1, 10), (2, 9), (3, 8), (4, 7), (5, 6))):
        for x in range(x0, x1 + 1):
            body.add((x, 3 + row))
    for x, y in body:
        image.putpixel((x, y), PARCHMENT_DARK)
    for x in range(2, 10):
        image.putpixel((x, 3), PARCHMENT)   # lit top edge
    ink_ring(image, body)
    return image


def ink_ring(image: Image.Image, pixels: set) -> None:
    """A 1 px ink ring (4-neighbourhood) around `pixels`."""
    w, h = image.size
    for x, y in pixels:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in pixels and image.getpixel((nx, ny))[3] == 0:
                image.putpixel((nx, ny), INK)


def radio(on: bool, disabled: bool = False) -> Image.Image:
    """16 x 16: a round well (ink ring, steel rim, charcoal) - on: a gold 4 x 4 jewel in the middle."""
    image = Image.new("RGBA", (16, 16), T)
    ring = disk(8, 8, 6.0)
    rim = disk(8, 8, 5.0)
    well = disk(8, 8, 4.0)
    for x, y in ring:
        image.putpixel((x, y), INK)
    for x, y in rim:
        image.putpixel((x, y), SLATE_DARK if disabled else STEEL_DARK)
    for x, y in well:
        image.putpixel((x, y), PLATE if disabled else CHARCOAL)
    if on:
        for x, y in rect(6, 6, 9, 9) - {(6, 6), (9, 6), (6, 9), (9, 9)}:
            image.putpixel((x, y), GOLD_DARK if disabled else OLD_GOLD)
        if not disabled:
            image.putpixel((7, 6), GOLD_LIGHT)
            image.putpixel((6, 7), GOLD_LIGHT)
    return image


## The check mark: two strokes over 10 columns, 2 px thick everywhere (at the 0.75 UI scale still a
## solid mark of 7-8 screen px, never a dotted line).
CHECK_STROKE = [(3, 7), (4, 8), (5, 9), (6, 10), (7, 9), (8, 8), (9, 7), (10, 6), (11, 5), (12, 4)]


def check_box(on: bool, disabled: bool = False) -> Image.Image:
    """16 x 16: a square well like an inventory slot (ink, rim, inner shadow, charcoal); on: a gold
    check mark with an ink shadow. Disabled: the rim sinks into the dark, the mark turns dark gold."""
    rim = (SLATE_DARK, SLATE_DARK) if disabled else (STEEL, STEEL_DARK)
    well = PLATE if disabled else CHARCOAL
    image = profile_frame(16, [(INK, INK), rim], well, chamfer=1)
    if on:
        mark = set()
        for x, y in CHECK_STROKE:
            mark.add((x, y))
            mark.add((x, y + 1))
        for x, y in mark:
            if (x, y + 1) not in mark and y + 1 < 14 and image.getpixel((x, y + 1)) == well:
                image.putpixel((x, y + 1), INK)   # a hard 1 px drop shadow under the stroke
        for x, y in mark:
            image.putpixel((x, y), GOLD_DARK if disabled else OLD_GOLD)
        if not disabled:
            for x, y in CHECK_STROKE:
                image.putpixel((x, y), GOLD_LIGHT)   # lit upper edge of the stroke
    return image


def slider_fill() -> Image.Image:
    """10 x 10, nine-patch 3: the filled part of a slider - an old-gold bar (active value = gold)."""
    return profile_frame(10, [(INK, INK), (GOLD_LIGHT, GOLD_DARK), (OLD_GOLD, OLD_GOLD)], OLD_GOLD)


def slider_grabber(state: str) -> Image.Image:
    """16 x 16: an upright steel handle (8 px wide) with a grip line; hover / keyboard focus (Godot shows
    `grabber_highlight` for both): the steel lights up and the grip turns gold; disabled: dim slate."""
    image = Image.new("RGBA", (16, 16), T)
    light, dark, fill, grip = {
        "normal": (STEEL_LIGHT, STEEL_DARK, STEEL, INK),
        "hover": (PARCHMENT_LIGHT, STEEL, STEEL_LIGHT, OLD_GOLD),
        "disabled": (SLATE_LIGHT, SLATE_DARK, SLATE, SLATE_DARK),
    }[state]
    x0, x1, y0, y1 = 3, 12, 1, 14
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            edge = x in (x0, x1) or y in (y0, y1)
            if edge:
                colour = INK
            elif x == x0 + 1 or y == y0 + 1:
                colour = light
            elif x == x1 - 1 or y == y1 - 1:
                colour = dark
            else:
                colour = fill
            image.putpixel((x, y), colour)
    for corner in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
        image.putpixel(corner, T)   # cut corners
    for y in range(5, 11):
        image.putpixel((7, y), grip)
        image.putpixel((8, y), grip)
    return image


def key_chip() -> Image.Image:
    """12 x 12, nine-patch 3: a small key cap in the slot language - ink, steel rim lit on top, flat
    dark slate; the parchment key letter sits on it."""
    return profile_frame(12, [(INK, INK), (STEEL, STEEL_DARK), (SLATE, SLATE_DARK)], SLATE_DARK, chamfer=1)


## BookTabs Visual Integration 1.0: the page registers left of Class Station / Professions (BookTabs:
## 112 x 46, the selected one 122 x 46, its right end tucked 6 px under the window frame). 24 x 24,
## nine-patch 4, identical geometry; rings only on the left, top and bottom - the right side stays open
## towards the page. normal: dark slate; hover: lighter slate, steel rim; selected: the card language of a
## selection - an old-gold rim around the lightest fill. Keyboard focus stays the separate cyan outline.
REGISTER_STATES = {
    "normal": ([(INK, INK), (STEEL_DARK, SLATE_DARK), (SLATE, SLATE_DARK)], SLATE_DARK),
    "hover": ([(INK, INK), (STEEL, STEEL_DARK), (SLATE_LIGHT, SLATE_DARK)], SLATE),
    "selected": ([(INK, INK), (GOLD_LIGHT, GOLD_DARK), (OLD_GOLD, SLATE_DARK)], HOVER_FILL),
}


def book_register(state: str) -> Image.Image:
    profile, fill = REGISTER_STATES[state]
    size = 24
    image = Image.new("RGBA", (size, size), T)
    last = size - 1
    for y in range(size):
        for x in range(size):
            distances = {"top": y, "left": x, "bottom": last - y}   # no right edge: open to the page
            side = min(distances, key=lambda k: (distances[k], k == "bottom"))
            d = distances[side]
            if d < len(profile):
                light, dark = profile[d]
                colour = dark if side == "bottom" else light
            else:
                colour = fill
            image.putpixel((x, y), colour)
    for corner in ((0, 0), (0, last)):   # the outer (left) corners cut, the outline follows
        image.putpixel(corner, T)
    image.putpixel((1, 0), INK)
    image.putpixel((0, 1), INK)
    image.putpixel((1, last), INK)
    image.putpixel((0, last - 1), INK)
    return image


## HUD Bars Visual Integration 1.0. One frame and one fill for every bar (HP 18, resource 12, target 10,
## poise 5, EXP 14 and the small window bars 3-8 px high). bar/frame: 3 x 3, nine-patch 1 - a steel ring
## around a dark groove; 1 px rims work down to the 3 px bars. bar/fill: 4 x 6, nine-patch top 1 /
## bottom 1 / sides 0 - a neutral tint MASK (lit top row, body, shaded bottom row), multiplied with the
## bar's meaning colour (HP red, the class resource, EXP bronze ...). No side rims, so it can be drawn at
## any width from 1 px on: no squeezed corners and no minimum fill at 1 %.
BAR_RIM = STEEL_DARK
BAR_GROOVE = PLATE
MASK_LIGHT = rgb("FFFFFF")   # tint mask only (validator: the documented mask tones of bar/fill)
MASK_BODY = rgb("D8D8D8")    # = 0.847: UiTheme scales the tint by 1 / 0.847, so the body is the exact colour
MASK_SHADE = rgb("9C9C9C")


def bar_frame() -> Image.Image:
    image = profile_frame(3, [(BAR_RIM, BAR_RIM)], BAR_GROOVE)
    for corner in ((0, 0), (2, 0), (0, 2), (2, 2)):
        image.putpixel(corner, INK)   # ink corners: the ring reads slightly rounded, the outline closed
    return image


def bar_fill() -> Image.Image:
    image = Image.new("RGBA", (4, 6), MASK_BODY)
    for x in range(4):
        image.putpixel((x, 0), MASK_LIGHT)
        image.putpixel((x, 5), MASK_SHADE)
    return image


## Map Markers Pixel Art 1.0: the markers of minimap, area map and map legend (MapPainter), 16 x 16, drawn 1:1
## centred on the spot (texel 8, 8 = the spot). Flat silhouettes with a 1 px ink contour, the meaning colours the
## map already uses (UiTheme.MAP_*) plus a darker shade each; every kind its own shape, so they read without
## colour too. waystone / waystone_silent: one shape - the silent stone is dimmer and its rune is dark, not lit.
MAP_PLAYER_DARK = FOCUS_DARK
MAP_EXIT = rgb("A680FF")          # = UiTheme.MAP_EXIT
MAP_EXIT_DARK = rgb("6E50B0")
MAP_REST = rgb("FF8C26")          # = UiTheme.MAP_REST
MAP_NPC = rgb("9CBF7E")           # = UiTheme.MAP_NPC (SUCCESS)
MAP_NPC_DARK = rgb("6F8C58")
MAP_LANDMARK = rgb("C5AD85")      # = UiTheme.MAP_LANDMARK (BRONZE)
MAP_GOAL = rgb("D9B46A")          # = UiTheme.MAP_GOAL (WARNING)
MAP_GOAL_DARK = rgb("9C7E44")


def marker(parts: list[tuple], details: list[tuple] = ()) -> Image.Image:
    """parts: (colour, pixel set) filled in order; then a 1 px ink contour around them; then details."""
    image = Image.new("RGBA", (16, 16), T)
    body: set = set()
    for colour, pixels in parts:
        for x, y in pixels:
            if 0 <= x < 16 and 0 <= y < 16:
                image.putpixel((x, y), colour)
                body.add((x, y))
    ink_ring(image, body)
    for colour, pixels in details:
        for x, y in pixels:
            image.putpixel((x, y), colour)
    return image


def map_player() -> Image.Image:
    """An arrowhead pointing up (MapPainter turns it to the facing), notched at the back; the right half
    in the darker shade - light from the top left."""
    rows = {2: (7, 8), 3: (7, 8), 4: (6, 9), 5: (6, 9), 6: (5, 10), 7: (5, 10), 8: (4, 11), 9: (4, 11), 10: (3, 12)}
    head = {(x, y) for y, (x0, x1) in rows.items() for x in range(x0, x1 + 1)}
    legs = rect(3, 11, 5, 11) | rect(10, 11, 12, 11) | {(3, 12), (12, 12)}
    shape = head | legs
    left = {(x, y) for x, y in shape if x <= 7}
    return marker([(MAP_PLAYER_DARK, shape), (FOCUS_LIGHT, left)])


def map_exit() -> Image.Image:
    """A doorway: an arch with a dark passage open at the bottom."""
    arch = rect(3, 4, 12, 13) - {(3, 4), (12, 4)} | rect(5, 3, 10, 3)
    opening = rect(6, 7, 9, 13) - {(6, 7), (9, 7)}
    return marker([(MAP_EXIT, arch - opening)], [(INK, opening), (MAP_EXIT_DARK, rect(11, 5, 11, 13) | rect(10, 7, 10, 13))])


WAYSTONE_RUNE = [(7, 5), (8, 5), (8, 6), (7, 7), (8, 8), (7, 9), (8, 9), (7, 10)]


def map_waystone(silent: bool = False) -> Image.Image:
    """A standing rune stone on a low base; awake: a lit cyan rune, silent: dim stone, dark carved rune."""
    slab = rect(5, 2, 10, 12) - {(5, 2), (10, 2)}
    base = rect(4, 13, 11, 13)
    light, body, shade = (SLATE_LIGHT, SLATE, SLATE_DARK) if silent else (STEEL_LIGHT, STEEL, STEEL_DARK)
    rune = SLATE_DARK if silent else FOCUS_LIGHT
    details = [(light, rect(5, 3, 5, 12) | rect(6, 2, 9, 2)), (shade, rect(10, 3, 10, 12)), (rune, set(WAYSTONE_RUNE))]
    if not silent:
        details.append((PARCHMENT_LIGHT, {(8, 5)}))   # the rune's glint
    return marker([(body, slab), (SLATE_DARK, base)], details)


def map_rest() -> Image.Image:
    """A small fire: a flame (orange, gold core) over two crossed logs."""
    flame = disk(8, 9, 3.2) | rect(7, 3, 8, 5) | {(9, 4), (6, 5), (9, 5)}
    flame = {(x, y) for x, y in flame if y <= 11}
    logs = {(x, 13 - (x - 3) // 5) for x in range(3, 13)} | {(x, 12 + (x - 3) // 5) for x in range(3, 13)}
    core = disk(8, 9.5, 1.6)
    return marker([(GOLD_DARK, logs), (MAP_REST, flame)], [(GOLD_LIGHT, core), (PARCHMENT_LIGHT, {(8, 9)})])


def map_npc() -> Image.Image:
    """A person: a round head, a gap for the neck, broad low shoulders (wider than any stone or flame)."""
    head = disk(8, 5, 2.6)
    shoulders = rect(2, 10, 13, 13) - {(2, 10), (13, 10), (2, 11), (13, 11)} | rect(5, 9, 10, 9)
    return marker([(MAP_NPC, head | shoulders)], [(MAP_NPC_DARK, rect(11, 11, 12, 13) | rect(9, 9, 10, 9) | {(9, 6), (9, 5)})])


def map_landmark() -> Image.Image:
    """A banner on a pole on a small base - a fixed point to find your way by."""
    pole = rect(4, 2, 5, 12)
    banner = {(x, y) for y in range(3, 9) for x in range(6, 13) if x - 6 <= 6 - abs(y - 5.5) * 1.2}
    base = rect(3, 13, 7, 13)
    return marker([(STEEL, pole | base), (MAP_LANDMARK, banner)], [(STEEL_LIGHT, rect(4, 2, 4, 12)), (GOLD_DARK, {(x, 8) for x in range(6, 9)})])


def map_quest() -> Image.Image:
    """The current goal: a gold diamond with an ink exclamation mark."""
    diamond = {(x, y) for y in range(16) for x in range(16) if abs(x - 7.5) + abs(y - 7.5) <= 6.5}
    shade = {(x, y) for x, y in diamond if x >= 8 and y >= 8}
    return marker([(MAP_GOAL, diamond), (MAP_GOAL_DARK, shade)], [(INK, rect(7, 3, 8, 8) | rect(7, 10, 8, 11))])


## Skill Icons Pixel Art 1.0: one 40 x 40 icon per active skill of the three playable classes (the HUD combat slot
## draws skills/<id> 1:1 at 40 x 40). Hard pixels only (ImageDraw draws aliased), a 1 px ink contour around the
## silhouette, transparent ground. Each icon shows the skill's own action; the class speaks through its accents
## (= the skills' colours): Warrior steel + rage red / ember, Arcanist violet / starlight gold / frost,
## Shadowrunner shadow violet, blade steel, crimson.
SK_RED = rgb("DB4C38")
SK_RED_DARK = rgb("8E2A20")
SK_EMBER = rgb("FFA64D")
SK_EMBER_DARK = rgb("B36A26")
SK_BLOOD = rgb("CC1F33")
SK_BLOOD_DARK = rgb("7A1220")
SK_FURY = rgb("FF4D1A")
SK_GOLD = rgb("E6BF66")
SK_ARC = rgb("B880FF")
SK_ARC_DARK = rgb("6E48B0")
SK_ARC_LIGHT = rgb("DCC2FF")
SK_ASTRAL = rgb("F2E68C")
SK_ASTRAL_DARK = rgb("B0A050")
SK_FROST = rgb("99E6FF")
SK_FROST_DARK = rgb("4A8CB0")
SK_SHADOW = rgb("9E80E6")
SK_SHADOW_DARK = rgb("5A4690")
SK_CRIT = rgb("F05A66")
SK_CRIT_DARK = rgb("9A2E38")
SK_SMOKE = rgb("8C8C9E")
SK_SMOKE_DARK = rgb("5C5C6A")
SK_FOCUS = rgb("FFD959")
SK_FOCUS_DARK = rgb("B39433")
SKILL_COLOURS = [SK_RED, SK_RED_DARK, SK_EMBER, SK_EMBER_DARK, SK_BLOOD, SK_BLOOD_DARK, SK_FURY, SK_GOLD, SK_ARC, SK_ARC_DARK,
                 SK_ARC_LIGHT, SK_ASTRAL, SK_ASTRAL_DARK, SK_FROST, SK_FROST_DARK, SK_SHADOW, SK_SHADOW_DARK, SK_CRIT,
                 SK_CRIT_DARK, SK_SMOKE, SK_SMOKE_DARK, SK_FOCUS, SK_FOCUS_DARK]


def skill_canvas():
    from PIL import ImageDraw
    image = Image.new("RGBA", (40, 40), T)
    return image, ImageDraw.Draw(image)


def skill_finish(image: Image.Image) -> Image.Image:
    """The ink contour around everything drawn (4-neighbourhood), nothing on the outermost pixel row."""
    w, h = image.size
    for x in range(w):
        for y in (0, h - 1):
            image.putpixel((x, y), T)
    for y in range(h):
        for x in (0, w - 1):
            image.putpixel((x, y), T)
    body = {(x, y) for y in range(h) for x in range(w) if image.getpixel((x, y))[3] > 0}
    ink_ring(image, body)
    return image


def star_points(cx: float, cy: float, outer: float, inner: float, tips: int = 4, turn: float = 0.0) -> list:
    import math
    points = []
    for i in range(tips * 2):
        r = outer if i % 2 == 0 else inner
        a = math.pi * i / tips - math.pi / 2 + turn
        points.append((round(cx + r * math.cos(a)), round(cy + r * math.sin(a))))
    return points


# --- Warrior -------------------------------------------------------------------------------------

def skill_furious_strike() -> Image.Image:
    """A heavy forward cleave: a broad blade swung up-right inside a rage-red crescent of motion."""
    image, d = skill_canvas()
    d.arc([3, 3, 36, 36], 195, 345, fill=SK_RED, width=5)
    d.arc([5, 5, 34, 34], 200, 340, fill=SK_RED_DARK, width=1)
    d.polygon([(13, 27), (27, 10), (31, 8), (30, 12), (16, 29)], fill=STEEL)
    d.line([(14, 26), (28, 10)], fill=STEEL_LIGHT, width=1)
    d.line([(10, 23), (19, 32)], fill=GOLD_DARK, width=3)
    d.line([(6, 34), (11, 29)], fill=OLD_GOLD, width=3)
    return skill_finish(image)


def skill_battle_cry() -> Image.Image:
    """A roar: a curved war horn sounding, two rings of sound leaving its wide mouth."""
    image, d = skill_canvas()
    d.polygon([(3, 33), (6, 29), (11, 27), (16, 23), (19, 17), (20, 10), (27, 9), (27, 17), (24, 25), (18, 31), (10, 35), (5, 36)], fill=PARCHMENT)
    d.polygon([(20, 10), (27, 9), (27, 17), (22, 16)], fill=PARCHMENT_LIGHT)
    d.line([(10, 28), (13, 34)], fill=GOLD_DARK, width=2)
    d.line([(17, 22), (22, 27)], fill=GOLD_DARK, width=2)
    d.line([(20, 10), (27, 9)], fill=GOLD_DARK, width=2)
    d.arc([22, 5, 34, 21], 290, 430, fill=SK_EMBER, width=2)
    d.arc([22, 1, 38, 25], 300, 420, fill=SK_EMBER_DARK, width=2)
    return skill_finish(image)


def skill_blade_rush() -> Image.Image:
    """A charge: a sword driven forward (right), speed lines streaming behind its grip."""
    image, d = skill_canvas()
    d.rectangle([17, 18, 33, 21], fill=STEEL)
    d.line([(17, 18), (33, 18)], fill=STEEL_LIGHT)
    d.polygon([(33, 17), (37, 19), (37, 20), (33, 22)], fill=STEEL_LIGHT)
    d.rectangle([14, 13, 16, 26], fill=GOLD_DARK)
    d.rectangle([9, 18, 13, 21], fill=OLD_GOLD)
    for y, x0, x1 in ((9, 6, 20), (13, 2, 11), (26, 2, 11), (30, 6, 20)):
        d.line([(x0, y), (x1, y)], fill=PARCHMENT_DARK, width=2)
    return skill_finish(image)


def skill_warbreaker() -> Image.Image:
    """A crushing overhead slam: a war hammer coming down onto cracking ground."""
    image, d = skill_canvas()
    d.rectangle([9, 5, 30, 15], fill=STEEL)
    d.line([(9, 5), (30, 5)], fill=STEEL_LIGHT, width=2)
    d.rectangle([9, 14, 30, 15], fill=STEEL_DARK)
    d.rectangle([18, 16, 21, 27], fill=GOLD_DARK)
    d.line([(4, 34), (11, 31), (15, 35), (20, 30), (25, 35), (29, 31), (35, 34)], fill=SK_GOLD, width=2)
    d.line([(20, 30), (20, 36)], fill=SK_GOLD, width=2)
    return skill_finish(image)


def skill_whirlwind() -> Image.Image:
    """A spin: three curved blades chasing each other around the warrior, a red swirl inside."""
    image, d = skill_canvas()
    for start in (0, 120, 240):
        d.arc([3, 3, 36, 36], start, start + 80, fill=STEEL, width=4)
        d.arc([3, 3, 36, 36], start + 70, start + 80, fill=STEEL_LIGHT, width=4)
    for start in (60, 180, 300):
        d.arc([11, 11, 28, 28], start, start + 70, fill=SK_RED, width=3)
    d.ellipse([17, 17, 22, 22], fill=SK_RED_DARK)
    return skill_finish(image)


def skill_blood_frenzy() -> Image.Image:
    """A frenzy: a drop of blood torn by three claw marks."""
    image, d = skill_canvas()
    d.ellipse([9, 14, 31, 36], fill=SK_BLOOD)
    d.polygon([(20, 2), (10, 20), (30, 20)], fill=SK_BLOOD)
    d.ellipse([12, 18, 18, 24], fill=SK_RED)
    for dx in (-6, 0, 6):
        d.line([(14 + dx, 16), (24 + dx, 32)], fill=SK_BLOOD_DARK, width=2)
    d.line([(20, 4), (20, 9)], fill=SK_RED)
    return skill_finish(image)


def skill_unbound_fury() -> Image.Image:
    """The berserker capstone: a blaze bursting free of a broken chain."""
    image, d = skill_canvas()
    d.polygon([(20, 2), (25, 11), (31, 7), (32, 20), (29, 29), (20, 33), (11, 29), (8, 20), (9, 7), (15, 11)], fill=SK_FURY)
    d.polygon([(20, 12), (25, 21), (23, 29), (17, 29), (15, 21)], fill=SK_EMBER)
    d.polygon([(20, 19), (22, 25), (18, 25)], fill=PARCHMENT_LIGHT)
    for box in ([3, 30, 12, 37], [28, 30, 37, 37]):
        d.ellipse(box, outline=STEEL, width=2)
    return skill_finish(image)


# --- Arcanist ------------------------------------------------------------------------------------

def skill_arcane_bolt() -> Image.Image:
    """A quick bolt: a violet orb flying up-right with its tapering trail."""
    image, d = skill_canvas()
    d.polygon([(23, 13), (27, 17), (9, 35), (5, 31)], fill=SK_ARC_DARK)
    d.polygon([(24, 14), (26, 16), (13, 29), (11, 27)], fill=SK_ARC)
    d.ellipse([21, 5, 35, 19], fill=SK_ARC)
    d.ellipse([25, 8, 31, 14], fill=SK_ARC_LIGHT)
    d.point([(26, 9), (27, 9)], fill=PARCHMENT_LIGHT)
    return skill_finish(image)


def skill_mana_pulse() -> Image.Image:
    """A burst around you: a core of mana and two rings pushing outward."""
    image, d = skill_canvas()
    d.ellipse([3, 3, 36, 36], outline=SK_ARC, width=3)
    d.ellipse([10, 10, 29, 29], outline=SK_ARC_LIGHT, width=2)
    d.ellipse([16, 16, 23, 23], fill=SK_ARC_LIGHT)
    d.point([(18, 18)], fill=PARCHMENT_LIGHT)
    return skill_finish(image)


def skill_frostbind() -> Image.Image:
    """A shard of binding frost: a long ice crystal with two chips flying off."""
    image, d = skill_canvas()
    d.polygon([(20, 2), (28, 15), (20, 37), (12, 15)], fill=SK_FROST)
    d.polygon([(20, 2), (28, 15), (20, 37)], fill=SK_FROST_DARK)
    d.line([(20, 4), (14, 15)], fill=PARCHMENT_LIGHT)
    d.polygon([(6, 8), (9, 11), (6, 14), (3, 11)], fill=SK_FROST)
    d.polygon([(33, 24), (36, 27), (33, 30), (30, 27)], fill=SK_FROST)
    return skill_finish(image)


def skill_rune_sigil() -> Image.Image:
    """An inscribed sigil: a rune diamond on the ground, a glyph burning in its heart."""
    image, d = skill_canvas()
    d.polygon([(20, 2), (37, 19), (20, 36), (3, 19)], outline=SK_ARC, width=3)
    d.line([(20, 10), (20, 28)], fill=SK_ARC_LIGHT, width=2)
    d.line([(14, 14), (26, 24)], fill=SK_ARC_LIGHT, width=2)
    d.line([(26, 14), (14, 24)], fill=SK_ARC_LIGHT, width=2)
    d.ellipse([18, 17, 22, 21], fill=PARCHMENT_LIGHT)
    return skill_finish(image)


def skill_arcane_rift() -> Image.Image:
    """A torn rift: a jagged tear in the air, its glowing slit pulsing."""
    image, d = skill_canvas()
    d.polygon([(20, 2), (26, 9), (24, 15), (29, 21), (25, 29), (20, 37), (15, 29), (11, 21), (16, 15), (14, 9)], fill=SK_ARC_DARK)
    d.polygon([(20, 7), (22, 14), (21, 20), (23, 26), (20, 32), (18, 26), (19, 20), (17, 14)], fill=SK_ARC_LIGHT)
    for x, y in ((6, 12), (33, 15), (7, 28), (32, 30)):
        d.rectangle([x, y, x + 1, y + 1], fill=SK_ARC)
    return skill_finish(image)


def skill_astral_lance() -> Image.Image:
    """A piercing lance of starlight: a long beam up-right ending in a four-pointed star."""
    image, d = skill_canvas()
    d.line([(5, 35), (26, 14)], fill=SK_ASTRAL_DARK, width=5)
    d.line([(6, 33), (26, 13)], fill=SK_ASTRAL, width=2)
    d.polygon(star_points(29, 11, 9, 3), fill=SK_ASTRAL)
    d.polygon(star_points(29, 11, 4, 1), fill=PARCHMENT_LIGHT)
    return skill_finish(image)


def skill_astral_ascension() -> Image.Image:
    """The astral capstone: a great star rising out of a crescent."""
    image, d = skill_canvas()
    d.arc([5, 15, 35, 39], 20, 160, fill=SK_ASTRAL_DARK, width=4)
    d.polygon(star_points(20, 14, 12, 4, tips=8), fill=SK_ASTRAL)
    d.polygon(star_points(20, 14, 6, 2), fill=PARCHMENT_LIGHT)
    d.polygon([(20, 30), (24, 34), (16, 34)], fill=SK_ASTRAL)
    return skill_finish(image)


# --- Shadowrunner --------------------------------------------------------------------------------

def skill_shadow_strike() -> Image.Image:
    """A lunging slash: a curved shadow cut sweeping right, the dagger that drew it."""
    image, d = skill_canvas()
    d.chord([4, 3, 37, 37], 270, 90, fill=SK_SHADOW)
    d.chord([0, 6, 30, 34], 270, 90, fill=T)
    d.pieslice([4, 3, 37, 37], 280, 300, fill=SK_SHADOW_DARK)
    d.polygon([(7, 30), (17, 20), (19, 22), (9, 32)], fill=STEEL)
    d.line([(8, 30), (17, 21)], fill=STEEL_LIGHT)
    d.rectangle([4, 32, 7, 35], fill=SK_SHADOW_DARK)
    return skill_finish(image)


def skill_expose_weakness() -> Image.Image:
    """A probing look that finds the weak point: an eye with a golden iris inside four aiming ticks."""
    image, d = skill_canvas()
    d.polygon([(4, 20), (11, 13), (20, 11), (29, 13), (36, 20), (29, 27), (20, 29), (11, 27)], fill=PARCHMENT)
    d.ellipse([14, 14, 26, 26], fill=SK_FOCUS)
    d.ellipse([17, 17, 23, 23], fill=INK)
    d.point([(16, 16)], fill=PARCHMENT_LIGHT)
    for box in ([19, 2, 21, 7], [19, 33, 21, 37], [2, 19, 5, 21], [35, 19, 37, 21]):
        d.rectangle(box, fill=SK_FOCUS_DARK)
    return skill_finish(image)


def skill_shadowstep() -> Image.Image:
    """Stepping through shadow: three chevrons, the last one solid where you come out."""
    image, d = skill_canvas()
    for x0, colour in ((3, SK_SHADOW_DARK), (13, SK_SHADOW), (23, SK_ARC_LIGHT)):
        d.polygon([(x0, 6), (x0 + 6, 6), (x0 + 14, 20), (x0 + 6, 34), (x0, 34), (x0 + 8, 20)], fill=colour)
    return skill_finish(image)


def skill_execution() -> Image.Image:
    """A precise finishing blow: a dagger plunged straight down, a crimson drop at its point."""
    image, d = skill_canvas()
    d.polygon([(17, 13), (22, 13), (20, 33)], fill=STEEL)
    d.line([(18, 14), (20, 30)], fill=STEEL_LIGHT)
    d.rectangle([12, 10, 27, 12], fill=GOLD_DARK)
    d.rectangle([18, 3, 21, 9], fill=SK_SHADOW_DARK)
    d.rectangle([17, 2, 22, 3], fill=OLD_GOLD)
    d.ellipse([25, 27, 32, 36], fill=SK_CRIT)
    d.polygon([(28, 22), (25, 30), (32, 30)], fill=SK_CRIT)
    return skill_finish(image)


def skill_blade_fan() -> Image.Image:
    """A fan of five knives thrown from one hand."""
    import math
    image, d = skill_canvas()
    cx, cy = 20, 34
    for angle in (-62, -31, 0, 31, 62):
        a = math.radians(angle - 90)
        tip = (round(cx + 30 * math.cos(a)), round(cy + 30 * math.sin(a)))
        side = (math.cos(a + math.pi / 2), math.sin(a + math.pi / 2))
        base = (cx + 11 * math.cos(a), cy + 11 * math.sin(a))
        d.polygon([(round(base[0] + 2 * side[0]), round(base[1] + 2 * side[1])), tip,
                   (round(base[0] - 2 * side[0]), round(base[1] - 2 * side[1]))], fill=STEEL)
        d.line([(round(cx + 5 * math.cos(a)), round(cy + 5 * math.sin(a))), (round(base[0]), round(base[1]))], fill=SK_SHADOW_DARK, width=2)
    d.ellipse([17, 31, 23, 37], fill=SK_SHADOW_DARK)
    return skill_finish(image)


def skill_smoke_veil() -> Image.Image:
    """A smoke cloud dropped at your feet: four round puffs, each with a lit upper-left rim, drifting wisps."""
    image, d = skill_canvas()
    puffs = ([3, 15, 19, 31], [13, 5, 29, 21], [21, 15, 37, 31], [10, 21, 30, 37])
    for box in puffs:
        d.ellipse(box, fill=SK_SMOKE_DARK)
    for x0, y0, x1, y1 in puffs:
        d.ellipse([x0, y0, x1 - 3, y1 - 3], fill=SK_SMOKE)
    for x0, y0, x1, y1 in puffs:
        d.arc([x0 + 1, y0 + 1, x1 - 4, y1 - 4], 190, 280, fill=PARCHMENT_DARK, width=2)   # lit rim of each puff
    d.line([(2, 10), (9, 10)], fill=SK_SMOKE, width=2)
    d.line([(31, 5), (37, 5)], fill=SK_SMOKE, width=2)
    return skill_finish(image)


def skill_death_mark() -> Image.Image:
    """The assassin capstone: a skull marked for death with a crimson brand."""
    image, d = skill_canvas()
    d.ellipse([8, 3, 32, 26], fill=PARCHMENT)
    d.rectangle([13, 22, 27, 32], fill=PARCHMENT)
    d.ellipse([12, 12, 18, 18], fill=INK)
    d.ellipse([22, 12, 28, 18], fill=INK)
    d.polygon([(20, 19), (22, 23), (18, 23)], fill=INK)
    for x in (15, 19, 23):
        d.line([(x, 27), (x, 32)], fill=PARCHMENT_DARK)
    d.line([(4, 32), (14, 37)], fill=SK_CRIT, width=3)
    d.line([(4, 37), (14, 32)], fill=SK_CRIT, width=3)
    d.polygon([(20, 5), (23, 8), (20, 11), (17, 8)], fill=SK_CRIT)
    return skill_finish(image)


SKILL_ICONS = {
    "furious_strike": skill_furious_strike, "battle_cry": skill_battle_cry, "blade_rush": skill_blade_rush,
    "warbreaker": skill_warbreaker, "whirlwind": skill_whirlwind, "blood_frenzy": skill_blood_frenzy,
    "unbound_fury": skill_unbound_fury,
    "arcane_bolt": skill_arcane_bolt, "mana_pulse": skill_mana_pulse, "frostbind": skill_frostbind,
    "rune_sigil": skill_rune_sigil, "arcane_rift": skill_arcane_rift, "astral_lance": skill_astral_lance,
    "astral_ascension": skill_astral_ascension,
    "shadow_strike": skill_shadow_strike, "expose_weakness": skill_expose_weakness, "shadowstep": skill_shadowstep,
    "execution": skill_execution, "blade_fan": skill_blade_fan, "smoke_veil": skill_smoke_veil, "death_mark": skill_death_mark,
}


## Skills & Talents UX 2.0 Phase 1 (Weapon Mastery): one 40 x 40 icon per combo ACTION, shared by every weapon
## family whose combo does the same thing (the families share their input sequences; names differ, the action
## does not). Id = combos/<form>_<inputs>[_<effect>] - ComboIcons.icon_id derives it from the data:
##   form    sweep (an arc hit: swords, axe, mace, dagger, staff), thrust (a narrow arc: spear),
##           bolt (a projectile: wand), arrow (a bow)
##   effect  lunge (moves forward), sidestep_r / sidestep_l (moves aside), x3 (hits up to 3 times),
##           twin (two projectiles) - only where the final attack really does it
## Top row: the input rhythm as pips (small diamond = quick L, big gold diamond = heavy H, gold ring = precision P);
## below: the finishing hit of the form, light (steel) or heavy / precision (old gold).
CB_ARC = rgb("B880FF")        # the wand's bolts (= the Arcanist accent)
CB_ARC_DARK = rgb("6E48B0")
CB_WOOD = rgb("8A6A44")       # bow and arrow wood
CB_WOOD_DARK = rgb("5E4630")


def combo_pips(d, inputs: str) -> None:
    """The input rhythm, centred at the top (rows 1..9)."""
    widths = {"L": 5, "H": 9, "P": 9}
    gap = 3
    total = sum(widths[c] for c in inputs) + gap * (len(inputs) - 1)
    x = (40 - total) // 2
    for c in inputs:
        w = widths[c]
        cx, cy = x + w // 2, 5
        r = w // 2
        if c == "P":
            d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=GOLD_LIGHT, width=2)
            d.point([(cx, cy)], fill=OLD_GOLD)
        else:
            colour = PARCHMENT if c == "L" else OLD_GOLD
            d.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], fill=colour)
            if c == "H":
                d.polygon([(cx, cy - r + 1), (cx + r - 1, cy), (cx, cy)], fill=GOLD_LIGHT)
        x += w + gap


def combo_sweep(d, heavy: bool, x3: bool = False) -> None:
    """An arc hit opening to the right: a thin steel crescent (light) or a broad gold one with sparks (heavy)."""
    if x3:
        for dx in (-6, 0, 6):
            d.arc([6 + dx, 13, 30 + dx, 37], 300, 60, fill=STEEL_LIGHT, width=2)
        return
    if heavy:
        d.arc([4, 12, 34, 38], 290, 70, fill=OLD_GOLD, width=6)
        d.arc([4, 12, 34, 38], 300, 340, fill=GOLD_LIGHT, width=2)
        for x, y in ((35, 17), (36, 25), (35, 33)):
            d.rectangle([x, y, x + 1, y + 1], fill=GOLD_LIGHT)
    else:
        d.arc([6, 13, 32, 37], 295, 65, fill=STEEL_LIGHT, width=3)
        d.arc([6, 13, 32, 37], 330, 30, fill=PARCHMENT_LIGHT, width=1)


def combo_thrust(d, heavy: bool) -> None:
    """A straight thrust to the right: a thin spear (light) or a heavy one with a burst at its point."""
    if heavy:
        d.rectangle([4, 23, 26, 26], fill=GOLD_DARK)
        d.polygon([(26, 19), (35, 24), (35, 25), (26, 30)], fill=OLD_GOLD)
        d.line([(27, 21), (34, 24)], fill=GOLD_LIGHT)
        for x, y in ((37, 18), (37, 30), (38, 24)):
            d.rectangle([x, y, x + 1, y + 1], fill=GOLD_LIGHT)
    else:
        d.rectangle([4, 24, 27, 25], fill=GOLD_DARK)
        d.polygon([(27, 21), (35, 24), (35, 25), (27, 28)], fill=STEEL_LIGHT)


def combo_bolt(d, heavy: bool, twin: bool = False) -> None:
    """A spell projectile flying right: a violet orb with its trail; heavy = bigger with a gold core; twin = two."""
    def orb(cx: int, cy: int, r: int, core) -> None:
        d.polygon([(cx - r, cy - r + 1), (cx, cy), (cx - r, cy + r - 1), (cx - 4 * r, cy)], fill=CB_ARC_DARK)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=CB_ARC)
        d.ellipse([cx - r // 2, cy - r // 2, cx + r // 2, cy + r // 2], fill=core)
    if twin:
        orb(30, 18, 4, PARCHMENT_LIGHT)
        orb(30, 31, 4, PARCHMENT_LIGHT)
    elif heavy:
        orb(27, 25, 8, GOLD_LIGHT)
    else:
        orb(28, 25, 5, PARCHMENT_LIGHT)


def combo_arrow(d, precision: bool, y: int = 25, short: bool = False) -> None:
    """An arrow flying right: shaft, steel head, fletching; precision = longer, with a gold aiming ring at the head."""
    x0 = 10 if short else 4
    d.rectangle([x0, y, 30, y + 1], fill=CB_WOOD)
    d.polygon([(x0, y - 2), (x0 + 4, y), (x0 + 4, y + 1), (x0, y + 3)], fill=PARCHMENT_DARK)
    d.polygon([(30, y - 2), (36, y), (36, y + 1), (30, y + 3)], fill=STEEL_LIGHT)
    if precision:
        d.ellipse([28, y - 6, 39, y + 7], outline=GOLD_LIGHT, width=1)


def combo_lunge(d) -> None:
    """Moving forward: a gold double chevron (forward = right) in the bottom-left corner."""
    for x0 in (1, 6):
        d.line([(x0, 30), (x0 + 3, 34), (x0, 38)], fill=GOLD_LIGHT, width=2)


def combo_sidestep(d, clockwise: bool) -> None:
    """Moving aside: a short arrow across the attack direction at the left (down = clockwise, up = counter)."""
    tip_y, tail_y = (37, 26) if clockwise else (14, 25)
    d.line([(4, tail_y), (4, tip_y)], fill=GOLD_LIGHT, width=2)
    sign = 1 if clockwise else -1
    d.polygon([(1, tip_y - 3 * sign), (7, tip_y - 3 * sign), (4, tip_y)], fill=GOLD_LIGHT)


def combo_icon(form: str, inputs: str, effect: str = "") -> Image.Image:
    image, d = skill_canvas()
    combo_pips(d, "LLL" if inputs == "flowing_draw" else inputs.upper())
    last = "L" if inputs == "flowing_draw" else inputs.upper()[-1]
    heavy = last in ("H", "P")
    if form == "sweep":
        combo_sweep(d, heavy, x3=effect == "x3")
    elif form == "thrust":
        combo_thrust(d, heavy)
    elif form == "bolt":
        combo_bolt(d, heavy, twin=effect == "twin")
    elif inputs == "flowing_draw":   # three quick shots in a row, held draw
        for y in (16, 25, 34):
            combo_arrow(d, False, y=y, short=True)
        d.arc([0, 14, 12, 38], 120, 240, fill=GOLD_LIGHT, width=1)
    else:
        combo_arrow(d, last == "P")
    if effect == "lunge":
        combo_lunge(d)
    elif effect in ("sidestep_r", "sidestep_l"):
        combo_sidestep(d, effect == "sidestep_r")
    return skill_finish(image)


# id -> (form, inputs, effect): every combo action that exists in data/weapons (ComboIcons.icon_id)
COMBO_ICONS = {}
for _inputs in ("l", "h", "lll", "llh", "lhl", "hll", "lhh", "hlh", "hhl", "hhh"):
    COMBO_ICONS[f"sweep_{_inputs}"] = ("sweep", _inputs, "")
COMBO_ICONS.update({"sweep_hll_lunge": ("sweep", "hll", "lunge"), "sweep_lhl_sidestep_r": ("sweep", "lhl", "sidestep_r"),
                    "sweep_hhl_sidestep_l": ("sweep", "hhl", "sidestep_l"), "sweep_hhh_x3": ("sweep", "hhh", "x3")})
for _inputs in ("l", "h", "lll", "lhl", "lhh", "hlh", "hhl", "hhh"):
    COMBO_ICONS[f"thrust_{_inputs}"] = ("thrust", _inputs, "")
COMBO_ICONS.update({"thrust_llh_lunge": ("thrust", "llh", "lunge"), "thrust_hll_lunge": ("thrust", "hll", "lunge")})
for _inputs in ("l", "h", "lll", "llh", "hll", "lhh", "hlh", "hhh"):
    COMBO_ICONS[f"bolt_{_inputs}"] = ("bolt", _inputs, "")
COMBO_ICONS.update({"bolt_lhl_twin": ("bolt", "lhl", "twin"), "bolt_hhl_twin": ("bolt", "hhl", "twin")})
for _inputs in ("l", "p", "ll", "lp", "pl", "llp", "plp", "lpl", "pllp", "flowing_draw"):
    COMBO_ICONS[f"arrow_{_inputs}"] = ("arrow", _inputs, "")


# --- icons ----------------------------------------------------------------------------------------

def shape_icon(shapes: list[tuple], details: list[tuple] = ()) -> Image.Image:
    """shapes: (colour, [(x0, y0, x1, y1), ...] inclusive rects, [(x, y) pixels to clear]) drawn in
    order; then a 1 px ink outline around the silhouette, then rim shading (base colours lighter where
    the ink is above/left, darker below/right) - together the ~2 px contour; details are drawn last."""
    image = Image.new("RGBA", (32, 32), T)
    for colour, rects, clear in shapes:
        for x0, y0, x1, y1 in rects:
            for y in range(y0, y1 + 1):
                for x in range(x0, x1 + 1):
                    image.putpixel((x, y), colour)
        for x, y in clear:
            image.putpixel((x, y), T)
    outline(image)
    shade(image)
    for colour, pixels in details:
        for x, y in pixels:
            image.putpixel((x, y), colour)
    return image


LIGHTER = {OLD_GOLD: GOLD_LIGHT, GOLD_DARK: OLD_GOLD, STEEL: STEEL_LIGHT, STEEL_DARK: STEEL, PARCHMENT: PARCHMENT_LIGHT,
           PARCHMENT_DARK: PARCHMENT, SLATE: SLATE_LIGHT}
DARKER = {OLD_GOLD: GOLD_DARK, GOLD_DARK: GOLD_DARK, STEEL: STEEL_DARK, STEEL_DARK: STEEL_DARK,
          PARCHMENT: PARCHMENT_DARK, PARCHMENT_DARK: PARCHMENT_DARK, SLATE: SLATE_DARK}
N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))


# --- menu icon family (Menu Icons 1.0) --------------------------------------------------------------
# One rule set for all seven: 32 x 32, motif ~24 px and centred, a 1 px ink outline plus a 1 px rim
# (light top/left, dark bottom/right) = the same ~2 px contour everywhere; one main material
# (steel, old gold or parchment) with an old-gold accent; ink only for openings and separations.

def disk(cx: float, cy: float, r: float) -> set[tuple[int, int]]:
    return {(x, y) for y in range(32) for x in range(32) if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r}


def rect(x0: int, y0: int, x1: int, y1: int) -> set[tuple[int, int]]:
    return set(rect_pixels(x0, y0, x1, y1))


def mask_icon(parts: list[tuple], details: list[tuple] = ()) -> Image.Image:
    """parts: (colour, pixel set, separate) in drawing order; a separate part gets a 1 px ink line
    where it lies on earlier parts. Then outline and rim shading as shape_icon, then details."""
    image = Image.new("RGBA", (32, 32), T)
    owner: dict[tuple[int, int], int] = {}
    for index, (colour, pixels, separate) in enumerate(parts):
        pixels = {p for p in pixels if 0 <= p[0] < 32 and 0 <= p[1] < 32}
        for p in pixels:
            image.putpixel(p, colour)
            owner[p] = index
        if separate:
            for x, y in pixels:
                for dx, dy in N4:
                    q = (x + dx, y + dy)
                    if q in owner and owner[q] not in (index, -1) and q not in pixels:
                        image.putpixel(q, INK)
                        owner[q] = -1
    outline(image)
    shade(image)
    for colour, pixels in details:
        for p in pixels:
            image.putpixel(p, colour)
    return image


def outline(image: Image.Image) -> None:
    w, h = image.size
    solid = {(x, y) for y in range(h) for x in range(w) if image.getpixel((x, y))[3] > 0}
    for y in range(h):
        for x in range(w):
            if (x, y) in solid:
                continue
            if any((x + dx, y + dy) in solid for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                image.putpixel((x, y), INK)


def shade(image: Image.Image) -> None:
    w, h = image.size
    source = image.copy()
    for y in range(h):
        for x in range(w):
            colour = source.getpixel((x, y))
            if colour[3] == 0 or colour == INK:
                continue

            def ink(dx: int, dy: int) -> bool:
                nx, ny = x + dx, y + dy
                return 0 <= nx < w and 0 <= ny < h and source.getpixel((nx, ny)) == INK

            if (ink(1, 0) or ink(0, 1)) and colour in DARKER:
                image.putpixel((x, y), DARKER[colour])
            elif (ink(-1, 0) or ink(0, -1)) and colour in LIGHTER:
                image.putpixel((x, y), LIGHTER[colour])


def rect_pixels(x0: int, y0: int, x1: int, y1: int) -> list[tuple[int, int]]:
    return [(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)]


def menu_inventory() -> Image.Image:
    """A travel pack: round carry loop, tall body, rounded top flap with a steel buckle on a strap,
    stitched side pockets, a darker base."""
    body = (OLD_GOLD, [(9, 9, 22, 28)], [(9, 9), (22, 9), (9, 10), (22, 10), (10, 9), (21, 9), (9, 28), (22, 28)])
    pockets = (GOLD_DARK, [(6, 17, 8, 26), (23, 17, 25, 26)], [(6, 17), (25, 17), (6, 26), (25, 26)])
    loop = (GOLD_DARK, [(13, 3, 18, 8)], [(13, 3), (18, 3)] + rect_pixels(15, 5, 16, 8))
    image = shape_icon([pockets, body, loop])
    flap = rect_pixels(10, 10, 21, 16) + rect_pixels(11, 17, 20, 17) + rect_pixels(13, 18, 18, 18)
    flap_edge = [(10, 17), (11, 18), (12, 18), (12, 19), (13, 19), (14, 19), (17, 19), (18, 19), (19, 19),
                 (19, 18), (20, 18), (21, 17)]
    details = [
        (GOLD_DARK, flap),                                   # flap, curved lower edge
        (INK, flap_edge),
        (GOLD_LIGHT, [(11, 11), (12, 11), (13, 11), (11, 12)]),   # flap light
        (GOLD_DARK, rect_pixels(15, 20, 16, 25)),           # strap below the buckle
        (INK, rect_pixels(13, 16, 18, 21)),                  # buckle frame
        (STEEL_LIGHT, [(14, 17), (15, 17), (16, 17), (17, 17), (14, 18), (14, 19)]),
        (STEEL, [(17, 18), (17, 19), (14, 20), (15, 20), (16, 20), (17, 20)]),
        (INK, [(15, 18), (16, 18), (15, 19), (16, 19)]),     # buckle opening
        (PARCHMENT_DARK, [(7, 19), (7, 21), (7, 23), (24, 19), (24, 21), (24, 23)]),   # pocket stitches
        (INK, [(x, 26) for x in range(10, 22)]),            # base seam
        (GOLD_DARK, [(x, 27) for x in range(10, 22)]),
    ]
    for colour, pixels in details:
        for x, y in pixels:
            image.putpixel((x, y), colour)
    return image


def menu_journal() -> Image.Image:
    """A closed tome: slate-steel cover with spine, parchment page block right and below, gold corner
    fittings and a gold diamond, a gold ribbon hanging out below."""
    pages = (PARCHMENT, [(11, 7, 24, 27)], [])
    cover = (STEEL, [(7, 5, 22, 25)], [(7, 5), (7, 25)])
    ribbon = (OLD_GOLD, [(18, 26, 19, 28)], [])   # ends on the family baseline (y 28 + outline)
    image = shape_icon([pages, cover, ribbon])
    details = [
        (STEEL_DARK, rect_pixels(8, 6, 10, 24)),             # spine
        (INK, [(11, y) for y in range(6, 25)]),             # spine edge
        (STEEL_LIGHT, [(9, y) for y in range(7, 24)]),     # spine light
        (PARCHMENT_DARK, [(23, y) for y in range(8, 27, 2)] + [(x, 26) for x in range(13, 24, 2)]),  # page lines
        # gold corner fittings
        (OLD_GOLD, [(20, 6), (21, 6), (21, 7), (20, 24), (21, 24), (21, 23)]),
        (GOLD_LIGHT, [(19, 6), (21, 8)]),
        # diamond emblem
        (INK, [(16, 11), (15, 12), (17, 12), (14, 13), (18, 13), (13, 14), (19, 14), (14, 15), (18, 15), (15, 16), (17, 16), (16, 17)]),
        (OLD_GOLD, [(16, 12), (15, 13), (16, 13), (17, 13), (14, 14), (15, 14), (17, 14), (18, 14), (15, 15), (16, 15), (17, 15), (16, 16)]),
        (GOLD_LIGHT, [(16, 12), (15, 13), (14, 14)]),
        (INK, [(16, 14)]),
        # title band
        (STEEL_DARK, [(x, 20) for x in range(13, 21)]),
        (STEEL_LIGHT, [(x, 19) for x in range(13, 21)]),
    ]
    for colour, pixels in details:
        for x, y in pixels:
            image.putpixel((x, y), colour)
    return image


def menu_character() -> Image.Image:
    """A closed steel helm, front view: rounded dome, gold crest ridge and brow band, two eye slits
    beside a nose guard, breathing holes, a gold-dark gorget rim."""
    dome = {p for p in disk(16, 13, 9) if p[1] <= 13}
    helm = dome | rect(7, 13, 24, 23) | rect(9, 24, 22, 25)
    gorget = rect(10, 26, 21, 27)
    crest = rect(15, 3, 16, 12)
    details = [
        (OLD_GOLD, rect_pixels(8, 14, 23, 14)),              # brow band
        (GOLD_LIGHT, rect_pixels(8, 14, 11, 14)),
        (INK, rect_pixels(9, 16, 13, 17) + rect_pixels(18, 16, 22, 17)),   # eye slits
        (INK, [(11, 21), (11, 23), (20, 21), (20, 23)]),     # breathing holes
    ]
    return mask_icon([(STEEL, helm, False), (GOLD_DARK, gorget, True), (OLD_GOLD, crest, True)], details)


def menu_skills() -> Image.Image:
    """An ability seal: a steel ring, broken by a four-pointed gold spark that bursts through it."""
    ring = disk(16, 16, 10.5) - disk(16, 16, 7.5)

    def spark(x: int, y: int) -> bool:
        dx, dy = abs(x + 0.5 - 16), abs(y + 0.5 - 16)
        # a tapering four-pointed star (astroid, exponent 0.6): broad heart, 2 px tips - a spark,
        # not a crosshair (straight thin rays read as an aiming reticle)
        return dx ** 0.6 + dy ** 0.6 <= 15.0 ** 0.6

    star = {(x, y) for y in range(32) for x in range(32) if spark(x, y)}
    details = [(GOLD_LIGHT, [(15, 14), (14, 15), (15, 15)]), (PARCHMENT_LIGHT, [(15, 15)])]
    return mask_icon([(STEEL, ring, False), (OLD_GOLD, star, True)], details)


def menu_professions() -> Image.Image:
    """Smithing: a steel hammer resting upright on a steel anvil, gold-dark wooden handle."""
    anvil_top = rect(8, 18, 25, 20) | rect(5, 18, 7, 19)        # face with a short tapering horn
    anvil = anvil_top | rect(12, 21, 21, 23) | rect(9, 24, 24, 27)
    handle = rect(16, 10, 17, 15)
    head = rect(10, 3, 23, 9) - {(10, 3), (23, 3), (10, 9), (23, 9)}
    details = [
        (INK, [(x, 23) for x in range(12, 22)]),             # waist / base seam
        (INK, [(16, 6), (17, 6)]),                           # eye of the hammer head
        (GOLD_LIGHT, [(11, 4), (12, 4), (13, 4)]),
    ]
    return mask_icon([(STEEL, anvil, False), (GOLD_DARK, handle, True), (STEEL, head, True)], details)


def menu_map() -> Image.Image:
    """A folded map: three panels (the middle one in the fold's shadow), an ink route and a gold mark."""
    left = rect(5, 8, 11, 25)
    middle = rect(12, 6, 19, 23)
    right = rect(20, 8, 26, 25)
    route = [(7, 23), (8, 22), (8, 21), (10, 20), (11, 19), (13, 18), (14, 17), (15, 15), (16, 14), (18, 13),
             (19, 13), (21, 14)]
    pin_ring = [(22, 9), (23, 9), (21, 10), (24, 10), (21, 11), (24, 11), (22, 12), (23, 12)]
    details = [(INK, route), (INK, pin_ring), (OLD_GOLD, [(22, 10), (23, 10), (23, 11)]), (GOLD_LIGHT, [(22, 11)])]
    return mask_icon([(PARCHMENT, left, False), (PARCHMENT_DARK, middle, True), (PARCHMENT, right, True)], details)


def menu_settings() -> Image.Image:
    """A steel cog with eight teeth around a gold hub and an open centre."""
    import math

    def tooth(x: int, y: int) -> bool:
        angle = math.degrees(math.atan2(y + 0.5 - 16, x + 0.5 - 16)) % 45.0
        return angle <= 11.5 or angle >= 33.5

    teeth = {p for p in disk(16, 16, 12) if tooth(*p)}
    cog = (disk(16, 16, 8.6) | teeth) - disk(16, 16, 5.2)
    hub = disk(16, 16, 5.2) - disk(16, 16, 2.6)
    return mask_icon([(STEEL, cog, False), (OLD_GOLD, hub, True)])



# --- Menu UX Polish 1.0: main-window ground and page ---------------------------------------------

def window_backdrop() -> Image.Image:
    """32 x 32 tile (drawn tiled, 1:1, inside the window frame of the seven main menus): the window tone
    with an ordered grain - a lit pixel on a diagonal lattice every 4th row, its sunk shadow one pixel
    down-right (light from the top left). 1.6 % lit, 1.6 % sunk: a surface, not noise; seamless."""
    image = Image.new("RGBA", (32, 32), WINDOW_GROUND)
    for y in range(0, 32, 4):
        for x in range(32):
            if (x + 2 * y) % 16 == 0:
                image.putpixel((x, y), WINDOW_GRAIN)
                image.putpixel(((x + 1) % 32, (y + 1) % 32), CHARCOAL)
    return image


def window_page() -> Image.Image:
    """16 x 16, nine-patch 6: the calm page behind a main menu's content - an engraved double line (dark
    groove over a lit lip, reversed on the bottom / right) around flat charcoal, small old-gold corner
    ticks on the groove. Drawn a few px around the body; the grain stays outside, text sits on flat ground."""
    image = profile_frame(16, [(INK, SLATE_DARK), (SLATE_DARK, INK)], CHARCOAL, chamfer=1)
    corner_ticks(image, OLD_GOLD, depth=1, length=3)
    return image



# --- Combat HUD UX 2.0: vessels (health / class resource) and quick-use bottles ---------------------------

VESSEL_SIZE = (52, 66)
VESSEL_CHAMFER = 10
BOTTLE_SIZE = (40, 48)


def _erode(pixels: set) -> set:
    return {(x, y) for x, y in pixels if all((x + dx, y + dy) in pixels for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))}


def _rings(shape: set, profile: list[tuple]) -> tuple[dict, set]:
    """Colours of the outer rings of `shape` (profile[d] = (lit, shade): lit where the ring faces up / left)
    and the remaining interior."""
    colours: dict = {}
    current = set(shape)
    for lit, shade in profile:
        inner = _erode(current)
        for x, y in current - inner:
            faces_light = (x, y - 1) not in current or (x - 1, y) not in current
            colours[(x, y)] = lit if faces_light else shade
        current = inner
    return colours, current


def _vessel_shape(right: bool) -> set:
    """52 x 66: a tall vessel, its outer side (left for health, right for the resource) cut diagonally at the
    top and bottom (VESSEL_CHAMFER), the inner corners lightly cut - square towards the combat bar."""
    w, h = VESSEL_SIZE
    shape = set()
    for y in range(h):
        for x in range(w):
            outer = (w - 1 - x) if right else x   # distance from the outer side
            inner = x if right else (w - 1 - x)
            if outer + y < VESSEL_CHAMFER or outer + (h - 1 - y) < VESSEL_CHAMFER:
                continue
            if inner + y < 1 or inner + (h - 1 - y) < 1:
                continue
            shape.add((x, y))
    return shape


VESSEL_PROFILE = [(INK, INK), (STEEL, STEEL_DARK), (INK, INK)]


def hud_vessel(right: bool) -> Image.Image:
    """The frame of a HUD vessel: ink, a thin neutral steel band lit from the top left, ink; the inside is
    open (drawn by the game: the empty well and the fill come from hud/vessel_fill_*)."""
    image = Image.new("RGBA", VESSEL_SIZE, T)
    colours, _ = _rings(_vessel_shape(right), VESSEL_PROFILE)
    for p, c in colours.items():
        image.putpixel(p, c)
    return image


def _tone_mask(size: tuple, inside: set) -> Image.Image:
    """Tint mask of `inside` like bar/fill: per row the leftmost pixel lit, the rightmost shaded, body between."""
    image = Image.new("RGBA", size, T)
    rows: dict = {}
    for x, y in inside:
        rows.setdefault(y, []).append(x)
    for y, xs in rows.items():
        for x in xs:
            image.putpixel((x, y), MASK_LIGHT if x == min(xs) else (MASK_SHADE if x == max(xs) else MASK_BODY))
    return image


def hud_vessel_fill(right: bool) -> Image.Image:
    """Tint mask of the vessel's inside (exactly the open part of hud/vessel_*): drawn tinted from the bottom
    up to the value, and in a dark tone as the empty well."""
    _, inside = _rings(_vessel_shape(right), VESSEL_PROFILE)
    return _tone_mask(VESSEL_SIZE, inside)


def _bottle_shapes(round_body: bool) -> tuple[set, set]:
    """Glass silhouette and cork of a quick-use bottle in 40 x 48 (centred, a little low: the key label sits
    top left in the slot). Hearth Flask: a broad squared bottle; a potion: a round flask - two silhouettes."""
    w, h = BOTTLE_SIZE
    glass = set(rect_pixels(15, 7, 24, 15))   # neck
    if round_body:
        cx, cy, r = 20.0, 31.0, 15.5
        glass |= {(x, y) for y in range(h) for x in range(w) if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r}
    else:
        for y in range(15, 47):   # shoulders widen over 5 rows, then a body with rounded bottom corners
            half = min(16, 5 + (y - 15) * 2.4)
            if y >= 44:
                half -= (y - 43)
            glass |= {(x, y) for x in range(int(20 - half), int(20 + half))}
    cork = set(rect_pixels(16, 2, 23, 7))
    return glass, cork


BOTTLE_PROFILE = [(INK, INK), (STEEL_LIGHT, STEEL_DARK)]


def _bottle_parts(round_body: bool) -> tuple[dict, set]:
    glass, cork = _bottle_shapes(round_body)
    colours, inside = _rings(glass, BOTTLE_PROFILE)
    cork_colours, cork_inside = _rings(cork, [(INK, INK)])
    for p in cork_inside:
        cork_colours[p] = PARCHMENT_DARK if p[1] <= 3 else GOLD_DARK
    colours.update(cork_colours)
    # a glint on the glass, on top of the liquid: two short columns on the upper left of the body
    top = min(y for _, y in inside if y > 16)
    glint = {(x, y) for x, y in inside if top + 2 <= y <= top + 9 and x == min(px for px, py in inside if py == y) + 2}
    for p in glint:
        colours[p] = PARCHMENT_LIGHT
    return colours, inside - glint - set(cork_colours)


def hud_bottle(round_body: bool) -> Image.Image:
    """Quick-use bottle (Hearth Flask: squared, potion: round): ink outline, a lit steel glass rim, cork,
    a glint; the glass is open - the liquid (hud/*_fill) shows the charges / stack below it."""
    image = Image.new("RGBA", BOTTLE_SIZE, T)
    colours, _ = _bottle_parts(round_body)
    for p, c in colours.items():
        image.putpixel(p, c)
    return image


def hud_bottle_fill(round_body: bool) -> Image.Image:
    """Tint mask of the bottle's liquid (the open glass of hud/flask or hud/potion, without the glint)."""
    _, inside = _bottle_parts(round_body)
    return _tone_mask(BOTTLE_SIZE, inside)


ASSETS = {
    "window/panel": window_panel,
    "button/normal": lambda: button("normal"),
    "button/hover": lambda: button("hover"),
    "button/pressed": lambda: button("pressed"),
    "button/disabled": lambda: button("disabled"),
    "slot/normal": lambda: slot("normal"),
    "slot/selected": lambda: slot("selected"),
    "slot/hover": lambda: slot("hover"),
    "slot/disabled": lambda: slot("disabled"),
    "tab/normal": lambda: tab("normal"),
    "tab/hover": lambda: tab("hover"),
    "tab/selected": lambda: tab("selected"),
    "button/primary_normal": lambda: primary_button("normal"),
    "button/primary_hover": lambda: primary_button("hover"),
    "button/primary_pressed": lambda: primary_button("pressed"),
    "button/primary_disabled": lambda: primary_button("disabled"),
    "panel/hud": panel_hud,
    "panel/card": lambda: panel_card(False),
    "panel/card_selected": lambda: panel_card(True),
    "panel/inset": panel_inset,
    "tooltip/panel": tooltip_panel,
    "hud/slot_frame": hud_slot_frame,
    "hud/slot_frame_disabled": lambda: hud_slot_frame(disabled=True),
    "menu/inventory": menu_inventory,
    "menu/character": menu_character,
    "menu/skills": menu_skills,
    "menu/professions": menu_professions,
    "menu/journal": menu_journal,
    "menu/map": menu_map,
    "menu/settings": menu_settings,
    "scroll/track": scroll_track,
    "scroll/grabber": scroll_grabber,
    "input/normal": lambda: input_field("normal"),
    "input/focus": lambda: input_field("focus"),
    "input/disabled": lambda: input_field("disabled"),
    # Secondary Controls 1.0
    "dropdown/arrow": dropdown_arrow,
    "dropdown/radio_on": lambda: radio(True),
    "dropdown/radio_off": lambda: radio(False),
    "dropdown/radio_off_disabled": lambda: radio(False, disabled=True),
    "check/on": lambda: check_box(True),
    "check/off": lambda: check_box(False),
    "check/on_disabled": lambda: check_box(True, disabled=True),
    "check/off_disabled": lambda: check_box(False, disabled=True),
    "slider/fill": slider_fill,
    "slider/grabber": lambda: slider_grabber("normal"),
    "slider/grabber_hover": lambda: slider_grabber("hover"),
    "slider/grabber_disabled": lambda: slider_grabber("disabled"),
    "chip/key": key_chip,
    # BookTabs Visual Integration 1.0
    "booktab/normal": lambda: book_register("normal"),
    "booktab/hover": lambda: book_register("hover"),
    "booktab/selected": lambda: book_register("selected"),
    # HUD Bars Visual Integration 1.0
    "bar/frame": bar_frame,
    "bar/fill": bar_fill,
    # Map Markers Pixel Art 1.0
    "map/player": map_player,
    "map/exit": map_exit,
    "map/waystone": map_waystone,
    "map/waystone_silent": lambda: map_waystone(silent=True),
    "map/rest": map_rest,
    "map/npc": map_npc,
    "map/landmark": map_landmark,
    "map/quest": map_quest,
    # Menu UX Polish 1.0
    "window/backdrop": window_backdrop,
    "window/page": window_page,
    # Combat HUD UX 2.0
    "hud/vessel_left": lambda: hud_vessel(False),
    "hud/vessel_right": lambda: hud_vessel(True),
    "hud/vessel_fill_left": lambda: hud_vessel_fill(False),
    "hud/vessel_fill_right": lambda: hud_vessel_fill(True),
    "hud/flask": lambda: hud_bottle(False),
    "hud/flask_fill": lambda: hud_bottle_fill(False),
    "hud/potion": lambda: hud_bottle(True),
    "hud/potion_fill": lambda: hud_bottle_fill(True),
}
# Skill Icons Pixel Art 1.0: skills/<skill id> for every active skill of the three playable classes
ASSETS.update({f"skills/{skill_id}": build for skill_id, build in SKILL_ICONS.items()})
# Skills & Talents UX 2.0 Phase 1: combos/<form>_<inputs>[_<effect>] for every combo action of data/weapons
ASSETS.update({f"combos/{icon_id}": (lambda spec=spec: combo_icon(*spec)) for icon_id, spec in COMBO_ICONS.items()})


def preview(images: dict[str, Image.Image], directory: Path) -> None:
    """8x nearest-neighbour previews on two backgrounds (not game assets)."""
    directory.mkdir(parents=True, exist_ok=True)
    for name, image in images.items():
        for bg_name, bg in (("dark", rgb("1C2320")), ("slate", rgb("303A33"))):
            canvas = Image.new("RGBA", image.size, bg)
            canvas.alpha_composite(image)
            canvas.resize((image.width * 8, image.height * 8), Image.NEAREST).save(directory / f"{name.replace('/', '_')}_{bg_name}_8x.png")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="replace existing files")
    parser.add_argument("--preview", type=Path, help="write 8x preview sheets into this directory")
    args = parser.parse_args()
    images = {name: build() for name, build in ASSETS.items()}
    for name, image in images.items():
        path = OUT / f"{name}.png"
        if path.exists() and not args.force:
            print(f"kept (exists): {path.relative_to(ROOT)}")
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        image.save(path)
        print(f"wrote {path.relative_to(ROOT)} {image.size[0]}x{image.size[1]} {image.mode}")
    if args.preview:
        preview(images, args.preview)
    return 0


if __name__ == "__main__":
    sys.exit(main())
