// Fewest-shots search: exploration solver where shots fired is part of the state, keeps the cheapest path to each spot.
const C=require('./core_loader.js');
function key(r){const p=r.p;return [Math.floor(p.x/30),Math.floor(p.y/30),r.phased?1:0,r.g,r.rope?1:0,p.ammo,Math.floor(r.t/40)%4,r.shots].join(',');}
function minShots(i,diff,budget){
  const s0=C.newRun(i,diff);s0.started=true;
  const arch=new Map();arch.set(key(s0),{s:structuredClone(s0),v:0});let keys=[...arch.keys()],best=Infinity;
  for(let it=0;it<budget;it++){
    let k=keys[Math.floor(Math.random()*keys.length)];
    for(let j=0;j<3;j++){const k2=keys[Math.floor(Math.random()*keys.length)];const a=arch.get(k2),b=arch.get(k);
      if(a.s.shots<b.s.shots||(a.s.shots===b.s.shots&&a.v<b.v))k=k2;}
    const e=arch.get(k);e.v++;if(e.s.shots>=best-1)continue;
    const r=structuredClone(e.s);let next=Math.floor(Math.random()*40);
    for(let f=0;f<160;f++){
      if(f>=next&&r.p.ammo>0){const a=Math.random()*6.283;C.fire(r,Math.cos(a),Math.sin(a));next=f+6+Math.floor(Math.random()*(r.rope?80:60));if(r.shots>=best)break;}
      const res=C.tick(r);r.events.length=0;
      if(res==='win'){best=Math.min(best,r.shots);break;}if(res==='dead')break;
      const ck=key(r);if(!arch.has(ck)){arch.set(ck,{s:structuredClone(r),v:0});keys.push(ck);}
    }
  }
  return best;
}
// node par.js <difficulty> [from-to]   e.g. "node par.js master 0-29" (levels outside the range print null)
const diff=process.argv[2],out=[];
const [lo,hi]=(process.argv[3]||'0-'+(C.LEVELS.length-1)).split('-').map(Number);
for(let i=0;i<C.LEVELS.length;i++){if(i<lo||i>hi){out.push(null);continue;}let b=Infinity;for(let k=0;k<3;k++)b=Math.min(b,minShots(i,diff,25000));out.push(b);}
console.log(diff+' '+JSON.stringify(out));
