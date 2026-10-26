# Combat Defense & Feedback 0.4 – Bericht

Branch `dev/combat-defense-feedback-04` (von `dev/class-combat-polish-03`, `94f7423`). Nur lokal, kein
Push.

**Hinweis zu `project.godot`:** Die bereits gemeldete fremde, uncommittete Änderung (Editor-Resave) liegt
weiterhin vor. Sie wurde **nicht verändert und nicht committet**. Diese Arbeit kommt ohne Änderungen an
`project.godot` aus: Shift war schon als `defensive` gebunden, und der Audio-Bus wird zur Laufzeit
angelegt.

## Status der Phasen
| Phase | Inhalt | Status |
|---|---|---|
| A | Focus 8 → 6/s | ✅ |
| B | Block & Parry auf Shift, Defense Profiles, Angriffs-Flags, Boss-Grenzen | ✅ |
| C | Skill-VFX aller drei Klassen, Status-Marker, Verteidigungs- und Poise-Break-Feedback | ✅ (prozedurale Platzhalter, keine Pixel-Art-Assets) |
| D | Combat-Audio-Schicht | ✅ funktionsfähig mit **synthetischen Platzhaltern**; echte Assets fehlen |
| E | Lesbarkeit, HUD-Zeile, Integrations- und Fenstertests | ✅ |

## Focus-Regeneration
| | vorher (0.3) | nachher (0.4) |
|---|---|---|
| Passive Regeneration | 8/s | **6/s** |
| Unverändert | – | Max. 100, Start 50, im Kampf und in Bewegung, nicht im Tod, keine Treffergewinne ohne Talente, Expose Weakness +15, Focused Strikes und andere Talente |

## Defense Profiles (`data/combat/defense/`)
| Profil | gilt für | Parry-Fenster | Parry-Bogen | Anti-Spam ab Druck | Whiff-Recovery | Block | Block-Bogen | Bewegung | Block-Recovery | Parry-Haltung | Counter |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Sword Guard | Einhandschwert | 150 ms | 120° | 550 ms | 300 ms | −45 % Schaden, Knockback ×0,5, Angreifer −4 Haltung | 120° | ×0,5 | 150 ms | 30 | 1 s, ×1,5 |
| Heavy Guard | Zweihandschwert | 130 ms | 110° | 650 ms | 400 ms | −25 %, ×0,6, −6 | 100° | ×0,4 | 250 ms | 45 | 1 s, ×1,6 |
| Shield Guard | Oak Shield in der Nebenhand (überschreibt die Waffe) | 120 ms | 140° | 600 ms | 300 ms | −65 %, ×0,35, −6 | 160° | ×0,6 | 100 ms | 20 | 0,8 s, ×1,3 |

Guard Break führt bei allen Profilen zu 0,6–0,7 s Recovery. Es gibt keine Stamina; die Begrenzung
übernehmen Reduktion < 100 %, Verlangsamung, Recoveries, Guard Break und Unblockables. Die Werte sind
Startwerte und nicht von Menschen gespielt.

## Block-/Parry-Regeln
**Ablauf auf Shift:**
- **Drücken** öffnet das Parry-Fenster.
- **Halten** führt danach in den Block.
- **Loslassen** löst eine Recovery aus (Whiff bzw. Block-Recovery).
- Halten öffnet nie ein neues Fenster.

**Start:** nur, wo ein Dash-Cancel erlaubt ist.
- Aufladen bricht er ab.
- Einen Heavy-Angriff in seiner aktiven Phase nicht.
- Er erzeugt also keinen neuen Angriffscancel.

**Während Verteidigung:** keine Angriffe und Skills, langsamere Bewegung.

**Beenden:**
- Ein Dash beendet die Verteidigung. Dash-iFrames bleiben exakt 11 Ticks (180 ms) und werden nie
  gestapelt.
- Ebenso unterbrechende Reaktionen und der Tod.

**Auflösung:** vor dem Schaden über `Hurtbox.hit_filter`, nur aus dem Frontbogen um die Mausrichtung. Ein
bereits gelandeter Treffer ist nicht nachträglich parierbar.

**Parry:**
- 0 Schaden, kein Knockback, keine Reaktion.
- Der Angreifer verliert Haltung.
- Normale Gegner werden unterbrochen und 0,5 s benommen.
- Counter-Fenster für den nächsten eigenen Waffentreffer.
- Feedback: Stern, Blitz, „PARRY“, Ton, HUD „COUNTER!“.

