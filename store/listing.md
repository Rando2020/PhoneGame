# Meldlings: App Store listing

Every field below goes into App Store Connect as written. The limits are
Apple's, and `python3 tools/check_listing.py` checks every one (plus no em
dashes and no emoji). Numbers come from the game data (pass 11): 53 charms,
6 Meldlings (+4 ascended forms), 17 Spoilers, 6 marks, 17 deeds, 8 streets,
8 trials, 5 acts of 3 rounds.

**Needs Ziah:** the two URLs, the copyright line, a final yes on the age
rating answers (especially simulated gambling, see below), and the unlock's
price (set in App Store Connect; $2.99 suggested, $0.99 launch week).

## In-app purchase (App Store Connect)

```text
Type: Non-Consumable. Product ID: com.meldlings.full. Reference name: Full game. Display name: Full game. Description: Unlock acts 2 to 5, every street, the trials and the Long Count.
```

## Name (30)

```text
Meldlings: Cribbage Roguelite
```

## Subtitle (30)

```text
Keep four. Count big. Go deep.
```

## Promotional text (170)

```text
Cribbage hands meet roguelite runs. Free to try: play act 1 and its Spoiler. One purchase unlocks the full game. No ads, no account.
```

## Description (4000)

```text
Meldlings is cribbage turned into a roguelite run.

Each deal gives you six cards. Keep four, throw two to your Crib, then the cut decides. Fifteens, pairs, runs and flushes tick up one by one, then your multiplier slams down. Beat the round's target in four deals and you move on.

HOW A RUN WORKS
- 5 acts of 3 rounds. Every third round is a Spoiler: a boss with a rule that breaks something, like "pairs score half" or "you keep one card fewer".
- An act's first round brings a twist, a small rule like "pairs score 4" that changes the best keep, for a slightly higher target. Its second round runs short: whatever you have scored most with scores half, so you have to play another way.
- Between rounds, spend Glim at the Peg House on charms, marked cards and Reckonings that level up a scoring type.
- The Play: after the count, peg to 31 against the Spoiler. What you peg rides your multiplier into your score.

WHAT'S IN IT
- 53 charms across 5 rarities. Five slots, so you choose.
- 6 Meldlings to play as, each with its own face and its own trick, and 4 ascended forms to unlock.
- 17 Spoilers, five drawn per run, so no two runs meet the same set.
- 6 card marks: Sunlit, Brittle, Mimic, Offering, Minted and Fickle.
- 8 streets, 8 trials and 17 deeds to earn.
- A Gallery of every card, mark, back, Meldling and Spoiler, and a charm collection to fill: each charm moves from unseen to seen, owned and won with.

MADE FOR A PHONE
- Drag or tap. Flick a card up to throw it to your Crib, down to keep it.
- Haptics on the big moments, and sound you can turn off.
- Text size and Reduce Motion settings.
- Plays offline. No ads, no account, no data collected.

FREE TO TRY
- Every run plays act 1 in full, through its Spoiler, with all four starting Meldlings, The Play, the Peddler and the Gallery.
- One purchase unlocks the full game for good: 4 more acts, then 7 more streets, 8 trials and the Long Count to earn.
- No ads, no subscriptions, nothing random for sale.

New to cribbage? The 8-step How to play covers it in a minute.
```

## Keywords (100)

```text
card game,roguelike,deckbuilder,solitaire,pegging,fifteen,crib,cards,strategy,offline,boss,puzzle
```

## What's new (4000)

```text
First release. Free to try; one purchase unlocks the full game.
```

## Support URL

```text
https://rando2020.github.io/PhoneGame/support.html
```

Ready in `docs/support.html`. **Needs Ziah:** turn on GitHub Pages (repo
Settings > Pages > deploy from a branch, folder `/docs`) on the branch that
holds it, and put your email in the page (marked NEEDS ZIAH). The URL works
only after that (unverified until Pages is on). Pages on a private repo needs
a paid GitHub plan (unverified for your account); everything in `docs/`
becomes public.

## Privacy policy URL

```text
https://rando2020.github.io/PhoneGame/privacy.html
```

Ready in `docs/privacy.html` ("Data Not Collected", matching
`godot/ios/PrivacyInfo.xcprivacy`). Same Pages step as above; add your email.

## Copyright

```text
NEEDS ZIAH: e.g. 2026 Josiah Parve
```

## Category

```text
Primary: Games > Card. Secondary: Games > Strategy.
```

## Age rating answers

All "None", except where noted. Expected result: 4+ (unverified; Apple
computes it from the answers).

- Cartoon or fantasy violence: None (Spoilers are characters; nothing is hurt)
- Realistic violence: None
- Sexual content or nudity: None
- Profanity or crude humor: None
- Alcohol, tobacco or drug use: None
- Mature or suggestive themes: None
- Horror or fear themes: None
- Medical or treatment information: None
- **Simulated gambling: None (Ziah to confirm).** Cribbage is a card game and
  nothing can be bought, but some rounds are called a "Wager" (score exactly
  the target to keep a reward). If Apple reads that as simulated gambling,
  "Infrequent" raises the rating (unverified by how much).
- Contests: None
- Unrestricted web access: No
- User-generated content: No
- In-app purchases: Yes (one non-consumable, "Full game"; no random items)

## App privacy ("nutrition label")

Answer: **Data not collected.** Matches `godot/ios/PrivacyInfo.xcprivacy`
(no tracking, no tracking domains, no collected data types). The manifest's
four "required reason" API entries (file timestamps C617.1, system boot time
35F9.1, disk space E174.1, user defaults CA92.1) are the engine reading its
own save and clock; none of them is data collection.
