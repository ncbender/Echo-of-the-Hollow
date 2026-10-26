# Class Combat Polish 0.3 – Bericht

Branch `dev/class-combat-polish-03` (von `dev/class-foundation`, `ab6b68e`). Nur lokal, kein Push.

**Anlass** war der erste menschliche Playtest:
- Warrior und Arcanist fühlten sich gut an, der Shadowrunner gemischt.
- Gewünscht war passiver Focus statt Focus durch Treffer.
- Frei einsetzbare Dash-artige Skills neben den zwei Universal-Dashes störten.

**Hinweis:** Beim Start lag eine fremde, uncommittete Änderung in `project.godot` vor. Es war ein
Editor-Resave: die Defaultwerte `aspect="keep"` und `fallback="en"` wurden entfernt und ein Abschnitt
verschoben. Ich habe sie **weder verändert noch committet**.

## Focus-Regeln
| | vorher (0.2) | neu (0.3) |
|---|---|---|
| Regeneration | −8/s (Zerfall) nach 4 s ohne Gewinn | **+8/s immer**: im Kampf, in Bewegung, beim Angreifen; nicht im Tod; ein pausierter Baum läuft nicht |
| Start | 0 | 50 (der Pool wird bei Klassenwechsel und Laden neu erzeugt und nie gespeichert) |
| Normale Treffer | +5, Finisher +8, Weak Point +10, Krit +5 | **0** |
| Haltungsbruch / Kill | +8 / +12 | **0** |
| Maximum | 100 (+ Talente) | unverändert, nie überschritten |
| Skill-Quellen | Expose Weakness +15 je Ziel, Mod „Focus Return“ | unverändert |

**Technik:**
- Bestehender `ClassResourcePool` und `ClassResourceDefinition`, nur die Daten geändert. Die
  Regeneration ist delta-basiert (frame-unabhängig), einmal pro Physik-Tick in `ClassRuntime.step`.
- Neu: keine Regeneration, solange der Spieler tot ist.
- Combat Pressure bleibt bestehen, für das Talent Flurry; sie skaliert nur noch Talent- und
  Skill-Gewinne.

**Balancewert:** 8 Focus/s bei Maximum 100. Das ist der vorgeschlagene Startwert und nicht gespielt.
Execution (40) ist damit etwa alle 5 s aus Regeneration bezahlbar.

## Focus-Talente
| Talent | vorher | neu |
|---|---|---|
| **Focused Strikes** (Bladestorm T2, ID `sr_bs_dance`, vorher „Dancing Blades“) | +5 % Focus-Gewinn pro Rang (wirkungslos ohne Treffergewinne) | Direkte Waffentreffer: **25 % Chance** auf **3 Focus pro Rang** (max. 9). Höchstens **einmal pro Schwung**; Skill-, Status- und ausgelöste Treffer (Essenzen) zählen nie. Chance und Wert sind Daten (`HitTriggerEffect`) |
| Opportunist (Assassin) | Treffer auf Weak Points +2 Focus/Rang | unverändert, passt als Präzisionsbelohnung über Talent |
| Killing Edge (Assassin) | Krits +3 Focus/Rang | unverändert |
| Death Mark (Endtalent) | Kill markierter Ziele +30 Focus | unverändert |
| Assassin's Focus / Patient Hunter | +6 max. Focus/Rang | unverändert |

Die ID `sr_bs_dance` blieb gleich, damit gespeicherte Talentverteilungen gültig bleiben (getestet).
Tooltip-Texte sind Englisch und entsprechen der Funktion.