**Block:** Schaden und Knockback reduziert, Reaktion höchstens FLINCH, Funken, Ton.

**Guard Breaking:** Der Block scheitert. Voller Treffer, „GUARD BREAK“, Ton, Recovery.

**Unblockable:** ignoriert jede Verteidigung.

## Geprüfte Gegnerangriffe
| Angriff | Flags | geprüft mit |
|---|---|---|
| Grunt Swipe | blockbar, parierbar | Parry im Fenster, Block, Whiff, von hinten, echter Angriff im Fenster (Headless und Fenster) |
| Grunt Slam | blockbar, parierbar, **Guard Breaking** | Guard Break beim Block |
| Grove Warden Swipe (neue Datei `grove_warden_attacks.tres`, gleiche Timings und Werte) | nur blockbar | Block statt Parry im Fenster |
| Grove Warden Crushing Slam | **unblockable** | voller Schaden im Parry-Fenster, Telegraph und Warnton im Fenster |

**Boss-Grenzen (Grove Warden):**
- Parry gibt nur 0,3× Haltung und unterbricht nie (`parry_interrupts = false`).
- Ein Haltungsbruch bleibt nach den normalen Regeln möglich, ein Dauer-Lock nicht.

## Neue Combat-Events
| Ereignis | Quelle | genutzt von |
|---|---|---|
| `DefenseComponent.parry_started` / `parried` / `blocked` / `guard_broken` | Player | FX, Audio, HUD |
| `Enemy.parried` | Gegner | Blitz am Gegner |
| `Player.skill_motion_finished` | (seit 0.3) | Ankunfts-Effekte |
| `HitData`-Tags `parried`, `blocked`, `guard_break`, `unblockable`, `counter` | Trefferstrom | Klassenlaufzeit (parierte Treffer kosten keinen Pressure und geben keine Rage), Tests |

Neue Treffer, die beim Gegner ankommen (Parry- und Block-Haltung), sind TRIGGERED mit Tiefe 1. Es gibt
also keine neue Kette im Ereignisstrom. Der Kettenschutz des Runners bleibt unverändert und ist durch die
volle Suite abgedeckt.

## Implementierte VFX (`CombatFx`, prozedural)
| Klasse | Effekte |
|---|---|
| Warrior | Battle-Cry-, Blood-Frenzy- und Unbound-Fury-Aura (endet mit dem Buff); Furious-Strike-Sichel; Blade-Rush-Kreuzschlag bei Ankunft; Warbreaker-Ring + Funken; Whirlwind-Ring; Talent-Bursts (Worldbreaker, Aftershock) mit Funken |
| Arcanist | Glyphe beim Wirken; Stern-Treffer; Splitter-Projektile (Frostbind, Astral Lance) und rotierende Orb-Projektile; Detonations-Stern + Ring in Markenfarbe; Chill-Marker (Tönung, Kristalle, Ring) |
| Shadowrunner | Nachbilder entlang Shadowstep und Blade Rush; violette Hiebe; Weak-Point-Fadenkreuz; karmesinroter Execution-Kreuzschlag + Verbrauchs-Burst; Messer-Projektile (Blade Fan); Thousand-Cuts-Klingenring (Talent) |
| Allgemein | Poise Break (Stern, Ring, „BREAK“); Parry/Block/Guard Break; Schutzhaltung als Bogen vor dem Spieler (hell = Parry-Fenster); keine „0“-Schadenszahl bei Parry |

**Status-Marker** (nach Form, nicht nur nach Farbe):
- Arcane Mark: eine kreisende Rune pro Stack
- Weak Point / Death Mark: Fadenkreuz
- Bleeding: Tropfen
- Chill: Tönung + Kristalle
- Smoked: Rauch

Dazu die Punktzeile mit Stack-Strichen. Die Marker blinken vor dem Ablauf und verschwinden bei Verbrauch
und Tod.

**Regeln:**
- Feste Lebensdauer, Selbst-Freigabe.
- Folge-Effekte enden mit Buff, Klassenwechsel und Tod.
- Ein Szenenwechsel entfernt alles (getestet).
- Keine Vollbild-Blitze; Boden-Effekte liegen unter den Figuren.
- Hitboxen und Schaden werden nie verändert.

