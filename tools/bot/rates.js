const C=require('./core_loader.js');const N=+process.argv[2]||8000;
const diffs=['easy','medium','hard','master'];const tot={};
console.log('level'.padEnd(16)+diffs.map(d=>d.padStart(9)).join(''));
for(let i=0;i<C.LEVELS.length;i++){const row=[];
 for(const d of diffs){let w=0;for(let n=0;n<N;n++){const r=C.newRun(i,d);let next=0;
  for(let f=0;f<1200;f++){if(f>=next&&r.p.ammo>0){const a=Math.random()*6.283;C.fire(r,Math.cos(a),Math.sin(a));next=f+5+Math.floor(Math.random()*(r.rope?70:40));}
   const res=C.tick(r);r.events.length=0;if(res==='win'){w++;break}if(res==='dead')break;}}
  row.push(w);tot[d]=(tot[d]||0)+w;}
 console.log(`${String(i+1).padStart(2)}. ${C.LEVELS[i].name.padEnd(12)}`+row.map(w=>(w/N*100).toFixed(2).padStart(8)+'%').join(''));}
console.log('TOTAL wins      '+diffs.map(d=>String(tot[d]).padStart(9)).join(''));
