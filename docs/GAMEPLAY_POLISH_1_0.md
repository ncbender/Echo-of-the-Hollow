# Region 1 – Gameplay Polish 1.0

Umsetzung kleiner Befunde aus dem Gameplay Review 1.0 auf dem uncommitteten Stand A/B/C + Talent Fix. Save bleibt **v15**;
keine Änderung an XP, Talenten, Gegnern, Bossen, Kartengrößen, Zoom, Haupt- oder Nebenquest-Abläufen.

## Questtracker
- `StoryService.tracker_lines`: Hauptquest unverändert (Kapitel/Name, aktueller Schritt, Zähler). Nebenquests (Quests mit
  `start_event_id`) folgen unter einer Zeile „Side Quests“ mit je einer Zeile `Name - Kurzziel` (`StoryService.short_goal`:
  Ziel-Beschreibungen des aktuellen Schritts mit Zählern, z. B. „Find the carved marks 1/3“). Volltext bleibt im Journal.
- Reward-Hinweise (`ObjectivePanel.reward_lines`) unverändert.
- Messung (echtes Fenster, Hauptquest + 3 Nebenquests + offener Reward): Höhe 556 → **406** Design-px; bei 150 % UI
  79 % → **59 %** der Bildhöhe, keine Überlappung mit dem Loot-Feed mehr (1080p/1440p/4K identisch, Design-px).
- Kurzziele der drei Nebenquests in den Daten geschärft (nur Texte, IDs/Events unverändert).

## What the Roots Keep – Orientierung
- Schritt 0 nennt die drei Gebiete (nördlicher Pfad beim verschluckten Karren, Senke im Süden, Weg zum Sunken Grove),
  ohne Koordinaten. Knotted Marker deutet alle drei Richtungen an; Nord-Zeichen verweist auf die Senke, Senken-Zeichen auf
  den Grove. Events, Mengen, Flags, Cache unverändert.

## Optionale Funde (je `Readable` mit Rewards: einmalig über `read.<id>`, alles oder nichts bei voller Tasche)
| Ort | Knoten | `persistent_id` | Inhalt |
|---|---|---|---|
| Chapel-Kreuzgang (40, −500) | `Finds/AlmsBox` | `chapel_alms_box` | 15 Gold |
| Tangled-Wood-Nordschleife (40, −790) | `Finds/CartSatchel` | `tangled_cart_satchel` | 2 `linen_cloth` |
| Warden's-Rest-Wachhütte (440, −440) | `HutFind/Footlocker` (erst nach `defeated.wardens_rest_rootbound_sentinel`) | `wardens_rest_footlocker` | 2 `oak_plank`, 1 `cured_leather` |

## Tests
`test_gameplay_polish` (5). Angepasst (Reward-Prüfung auf die neuen Fund-Knoten begrenzt, Story-Event-Verbot bleibt):
`roots_remember_m2`, `world_expansion_a`, `world_expansion_b`.

## Offen
- Kurzzeilen umbrechen bei 340 px Spaltenbreite auf zwei Zeilen; die Hauptquest-Prosa bleibt drei Zeilen lang.
- Journal: Nebenquests stehen auf der Story-Seite; die Journal-Seite „Side Quests“ zeigt weiterhin Klassenquests.
