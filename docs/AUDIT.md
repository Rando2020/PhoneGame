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


# Re-check, 2026-10-19 (after pass 9)

Measured by tests, not by hand: `text_size_test` (13 screens x 2 shapes x 3
text sizes), `dead_space_test`, `menu_slide_test`, `drag_test`, `os_access_test`.
Every new check was mutation-tested (each fails when its fix is undone).

| # | finding | status | measured now |
|---|---|---|---|
| 1 | Text too small | fixed (floor) | 0 of 227 labels under 20 px (11 pt) at 720x1560; also 0 at 720x1280 and at Large and Larger. No text off screen, trimmed or overlapping on any of 78 screen states. Body text is 21 to 22 px (11.5 to 12 pt): over Apple's floor, under the 17 pt default for reading apps |
| 7 | Screens cut | fixed | menu steps slide on the RunFlow spring (in from the right going deeper, the left going back); cross-fade with Reduce Motion |
| 8 | Cards can't be dragged | fixed | keep hand: 1:1 drag holding the grab point; flick up throws, flick down keeps; release hands its speed to a spring home; tap still works (now on release, 0.97 on touch-down). Same keep as by taps |
| 9 | Reduce Motion ignores the phone | partly | in-game switch works everywhere; the phone's setting is wired through a plugin hook (tested with a stand-in); the plugin itself needs a Mac (PORT.md) |
| 10 | Text ignores the phone's text size | partly | in-game Text size (3 steps, every screen re-laid out); the phone's setting comes through the same hook; plugin needs a Mac |
| 12 | Dead space | fixed | tallest empty band, intro and round end, was 25 to 47% of the height; now 5 to 16% (act track, your charms, the Meldling grows into spare room, block centred) |
| 18 | Safe areas | unverified | needs a simulator or device (PORT.md checklist, step 6) |

Found this pass:
- The Play store screenshot rendered at the wrong width (since pass 8): fixed; the shot is now a busier moment (6 cards on the pile at 23, 7 to 6).
- On tall phones The Play still has an empty middle between the pile and your hand.


# Re-check, 2026-10-19 (after pass 10)

New tests: `peg_drag_test`, `live_text_test`, `drag_hint_test`; The Play added to
`dead_space_test`; body text, two How to play steps, three Gallery tabs and
"text on a card" added to `text_size_test` (96 screen states, 541 checks).
Every new check was mutation-tested.

