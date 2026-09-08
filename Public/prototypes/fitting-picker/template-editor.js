/* In-tab template editing. Trial paths receive independent configuration copies. */
(() => {
  'use strict';
  const M=window.GuidedPath, app=document.getElementById('app');
  const esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  let callbacks, drafts={}, saved={}, type='supply', activeKey='branch', visible=false, catalogOpen=false;
  const draft=()=>drafts[type], step=()=>draft().steps.find(s=>s.key===activeKey);
  const editable=s=>s.group===2||s.key==='elbows';
  const ids=s=>M.optionsFor(s).map(o=>o.id);
  const dirty=()=>JSON.stringify(draft())!==JSON.stringify(saved[type]);
  function art(f) {return `<img loading="lazy" src="${esc(f.image+(f.viewport?'#svgView(viewBox('+f.viewport.join(',')+'))':''))}" alt="${esc(f.name)}">`;}
  function behavior(s) {return s.mode==='quantities'?'Enter quantities':M.isOptional(s)?'Optional choice':'Choose a fitting';}
  function render() {
    visible=true;
    const s=step(), error=M.validateTemplate(draft());
    app.innerHTML=`<div class="topbar"><div class="brand">Duct Calc<span>Path templates</span></div><button class="quiet" data-editor-action="close">← Back to path</button></div>
      <main class="template-editor"><header class="editor-heading"><div><span class="eyebrow">Configure your usual workflow</span><h1 tabindex="-1" id="editor-title">Edit path template</h1><p class="muted">Choose what to offer and what to ask on each path.</p></div><div class="actions"><button data-editor-action="try" ${error?'disabled':''}>Try this template →</button><button class="primary" data-editor-action="save" ${error?'disabled':''}>Save template</button></div></header>
      <div class="editor-meta"><label>Template name<input id="template-name" maxlength="100" value="${esc(draft().name)}"></label><div><span class="field-label">Template type</span><div class="type-switch" role="group" aria-label="Template type"><button data-editor-action="type" data-type="supply" aria-pressed="${type==='supply'}">Supply</button><button data-editor-action="type" data-type="return" aria-pressed="${type==='return'}">Return</button></div></div></div>
      <div class="editor-status"><span id="template-status" role="status">${error|| (dirty()?'Unsaved changes':'Saved in this tab')}</span><button class="quiet" data-editor-action="discard" ${dirty()?'':'disabled'}>Discard changes</button></div>
      <div class="editor-layout"><aside class="editor-outline" aria-label="Template steps"><h2>Steps in this template</h2><p class="muted">Group 2 and elbows are editable in this pass.</p><ol>${draft().steps.map((entry,i)=>`<li class="outline-row ${entry.key===activeKey?'active':''}"><span class="step-number">${i+1}</span><div><strong>${esc(entry.title)}</strong><small>Group ${entry.group} · ${behavior(entry)}</small><small>${ids(entry).length} fitting${ids(entry).length===1?'':'s'}</small>${editable(entry)?`<button class="quiet" data-editor-action="step" data-key="${entry.key}" ${entry.key===activeKey?'aria-current="true"':''}>${entry.key===activeKey?'Editing':'Edit step'}</button>`:'<span class="locked-step">Preview only</span>'}</div></li>`).join('')}</ol><p class="prototype-note">Other step editors and adding or reordering steps will follow after this review.</p></aside>
      <section class="editor-panel" aria-labelledby="step-editor-title"><span class="eyebrow">Group ${s.group}</span><h2 id="step-editor-title">${esc(s.title)}</h2><div class="step-settings"><label>Step name<input id="template-step-name" maxlength="100" value="${esc(s.title)}"></label><label>How should this step work?<select id="template-behavior"><option value="choose" ${s.mode!=='quantities'?'selected':''}>Choose a fitting</option><option value="quantities" ${s.mode==='quantities'?'selected':''}>Enter quantities</option></select></label><label class="check-setting"><input id="template-optional" type="checkbox" ${M.isOptional(s)?'checked':''}>Allow skipping this step</label><p id="optional-help" class="muted">${s.mode==='quantities'?(M.isOptional(s)?'All quantities can stay at zero.':'At least one fitting must have a quantity above zero.'):(M.isOptional(s)?'Show the fitting choices with a Skip option.':'Show the choices directly and require a selection.')}</p></div>
      <div class="selection-heading"><h3>Your choices <span class="pill">${ids(s).length}</span></h3><small>${s.mode==='quantities'?'One quantity control per fitting':'Selecting a resolved fitting adds quantity 1'}</small></div>
      <div class="chosen-fittings">${ids(s).length?ids(s).map(id=>chosen(M.find(id),s)).join(''):'<div class="empty-row">Choose at least one fitting below.</div>'}</div>
      <details class="editor-catalog" ${catalogOpen?'open':''}><summary>Add or remove fitting choices</summary><p class="muted">Check the drawings you want to offer in this step.</p><div class="cards">${window.FITTINGS.filter(f=>f.group===s.group).map(f=>`<label class="fitting-card catalog-checkbox">${art(f)}<span class="card-caption"><span class="card-code"><span>${esc(f.code)}</span><input type="checkbox" data-template-choice="${esc(f.id)}" ${ids(s).includes(f.id)?'checked':''} aria-label="Include ${esc(f.name)}"></span><span class="card-name">${esc(f.name)}</span></span></label>`).join('')}</div></details>
      <div class="editor-rule-note"><strong>Keep routine selections quick.</strong><p>A resolved fitting adds immediately. A single choice also opens the next section. Missing inputs are asked for on the path. Quantity and multiple-fitting sections stay open until the user is done.</p></div></section></div>
      <p class="prototype-note">Prototype · Saved templates and drafts stay in this tab and reset on reload. Saving affects new paths; paths already started keep their own copy.</p></main>`;
    document.querySelector('.editor-catalog').addEventListener('toggle',event=>{if(visible&&event.target.isConnected)catalogOpen=event.target.open;});
  }
  function chosen(f,s) {
    const defaults=s.defaults?.[f.id]||{}, keys=f.rule?.kind==='table'?f.rule.labels:[];
    return `<article class="chosen-fitting">${art(f)}<div class="chosen-content"><div class="selection-heading"><div><strong>${esc(f.code)} · ${esc(f.name)}</strong><small>${s.mode==='quantities'?'Quantity starts at zero':'Adds with quantity 1'}</small></div><button class="quiet" data-editor-action="remove" data-id="${esc(f.id)}" aria-label="Remove ${esc(f.name)} from template">Remove</button></div>${keys.length?`<div class="template-defaults">${keys.map((label,i)=>`<label>${esc(label)}<select data-template-default="${esc(f.id)}" data-key="choice${i}"><option value="">Ask for each path</option>${f.rule.options[i].map(value=>`<option value="${esc(value)}" ${defaults['choice'+i]===value?'selected':''}>Default: ${esc(label==='R/D'&&value==='1'?'1.0':value)}</option>`).join('')}</select></label>`).join('')}</div>`:f.fixed!==undefined?'<p class="muted">No additional inputs needed.</p>':'<p class="muted">Fitting details will be asked for on each path.</p>'}</div></article>`;
  }
  function updateStatus(message) {
    const error=M.validateTemplate(draft());
    document.getElementById('template-status').textContent=error||message||(dirty()?'Unsaved changes':'Saved in this tab');
    for(const action of ['save','try'])document.querySelector(`[data-editor-action="${action}"]`).disabled=!!error;
    document.querySelector('[data-editor-action="discard"]').disabled=!dirty();
  }
  function toggleChoice(id,checked) {
    const s=step();
    if(s.options) {
      s.options=s.options.filter(o=>o.id!==id);
      if(checked){const f=M.find(id), seed=M.elbowOptions.find(o=>o.id===id);s.options.push(seed?M.clone(seed):{id,label:f.code,description:f.name});}
    } else {
      s.buckets.forEach(bucket=>{bucket.ids=bucket.ids.filter(value=>value!==id);});
      if(checked){const f=M.find(id), preferred=s.buckets.find(b=>b.label===(f.shape==='round'?'Round':'Rectangular'))||s.buckets[0];preferred.ids.push(id);}
    }
    render();
    document.querySelector(`[data-template-choice="${id}"]`)?.focus({preventScroll:true});
  }
  document.addEventListener('click',event=>{
    const button=event.target.closest('[data-editor-action]');if(!visible||!button)return;
    const action=button.dataset.editorAction;
    if(action==='close'){visible=false;callbacks.onClose();return;}
    if(action==='type'){type=button.dataset.type;activeKey=type==='supply'?'branch':'elbows';catalogOpen=false;render();return;}
    if(action==='step'){activeKey=button.dataset.key;catalogOpen=false;render();document.getElementById('step-editor-title').scrollIntoView?.({block:'nearest'});return;}
    if(action==='remove'){toggleChoice(button.dataset.id,false);return;}
    if(action==='discard'){drafts[type]=M.clone(saved[type]);render();return;}
    if(action==='save'&&!M.validateTemplate(draft())){saved[type]=M.clone(draft());callbacks.onSave(type,M.clone(draft()));updateStatus('Template saved for new paths in this tab.');return;}
    if(action==='try'&&!M.validateTemplate(draft())){visible=false;callbacks.onTry(type,M.clone(draft()));return;}
  });
  document.addEventListener('input',event=>{
    if(!visible)return;
    if(event.target.id==='template-name'){draft().name=event.target.value;updateStatus();}
    if(event.target.id==='template-step-name'){step().title=event.target.value;updateStatus();document.getElementById('step-editor-title').textContent=step().title;}
  });
  document.addEventListener('change',event=>{
    if(!visible)return;
    const input=event.target,s=step();
    if(input.dataset.templateChoice){toggleChoice(input.dataset.templateChoice,input.checked);return;}
    if(input.id==='template-behavior'){s.optional=M.isOptional(s);s.mode=input.value;render();return;}
    if(input.id==='template-optional'){s.optional=input.checked;render();return;}
    if(input.dataset.templateDefault){s.defaults??={};s.defaults[input.dataset.templateDefault]??={};const values=s.defaults[input.dataset.templateDefault];if(input.value)values[input.dataset.key]=input.value;else delete values[input.dataset.key];updateStatus();}
  });
  window.TemplateEditor={
    open(options){callbacks=options;type=options.type;saved=M.clone(options.saved);for(const key of ['supply','return'])drafts[key]??=M.clone(saved[key]);activeKey=type==='supply'?'branch':'elbows';render();},
    resume(){render();},
    get visible(){return visible;},
  };
})();
