# Crafting Foundation 0.1 – Bericht (Resonanzschmieden, Phasen A–G)

**Engine:** Godot 4.7.2 · **Branch:** `dev/crafting-foundation` (von `b71ae58`, lokal, nicht gepusht)
Ausgangsstand verifiziert: `beb0317` (Combat Polish 0.2), `a0b1e64` (Editor-Bereinigung) und
`b71ae58` (UI Foundation 0.1) sind enthalten, das Arbeitsverzeichnis war sauber.
Combat-Timings, Dash-Regeln, Bewegung und Waffenreichweiten sind **unverändert**. Die UI Foundation
wurde nicht neu gebaut, sondern genutzt. Design und Werte: `CRAFTING_DESIGN.md`.

## 1. Status der Phasen
| Phase | Inhalt | Status | Commit |
|---|---|---|---|
| A | Datenmodell, Instanz-Crafting-Zustand, `ItemStats`, Save v3 + Migration | ✅ vollständig | `45ac28b` |
| B | 3 Materialien, 12 Affixe, Affix-Pool, neue Stats im Hit-Pipeline | ✅ vollständig | `78b37a8` |
| C | Prägen, Erweitern, Umformen als Transaktionen; 3 Währungen; Unique-Schutz | ✅ vollständig | `e27ed3e` |
| D | Storm Wolf, Stone Golem, Thunderquake-Resonanz; Binden/Ersetzen/Extrahieren | ✅ vollständig | `f105267` |
| E | Sockel (Garnet, Rune of Impact), Socket Chisel, Qualität mit Forge Crystal | ✅ vollständig | `80e0a56` |
| F | Item-Evolution (Stormcaller Fang, 3 Stufen, 2 Mutationspfade) | ✅ vollständig | `5a6ca80` |
| G | Resonance Forge an der Schmiede, Vertical Slice, Playtests | ✅ vollständig | `bb3047a` |
| Doku | dieser Bericht + Systemdokumente | ✅ | letzter Commit |

**Teilweise oder nur vorbereitet:**
- Gleichwertigkeit von Loot und Crafting (Regel 1) ist nur strukturell vorbereitet, denn es gibt
  noch keinen Loot-Generator mit Affixen.
- Essenzen und Crafting-Währungen kommen nur aus dem Debug-Kit (F4); bestehende Drops habe ich
  nicht verändert.
- Attack Speed (Affix „Swift“, Storm-Ore-Prägung) wird berechnet und angezeigt, wirkt aber bewusst
  nicht auf die Combat-Timings.

## 2. Tatsächliche Implementierung und Entscheidungen
- **Keine Parallelsysteme:**
  - Crafting erweitert `ItemDefinition` (Sub-Resource `CraftingProfile`), `ItemInstance`,
    `GameDatabase`, `Character._stat_sources`, `ItemEffectRunner`, `CharacterStatModifier` und
    die Bridge.
  - Neue Klassen liegen in `scripts/rpg/crafting/` (Definitionen, `AffixPool`, `CraftingService`,
    `ItemStats`, `ItemEvolution`, Request/Preview).
- **`ItemStats`** ist die einzige Stelle, die Crafting-Zustand in Stats und Effekte übersetzt.
  Deshalb gibt es keine doppelte Anwendung beim Ausrüsten, beim Klassenwechsel oder nach dem Laden.
- **Transaktion** (`CraftingService`):
  - `execute()` baut zuerst exakt die Vorschau. Abgelehnte Vorgänge kosten nichts.
  - Es wird genau einmal gewürfelt, dann werden Kosten abgezogen und das Item geändert.
  - Eine Item-Revision schützt gegen Doppelausführung, ein Re-Entrancy-Guard gegen verschachtelte
    Aufrufe.
  - Kosten dürfen keine Ausrüstung sein (validiert), daher nie Itemzerstörung.
- **Determinismus:** Der Zufallsgenerator wird injiziert. Der Pool ist nach Affix-ID sortiert, also
  liefert derselbe Seed dasselbe Ergebnis.
