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
| 5 | Plain-round twists | round | done (pass 15) | |
| 6 | 3 rounds an act, growth x1.29 (simulated above) | run | done (pass 14) | |
| 7 | Synergy callouts on the round end | round | done (pass 15) | |
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

## Pass 15: what changed

- **Plain-round twists** (both engines). Every plain round gets one of 6
  twists, drawn once at run start: Doubled Pairs (pairs score 4), Rich
  Fifteens (fifteens score 3), Short Suits (a flush needs 3), Nobs for Three,
  Open Crib (the Crib scores in full) and Second Look (one more mulligan).
  - No twist twice in a row.
  - No twist on Spoiler rounds, Wagers or the Long Count.
  - A twist never makes a rule worse: if a deck or charm already has a better
    rule, that one stays.
  - A twist round's target is 10% higher.
  - Twists are drawn from a stream seeded with the run seed + 7919. Deals,
    cuts and the shop draw exactly what they did before (tested: planning
    leaves the run's rng untouched).
  - Shown on the intro (in place of "Score N in D deals"), in the keep
    screen's status line, and ahead of time on the round end's "Next" line.
- **The twist round's target, simulated** (`run_length.js`, 800 runs a row,
  about ±1.3 points of noise):

| | strong clears | strong run | beginner reaches the first Spoiler |
|---|---|---|---|
| no twists (pass 14) | 14.8% | 23.2 min | 50.8% |
| twists, target +0% | 17.4% | 23.7 min | 61.5% |
| twists, target +5% | 13.8% | 23.3 min | 53.8% |
| **twists, target +10% (shipped)** | **14.5%** | **22.7 min** | **50.4%** |
| twists, target +15% | 13.3% | 22.2 min | 47.1% |

  At +10%, difficulty and run length stay the same; what changes is that the
  best keep moves round to round. Whether that breaks the autopilot feeling
  is unverified: it needs a playtest.
- **Synergy callouts** (port, presentation only). For two charms that both
  scored in a count, their synergy is the total, minus the total without A,
  minus the total without B, plus the total without either. Those are pure
  recounts, with no draws, so parity is unchanged. The round end names the
  round's best pair at 5 points or more: "Ballast + Fifteener fed each other
  +7".

## Pass 16: what changed

### The shop's upgrade mark (LOOP_AUDIT 3)

When the charm bar is full, the shop marks at most one offer: "UPGRADE over
Keystone: +23 on your last 9 counts". It's measured, not guessed:
- The run logs its latest 24 hand counts: the hand, the cut, that round's
  rules, the luck rolls, and the round state charms read (deal number,
  mulligans left, deals left).
- In the shop, each logged count is recounted with the offer in the owned
  charm's slot, for every pair. The gain is that total minus the same counts
  with the bar as it is.
- The best pair is marked at 5 points or more.
- Replay fidelity is tested: a logged count recounted with the bar unchanged
  gives exactly the real count's total (201 of 201).

Limits:
- Charms that change the rules (Aces High, Half a Flush and the like) are
  never compared: the logged rules already carry them.
- Charms that read Glim use today's Glim.
- The log isn't kept across a resume of an older save: it starts empty, so no
  mark until new counts come in.

Presentation only, port only: parity unchanged, and nothing in `web/`
changed, so the cribsim gates are the same by construction.

### Do twists change the keep? (the playtest proxy)

