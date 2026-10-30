# Parry Timing Cue 1.0

Korrigierte Designrichtung nach dem Playtest: Statt Symbolen für die Verteidigungskategorie zeigt das Spiel ein
**zeitliches Handlungssignal** – einen kurzen hellen Kreuzblitz an der Angriffsseite eines Elite- oder Bossgegners in dem
Moment, in dem ein sofortiger Shift-Druck den angekündigten Angriff pariert (bei richtiger Position und erfüllten
Parry-Bedingungen). Ersetzt die Symbolentscheidung aus Combat Telegraphs 1.0. Unverändert: Parry-Fenster, Cooldowns,
Input-Regeln, Flags, Schaden, Reichweiten, Hitboxen, Phasenzeiten, KI, Husk-Mix, Loot, Menüs, Karten, Save v15.
Die übrige Abnahme bleibt gültig; nur das Signal braucht eine erneute gezielte menschliche Prüfung.

## 1. Tatsächliche Input-/Parry-/Treffer-Zeitbeziehung

- **Parry-Eingabe** (`DefenseComponent.step`): Shift landet im Eingabepuffer (0,12 s); das Fenster öffnet im selben Tick,
  sobald der Spieler `IDLE` ist, Starten erlaubt ist (Dash-Cancel-Regel des laufenden Angriffs) und `parry_cooldown`
  abgelaufen ist. Keine weitere Aktivierungsverzögerung.
- **Fensterdauer:** `DefenseProfile.parry_window` – Schwert 0,15 s, Heavy 0,13 s, Schild 0,12 s. Cooldown 0,55 –
  0,65 s ab dem Druck; ein leeres Fenster endet in `parry_recovery`.
- **Treffer:** Gegnerangriffe sind Nahkampf (`CombatComponent`). Der Treffer wird beim Eintritt in die Aktivphase
  geprüft (`_scan_hits` direkt beim Phasenwechsel) und in `Hurtbox.hit_filter` → `DefenseComponent.resolve` aufgelöst.
  Zeitpunkt = Ende des Startups; `phase_duration()` enthält die Angriffsgeschwindigkeit (beim Start fest).
- **Projektile:** keine Gegner-Projektile im Content → kein Signal dafür (`ParryCue.eligible` schließt sie aus).
  **Mehrfachtreffer:** alle Gegnerangriffe `max_hits_per_target = 1`.
- **Unterbrechung / Stagger / Tod:** beenden den Startup (Zustand verlässt TELEGRAPH) → kein Signal bzw. Abbruch.
  Hitstop friert den Gegner ein; die Restzeit läuft dann ebenfalls nicht weiter.
- Ein Ziel, das erst später im Aktivfenster in Reichweite kommt, wird später getroffen – die Vorhersage gilt für den
  Fall „steht in Reichweite“, also für die Situation, in der Parieren überhaupt sinnvoll ist.

## 2. Signalberechnung und Reaktionsvorlauf (`ParryCue`)

- Ein Druck `r` Sekunden nach dem Signal pariert, wenn der Treffer in `[Signal + r, Signal + r + Fenster]` fällt; mit dem
  Signal `L` vor dem Treffer heißt das **L − Fenster ≤ r ≤ L**.
- Gewählt: **L = REACTION + Fenster / 2** mit zentralem `REACTION = 0,19 s` – der erfolgreiche Reaktionsbereich ist so für
  jedes Profil auf 0,19 s zentriert: Schwert 0,115–0,265 s, Heavy 0,125–0,255 s, Schild 0,13–0,25 s. Das Fenster selbst
  bleibt unverändert; maßgeblich ist das Profil des tatsächlichen Ziels (Fallback 0,15 s).
- Signalzeitpunkt: erster Physik-Tick des Gegners mit Restzeit bis zum Treffer ≤ L (Prüfung in `EnemyView._physics_process`,
  direkt nach dem Gegner-Tick). Bei 60 Hz damit 0,25 s vor dem Treffer (Schwert).
- Gemessen (echter Spieler, echte Gegner, Druck r s nach dem Signal, 0,02-s-Schritte): **pariert bei 0,12 – 0,24 s**,
  davor zu früh, danach zu spät – gleich für Hardened Husk und Rootbound Sentinel.
- Ein verpasster Zeitpunkt (Angriff erst später als 0,05 s danach beobachtet) wird nicht nachgeholt. Alle Startups im
  Content (≥ 0,45 s) sind länger als L.

## 3. Berechtigte Gegner und Angriffe

- Datengetrieben über `EnemyConfig.rank` (Elite 1, Boss 2) und `AttackDefinition.is_parryable()`; keine Namen, keine
  ID-Listen, keine neue Elite-Architektur.
- **Elite:** Hardened Husk – `husk_swipe` (Signal), `husk_slam` (nur blockbar, kein Signal).
- **Bosse:** Rootbound Sentinel – `sentinel_strike` (Signal), `sentinel_root_slam` (nur blockbar, kein Signal);
  Grove Warden – `warden_swipe` (nur blockbar) und `warden_slam` (unblockbar): kein Signal.
- **Trial-Bosse** (Rang 2, ohne eigene Familie → Grunt-Angriffe): Sanctum Warden, Bastion Guardian, Passage Alpha –
  `grunt_swipe` und `grunt_slam` sind parierbar → beide zeigen das Signal.
- **Normale Gegner** (Grunt, Rootbound Husk, Hollowfang Wolf …): nie ein Signal, weiterhin parierbar.

