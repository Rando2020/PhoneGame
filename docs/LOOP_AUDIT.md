# Loop audit: what makes "one more run" (2026-10-20)

Goal: the pull of a good roguelite (Balatro, Vampire Survivors), from moments
that are earned, never manufactured. Method: the four loops, fastest to
slowest, each checked against the code and the soak data. Numbers marked
*(estimate)* are worked out, not timed with a player.

## The verdict in one line

The second-to-second loop (keep, cut, count) is already strong. The pull
breaks down in the slower loops: a run is too long for a phone, the big beats
are 15 minutes apart, and the meta rewards arrive many runs too late, so a
new player has little reason to start run three.

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

## 3. The run loop: 5 acts of 5 rounds (25 to 30 minutes) — too long for a phone

The numbers: a deal takes about 35 to 50 s with a real player *(estimate:
10 to 20 s keep, 3 to 6 s cut and count at 1x, about 20 s of The Play)*. A
round is 4 deals plus the shop: about 3 to 4 minutes. Ziah's playtest: a
full run is 25 to 30 minutes. The first Spoiler, the run's biggest beat,
comes at round 5: about **15 minutes in**. The strong soak player reached
act 3 or later in 27 of 50 runs; a beginner (the random soak player)
averaged about 3 rounds, so most beginner runs end before the first Spoiler.

Why it matters: phone sessions are short. A run that can't reach its first
big beat in one sitting doesn't build "one more". Save and resume works
(soaked: 2,445 resumes identical), which helps, but resume doesn't produce
the itch to start the next run.

Options (the first two are balance changes: decide, then simulate, per the
design principle "simulation before intuition"):
- **3 rounds an act instead of 5** (Spoiler every third round). The first
  Spoiler at about 9 minutes, a full run about 15 to 18 minutes. Keeps 5 acts
  and 17 Spoilers; the target ladder needs re-tuning (sim it with the
  existing tools before shipping).
- **3 deals a round in act 1** (4 after): a faster first round, the first
  Spoiler at about 11 minutes, no change to the end game.
- **Count speed 2x by default after the first run** (the setting exists;
  the default is 1x). Cheap, and returning players skip watching familiar
  counts.
- Already right: CONTINUE on the title, a run record, and an end-of-run card
  with Pegs earned.

## 4. The meta loop: unlocks across runs (days) — rewards come too late

What's there: Pegs (Peddler: card backs 25 to 80, lenses 30 to 45), deeds
(17), Meldlings earned by deeds (2), systems won from Wagers (6), 8 streets,
8 trials, 4 ascended forms, a daily with a streak, the Gallery.

The math, from `Meta.pegs_for_run`: Pegs = rounds reached / 2, + 20 + 10 x
street for clearing a run, + 5 per deed earned that run.
- A beginner run that ends in act 1 round 3 pays **1 Peg** (plus 5 if a
  first-time deed lands). The cheapest back costs **25**. Without deeds that
  is about 15 to 25 runs to the first purchase *(estimate)*.
- A strong run that ends in act 4 pays about 9.

Systems are worse. They come only from Wagers, placed 1 or 2 per run at
random in act 1 round 2 to act 5 round 4, and won only by an exact score.
From `CribRun.plan_wagers`: a player who dies at act 1 round 3 sees a Wager in
about **19%** of runs, then has to hit the target exactly. **The Play**, the
game's best second loop (the preview's centrepiece), is one of those
systems, so most new players don't have it for many runs.

Fixes:
1. **Pegs every run, sized for the first week**: a floor of 5 Pegs a run,
   plus 2 per round reached, plus the existing bonuses. The first back after
   about 3 to 5 runs *(estimate)*. Losing still pays, which keeps the "next
   run" mood instead of the "I got nothing" mood.
2. **Give The Play from the start** (or win it at the first Spoiler). It's
   the most fun system, and gating it hides it. Keep Wagers for the other
   five systems.
3. **A "next unlock" line on every run end**: the nearest goal with its
   distance ("12 Pegs to Crimson", "Deed: score 29 in one hand, best so far
   24", "Wager: next run, maybe"). One concrete near goal is the strongest
   "one more" there is, and it's honest: it's a real goal, shown plainly.
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
| 1 | Pegs floor and per-round pay (first back in about 3 to 5 runs) | meta | tuning, 1 function | Ziah's yes |
| 2 | The Play from the start (or at the first Spoiler) | meta and round | 1 rule | Ziah's yes |
| 3 | "Next unlock" line on the run end | meta | UI | nothing |
| 4 | Count speed 2x by default from run 2 | run | 1 default | nothing |
| 5 | Plain-round twists | round | new content, sim | design and sim |
| 6 | Shorter acts (3 rounds) or a shorter act 1 | run | balance, sim | Ziah's call and sim |
| 7 | Synergy callouts on the round end | round | UI | nothing |
| 8 | "Needs N more" on the count | micro | UI | nothing |
| 9 | Cut-tier sound step | micro | audio | nothing |
| 10 | First-time celebrations | meta | UI | nothing |

1 and 2 make the free part (act 1, ending at the first Spoiler) much
stronger: a new player would earn Pegs, play The Play, and see a real goal
before the paywall card.
