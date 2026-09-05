# Market audit — benchmarked against what's actually working

Researched August 2026. Sources cited inline; findings applied, not just listed.

## Context

The bar is brutal. <cite index="10-1">Of 20,282 games released on Steam in 2025, only 608 reached 1,000 reviews — a 2.99% success rate.</cite> <cite index="10-1">The indie market is projected to grow from $4.85bn in 2025 to $10.83bn by 2031.</cite> Big market, savage discovery.

Our genre is crowded and healthy: <cite index="6-1">Slay the Spire 2 has been dominating the charts since its March 2026 Early Access launch</cite>, and <cite index="6-1">Mewgenics sold over a million copies in its first week</cite>.

## Benchmarked against Balatro

Balatro is the direct comparison, so I audited against documented analyses of it.

### PASS — we already match

**Juice as the product.** One breakdown puts it bluntly: <cite index="11-1">the game engine is mostly multiplications and additions, and what makes it feel like fireworks is the audiovisual feedback layer.</cite> We have the cascade, ramp, slam, shake and particles.

**Simple parts, complex interactions.** <cite index="13-1">Each Joker changes one rule; in combination they produce escalating scoring chains.</cite> Our charms are the same shape, and legendaries like Overflow and Sovereign multiply.

**Variable rewards at multiple levels** — shop, round, hand. Present.

### FAIL — three real gaps, now fixed

**1. Per-item triggers weren't shown individually.**

The critical insight from a feedback-design breakdown of Balatro: <cite index="17-1">each Joker physically bounces when it activates, the running total updates after each trigger, and by showing each Joker trigger individually, players learn which combinations matter.</cite>

Ours flashed all charms at once, then jumped to a final number. Players could never learn *which* charm was carrying them.

**Fixed:** the engine now computes an exact sequential chain — charms applied one at a time, total snapshotted after each:

```
base-only                     21
Thump            +  8  ->    29   (21 × 1.40)
Fifteener        +  9  ->    38   (27 × 1.40)
Keystone         + 22  ->    60   (27 × 2.24)
Counting House   + 34  ->    94   (27 × 3.50)
```

Steps sum exactly to the final total. Each fires in turn with its chip bouncing, its own row, and the running number climbing — and the base × mult line updates live beneath.

**2. No animation speed control.**

Balatro ships one deliberately: <cite index="12-1">a global speed adjustment lets players compress waiting animations, which shortens the feedback loop for positive reinforcement.</cite> A full run here is 25 rounds × 4 deals ≈ 100 cascades. At ~5s each that's eight minutes of watching the same animation.

**Fixed:** a **1× / 2× / 4×** toggle, on both the table and the count screen. Every timing routes through `Speed.ms()`.

**3. No per-card enhancement axis.**

Balatro modifies individual cards — <cite index="12-1">gold, glass, foil, steel and stone textures convey buff attributes visually</cite>. We had deck add/remove but nothing that made *specific cards* matter.

**Fixed — gilding, which is cribbage-native.** Gild a *rank* and every copy adds +4 base whenever it appears in a counted hand. Gilding 5s is the obvious first move (fives make fifteens), which gives the shop a third spending axis alongside charms and category levels.

This also solved a balance problem: **Thump had been stuck at 8% clears across two passes.** Gilding gives its fifteens identity direct support, and it moved to 22%. Final band: **Pip 13% · Thump 22% · Clover 18% · Facet 24%** — no outliers for the first time.

## Benchmarked against short-video virality

The research is consistent and specific: <cite index="20-1">if your gameplay doesn't look good in a 10-second clip, it won't go viral</cite>, and <cite index="20-1">players don't share games, they want to share feelings.</cite>

On competitive clips: <cite index="27-1">the key is emotional stakes — start the clip with the scoreboard showing you are losing, then cut to the clutch play.</cite>

**That's exactly the beat we built last pass.** The HUD shows `NEED 47 · 2 deals left`, then `SOVEREIGN SAVED IT` fires. The clip structure is already in the game.

What was missing was any way to *take* it. Added a **share card** on the death screen: deck, act, score/target, the near-miss margin, who carried the run, and your charm list — with a **COPY RESULT** button producing shareable text. Built to be screenshotted, and it leads with the emotional beat rather than the stats.

<cite index="26-1">Wordle proved simplicity is viral magic — a five-letter puzzle became a mainstream habit because it invited participation and comparison.</cite> A daily seed is the obvious next step and is not yet built.

## Where we still differ from Balatro, deliberately or not

| | Balatro | Meldlings |
|---|---|---|
| Scaling | <cite index="11-1">roughly 1.5× to 2× per ante, 300 to 300,000 over eight stages</cite> | ×1.205 per round, ~145× over 25 |
| Colour language | <cite index="17-1">blue chips, red mult, gold money — colour IS the label</cite> | partial; ours is gold/blue/green but not systematic |
| Micro-interaction | <cite index="12-1">card dragging has simulated inertia and magnetic snap</cite> | tap-select only, no drag-reorder |
| Audio sync | <cite index="12-1">number-jump frequency synchronises with the background audio pitch</cite> | rising pentatonic ticks, not keyed to the track |

The scaling gap is the interesting one. Balatro's ~1000× curve is what produces the screenshot-worthy million-point hands. Ours tops out far lower, which is safer to balance but caps the ceiling on exactly the moments people share.

## Recommended next, in order

1. **Daily seed + comparison** — the Wordle hook, and the cheapest big win left.
2. **Formalise the colour language** so colour alone reads value type.
3. **Raise the ceiling** — more multiplicative legendaries and a steeper late curve, to make million-point hands reachable.
4. **Card drag-reorder with inertia** — pure feel, but it's the thing that makes the hand feel physical.
