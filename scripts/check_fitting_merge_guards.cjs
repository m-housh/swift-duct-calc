// Creates disposable accounts and paths. Run against a development application.
const { chromium } = require('playwright');
const { randomUUID } = require('node:crypto');
const assert = require('node:assert/strict');
(async () => {
 const browser = await chromium.launch({headless:true,args:['--no-sandbox']});
 const base=process.env.FITTING_APP_URL || 'http://127.0.0.1:8081';
 async function account() {
  const context=await browser.newContext(); const password=randomUUID();
  const r=await context.request.post(base+'/signup',{form:{email:`merge-review-${randomUUID()}@example.test`,password,confirmPassword:password}});
  const userID=(await r.text()).match(/name="userID" value="([^"]+)"/)[1];
  await context.request.post(base+'/signup/profile',{form:{userID,firstName:'Merge',lastName:'Review',companyName:'QA',streetAddress:'1 Test Street',city:'Cincinnati',state:'OH',zipCode:'45202',theme:'dracula'}});
  return context;
 }
 try {
  const owner=await account(), other=await account();
  const project=await owner.request.post(base+'/projects',{form:{name:'Disposable merge security review',streetAddress:'1 Test Street',city:'Cincinnati',state:'OH',zipCode:'45202'}});
  const projectID=(await project.text()).match(/projects\/([0-9A-Fa-f-]{36})/)[1];
  const stepID=randomUUID();
  const config={schemaVersion:1,name:'Review template',type:'supply',steps:[{id:stepID,title:'Takeoff',group:1,behavior:'chooseOne',allowsSkipping:false,choices:[{fittingID:'1B'}]}]};
  const created=await owner.request.post(base+'/path-templates',{data:{configuration:config}});
  const createdText=await created.text();
  const templateURL=createdText.match(/data-redirect="([^"]+)"/)?.[1]; assert(templateURL,createdText.slice(0,300));
  const page=await owner.newPage(); await page.goto(base+templateURL);
  const data=JSON.parse(await page.locator('#path-template-data').textContent());
  const endpoint=base+`/projects/${projectID}/effective-lengths`;
  const payload={name:'Review initial',straightLengths:[10],snapshot:{templateID:data.template.id,revision:data.template.revision,configuration:config},rows:[{id:randomUUID(),stepID,fittingID:'1B',inputs:{fixed:{}},quantity:1}]};
  const save=await owner.request.post(endpoint+'/guided',{data:payload}); assert((await save.text()).includes('data-redirect'));
  await page.goto(endpoint); const href=await page.getByRole('link',{name:'Edit',exact:true}).first().getAttribute('href');
  await page.goto(base+href); const saved=JSON.parse(await page.locator('#path-template-data').textContent()).path;
  const first={...payload,id:saved.id,revision:saved.revision,name:'Newer saved edit',straightLengths:[25]};
  const stale={...payload,id:saved.id,revision:saved.revision,name:'Stale tab overwrite',straightLengths:[10]};
  assert((await (await owner.request.post(endpoint+'/guided',{data:first})).text()).includes('data-redirect'));
  const staleResponse=await owner.request.post(endpoint+'/guided',{data:stale});
  assert((await staleResponse.text()).includes('This path changed in another tab'));
  // The browser keeps the stale draft open when the server refuses the save.
  await page.locator('[data-path=name]').fill('Unsaved stale draft');
  await page.locator('[data-action=save-path]').click();
  await page.getByRole('status').filter({hasText:'This path changed in another tab'}).waitFor();
  assert.equal(await page.locator('[data-path=name]').inputValue(),'Unsaved stale draft');
  page.on('dialog', dialog => dialog.accept());
  const leak=await other.request.get(endpoint);
  assert.equal(leak.status(),404);
  assert(!(await leak.text()).includes('Newer saved edit'));
  const guarded=await other.request.get(endpoint+'/guided/edit/'+saved.id);
  assert.equal(guarded.status(),404);
  const unsupported={schemaVersion:1,name:'Unusable required offset',type:'supply',steps:[{id:randomUUID(),title:'Required offset',group:8,behavior:'chooseOne',allowsSkipping:false,choices:[{fittingID:'8O'}]}]};
  const unsupportedResponse=await owner.request.post(base+'/path-templates',{data:{configuration:unsupported}});
  assert((await unsupportedResponse.text()).includes('add a fitting with supported guided inputs'));
  // Try should give the same error without entering a dead-end flow.
  await page.goto(base+'/path-templates/new/supply');
  await page.locator('#new-group').selectOption('8');
  await page.locator('[data-action=add-step]').click();
  await page.locator('[data-choice="8O"]').check();
  await page.locator('[data-action=try]').click();
  await page.getByRole('status').filter({hasText:'add a fitting with supported guided inputs'}).waitFor();
  assert.equal(await page.locator('[data-config=name]').count(),1);
  const removal=await other.request.delete(endpoint+'/'+saved.id);
  const after=await owner.request.get(endpoint);
  assert.equal(removal.status(),404);
  assert((await after.text()).includes('Newer saved edit'));
  const ownDelete=await owner.request.delete(endpoint+'/'+saved.id);
  assert.equal(ownDelete.status(),200);
  assert(!(await (await owner.request.get(endpoint)).text()).includes('Newer saved edit'));
  console.log('PASS: ownership guards, stale guided save with retained browser draft, unusable template rejection, and owner deletion.');
 } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
