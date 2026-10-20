# Loop audit: what makes "one more run" (2026-10-20)

Goal: the pull of a good roguelite (Balatro, Vampire Survivors), from moments
that are earned, never manufactured. Method: the four loops, fastest to
slowest, each checked against the code and the soak data. Numbers marked
*(estimate)* are worked out, not timed with a player.

## The verdict in one line

The second-to-second loop (keep, cut, count) is already strong. The pull
breaks down in the slower loops: a run is long for a phone (a strong run is
about 36 minutes, simulated), and the meta paid nothing for a lost run, so a
new player had little reason to start run three. Pass 13 fixes the meta;
run length is simulated and waits for a decision.

## 1. The micro loop: keep, cut, count (seconds) — strong

What's there: a real decision (4 of 6, with the Crib as a second decision),
uncertainty after you commit (the cut, rolling longer for better cuts), then
a payoff that ticks up line by line and slams the multiplier. Meldling
reactions, bursts, shake, haptics and a rising pentatonic tick. "MASSIVE",
"THE CUT SAVED IT" and "THIS WON YOU THE ROUND" name what you did.

This matches what works: a choice, a reveal you didn't control, a payoff
sized to the choice, and credit for the choice.

Gaps, small:
- **No "how good was that" anchor before the count.** The count's total
  means more when you knew the target. Show the round's remaining need on the
  count ("needs 22 more") so the slam lands against something.
- **The best cut and the worst cut feel alike until the numbers come.** The
  ceremony already rolls longer for better cuts; one sound step per cut
  tier would make a great cut felt before it's read.

## 2. The round loop: 4 deals to a target (minutes) — good, then flat

What's there: a target, 4 deals, the Peg House between rounds (charms, marked
cards, Reckonings), The Play after each count, the round-end card with the
round's biggest contributor.