- **Combat-Integration** nur über Hooks:
  - Neue Stats laufen über den bestehenden AttackModifier.
  - Essenzen, Runen und Mutationen sind `ItemEffect`s. Die API wurde um
    `get_attack_modifiers_for(runner, key)` ergänzt; Modifier halten den Runner per `WeakRef`, um
    einen Referenzzyklus zu vermeiden.
  - Der Runner verwaltet Markierungen (für die Resonanz), geteilten Effektzustand (einmal pro
    Schwung, auch bei zwei Trägern) und Stats (für Schockschaden).
  - Knockback-Boni skalieren die Knockback-Distanz aus Combat Polish 0.2 genau einmal.
- **Daten** liegen als `.tres` unter `data/crafting/`. Erzeugt habe ich sie einmalig mit einem
  Godot-Generator, der danach gelöscht wurde; die `.tres` sind die Quelle. Neue Items liegen unter
  `data/items/`.

## 3. Save-Version und Migration
- Die Save-Version steigt von 2 auf **3**.
- Migration 2→3:
  - Alle Items erhalten `ilvl` 1 und `quality` 0.
  - Das vorbereitete `essence`-Feld wird zur Liste `essences`, unbekannte Inhalte wandern nach
    `progress.legacy_essence`.
  - Affixe ohne ID werden als `legacy` markiert und wirken unverändert weiter.
  - Es wird nichts neu gewürfelt.
- Nach dem Laden begrenzt `ItemStats.sanitize` Qualität und Stufe. Überzählige Essenzen und Sockel
  werden geparkt, nicht gelöscht, und es gibt Warnungen. JSON-Zahlentypen werden normalisiert, damit
  der Roundtrip bitgleich ist.
- UI-Einstellungen bleiben in `user://settings.cfg`. Tests nutzen nur `user://test_saves/`.

## 4. Inhalte
- **Materialien und Affixe:** siehe Tabellen in `CRAFTING_DESIGN.md` (Bloodsteel, Storm Ore,
  Frost Glass; 12 Affixe mit je 3 Tiers).
- **Basen und Testitem:** Forged Blade, Forged Greatsword (je 4 Affix-, 2 Essenz- und 2 Sockelplätze,
  Itemlevel 12), Stormcaller Fang (evolvierend).
- **Währungen:**
  - Crafting: Imprint Shard, Transmutation Core, Socket Chisel
  - Katalysator: Focus Catalyst
  - Upgrade: Forge Crystal, Awakening Stone
  - Extraktion: Essence Siphon
- **Essenzen und Resonanz:**
  - Storm Wolf (Entladung bei Heavy-Finishern, markiert Ziele)
  - Stone Golem (+60 % Haltung bei voll aufgeladenen Heavy-Finishern)
  - Thunderquake (nächster Treffer auf ein markiertes Ziel: +50 % Haltung)
  - Material-Affinität: ×1,25
- **Sockel und Qualität:** Garnet (+20 Max Health), Rune of Impact (Heavy +25 % Knockback,
  +15 % Haltung). Qualität 0–20 wirkt mit +1 % je Punkt nur auf Basiswerte.
- **Evolution:**
  - Stufe 2 bei 60 Item-EP.
  - Stufe 3 bei 150 EP plus Awakening Stone, mit Wahl zwischen Pfad A Storm Charge und Pfad B
    Steadfast. Die Wahl ist permanent.
  - Item-EP kommen nur von echten Gegnern, nur für das Main-Hand-Item, und sind getrennt von der
    Waffenbeherrschung.
- **Uniques:** Crushing Oath erlaubt ausschließlich Qualität und einen Sockel. Ihr Kern wird in der
  UI als „Core (protected)“ angezeigt.

