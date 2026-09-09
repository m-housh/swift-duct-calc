/* Shared, read-only reference model. This is not the production import/API contract. */
(() => {
  'use strict';
  const groups = [
    [1, 'Supply at equipment', 'Supply air fittings at equipment'],
    [2, 'Supply branch takeoffs', 'Supply trunk branch takeoffs'],
    [3, 'Reducing trunk takeoffs', 'Reducing trunk takeoffs'],
    [4, 'Supply boots & heads', 'Supply boots and stack heads'],
    [5, 'Return at equipment', 'Return fittings at equipment'],
    [6, 'Return branches & boots', 'Return trunk branches and return boots'],
    [7, 'Joist & stud returns', 'Panned joists and stud returns'],
    [8, 'Elbows & offsets', 'Elbows and offsets'],
    [9, 'Supply junctions', 'Supply trunk junctions'],
    [10, 'Return junctions', 'Return trunk junctions'],
    [11, 'Flex junctions & bends', 'Flexible duct junctions and bends'],
    [12, 'Transitions & squeezes', 'Transitions and oval squeezes'],
  ].map(([id, name, title]) => ({id, name, title}));
  const items = window.FITTINGS;
  // Same applicability as the full-catalog path picker. Shared groups occur in both paths.
  const pathGroups = {supply: [1, 2, 3, 4, 8, 9, 11, 12], return: [5, 6, 7, 8, 10, 11, 12]};
  const groupsForSystem = (system = 'all') => groups.filter(g => !pathGroups[system] || pathGroups[system].includes(g.id));
  const group = id => groups.find(g => g.id === Number(id));
  const imageURL = f => (f.image.startsWith('/') ? f.image : '/fittings/' + f.image) + (f.viewport ? '#svgView(viewBox(' + f.viewport.join(',') + '))' : '');
  function table(f) {
    if (f.fixed !== undefined) return {labels: ['Reference'], rows: [{keys: ['At stated conditions'], value: f.fixed}]};
    if (f.rule?.kind === 'ratio') return {labels: [f.rule.parameter], rows: f.rule.rows.map(r => ({keys: [String(r.ratio)], value: r.feet}))};
    if (f.rule?.kind === 'table') return {labels: f.rule.labels, rows: f.rule.rows};
    return {labels: [], rows: []};
  }
  function record(f) {
    return {
      id: f.id, source_fitting_code: f.code, group: f.group, name: f.name,
      variant: f.variant || null, shape: f.shape || null, view: f.view || null,
      artwork_status: f.concept ? 'concept' : 'visually-approved',
      image_url: imageURL(f),
      reference: {units: 'ft', fixed_equivalent_length_ft: f.fixed ?? null, conditions: f.conditions, table: table(f),
        source_values: f.values, ratio_table: f.ratioTable || null, downstream_branches: f.branches || null,
        adjustment: f.adjustment || null, counting_rule: f.countingRule || null,
        notes: f.notes, calculation_status: 'prototype-adapter-not-audited'},
      source: {document: 'ACCA Manual D', printed_page: f.page},
    };
  }
  function filter({group: groupId = 'all', query = '', type = 'all', system = 'all'} = {}) {
    const terms = query.trim().toLowerCase().split(/\s+/).filter(Boolean);
    const eligible = new Set(groupsForSystem(system).map(g => g.id));
    return items.filter(f => eligible.has(f.group) && (groupId === 'all' || f.group === Number(groupId)) &&
      (type === 'all' || (type === 'fixed' ? f.fixed !== undefined : f.fixed === undefined)) &&
      terms.every(t => [f.id, f.code, f.name, f.variant, f.shape, f.view, group(f.group).title, ...f.notes].join(' ').toLowerCase().includes(t)));
  }
  const csvCell = value => '"' + String(value ?? '').replaceAll('"', '""') + '"';
  function csv(fittings) {
    const columns = ['id', 'source_fitting_code', 'group', 'name', 'variant', 'shape', 'artwork_status', 'fixed_equivalent_length_ft', 'conditions_json', 'reference_json', 'source_json', 'image_url'];
    return [columns, ...fittings.map(f => {const r = record(f); return [r.id, r.source_fitting_code, r.group, r.name, r.variant, r.shape, r.artwork_status, r.reference.fixed_equivalent_length_ft, JSON.stringify(r.reference.conditions), JSON.stringify(r.reference), JSON.stringify(r.source), r.image_url];})].map(row => row.map(csvCell).join(',')).join('\r\n') + '\r\n';
  }
  function json(fittings) {
    return JSON.stringify({schema: 'duct-calc.fitting-reference.prototype.v1', status: 'reference-only; not a production API or import contract', fittings: fittings.map(record)}, null, 2);
  }
  window.FittingReference = {groups, groupsForSystem, items, group, imageURL, table, record, filter, csv, json};
})();
