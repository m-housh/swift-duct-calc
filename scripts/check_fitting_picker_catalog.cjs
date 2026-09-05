// Run: node scripts/check_fitting_picker_catalog.cjs
// Dependency-free checks of prototype source adapters, not production Swift rules.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'..'),dir=path.join(root,'Public/prototypes/fitting-picker'),ctx={window:{}};
vm.createContext(ctx);for(const name of ['catalog-data.js','catalog-rules.js'])vm.runInContext(fs.readFileSync(path.join(dir,name),'utf8'),ctx);
const data=ctx.window.FITTINGS,calc=ctx.window.CatalogRules.calculate,find=id=>{const f=data.find(f=>f.id===id);assert(f,id);return f;},value=(id,inputs)=>calc(find(id),inputs).value;
assert.equal(data.length,231);assert.equal(new Set(data.map(f=>f.id)).size,data.length);
assert.deepEqual([...new Set(data.map(f=>f.group))],Array.from({length:12},(_,i)=>i+1));
for(const f of data){
 assert(fs.existsSync(f.image.startsWith('/')?path.join(root,'Public',f.image):path.join(dir,f.image)),f.image);
 assert(f.fixed!==undefined||f.rule||f.concept,`Missing rule ${f.id}`);
 if(f.fixed!==undefined)assert.equal(calc(f,{}).value,f.fixed);
 else assert.equal(calc(f,{}).value,null,`Incomplete inputs must not resolve: ${f.id}`);
 if(f.rule?.kind==='table')for(const row of f.rule.rows){const inputs=Object.fromEntries(row.keys.map((k,i)=>['choice'+i,String(k)]));assert.equal(calc(f,inputs).value,row.value,f.id);assert(Number.isFinite(row.value));}
}
assert.equal(find('5A-round').code,'5B');assert.equal(find('5F-round').code,'5G');assert.equal(find('2Q').image,'/images/fittings/group-2-restored/2Q.svg');
assert.equal(value('1F',{numerator:'10',denominator:'20'}),120);
assert.equal(value('1F',{numerator:'12',denominator:'20'}),null);
assert.equal(value('1F',{numerator:'Infinity',denominator:'20'}),null);
assert.equal(value('2A',{choice0:'5+'}),80);
assert.equal(value('6A',{choice0:'1',choice1:'Trunk'}),null);
assert.equal(value('6A',{choice0:'1',choice1:'Branch'}),75);
assert.equal(value('7A',{choice0:'300'}),null);
assert.equal(value('7C-assembly-merging',{choice0:'200'}),70);
assert.equal(value('7C',{choice0:'200'}),30);
assert.equal(value('8A-3-piece',{choice0:'1'}),25);
assert.equal(value('8A-4-or-5-piece',{choice0:'1'}),20);
assert.equal(value('8H',{choice0:'0.5',choice1:'With vanes'}),null);
assert.equal(value('9A',{choice0:'Branch'}),80);assert.equal(value('9A',{choice0:'Main'}),5);
assert.equal(value('12W',{choice0:'900',choice1:'600'}),35);
const squeeze=calc(find('12X'),{choice0:'700',choice1:'4'});assert.equal(squeeze.value,330);assert(squeeze.note.includes('0.71 IWC'));
assert.equal(value('11-junction-box',{velocity:'700'}),null);
assert.equal(value('11-junction-box',{velocity:'700',openings:'top-bottom'}),null);
assert.equal(value('11-junction-box',{velocity:'700',openings:'sidewall'}),60);
const validBox={velocity:'700',openings:'sidewall'};
assert.equal(value('11-junction-box',{...validBox,withBend:'yes'}),null);
assert.equal(value('11-junction-box',{...validBox,withBend:'yes',bendVelocity:'700',radius:'1.0'}),75);
assert.equal(value('11-junction-box',{...validBox,withBend:'yes',bendVelocity:'400',radius:'1.0'}),65);
assert.equal(value('11-junction-box',{...validBox,withBend:'',bendVelocity:'750',radius:'1.2'}),60);
assert.equal(value('11-junction-box',{...validBox,withBend:'yes',bendVelocity:'750',radius:'1.0'}),null);
assert.equal(value('11-junction-box',{...validBox,withBend:'yes',bendVelocity:'700',radius:'1.2'}),null);
assert(!data.some(f=>f.id==='11-radius-bend'));
console.log('PASS: 231 choices, source identities/assets, all table rows, ratios, blank cells, compound rules, Group 11 conditions and fractional lengths.');