## 5. Ausgeführte Tests (tatsächlich gelaufen, chronologisch)
| Phase | Lauf | Ergebnis |
|---|---|---|
| A | crafting_save (neu) | 4/5 ❌ – JSON macht Ganzzahlen zu Floats (`tier 2.0`) → Typnormalisierung beim Laden → 5/5 ✅ |
| A | save, inventory, equipment, item_effects, classes, pickup, world, project + Startprüfung | 64/64 ✅, OK |
| B | Datengenerator: Typinferenz-Fehler im neuen Stat-Code, Array-Zuweisung im Generator → behoben; Startprüfung | OK |
| B | affix_pool (neu), crafting_stats (neu) | 11/11 ✅ |
| B | equipment, classes, item_effects, mastery, save, project, inventory, ui_layout | 66/66 ✅ |
| C | crafting_ops (neu) | 11/11 ✅ |
| C | project, equipment, save, item_effects, crafting_save | 37/37 ✅ |
| D | essences (neu); Lauf auf Speicherlecks geprüft (keine Meldung) | 9/9 ✅ |
| D | Startprüfung; item_effects, crafting_ops, crafting_save, project, mastery | OK; 37/37 ✅ |
| E | sockets_quality (neu) | 6/6 ✅ |
| E | crafting_ops, essences, project, item_effects | 30/30 ✅ |
| F | evolution (neu) | 6/7 ❌ – Formatstring im Test (`% o`) → 7/7 ✅ |
| F | mastery, classes, item_effects, essences, crafting_ops, sockets_quality, project | 57/57 ✅ |
| G | Startprüfung | ❌ `set_material()` kollidierte mit `CanvasItem.set_material` → in `choose_*` umbenannt → OK |
| G | crafting_loop (neu, E2E headless) | 1/1 ✅ |
| G | base, world, loop, ui_layout, project, input, crafting_loop | 25/25 ✅ |
| G | ui_layout mit Forge bei allen UI-Skalierungen | 2/2 ✅ |
| Abschluss | F4-Kit um Schmiede-Baumaterial ergänzt (Anleitung ohne F7); Startprüfung; crafting_loop, ui_layout, project | OK; 6/6 ✅ |

**Nicht ausgeführt:**
- Die reinen Combat-Suites: dash, combo, movement, light/heavy_attack, collision, hit_reaction,
  knockback, lunge, combo_reach, weapon_switch, combat_data, hits, enemy. Combat-Code, -Daten und
  -Timings sind unverändert.
- Der erweiterte `CharacterStatModifier` wirkt nur über die Bridge und mit nicht-neutralen Stats;
  das decken crafting_stats, essences, sockets_quality und evolution ab.
- gathering wurde nicht ausgeführt.
- Kein vollständiger Testlauf.

## 6. Visuelle Playtests (Fenster, Primärmonitor 4K)
1. **`crafting_playtest.gd`:** Resonance Forge bei 1920×1080 und 3840×2160, jeweils mit 100 % und
   150 %.
   - Geprüft: Itemliste mit Tooltip, Wahrscheinlichkeitstabelle, Umformen mit Fokus,
     Essenzen und Resonanz, Sockel, Qualität, Mutationswahl.
   - Automatische Checks: nichts außerhalb des Bildes, nichts gequetscht, „Confirm“ erreichbar
     (bei 150 % per Scrollen), Idle-Frame-Zeit 8 ms (kein Rebuild-Loop).
   - Ein echter Mausklick auf „Confirm“ hat die Qualität erhöht.
   - Erster Lauf: 55/57. Der Tooltip bei 150 % wurde nicht gefunden, weil der Testcursor bei
     y = −622 landete: Das Fenster war durch ein verzögertes `ensure_control_visible` noch
     gescrollt (Testskript). Nach dem Reset: **61/61 ✅**.
2. **`crafting_playtest.gd --loop`:**
   - Ablauf: F4 → G an der Schmiede → Prägen, Erweitern, Umformen, zwei Essenzen, Sockel und Rune,
     Qualität per echtem Klick → ausrüsten → Arena.
   - Im Arena-Kampf mit voll aufgeladenem L-L-H griffen Entladung, Golem-Bonus und Rune, danach
     die Resonanz.
   - Abschluss: F6 → neuer Charakter → F9; dieselbe Instanz mit identischen Eigenschaften, Effekte
     wieder aktiv.
   - Erster Lauf: 16/17. Der Folgetreffer erreichte den Grunt nicht mehr, weil der Finisher ihn auf
     52,5 px weggestoßen hatte. Das Skript rückt jetzt wie ein Spieler nach → **17/17 ✅**.
     Das ist eine echte Balance-Beobachtung, siehe Abschnitt 7.
3. **`loop_playtest.gd --build-only`** (erweitert): Die Schmiede öffnet die Forge, und „Smithy
   recipes“ führt zum Rezept zurück ✅.

