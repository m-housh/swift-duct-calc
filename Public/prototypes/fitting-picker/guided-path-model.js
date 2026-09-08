/* Seed configuration for the guided workflow exploration; no project persistence. */
(() => {
  'use strict';
  const buckets = (round, rectangular) => [{label:'Round', ids:round}, {label:'Rectangular', ids:rectangular}];
  const elbowOptions = [
    {id:'8A-4-or-5-piece', label:'90° elbow', description:'Four- or five-piece round elbow'},
    {id:'8A-3-piece-45', label:'45° elbow', description:'Three-piece round elbow'},
  ];
  const elbows = () => ({key:'elbows', group:8, title:'Elbows', mode:'quantities', optional:true, options:elbowOptions,
    defaults:{'8A-4-or-5-piece':{choice0:'1'}}});
  const transitions = () => ({key:'transitions', group:12, title:'Transitions', mode:'optional', multiple:true,
    question:'Do you want to add a transition to the path?', buckets:[{label:'Your usual transitions', ids:['12J','12S','12T','12U']}]});
  const templates = {
    supply: {name:'My usual supply path', steps:[
      {key:'equipment', group:1, title:'Equipment connection', mode:'choose', buckets:buckets(['1A','1B'],['1C','1D','1E'])},
      {key:'branch', group:2, title:'Supply trunk branch takeoff', mode:'optional', question:'Do you want to add a Supply trunk branch takeoff to the path?', buckets:buckets(['2N','2O','2P','2Q'],['2A','2B'])},
      {key:'boot', group:4, title:'Boot', mode:'choose', buckets:[{label:'Your usual boots', ids:['4G','4Q','4R']}]},
      elbows(), transitions(),
    ]},
    return: {name:'My usual return path', steps:[
      {key:'equipment', group:5, title:'Equipment connection', mode:'choose', buckets:buckets(['5A-round','5C-round','5E-round'],['5E-rectangular','5F-rectangular','5H-rectangular','5I-rectangular','5J-rectangular'])},
      {key:'branch', group:6, title:'Return branch / boot', mode:'choose', buckets:buckets(['6I','6J','6K','6L','6M','6N'],['6F','6H'])},
      elbows(), transitions(),
    ]},
  };
  const allowed = {supply:[1,2,3,4,8,9,11,12], return:[5,6,7,8,10,11,12]};
  const find = id => window.FITTINGS.find(f => f.id === id);
  const clone = value => JSON.parse(JSON.stringify(value));
  const createPath = (type, source=templates[type]) => ({type, template:clone(source), name:'', straight:'', cursor:0, finished:false, extras:[],
    steps:source.steps.map(() => ({rows:[], status:'pending', choosing:false, quantities:{}, inputs:{}}))});
  const isOptional = step => step.optional ?? (step.mode==='optional'||step.mode==='quantities');
  const optionsFor = step => step.options || step.buckets.flatMap(bucket=>bucket.ids.map(id=>({id,label:find(id).code,description:find(id).name})));
  const defaultInputs = (path,index,id) => clone(path.template.steps[index]?.defaults?.[id] || {});
  function validateTemplate(template) {
    if(!template.name.trim())return 'Give this template a name.';
    for(const step of template.steps) {
      if(!step.title.trim())return 'Give each step a name.';
      if(!optionsFor(step).length)return 'Choose at least one fitting for '+step.title+'.';
    }
    return '';
  }
  function evaluate(row) {
    const fitting = find(row.id);
    if (!fitting) return {value:null, note:'This fitting is unavailable.'};
    if (!Number.isSafeInteger(row.quantity) || row.quantity < 1) return {value:null, note:'Enter a whole quantity of 1 or more.'};
    return window.CatalogRules.calculate(fitting, row.inputs);
  }
  function rows(path) {
    return [...path.steps.flatMap(step => step.rows), ...path.extras];
  }
  function total(path) {
    let value = 0, unresolved = 0;
    for (const row of rows(path)) {
      const result = evaluate(row);
      if (result.value === null) unresolved++;
      else value += result.value * row.quantity;
    }
    return {value, unresolved};
  }
  function stepReady(path, index) {
    const config = path.template.steps[index], state = path.steps[index];
    if (config.mode === 'quantities') {
      return (isOptional(config)||state.rows.length>0) && optionsFor(config).every(option => {
        const quantity = state.quantities[option.id] ?? '0';
        const number = Number(quantity);
        if (quantity === '' || !Number.isSafeInteger(number) || number < 0) return false;
        return number === 0 || state.rows.some(row => row.id === option.id && row.quantity === number && evaluate(row).value !== null);
      }) && state.rows.every(row => evaluate(row).value !== null);
    }
    if (state.status === 'skipped' && isOptional(config)) return true;
    return state.rows.length > 0 && state.rows.every(row => evaluate(row).value !== null);
  }
  function complete(path) {
    return path.template.steps.every((_, index) => path.steps[index].status !== 'pending' && stepReady(path,index)) && total(path).unresolved === 0;
  }
  window.GuidedPath = {templates, allowed, elbowOptions, find, createPath, evaluate, rows, total, stepReady, complete, clone, isOptional, optionsFor, defaultInputs, validateTemplate};
})();
