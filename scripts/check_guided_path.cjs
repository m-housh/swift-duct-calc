const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '..');
const context = vm.createContext({window:{}});
for (const file of ['catalog-data.js', 'catalog-rules.js', 'guided-path-model.js']) {
  vm.runInContext(fs.readFileSync(path.join(root, 'Public/prototypes/fitting-picker', file), 'utf8'), context);
}
const M = context.window.GuidedPath;
for (const [type, template] of Object.entries(M.templates)) {
  for (const step of template.steps) {
    const ids = step.buckets?.flatMap(bucket => bucket.ids) || step.options.map(option => option.id);
    for (const id of ids) {
      const fitting = M.find(id);
      assert(fitting, `Missing ${id}`);
      assert.equal(fitting.group, step.group);
      assert(M.allowed[type].includes(fitting.group), `${id} is ineligible for ${type}`);
    }
  }
}
const supply = M.createPath('supply'), returning = M.createPath('return');
const row = (id, quantity=1, inputs={}) => ({id, quantity, inputs});
assert.equal(M.complete(supply), false);
supply.steps[0].rows = [row('1B')]; supply.steps[0].status = 'done';
supply.steps[1].rows = [row('2O')]; supply.steps[1].status = 'done';
assert.equal(M.evaluate(supply.steps[1].rows[0]).value, null);
assert.equal(M.total(supply).unresolved, 1);
supply.steps[1].rows[0].inputs.choice0 = '0';
assert.equal(M.evaluate(supply.steps[1].rows[0]).value, 55, 'Zero is a valid branch count');
supply.steps[2].rows = [row('4G')]; supply.steps[2].status = 'done';
assert.equal(M.stepReady(supply, 3), true, 'Zero elbows are allowed');
supply.steps[3].quantities['8A-4-or-5-piece'] = '2';
supply.steps[3].rows = [row('8A-4-or-5-piece',2)];
assert.equal(M.stepReady(supply, 3), false, 'Nonzero 90° elbow needs R/D');
supply.steps[3].rows[0].inputs.choice0 = '1';
supply.steps[3].quantities['8A-3-piece-45'] = '1';
supply.steps[3].rows.push(row('8A-3-piece-45'));
assert.equal(M.stepReady(supply, 3), true);
assert.equal(M.evaluate(supply.steps[3].rows[1]).value, 10, '45° uses its distinct catalog entry');
for (const invalid of ['', '-1', '1.5', 'NaN', 'Infinity']) {
  supply.steps[3].quantities['8A-3-piece-45'] = invalid;
  assert.equal(M.stepReady(supply, 3), false, `Reject quantity ${invalid}`);
}
supply.steps[3].quantities['8A-3-piece-45'] = '1'; supply.steps[3].status = 'done';
supply.steps[4].rows = [row('12S'),row('12U')]; supply.steps[4].status = 'done';
assert.equal(M.complete(supply), true);
assert.equal(M.total(supply).value, 250);
supply.steps[1].rows = []; supply.steps[1].status = 'skipped';
assert.equal(M.complete(supply), true);
assert.equal(M.total(supply).value, 195, 'Skipped takeoff does not contribute');
supply.steps[0].rows = [];
assert.equal(M.complete(supply), false, 'Removing a required fitting invalidates completion');
assert.equal(M.rows(returning).length, 0, 'Supply changes do not affect return');
assert.equal(M.evaluate(row('5E-round',1,{choice0:'1'})).value,10);
assert.equal(M.find('5E-round').shape,'round');
assert.equal(M.find('5E-rectangular').shape,'rectangular');
assert.equal(M.defaultInputs(supply,3,'8A-4-or-5-piece').choice0,'1');
assert.equal(M.defaultInputs(returning,2,'8A-4-or-5-piece').choice0,'1');
const custom=M.clone(M.templates.supply), original=M.createPath('supply',custom);
custom.name='Custom supply';
custom.steps[1].optional=false;
custom.steps[1].defaults={'2O':{choice0:'2'}};
const trial=M.createPath('supply',custom);
assert.equal(original.template.name,'My usual supply path');
assert.equal(M.defaultInputs(original,1,'2O').choice0,undefined);
assert.equal(M.defaultInputs(trial,1,'2O').choice0,'2');
custom.steps[1].defaults['2O'].choice0='5+';
assert.equal(M.defaultInputs(trial,1,'2O').choice0,'2','An existing path keeps its defaults');
const inputs=M.defaultInputs(trial,1,'2O');inputs.choice0='0';
assert.equal(M.defaultInputs(trial,1,'2O').choice0,'2','Entry inputs do not mutate the template');
trial.steps[1].status='skipped';
assert.equal(M.stepReady(trial,1),false,'A required choice cannot be skipped');
trial.template.steps[1].mode='quantities';
assert.equal(M.stepReady(trial,1),false,'Required quantity steps need at least one fitting');
trial.steps[1].quantities['2O']='1';trial.steps[1].rows=[row('2O',1,{choice0:'2'})];
assert.equal(M.stepReady(trial,1),true);
assert.equal(M.validateTemplate(custom),'');
custom.steps[1].buckets.forEach(bucket=>bucket.ids=[]);
assert(M.validateTemplate(custom).includes('Choose at least one fitting'));
custom.name=' ';
assert.equal(M.validateTemplate(custom),'Give this template a name.');
console.log('PASS: identities/eligibility, fitting inputs and arithmetic, 1.0 defaults, template snapshots, trial isolation, required quantity steps and empty-template validation.');
