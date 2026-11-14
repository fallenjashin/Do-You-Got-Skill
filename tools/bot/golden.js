const C=require('./core_loader.js');
// seeded RNG so the reference runs are reproducible
function rng(seed){return()=>{seed|=0;seed=seed+0x6D2B79F5|0;let t=Math.imul(seed^seed>>>15,1|seed);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296;};}
function key(r){const p=r.p;return [r.room,Math.floor(p.x/30),Math.floor(p.y/30),r.phased?1:0,r.g,r.rope?1:0,p.ammo,Math.floor(r.t/40)%4].join(',');}
function findWin(i,diff,R){ // exploration solver that records its inputs
  const s0=C.newRun(i,diff);s0.started=true;s0.acts=[];
  const arch=new Map([[key(s0),{s:structuredClone(s0),v:0}]]);let keys=[...arch.keys()];
  for(let it=0;it<(C.LEVELS[i].rooms?300000:80000);it++){let k=keys[Math.floor(R()*keys.length)];
    for(let j=0;j<3;j++){const k2=keys[Math.floor(R()*keys.length)];if(arch.get(k2).v<arch.get(k).v)k=k2;}
    const e=arch.get(k);e.v++;const r=structuredClone(e.s);let next=Math.floor(R()*15);
    for(let f=0;f<120;f++){
      if(f>=next&&r.p.ammo>0){const a=R()*6.283,dx=Math.cos(a),dy=Math.sin(a);if(C.fire(r,dx,dy))r.acts.push([r.t,dx,dy]);next=f+4+Math.floor(R()*(r.rope?70:35));}
      const res=C.tick(r);r.events.length=0;if(res==='win')return r.acts;if(res==='dead')break;
      const ck=key(r);if(!arch.has(ck)){arch.set(ck,{s:structuredClone(r),v:0});keys.push(ck);}}}
  return null;}
function randomActs(i,diff,R){const r=C.newRun(i,diff);r.started=true;const acts=[];let next=0;
  for(let f=0;f<600;f++){if(f>=next&&r.p.ammo>0){const a=R()*6.283,dx=Math.cos(a),dy=Math.sin(a);if(C.fire(r,dx,dy))acts.push([r.t,dx,dy]);next=f+5+Math.floor(R()*40);}
    let res=C.tick(r);r.events.length=0;if(res==='dead'&&C.respawn(r))res=null;if(res)break;}return acts;}
function replay(i,diff,acts){ // the exact procedure the Godot test will follow
  const r=C.newRun(i,diff);r.started=true;let ai=0;const trace=[];let res=null;
  for(let f=0;f<6000;f++){while(ai<acts.length&&acts[ai][0]===r.t){C.fire(r,acts[ai][1],acts[ai][2]);ai++;}
    res=C.tick(r);r.events.length=0;if(res==='dead'&&C.respawn(r))res=null;if(r.t%10===0)trace.push([r.t,r.p.x,r.p.y]);if(res)break;}
  return {result:res||'timeout',t:r.t,shots:r.shots,final:[r.p.x,r.p.y,r.p.vx,r.p.vy,r.p.ammo,r.phased?1:0,r.g,r.room],trace};}
const R=rng(12345),cases=[];let wins=0;
// winning runs on Medium and Master for every level; random runs on all four difficulties
for(let i=0;i<C.LEVELS.length;i++)for(const diff of ['easy','medium','hard','master']){
  if(diff==='medium'||diff==='master'){const w=findWin(i,diff,R);if(w){const g=replay(i,diff,w);if(g.result!=='win')throw new Error('replay mismatch '+i+diff+' got '+g.result+' at t='+g.t);wins++;cases.push({level:i,diff,kind:'win',acts:w,...g});}}
  for(let k=0;k<2;k++){const a=randomActs(i,diff,R);cases.push({level:i,diff,kind:'random',acts:a,...replay(i,diff,a)});}}
require('fs').writeFileSync(require('path').join(__dirname,'../../tests/golden_runs.json'),JSON.stringify(cases));
const by={};cases.forEach(c=>by[c.result]=(by[c.result]||0)+1);
console.log('runs that reached screen 2+:',cases.filter(c=>c.final[7]>0).length,' multi-screen wins:',cases.filter(c=>c.kind==='win'&&C.LEVELS[c.level].rooms).length);
console.log('cases',cases.length,'winning solutions',wins,'/'+(C.LEVELS.length*2)+'  outcomes',JSON.stringify(by));
