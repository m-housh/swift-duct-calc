const { saveAndReopen } = require('./fitting_browser_helpers.cjs');
// Requires Playwright and a disposable running application; creates a test user and project.
const{chromium}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{const b=await chromium.launch({headless:true,args:['--no-sandbox']});try{
 const context=await b.newContext({viewport:{width:1440,height:1000}}),p=await context.newPage();
 const appURL=process.env.FITTING_APP_URL || 'http://localhost:8081';
 const suffix=Date.now()+'-'+Math.random().toString(36).slice(2),password=require('node:crypto').randomUUID();
 await context.request.post(appURL+'/signup',{form:{email:`fitting-qa-${suffix}@example.test`,password,confirmPassword:password}});
 const projectResponse=await context.request.post(appURL+'/projects',{form:{name:'Fitting UI check '+suffix,streetAddress:'1 Test Street',city:'Test City',state:'OH',zipCode:'45040'}});
 const projectHTML=await projectResponse.text();const match=projectHTML.match(/projects\/([0-9A-Fa-f-]{36})/);assert(match,'Could not create test project');
 const project=match[1],base=`${appURL}/projects/${project}/effective-lengths`;
 fs.writeFileSync('/tmp/fitting-review-project.txt',project);
 await context.storageState({path:'/tmp/fitting-review-auth.json'});fs.chmodSync('/tmp/fitting-review-auth.json',0o600);

 const errors=[];p.on('pageerror',e=>errors.push(e.message));p.on('dialog',d=>d.accept());
 await p.goto(base);await p.getByRole('link',{name:'Add equivalent length',exact:true}).click();await p.locator('#fitting-path').waitFor({state:'visible'});await p.locator('#path-name').fill('Living room supply');await p.locator('#path-straight').fill('10, 25');
 async function group(n){await p.locator('[data-open-picker]').click();const carousel=p.locator('[data-path-carousel="supply"]');await carousel.getByRole('button',{name:new RegExp(`^Show Group ${n}:`)}).click();await carousel.locator('.is-current [data-choose-group]').click();await p.locator('.fitting-grid').waitFor();}
 await group(1);const fixed=p.locator('[data-catalog-id="1A"]');await fixed.locator('.fp-active-art').click();await p.locator('#path-rows [data-row-id]').waitFor();assert.equal(await p.locator('#picker-dialog').evaluate(e=>e.open),false);
 await p.locator('[data-quantity]').fill('2');await p.locator('[data-quantity]').press('Tab');await p.waitForFunction(()=>document.querySelector('.sheet-subtotal').textContent==='70 ft');
 await group(8);const offset=p.locator('[data-catalog-id="8O"]');assert.equal(await offset.locator('[name=insideCornerRadius]').inputValue(),'mitered');
 await offset.locator('[data-favorite]').click();await p.waitForFunction(()=>document.querySelector('.fitting-grid').firstElementChild.dataset.catalogId==='8O');await offset.locator('[data-row]').click();await p.waitForFunction(()=>document.querySelectorAll('#path-rows [data-row-id]').length===2);
 await p.locator('#quick-entry-open').click();await p.locator('#reference-form [name=code]').fill('4AG');await p.locator('#reference-form [name=length]').fill('61.375');await p.locator('#reference-form button[type=submit]').click();await p.locator('#reference-result [data-row]').click();await p.waitForFunction(()=>document.querySelectorAll('#path-rows [data-row-id]').length===3);
 const total=await p.locator('#path-total').innerText();await p.screenshot({path:'/tmp/integrated-filled.png',fullPage:true});
 await saveAndReopen(p);await p.waitForURL(/editor\?id=/);assert.equal(await p.locator('#path-total').innerText(),total);let saved=JSON.parse(await p.locator('#fitting-path').getAttribute('data-baseline'));assert.equal(saved.groups[2].value,61.375);assert.equal(saved.groups[0].quantity,2);assert.equal(saved.groups[1].fitting.origin,'catalog');
 fs.writeFileSync('/tmp/fitting-review-path.txt',p.url());
 await p.locator('#path-name').fill('Living room supply reviewed');await saveAndReopen(p);await p.waitForFunction(()=>JSON.parse(document.querySelector('#fitting-path').dataset.baseline).name==='Living room supply reviewed');assert.equal(await p.locator('#path-total').innerText(),total);
 await group(8);assert.equal(await p.locator('.fitting-grid').first().locator('[data-catalog-id]').first().getAttribute('data-catalog-id'),'8O');await p.locator('[data-close-dialog="picker-dialog"]').click();
 await p.locator('#path-rows [data-edit-row]').nth(1).click();await p.locator('#edit-fitting [data-row]').waitFor();assert.equal(await p.locator('#edit-fitting [name=insideCornerRadius]').inputValue(),'mitered');await p.locator('[data-close-dialog="edit-dialog"]').click();
 await group(11);const flex=p.locator('[data-catalog-id="11-junction-box"]');assert.equal(await flex.locator('[name=bendVelocity]').isVisible(),false);await flex.locator('[name=suppliedBend]').check();await flex.locator('[name=bendVelocity]').selectOption('900');await p.waitForFunction(()=>document.querySelector('[data-catalog-id="11-junction-box"] .fp-result').textContent.includes('80 ft'));await p.screenshot({path:'/tmp/integrated-flex.png'});await flex.locator('[data-row]').click();await p.waitForFunction(()=>document.querySelectorAll('#path-rows [data-row-id]').length===4);
 await saveAndReopen(p);await p.waitForFunction(()=>JSON.parse(document.querySelector('#fitting-path').dataset.baseline).groups.length===4);
 assert.equal(JSON.parse(await p.locator('#fitting-path').getAttribute('data-baseline')).groups[3].value,80);
 await p.setViewportSize({width:390,height:844});assert.equal(await p.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);await p.screenshot({path:'/tmp/integrated-mobile.png',fullPage:true});await p.locator('[data-open-picker]').click();await p.screenshot({path:'/tmp/integrated-mobile-carousel.png'});assert.equal(await p.evaluate(()=>document.querySelector('#picker-dialog').scrollWidth<=document.querySelector('#picker-dialog').clientWidth),true);
 console.log('PASS: real project create/save/reopen/rename, fixed direct add, 8O defaults and edit, per-user favorites, fractional reference, quantities, Group 11 bend, mobile.');assert.deepEqual(errors,[]);
}finally{await b.close()}})().catch(e=>{console.error(e);process.exit(1)});
