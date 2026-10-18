# Godot build audit against Apple's guidelines (2026-10-18)

Method: every screen rendered at 720x1560 (iPhone 15 shape) with the real
scenes (front_shot, shot, cut_shot, peg_shot, shop_shot, flow_shot), plus code
measurements. The canvas is 720 px wide and an iPhone is 390 pt wide, so
1 pt = 1.85 canvas px. Apple: text at least 11 pt (20 px), body 17 pt (31 px),
touch targets at least 44 pt (81 px).

## Review risks (fix first)

| # | finding | measured | Apple bar |
|---|---|---|---|
| 1 | Text too small almost everywhere | font sizes in ui/: 14-24 px = 7.6-13 pt; most lines 16-18 px (8.7-9.7 pt) | 11 pt minimum, 17 pt body |
| 2 | Touch targets too small | Peddler / Back / Mulligan ~44 px tall (24 pt); the charm sell "x" ~10 px (5 pt); Meldling < > arrows ~40 px | 44 pt (81 px) |
| 3 | No haptics | 0 calls to Input.vibrate_handheld | expected on commits: cut, 31, round cleared, purchase |
| 4 | No sound | 0 AudioStreamPlayer (web has a full synth) | the web version has it; a silent native app reads as unfinished |
| 5 | Reads like a web page in a frame | flat colour fill, plain grey buttons, no transitions between screens | 4.2 rejection risk: "minimum functionality / not app-like" |

## Feel (Apple's fluid-interface rules)

| # | finding | rule |
|---|---|---|
| 6 | Buttons give no press feedback (4 button_down/gui_input hooks in all of ui/) | respond on touch-down: scale 0.97 + highlight instantly |
| 7 | Screens cut, they don't move | enter and exit along one path; springs, damping 1.0, response 0.3-0.4 s |
| 8 | Cards can't be dragged; tap only | 1:1 drag respecting grab offset, flick to Crib with velocity handoff |
| 9 | No reduced-motion path | iOS Reduce Motion: cross-fade instead of slides/shake |
| 10 | Text doesn't follow the phone's text size | scale layout with Dynamic Type |

## Dopamine gaps (the big one)

| # | finding |
|---|---|
| 11 | No Meldlings on screen anywhere: the title parade, the Meldling picker ("???"), the intro, the count and The Play all show text only. The web shows them on 6 screens |
| 12 | Large dead space: title, picker, intro and round end use about 50% of the height for nothing |
| 13 | The count has no reaction: numbers tick, but nothing on screen cheers, flinches or celebrates |
| 14 | The Spoiler in The Play is a word ("THE LEVY"), not a character |
| 15 | No particles, no screen shake, no glow on big hits (web has Juice.burst / shake) |

## What is already good

- Card art is crisp and readable; marks (Brittle, Mimic, Minted) read at a glance.
- The count breakdown ("Pair of 2s +1 ... Pip +32") is clear, and "MASSIVE / THE CUT SAVED IT" is the right kind of beat.
- Safe areas: content clears the notch and home bar in every render.
- The keep screen layout adapts to 720x1280, 720x1560 and 960x1280.

## Current Meldling art

32x32 pixel sprites from tools/make_creatures.py: 6 playable, idle (8 frames),
attack and hurt strips. Cute and consistent, but the six share one face (same
eyes, near-same mouth), they're small at phone size, and there are no reaction
states (happy, nervous, triumphant, defeated).