## Sounds (`CombatAudio` + `SynthSounds`)
**Vorhanden** sind synthetische Platzhalter, zur Laufzeit erzeugt, ohne Dateien und ohne Downloads.
Cues:
- `hit_light`, `hit_heavy`, `poise_break`
- `block`, `parry`, `guard_break`
- `warrior_skill`, `arcane_cast`, `shadow_skill`
- `arcane_detonate`, `execution`, `unblockable_warn`

**Fehlt:** echte, lizenzierte Audio-Assets. Austausch pro Cue über `CombatAudio.files` ohne Codeänderung
an den Auslösern.

**Verwaltung:**
- Ein Layer pro Map, mit der Map freigegeben.
- 12 positionale Stimmen auf dem Bus „SFX“.
- Gleicher Cue höchstens alle 50 ms und 3-fach überlagert. Ein Schwung gegen drei Ziele ergibt einen
  Ton (getestet).
- Jede weitere gleichzeitige Stimme ist 1,5 dB leiser.
- Pausieren wird von Godots `AudioStreamPlayer2D` übernommen (pausierbarer Baum); nicht eigens getestet.

**Lautstärke:** „Effects volume“-Regler im Options-Fenster, gespeichert in `user://settings.cfg`
(Abschnitt `audio`, nie im Spielstand).

## Statusanzeigen
- **HUD-Klasseninfo:** „Shift: Sword Guard (block −45 %)“ und „COUNTER!“ während des Counter-Fensters.
- **Steuerungshinweis:** um „Shift block/parry“ ergänzt.

## Ausgeführte Tests (nur `user://test_saves/`)
| Lauf | Ergebnis |
|---|---|
| A: class_combat_polish, shadowrunner, prologue | 26/26 |
| B: `defense` (neu, 10) | erst 6/10 |
| B: Regression (defense, dash, light/heavy_attack, combo, combo_reach, lunge, hit_reaction, hits, enemy, knockback, collision, movement, input, skills, shadowrunner, warrior, class_combat_polish, equipment, item_effects, essences, classes) | **198/198** |
| B: world, loop, project, pickup | 15/15 |
| C: Regression (defense, skills, Klassen, status_effects, talents, hits, enemy, item_effects, essences, prologue) | 112/112 |
| C: `combat_feedback` (neu, 5) | 5/5 |
| D: `combat_audio` (neu, 7) | erst 6/7 (Testfehler: ohne Player ein Player-Tick), dann mit combat_feedback, settings, ui_layout, defense **33/33** |
| E: **volle Suite** (begründet: Player, Hurtbox-Trefferfilter, Gegner und Settings sind zentral geändert) | **381/381 in 51 Suites** |

**Die vier Fehlschläge im ersten `defense`-Lauf:**
1. **Echter Fehler im Code:** Die Angriffssperre während der Verteidigung fehlte, weil meine erste
   Ersetzung nicht gegriffen hatte. Aus der Recovery heraus konnte ein Angriff starten. Behoben.
2. **Daten:** Die Schildprofil-Zeile stand vor der `script`-Zeile und wurde ignoriert. Behoben.
3. **Zwei Testfehler:** eine iFrame-Zählung mit falschem Offset und ein Combo-Fenster, das noch offen war.
   Behoben; danach 10/10.

## Grafische Prüfungen (Fenster)
| Playtest | Ergebnis |
|---|---|
| `feedback_playtest.gd` (1600×900, fester 60-Hz-Takt) | **15/15** (erster Lauf 14/15: Der Blade-Rush-Check kam vor der Ankunft, Wartezeit angepasst). Parry und Block gegen einen echt angreifenden Grunt, Unblockable-Telegraph und Warnton, zwei Runen für zwei Marken, Detonation, Chill, Weak Point, Execution, Bleeding, Poise Break. Sechs Gegner mit Effekten: **8,3 ms pro Frame**. Alle Einmal-Effekte aufgeräumt; nach Szenenwechsel keine Effekte. Screenshots selbst angesehen: PARRY + COUNTER!, Runen, „!!“ + Zickzack, Fadenkreuz gut lesbar. |
| `class_playtest.gd` (Klassen-UI und HUD bei 1920×1080 und 3840×2160, je 100 % und 150 %) | 41/41 in 4 von 6 Läufen. Einmal kein Hover-Tooltip bei 1080p/150 %, einmal ein verschluckter echter Mausklick (der offene Tooltip lag über dem Button). Klick-Ablauf korrigiert; danach 3 von 3 Läufen OK. Der einzelne Tooltip-Aussetzer trat nicht mehr auf und bleibt als mögliche Unsicherheit des Echt-Maus-Harness notiert |
| `ui_playtest.gd` (voll: 720p–4K, alle UI-Skalierungen, Options mit Lautstärkeregler) | **117/117** |

