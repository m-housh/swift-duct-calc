/* Pure review-state helpers, also used by the Node verification. */
(function(root){
  function reconcile(batch,saved){
    const decisions={}; let changed=false;
    for(const item of batch.items){
      const old=saved?.decisions?.[item.id];
      if(old?.revision===item.revision){decisions[item.id]={revision:item.revision,needsWork:old.needsWork===true,note:typeof old.note==='string'?old.note:''};}
      else{decisions[item.id]={revision:item.revision,needsWork:false,note:''};changed=true;}
    }
    if(Object.keys(saved?.decisions||{}).length!==batch.items.length)changed=true;
    return {schemaVersion:1,batchId:batch.id,completedAt:!changed&&typeof saved?.completedAt==='string'?saved.completedAt:null,decisions};
  }
  function report(batch,state){
    return {schemaVersion:1,batchId:batch.id,completedAt:state.completedAt,drawings:batch.items.map(item=>({id:item.id,revision:item.revision,status:state.decisions[item.id].needsWork?'needs-work':state.completedAt||item.priorApproval?'accepted':'pending',note:state.decisions[item.id].note}))};
  }
  const api={reconcile,report};if(typeof module!=='undefined')module.exports=api;else root.ReviewState=api;
})(globalThis);
