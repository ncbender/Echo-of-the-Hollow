"""Core UI Asset Prototype 1.0 - automated checks of the UI PNGs (exit code 1 on any failure).

    py -3 tools/ui_art/validate_ui_assets.py [--render DIR]

Checks: exact path and size, RGBA, hard alpha (only 0 / 255, plus the documented HUD-slot interior
alpha), every colour from the asset palette (no antialiasing fringe), nine-patch edges uniform along
their stretch axis and a flat centre, identical geometry (alpha mask) of state variants, icons without
a background plate (transparent corners, an outline around the silhouette). Menu UX Polish 1.0: window/backdrop - opaque, at most three
tones close together, grain on few pixels; window/page - a flat centre darker than the ground. --render additionally
stretches window/panel like Godot's StyleBoxTexture to 320x160, 800x700 and 1200x850 for review.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image

sys.dont_write_bytecode = True   # no __pycache__ inside the project
sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_core_ui_assets import (GOLD_LIGHT, HUD_FILL, HUD_PANEL_FILL, INK, MASK_BODY, MASK_LIGHT,  # noqa: E402
                                     MASK_SHADE, OLD_GOLD, OUT, PALETTE, SKILL_ICONS, COMBO_ICONS)

SPEC = {   # id: (size, nine-patch border or None)
    "window/panel": (48, 12),
    "button/normal": (24, 4),
    "button/hover": (24, 4),
    "button/pressed": (24, 4),
    "button/disabled": (24, 4),
    "button/primary_normal": (24, 4),
    "button/primary_hover": (24, 4),
    "button/primary_pressed": (24, 4),
    "button/primary_disabled": (24, 4),
    "panel/hud": (24, 6),
    "panel/card": (24, 6),
    "panel/card_selected": (24, 6),
    "panel/inset": (16, 4),
    "tooltip/panel": (24, 6),
    "slot/normal": (24, 4),
    "slot/selected": (24, 4),
    "slot/hover": (24, 4),
    "slot/disabled": (24, 4),
    "tab/normal": (24, 4),
    "tab/hover": (24, 4),
    "tab/selected": (24, 4),
    "hud/slot_frame": (64, None),
    "hud/slot_frame_disabled": (64, None),
    "menu/inventory": (32, None),
    "menu/character": (32, None),
    "menu/skills": (32, None),
    "menu/professions": (32, None),
    "menu/journal": (32, None),
    "menu/map": (32, None),
    "menu/settings": (32, None),
    "scroll/track": (10, 3),       # UI Scrollbars & Input Fields 1.0
    "scroll/grabber": (10, 3),
    "input/normal": (24, 4),
    "input/focus": (24, 4),
    "input/disabled": (24, 4),
    # Secondary Controls 1.0 (sizes = the theme slots Godot draws, see the generator)
    "dropdown/arrow": (12, None),
    "dropdown/radio_on": (16, None),
    "dropdown/radio_off": (16, None),
    "dropdown/radio_off_disabled": (16, None),
    "check/on": (16, None),
    "check/off": (16, None),
    "check/on_disabled": (16, None),
    "check/off_disabled": (16, None),
    "slider/fill": (10, 3),
    "slider/grabber": (16, None),
    "slider/grabber_hover": (16, None),
    "slider/grabber_disabled": (16, None),
    "chip/key": (12, 3),
    "booktab/normal": (24, 4),     # BookTabs Visual Integration 1.0 (right side open towards the page)
    "booktab/hover": (24, 4),
    "booktab/selected": (24, 4),
    "bar/frame": (3, 1),           # HUD Bars Visual Integration 1.0
    "bar/fill": ((4, 6), None),    # tint mask, nine-patch top / bottom 1, sides 0 (checked below)
    "map/player": (16, None),      # Map Markers Pixel Art 1.0
    "map/exit": (16, None),
    "map/waystone": (16, None),
    "map/waystone_silent": (16, None),
    "map/rest": (16, None),
    "map/npc": (16, None),
    "map/landmark": (16, None),
    "map/quest": (16, None),
    "window/backdrop": (32, None),   # Menu UX Polish 1.0: tiled ground of the main menus (checked below)
    "window/page": (16, 6),          # Menu UX Polish 1.0: calm engraved page behind the content
    "hud/vessel_left": ((52, 66), None),        # Combat HUD UX 2.0: health vessel (outer side left)
    "hud/vessel_right": ((52, 66), None),       # class resource vessel (mirrored geometry)
    "hud/vessel_fill_left": ((52, 66), None),   # tint masks of the open inside (checked below)
    "hud/vessel_fill_right": ((52, 66), None),
    "hud/flask": ((40, 48), None),              # Hearth Flask bottle, open glass
    "hud/flask_fill": ((40, 48), None),
    "hud/potion": ((40, 48), None),             # potion bottle (round), open glass
    "hud/potion_fill": ((40, 48), None),
}
MARKERS = [name for name in SPEC if name.startswith("map/")]
# Skill Icons Pixel Art 1.0: one 40 x 40 icon per active skill of a playable class (ids from data/, see below)
SPEC.update({f"skills/{skill_id}": (40, None) for skill_id in SKILL_ICONS})
SKILLS = [name for name in SPEC if name.startswith("skills/")]
# Skills & Talents UX 2.0 Phase 1: one 40 x 40 icon per combo action (which ones exist: test_weapon_mastery_ui)
SPEC.update({f"combos/{icon_id}": (40, None) for icon_id in COMBO_ICONS})
COMBOS = [name for name in SPEC if name.startswith("combos/")]


def playable_skill_ids() -> set:
    """Skill ids of data/skills whose class is playable (data/classes/<class>.tres: playable = true or unset)."""
    data = OUT.parents[1] / "data"
    playable = set()
    for path in (data / "classes").glob("*.tres"):
        text = path.read_text(encoding="utf-8")
        if "playable = false" not in text:
            playable.add(path.stem)
    ids = set()
    for path in (data / "skills").glob("*.tres"):
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.startswith("class_id = &\""):
                if line.split("\"")[1] in playable:
                    ids.add(path.stem)
    return ids
## Pieces used for both orientations (H and V scroll bars): the image must equal its own transpose
## (a mirror on the main diagonal), so a vertical and a horizontal bar show the same frame.
ORIENTATION_FREE = ["scroll/track", "scroll/grabber", "slider/fill"]
## Small control icons: transparent corners (no plate) and a closed dark contour.
CONTROL_ICONS = SKILLS + COMBOS + ["dropdown/arrow", "dropdown/radio_on", "dropdown/radio_off", "dropdown/radio_off_disabled",
                 "slider/grabber", "slider/grabber_hover", "slider/grabber_disabled",
                 "map/player", "map/exit", "map/waystone", "map/waystone_silent", "map/rest", "map/npc", "map/landmark", "map/quest"]
PAIRS = [("button/normal", other) for other in ("button/hover", "button/pressed", "button/disabled")] +     [("slot/normal", other) for other in ("slot/selected", "slot/hover", "slot/disabled")] +     [("tab/normal", "tab/hover"), ("tab/normal", "tab/selected"), ("hud/slot_frame", "hud/slot_frame_disabled")] +     [("button/primary_normal", other) for other in ("button/primary_hover", "button/primary_pressed", "button/primary_disabled")] +     [("panel/card", "panel/card_selected")] +     [("input/normal", "input/focus"), ("input/normal", "input/disabled")] +     [("dropdown/radio_off", "dropdown/radio_on"), ("dropdown/radio_off", "dropdown/radio_off_disabled")] +     [("check/off", other) for other in ("check/on", "check/on_disabled", "check/off_disabled")] +     [("slider/grabber", "slider/grabber_hover"), ("slider/grabber", "slider/grabber_disabled")] +     [("booktab/normal", "booktab/hover"), ("booktab/normal", "booktab/selected")]
ICONS = [name for name in SPEC if name.startswith("menu/")]
## bar/fill is a neutral tint mask (multiplied with the bar's meaning colour), not a palette surface.
EXTRA_COLOURS = {name: {MASK_LIGHT, MASK_BODY, MASK_SHADE} for name in ("bar/fill", "hud/vessel_fill_left", "hud/vessel_fill_right",
                                                                 "hud/flask_fill", "hud/potion_fill")}
EXTRA_ALPHA = {"hud/slot_frame": {HUD_FILL[3]}, "hud/slot_frame_disabled": {HUD_FILL[3]}, "panel/hud": {HUD_PANEL_FILL[3]}}

failures: list[str] = []


def check(ok: bool, text: str) -> None:
    print(("OK    " if ok else "FAIL  ") + text)
    if not ok:
        failures.append(text)


def ninepatch(image: Image.Image, border: int, name: str) -> None:
    w, h = image.size
    px = image.load()
    top_ok = all(len({px[x, y] for x in range(border, w - border)}) == 1 for y in list(range(border)) + list(range(h - border, h)))
    side_ok = all(len({px[x, y] for y in range(border, h - border)}) == 1 for x in list(range(border)) + list(range(w - border, w)))
    centre = {px[x, y] for y in range(border, h - border) for x in range(border, w - border)}
    check(top_ok, f"{name}: top/bottom edges uniform along x (stretch-safe)")
    check(side_ok, f"{name}: left/right edges uniform along y (stretch-safe)")
    check(len(centre) == 1, f"{name}: flat centre ({len(centre)} colour)")
    corners = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    check(all(px[c][3] == 0 or px[c] == INK for c in corners), f"{name}: outer corners closed (ink or cut)")


def stretch(image: Image.Image, border: int, size: tuple[int, int]) -> Image.Image:
    """Nine-patch with stretched (not tiled) edges and centre, nearest filter - as StyleBoxTexture."""
    w, h = image.size
    tw, th = size
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    xs = [(0, border, 0, border), (border, w - border, border, tw - border), (w - border, w, tw - border, tw)]
    ys = [(0, border, 0, border), (border, h - border, border, th - border), (h - border, h, th - border, th)]
    for sx0, sx1, dx0, dx1 in xs:
        for sy0, sy1, dy0, dy1 in ys:
            part = image.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.NEAREST)
            out.paste(part, (dx0, dy0))
    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--render", type=Path)
    args = parser.parse_args()
    images: dict[str, Image.Image] = {}
    on_disk = sorted(p.relative_to(OUT).as_posix()[:-4] for p in OUT.rglob("*.png"))
    check(on_disk == sorted(SPEC), f"exactly the {len(SPEC)} PNGs under assets/ui ({on_disk})")
    for name, (size, border) in SPEC.items():
        path = OUT / f"{name}.png"
        if not path.exists():
            check(False, f"{name}: file {path} exists")
            continue
        image = Image.open(path)
        images[name] = image
        check(image.mode == "RGBA", f"{name}: RGBA ({image.mode})")
        want = size if isinstance(size, tuple) else (size, size)
        check(image.size == want, f"{name}: {want[0]}x{want[1]} ({image.size[0]}x{image.size[1]})")
        image = image.convert("RGBA")
        colours = set(image.get_flattened_data())
        alphas = {c[3] for c in colours}
        allowed = {0, 255} | EXTRA_ALPHA.get(name, set())
        check(alphas <= allowed, f"{name}: hard alpha only {sorted(allowed)} ({sorted(alphas)})")
        stray = {c for c in colours if c[3] > 0 and c not in PALETTE and c not in EXTRA_COLOURS.get(name, set())}
        check(not stray, f"{name}: palette colours only, no fringe ({len(stray)} stray)")
        if border is not None:
            ninepatch(image, border, name)
    for a, b in PAIRS:
        if a in images and b in images:
            mask_a = images[a].getchannel("A")
            mask_b = images[b].getchannel("A")
            check(list(mask_a.get_flattened_data()) == list(mask_b.get_flattened_data()), f"{a} / {b}: identical geometry (alpha mask)")
            diff = sum(1 for p, q in zip(images[a].get_flattened_data(), images[b].get_flattened_data()) if p != q)
            check(diff > 0, f"{a} / {b}: states differ ({diff} px)")
    for name in ORIENTATION_FREE:
        if name in images:
            image = images[name]
            check(list(image.get_flattened_data()) == list(image.transpose(Image.Transpose.TRANSPOSE).get_flattened_data()),
                  f"{name}: same frame for horizontal and vertical bars (diagonal-symmetric)")
    if "scroll/track" in images and "scroll/grabber" in images:
        def luma(c: tuple) -> float:
            return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
        track = images["scroll/track"].getpixel((5, 5))
        grab = images["scroll/grabber"].getpixel((5, 5))
        check(luma(grab) - luma(track) >= 60, f"scroll/grabber stands out from the track (centre luma {luma(grab):.0f} vs {luma(track):.0f})")
    # map markers: each its own silhouette (readable without colour); the two waystones share one shape
    # and differ in brightness (the silent one is clearly dimmer, its rune dark)
    def mask(name: str) -> set:
        return {(i % 16, i // 16) for i, c in enumerate(images[name].get_flattened_data()) if c[3] > 0}
    def luma(c: tuple) -> float:
        return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
    shapes = [n for n in MARKERS if n in images and n != "map/waystone_silent"]
    for i, a in enumerate(shapes):
        for b in shapes[i + 1:]:
            ma, mb = mask(a), mask(b)
            overlap = len(ma & mb) / len(ma | mb)
            check(overlap < 0.8, f"{a} / {b}: different silhouettes (overlap {overlap:.2f})")
    if "map/waystone" in images and "map/waystone_silent" in images:
        check(mask("map/waystone") == mask("map/waystone_silent"), "map/waystone / waystone_silent: the same stone")
        lit = [luma(c) for c in images["map/waystone"].get_flattened_data() if c[3] > 0]
        dim = [luma(c) for c in images["map/waystone_silent"].get_flattened_data() if c[3] > 0]
        check(sum(lit) / len(lit) - sum(dim) / len(dim) >= 25, f"map/waystone_silent: clearly dimmer ({sum(lit) / len(lit):.0f} vs {sum(dim) / len(dim):.0f})")
        rune = (7, 7)
        check(luma(images["map/waystone"].getpixel(rune)) - luma(images["map/waystone_silent"].getpixel(rune)) >= 60, "map/waystone_silent: the rune is dark, not lit")
    # skill icons: exactly the active skills of the playable classes, every one its own silhouette
    wanted = playable_skill_ids()
    check({n.split("/", 1)[1] for n in SKILLS} == wanted, f"skill icons = the {len(wanted)} active skills of the playable classes "
          f"(missing {sorted(wanted - set(SKILL_ICONS))}, extra {sorted(set(SKILL_ICONS) - wanted)})")
    def skill_mask(name: str) -> set:
        return {(i % 40, i // 40) for i, c in enumerate(images[name].get_flattened_data()) if c[3] > 0}
    skill_names = [n for n in SKILLS if n in images]
    worst = (0.0, "")
    for i, a in enumerate(skill_names):
        for b in skill_names[i + 1:]:
            ma, mb = skill_mask(a), skill_mask(b)
            overlap = len(ma & mb) / len(ma | mb)
            worst = max(worst, (overlap, f"{a} / {b}"))
            if overlap >= 0.7:
                check(False, f"{a} / {b}: different silhouettes (overlap {overlap:.2f})")
    check(worst[0] < 0.7, f"skill icons: all {len(skill_names)} silhouettes differ (closest pair {worst[1]}, overlap {worst[0]:.2f})")
    for name in skill_names:
        opaque = len(skill_mask(name))
        check(250 <= opaque <= 1100, f"{name}: a readable symbol, not a plate ({opaque} of 1600 px)")
    # combo icons: no two the same picture; within one form the input rhythm (pips) tells them apart
    pictures = {}
    for name in COMBOS:
        if name in images:
            pictures.setdefault(bytes(images[name].tobytes()), []).append(name)
    same = [names for names in pictures.values() if len(names) > 1]
    check(not same, f"combo icons: {len(COMBOS)} different pictures ({same})")
    for name in COMBOS:
        if name in images:
            opaque = sum(1 for c in images[name].get_flattened_data() if c[3] > 0)
            check(80 <= opaque <= 900, f"{name}: a readable symbol, not a plate ({opaque} of 1600 px)")
    for name in MARKERS:
        if name in images:
            opaque = sum(1 for c in images[name].get_flattened_data() if c[3] > 0)
            check(25 <= opaque <= 200, f"{name}: a compact symbol, not a plate ({opaque} of 256 px)")
    if "bar/fill" in images:   # the fill: every column identical (drawable at any width), rows light / body / shade
        px = images["bar/fill"].load()
        w, h = images["bar/fill"].size
        check(all(len({px[x, y] for x in range(w)}) == 1 for y in range(h)), "bar/fill: all columns identical (any width, no side corners)")
        check(px[0, 0] == MASK_LIGHT and px[0, h - 1] == MASK_SHADE and len({px[0, y] for y in range(1, h - 1)}) == 1,
              "bar/fill: lit top row, flat body, shaded bottom row")
        check(all(px[x, y][3] == 255 for y in range(h) for x in range(w)), "bar/fill: opaque (no gap to the frame)")
    # Combat HUD UX 2.0: each fill mask is exactly the open inside of its frame (no overlap, no gap to the rim),
    # only mask tones; the two vessels are mirror images; flask and potion are two different silhouettes
    for frame, fill in (("hud/vessel_left", "hud/vessel_fill_left"), ("hud/vessel_right", "hud/vessel_fill_right"),
                        ("hud/flask", "hud/flask_fill"), ("hud/potion", "hud/potion_fill")):
        if frame in images and fill in images:
            fr, fi = images[frame].load(), images[fill].load()
            w, h = images[frame].size
            inside = {(x, y) for y in range(h) for x in range(w) if fi[x, y][3] > 0}
            check(len(inside) >= 200 and all(fr[p][3] == 0 for p in inside), f"{fill}: the open inside of {frame} ({len(inside)} px, no overlap)")
            closed = all(fr[x + dx, y + dy][3] > 0 or (x + dx, y + dy) in inside for x, y in inside for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            check(closed, f"{frame}: the rim closes the inside (no gap)")
            check({c for c in images[fill].get_flattened_data() if c[3] > 0} <= {MASK_LIGHT, MASK_BODY, MASK_SHADE}, f"{fill}: mask tones only")
    if "hud/vessel_left" in images and "hud/vessel_right" in images:
        left = images["hud/vessel_left"].getchannel("A")
        check(list(left.transpose(Image.Transpose.FLIP_LEFT_RIGHT).get_flattened_data()) == list(images["hud/vessel_right"].getchannel("A").get_flattened_data()),
              "hud/vessel_left / right: mirrored geometry")
    if "hud/flask" in images and "hud/potion" in images:
        a = {i for i, c in enumerate(images["hud/flask"].getchannel("A").get_flattened_data()) if c}
        b = {i for i, c in enumerate(images["hud/potion"].getchannel("A").get_flattened_data()) if c}
        check(len(a & b) / len(a | b) < 0.8, f"hud/flask / potion: different silhouettes (overlap {len(a & b) / len(a | b):.2f})")
    if "window/backdrop" in images:   # Menu UX Polish 1.0: a quiet, ordered grain - never noise behind text
        tile = images["window/backdrop"]
        data = list(tile.get_flattened_data())
        tones = {}
        for c in data:
            tones[c] = tones.get(c, 0) + 1
        ground = max(tones, key=tones.get)
        lumas = [0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2] for c in tones]
        check(all(c[3] == 255 for c in tones), "window/backdrop: opaque (a tile, no holes)")
        check(len(tones) <= 3 and max(lumas) - min(lumas) <= 12, f"window/backdrop: at most 3 tones within 12 luma ({len(tones)}, {max(lumas) - min(lumas):.1f})")
        check(tones[ground] >= len(data) * 0.95, f"window/backdrop: grain on at most 5 % of the pixels ({len(data) - tones[ground]} of {len(data)})")
    if "window/page" in images and "window/backdrop" in images:   # the page is calmer and darker than the ground
        page_centre = images["window/page"].getpixel((8, 8))
        ground = max(set(images["window/backdrop"].get_flattened_data()), key=list(images["window/backdrop"].get_flattened_data()).count)
        check(page_centre[3] == 255 and sum(page_centre[:3]) < sum(ground[:3]), "window/page: opaque flat centre a step below the ground")
    if "bar/frame" in images:   # the frame never paints over the inside where the fill goes
        px = images["bar/frame"].load()
        check(px[1, 1] != px[0, 1] and px[0, 0] == px[2, 2], "bar/frame: one rim colour around a different groove")
    for name in ("booktab/normal", "booktab/hover", "booktab/selected"):   # open towards the page
        if name in images:
            px = images[name].load()
            check(all(px[23, y][3] == 255 and px[23, y] != INK for y in range(4, 20)), f"{name}: right side open (no rim towards the page)")
    for name in CONTROL_ICONS:
        if name in images:
            image = images[name]
            w, h = image.size
            corners = [image.getpixel(c)[3] for c in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1))]
            px = image.load()
            edge_ok = all(px[x, y] == INK for y in range(h) for x in range(w) if px[x, y][3] > 0 and any(
                not (0 <= x + dx < w and 0 <= y + dy < h) or px[x + dx, y + dy][3] == 0 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))))
            check(max(corners) == 0 and edge_ok, f"{name}: no plate, closed ink contour")
    if "check/on" in images:   # the mark must survive 0.75: every stroke column at least 2 px of gold
        px = images["check/on"].load()
        gold = {(x, y) for y in range(16) for x in range(16) if px[x, y][:3] in {c[:3] for c in (OLD_GOLD, GOLD_LIGHT)}}
        columns = {x for x, _ in gold}
        check(all(sum(1 for (gx, _) in gold if gx == x) >= 2 for x in columns) and len(columns) >= 7,
              f"check/on: check mark 2 px thick in all {len(columns)} columns")
    for name in ICONS:
        if name in images:
            image = images[name]
            w, h = image.size
            corners = [image.getpixel(c)[3] for c in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1))]
            opaque = sum(1 for c in image.get_flattened_data() if c[3] > 0)
            check(max(corners) == 0 and opaque < w * h * 0.75, f"{name}: no background plate ({opaque} of {w * h} px opaque)")
            px = image.load()
            edge_ok = all(px[x, y] == INK for y in range(h) for x in range(w) if px[x, y][3] > 0 and any(
                not (0 <= x + dx < w and 0 <= y + dy < h) or px[x + dx, y + dy][3] == 0 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))))
            check(edge_ok, f"{name}: silhouette closed by a dark outline")
    if args.render and "window/panel" in images:
        args.render.mkdir(parents=True, exist_ok=True)
        for size in ((320, 160), (800, 700), (1200, 850)):
            stretch(images["window/panel"], 12, size).save(args.render / f"window_panel_{size[0]}x{size[1]}.png")
        print(f"rendered window/panel at 320x160, 800x700, 1200x850 into {args.render}")
    print("RESULT:", "OK" if not failures else f"FAILED ({len(failures)})")
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
