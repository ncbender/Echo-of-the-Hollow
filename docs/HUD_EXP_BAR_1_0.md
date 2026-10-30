# HUD EXP Bar 1.0

> **Combat HUD UX 2.0 (`COMBAT_HUD_UX_2_0.md`):** Maße und Inhalt sind unverändert (426 × 14, 6 px unter der
> Kampfleiste, nur Prozent oder `MAX`). Links daneben steht das Klassenlevel als eigenes Abzeichen `HudBadge`
> (52 × 14, „Lv n“), rechts das Pressure-Abzeichen. `_combat_column` steht jetzt in `GameHud._combat_unit` zwischen
> den Gefäßen.

Genau ein EXP-Balken, unten mittig direkt unter der Kampfleiste. Keine Änderung an XP-Kurve,
Levelgrenzen, Talentpunkten, Kampf, Loot, Quests, Save (v15) oder Kamera.

## Platz und Maße (Design-px)
- `GameHud._combat_column` (VBox, Abstand `UiTheme.XP_BAR_GAP` = 6) im unteren Mittelblock:
  `CombatBar` (`_combat_row`), darunter `XpBar` (`HudXpBar`). Toasts und Interaktionshinweis bleiben
  darüber im selben Block wie bisher (Abstand 8).
- `UiTheme.XP_BAR_SIZE` = 426 × 14 = Breite der Kampfleiste (2 × 64 + 6, 18, 4 × 64 + 3 × 6), zentriert.
- Unterkante = Bildschirmrand − 16 (wie die Menüleiste); die Kampfleiste liegt dadurch 20 px höher.

## Anzeige
- Nur der Fortschritt im aktuellen Level der aktiven Klasse (`CharacterClasses.active_class_id`,
  `get_level`, `get_xp`, `xp_to_next`; keine eigene XP-Logik): ganze Prozent, abgerundet und höchstens
  „99%“ vor dem Aufstieg; am Maximallevel „MAX“ (voller Balken). Keine absoluten XP-Zahlen.
- Aktualisiert pro Frame (wie `PlayerFrame`), zeichnet nur bei Änderung neu: XP-Gewinn, Aufstieg
  (zurück auf 0 %), Klassenwechsel und Laden ändern die Anzeige sofort.
- Text: CaptionLabel 13, PARCHMENT, Outline 4 (wie die kleinen PlayerFrame-Balken), mittig im Balken.
- Füllung `UiTheme.XP` (= BRONZE_DIM, damit die Zahl lesbar bleibt), ganze Designpixel innerhalb des
  1-px-Rahmens.
- Art: die gemeinsamen `bar/frame` und `bar/fill` (Tönungsmaske in EXP-Bronze) aller Leisten
  (HUD Bars Visual Integration 1.0, `docs/HUD_BARS_VISUAL_INTEGRATION_1_0.md`); ohne Dateien prozedural.

## Verhalten
- Großes Fenster offen: blendet zusammen mit der Kampfleiste aus (`modulate`, Layout bleibt).
- Dialog: verschwindet mit dem unteren Mittelblock.
- `MOUSE_FILTER_IGNORE` (Balken und Spalte): nie ein Klickziel, kein Input-Blocker.

## Offen
- Klassen-Trial: Angezeigt wird die Trial-Klasse (temporär, ohne XP), also 0 %.
- Schriftwahl (`UI Font Comparison 1.0`) steht noch aus; Größe 13 ist nicht rasterbündig für Pixelfonts.

## Tests
`tests/integration/test_hud_xp_bar.gd` (5): ein Balken, Lage/Breite/Abstand/Ausrichtung und keine
Überlappung (Menü, Loot-Feed, Skill-/Quick-Leiste, Speicheranzeige, Toasts, Hinweis) bei 100/125/150 %;
0/50/99 %, Aufstieg, nie 100 %, MAX; Klassenwechsel; Save/Load; Fenster und Dialog.
Angepasst: `test_ui_layout_lock` (Hinweis und Kampfleiste haben jetzt `CombatColumn` als Zwischenknoten).
Fenster-Screenshots: `ui_gallery.gd --only=hud_combat,journal` bei 1080p/1440p/4K × 100/125/150 %.