## 4. Visuelle Umsetzung, entfernte Symbole

- `EnemyView`: ein kurzer (0,16 s) heller Kreuzblitz – „+“ mit Tintenkontur, goldener „x“-Glanz, weißer Kern, wächst kurz
  und verblasst –, an der Angriffsseite des Körpers (`cue_point`, die prozeduralen Gegner haben keine Waffe), auf eigener
  Ebene über Gegner, Held und Fläche (`ParryCueLayer`, z 20) – nie verdeckt. Ganzpixlig, ohne Text, ohne Zähler.
- Ein Signal pro Angriff (`cue_instance`), kein Doppelblitz; Stagger und Tod brechen ihn ab; der Knoten verschwindet mit
  dem Gegner bzw. der Karte.
- **Entfernt:** Kreuzfunke, Bernstein-Schild und roter gebrochener Ring aus Combat Telegraphs 1.0 (`draw_telegraph_symbol`,
  `symbol_anchor`).
- **Erhalten:** Richtungs-/Reichweitenkegel mit wachsender Füllung (dünn leicht, dick schwer), rote gezackte Fläche für
  nicht abwehrbare Angriffe (`telegraph_kind` UNDEFENDABLE), Warnton `unblockable_warn`, Erfolgsfeedback nach einer
  Parade (Stern, Blitz, Sound, Aufblitzen und Benommenheit des Gegners). Kein „PARRY“-Text.

## 5. Ausgeführte Tests

- `./tools/check_project.ps1`: **Startup check OK**.
- Neu `test_parry_timing_cue` (5 Tests, echter Spieler über `physics_step`, echte Gegner):
  - Husk-Swipe: Signal, dann Shift nach 0,13 / 0,16 / 0,19 / 0,22 / 0,25 s → **jeweils echte Parade** durch
    `DefenseComponent.resolve`; Shift im Signal-Tick (0,0 s) → keine Parade (Fenster vor dem Treffer zu), nach 0,40 s →
    keine (Treffer schon da).
  - Sentinel-Strike (Boss): Signal und Parade bei 0,16 und 0,22 s.
  - Kein Signal: Grunt (aber weiterhin parierbar, echte Parade ohne Signal), Grove Warden (Swipe und Slam), Husk-Slam;
    der Husk signalisiert nur den Swipe.
  - Lebenszyklus: genau ein Signal pro Angriff; Stagger vor dem Zeitpunkt → keins; Tod im Startup → keins, kein Blitz;
    verpasster Zeitpunkt → kein nachträglicher Blitz.
  - Daten unverändert: Flags, Startup- und Aktivzeiten von Grunt-, Husk-, Warden-, Sentinel-Angriffen; Ränge.
- `test_combat_telegraphs`: Test der Symbolplatzierung entfernt (Symbole gibt es nicht mehr), übrige 7 Tests grün.
- `-Suite "parry_timing_cue,combat_telegraphs"`: **12 passed**; nach der Ebenen-Korrektur
  `-Suite "parry_timing_cue,combat_telegraphs,combat_feedback"`: **17 passed**.
- `-Suite "combat_feedback,defense,enemy,roots_remember_m3,class_trials_m31,hit_reaction"`: **54 passed, 0 failed**.
- Messlauf des Reaktionsbereichs (0–0,40 s, temporär, nicht eingecheckt): siehe Abschnitt 2.
- Keine Full-Suite, keine Gameplay-Loops, keine Assets.

## 6. Sichtprüfung in Bewegung (1920 × 1080, 100 %)

`tests/playtest/parry_cue_check.gd` im echten Fenster in der Arena: Husk (Swipe, Slam, Swipe), Sentinel (Strike, Slam),
Grunt (zwei Swipes); jedes 2. Bild um die Windups gespeichert, Shift 0,19 s nach jedem Signal über den echten Inputweg.
Ergebnis **OK (5 checks)**: Husk 2 Signale / 2 Paraden, Sentinel 1 / 1, Grunt kein Signal. Log: Signal 0,250 s vor dem
Treffer. Angesehen als Bildfolgen: Kegel wächst, Blitz an der Angriffsseite für etwa 4 Bilder (≈ 0,16 s), danach
Treffer bzw. Parade-Stern; der Slam des Husk und des Sentinel ohne Blitz.
Befund und Korrektur: Im ersten Lauf überdeckte der nahe Held den Blitz teilweise → eigene obere Ebene, Punkt am
Körperrand; im zweiten Lauf frei sichtbar.

## 7. Einschränkungen und offene Punkte

1. Die Signal-Mitte 0,19 s ist eine Annahme zur menschlichen Reaktion; der Entwickler bewertet, ob früher oder später
   besser liegt (eine Konstante: `ParryCue.REACTION`).
2. Das Signal setzt voraus, dass der Held beim Eintritt der Aktivphase in Reichweite steht; wer sich erst danach
   hineinbewegt, wird später getroffen.
3. Gleichzeitige Signale mehrerer Gegner sind möglich (je einer pro Angriff).
4. Für künftige Projektil- oder Mehrtreffer-Angriffe von Elites/Bossen gibt es noch kein Signal (bewusst ausgeschlossen);
   Folgelösung: Treffzeit aus Flugzeit/`rehit_interval` je Treffer ableiten.
5. Menschliche Abnahme des Signals in echten Kämpfen.

## 8. Commit

Siehe unten (nachgetragen).
