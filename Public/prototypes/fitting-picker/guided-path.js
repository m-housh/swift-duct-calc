(() => {
  'use strict';
  const M = window.GuidedPath, rules = window.CatalogRules;
  const app = document.getElementById('app'), dialog = document.getElementById('fitting-dialog');
  const paths = {supply:M.createPath('supply'), return:M.createPath('return')};
  const savedTemplates=M.clone(M.templates);
  let type = 'supply', modal = null, lastTrigger = null, trial=null;
  const esc = s => String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const fmt = n => Number(n.toFixed(2)).toString();
  const path = () => trial?.path || paths[type], template = () => path().template;
  const quantityOptions = () => M.optionsFor(config());
  function showEditor() {
    window.TemplateEditor.open({type,saved:savedTemplates,
      onClose:()=>{render();focusHeading();},
      onSave:(savedType,value)=>{savedTemplates[savedType]=M.clone(value);},
      onTry:(trialType,value)=>{trial={previousType:type,path:M.createPath(trialType,value)};type=trialType;render();focusHeading();},
    });
  }
  const current = () => path().steps[path().cursor], config = () => template().steps[path().cursor];
  const titles = ['','Supply equipment connections','Supply trunk branch takeoffs','Reducing trunk takeoffs','Supply boots','Return equipment connections','Return branches and boots','Panned joists and stud returns','Elbows and offsets','Supply trunk junctions','Return trunk junctions','Flexible duct junctions and bends','Transitions'];
  function art(f, cls='') {
    return `<img class="${cls}" loading="lazy" src="${esc(f.image + (f.viewport ? '#svgView(viewBox('+f.viewport.join(',')+'))' : ''))}" alt="${esc(f.code+' · '+f.name+(f.shape?' · '+f.shape:''))}">`;
  }
  function announce(message) { document.getElementById('announcement').textContent = message; }
  function focusHeading() {
    const heading=document.getElementById('page-title');
    heading?.focus({preventScroll:true});
    heading?.scrollIntoView?.({block:'start'});
  }
  function move(index) { path().cursor=index; path().finished=false; render(); focusHeading(); }
  function stateLabel(index) {
    const state=path().steps[index];
    if(state.status==='skipped')return 'Skipped';
    if(state.rows.length)return state.rows.map(r=>`${M.find(r.id).code} × ${r.quantity}`).join(' · ');
    if(state.status==='done')return 'None needed';
    return M.isOptional(template().steps[index])?'Optional':template().steps[index].mode==='quantities'?'Enter quantities':'Choose a fitting';
  }
  function sidebar() {
    return `<aside class="sidebar"><span class="eyebrow">Path template</span><h2>${esc(template().name)}</h2>
      <div class="type-switch" role="group" aria-label="Path type" ${trial?'hidden':''}><button data-action="type" data-type="supply" aria-pressed="${type==='supply'}">Supply</button><button data-action="type" data-type="return" aria-pressed="${type==='return'}">Return</button></div>
      <nav class="steps" aria-label="Path steps">${template().steps.map((s,i)=>`<button class="step-link ${path().steps[i].status!=='pending'&&M.stepReady(path(),i)?'done':''}" data-action="step" data-index="${i}" ${path().cursor===i?'aria-current="step"':''}><span class="step-number">${path().steps[i].status!=='pending'&&M.stepReady(path(),i)?'✓':i+1}</span><span>${esc(s.title)}<small>${esc(stateLabel(i))}</small></span></button>`).join('')}
      <button class="step-link" data-action="review" ${path().cursor===template().steps.length?'aria-current="step"':''}><span class="step-number">≡</span><span>Review path<small>${M.rows(path()).length} fitting entries</small></span></button></nav>
      <details class="template-note"><summary>About this template</summary><p>These are your configured fitting shortlists. Round and rectangular choices are independent at each step.</p><p>For this first draft: Group 6 is required; Group 12 is optional and can include multiple transitions.</p><p>Each path keeps a copy of its template. Edits to the saved template apply to new paths.</p></details>${trial?'':'<div class="flow-template-actions"><button data-action="edit-template">Edit template</button><button class="quiet" data-action="new-path">New path from saved template</button></div>'}</aside>`;
  }
  function card(f, selected=false) {
    return `<button class="fitting-card" data-action="fit" data-id="${esc(f.id)}" aria-pressed="${selected}">${art(f)}<span class="card-caption"><span class="card-code">${esc(f.code)}${selected?'<span class="pill">Selected</span>':''}</span><span class="card-name">${esc(f.name)}</span><small>${f.fixed!==undefined?fmt(f.fixed)+' ft each':'Choose fitting details'}</small></span></button>`;
  }
  function rowMarkup(row, index, stepIndex, extras=false) {
    const f=M.find(row.id), result=M.evaluate(row);
    return `<div class="selected-row">${art(f)}<div class="row-description"><strong>${esc(f.code)} · ${esc(f.name)}</strong><small>${esc(result.note)}</small><small>Quantity ${row.quantity}</small></div><span class="row-value">${result.value===null?'Needs details':fmt(result.value*row.quantity)+' ft'}</span><div class="row-actions"><button data-action="edit-row" data-index="${index}" data-step="${stepIndex}" data-extras="${extras}">Edit</button><button class="quiet" data-action="remove-row" data-index="${index}" data-step="${stepIndex}" data-extras="${extras}" aria-label="Remove ${esc(f.code)}">Remove</button></div></div>`;
  }
  function selectedRows(rows, stepIndex, extras=false) {
    return rows.length?`<div class="selected-rows">${rows.map((row,i)=>rowMarkup(row,i,stepIndex,extras)).join('')}</div>`:'';
  }
  function stepContent() {
    const c=config(), state=current();
    if(c.mode==='quantities')return elbowContent();
    return `${selectedRows(state.rows,path().cursor)}${c.multiple&&state.rows.length?'<p class="muted">Add another fitting below, or finish this section.</p>':''}
      ${(c.buckets||[{label:'Your choices',ids:M.optionsFor(c).map(o=>o.id)}]).filter(bucket=>bucket.ids.length).map(bucket=>`<section class="fitting-section"><div class="section-heading"><h2>${esc(bucket.label)}</h2><small>${bucket.ids.length} choices</small></div><div class="cards">${bucket.ids.map(id=>card(M.find(id),state.rows.some(r=>r.id===id))).join('')}</div></section>`).join('')}
      <button class="quiet" data-action="browse">Browse all Group ${c.group} fittings →</button>`;
  }
  function elbowContent() {
    const state=current();
    return `<p class="muted">Enter a quantity for each. ${M.isOptional(config())?'Leave it at zero if you do not need it.':'Include at least one fitting.'}</p><div class="elbow-grid fitting-section">${quantityOptions().map(option=>{
      const f=M.find(option.id), quantity=state.quantities[f.id]??'0', row=state.rows.find(r=>r.id===f.id), inputs=state.inputs[f.id]??row?.inputs??M.defaultInputs(path(),path().cursor,f.id);
      return `<section class="elbow-card" data-elbow="${f.id}">${art(f)}<div class="elbow-body"><span class="eyebrow">${esc(f.code)} · ${esc(option.label)}</span><h2>${esc(option.description)}</h2><p>${f.rule?'Fitting details appear when quantity is above zero.':'No additional fitting inputs needed.'}</p><label for="qty-${f.id}">Quantity</label><div class="quantity-control"><button data-action="minus" data-id="${f.id}" aria-label="Decrease ${option.label} quantity">−</button><input id="qty-${f.id}" data-elbow-quantity="${f.id}" type="number" min="0" step="1" value="${esc(quantity)}" aria-describedby="error-${f.id}"><button data-action="plus" data-id="${f.id}" aria-label="Increase ${option.label} quantity">+</button></div><div class="elbow-fields" ${Number(quantity)>0?'':'hidden'}>${rules.fields(f,inputs)}</div><div class="error" id="error-${f.id}"></div><output class="elbow-result"></output></div></section>`;
    }).join('')}</div><div class="selected-rows" ${state.rows.some(row=>!quantityOptions().some(o=>o.id===row.id))?'':'hidden'}>${state.rows.map((row,index)=>quantityOptions().some(o=>o.id===row.id)?'':rowMarkup(row,index,path().cursor)).join('')}</div><button class="quiet" data-action="browse">Browse other Group ${config().group} fittings →</button>`;
  }
  function runningTotal() {
    const sum=M.total(path()), count=M.rows(path()).reduce((n,row)=>n+row.quantity,0);
    return `<div class="running-total"><div><small>Fittings added so far</small><strong>${count} fitting${count===1?'':'s'}</strong></div><div><small>${sum.unresolved?'Fitting total incomplete':'Fitting equivalent length so far'}</small><strong>${sum.unresolved?'Needs fitting details':fmt(sum.value)+' ft'}</strong></div></div>`;
  }
  function review() {
    const sum=M.total(path()), validLength=path().straight!==''&&Number.isFinite(Number(path().straight))&&Number(path().straight)>=0;
    return `${path().finished?'<section class="success" role="status"><strong>Your path preview is ready.</strong><p>You can still edit any step. This prototype does not save to a project.</p></section>':''}
      <div class="review-fields"><label>Path name<input id="path-name" type="text" value="${esc(path().name)}" placeholder="e.g. Living room supply" required maxlength="160"></label><label>Total straight duct length (ft)<input id="straight-length" type="number" min="0" step="any" value="${esc(path().straight)}" placeholder="Enter length" required><small>For this path only; not part of the template.</small></label></div>
      ${template().steps.map((c,i)=>`<section class="review-group"><header><h2>${esc(c.title)} <small>· Group ${c.group}</small></h2><button class="quiet" data-action="step" data-index="${i}">${M.stepReady(path(),i)&&path().steps[i].status!=='pending'?'Revisit':'Complete step'}</button></header>${selectedRows(path().steps[i].rows,i)||`<div class="empty-row">${path().steps[i].status==='skipped'?'Skipped':path().steps[i].status==='done'?'None needed':'Not completed yet'}</div>`}</section>`).join('')}
      ${path().extras.length?'<section class="review-group"><h2>Additional fittings</h2>'+selectedRows(path().extras,-1,true)+'</section>':''}
      <button class="quiet" data-action="add-extra">＋ Add another fitting</button>
      <div class="review-total"><div><small>Total path equivalent length</small><strong id="review-total">${M.complete(path())&&validLength?fmt(sum.value+Number(path().straight))+' ft':'Path total incomplete'}</strong></div><small id="review-breakdown">${fmt(sum.value)} ft resolved fittings${validLength?' + '+fmt(Number(path().straight))+' ft straight duct':''}</small></div>
      <p id="review-help" class="muted"></p><div class="step-footer"><button data-action="back">← Back</button><button class="primary" data-action="finish" id="finish-button">Finish preview</button></div>`;
  }
  function stepFooter() {
    const c=config(), state=current(), batch=c.mode==='quantities'||c.multiple;
    const label=batch?'Done with '+c.title.toLowerCase()+' →':'Next section →';
    return `<div class="step-footer"><button data-action="back" ${path().cursor===0?'disabled':''}>← Back</button><div class="actions">${c.mode!=='quantities'&&M.isOptional(c)?`<button data-action="skip">${state.rows.length?'Clear and skip':'Skip →'}</button>`:''}${batch||state.rows.length||state.status==='skipped'?`<button class="primary" id="continue-button" data-action="next">${esc(label)}</button>`:''}</div></div>`;
  }
  function render() {
    const isReview=path().cursor===template().steps.length, c=config();
    app.innerHTML=`<div class="topbar"><div class="brand">Duct Calc<span>Guided path</span></div><div class="actions">${trial?'':'<button data-action="edit-template">Edit template</button>'}<a href="path-catalog.html">Full fitting catalog ↗</a></div></div>${trial?'<div class="trial-banner"><div><strong>Trying '+esc(template().name)+'</strong><small>Temporary walkthrough. Your original path is unchanged.</small></div><button data-action="end-trial">← Back to template editor</button></div>':''}<div class="workspace">${sidebar()}<main class="main"><header class="page-heading"><div><span class="eyebrow">${type} path${!isReview?' · Group '+c.group:''}</span><h1 id="page-title" tabindex="-1">${isReview?'Review your path':c.mode==='quantities'?(c.group===8?'How many elbows?':'How many fittings?'):c.title}</h1><p>${isReview?'Check the fittings, then name this path and enter its straight length.':c.mode==='quantities'?'Enter the quantities, then finish this section.':c.multiple?'Add the fittings you need, then finish this section.':'Choosing a fitting moves to the next section. You can return using the step list.'}</p></div><span class="progress-caption">${isReview?'Review':(path().cursor+1)+' of '+template().steps.length}</span></header>${isReview?review():stepContent()+stepFooter()+runningTotal()}<p class="prototype-note">Workflow prototype · Paths stay in this tab and reset on reload. Uses the existing preview reference tables; not the production calculator.</p></main></div>`;
    if(isReview)refreshReview();else if(c.mode==='quantities')refreshElbows();else refreshNext();
  }
  function refreshNext() {
    const button=document.getElementById('continue-button');
    if(button)button.disabled=!M.stepReady(path(),path().cursor);
  }
  function refreshReview() {
    const sum=M.total(path()), length=Number(path().straight), validLength=path().straight!==''&&Number.isFinite(length)&&length>=0, complete=M.complete(path());
    document.getElementById('review-total').textContent=complete&&validLength?fmt(sum.value+length)+' ft':'Path total incomplete';
    document.getElementById('review-breakdown').textContent=fmt(sum.value)+' ft resolved fittings'+(validLength?' + '+fmt(length)+' ft straight duct':'');
    document.getElementById('finish-button').disabled=!(complete&&validLength&&path().name.trim());
    document.getElementById('review-help').textContent=!complete?'Complete the unfinished steps and fitting details before finishing.':!validLength?'Enter the total straight duct length; zero is allowed.':!path().name.trim()?'Give this path a name.':'All fitting steps are complete.';
  }
  function refreshElbows() {
    const state=current();
    document.querySelectorAll('[data-elbow]').forEach(el=>{
      const id=el.dataset.elbow, value=state.quantities[id]??'0', number=Number(value), valid=value!==''&&Number.isSafeInteger(number)&&number>=0;
      const row=state.rows.find(r=>r.id===id), result=row?M.evaluate(row):null;
      el.querySelector('.elbow-fields').hidden=!(valid&&number>0);
      el.querySelector('.error').textContent=valid?'':'Enter a whole quantity of zero or more.';
      el.querySelector('input[data-elbow-quantity]').setAttribute('aria-invalid',String(!valid));
      el.querySelector('.elbow-result').textContent=!valid?'':number===0?'Not included':result?.value!==null&&result?fmt(result.value)+' ft × '+number+' = '+fmt(result.value*number)+' ft':result?.note||'Choose the fitting details.';
    });
    refreshNext();
    const total=document.querySelector('.running-total');if(total)total.outerHTML=runningTotal();
  }
  function setElbow(id,value) {
    const state=current(), quantity=Number(value);
    state.quantities[id]=value; state.status='pending';
    const existing=state.rows.find(row=>row.id===id), inputs=state.inputs[id]??existing?.inputs??M.defaultInputs(path(),path().cursor,id);
    state.inputs[id]=inputs;
    state.rows=state.rows.filter(row=>row.id!==id);
    if(value!==''&&Number.isSafeInteger(quantity)&&quantity>0)state.rows.push({id,quantity,inputs});
    refreshElbows();
  }
  function openDialog() {
    lastTrigger=document.activeElement;
    if(!dialog.open)dialog.showModal();
    document.body.classList.add('body-lock');
  }
  function closeDialog() { dialog.close(); }
  dialog.addEventListener('close',()=>{document.body.classList.remove('body-lock');modal=null;if(lastTrigger?.isConnected)lastTrigger.focus();else focusHeading();});
  function openFitting(id, {step=path().cursor,index=null,extras=false}={}) {
    const f=M.find(id), source=extras?path().extras:path().steps[step].rows;
    if(index===null&&!extras&&template().steps[step].mode==='quantities') {
      const found=source.findIndex(row=>row.id===id); if(found>=0)index=found;
    }
    const existing=index!==null?source[index]:null;
    const defaultStep=extras?template().steps.findIndex(s=>s.group===f.group):step;
    modal={kind:'fitting',id,step,index,extras,inputs:{...(existing?.inputs??M.defaultInputs(path(),defaultStep,id))},quantity:String(existing?.quantity||1)};
    if(!existing&&M.evaluate({id,inputs:modal.inputs,quantity:1}).value!==null){commitFitting();return;}
    dialog.innerHTML=`<header><div><span class="eyebrow">Group ${f.group} · ${esc(f.code)}</span><h2 id="dialog-title">${esc(f.name)}</h2></div><button data-action="close">Close</button></header><div class="dialog-config">${art(f)}<div class="dialog-fields">${rules.fields(f,modal.inputs)}<label>Quantity<input id="fitting-quantity" type="number" min="1" step="1" value="${modal.quantity}"></label><div class="dialog-result" aria-live="polite"><strong id="fitting-value"></strong><small id="fitting-reason"></small></div><button class="primary" id="use-fitting" data-action="commit-fitting">${existing?'Save fitting':!extras&& !template().steps[step].multiple&&template().steps[step].mode!=='quantities'?'Add and next →':'Add fitting'}</button>${rules.reference(f)}</div></div>`;
    openDialog();refreshFitting();
  }
  function refreshFitting() {
    const result=M.evaluate({id:modal.id,inputs:modal.inputs,quantity:Number(modal.quantity)});
    document.getElementById('fitting-value').textContent=result.value===null?'Needs fitting details':fmt(result.value)+' ft each · '+fmt(result.value*Number(modal.quantity))+' ft total';
    document.getElementById('fitting-reason').textContent=result.note;
    document.getElementById('use-fitting').disabled=result.value===null;
    const bend=dialog.querySelector('.supplied-bend');if(bend)bend.hidden=modal.inputs.withBend!=='yes';
  }
  function commitFitting() {
    const row={id:modal.id,inputs:{...modal.inputs},quantity:Number(modal.quantity)};
    if(M.evaluate(row).value===null)return;
    const advance=!modal.extras&&modal.index===null&&modal.step===path().cursor&&template().steps[modal.step].mode!=='quantities'&&!template().steps[modal.step].multiple;
    const nextIndex=modal.step+1;
    const target=modal.extras?path().extras:path().steps[modal.step].rows;
    if(modal.index!==null)target[modal.index]=row;
    else if(!modal.extras&&['choose','optional'].includes(template().steps[modal.step].mode)&&!template().steps[modal.step].multiple)target.splice(0,target.length,row);
    else target.push(row);
    if(!modal.extras) {
      const state=path().steps[modal.step];state.status='done';state.choosing=true;
      if(template().steps[modal.step].mode==='quantities'&&M.optionsFor(template().steps[modal.step]).some(o=>o.id===row.id))state.quantities[row.id]=String(row.quantity);
      state.inputs[row.id]=M.clone(row.inputs);
    }
    path().finished=false;if(dialog.open)closeDialog();else modal=null;if(advance)move(nextIndex);else render();announce(M.find(row.id).code+' added to the path.');
  }
  function browse(group, extras=false) {
    modal={kind:'browse',group,extras};
    dialog.innerHTML=`<header><h2 id="dialog-title">${extras?'Add a fitting':'Browse Group '+group}</h2><button data-action="close">Close</button></header>${extras?`<label class="catalog-filter">Group<select id="browse-group">${M.allowed[type].map(g=>`<option value="${g}" ${g===group?'selected':''}>${g} · ${titles[g]}</option>`).join('')}</select></label>`:''}<div class="dialog-catalog"><div class="cards">${window.FITTINGS.filter(f=>f.group===group).map(f=>card(f)).join('')}</div></div>`;
    openDialog();
  }
  document.addEventListener('click',event=>{
    const button=event.target.closest('button[data-action]');if(!button)return;
    const action=button.dataset.action;
    if(window.TemplateEditor.visible)return;
    if(action==='edit-template'){showEditor();return;}
    if(action==='new-path'){paths[type]=M.createPath(type,savedTemplates[type]);render();focusHeading();return;}
    if(action==='end-trial'){type=trial.previousType;trial=null;window.TemplateEditor.resume();return;}
    if(action==='type'){type=button.dataset.type;render();return;}
    if(action==='step'){move(Number(button.dataset.index));return;}
    if(action==='review'){move(template().steps.length);return;}
    if(action==='back'){move(Math.max(0,path().cursor-1));return;}
    if(action==='next'){if(M.stepReady(path(),path().cursor)){current().status=current().rows.length?'done':config().mode==='quantities'?'done':'skipped';move(path().cursor+1);}return;}
    if(action==='skip'&&M.isOptional(config())){current().rows=[];current().status='skipped';current().choosing=false;move(path().cursor+1);return;}
    if(action==='fit'){const extras=dialog.open&&modal?.kind==='browse'&&modal.extras;openFitting(button.dataset.id,{extras});return;}
    if(action==='browse'){browse(config().group);return;}
    if(action==='add-extra'){browse(M.allowed[type][0],true);return;}
    if(action==='close'){closeDialog();return;}
    if(action==='commit-fitting'){commitFitting();return;}
    if(action==='edit-row'){openFitting((button.dataset.extras==='true'?path().extras:path().steps[Number(button.dataset.step)].rows)[Number(button.dataset.index)].id,{step:Number(button.dataset.step),index:Number(button.dataset.index),extras:button.dataset.extras==='true'});return;}
    if(action==='remove-row'){
      const extras=button.dataset.extras==='true', step=Number(button.dataset.step), rows=extras?path().extras:path().steps[step].rows;
      const [removed]=rows.splice(Number(button.dataset.index),1);
      if(!extras){const state=path().steps[step];state.status='pending';if(template().steps[step].mode==='quantities')state.quantities[removed.id]='0';}
      path().finished=false;render();announce('Fitting removed.');return;
    }
    if(action==='plus'||action==='minus'){
      const input=document.getElementById('qty-'+button.dataset.id), previous=Number(input.value)||0;
      input.value=String(Math.max(0,previous+(action==='plus'?1:-1)));setElbow(button.dataset.id,input.value);return;
    }
    if(action==='finish'){
      if(!document.getElementById('finish-button').disabled){path().finished=true;render();focusHeading();}return;
    }
  });
  function inputChanged(event) {
    const input=event.target;
    if(input.id==='browse-group'){browse(Number(input.value),true);return;}
    if(input.id==='path-name'||input.id==='straight-length'){
      path()[input.id==='path-name'?'name':'straight']=input.value;path().finished=false;
      document.querySelector('.success')?.remove();refreshReview();return;
    }
    if(input.dataset.elbowQuantity){setElbow(input.dataset.elbowQuantity,input.value);return;}
    if(dialog.open&&modal?.kind==='fitting') {
      if(input.id==='fitting-quantity')modal.quantity=input.value;
      else if(input.dataset.field)modal.inputs[input.dataset.field]=input.type==='checkbox'?(input.checked?'yes':'no'):input.value;
      else return;
      refreshFitting();return;
    }
    if(input.dataset.field&&input.closest('[data-elbow]')) {
      const id=input.closest('[data-elbow]').dataset.elbow, row=current().rows.find(r=>r.id===id);
      if(row){row.inputs[input.dataset.field]=input.value;current().inputs[id]=row.inputs;}
      current().status='pending';refreshElbows();
    }
  }
  document.addEventListener('input',inputChanged);
  document.addEventListener('change',event=>{if(event.target.tagName==='SELECT')inputChanged(event);});
  render();
  if(new URLSearchParams(location.search).get('view')==='templates')showEditor();
})();