**Kein menschlicher Playtest.** Das Spielgefühl von Block und Parry und die Lautstärke bzw. Qualität der
Platzhalter-Sounds sind nicht bewertet.

## Bekannte Einschränkungen
- **Audio:** nur synthetische Platzhalter; die Lautstärke ist ein globaler Effekte-Regler (kein
  Master-/Musik-Regler).
- **VFX:** prozedurale Linien- und Kreis-Effekte, keine Sprite-Animationen.
- **Verteidigung:**
  - Gegner verteidigen sich selbst nicht.
  - Parry-Talente und Klassen-Unterschiede bei der Verteidigung gibt es noch nicht; Profile gelten pro
    Waffe bzw. Schild.
  - Der Schildblock gilt nur mit einem Schild in der Nebenhand, also nur für Klassen, die Schilde
    tragen dürfen (Warrior).
- **Unblockable:** Den Unblockable-Angriff hat bisher nur der Grove Warden. Spieler-Skills sind nicht
  blockbar-relevant, da Gegner nicht verteidigen.
- **Startwerte:** Parry-Fenster 120–150 ms und die Reduktionen wurden nur automatisch geprüft.

## Git-Commits
| Commit | Inhalt |
|---|---|
| `569b667` | A: Focus 6/s |
| `03ff34e` | B: Block & Parry, Profile, Angriffs-Flags, Warden-Daten, Unblockable-Telegraph |
| `3f6b294` | C: Skill-VFX, Status-Marker, Verteidigungs- und Poise-Break-Feedback |
| `669f068` | D: Combat-Audio mit Synth-Platzhaltern, Lautstärke-Einstellung |
| `7aee53d` | E: HUD-Zeile, Feedback-Fenstertest, Klick-Fix im Klassen-Playtest |
| Doku-Commit | dieser Bericht und die Design-Dokumente |

## Bedienung
- **Shift kurz drücken:** Parry. Kurz bevor ein Treffer landet; der Gegner-Telegraph läuft vorher ab.
- **Shift halten:** Block. Frontal, bewegt sich langsamer.
- **Loslassen:** kurze Recovery.
- **Unblockable** (magenta Zickzack + „!!“ + Warnton): ausweichen (Space).
- **Grunt-Slam** (roter Telegraph): bricht den Block; parieren oder ausweichen.
- **Optionen (O):** „Effects volume“.

## Menschlicher Playtest
1. **Parry:** In der Arena (F2) Grunts spawnen und den Swipe-Telegraph (orange) parieren. Ist das Fenster
   fair? Ist der Konter (nächster Schlag, HUD „COUNTER!“) spürbar?
2. **Block:** Shift halten gegen mehrere Grunts. Fühlt sich −45 % richtig an? Stört die Verlangsamung?
3. **Slam:** gegen den Grunt-Slam blocken (Guard Break) und dann parieren. Ist der Unterschied
   verständlich?
4. **Zweihänder (Taste 2):** Heavy Guard (−25 %). Zu schwach?
5. **Schild:** Warrior mit Oak Shield (F7-Kit). Wirkt der Schild sicherer?
6. **Grove Warden** (Whisper Forest):
   - Wird der Crushing Slam als unblockable erkannt?
   - Lässt sich der Swipe nur blocken?
   - Bleibt der Boss trotz Parrys handlungsfähig?
7. **Sicht, Ton, Klang:**
   - Klassen-Skills nacheinander: Sind die Effekte gut unterscheidbar und nie störend über Telegraphen?
   - Sind die Platzhalter-Töne zu laut oder nervig?
   - Arcane-Runen und das Weak-Point-Fadenkreuz bei mehreren Gegnern: Ist klar, wer markiert ist?
8. **Shadowrunner Focus 6/s:** Ist der Rhythmus jetzt passend?
