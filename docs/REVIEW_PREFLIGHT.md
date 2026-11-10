# Review preflight: what to answer, and what Apple will check

Read this before you open App Store Connect. It has the answers to paste into
the App Privacy and Age Rating forms, and a check of the purchase flow against
App Review Guidelines 3.1.1 (in-app purchase) and 5.1 (privacy).

Checked 2026-11-09 against the code on `release/1.0` (PR #12). Guideline
wording comes from Apple's pages as quoted by recent sources (2026); open the
live guidelines once before submitting. "Unverified" means nobody has seen it
on a real iPhone yet.

---

## 1. Findings first

| # | finding | risk | fix | who |
|---|---|---|---|---|
| F1 | **Restore Purchases lives only on the end card**, which a player sees only after beating act 1's Spoiler. Someone who bought the game, then reinstalls or gets a new iPhone, has to replay act 1 before they can restore. | **High.** 3.1.1 asks for a restore mechanism, and reviewers usually look for it in Settings or on the title screen. A missing or hard-to-find Restore is one of the most common IAP rejections. | Add a **Full game** row to Settings: `Unlock · $price` when locked, `Restore Purchases` always, `Unlocked` once owned. Same calls as the end card (`Entitlement.store()`, `purchase`, `restore`). | AI session (task in FINISH_LINE Phase 1) |
| F2 | **The reviewer must win act 1 to reach the purchase.** The unlock button exists only on the end card. Reviewers often don't play that far. | **Medium.** If they can't find the IAP they reject or stall the review ("we were unable to locate the in-app purchase"). | The F1 Settings row fixes this too. Also say where it is in the review notes (section 5). | AI session (same task) |
| F3 | **No privacy policy link inside the app.** 5.1.1(i) wants the policy linked in App Store Connect *and* reachable in the app. | **Low to medium.** Often waved through for apps that collect nothing, but it's a stated requirement. | Settings gets a `Privacy policy` row that opens `https://rando2020.github.io/PhoneGame/privacy.html` (`OS.shell_open`). Needs Pages on first (Phase 1). | AI session (same task) |
| F4 | **The age rating questionnaire changed** after `store/listing.md` was written: new questions on in-app controls, capabilities, medical or wellness, violent themes, and (required from September 2026) social media. Simulated gambling now rates 13+ if "Infrequent". | **Low**, if answered as in section 3. | Use section 3, not the old list in `store/listing.md`. | Ziah |
| F5 | The rounds are called **Wagers**, which reads like gambling. Nothing is staked: a Wager asks for an exact score, the prize is an unlock (split cards), and missing it costs the prize, not the run (`crib_round.gd`, `settle()`). | **Low.** | Answer simulated gambling "None" and explain it in the review notes. | Ziah confirms |

Everything else checks out (sections 2 to 4).

---

## 2. App Privacy (the "nutrition label")

App Store Connect > your app > App Privacy > Get Started.

**Do you or your third-party partners collect data from this app?**
Answer: **No, we do not collect data from this app.**

The label then reads **Data Not Collected**. Why that's true, from the code:

| possible source | what the build does | collected? |
|---|---|---|
| Analytics, crash reporting, ads, tracking SDKs | none in the build | no |
| Network | the game makes no HTTP requests (no `HTTPRequest` or `HTTPClient` in `godot/`) | no |
| The in-app purchase | handled by Apple's StoreKit; the game stores one "full" flag on the device | no (Apple's data, not yours) |
| Save, Record, Deeds, settings | saved on the device only (`user://`) | no |
| Share a run card | the iOS share sheet; the player picks where it goes; nothing reaches you | no |
| Playtest log | only in builds with the `playtest` feature (the desktop playtest presets). The iOS preset has none (`custom_features=""`), and `Playtest.enabled()` checks it | no |
| Required-reason APIs | `godot/ios/PrivacyInfo.xcprivacy`: file timestamps C617.1, boot time 35F9.1, disk space E174.1, user defaults CA92.1. The engine reading its own save and clock | not collection |
| Tracking | `NSPrivacyTracking` false, no tracking domains | no |

**Privacy policy URL:** `https://rando2020.github.io/PhoneGame/privacy.html`
(live once Pages is on and the email is filled in; NEEDS ZIAH).

---

## 3. Age rating answers (current questionnaire)

App Store Connect > your app > App Information > Age Rating > Edit.

Apple computes the rating from the answers. Expected result: **4+**
(unverified until App Store Connect shows it). If you answer simulated
gambling "Infrequent", expect **13+** instead.

**Content (frequency questions):** answer **None** to all of these.

- Cartoon or fantasy violence: None (Spoilers are characters you outscore; nothing is hurt)
- Realistic violence: None
- Prolonged graphic or sadistic violence: None
- Violent themes (new): None
- Sexual content or nudity: None
- Profanity or crude humor: None
- Alcohol, tobacco or drug use or references: None
- Mature or suggestive themes: None
- Horror or fear themes: None
- Medical or treatment information / medical or wellness topics (new): None
- **Simulated gambling: None** (see F5; NEEDS ZIAH: confirm)
- Contests: None
- Loot boxes or paid random items: **No** (one fixed unlock; no random items for money)

