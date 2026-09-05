const vm = require("vm"); const fs = require("fs"); const dom = require("./domtest.js");
const html = fs.readFileSync("../meldlings.html","utf8");
const blocks=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m=>m[1]);
const sandbox=Object.assign({},dom,{console,setTimeout,clearTimeout,setInterval,clearInterval,
  Math,Date,JSON,Object,Array,String,Number,Boolean,Set,Map,Promise,Error,isNaN,parseInt,parseFloat});
sandbox.globalThis=sandbox; sandbox.window=Object.assign(sandbox.window,sandbox);
const ctx=vm.createContext(sandbox);
blocks.forEach(b=>{try{vm.runInContext(b,ctx);}catch(e){}});
const run=s=>vm.runInContext(s,ctx);

run('Cb.street = STREETS[0]; Cb.run = new CribRun("pip", Cb.street);');
run('Cb.round = new CribRound(Cb.run); Cb.round.newDeal(); Cb.keep=[]; renderCrib();');

/* Walk the rendered tree and estimate vertical budget on a 390x844 phone. */
const EST = { p:20, div:26, h2:34, button:56, label:22, span:0 };
function measure(node, depth=0, out=[]) {
  for (const c of node.children||[]) {
    const cls=[...(c.classList?._set||[])].join(".");
    let h=0;
    if (cls.includes("hand")) h=200;
    else if (cls.includes("panel")) h=0;
    else if (cls.includes("decktrack")) h=34;
    else if (cls.includes("cribwrap")) h=70;
    else if (cls.includes("charmrow")) h=34;
    else if (c.tagName==="BUTTON") h=EST.button;
    else if (c.tagName==="P") h=EST.p;
    else if (c.tagName==="H2") h=EST.h2;
    else if (c.tagName==="DIV" && !(c.children||[]).length) h=EST.div;
    if (h) out.push({ el: cls || c.tagName.toLowerCase(), h, depth });
    measure(c, depth+1, out);
  }
  return out;
}
const items = measure(dom.app);
const total = items.reduce((t,i)=>t+i.h,0);
console.log("PLAY SCREEN — estimated vertical budget on a 390x844 phone\n");
console.log("  element                       est px");
for (const i of items) console.log("  " + i.el.slice(0,28).padEnd(30) + String(i.h).padStart(5));
console.log("  " + "-".repeat(36));
console.log("  TOTAL".padEnd(30) + String(total).padStart(5));
console.log("  viewport (minus browser chrome)".padEnd(30) + "  ~700");
console.log("\n  overflow: " + (total-700) + "px  -> " + ((total/700).toFixed(2)) + " screens of content");

const groups = {
  "always needed": ["hud","hand","btn","banner","selcount"],
  "reference only": ["decktrack","cribwrap","charmrow","small"],
};
let need=0, ref=0;
for (const i of items) {
  if (groups["reference only"].some(g=>i.el.includes(g))) ref+=i.h; else need+=i.h;
}
console.log("\n  essential to the decision : " + need + "px");
console.log("  reference / could collapse: " + ref + "px  (" + Math.round(100*ref/total) + "% of the screen)");
