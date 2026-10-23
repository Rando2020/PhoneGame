# Playtesting Meldlings

This page covers a 20-minute session with a real person: the build, a script to follow, and 6 questions. Each question is answered by a number in the log.

## 1. Build it (one command)

```
tools/playtest_build.sh
```

It exports the three desktop presets ("Playtest Linux", "Playtest Windows" and "Playtest macOS") into `build/playtest/`:

| OS | File | Size (pass 22) | Run it |
|---|---|---|---|
| Linux | `build/playtest/linux/Meldlings.x86_64` | 77 MB | `./Meldlings.x86_64` |
| Windows | `build/playtest/windows/Meldlings.exe` | 95 MB | double-click; SmartScreen: More info, Run anyway |
| macOS | `build/playtest/macos/Meldlings.zip` | 61 MB | unzip; the app is unsigned, so right-click it, choose Open, then Open again |

To run it you need Godot 4.3 export templates in `~/.local/share/godot/export_templates/4.3.stable/`. The window opens at phone shape: 432x936.

These builds carry the `playtest` feature tag. The iOS release preset does not, so the menu and the log can't exist in an App Store build (pass22_test checks the presets).

## 2. The hidden menu

On the title screen, tap the version label (top right, "v2.0.0") 5 times within 2.5 seconds. The menu has 4 jumps. Each one plays real rounds through the engine to reach its state. None are mocked.

- **Act 1, round 2 with a Shortage.** Round 1 is played on autopilot, then you land on round 2's intro with the stamp.
- **Full charm bar with an upgrade mark.** A Thump run with 5 charms, one round played, in a shop whose offer includes an upgrade.
- **Gallery with risen charms.** Four charms move up a tier (one won, two owned, one seen) and rise on the Charms tab. This writes to your Collection.
- **A run's end with Share.** A Pip run at act 2, played badly until it loses. **It records a real run and pays Pegs**, so use it on a test profile.

The menu also shows this session's summary, a **Session log: On/Off** toggle, and **Clear the log**.

## 3. The log (private)

- Where: `user://playtest.log`, one JSON line a round. On Linux that's `~/.local/share/godot/app_userdata/Meldlings/playtest.log`. On macOS it's `~/Library/Application Support/Godot/app_userdata/Meldlings/`. On Windows it's `%APPDATA%\Godot\app_userdata\Meldlings\`.
- It never leaves the machine. There's no network code in it.
- A line looks like `{"session","act","round","kind","mix","secs","mulligans","cleared"}`.
  - `kind` is `twist:<id>`, `shortage:<cat>`, `spoiler` or `plain`.
  - `mix` is the points the round added to each category.
- It's on by default in playtest builds. It's off and absent in release builds.

## 4. The 20-minute script (for Ziah)

Before you start: clear the log from the menu. Play on a fresh profile if you can. Think aloud. Note the clock time whenever something feels off.

| Min | Do | Notice |
|---|---|---|
| 0-2 | Start a run with any character. Read the round 1 intro. | Did you read the twist before you picked your keep? Could you say what it does? |
| 2-7 | Play act 1 to the round 2 intro. | When the Shortage stamp hits, do you change what you keep, or just score less? Does round 2 feel like a new puzzle or a tax? |
| 7-10 | Buy a charm in the shop. | Does the purchase feel good: the flight, the tap, seeing it on your bar? Did you understand the charm before you bought it? |
| 10-15 | Keep playing until the run ends, win or lose. | Where did you hesitate longest? Did you use mulligans, and did they feel like a choice? |
| 15-18 | Open the menu: try the Shortage jump and the shop jump. | Does the upgrade mark make sense with no explanation? |
| 18-20 | Read the THIS SESSION numbers in the menu and answer below. | |

## 5. Six questions, each tied to a number

Read the numbers from the THIS SESSION block in the menu. The same numbers come from `Playtest.summary()`.