**Capabilities and controls (new):**

- Unrestricted web access: No
- User-generated content: No
- Messaging or chat: No
- Social media, or a feed of other people's content: No
- Advertising: No
- AI chatbot or generated content: No
- In-app controls (parental controls, age assurance): None. The game has nothing to filter.

**Made for Kids:** No. Don't put it in the Kids category; that adds rules
(no outside links, a parental gate before any purchase) for no gain.

---

## 4. The purchase flow vs 3.1.1 and 5.1

The flow (code: `godot/ui/run_flow.gd` `show_free_end`,
`godot/engine/entitlement.gd`; rules: `docs/MONETIZATION.md`).

| check | guideline | status |
|---|---|---|
| Unlocking more of the game uses Apple's in-app purchase, not a key, code or outside payment | 3.1.1 | **pass** (`MeldStore.purchase("com.meldlings.full")`) |
| Product is a non-consumable, so it can be restored | 3.1.1 | **pass** in code; set the type to Non-Consumable in App Store Connect (MAC_HANDOFF 3b) |
| A restore mechanism exists | 3.1.1 | **partial**: on the end card only. See F1 |
| Restore uses StoreKit, never asks for an Apple ID or password | 3.1.1 | **pass** in code (`restore()` on the plugin); unverified on a device |
| The price shown is the store's localized price | 3.1.1 | **pass** (`Entitlement.price()` reads it from StoreKit; before it answers, the button says "UNLOCK THE FULL GAME" with no number) |
| The card says plainly what you get | 3.1.1, 3.1.2-style clarity | **pass** (`Entitlement.pitch()`: counts from the data, "One purchase. No ads, no account.") |
| **Not now** always works and ends the run fairly | 3.1.1, 5.6 (no manipulation) | **pass** (recorded, Pegs paid; card shows once a run, after a win, never mid-play or after a loss) |
| Cancel or failure leaves the game unchanged and says so | 3.1.1 | **pass** ("Purchase cancelled. Nothing changed." / "didn't go through (reason)") |
| What's free works fully without paying (act 1, its Spoiler, four Meldlings, The Play, Gallery, Daily to act 1) | 2.1, 3.1.1 | **pass** (soak in free mode) |
| Purchase does not change scoring (no pay-to-win in a single-player game; just fair) | design rule 7 | **pass** (parity passes unlocked) |
| A shipped build without the store plugin gives nothing away | 3.1.1 | **pass** (`full()` is true without the plugin only in the editor) |
| The IAP can be found and tested by the reviewer | App Review process | **at risk**: see F2 |
| Data collection disclosed, privacy policy in ASC | 5.1.1, 5.1.2 | **pass** (Data Not Collected; URL ready once Pages is on) |
| Privacy policy reachable inside the app | 5.1.1(i) | **missing**: see F3 |
| No account required, so no account deletion needed | 5.1.1(v) | **pass** (no accounts) |
| No tracking, so no App Tracking Transparency prompt | 5.1.2 | **pass** |
| Sign in with Apple not needed (no third-party login) | 4.8 | **pass** |
| Native app, not a web view | 4.2 | **pass** (Godot native binary) |

---

## 5. Review notes (paste into App Review Information > Notes)

Use this once F1 to F3 are fixed. Edit the Settings line if the row's label
changes.

```text
Meldlings is a native Godot app (no web view). It plays fully offline, has no
accounts, no ads and collects no data.

Free to try: every run plays act 1 and its boss. One non-consumable in-app
purchase, "Full game" (com.meldlings.full), unlocks acts 2 to 5.

To test the purchase: Settings > Full game > Unlock. Restore Purchases is on the
same row. The same offer also appears at the end of act 1 after the first boss
is beaten.

"Wager" rounds are a scoring challenge: hit the target exactly to win a card
unlock. Nothing is staked or bought, and there is no real or simulated money.
```

---

## 6. Before you press Submit (Ziah)

- [ ] F1 to F3 fixed and on the build you upload (an AI session can do it).
- [ ] Age rating answered as in section 3, and the result is 4+ (or 13+ if you chose Infrequent).
- [ ] App Privacy answered "Data Not Collected".
- [ ] Privacy and support URLs load (Pages on, email filled in). NEEDS ZIAH.
- [ ] In-app purchase `com.meldlings.full` created as Non-Consumable, with a
      price, a review screenshot of the end card, and attached to this version.
- [ ] Paid Apps agreement active (Agreements, Tax, and Banking).
- [ ] On a real iPhone from TestFlight: buy with a Sandbox account, delete the
      app, reinstall, Restore from Settings. Cancel a purchase once.
- [ ] Review notes from section 5 pasted.
