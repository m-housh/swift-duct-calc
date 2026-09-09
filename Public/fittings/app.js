(() => {
  'use strict';
  const R = window.FittingReference;
  const root = document.getElementById('fittings-page');
  if (!root) return;
  const $ = s => root.querySelector(s);
  const narrowLayout = window.matchMedia('(max-width: 700px)');
  function placeSystemToggle(toggle = $('.system-toggle')) {
    const header = !narrowLayout.matches && $('.group-sidebar-header');
    if (header) header.append(toggle);
    else $('#filters').prepend(toggle);
  }
  narrowLayout.addEventListener('change', () => { if (root.isConnected) placeSystemToggle(); });
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;'}[c]));
  const canUseData = root.dataset.tools === 'enabled';
  const params = new URLSearchParams(location.search);
  const initial = R.items.find(f => f.id === params.get('fitting'));
  const state = {
    group: params.get('group') === 'all' ? 'all' : R.group(params.get('group')) ? params.get('group') : initial ? String(initial.group) : '1',
    query: params.get('q') || '', type: ['fixed', 'conditional'].includes(params.get('type')) ? params.get('type') : 'all',
    selected: initial?.id || '1A', format: ['json', 'csv', 'path'].includes(params.get('data')) ? params.get('data') : 'json', scope: 'record',
    showData: canUseData && ['json', 'csv', 'path'].includes(params.get('data')),
    system: ['supply', 'return'].includes(params.get('system')) ? params.get('system') : 'all',
  };
  let rows = [];
  let toastTimer;
  let lastRender = {};
  const selected = () => R.items.find(f => f.id === state.selected);
  function url() {
    const p = new URLSearchParams({group: state.group});
    if (state.selected) p.set('fitting', state.selected);
    if (state.query) p.set('q', state.query);
    if (state.type !== 'all') p.set('type', state.type);
    if (state.system !== 'all') p.set('system', state.system);
    if (state.showData) p.set('data', state.format);
    history.replaceState(null, '', '?' + p);
  }
  function loginHref() {
    const next = new URL(location.href);
    next.searchParams.set('data', state.format);
    return '/login?' + new URLSearchParams({next: next.pathname + next.search});
  }
  function toast(message) {
    $('#toast').textContent = message;
    $('#toast').classList.add('visible');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => $('#toast').classList.remove('visible'), 2500);
  }
  async function copy(text) {
    try { await navigator.clipboard.writeText(text); toast('Copied to clipboard'); }
    catch { const d = $('#copy-dialog'); d.querySelector('textarea').value = text; d.showModal(); d.querySelector('textarea').select(); }
  }
  function image(f) {
    const label = esc(f.code + ' — ' + f.name);
    // Frame the existing sheet artwork without relying on browser SVG-fragment support.
    if (f.viewport) return `<svg class="drawing" viewBox="${f.viewport.join(' ')}" role="img" aria-label="${label}"><image href="${esc(f.image)}" width="640" height="520" /></svg>`;
    return `<img class="drawing" src="${esc(R.imageURL(f))}" alt="${label}" loading="lazy" decoding="async">`;
  }
  const typeBadge = f => `<span class="reference-badge ${f.fixed !== undefined ? '' : 'conditional'}">${f.concept ? 'Concept' : f.fixed !== undefined ? 'Fixed reference' : 'Requires conditions'}</span>`;
  const allGroupsLabel = () => state.system === 'all' ? 'All groups' : `All ${state.system} groups`;
  function groupNav() {
    const groups = R.groupsForSystem(state.system);
    return `<aside class="group-sidebar" aria-label="Fitting groups"><div class="group-sidebar-header"></div><div class="panel-caption">${state.system === 'all' ? 'GROUPS' : state.system.toUpperCase() + ' GROUPS'} <span>${groups.length}</span></div>${[{id:'all', name:allGroupsLabel()}, ...groups].map(g => {
      const count = R.filter({group: String(g.id), query: state.query, type: state.type, system: state.system}).length;
      return `<button class="group-item ${state.group === String(g.id) ? 'active' : ''}" data-group="${g.id}" ${state.group === String(g.id) ? 'aria-current="true"' : ''}><span class="group-number">${g.id === 'all' ? '∑' : String(g.id).padStart(2, '0')}</span><span>${esc(g.name)}</span><small>${count || '—'}</small></button>`;
    }).join('')}<div class="sidebar-note">Group 11 uses a concept drawing.</div></aside>`;
  }
  function empty() {
    return `<div class="empty"><span class="empty-symbol">⌕</span><h2>No matching fittings</h2><p>Try a shorter name, another group, or a fitting ID such as 8A.</p><button data-action="reset">Show all fittings</button></div>`;
  }
  function list() {
    return `<aside class="fitting-sidebar" aria-label="Fittings"><div class="panel-caption">FITTINGS <span>${rows.length}</span></div>${rows.length ? rows.map(f => `<button class="fitting-item ${f.id === state.selected ? 'active' : ''}" data-select="${esc(f.id)}" ${f.id === state.selected ? 'aria-current="true"' : ''}>${image(f)}<span><strong>${esc(f.code)}</strong><span>${esc(f.name)}</span><small>${esc(f.variant || f.shape || 'Group ' + f.group)}</small></span><span class="item-arrow" aria-hidden="true">›</span></button>`).join('') : '<p class="sidebar-note">No matching drawings.</p>'}</aside>`;
  }
  const labels = {velocityFpm:'Reference velocity (FPM)', frictionRateIwcPer100Feet:'Friction rate (IWC / 100 ft)'};
  const readable = value => typeof value === 'object' ? JSON.stringify(value) : String(value);
  function conditions(f) {
    const entries = Object.entries(f.conditions || {});
    return entries.length ? `<dl class="conditions">${entries.map(([k,v]) => `<div><dt>${esc(labels[k] || k.replace(/([A-Z])/g, ' $1').replace(/^./, x => x.toUpperCase()))}</dt><dd>${esc(readable(v))}</dd></div>`).join('')}</dl>` : '<p class="muted">No reference conditions are recorded for this fitting.</p>';
  }
  function referenceTable(f) {
    const t = R.table(f);
    if (!t.rows.length) return '<p class="notice">No supported reference table is available. This fitting cannot supply a reference value.</p>';
    return `<div class="source-table-wrap"><table class="source-table"><caption>${f.concept ? 'Junction box only · sidewall openings' : 'Equivalent length at listed conditions'}</caption><thead><tr>${t.labels.map(l => `<th scope="col">${esc(l)}</th>`).join('')}<th scope="col">EL (ft)</th>${t.rows.some(r => r.note) ? '<th scope="col">Note</th>' : ''}</tr></thead><tbody>${t.rows.map(r => `<tr>${r.keys.map(k => `<td>${esc(k)}</td>`).join('')}<td class="numeric">${r.value}</td>${t.rows.some(r => r.note) ? `<td>${esc(r.note || '')}</td>` : ''}</tr>`).join('')}</tbody></table></div>`;
  }
  function notes(f) {
    const n = [...f.notes];
    if (f.countingRule) n.push(f.countingRule);
    if (f.concept) n.push('Concept illustration. The table assumes straight approach and departure, sidewall openings, and the first outlet at L ≥ 2D. An optional supplied bend adds a separate loss; this table shows the box only. The controlling duct for box velocity remains unresolved.');
    if (f.rule?.kind === 'ratio') n.push('Only the listed source ratios are represented. Interpolation has not been established.');
    return n.length ? `<section class="notes"><h3>Application notes</h3><ul>${n.map(s => `<li>${esc(readable(s))}</li>`).join('')}</ul></section>` : '';
  }
  function detail(f) {
    if (!f) return empty();
    return `<article class="detail"><div class="breadcrumb">GROUP ${String(f.group).padStart(2,'0')} <span>/</span> ${esc(R.group(f.group).name)}</div><div class="detail-heading"><div><span class="fitting-code">${esc(f.code)}</span><h2>${esc(f.name)}</h2></div>${typeBadge(f)}</div><div class="artboard">${image(f)}<span class="art-label">${f.concept ? 'CONCEPT ILLUSTRATION' : 'INDIVIDUAL FITTING DRAWING'}</span></div><div class="identity"><div><span class="eyebrow">CATALOG ID</span><code>${esc(f.id)}</code></div><button data-copy-id="${esc(f.id)}" class="text-button">Copy ID</button><button data-action="share" data-id="${esc(f.id)}" class="text-button">Copy link ↗</button></div><div class="detail-columns"><section><h3>Reference values</h3>${referenceTable(f)}</section><section><h3>Conditions</h3>${conditions(f)}</section></div>${notes(f)}<div class="source-line"><span>ACCA Manual D · printed page ${esc(f.page)}</span>${canUseData ? `<button class="text-button" data-record="${esc(f.id)}">View JSON / CSV →</button>` : ''}</div><p class="audit-note">${f.concept ? 'Concept artwork' : 'Visually approved artwork'} · reference transcription, not an audited calculation rule.</p></article>`;
  }
  function combined() {
    return `<div class="explorer combined">${groupNav()}${list()}<section class="combined-panel" aria-label="Fitting reference and data"><div class="combined-toolbar"><div><strong>Fitting details</strong><code>${esc(state.selected)}</code></div>${canUseData ? `<button data-action="toggle-data" aria-expanded="${state.showData}" aria-controls="combined-data" ${rows.length ? '' : 'disabled'}><span aria-hidden="true">{ }</span> ${state.showData ? 'Hide data' : 'Show CSV / JSON'}</button>` : `<a class="sign-in-data" href="${esc(loginHref())}" data-login>Sign in for CSV / JSON</a>`}</div><div class="combined-content ${state.showData && rows.length ? 'with-data' : ''}"><div class="detail-panel">${rows.length ? detail(selected()) : empty()}</div><div id="combined-data" ${state.showData && rows.length ? '' : 'hidden'}>${state.showData && rows.length ? dataPanel() : ''}</div></div></section></div>`;
  }
  function exportText() {
    const fittings = state.scope === 'filtered' ? rows : selected() ? [selected()] : [];
    if (state.format === 'csv') return R.csv(fittings);
    if (state.format === 'path') {
      const f = fittings[0];
      if (!f) return '// Select a fitting to see a path-entry example.';
      const table = R.table(f);
      const needs = f.fixed === undefined;
      return JSON.stringify({schema: 'duct-calc.path-example.prototype.v1', status: 'Illustrative only; no production import or API endpoint exists here', entries: [{sequence: 1, fitting_id: f.id, quantity: 1, conditions: needs ? Object.fromEntries(table.labels.map(l => [l, null])) : {}, reference_equivalent_length_ft: needs ? null : f.fixed, resolution: needs ? 'Select the required source conditions before resolving a value' : 'Fixed at the catalog reference conditions'}]}, null, 2);
    }
    return R.json(fittings);
  }
  function dataPanel() {
    if (!canUseData) return '';
    return `<section class="code-panel"><div class="code-heading"><div class="format-tabs" aria-label="Data format">${[['json','JSON'],['csv','CSV'],['path','Path example']].map(([v,l]) => `<button data-format="${v}" aria-pressed="${state.format === v}">${l}</button>`).join('')}</div><button data-action="copy-data">Copy</button><button data-action="download-data">Download ↓</button></div><div class="code-subhead"><label>Include <select id="scope" ${state.format === 'path' ? 'disabled' : ''}><option value="record" ${state.scope === 'record' ? 'selected' : ''}>Selected fitting</option><option value="filtered" ${state.scope === 'filtered' ? 'selected' : ''}>All ${rows.length} filtered fittings</option></select></label><span>${state.format === 'path' ? 'ILLUSTRATIVE SCHEMA' : 'REFERENCE DATA'}</span></div><pre tabindex="0" aria-label="${state.format.toUpperCase()} reference data"><code>${esc(exportText())}</code></pre><div class="code-note"><strong>${state.format === 'csv' ? 'One row per drawing variant.' : state.format === 'path' ? 'A possible shape for a future path entry.' : 'Stable IDs. Explicit source conditions.'}</strong><p>${state.format === 'csv' ? 'Nested conditions and tables are quoted JSON fields, so conditional values are preserved.' : state.format === 'path' ? 'This example uses the selected fitting. Null values need source conditions; this page does not submit or import paths.' : 'These are prototype reference records. The schema is experimental and no live API is connected.'}</p></div></section>`;
  }
  function render() {
    const systemToggle = $('.system-toggle');
    const scrollAreas = ['.combined-content .detail-panel', '.group-sidebar', '.fitting-sidebar'];
    const scrollPositions = scrollAreas.map(selector => {const el = $(selector); return {selector, top: el?.scrollTop || 0, left: el?.scrollLeft || 0};});
    const groups = R.groupsForSystem(state.system);
    if (state.group !== 'all' && !groups.some(g => String(g.id) === state.group)) state.group = String(groups[0].id);
    rows = R.filter(state);
    if (!rows.some(f => f.id === state.selected)) state.selected = rows[0]?.id || '';
    $('#search').value = state.query;
    const searchLabel = `Search ${state.system === 'all' ? 'all' : state.system} groups by ID, name, or shape`;
    $('#search').placeholder = searchLabel + '…'; $('#search').setAttribute('aria-label', searchLabel);
    root.querySelectorAll('[data-system]').forEach(button => button.setAttribute('aria-pressed', String(button.dataset.system === state.system)));
    $('#group-filter').innerHTML = `<option value="all">${allGroupsLabel()}</option>` + groups.map(g => `<option value="${g.id}">${g.id} · ${esc(g.name)}</option>`).join('');
    $('#group-filter').value = state.group; $('#value-filter').value = state.type;
    $('#result-count').textContent = rows.length + ' fittings';
    $('#workspace').innerHTML = combined();
    placeSystemToggle(systemToggle);
    if (lastRender.selected === state.selected) {
      for (const {selector, top, left} of scrollPositions) {const el = $(selector); if (el) {el.scrollTop = top; el.scrollLeft = left;}}
    }
    lastRender = {selected:state.selected};
    url();
    root.querySelectorAll('[data-login]').forEach(link => link.href = loginHref());
  }
  function download(text, format) {
    const blob = new Blob([text], {type: format === 'csv' ? 'text/csv;charset=utf-8' : 'application/json'});
    const href = URL.createObjectURL(blob); const a = document.createElement('a');
    a.href = href; a.download = `fitting-${state.format === 'path' && format !== 'csv' ? 'path-example' : 'reference'}.${format}`;
    a.click(); setTimeout(() => URL.revokeObjectURL(href), 1000);
  }
  $('#filters').addEventListener('submit', e => e.preventDefault());
  $('#search').addEventListener('input', e => {state.query = e.target.value; if (state.query) state.group = 'all'; render();});
  root.addEventListener('change', e => {
    if (e.target.id === 'group-filter') state.group = e.target.value;
    else if (e.target.id === 'value-filter') state.type = e.target.value;
    else if (e.target.id === 'scope') state.scope = e.target.value;
    else return;
    const id = e.target.id; render(); document.getElementById(id)?.focus();
  });
  root.addEventListener('click', e => {
    const b = e.target.closest('button'); if (!b) return;
    const d = b.dataset;
    if (d.system) { state.system = d.system; render(); b.focus(); }
    else if (d.group) { state.group = d.group; render(); $(`[data-group="${d.group}"]`)?.focus(); }
    else if (d.select) {
      const scroll = $('.fitting-sidebar').scrollTop;
      const groupScroll = $('.group-sidebar')?.scrollTop;
      state.selected = d.select; render(); $('.fitting-sidebar').scrollTop = scroll;
      if ($('.group-sidebar')) $('.group-sidebar').scrollTop = groupScroll || 0;
      $(`[data-select="${CSS.escape(d.select)}"]`)?.focus({preventScroll:true});
    }
    else if (d.copyId) copy(d.copyId);
    else if (d.record && canUseData) {
      state.showData = true; state.scope = 'record'; state.format = 'json'; render(); $('.code-panel pre').focus();
    }
    else if (d.format && canUseData) { state.format = d.format; if (d.format === 'path') state.scope = 'record'; render(); $(`[data-format="${d.format}"]`).focus(); }
    else if (d.action === 'reset') { state.query = ''; state.group = 'all'; state.type = 'all'; state.system = 'all'; render(); $('#search').focus(); }
    else if (d.action === 'close-copy') $('#copy-dialog').close();
    else if (d.action === 'toggle-data' && canUseData) {
      state.showData = !state.showData; render();
      $('[data-action="toggle-data"]').focus();
    }
    else if (d.action === 'share') { const p = new URLSearchParams({fitting:d.id, group:String(R.items.find(f => f.id === d.id).group)}); if (state.showData) p.set('data',state.format); if (state.system !== 'all' && R.groupsForSystem(state.system).some(g => g.id === R.items.find(f => f.id === d.id).group)) p.set('system',state.system); copy(location.origin + location.pathname + '?' + p); }
    else if (d.action === 'copy-data' && canUseData) copy(exportText());
    else if (d.action === 'download-data' && canUseData) download(exportText(), state.format === 'csv' ? 'csv' : 'json');
  });
  document.addEventListener('keydown', e => {
    if (root.isConnected && e.key === '/' && !e.ctrlKey && !e.metaKey && !/INPUT|TEXTAREA|SELECT/.test(e.target.tagName) && !document.querySelector('dialog[open]')) {e.preventDefault(); $('#search').focus();}
  });
  render();
})();
