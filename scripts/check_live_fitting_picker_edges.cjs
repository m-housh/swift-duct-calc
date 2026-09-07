// Requires Playwright with Chromium and a running live app. See docs/fitting-picker-preview.md.
const {chromium}=require('playwright');const assert=require('node:assert/strict');
(async()=>{const b=await chromium.launch({headless:true,args:['--no-sandbox']});const p=await b.newPage();
await p.goto(`${process.env.FITTING_PICKER_URL || 'http://localhost:8081'}/fittings`);
await p.locator('[data-group="8"]').click();await p.locator('[data-fitting-id="8L-round"]').click();
await p.locator('[name=baseFitting]').waitFor();assert.equal(await p.locator('[data-row]').count(),0);
const options=await p.locator('[name=baseFitting] option').evaluateAll(xs=>xs.map(x=>({v:x.value,t:x.textContent})));
const base=options.find(x=>x.v.startsWith('8A'));assert(base);
await p.locator('[name=baseFitting]').selectOption(base.v);await p.locator('[name="base.radiusRatio"]').selectOption('1.0');await p.locator('[data-row]').waitFor();
let row=JSON.parse(await p.locator('[data-row]').getAttribute('data-row'));
assert.equal(row.calculation.derivation.scaled.multiplier,1.7);assert.equal(row.calculation.equivalentLengthFeet,row.calculation.derivation.scaled.base.equivalentLengthFeet*1.7);
await p.locator('[data-row]').click();
await p.locator('#fp-rows button').filter({hasText:'Edit'}).click();await p.locator('[data-row]').waitFor();assert.equal(await p.locator('[name=baseFitting]').inputValue(),base.v);
await p.locator('[data-close-picker]').click();await p.locator('[data-group="12"]').click();await p.locator('[data-fitting-id="12X"]').click();await p.locator('[name=upstreamVelocity]').selectOption('700');await p.locator('[name=areaRatio]').selectOption('4');
await p.locator('[data-row]').waitFor();assert.match(await p.locator('#fp-result').innerText(),/IWC upstream static pressure/);
await p.locator('[data-row]').click();const downloadPromise=p.waitForEvent('download');await p.locator('#fp-download').click();const download=await downloadPromise;
const stream=await download.createReadStream();let text='';for await(const chunk of stream)text+=chunk;const draft=JSON.parse(text);
assert.equal(draft.schemaVersion,1);assert.equal(draft.rows.length,2);assert(draft.rows[1].calculation.minimumUpstreamStaticPressureIWC>0);
// Delay the old evaluation response so editing must invalidate its Add button immediately.
await p.locator('[data-group="11"]').click();await p.locator('[data-fitting-id="11-junction-box"]').click();await p.locator('[data-row]').waitFor();
await p.route('**/fittings/evaluate',async route=>{await new Promise(r=>setTimeout(r,400));await route.continue();});
await p.locator('[name=flexVelocity]').selectOption('800');assert.equal(await p.locator('[data-row]').count(),0);
await p.locator('[name=flexVelocity]').selectOption('900');await p.locator('[data-row]').waitFor();assert.match(await p.locator('#fp-result').innerText(),/95 ft/);
console.log('PASS: matching elbow pair multiplier and edit, upstream pressure condition, JSON snapshots, stale response cancellation.');await b.close();})().catch(e=>{console.error(e);process.exit(1)});