Screenshots liegen in `docs/screenshots/crafting_foundation_01/`, alle in `tests/output/crafting/`.
Ein **menschlicher** Playtest hat nicht stattgefunden.

## 7. Fehler, Einschränkungen und Risiken
- **Keine bekannten funktionalen Fehler.**
- **Resonanz-Timing:** Voll aufgeladene Finisher stoßen Standardgegner weit weg (~52 px mit
  Frostglas). Die Markierung hält 2 s, man muss also nachsetzen. Vor einer Änderung bitte im
  Playtest bewerten.
- **Debug-Overlay:** Die FPS-Anzeige fiel während der skriptgesteuerten UI-Umbauten kurz auf
  ~15. Im Leerlauf mit offener Forge sind es 8 ms pro Frame. Die Forge baut sich bei jeder Auswahl
  komplett neu auf; bei deutlich mehr Items wäre ein inkrementelles Update sinnvoll.
- **Herkunft der Ressourcen:** Es gibt keine Loot- oder Drop-Quelle für Essenzen und Währungen
  außer F4.
- **Mehrdeutige Begriffe:** „Blutung“ und „Kälte“ sind bewusst über vorhandene Mechaniken
  umgesetzt (Life on Hit, Haltung, Knockback), nicht als eigene Statussysteme.
- **Kosten** sind flach, Qualität kostet 1 Kristall je Punkt. Die Balance ist unbestätigt.
- **Einmalige Entscheidungen:** Hauptmaterial und Mutationspfad sind permanent, ein Respec ist in
  0.1 nicht vorgesehen.

## 8. Lokale Commits
`45ac28b` A · `78b37a8` B · `e27ed3e` C · `f105267` D · `80e0a56` E · `5a6ca80` F · `bb3047a` G ·
Doku-Commit. Kein Push.

## 9. Menschlicher Crafting-Playtest – Anleitung
```powershell
cd "C:\Users\ncbha\GameDev\Echo of the Hollow"
git switch dev/crafting-foundation
..\tools\godot\Godot_v4.7.2-stable_win64.exe --path .
```
1. **F4** drücken: Crafting-Kit (Basen, Materialien, Währungen, Essenzen, Einlagen und das
   Baumaterial der Schmiede). Nicht zusätzlich F7 drücken, sonst ist das Inventar zu voll.
2. **Schmiede bauen:** auf einem gestrichelten Bauplatz G → Build (Smithy).
3. An der gebauten Schmiede **G** drücken: Resonance Forge.
   - Forged Blade wählen und prägen: Material wählen, Chancen vergleichen, optional Fokus.
   - Erweitern, dann einen Affix anklicken und umformen.
   - Storm Wolf und Stone Golem binden (die Resonanz erscheint in den Details).
   - Sockel öffnen, Rune of Impact einsetzen, Qualität erhöhen.
4. **I** → Blade ausrüsten → Nord-Durchgang in die Arena → F2 (Gegner) → L-L-H, Heavy voll halten
   → blauer Entladungsring → nachsetzen (Resonanz).
5. **F6** speichern, Spiel neu starten, **F9** laden → Forge erneut öffnen und prüfen, dass die
   Werte identisch sind.
6. **Evolution:** Stormcaller Fang ausrüsten und im Wald oder in der Arena kämpfen (60 bzw. 150
   Item-EP). An der Forge entwickeln; für Stufe 3 einen Mutationspfad wählen.

**Besonders prüfen:**
- Verständlichkeit der Chancen-Tabelle
- Lesbarkeit bei 150 % (O → UI scale)
- Gefühl der Entladung und ob die Resonanz-Markierung lange genug hält
- Kosten
- Ob die Endgültigkeit von Material und Mutation verstanden wird

Automatisierte Tests:
```powershell
.\tools\run_tests.ps1 -Suite "crafting_save,affix_pool,crafting_stats,crafting_ops,essences,sockets_quality,evolution,crafting_loop"
..\tools\godot\Godot_v4.7.2-stable_win64_console.exe --path . -s res://tests/playtest/crafting_playtest.gd
..\tools\godot\Godot_v4.7.2-stable_win64_console.exe --path . --fixed-fps 60 -s res://tests/playtest/crafting_playtest.gd -- --loop
```
