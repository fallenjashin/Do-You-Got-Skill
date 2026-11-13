// Exploration solver: remembers every new spot it reaches, restarts from promising spots, explores randomly.
const C=require('./core_loader.js');
function cellKey(r){const p=r.p;return [Math.floor(p.x/30),Math.floor(p.y/30),r.phased?1:0,r.g,r.rope?1:0,p.ammo,Math.floor(r.t/40)%4].join(',');}
function solve(i,budget=60000,diff="medium"){
  const start=C.newRun(i,diff);start.started=true;
  const arch=new Map();arch.set(cellKey(start),{s:structuredClone(start),v:0});
  let keys=[...arch.keys()];
  for(let it=0;it<budget;it++){
    // pick a cell, favouring rarely-visited ones
    let k=keys[Math.floor(Math.random()*keys.length)];
    for(let j=0;j<3;j++){const k2=keys[Math.floor(Math.random()*keys.length)];if(arch.get(k2).v<arch.get(k).v)k=k2;}
    const e=arch.get(k);e.v++;
    const r=structuredClone(e.s);let next=Math.floor(Math.random()*15);
    for(let f=0;f<120;f++){
      if(f>=next&&r.p.ammo>0){const a=Math.random()*6.283;C.fire(r,Math.cos(a),Math.sin(a));next=f+4+Math.floor(Math.random()*(r.rope?70:35));}
      const res=C.tick(r);r.used=r.used||{};for(const ev of r.events)r.used[ev]=1;r.events.length=0;
      if(res==="win")return {it,t:r.t,cells:arch.size,used:Object.keys(r.used).filter(x=>["latch","phase","unphase","grav","tp","orb"].includes(x)).join("+")};
      if(res==='dead')break;
      const ck=cellKey(r);if(!arch.has(ck)){arch.set(ck,{s:structuredClone(r),v:0});keys.push(ck);}
    }
  }
  return {it:budget,t:null,cells:arch.size};
}
const which=process.argv[2]?process.argv[2].split(',').map(Number):C.LEVELS.map((_,i)=>i);
for(const i of which){const res=[];for(let k=0;k<3;k++)res.push(solve(i));
  const ok=res.filter(x=>x.t!==null);
  console.log(`${String(i+1).padStart(2)}. ${C.LEVELS[i].name.padEnd(11)} solved ${ok.length}/3  avg search ${Math.round(res.reduce((a,b)=>a+b.it,0)/3)}  used: ${ok.map(x=>x.used||'-').join(' | ')}`);}
