# Hearth Flask & Consumables 1.0

Regeln nur in `ConsumableService`, Zustand in `Character.consumables` (`CharacterConsumables`, Save v9),
Werte in `ProgressionRules` („Hearth Flask & Potions“, provisorisch balanciert). Spielerseitige Texte Englisch.

## Hearth Flask
- Charakterfunktion, kein Item: nicht verkaufbar, einlagerbar, fallen zu lassen oder verwertbar.
- Start: 2 Ladungen, 30 % der maximalen HP je Ladung.
- Trinken (Taste 1): 1,1 s, währenddessen 45 % Gehtempo, keine Angriffe, Skills oder Blocken.
  - Heilung und Ladungsverbrauch erst am Ende (`Player.begin_use` → Abschluss-Callback der Bridge).
  - Unterbrochen durch Dash, Treffer ab INTERRUPT, Tod oder Szenenwechsel: nichts verbraucht, keine Heilung.
- Kein Cooldown.
- Rastplätze (`Checkpoint`): volle HP, volle Ladungen, Respawnpunkt.
  - Kein Speichern (wie bisher), keine Gegner kehren zurück.
  - Tod und Respawn ändern die Ladungen nicht.

## Upgrades bei Mara
- Mara in Haven (`StoryNpc.offers_service`, `NpcDefinition.service = hearth_flask`) öffnet das Fenster
  „Hearth Flask“, sobald kein ungehörter Dialog ansteht. Ihr wiederholbarer Dialog bleibt über „Talk to …“
  erreichbar.
- Nur Gold, jeweils eine Stufe pro Kauf, atomar (Gold vorab geprüft):
  - Capacity: 2 → 3 / 4 / 5 / 6 Ladungen für 150 / 450 / 1100 / 2400 Gold. Die neue Ladung ist sofort gefüllt.
  - Potency: 30 → 40 / 50 / 60 / 70 % für 200 / 550 / 1300 / 2800 Gold.

## Spezialtränke
Echte stapelbare Items (`ItemDefinition.potion_effect` → `PotionEffectDefinition`: Dauer, Stat-Modifikatoren,
Farbe).

| Trank | Wirkung | Dauer | Alchemie (Alchemist's Cottage) |
|---|---|---|---|
| Ember Draught | +8 % verursachter Schaden (`damage_dealt`, alle ausgehenden Treffer) | 45 s | Stufe 1: 2 Duskleaf + 1 Timber |
| Resonance Elixir | −10 % Klassenressourcenkosten (`resource_efficiency`, Deckel 50 % → nie negativ) | 60 s | Stufe 3: 3 Duskleaf + 1 Iron Ore |
| Barkskin Tonic | −8 % erlittener Schaden (`damage_reduction`, nach Rüstung; Parry/Block unverändert) | 3 min | Stufe 2: 2 Duskleaf + 3 Timber |
| Quickstep Tincture | +7 % Gehtempo (`move_speed`; nie Dash-Distanz, iFrames, Ladungen, Aufladung) | 4 min | Stufe 1: 2 Duskleaf + 2 Flax Fiber |
| Whisperbloom Concentrate | +15 % Statusresistenz (`status_resistance` → `StatusComponent.general_resistance`) | 3 min | Stufe 4: 4 Duskleaf – **nicht herstellbar** |

- **Whisperbloom:** Kein Gegner belegt den Spieler bisher mit Status. Der Trank würde nichts bewirken; das Rezept
  ist daher wie zuvor Stoneskin mit Grund gesperrt. Effekt und Stat sind eingebaut.
- **Stoneskin Draught:** Das alte Datenrezept gehört nicht zu den fünf Tränken und bleibt „Not brewed in this version“.
- **Schnellslot:** Rechtsklick auf einen Trank in der Tasche legt ihn auf Slot 2.
  - Die Zuordnung wird gespeichert und bleibt bei leerem Stapel erhalten.
- **Trinken (Taste 2):** 0,7 s, verlangsamt (45 %, kein eigener Wert entworfen), unterbrechbar ohne Verbrauch.
  - Am Ende wird genau ein Trank verbraucht.
  - Der Buff ersetzt einen laufenden (nur einer aktiv, nie gestapelt).
  - Danach 30 s gemeinsamer Cooldown.
- **Ende des Buffs:** Tod beendet ihn. Keine Heilung.
- **Zeit:** Buff und Cooldown laufen in Spielzeit (Physik-Tick der Bridge) und werden mit Restzeit gespeichert.

## Tasten
- 1 = `use_flask`, 2 = `use_potion`, zur Laufzeit registriert (`GameHud.ensure_input_actions`).
- `project.godot` bleibt unberührt. Die Aktionen `weapon_slot_1/2` verlieren dabei zur Laufzeit die Tasten 1/2.
  - Waffen-Schnellwechsel hat damit derzeit keine Taste (offene Entscheidung, siehe Bericht).
  - Options › Controls zeigt Flask und Potion statt Weapon 1/2.

## HUD
- Linke Spalte über dem Player Frame: Effektleiste und Quick Use.
  - Slot 1 „Hearth Flask“: Ladungen/Maximum, Heilanteil oder „Empty - rest by a fire“.
  - Slot 2: Trankname, Anzahl, Cooldown als Text und Balken.
- `EffectBar` (allgemein, später auch andere Buffs/Debuffs): je Effekt ein quadratisches Icon.
  - Die Restdauer läuft als Ring im Uhrzeigersinn ab 12 Uhr ab, der abgelaufene Teil ist abgedunkelt.
  - Darunter steht die Zeit (m:ss).
  - Ein neuer Trankbuff ersetzt das Icon; abgelaufen verschwindet es.
  - Reine Anzeige: liest `ConsumableService.active_effects`, steuert keinen Timer.
