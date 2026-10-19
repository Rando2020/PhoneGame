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


# Re-check, 2026-10-19 (after Meldlings 2.0 passes 1 to 8)

Measured on the current build: every screen (title, road, street, Meldling
picker, Peddler, Deeds, Record, Gallery, How to play, Settings, intro, keep,
shop) probed for label font sizes and button heights at 720x1560; plus code
counts and the iOS export dry run.

| # | finding | status | measured now |
|---|---|---|---|
| 1 | Text too small | **LEFT** | 83 of 158 visible labels (53%) are under 20 px (11 pt); sizes 14 to 19 px. Worst: shop 23, Deeds 18, Peddler 14, intro 7 |
| 2 | Touch targets too small | fixed | 0 buttons under 81 px (44 pt) on 13 screens; Press keeps it through re-layouts |
| 3 | No haptics | fixed | reactions (cheer, signatures, victory), 31, a legendary, deeds; in the same call as the sound |
| 4 | No sound | fixed | 44 samples and 10 loops from the web synth; 34 call sites |
| 5 | Reads like a web page in a frame (4.2) | mostly fixed | felt, characters, sound, haptics, press feedback, slides, an icon and launch screen; unverified on a device |
| 6 | No press feedback | fixed | every button: 0.97 and brighter on touch-down, spring back |
| 7 | Screens cut | mostly fixed | RunFlow pages slide on a spring; front-door steps (menus) still cut |
| 8 | Cards can't be dragged | **LEFT** | tap only |
| 9 | No Reduce Motion | partly | an in-game setting, saved; Godot 4.3 can't read the iOS setting |
| 10 | Text ignores the phone's text size | **LEFT** | no Dynamic Type |
| 11 | No Meldlings on screen | fixed | title, picker, intro, keep, count, The Play, round end, Gallery, How to play, Record |
| 12 | Dead space | partly | the title and keep screen fill; the intro's lower half and the round end are still empty |
| 13 | The count has no reaction | fixed | the Meldling reacts as the total lands; bursts and shake on big counts |
| 14 | The Spoiler is a word | fixed | a character with five poses |
| 15 | No particles, shake, glow | fixed | Juice and Glow |
| 16 | App icon, launch screen | fixed | generated from the art; the launch screen is the title's first frame |
| 17 | Privacy manifest | fixed | C617.1, 35F9.1, E174.1, CA92.1; no tracking (checked in the exported project) |
| 18 | Safe areas | unverified | 7 screens read SafeArea; it reports zero off-phone, so only a device can confirm |

4.2 (minimum functionality) risk, in plain words: the first rejection was a web
page in a wrapper. The build is now a native Godot app with native input,
haptics, generated art and sound, and no web view. The risk left is
presentation (small text), not functionality.

What can't be done here (no Mac): building and signing the .ipa, running it on a
simulator or device, TestFlight, and App Store Connect upload. The exported
Xcode project (`build/ios/`, regenerate with the export command in PORT.md)
opens in Xcode on a Mac; set the Team ID and bundle id there.