| item | before | after |
|---|---|---|
| The Play, tallest empty band | 15 to 41% of the height (payout 41% at 720x1560) | 5 to 16%: your Meldling and the Spoiler face off and react to each lay, both sides' pegs as a track, the round so far |
| Reading text at 17 pt (31 px) or more | 0 of 48 lines | 50 of 50 (deeds, charms, Meldlings, decks, Spoilers, marks, How to play); names at the same size in gold |
| Drag in The Play | tap only | 1:1 drag; flick up onto the pile lays it; 16 lays across 4 seeds: drag and tap leave the same play, step for step |
| Text size changes (#10) | next screen | the screen you're on, from Settings or from iOS (5 screens, 3 sizes, 43 checks) |
| Drag hint | none | one line on the first deal ever, saved at the first Keep; a 7th How to play step after the web's 6 (which still match the web word for word) |
| iOS plugin (#9, #10) | spec only | source in `ios_plugin/meld_access/`; **unverified**: never compiled (needs a Mac) |

Bugs found by the new checks, fixed:
- Gallery and How to play cards were drawn shifted (a card scales about its
  centre; `_card_at` placed its unscaled corner): suit headings and two
  How to play labels sat on cards.
- The Play: "of 31" overlapped the count.
- Touch-down feedback reset a small card (The Play draws them at 0.82) to full size.
- A finger that stopped before lifting still flicked (release speed now 0 after 50 ms still).
- A held card kept its hover sway under the finger (drag_test caught it 1 run in 2).
- The Play printed the Spoiler's name again over its score; it's "THEM" (the character is the name).

Still open: #18 safe areas (device), the plugin build (Mac).


# Re-check, 2026-10-20 (after pass 11)

New: `store/listing.md` + `tools/check_listing.py`; the app preview
(`tests/preview_run.gd`, `tools/make_preview.sh`, `tools/check_preview.py`);
`frame_time_test`, `soak_test` (+ `tools/soak.sh`), `reach_test`;
`docs/MAC_HANDOFF.md`. Every new check was mutation-tested.

**Listing.** Every field within Apple's limits (name 29/30, subtitle 30/30,
promotional 148/170, description 1400/4000, keywords 97/100). Every count in
the description is read from the game data (53 charms, 6 + 4 Meldlings, 17
Spoilers, 6 marks, 17 deeds, 8 streets, 8 trials, 5 acts of 5 rounds, 7 How
to play steps). Needs Ziah: support URL, privacy policy URL, copyright, and the
"simulated gambling" age-rating answer (the Wager rounds).

**App preview.** 21.0 s of a real run (deal, keep by flicks and taps, the
count, The Play laid by flicks, the shop and a purchase), 886x1920, H.264 High
4.0, 30 fps, 10 Mbps, 26.8 MB, the game's own sound as 256 kbps stereo AAC.
Checked against Apple's App Preview specifications page (read 2026-10-19):
15 to 30 s, at most 500 MB, up to 30 fps, 886x1920 for 6.9" and 6.5".

**Frame time** (headless, this shared machine; median worst frame of 3 passes,
wall time; an idle frame costs a 6.9 ms floor here):

| screen | before | after |
|---|---|---|
| first deal | 38 to 42 ms | 13 to 23 ms (warm-up builds the screens and card art at launch) |
| commit and count | 15 to 21 ms | 14 to 16 ms |
| The Play | not measured | 14 to 18 ms |
| shop, opening frame | 45 to 52 ms (drawn twice) | 26 to 36 ms (drawn once) |
| Gallery cards, opening frame | 27 ms | 22 to 24 ms |
| every other frame, all screens | | 7 to 9 ms |
| cards running _process at rest | 52 (Gallery) | 0 |

Still over 16.7 ms: the shop's and the Gallery's opening frame (text shaping,
about 0.4 to 0.8 ms a label here) and, on some passes, the first deal. Device
speed is unverified; the fix if it shows is building those screens over
several frames. Timing is reported, not gated (the same run varied 2x to
10x here); the gates are no card processing at rest and the warm-up done.

**Soak.** 200 full runs, 0 fails, 0 script or engine errors (19 min): 2,114
deals kept by 4,279 flicks and 4,389 taps, 8,373 lays in The Play, 444 buys,
110 rerolls, 48 sells; 2,445 saves resumed and saved again, identical, at every
kind of moment (keep, counted, mid-Play, after the Play, round end, shop,
intro); no node or orphan growth from run 1 to run 200. Limit: runs average
about 3 rounds (no run won), so acts 2 to 5 are covered by the other suites,
not the soak. Found and fixed: a save made in the keep
phase carried the last deal's Play cards (stale `peg_kept`; on resume a -1
index read as the deal's last card); a button freed in the frame it was added
logged an engine error (Press's deferred hookup now holds a weak reference).
Also found by the suites this pass: a resize landing mid-draw left the intro
laid out for the pre-layout width (the Spoiler 7 px off the edge); RunFlow now
checks for a redraw after the draw, deferred.

**Larger text on long screens (with an iPhone 16 Pro Max's safe area
simulated: 109 px top, 63 px bottom).** 210 buttons on 21 screens at 720x1280
and 720x1560 are reachable: on screen inside the safe area, or (52) scrolled
fully inside both the scroll view and the safe area. Found and fixed: at
Larger text on the short phone the intro's Spoiler list ran under the home
bar (the art now shrinks, to 90 px, when short of room); the title's "How to
play" button was clipped (the icon row wraps, and goes to rows of three when a
word won't fit; the probe now checks button text too).

#18 safe areas: checked in software against simulated insets; still needs a
simulator or device to confirm (MAC_HANDOFF.md, step 5).


# Re-check, 2026-10-20 (after pass 12)

New: `staged_build_test`, `resize_guard_test`, the strong-player soak
(`SOAK_STRONG=1 tools/soak.sh 50`), `docs/support.html`, `docs/privacy.html`,
`docs/RELEASE_CHECKLIST.md`. Every new check was mutation-tested.

**Opening frames.** The shop builds in 4 stages (one per frame while its page
slides in); every Gallery tab builds its rows on a 4 ms-a-frame budget, and a
tab tap swaps only the list. Same machine, back to back, median worst frame
of 3 passes:

| frame | before | after |
|---|---|---|
| shop, opening | 45 ms | 26 ms |
| Gallery, opening | 50 ms | 18 ms |
| Gallery, Meldlings tab tap | 92 ms | 11 ms |
| Gallery, Spoilers tab tap | 219 ms | 15 ms |
| Gallery, other tabs | 14 to 20 ms | 8 to 13 ms |

Built over frames, each screen ends identical to building it at once (class,
text, rect and state of every node; `staged_build_test`). Still over 16.7 ms
on this machine: the shop's and Gallery's opening frame (the page itself),
and, on slow runs, the deal, the count and The Play (13 to 15 ms on a quiet
run, 21 to 28 ms on this one; not touched this pass). Device speed unverified.

**Resize guard.** FrontDoor, the shop and The Play check for a redraw after the
draw, as RunFlow does. A resize landing mid-draw ends drawn for the new size,
with nothing past the new width; a notice at the same size doesn't redraw.

**Deep soak.** 50 strong runs: 0 fails, 0 errors; 27 reached act 3 or later
(4 reached act 5), 1 won; 194 Spoiler rounds; 1,887 saves round-tripped.

**Pages.** Support and privacy, in the game's colours; privacy states "Data
Not Collected" as the manifest does. Need Ziah: an email, and GitHub Pages on.

Found and fixed: spoiler_test had been reading the intro mid-slide; it passed
before only because an extra redraw cut the slide short (now gone).
