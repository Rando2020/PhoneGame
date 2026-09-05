const vm=require('vm'),fs=require('fs'),dom=require('./domtest.js');
const html=fs.readFileSync('../meldlings.html','utf8');
const blocks=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m=>m[1]);
const sb=Object.assign({},dom,{console,setTimeout,clearTimeout,setInterval,clearInterval,Math,Date,JSON,
 Object,Array,String,Number,Boolean,Set,Map,Promise,Error,isNaN,parseInt,parseFloat});
sb.globalThis=sb; sb.window=Object.assign(sb.window,sb);
const ctx=vm.createContext(sb);
blocks.forEach(b=>{try{vm.runInContext(b,ctx)}catch(e){console.log('load:',e.message)}});
let fail=0;
for(const t of ['cards','split','marks','backs','meld','spoil']){
  try{ vm.runInContext(`GAL.tab="${t}"; showGallery();`,ctx); console.log('  ok    gallery: '+t); }
  catch(e){ fail++; console.log('  FAIL  gallery: '+t+' -> '+e.message); }
}
console.log(fail? fail+' tabs broken' : 'all 6 gallery tabs render');
process.exit(fail?1:0);
