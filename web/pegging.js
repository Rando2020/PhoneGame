/* THE PLAY — real cribbage has two scoring phases, and we only ever built one.
   The show (counting your hand) is the whole game so far. This is the other half:
   you and the Spoiler alternate laying your four cards toward 31, scoring as you
   go. Short, tense, and it reuses cards you already committed. */

const PEG_TARGET = 31;

function pegScore(pile) {
  /* Score the card just laid, against the run of cards since the last reset. */
  const out = [];
  const total = pile.reduce((t, c) => t + cval(c), 0);

  if (total === 15) out.push({ label: "Fifteen", points: 2 });
  if (total === PEG_TARGET) out.push({ label: "Thirty-one", points: 2 });

  // pairs: how many cards back share the laid rank
  let same = 0;
  for (let i = pile.length - 1; i >= 0; i--) {
    if (pile[i].rank === pile[pile.length - 1].rank) same++;
    else break;
  }
  if (same === 2) out.push({ label: "Pair", points: 2 });
  if (same === 3) out.push({ label: "Three of a kind", points: 6 });
  if (same === 4) out.push({ label: "Four of a kind", points: 12 });

  // runs: the longest tail that forms a consecutive set, 3 or more
  for (let n = pile.length; n >= 3; n--) {
    const tail = pile.slice(-n).map((c) => c.rank).sort((a, b) => a - b);
    let ok = true;
    for (let i = 1; i < tail.length; i++) if (tail[i] !== tail[i - 1] + 1) { ok = false; break; }
    if (ok) { out.push({ label: `Run of ${n}`, points: n }); break; }
  }
  return out;
}

class PegPlay {
  constructor(round, hand, oppHand) {
    this.round = round;
    this.mine = hand.slice();
    this.theirs = oppHand.slice();
    this.pile = [];
    this.total = 0;
    this.score = 0;
    this.oppScore = 0;
    this.log = [];
    /* You hold the Crib, so in cribbage terms you are the dealer — which means
       the Spoiler leads and you play second. Responding is the advantage. */
    this.turn = "them";
    this.over = false;
  }

  canPlay(cards) { return cards.some((c) => this.total + cval(c) <= PEG_TARGET); }
  playable(i) { return this.total + cval(this.mine[i]) <= PEG_TARGET; }

  reset(reason) {
    this.log.push({ who: "-", label: reason, points: 0 });
    this.pile = [];
    this.total = 0;
  }

  lay(who, card) {
    const hand = who === "you" ? this.mine : this.theirs;
    const i = hand.indexOf(card);
    if (i >= 0) hand.splice(i, 1);
    this.pile.push(card);
    this.total += cval(card);
    const events = pegScore(this.pile);
    let gained = 0;
    for (const e of events) {
      gained += e.points;
      this.log.push({ who, label: e.label, points: e.points, card });
    }
    if (who === "you") this.score += gained; else this.oppScore += gained;
    const hit31 = this.total === PEG_TARGET;
    if (hit31) this.reset("Thirty-one — reset");
    this.lastLay = { who, card, events, gained, hit31 };
    return gained;
  }

  /* The Spoiler plays greedily: take points now, otherwise dump the biggest card
     that still fits. Simple, but it punishes careless leads. */
  oppTurn() {
    const legal = this.theirs.filter((c) => this.total + cval(c) <= PEG_TARGET);
    if (!legal.length) return null;
    let best = legal[0], bestPts = -1;
    for (const c of legal) {
      const pts = pegScore(this.pile.concat([c])).reduce((t, e) => t + e.points, 0);
      const score = pts * 10 + cval(c);
      if (score > bestPts) { bestPts = score; best = c; }
    }
    return best;
  }

  step() {
    /* Advance until it's the player's turn again, or the play is finished. */
    let guard = 0;
    while (guard++ < 20) {
      if (!this.mine.length && !this.theirs.length) {
        if (this.pile.length) { this.log.push({ who: "you", label: "Last card", points: 1 }); this.score += 1; }
        this.over = true;
        return;
      }
      const iCan = this.canPlay(this.mine);
      const theyCan = this.canPlay(this.theirs);
      if (!iCan && !theyCan) {
        const who = this.turn === "you" ? "them" : "you";
        this.log.push({ who, label: "Go", points: 1 });
        if (who === "you") this.score += 1; else this.oppScore += 1;
        this.reset("Go — reset");
        this.turn = "you";
        continue;
      }
      if (this.turn === "you") {
        if (iCan) return;                     // wait for input
        this.log.push({ who: "them", label: "Go", points: 1 });
        this.oppScore += 1;
        this.turn = "them";
        continue;
      }
      if (theyCan) {
        const c = this.oppTurn();
        if (c) this.lay("them", c);
        this.turn = "you";
      } else {
        this.turn = "you";
      }
    }
    this.over = true;
  }
}

if (typeof module !== "undefined") module.exports = { PegPlay, pegScore, PEG_TARGET };
