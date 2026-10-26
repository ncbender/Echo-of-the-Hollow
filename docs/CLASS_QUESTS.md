# Prolog, Klassenversuche und Klassenquests (Class Foundation 0.2)

Status-Legende: ✅ implementiert · 🟡 teilweise · 🔧 nur vorbereitet · ⬜ offen

> **Seit Prologue & Haven Slice 0.1:**
> - Die Trials heißen jetzt **Echos**: Echo of the Warrior, Echo of the Arcanist und Echo of the
>   Shadowrunner, jeweils mit Zitat.
> - Sie stehen am **Whispering Stone**; der Story-Prolog ist in `PROLOGUE_AND_HAVEN.md` beschrieben.
> - Die Ziele wurden neu gesetzt, ebenso die Gegnervarianten pro Echo (`enemy_configs`) und die
>   Wahltexte (`choice_text`).
> - Fallen alle Gegner vor den Zielen, erscheint eine neue Welle. Tod beendet das Echo.
> - Nach der Wahl folgt ein Meilenstein-Save; Erfolg wird erst nach dem Schreiben angezeigt.
> - Die Prologue Grounds bleiben als Entwicklerzugang (Tor in der Proving Arena).
> - Guardian und Soulbinder sind in der UI ausgeblendet.
> - Der Rest dieses Dokuments beschreibt die Regeln, die weiter gelten.

## Prolog ✅ (technisch spielbare Testsequenz, keine Storykampagne)
1. Neuer Charakter: **Basic Adventurer** in der Heimatbasis. Das Tor **„Prologue“** (G, nahe dem
   Startpunkt) führt zu den *Prologue Grounds*.
2. Dort: zwei Trainingsdummies (Bewegung, Grundcombat), drei Podeste **Trial of Steel / of the
   Arcane / of Shadows**, der **Altar of Choice** und ein Tor zurück.
3. G am Podest startet die Trial (3 Grunts erscheinen), G erneut verlässt sie.
4. Sind alle drei Trials abgeschlossen, wählt man am Altar **genau eine** Klasse (zwei Klicks:
   wählen, bestätigen).

| Trial | Klasse (Level 12, temporärer Build) | Ziele |
|---|---|---|
| Trial of Steel | Warrior: Furious Strike, Battle Cry, Blade Rush, Warbreaker | 50 Rage aufbauen · 2 Furious-Strike-Treffer · 2 Kills |
| Trial of the Arcane | Arcanist: Arcane Bolt, Mana Pulse, Frostbind, Rune Sigil | 3 Bolt-Treffer · 2 Arcane Marks setzen · 2 Marks detonieren |
| Trial of Shadows | Shadowrunner: Shadow Strike, Expose Weakness, Shadowstep, Execution | 2 Weak Points freilegen · 40 Focus · 1 Weak Point exekutieren |

## Regeln (`PrologueService`) ✅
Ein Klassenversuch ist **temporär**:
- Die Trial-Klasse wird gespielt (`CharacterClasses.trial_class_id`), aber nicht freigeschaltet.
- Level, Build und Loadout sind temporär. Das Loadout ist eine Referenzkopie des Adventurer-Loadouts;
  es werden keine Items erzeugt.
- Ressourcen und Cooldowns verfallen beim Ende.
- Es gibt keine dauerhaften Talentpunkte, Skills, Mods oder Klassen-XP.
- Speichern während einer Trial schreibt den Zustand **vor** der Trial. Nach dem Laden ist keine
  Trial aktiv; abgeschlossene Trials bleiben erhalten.
- Das Verlassen der Prolog-Map (`GameMap`) bricht eine laufende Trial ab.
- Eine Trial kann beliebig oft neu betreten werden.

Die endgültige Wahl:
- schaltet genau die gewählte Klasse dauerhaft frei und aktiviert sie
- lässt die anderen beiden gesperrt
- setzt den Prolog dauerhaft auf `completed`, mit `chosen_class`
- ist nie wiederholbar; danach sind auch keine Trials mehr möglich
- bleibt über Save/Load unverändert (getestet, inklusive F6/F9 im Fenster-Playtest)

Guardian und Soulbinder sind im Prolog nicht wählbar.

## Klassenquests (`ClassQuestDefinition`, `QuestLog`, `QuestService`) ✅
- Datengetrieben (`data/quests/`):
  - Klasse, Ziele (`TrialObjective`: Kills, Skill-Treffer, Status …)
  - Abgaben (Items, atomar verbraucht)
  - `requires_prologue`, `available`
- Annehmen und Abgeben an einer Klassenstation (Seite „Quests“). Das Abgeben schaltet die Klasse
  dauerhaft frei.
- Fortschritt zählt aus demselben Ereignisstrom wie die Trials und wird gespeichert (`quests`).

| Quest | Klasse | Status | Ziel |
|---|---|---|---|
| Path of Steel | Warrior | ✅ | 8 Hollow-Kreaturen besiegen, 3 Hollow Essence + 20 Gold abgeben |
| Path of the Arcane | Arcanist | ✅ | wie oben |
| Path of Shadows | Shadowrunner | ✅ | wie oben |
| Oath of the Guardian | Guardian | 🔧 `available = false` | vorbereitet |
| Bond of Souls | Soulbinder | 🔧 `available = false` | vorbereitet |

Die beiden nicht gewählten Prolog-Klassen sind über ihre Quest freischaltbar; die gewählte Klasse
braucht keine Quest.

## Offen
⬜ Story, Dialoge und NPCs; ⬜ eigene Quest-Gebiete; ⬜ Boss-/Erkundungsquellen für Mods (Schnittstelle
`ClassBuild.unlocked_mods` vorhanden); ⬜ Guardian- und Soulbinder-Inhalte.