## Movement-Skill-Audit (alle Skills der drei Klassen)
| Skill | Klasse | Bewegung vorher | Einordnung | Änderung |
|---|---|---|---|---|
| Shadowstep | Shadowrunner | freier 80-px-Schritt zur Maus | war ein freier Dash | **Gap-Closer** (s. u.) |
| Blade Rush | Warrior | freier 70-px-Ansturm | war ein freier Dash | **Gap-Closer**: 110 px, 50°-Kegel, Ankunftsschlag 22, streift Gegner neben dem Weg |
| Shadow Strike | Shadowrunner | freier 50-px-Sprint mit Treffer | dash-artig | **Angriffs-Lunge**: 24 px, danach Schlag (30 px Radius, 100°), legt Weak Point frei |
| Piercing Lunge (Mod für Furious Strike) | Warrior | 45-px-Stoß mit Treffer | Angriff mit Lunge | Länge 36 px (= Schwert-Stoß L-H), gedeckelt |
| Phantom Step (Talent für Shadowstep) | Shadowrunner | Schlag am **Startpunkt** (Fehler: nicht synchron) | Folgeaktion | läuft jetzt **bei Ankunft** |
| Mods Long Charge, Far Step | – | Bewegungsweite +50 % | – | Zielreichweite +50 % |
| Mod Long Strike | – | Weite +50 % | – | Lunge +50 % (36 px), Deckel 40 px |
| Furious Strike, Warbreaker, Battle Cry, Blood Frenzy, Unbound Fury | Warrior | keine | – | unverändert |
| Whirlwind | Warrior | dreht am Ort, Bewegung ×0,8 | keine Dash-Bewegung | unverändert |
| alle 7 Skills | Arcanist | keine | – | unverändert |
| Expose Weakness, Execution, Blade Fan, Smoke Veil, Death Mark | Shadowrunner | keine | – | unverändert |
| Space-Dash | alle | – | Universal Dash | **unverändert** (2 Ladungen, 300 ms, 180 ms iFrames, Mausrichtung) |
| Light-/Heavy-Lunges | alle | – | Attack Lunge (Waffe) | **unverändert** |

Regel im Code: `MoveAction.MAX_LUNGE = 40 px`. Freie Skill-Bewegung gibt es nur bis zu dieser Länge,
auch mit Mods. Längere Bewegung geht nur über `GapCloserAction`. Ein Test prüft alle Skill- und
Mod-Daten darauf.

## Shadowstep-Regeln
- **Ziel:** ein lebender Gegner (oder Dummy) in **130 px** (Far Step: 195) innerhalb eines
  **70°-Kegels** um die Mausrichtung. Der beste Treffer nach Winkel und Distanz gewinnt.
- **Zielpunkt:** direkt vor dem Gegner, Abstand = Körperradien + 2 px (mindestens 16 px). Er muss
  frei sein (kein Wand- oder Körperkontakt).
- **Weg:** Die Kreisform des Spielers (6 px) muss den ganzen Weg ohne Wand und ohne andere Körper
  zurücklegen können (`cast_motion`). Das Ziel selbst ist ausgenommen.
- **Ohne gültiges, erreichbares Ziel:** Abbruch **vor** Kosten und Cooldown, keine Bewegung,
  englische Meldung („No enemy in range in front of you.“, „The way to the target is blocked.“,
  „No room next to the target.“).
- **Bewegung:** über `Player.start_skill_motion` mit 650 px/s und exakter Distanz. Kollision läuft
  über `move_and_slide`. Kein Teleport, keine Dash-Ladung, keine iFrames.
- **Ankunft:** `Player.skill_motion_finished(true)`.
  - Ankunftstreffer: 8 Schaden, 6 Haltung, legt einen **Weak Point** frei, damit die folgende
    Execution sofort nutzbar ist.
  - Danach der Krit-Buff (+15 % für 3 s) und Talentaktionen (Phantom Step).
  - Wird die Bewegung unterbrochen (Trefferreaktion, Tod), entfallen Treffer und Folgeaktionen.
- **Weak Points** sind keine Voraussetzung (sonst wäre der Skill zu selten nutzbar).
- **Bosse:** Funktioniert genauso (getestet mit Grove-Warden-Konfiguration).

## Testergebnisse (nur `user://test_saves/`)
| Lauf | Ergebnis |
|---|---|
| Startprüfung | OK |
| shadowrunner, warrior, arcanist, skills, talents, prologue (erster Lauf) | 48/50. Die 2 Fehlschläge waren die beiden alten Tests, die Focus aus Treffern und den freien 80-px-Shadowstep erwarteten. Sie wurden durch Tests der neuen Regeln ersetzt |
| `class_combat_polish` (neu, 12 Tests) | erst 11/12: Mein Test stellte einen Dummy **in** den Ansturmweg, und Blade Rush lehnte korrekt ab. Dummy neben den Weg gestellt, dann 12/12 |
| movement, dash, lunge, hit_reaction, light_attack, heavy_attack, combo, skills, talents, warrior, arcanist, shadowrunner, prologue, presets, essences, item_effects, status_effects, class_ui, ui_layout, save, classes | **170/170** |
| Keine volle Suite | kein Anlass: geänderte Systeme = Skill-Ausführung, Player-Skill-Bewegung, Shadowrunner-Daten |

