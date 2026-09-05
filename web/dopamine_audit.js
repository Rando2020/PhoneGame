/* Structural dopamine audit. Compares the loop against the design patterns that
   the reference games are built on, then flags where ours breaks them. */
Object.assign(global,{SUIT_SYM:{S:"\u2660",H:"\u2665",C:"\u2663",D:"\u2666"}});
const C=require("./cribbage.js");
Object.assign(global,{countHand:C.countHand,countPoints:C.countPoints,keepOptions:C.keepOptions,
  keepEVFast:C.keepEVFast,keepOptionsEV:C.keepOptionsEV,cDeck:C.cDeck,cShuf:C.cShuf});
const R=require("./cribrogue.js");
const fs=require("fs");
const ui = fs.readFileSync("cribrogue_ui.js","utf8");
const cas = fs.readFileSync("cascade.js","utf8");

const rows=[];
const check=(pattern, game, ours, verdict)=>rows.push({pattern,"seen in":game,ours,verdict});

// --- 1. is the goal always on screen?
const targetOnPlay = /rd\.score.*rd\.target/.test(ui);
const targetOnCascade = /target/.test(cas);
check("Goal visible at all times","Balatro (blind requirement pinned)",
  targetOnPlay? "play: YES, cascade: "+(targetOnCascade?"yes":"NO") : "NO",
  targetOnCascade? "PASS":"FAIL");

// --- 2. are the items on screen while they act?
const charmOnCascade = /cribCharmRow|cascadecharms|firing/i.test(cas);
check("Items visible while they trigger","Balatro (joker row always up, wiggles in turn)",
  charmOnCascade? "yes":"charms hidden during the count",
  charmOnCascade? "PASS":"FAIL");

// --- 3. is required pace shown?
const pace = /NEEDED|to go|pace/i.test(ui);
check("Distance-to-goal / required pace","Balatro (you can compute if you'll make it)",
  pace? "yes":"only a raw bar, no numbers", pace? "PASS":"FAIL");

// --- 4. are negative effects legible when they bite?
const blocked = /blocked|BLOCKED|suppress/i.test(cas+ui);
check("Penalties visible at the moment they apply","Slay the Spire (intent telegraph + debuff icons)",
  blocked? "yes":"boss rule is one small line; you never see it fire",
  blocked? "PASS":"FAIL");

// --- 5. session hook
const persist = /localStorage/.test(ui) && /Meta\.record/.test(ui);
check("Cross-run progress hook","Balatro/Spire (unlocks, best runs)",
  persist? "yes":"nothing persists between runs", persist? "PASS":"FAIL");

// --- 6. context preservation
const screens = (ui.match(/screen\("/g)||[]).length;
const hudEverywhere = /cribHUD/.test(cas) && /cribHUD/.test(ui);
check("Goal + items persist across screens","Balatro (never leaves the play field)",
  hudEverywhere ? "HUD pinned to table AND count screen" : `${screens} screens, context lost`,
  hudEverywhere ? "PASS" : "PARTIAL");

// --- 7. reward cadence
const perRound = R.CRIB_DEALS;
check("Reward events per round","Balatro ~4 scored hands per blind",
  `${perRound} counts + 1 crib payout = ${perRound+1}`, "PASS");

// --- 8. silhouette readability
const gen = fs.readFileSync("../tools/make_creatures.py","utf8");
const tables = [...gen.matchAll(/def draw_(pip|thump|clover|facet)\(\)[\s\S]*?\[([\d,\s]+)\]/g)]
  .map(m => ({ id: m[1], hws: m[2].split(",").map(Number).filter(n=>!isNaN(n)) }));
const shapes = tables.map(t => `${t.id} h${t.hws.length}/w${Math.max(...t.hws)}`);
const distinct = new Set(tables.map(t => `${t.hws.length}/${Math.max(...t.hws)}`)).size;
check("Characters distinguishable in silhouette","Any roster game",
  shapes.join("  "), distinct === tables.length ? "PASS" : "FAIL");

console.table(rows);

// --- how often do boss rules actually bite?
console.log("\n=== how often does each boss rule actually change a hand? ===\n");
for (const b of R.BOSS_POOL.slice(0,8)) {
  let bit=0, N=400;
  for (let i=0;i<N;i++){
    const run=new R.CribRun("thump");
    const rd=new R.CribRound(run);
    rd.newDeal();
    const k=rd.bestKeepEV().idx;
    const hand=k.map(j=>rd.dealt[j]);
    rd.cutStarter();
    const normal=countHand(hand, rd.starter, false, {}).base;
    const under =countHand(hand, rd.starter, false, b.rule).base;
    if (under !== normal) bit++;
  }
  console.log(`  ${b.name.padEnd(16)} changes the hand ${(100*bit/N).toFixed(0).padStart(3)}% of deals`);
}
