// Loads the prototype's rules (tools/prototype/recoil.html) but swaps in the CURRENT
// levels, difficulties and par from data/levels.json, so the bot always tests the real game data.
const fs = require('fs'), path = require('path'), vm = require('vm');
const html = fs.readFileSync(path.join(__dirname, '../prototype/recoil.html'), 'utf8');
const src = html.split('<script id="core">')[1].split('</script>')[0];
const ctx = { module: { exports: {} }, Math }; vm.createContext(ctx);
vm.runInContext(src, ctx);
const C = ctx.module.exports;
const data = JSON.parse(fs.readFileSync(path.join(__dirname, '../../data/levels.json'), 'utf8'));
C.LEVELS.length = 0; data.levels.forEach(l => C.LEVELS.push(l));
for (const k of Object.keys(C.DIFF)) delete C.DIFF[k]; Object.assign(C.DIFF, data.difficulties);
Object.assign(C.T, data.tuning); Object.assign(C.PAR, data.par);
module.exports = C;