Gaps:
- **Autopilot in the middle of a run** (Ziah's own playtest). Once a build is
  set, deal 3 of round 8 plays like deal 2 of round 7. Nothing in a plain
  round asks for a different keep.
- **Shop decisions thin out.** With five slots full, most visits are "buy a
  Reckoning, next round"; nothing in the shop points at a sell or a swap
  *(a read of the shop, not measured with players)*.

Fixes, in order of pull per hour of work:
1. **A small twist on plain rounds** (one line on the intro, drawn per run,
   shown in advance like the Spoilers): "Pairs pay double this round",
   "Your Crib is cut twice", "Flushes need 5". Light, readable, changes the
   best keep. This is the strongest anti-autopilot lever.
2. **Charm synergy callouts**: when two owned charms feed each other, say so
   on the round end ("Keystone + Tallyman: +31"). It makes the build feel
   authored and gives the shop a direction.
3. **One shop item that tempts a sell**: a charm that is better than one you
   own, marked "upgrade" against it, so a full bar still has a choice.

## 3. The run loop: 5 acts of 5 rounds — long for a phone

Simulated with the real JS engine (`tools/sim/run_length.sh`, 480 runs per
row; minutes are deals x 40 s + shops x 25 s, an estimate). A round ends when
the target falls, so it often takes 2 or 3 deals, not 4.

| variant | strong player clears | strong run | beginner run | first Spoiler at |
|---|---|---|---|---|
| **today**: 5 rounds an act, growth x1.19 | 19% | 36 min | 17 min | 7 to 9 min (49% of beginners get there) |
| 3 rounds an act, x1.19 (same curve) | 94% | 23 min | 12 min | 4 to 5 min |
| 3 rounds an act, x1.25 | 54% | 25 min | 11 min | 4 to 5 min |
| **3 rounds an act, x1.29** | **23%** | **24 min** | **10 min** | **4 to 5 min** |
| 3 rounds an act, x1.31 | 13% | 23 min | 10 min | 4 to 5 min |
| 3 rounds an act, x1.347 (same last target) | 3.5% | 21 min | 9 min | 4 to 5 min |
| today, but 3 deals in act 1 | 14% | 26 min | 8 min | 23% of beginners get there |

"Strong" keeps the best hand every deal (the sim's `best`); "beginner" keeps
the highest cards (`naive`). Ziah's own playtest: 25 to 30 minutes a run.

Reading it: **3 rounds an act with the target growing x1.29 to x1.31 keeps
today's difficulty** (strong clears 13 to 23% against 19%) while cutting a
strong run from 36 to about 23 minutes and a beginner run from 17 to about
10, and the first Spoiler arrives in about 4 minutes instead of 7 to 9. Still
5 acts and 5 Spoilers. Shortening act 1's deals instead hurts beginners
(only 23% reach the first Spoiler): rejected.

Not changed yet: Ziah decides. If yes, the change is two constants (rounds
an act, growth) in both engines, then the parity fixtures, the deeds that
count rounds, and the free part (it would end at act 1 round 3).

Already right: CONTINUE on the title, a run record, and Pegs on every run end.

## 4. The meta loop: unlocks across runs (days) — rewards come too late

What's there: Pegs (Peddler: card backs 25 to 80, lenses 30 to 45), deeds
(17), Meldlings earned by deeds (2), systems won from Wagers (6), 8 streets,
8 trials, 4 ascended forms, a daily with a streak, the Gallery.

The math: Pegs were paid **only for clearing a whole run** (web and port:
`pegs_for_run` is called from the run-won screen only), 20 + 10 x street +
5 per deed and up. A lost run paid **nothing**. With the strong sim player
clearing 19% of runs and a beginner about 3%, most players would see the
Peddler's prices (25 to 80) and never be able to buy. **Fixed in pass 13:**
every lost run pays 5 + 2 per round cleared (a beginner who falls in round 3
earns 9; the first back in about 3 runs).

Systems are worse. They come only from Wagers, placed 1 or 2 per run at
random in act 1 round 2 to act 5 round 4, and won only by an exact score.
From `CribRun.plan_wagers`: a player who dies at act 1 round 3 sees a Wager in
about **19%** of runs, then has to hit the target exactly. **The Play**, the
game's best second loop (the preview's centrepiece), is one of those
systems, so most new players don't have it for many runs.

Fixes:
1. **Pegs every run** (done, pass 13): 5 + 2 per round cleared on a loss;
   the win payout as before.
2. **The Play from the start** (done, pass 13): a starter system; Wagers win
   the other five.
3. **A "next unlock" line on every run end** (done, pass 13): the nearest
   real goal with its distance ("Next: Crimson, 16 more Pegs (9 / 25)", or
   "You can afford Crimson at the Peddler").
4. **First-time celebrations**: a first Spoiler beaten, first act cleared,
   first unlock get their own full beat (the deed toast exists; these deserve
   a screen moment). Once each, never again.

## 5. Healthy by design: keep these lines

What makes the pull fun instead of manipulative. The game already holds most
of these; keep them as rules:
- **Nothing paid changes play.** The full-game unlock and cosmetics only.
- **No random paid rewards** (no loot boxes, no gacha packs).
- **No timers or energy**, no "come back in 4 hours".
- **No punished streaks**: the daily streak should never take anything away
  when it breaks, only show the count.
- **No notifications asking you to play.**
- **The paywall card appears after a win** (the first Spoiler beaten), never
  after a loss, and shows once a run, not at every menu.
- **Clean stopping points**: the end of an act, saved and resumable, so
  stopping is easy and coming back is easy.
- **Honest near misses**: "3 SHORT" and "MISSED BY 2" are real numbers.
  Never fake a near miss to keep someone playing.

## Ranked: what to do, by pull for the work

| # | change | loop | kind | needs |
|---|---|---|---|---|
| 1 | Pegs on every run end | meta | done (pass 13) | |
| 2 | The Play from the start | meta and round | done (pass 13) | |
| 3 | "Next unlock" line on the run end | meta | done (pass 13) | |
| 4 | Count speed 2x by default from run 2 | run | done (pass 14) | |
| 5 | Plain-round twists | round | new content, sim | design and sim |
| 6 | 3 rounds an act, growth x1.29 (simulated above) | run | done (pass 14) | |
| 7 | Synergy callouts on the round end | round | UI | nothing |
| 8 | "Needs N more" on the count | micro | done (pass 14) | |
| 9 | Cut-tier sound step | micro | done (pass 14) | |
| 10 | First-time celebrations | meta | done (pass 14) | |

1 and 2 make the free part (act 1, ending at the first Spoiler) much
stronger: a new player would earn Pegs, play The Play, and see a real goal
before the paywall card.

## Pass 14: what changed

- **Run length: 3 rounds an act, target growth x1.29** (Ziah chose "same
  difficulty"). The x1.30 figure in section 3 came from a sim bug: on round 3,
  `boss()` swapped in a random Spoiler (it checked `round == 3`, a leftover
  from 5 rounds). On the fixed engine, strong-player clears are x1.28 22.3%,
  x1.29 16.1%, x1.30 13.6%; the old game is 17.5 to 19.4%. So x1.29 is the
  match (n=800, an estimate). A strong run takes about 23 min (was 35), a
  beginner run about 10 min (was 17), and the first Spoiler comes at about
  4 to 5 min (was 7 to 9). Run times are estimates: deals x 40 s + shops x 25 s.
- cribsim gates at x1.29: clears 9 to 15% by deck, best play reaches round
  11.5 and naive play round 2.6, and growth from x1.25 to x1.33 runs from 69%
  down to 4% clears.
- Wagers now fall on round 2 of each act (5 slots, 1 or 2 used). The free
  part ends at act 1, round 3.
- Count speed is 2x from the second run. A saved choice wins, from Settings
  or from the in-count button (which now saves too).
- A short count now shows "Needs N more". The cut's sound rises 0, 2, 4 or 7
  semitones as the cut adds less than 4, less than 8, less than 12, or 12 or
  more points.
- First-time celebrations happen once each: first act cleared (which claims
  the first Spoiler too, since they land together), a first Spoiler beaten on
  its own (an extra Spoiler from Third Street), and a first Peddler buy.
- The Play has a coach line on its first opening, and How to play has an
  8th step, "The Play".
