const assert = require('node:assert/strict');
const fs = require('node:fs');
const { test } = require('node:test');
const { JSDOM } = require('jsdom');
const script = fs.readFileSync('Public/js/main.js', 'utf8');
const row = (id, name, level) => `<tr data-record="${id}" data-search="${name}" data-level="${level}"><td><button class="row-select">${name}</button></td><td class="number">42</td><td><button class="pencil">Edit</button></td></tr>`;
const fixture = `<div data-project-id="one"><input id="room-search"><select data-room-level><option value="all">All</option><option value="1">Level 1</option></select><table data-selectable-table="rooms"><tbody>${row('a','Kitchen','1')}${row('b','Living room','1')}${row('c','Bedroom','2')}</tbody></table><p data-no-rooms hidden></p><p data-inspector-empty></p><aside data-room-inspector="a"></aside><aside data-room-inspector="b"></aside><aside data-room-inspector="c"></aside></div>`;
function setup(t, html = fixture) {
  const dom = new JSDOM(html, {runScripts:'outside-only', pretendToBeVisual:true});
  t.after(() => dom.window.close());
  dom.window.eval(script);
  const doc = dom.window.document;
  doc.dispatchEvent(new dom.window.Event('DOMContentLoaded'));
  const press = (key, options = {}, target = doc.body) => {
    const event = new dom.window.KeyboardEvent('keydown', {key,ctrlKey:true,altKey:true,bubbles:true,cancelable:true,...options});
    target.dispatchEvent(event); return event;
  };
  return {dom,doc,press,selected:() => doc.querySelector('.selected-row')?.dataset.record};
}
test('request errors announce a dismissible PDF-specific message', async t => {
  const {dom,doc}=setup(t,'<button id="export" hx-ext="htmx-download">PDF</button><div id="app-error" role="alert"></div>');
  doc.dispatchEvent(new dom.window.CustomEvent('htmx:responseError',{detail:{elt:doc.getElementById('export')}}));
  await new Promise(resolve=>dom.window.requestAnimationFrame(resolve));
  assert.match(doc.getElementById('app-error').textContent,/PDF export failed/);
  doc.querySelector('[aria-label="Dismiss error"]').click();
  assert.equal(doc.getElementById('app-error').textContent,'');
});
test('whole row selects without opening its editor; pencil leaves selection alone', t => {
  const {doc,selected} = setup(t);
  assert.equal(selected(),'a');
  doc.querySelector('[data-record="b"] .number').click();
  assert.equal(selected(),'b');
  assert.equal(doc.activeElement.textContent,'Living room');
  assert.equal(doc.querySelector('[data-room-inspector="b"]').hidden,false);
  doc.querySelector('[data-record="c"] .pencil').click();
  assert.equal(selected(),'b');
});
test('Ctrl+Alt+J/K navigate visible rows, stop at boundaries, and Ctrl+K focuses search', t => {
  const {doc,press,selected} = setup(t);
  assert(press('j').defaultPrevented); assert.equal(selected(),'b');
  press('J'); press('j'); assert.equal(selected(),'c');
  press('k'); assert.equal(selected(),'b');
  assert(press('k',{altKey:false}).defaultPrevented);
  assert.equal(doc.activeElement.id,'room-search');
  assert.equal(press('j',{},doc.activeElement).defaultPrevented,false);
  for (const options of [{repeat:true},{isComposing:true},{modifierAltGraph:true},{metaKey:true},{shiftKey:true}]) assert.equal(press('j',options).defaultPrevented,false);
});
test('filtering updates selection and inspector, including no results', t => {
  const {dom,doc,press,selected} = setup(t);
  const search=doc.getElementById('room-search');
  search.value='bed'; search.dispatchEvent(new dom.window.Event('input',{bubbles:true}));
  assert.equal(selected(),'c'); press('j'); assert.equal(selected(),'c');
  search.value='absent'; search.dispatchEvent(new dom.window.Event('input',{bubbles:true}));
  assert.equal(selected(),undefined); assert.equal(doc.querySelector('[data-no-rooms]').hidden,false);
  assert.equal(press('j').defaultPrevented,false);
});
test('selection and filters survive replacement but are isolated by project', t => {
  const {dom,doc,selected} = setup(t);
  doc.querySelector('[data-record="b"] .number').click();
  doc.body.innerHTML=fixture; doc.dispatchEvent(new dom.window.Event('htmx:historyRestore'));
  assert.equal(selected(),'b');
  doc.body.innerHTML=fixture.replace('data-project-id="one"','data-project-id="two"'); doc.dispatchEvent(new dom.window.Event('htmx:historyRestore'));
  assert.equal(selected(),'a');
  dom.window.eval(script); doc.querySelector('[data-record="b"] .number').click(); assert.equal(selected(),'b');
});
test('path network and table selection agree without expanding or changing ranks', t => {
  const html=`<div data-project-id="one"><svg><path data-path-wire="a"></path><path data-path-wire="b"></path></svg><button data-select-path="a"></button><button data-select-path="b"></button><table data-selectable-table="paths"><tbody>${row('a','First','1')}${row('b','Second','1')}${row('c','Outside network','1')}</tbody></table></div>`;
  const {doc,selected}=setup(t,html);
  doc.querySelector('[data-select-path="b"]').click(); assert.equal(selected(),'b');
  assert.equal(doc.querySelector('.selected-wire').dataset.pathWire,'b');
  doc.querySelector('[data-record="c"] .number').click(); assert.equal(selected(),'c');
  assert.equal(doc.querySelectorAll('[data-select-path][aria-pressed="true"]').length,0);
  assert.equal(doc.querySelectorAll('.selected-wire').length,0);
  assert.equal(doc.querySelectorAll('[data-select-path]').length,2);
});
test('network starts open and preserves a collapse across workspace replacement', t => {
  const html = '<div data-project-id="one"><details data-expansion="path-network" open><summary>Path network</summary><div>Network</div></details><details data-expansion="fittings-a"><summary>Fittings</summary></details><table id="all-paths"></table></div>';
  const {dom,doc} = setup(t, html);
  assert.equal(doc.querySelector('[data-expansion="path-network"]').open, true);
  assert.equal(doc.querySelector('[data-expansion="fittings-a"]').open, false);
  const network = doc.querySelector('[data-expansion="path-network"]');
  network.open = false;
  network.dispatchEvent(new dom.window.Event('toggle'));
  doc.body.innerHTML = html;
  doc.dispatchEvent(new dom.window.Event('htmx:historyRestore'));
  assert.equal(doc.querySelector('[data-expansion="path-network"]').open, false);
  assert.equal(doc.querySelector('#all-paths').closest('details'), null);
  doc.body.innerHTML = html.replace('data-project-id="one"', 'data-project-id="two"');
  doc.dispatchEvent(new dom.window.Event('htmx:historyRestore'));
  assert.equal(doc.querySelector('[data-expansion="path-network"]').open, true);
});
test('dialogs pause workspace shortcuts', t => {
  const {doc,press}=setup(t); const dialog=doc.createElement('dialog'); dialog.open=true; doc.body.append(dialog);
  assert.equal(press('j').defaultPrevented,false); assert.equal(press('k',{altKey:false}).defaultPrevented,false);
});
test('Ctrl+K focuses project search after navigation and respects open dialogs', t => {
  const {doc,press} = setup(t, '<input id="project-search" value="Cedar">');
  assert(press('k',{altKey:false}).defaultPrevented);
  assert.equal(doc.activeElement.id,'project-search');
  assert.equal(doc.activeElement.selectionEnd,5);
  doc.body.innerHTML='<input id="project-search" value="Maple"><input id="other">';
  assert(press('k',{altKey:false}).defaultPrevented);
  assert.equal(doc.activeElement.value,'Maple');
  doc.getElementById('other').focus();
  assert.equal(press('k',{altKey:false},doc.activeElement).defaultPrevented,false);
  const dialog=doc.createElement('dialog'); dialog.open=true; doc.body.append(dialog);
  assert.equal(press('k',{altKey:false}).defaultPrevented,false);
});
test('project row cells open the project link without intercepting actions or modified clicks', t => {
  const html='<table><tbody><tr data-project-row><td><a class="project-name" href="/projects/cedar">Cedar</a></td><td class="address">248 Cedar Lane</td><td><button class="delete">Delete</button></td></tr></tbody></table>';
  const {dom,doc}=setup(t,html);
  let navigations=0, deletions=0;
  doc.addEventListener('click',event=>{
    if(event.target.matches('a.project-name')) { event.preventDefault(); navigations++; }
    if(event.target.matches('button.delete')) deletions++;
  });
  doc.querySelector('.address').click(); assert.equal(navigations,1);
  doc.querySelector('.delete').click(); assert.equal(deletions,1); assert.equal(navigations,1);
  doc.querySelector('a.project-name').click(); assert.equal(navigations,2);
  doc.querySelector('.address').dispatchEvent(new dom.window.MouseEvent('click',{bubbles:true,ctrlKey:true}));
  assert.equal(navigations,2);
  doc.body.innerHTML=html;
  doc.querySelector('.address').click(); assert.equal(navigations,3);
});
test('pressure selection highlights its stream and restores after a save', t => {
  const html = `<div data-project-id="one"><svg><path class="loss-stream" data-loss-stream="a"></path><path class="loss-stream" data-loss-stream="b"></path></svg><article class="river-endpoint"><button data-select-loss="a"></button><button class="loss-edit">Edit</button></article><article class="river-endpoint"><button data-select-loss="b"></button><button class="loss-delete">Delete</button></article><table data-selectable-table="loss"><tbody>${row('a','Coil','')}${row('b','Filter','')}</tbody></table><form data-loss-form="a"><input></form></div>`;
  const {dom, doc} = setup(t, html);
  assert.equal(doc.querySelector('.loss-stream.active').dataset.lossStream, 'a');
  doc.querySelector('.loss-delete').click();
  assert.equal(doc.querySelector('.loss-stream.active').dataset.lossStream, 'a');
  doc.querySelector('[data-select-loss="b"]').click();
  assert.equal(doc.querySelectorAll('.loss-stream.active').length, 1);
  assert.equal(doc.querySelector('.loss-stream.active').dataset.lossStream, 'b');
  assert.equal(doc.querySelector('.selected-row').dataset.record, 'b');
  assert.equal(doc.querySelectorAll('[data-selectable-table="loss"] tr[hidden]').length, 0);
  doc.body.innerHTML = html;
  doc.dispatchEvent(new dom.window.Event('htmx:historyRestore'));
  assert.equal(doc.querySelector('.loss-stream.active').dataset.lossStream, 'b');
  assert.equal(doc.querySelector('[data-select-loss][aria-pressed="true"]').dataset.selectLoss, 'b');
  doc.querySelector('[data-loss-form="a"] input').focus();
  assert.equal(doc.querySelector('.selected-row').dataset.record, 'a');
  assert.equal(doc.querySelector('.loss-stream.active').dataset.lossStream, 'a');
});
test('pressure streams fit their cards without changing proportions or shrinking on repeated updates', t => {
  const html = `<div class="pressure-river"><svg class="river-wires"><path data-loss-stream="a" style="stroke-width:64"></path><path data-loss-stream="b" style="stroke-width:16"></path></svg><article class="river-endpoint"><button data-select-loss="a"></button><button class="loss-edit">Edit</button></article><article class="river-endpoint"><button data-select-loss="b"></button><button class="loss-delete">Delete</button></article></div>`;
  const {dom,doc}=setup(t,html);
  const svg=doc.querySelector('svg');
  Object.defineProperty(svg,'clientHeight',{value:980});
  Object.defineProperty(svg,'viewBox',{value:{baseVal:{height:490}}});
  let cardHeight=60;
  doc.querySelectorAll('.river-endpoint').forEach(card=>Object.defineProperty(card,'clientHeight',{get:()=>cardHeight}));
  doc.querySelectorAll('[data-select-loss]').forEach(button=>Object.defineProperty(button,'clientHeight',{value:20}));
  const fit=()=>doc.dispatchEvent(new dom.window.CustomEvent('htmx:afterSettle',{detail:{}}));
  const widths=()=>[...doc.querySelectorAll('path')].map(path=>parseFloat(path.style.strokeWidth));
  fit(); assert.deepEqual(widths(),[52,13]);
  fit(); assert.deepEqual(widths(),[52,13]);
  cardHeight=40; fit(); assert.deepEqual(widths(),[32,8]);
  cardHeight=80; fit(); assert.deepEqual(widths(),[72,18]);
});
test('saving one loss preserves other drafts across body refreshes, including empty input', t => {
  const form=(id,value)=>`<form data-loss-form="${id}" hx-patch="/loss/${id}"><input name="value" type="number" value="${value}"></form>`;
  const html=(a,b)=>`<div class="project-workspace" data-project-id="one">${form('a',a)}${form('b',b)}</div>`;
  const {dom,doc}=setup(t,html('0.03','0.03'));
  const input=id=>doc.querySelector(`[data-loss-form="${id}"] input`);
  const edit=(id,value)=>{input(id).value=value;input(id).dispatchEvent(new dom.window.Event('input',{bubbles:true}));};
  const refresh=(a,b)=>{doc.body.innerHTML=html(a,b);doc.dispatchEvent(new dom.window.CustomEvent('htmx:afterSwap',{detail:{}}));};
  edit('a','0.20');edit('b','0.10');refresh('0.20','0.03');
  assert.equal(input('a').value,'0.20');assert.equal(input('b').value,'0.10');
  refresh('0.20','0.10');refresh('0.20','0.15');
  assert.equal(input('b').value,'0.15','saved drafts do not overwrite later server values');
  edit('b','');refresh('0.20','0.15');assert.equal(input('b').value,'');
  doc.body.innerHTML=html('0.03','0.03').replace('data-project-id="one"','data-project-id="two"');
  doc.dispatchEvent(new dom.window.CustomEvent('htmx:afterSwap',{detail:{}}));
  assert.equal(input('b').value,'0.03','drafts stay within their project');
});
