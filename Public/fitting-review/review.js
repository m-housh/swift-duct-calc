(() => {
  const batch=window.FITTING_REVIEW;
  const storageKey='duct-fitting-review:'+batch.id;
  let saved; let storageOK=true;
  try{saved=JSON.parse(localStorage.getItem(storageKey)||'null');}catch{storageOK=false;}
  const state=ReviewState.reconcile(batch,saved);
  const summary=document.getElementById('summary');
  const finish=document.getElementById('finish');
  const brokenImages=new Set();
  let pendingImages=batch.items.length*2;
  function refresh(){
    const count=Object.values(state.decisions).filter(d=>d.needsWork).length;
    summary.textContent=state.completedAt?`Review finished · ${count} need work · ${batch.items.length-count} accepted`:`${batch.items.length} drawings · ${count} marked for more work · review in progress`;
    finish.textContent=state.completedAt?'Review finished':'Finish review';
    finish.disabled=Boolean(state.completedAt)||brokenImages.size>0||pendingImages>0;
    if(pendingImages)summary.textContent+=' · Loading comparisons…';
    if(brokenImages.size)summary.textContent+=' · Some images could not load; reload before finishing.';
    if(!storageOK)document.getElementById('storage').textContent='Browser saving is unavailable. Download your review before closing this page.';
  }
  function save(){try{localStorage.setItem(storageKey,JSON.stringify(state));}catch{storageOK=false;}refresh();}
  function el(tag,cls,content){const node=document.createElement(tag);if(cls)node.className=cls;if(content)node.textContent=content;return node;}
  document.getElementById('batch-title').textContent=batch.title;
  document.getElementById('batch-description').textContent=batch.description;
  const list=document.getElementById('drawings');
  for(const item of batch.items){
    const decision=state.decisions[item.id];
    const card=el('article',decision.needsWork?'flagged':'');
    const heading=el('div','card-heading');const title=el('h2');title.append(el('span','number',item.id),document.createTextNode(item.name));
    if(item.priorApproval)title.append(el('span','badge','Previously accepted'));
    const label=el('label','check');const checkbox=el('input');checkbox.type='checkbox';checkbox.checked=decision.needsWork;checkbox.id='needs-'+item.id;label.htmlFor=checkbox.id;label.append(checkbox,document.createTextNode('Needs more work'));
    heading.append(title,label);card.append(heading);
    const comparison=el('div','comparison');
    for(const [name,url] of [['Original',item.reference],['SVG',item.image]]){
      const panel=el('section','panel');const top=el('div','panel-title');top.append(el('strong',null,name));
      const link=el('a',null,name==='Original'?`Source p. ${item.sourcePage}`:'Open full size');link.href=name==='Original'?item.sourcePDF:url;link.target='_blank';link.rel='noopener';top.append(link);
      const img=el('img');img.alt=`${item.id} ${name==='Original'?'source reference':'SVG drawing'}`;
      img.addEventListener('load',()=>{pendingImages--;refresh();},{once:true});
      img.addEventListener('error',()=>{pendingImages--;brokenImages.add(item.id+name);panel.append(el('p','image-error','Image unavailable. Reload before finishing the review.'));refresh();},{once:true});
      img.src=url;
      panel.append(top,img);comparison.append(panel);
    }
    card.append(comparison);
    const notes=el('div','notes');notes.hidden=!decision.needsWork;
    const noteLabel=el('label',null,'What needs changing? (optional)');const textarea=el('textarea');textarea.id='note-'+item.id;noteLabel.htmlFor=textarea.id;textarea.value=decision.note;notes.append(noteLabel,textarea);card.append(notes);
    checkbox.addEventListener('change',()=>{decision.needsWork=checkbox.checked;state.completedAt=null;card.classList.toggle('flagged',checkbox.checked);notes.hidden=!checkbox.checked;save();});
    textarea.addEventListener('input',()=>{decision.note=textarea.value;state.completedAt=null;save();});
    list.append(card);
  }
  finish.addEventListener('click',()=>{state.completedAt=new Date().toISOString();save();});
  document.getElementById('export').addEventListener('click',()=>{
    const blob=new Blob([JSON.stringify(ReviewState.report(batch,state),null,2)+'\n'],{type:'application/json'});
    const url=URL.createObjectURL(blob);const a=el('a');a.href=url;a.download=`fitting-review-${batch.id}.json`;document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);
  });
  save();
})();