`tools/sim/twist_keep.js`: 2,000 round-1 deals per twist. Each deal is valued
twice, under plain rules and then under the twist's, by the game's own keep
value (the hand's expected count over the cut). "Changed" means the plain
best keep is no longer best under the twist (ties don't count).

| twist | best keep changes | avg gain when it does |
|---|---|---|
| Short Suits (flush needs 3) | 27.8% | +1.77 |
| Rich Fifteens (fifteens score 3) | 10.8% | +0.68 |
| Doubled Pairs (pairs score 4) | 10.3% | +0.96 |
| Nobs for Three | 2.8% | +0.35 |
| Open Crib (Crib in full) | 0% | 0 |
| Second Look (one more mulligan) | 0% | 0 |

Reading it:
- **For "breaks autopilot":** Short Suits clearly changes play (more than 1
  in 4 deals). Rich Fifteens and Doubled Pairs change about 1 deal in 10.
- **Against:** the other three mostly don't change the four cards you keep.
- **Below the 10% bar, candidates to replace: Nobs for Three, Open Crib,
  Second Look.**
- **The measure's blind spot:** Open Crib changes what you throw, not what you
  keep, and Second Look changes whether you redraw. The game's keep value
  can't see either, so their 0% means "not measured here", not "no effect".
  Nobs for Three is a real miss: one jack per hand is rarely worth chasing.
- Whether any of this feels different to a player is still unverified: it
  needs a playtest.

## Pass 17: every twist earns its slot

The pass 16 measure valued a keep by its hand EV only, so it couldn't see two
of the twists. `tools/sim/twist_keep.js` now values a keep as hand EV plus the
thrown cards' Crib EV at the Crib's real mult (0.5, or 1 under Open Crib). The
Crib EV is estimated on 24 shared samples a deal, so all of a deal's keeps are
valued on the same cards. For Second Look, a greedy player mulligans whenever
the best keep is worth less than a fresh deal on average (10.79). "Changed"
then means a round where that player wants a third mulligan. 2,000 each:

| twist | pass 16 (hand only) | pass 17 (hand + Crib) |
|---|---|---|
| Short Suits | 27.8% | 28.2% of deals |
| Open Crib | 0% | **17.6%** of deals |
| Rich Fifteens | 10.8% | 11.9% of deals |
| Doubled Pairs | 10.3% | 11.4% of deals |
| Second Look | 0% | **46.1% of rounds** want a 3rd mulligan |
| Nobs for Three | 2.8% | **1.7%: replaced** |

Candidates screened with the same measure (existing rule keys, never
shipped as twists): being dealt 7 cards 66.0%, runs of 2 count 30.4%, Aces
High 16.6%, a 5-card Crib 12.8%, Round the Bend 9.6%. Double cuts and recuts
weren't screened: the keep value doesn't model them.

**Shipped: Seventh Card** ("You are dealt 7 cards, not 6") in Nobs for Three's
place. Its index is the same, so the seeded draw is unchanged. It's named
apart from the Generous Deal charm (the same rule), and the two stack: a twist
adds to `dealtBonus`. Both engines; parity re-run (78 runs, 34 rounds with
Seventh Card).

**Target, re-swept** (`run_length.js`, 2,400 runs a row, about ±0.7 points):

| | strong clears | strong run | beginner reaches the first Spoiler |
|---|---|---|---|
| no twists | 16.6% | 23.3 min | 51.7% |
| twists, +5% | 17.1% | 23.5 min | 54.2% |
| **twists, +10% (kept)** | **14.8%** | **23.2 min** | **51.2%** |
| twists, +15% | 14.8% | 23.1 min | 47.4% |

+10% stays: strong clears at 14.8% sit in the 14.5 to 14.8% band, and
beginners match no twists. (+15% gives the same strong rate but costs
beginners 4 points.) "No twists" reads 16.6% here against 14.8% in pass 15.
That's the noise of the smaller pass 15 sample; this one is 3 times larger.

## Pass 18: does it feel different? (and what's left)

`tools/sim/twist_feel.js` plays seeded runs with cribsim's strong player,
twists on and off on the same seeds. For each round it records the points the
kept hands scored by category (fifteens, pairs, runs, flushes).

**The autopilot number** (800 runs; 40 runs as asked gave the same shape:
41.9% on, 41.0% off). Over consecutive plain rounds, how often the round's
leading category changes:

| | transitions | leading category changes | mean distance between mixes (0 to 2) |
|---|---|---|---|
| twists on | 5,513 | **40.9%** | 0.637 |
| twists off | 5,567 | **39.4%** | 0.615 |

**Verdict: twists barely move it (+1.5 points).** They change single keeps
(11% to 66% of deals, pass 17), but over a round the strong player's charms
decide what it scores with. A twist that pays pairs doesn't turn a fifteens
build into a pairs build. To truly break autopilot, the round has to ask for
something the build doesn't already do: a twist the build is weak at, with a
reward for answering it. That's a design for pass 19 or later, not a tweak.

**Per-twist round-clear rates** (twist rounds, twists on, 800 runs):

| twist | rounds | clear | vs others' mean |
|---|---|---|---|
| Seventh Card | 1,067 | 96.1% | +1.2 |
| Open Crib | 1,041 | 95.5% | +0.5 |
| Rich Fifteens | 1,061 | 95.2% | +0.1 |
| Short Suits | 1,032 | 94.9% | -0.3 |
| Doubled Pairs | 1,053 | 94.8% | -0.4 |
| Second Look | 1,059 | 94.2% | -1.1 |

No twist is more than 8 points above the others, so no fix is needed:
Seventh Card changes the keep most but doesn't make the round much easier.

**A bug the sim found: nearby seeds shared their first twist.** xorshift's
first draw from seed + 7919 barely moved between neighbouring seeds, so seeds
40000 to 40799 all opened act 1 on Second Look (800 of 800). Over whole runs,
Second Look came up about 1.5 times as often as the others. Fixed in both
engines with a 32-bit integer mix (`twistSeed` / `CribRun.twist_seed`); parity
OK. The Daily was never affected: its date hash already spreads the seeds
(2026: 55 to 69 per twist on act 1 round 1 before the fix). Test: consecutive
seeds now open on each twist 60 to 140 times in 600 (the old formula fails
it: 600 of 600 on one twist).

### What's still open

| item | status |
|---|---|
| Ranked fixes 1 to 10, and the round-loop fixes 1 to 3 (section 2) | all done (passes 13 to 17) |
| Twists break autopilot | **not shown**: +1.5 points on the autopilot number. Needs a build-aware twist (above) or a human playtest |
| A playtest of passes 13 to 18 | open; needs Ziah |
| The in-app purchase and store plugin | open; needs a Mac (MAC_HANDOFF 3b) |
| **Charms have no art** | **open, new**: 53 charms are text rows in the shop, the bar and the round end; the Gallery has no Charms tab. In the genre this game sits in, the build pieces are the collectible |
| A run card to share | open, new: nothing leaves the game when a run ends |

**Next, best pull per hour: charm art plus a Charms tab in the Gallery.**
It is the one loop with no art: 53 pixel icons drawn by a script, like
every other asset here. The icons then go everywhere charms appear (shop,
bar, round end, the upgrade mark, synergy lines). The tab shows each charm
as seen, bought, or won a run with. That gives the meta loop a "collect them
all" target that the run loop already feeds.

## Pass 19: charms get a face, collecting them is the meta loop

**Art.** `tools/make_charms.py` draws all 53 charm icons, 32x32 plus a 2x,
in the Meldlings' style: a dark tinted outline, three-tone shading, a soft
highlight. Each icon reads in three layers:
- **Category first:** a silhouette and colour per category. Fifteens are a
  gold coin, pairs two red cards, runs blue steps, flushes a violet fan,
  multipliers an orange burst, rules a teal scroll, the deck a tan box.
- **Then the charm:** a 9x9 cream motif with an ink shadow.
- **Then rarity:** the plaque frame in the UI's rarity colour.

The script stops if two charms share a silhouette and motif. It also draws a
silhouette per category for unseen charms: shape only, no motif, no rarity.
Checked by eye on a contact sheet at 1x and 3x; Bloodline, Fifteen Fever,
Ballast and the overlapping card shapes were redrawn after the first sheet.

**Where icons show:**
- The shop's offer rows and owned chips.
- The upgrade line, which also shows the charm it would replace.
- The round end's MVP panel and synergy line, with both charms.
- The first-purchase card.
- The charm bar: on a phone's 6-slot bar there's no room for an icon beside a
  name, so a charm chip shows its icon alone. The name moves to a tooltip and
  the bar keeps its height. A bar with room shows both. An icon never splits
  a word: "Quartermaster" stays whole on a shop chip, with no icon.

**The collection.** Each charm's best state is saved: unseen, seen (offered
in a shop), owned (bought), won with (owned on a cleared run). States only
rise. The Gallery's new Charms tab (first of 7) shows all 53 by category:
- unseen charms as a silhouette and "???"
- seen ones dimmed
- owned ones in full
- won-with names in gold with a ★

The header counts are real: "Charms 12 / 53" counts owned and better. A
charm's first purchase ever plays a celebration card with its icon, once per
charm.

**The run card.** SHARE on both run ends draws one 1080x1350 PNG in Godot: the
Meldling, how far the run got, the run's best single count (now tracked), up
to 6 charm icons with names, the street and the date. It's saved to user://.
On iOS it goes to the share sheet if the build has the MeldShare plugin; that
plugin isn't written yet (unverified without a Mac).

**Build-aware twists: tried, not shipped.** Each plain round's twist was aimed
at the category the run had scored least in so far (runs have no twist, so
Seventh Card), and clearing it paid +3 Glim. 800 runs, strong player:

| | leading category changes | strong clears |
|---|---|---|
| twists as shipped | 40.9% | 14.8% |
| build-aware twists | 40.7% | 16.6% |

It needed +5 points on the autopilot number and clears in 14.5 to 15.5%. It
got -0.2 and 16.6%, so it stays out of the game (the sim mode is kept in
`tools/sim/twist_feel.js`, MODES=on,aware). Aiming a twist at a weak
category doesn't change what a strong build scores with; the charms decide.
Breaking autopilot will take something the build has to *answer*, not a
nudge: for example a round rule that blocks the build's best category.
That's a design question for Ziah and a playtest, not more tuning.

## Pass 20: the middle of a run asks a new question (the Shortage)

**A correction first.** Pass 19 said "the charms decide how a run scores".
The sim doesn't show that. cribsim's strong player picks keeps by the hand's
base points only (`bestKeepEV`) and never looks at its charms, so the
autopilot number measures the base scoring mix of what it keeps. A rule
that changes what a category is worth makes it re-pick, and that moves the
number; a nudge that doesn't change the best keep's category doesn't.

Three designs, each pushing back against the build (`tools/sim/twist_feel.js`,
800 runs a row, the same seeds; strong = cribsim's best keeps, beginner =
highest cards):

| design | autopilot number | strong clears | beginner reaches the first Spoiler |
|---|---|---|---|
| twists only (before) | 40.9% | 14.8% | 50.9% |
| (a) Shortage on every plain round from round 2 | 66.5% | 14.9% | 51.1% |
| **(a) Shortage on round 2 of each act (shipped)** | **66.8%** | **15.3%** | **51.1%** |
| (b) Contract: score 8 from your weakest category for 6 Glim | 39.6% | 16.6% | 51.8% |
| (c) Benched: the charm that has added most sits the round out | 37.7% | 8.3% | 51.4% |

- **Shortage passes** (+25.9 points, clears in band) with no tuning of its
  numbers: half points, no target change. What I tuned was *where* it applies.
  Every plain round from round 2 also passed, but it would have removed twists
  almost entirely, so it ships on round 2 of each act, the round before the
  Spoiler. Twists keep round 1.
- **Part of its effect is mechanical:** halving the leading category can flip
  which category leads even with the same keeps. The sim player does re-pick
  around it, which is the behaviour wanted. Whether it feels like a question
  rather than a tax is for a playtest.
- **Contract fails:** the chase barely moves keeps (a strong player's keeps
  already score some of every category), and the Glim lifts clears.
- **Benched fails hard:** removing the top charm makes rounds much harder
  (8.3%) and the scoring mix *less* varied (37.7%). The build just plays
  weaker.

**Shipped: the Shortage, in both engines.**
- The run tallies what its kept hands score by category (`catPoints` /
  `cat_points`).
- On round 2 of each act, the tally's leading category scores half that round
  (ties: fifteens, pairs, runs, flushes), and the round has no twist.
- Never on the run's first round, a Spoiler, a Wager or the Long Count.
- There's no random draw: it follows from how the run has played, so it can't
  be gamed or rerolled, and it's the same in both engines by construction.
- A new rule key, `catScale`, scales a category's events inside the count;
  it's absent unless a round sets it.
- Shown ahead: the intro ("SHORTAGE: Runs score half this round, your best so
  far."), the keep screen's status ("Short: Runs") and the round end's "Next"
  line ("Next: Round 2, target 51 · Shortage: Pairs").
- Checked: the engine's own run of the plain game reproduces the sim exactly
  (66.8%, 15.3%). Parity OK, with 46 Shortage rounds in the fixtures.

## Pass 21: building and collecting feel physical

Every one of these animations follows one rule (`ui/fx/motion.gd`): the screen
draws its **final** state first, then each animation runs from a temporary
start toward it. Each animation carries a `finish` that puts its nodes back
at rest, so a tap (`skip()`) lands exactly on the static draw.
- Tweens live on the animated node: no await, no timers.
- `Motion.enabled = false` is the static draw the tests compare against.
- Reduce Motion swaps movement for a 0.2 s cross-fade.

| moment | motion | Reduce Motion |
|---|---|---|
| buying a charm | its icon flies from the offer row to its new chip (0.35 s, ease out), the chip settles 1.12 to 1.0, the Glim ticks down (0.3 s); a chip with no icon just settles | the chip fades in; Glim shows at once |
| any other spend | the Glim ticks to its new value | at once |
| the round end | Final score and Glim count up (0.6 s), the act track's new dot pops in, the Next line slides in last (after 0.5 s) | dot and Next line fade in; numbers at once |
| the Gallery | charms that rose since the last visit flip from their old look (silhouette or dimmed) to the new, 60 ms apart, once; the first visit ever just records the levels | a fade |
| the Shortage | the intro's Shortage line lands like a stamp (1.4 to 1.0, a short shake, the Spoiler's heavy note); the keep screen gets a small red HALF tag after its status text, once per round, where it fits | a fade (the note still plays) |
| the upgrade mark | a soft 1.5 s pulse on the marked offer's border | a steady border |

A tap anywhere on the shop, the run screen or the Gallery lands everything
(the tap still presses what's under it). The upgrade pulse is ambient: it
keeps going.

Found by eye on the way: Gallery cells at 5 a row broke "Quartermaster"
mid-word at the text-size floor. They're now 4 a row.

`pass21_test`: for the shop purchase, the round end, the Gallery and the
Shortage intro, the static draw, the drawn-then-skipped and the
drawn-then-run snapshots match, with and without Reduce Motion. Each one is
seen moving mid-flight, the fade path is taken under Reduce Motion, reveals
happen once and only for risen charms, the keep stamp comes to rest on
screen, and the pulse loops with motion and sits still without it.