**Inhalte der Suite `class_combat_polish`:**
- Focus-Daten
- Regeneration idle und im Kampf, ohne Treffergewinn
- Maximum
- Tod, Respawn und Klassenwechsel
- Focused Strikes: nur direkte Waffentreffer, einmal pro Schwung trotz mehrerer Ziele. Skill-,
  ausgelöste (Essenz-) und Status-Treffer lösen nie aus
- Shadowstep: ohne Ziel, Ziel hinter dem Spieler, außer Reichweite, Wand dazwischen
- Shadowstep mit Ziel: Ankunft, keine Dash-Ladung, keine iFrames, Weak Point, Buff, Dash danach
  unverändert
- Shadowstep gegen Grunt und Boss
- Blade Rush ohne und mit Ziel, inklusive Streifen
- Lunge-Länge und Deckel
- Datenprüfung aller Skills und Mods
- Save/Load

**Grafischer Test im Spielfenster** (`class_playtest.gd -- --polish`, Arena, 1600×900, fester 60-Hz-Takt): **9/9**.
- Focus +7,9 in 1 s idle
- Shadowstep ohne Ziel abgelehnt, mit Grund „No enemy …“, ohne Kosten und Bewegung
- Shadowstep auf einen echten Grunt: Abstand 19 px, Weak Point gesetzt, keine Dash-Ladung
- Im Kampf +7,9 Focus/s ohne Treffergewinn
- Space-Dash zur Maus
- Blade Rush zum Grunt

**Dabei gefundener Fehler im Testskript** (nicht im Spiel): `physics_frame` feuert vor der Verarbeitung
der Nodes, das Skript löschte Tastenflanken zu früh. Behoben. Der erste „kein Ziel“-Check war wegen
leerem Focus abgelehnt worden; der Grund wird jetzt ausdrücklich geprüft.

**Prolog-Fensterlauf** (`-- --prologue`, enthält den Shadowrunner-Trial mit der neuen Focus-Regel):
16/16. Screenshots liegen in `tests/output/classes/polish_*.png`.

**Kein menschlicher Playtest** dieser Änderungen. Spielgefühl und Werte sind nicht bewertet.

## Bekannte Einschränkungen
- Zielerfassung nach Mausrichtung (Kegel) statt Maus-Position oder explizitem Ziel-Lock. Bei
  mehreren Gegnern im Kegel gewinnt die beste Kombination aus Winkel und Nähe.
- Steht ein anderer Gegner direkt im Weg, wird der Gap-Closer abgelehnt; kein Umweg-Pathfinding.
- Gap-Closer haben keine eigenen VFX/SFX, nur Ziel-Ring, Spur und Treffer.
- Die Shadowrunner-Trial ist weiterhin sehr leicht (siehe 0.2-Bericht).
- Werte wie Regeneration 8/s, Reichweiten 130/110 px und Kegel 70°/50° sind Startwerte.

## Commits
- `0e73031` Class Combat Polish 0.3: passive Focus regeneration, Focused Strikes, target-bound gap
  closers (Code, Daten, Tests, Design-Dokumente)
- Bericht-Commit (dieses Dokument)

## Menschlicher Playtest (kurz)
1. Branch `dev/class-combat-polish-03`. Shadowrunner freischalten (Prolog oder vorhandener Spielstand),
   mit **F10** auf ca. Level 10.
2. **Focus:** Nichts tun und beobachten, ob sich Focus in etwa 12 s füllt. Im Kampf prüfen, ob sich der
   Rhythmus (Execution ~ alle 5 s) gut anfühlt und ob Treffer wirklich nichts mehr geben.
3. **Shadowstep (R):**
   - auf einen Gegner vor dir: Bist du davor, und ist der Weak Point gesetzt?
   - ins Leere und hinter eine Säule: Wird er abgelehnt, ohne dass Focus oder Cooldown verloren gehen?
   - Danach **Execution (F)** als Kombination testen.
4. **Space-Dash:** Fühlt er sich unverändert an (zwei Ladungen)?
5. **Warrior Blade Rush (R):** Ist der Ansturm auf einen Gegner kraftvoll genug? Stört die Ablehnung
   ohne Ziel?
6. Optional: Talent **Focused Strikes** (Bladestorm Tier 2) skillen. Sind die Bonus-Focus-Procs bei
   Light-Ketten spürbar, aber nicht dominant?