1. **Is round 2 a puzzle or a tax?** Compare the Shortage rounds' cleared % with the twist rounds'. More than 20 points lower suggests a tax. Then compare the Shortage rounds' average seconds with the twist rounds'. Longer means you were thinking, which suggests a puzzle.
2. **Does the Shortage move your keeps?** Look at the lead changes %. The sims predict about 67% on autopilot. If play is near that or higher, players are adapting. Much lower means they're ignoring it.
3. **Is the twist read before the keep?** Look at the twist rounds' average seconds against plain rounds. Then check your note from minute 0-2. A twist round that takes no longer was probably not read.
4. **Are mulligans a choice?** Look at mulligans a round. 0 suggests they're not seen; above 1.5 suggests hands feel bad.
5. **Is the pace right?** Look at the average seconds a round. Our target is 60 to 120 seconds (unverified; this is the first real data).
6. **Is the difficulty fair for a first session?** Look at the overall cleared %. Then look at the Spoiler cleared % (the act-end boss). A Spoiler near 0% at act 1 means the wall comes too early.

Write the six answers and the raw numbers into a dated note under `docs/playtests/`, then attach `playtest.log`.

## 6. Reading a session (pass 23)

```
python3 tools/playtest_report.py path/to/playtest.log [--session ID] [--json]
```

This prints the 6 numbers. Where the sims made a prediction, it prints it alongside. Each share gets a 95% Wilson interval, and the line ends with one of three marks:

- **within:** the prediction sits inside the interval.
- **outside:** it doesn't.
- **unverified:** fewer than 8 observations, so the session can't settle it.

The math matches `Playtest.summary()` (tools/test_playtest_report.py checks it on the same entries as pass22_test).

| Question | Log number | Sim prediction |
|---|---|---|
| 2 Lead changes | lead_changes_pct | 66.8% (autopilot; a player who adapts should be at or above it) |
| 6 Reach | runs reaching act 1, round 3 | 51.1% (beginner bot) |
| 6 Game wins | runs that clear act 5's Spoiler | 15.3% (strong bot; one session will not test this) |

Questions 1, 3, 4 and 5 have no sim prediction, so they're read against the rules in section 5.

Session notes go in `docs/playtests/YYYY-MM-DD.md`:

```
# Playtest YYYY-MM-DD
Device / OS:            Build: (git hash)
Report: (paste tools/playtest_report.py output)
Clock notes: (mm:ss  what happened  what it felt like)
Q1..Q6: (verdict: keep / tune / cut, and the number that drove it)
```

### Verdicts so far

**No session has been logged yet** (2026-10-23): there's no playtest.log and no notes, so all six verdicts are open.

| # | Question | Verdict | Number |
|---|---|---|---|
| 1 | Round 2: puzzle or tax | unverified | none yet |
| 2 | Shortage moves keeps | unverified | none yet |
| 3 | Twist read before the keep | unverified | none yet |
| 4 | Mulligans are a choice | unverified | none yet |
| 5 | Pace | unverified | none yet |
| 6 | Difficulty | unverified | none yet |

Following pass 23's rule (change only what two or more signals agree on), **no game change was made**. The twist-read fix (prompt item 4) is conditional on question 3 reading "not read", so it hasn't been built.

### Bot check of the log (not a playtest)

`tests/bot_log.gd` makes the best-keep autopilot write a real log through the same hooks: 300 runs, no shop, 60 s a round on a fake clock. The report then shows:

- lead changes 74.9% (95% 70 to 79), against the sim's 66.8%
- reach of the first Spoiler 53.3% (95% 48 to 59), against 51.1%
- Shortage rounds cleared 53.6%, against 93.8% for twist rounds

The bot doesn't shop, while the sims do, so these numbers aren't a calibration. The lead-change gap is unverified. The Shortage clear gap is one signal from a weakened bot; it's worth watching in question 1, not acting on alone.

### Still unverified

- The Windows and macOS builds have never been launched; there's no hardware for them here. Only the Linux build was run (headless, under xvfb, with no script errors).
- Haptics on a real phone. Desktop only logs the pulse.
- Whether the 5-tap target is easy to hit with a finger (tested by calls, not a hand).
- The log paths on Windows and macOS (taken from Godot's documented defaults).
- Every feel question above.
