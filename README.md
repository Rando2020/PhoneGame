# Meldlings

**Learn Rummy. Master Rummy. Break Rummy. Make your own rules.**

Meldlings is a portrait-first creature card roguelite prototype built in Godot 4. Both sides play from the same deck, use Rummy-derived card relationships, and trigger creature abilities through the cards they commit.

## First Blood Prototype

The current vertical slice includes:

- Shared 52-card deck and discard pile
- Player vs CPU rival using the same legality rules
- **PAIR → BRACE** for defense
- **2-card run → PREP** for setup
- **3+ run → STRIKE** for focused offense
- **3+ set → RALLY** for multi-suit attacks
- **4-suit set → GRAND MELD**
- HP, Block, Burn, Hex and Thorns
- CPU intent clues
- Post-win relic choice
- Persistent Essence and a capped Vitality upgrade
- Runtime-generated 8-bit-inspired square-wave sound effects

## Run It on PC

1. Install Godot 4.3+.
2. Clone this repository.
3. Import `project.godot` into Godot.
4. Press **F6/F5** or the Play button.
5. Mouse clicks simulate touch input. Press **R** to restart the battle.

No external assets, plugins or packages are required for the prototype.

## Mobile Targets

The UI is designed at a 720×1280 portrait viewport and uses Godot Controls, so the same scene can target desktop and mobile.

### Android

Install Godot's Android build template plus the Android SDK/JDK, then create an Android export preset in **Project → Export**. Touch works through the same Button input used on desktop.

### iPhone / iPad

Create an iOS export preset in Godot. Final iOS signing/export requires macOS with Xcode and an Apple developer provisioning setup.

### Desktop

Godot can export the same project to Windows, macOS and Linux. Desktop is the recommended playtest target while combat math is changing quickly.

## Project Structure

```text
PhoneGame/
├─ project.godot
├─ scenes/
│  └─ Main.tscn
├─ scripts/
│  ├─ main.gd
│  ├─ rummy_rules.gd
│  ├─ cpu_player.gd
│  └─ sound_manager.gd
├─ data/
│  └─ meldlings.json
├─ assets/
│  └─ meldlings/
└─ docs/
   ├─ GAME_DESIGN.md
   └─ ROADMAP.md
```

## Design Rule

Any major mechanic should do at least one of three things:

1. Teach a Rummy concept.
2. Reward mastery of a Rummy concept.
3. Let the player intelligently break a Rummy concept.

See `docs/GAME_DESIGN.md` for the combat foundation and `docs/ROADMAP.md` for planned evolutions, Fusion, co-op and multiplayer.
