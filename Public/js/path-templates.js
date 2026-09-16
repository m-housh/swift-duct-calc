/* Template configuration and guided navigation. Swift evaluates and saves fittings. */
(() => {
  'use strict';
  const clone = (value) => JSON.parse(JSON.stringify(value));
  const esc = (value) =>
    String(value ?? '').replace(
      /[&<>"']/g,
      (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]
    );
  const groups = {
    1: 'Equipment connection',
    2: 'Supply trunk branch takeoff',
    3: 'Reducing trunk takeoff',
    4: 'Supply boot',
    5: 'Return equipment connection',
    6: 'Return branch / boot',
    7: 'Return space',
    8: 'Elbows',
    9: 'Supply accessories',
    10: 'Return accessories',
    11: 'Flex junction boxes',
    12: 'Transitions',
  };
  const allowed = { supply: [1, 2, 3, 4, 8, 9, 11, 12], return: [5, 6, 7, 8, 10, 11, 12] };
  const kinds = {
    chooseOne: 'Choose one fitting',
    chooseMultiple: 'Choose multiple fittings',
    quantities: 'Enter quantities',
  };
  const fittingDirections = {
    fittingLeft: 'ArrowLeft', fittingDown: 'ArrowDown', fittingUp: 'ArrowUp', fittingRight: 'ArrowRight',
  };
  function fittingNavigationHint() {
    const bindings = window.ductCalcKeybindings?.() ?? {};
    const keys = Object.keys(fittingDirections).map(action => bindings[action]);
    if (keys.some(key => !key)) return 'Arrow keys';
    if (keys.join(' ') === 'Control+Alt+H Control+Alt+J Control+Alt+K Control+Alt+L') return 'Ctrl+Alt+H/J/K/L or arrows';
    return keys.map(key => key.replaceAll('Control', 'Ctrl').replaceAll('Meta', 'Command')).join(' / ') + ' or arrows';
  }
  const uuid = () => {
    if (typeof crypto.randomUUID === 'function') return crypto.randomUUID();
    // HTTP access through a LAN hostname or IP has getRandomValues, but not randomUUID.
    const bytes = crypto.getRandomValues(new Uint8Array(16));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    const hex = Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0')).join('');
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
  };
  const kind = (definition) => Object.keys(definition.requirements)[0];
  const button = (action, label, attributes = '', style = '') =>
    `<button type="button" class="btn ${style}" data-action="${action}" ${attributes}>${label}</button>`;

  function initialize() {
    const root = document.getElementById('path-template-workspace');
    if (!root || root.dataset.initialized) return;
    root.dataset.initialized = 'true';
    const data = JSON.parse(document.getElementById('path-template-data').textContent);
    function navigate(url, saved = false) {
      const event = new CustomEvent(saved ? 'path-template:saved' : 'path-template:navigate', {
        bubbles: true, cancelable: true, detail: { url }
      });
      if (root.dispatchEvent(event)) location.assign(url);
    }
    const definitions = new Map(data.definitions.map((d) => [d.id, d]));
    // Older templates may reference retired artwork-only IDs. Keep them editable.
    for (const step of data.configuration.steps) {
      for (const choice of step.choices) {
        if (!definitions.has(choice.fittingID)) definitions.set(choice.fittingID, {
          id: choice.fittingID, group: step.group, name: `Unavailable fitting (${choice.fittingID})`,
          notes: [], requirements: { unavailable: { _0: 'Choose a current fitting.' } }
        });
      }
    }

    let configuration = clone(data.configuration),
      selected = 0,
      mode = data.mode;
    let path,
      dialogDraft,
      busy = false,
      dirty = false,
      message = '',
      focusNext = false,
      trialWasDirty = false,
      importReady = false,
      quantityUpdates = Promise.resolve(),
      pendingQuantities = 0;

    function emptyInputs(d) {
      switch (kind(d)) {
        case 'fixed':
          return { fixed: {} };
        case 'dimensions':
          return { dimensions: { numeratorInches: null, denominatorInches: null } };
        case 'downstreamBranches':
          return { downstreamBranches: { _0: null } };
        case 'sourceTable':
          return { sourceTable: { choices: d.requirements.sourceTable.axes.map(() => null) } };
        default:
          return null;
      }
    }
    function missing(d, inputs) {
      if (!inputs) return true;
      if (kind(d) === 'dimensions')
        return !(
          inputs.dimensions?.numeratorInches > 0 && inputs.dimensions?.denominatorInches > 0
        );
      if (kind(d) === 'downstreamBranches')
        return (
          !Number.isSafeInteger(inputs.downstreamBranches?._0) || inputs.downstreamBranches._0 < 0
        );
      if (kind(d) === 'sourceTable')
        return inputs.sourceTable?.choices.some((x) => x === null || x === '');
      return kind(d) !== 'fixed';
    }
    function startPath(trial = false) {
      if (trial) trialWasDirty = dirty;
      const config = clone(configuration),
        saved = trial ? null : data.path,
        initial = trial ? null : data.initialValues;
      path = {
        config,
        trial,
        cursor: saved ? config.steps.length : 0,
        visited: saved ? config.steps.length : 0,
        name: saved?.name ?? initial?.name ?? '',
        straight: (saved?.straightLengths ?? initial?.straightLengths ?? []).join(', '),
        rows: [],
        inputs: {},
        quantities: {},
        completed: {},
      };
      if (saved) {
        path.rows = saved.groups.map((row) => ({
          id: row.rowID,
          stepID: row.stepID ?? null,
          fittingID: row.calculation.fittingID,
          inputs: clone(row.calculation.inputs),
          quantity: row.quantity,
          value: row.value,
        }));
        config.steps.forEach((s) => {
          path.completed[s.id] = true;
        });
        for (const row of path.rows) {
          rememberChoice(row);
        }
      }
      mode = 'path';
      message = '';
      render();
      if (busy) focusNext = true;
      else root.querySelector('#section-heading')?.focus();
    }
    function currentStep() {
      return path.config.steps[path.cursor];
    }
    function stepRows(step) {
      return path.rows.filter((r) => r.stepID === step.id);
    }
    // Keep browsed choices in this path's working copy, including when revisiting a saved path.
    function rememberChoice(row) {
      const step = path.config.steps.find((s) => s.id === row.stepID);
      if (!step) return;
      if (!step.choices.some((c) => c.fittingID === row.fittingID))
        step.choices.push({ fittingID: row.fittingID, defaults: null });
      path.inputs[`${step.id}:${row.fittingID}`] = clone(row.inputs);
      path.quantities[`${step.id}:${row.fittingID}`] = String(row.quantity);
    }
    function inputsFor(step, choice) {
      const key = `${step.id}:${choice.fittingID}`;
      if (!(key in path.inputs))
        path.inputs[key] = clone(choice.defaults ?? emptyInputs(definitions.get(choice.fittingID)));
      return path.inputs[key];
    }
    function artwork(d) {
      return d.artworkPath
        ? `<img loading="lazy" class="w-full h-40 object-contain rounded" src="${esc(d.artworkPath)}" alt="${esc(d.name)}">`
        : '<p class="p-8">Drawing unavailable</p>';
    }
    function fittingCard(d, action) {
      const unavailable = kind(d) === 'unavailable';
      const label = `${d.sourceCode || 'Group ' + d.group} · ${d.name}`;
      return `<article class="card bg-base-200 p-3">${button(
        action,
        `${artwork(d)}<span class="block mt-2">${esc(label)}</span>`,
        `data-id="${esc(d.id)}" data-fitting-choice aria-label="Choose ${esc(label)}" ${unavailable ? 'disabled' : ''}`,
        'btn-ghost h-auto min-h-12 w-full flex-col items-stretch whitespace-normal p-2'
      )}${unavailable ? '<p class="text-warning">Guided inputs are not available for this fitting. Use the project picker.</p>' : ''}${source(d)}</article>`;
    }
    function source(d) {
      const links = `<a class="link block" href="/fittings?fitting=${encodeURIComponent(d.id)}" target="_blank" rel="noopener">Fitting reference</a>`;
      return `<details class="text-sm mt-2"><summary class="cursor-pointer">Reference and conditions</summary>${d.notes.map((n) => `<p class="mt-2">${esc(n)}</p>`).join('')}${links}</details>`;
    }
    function fields(d, inputs, scope) {
      const attrs = (key) =>
        `data-field="${key}" data-scope="${scope}" data-fitting="${esc(d.id)}"`;
      const number = (key, label, value, integer = false) =>
        `<label class="form-control block space-y-1"><span>${esc(label)}</span><input class="input w-full" type="number" min="${integer ? 0 : 0.00000001}" step="${integer ? 1 : 'any'}" value="${esc(value)}" ${attrs(key)}></label>`;
      switch (kind(d)) {
        case 'fixed':
          return '<p class="text-sm">No additional fitting inputs.</p>';
        case 'dimensions': {
          const labels = d.requirements.dimensions,
            v = inputs?.dimensions || {};
          return (
            number('numeratorInches', `${labels.numerator} (in)`, v.numeratorInches) +
            number('denominatorInches', `${labels.denominator} (in)`, v.denominatorInches)
          );
        }
        case 'downstreamBranches':
          return (
            number('count', 'Downstream branches', inputs?.downstreamBranches?._0, true) +
            '<p class="text-sm">Count to the end of the trunk or the next reducer. Enter zero when there are none.</p>'
          );
        case 'sourceTable':
          return d.requirements.sourceTable.axes
            .map(
              (axis, i) =>
                `<label class="form-control block space-y-1"><span>${esc(axis.label)}</span><select class="select w-full" ${attrs(String(i))}><option value="">${scope === 'defaults' ? 'Ask for each path' : 'Choose…'}</option>${axis.options.map((v) => `<option value="${esc(v)}" ${inputs?.sourceTable?.choices[i] === v ? 'selected' : ''}>${esc(axis.label === 'R/D' && v === '1' ? '1.0' : v)}</option>`).join('')}</select></label>`
            )
            .join('');
        default:
          return '<p class="text-warning">Guided inputs are not available for this fitting. Use the project picker.</p>';
      }
    }
    function updateInput(inputs, key, value) {
      if (inputs.sourceTable) inputs.sourceTable.choices[Number(key)] = value || null;
      else if (inputs.dimensions) inputs.dimensions[key] = value === '' ? null : Number(value);
      else if (inputs.downstreamBranches)
        inputs.downstreamBranches._0 = value === '' ? null : Number(value);
    }
    function status() {
      return `<p role="status" id="workspace-status" class="${message ? 'alert alert-warning' : ''}">${esc(message.message || message)}</p>`;
    }
    function templateURL(url) {
      const target = new URL(url, location.origin);
      if (data.projectID) target.searchParams.set('project', data.projectID);
      return target.pathname + target.search;
    }
    function portableTemplate() {
      return {
        format: 'duct-calc-path-template',
        version: 1,
        name: configuration.name,
        type: configuration.type,
        steps: configuration.steps.map((step) => ({
          title: step.title,
          group: step.group,
          behavior: step.behavior,
          allowsSkipping: step.allowsSkipping,
          choices: step.choices.map((choice) => ({
            fittingID: choice.fittingID,
            defaults: choice.defaults ?? null,
          })),
        })),
      };
    }
    function importView() {
      return `<h1 class="text-2xl font-bold">Import path template</h1>${status()}
        <p>Choose a JSON template file to preview. Importing creates your own independent copy.</p>
        <label class="block space-y-2">Template file<input class="file-input w-full" type="file" accept=".json,application/json" id="import-template-file"></label>
        ${
          importReady
            ? `<label class="block">Template name<input class="input w-full" data-config="name" maxlength="100" value="${esc(configuration.name)}"></label>
          <p>${esc(configuration.type)} · ${configuration.steps.length} sections</p>
          <ol class="space-y-4">${configuration.steps
            .map(
              (step, i) => `<li class="card bg-base-200 p-4 space-y-3">
            <h2 class="font-bold">${i + 1}. ${esc(step.title)}</h2>
            <p>${esc(kinds[step.behavior])} · ${step.allowsSkipping ? 'Optional' : 'Required'}</p>
            ${step.choices
              .map((choice) => {
                const d = definitions.get(choice.fittingID);
                return `<div class="border-t border-base-300 pt-2"><h3>${esc(d.sourceCode || d.id)} · ${esc(d.name)}</h3>
                ${kind(d) === 'unavailable' ? '<p class="text-warning">Guided inputs are not available for this fitting. It will remain in the template.</p>' : ''}
                <fieldset disabled class="grid sm:grid-cols-2 gap-3 mt-2">${fields(d, choice.defaults ?? emptyInputs(d), 'defaults')}</fieldset></div>`;
              })
              .join('')}</li>`
            )
            .join('')}</ol>
          <div class="sticky bottom-0 bg-base-100 p-3 flex justify-end">${button('import-template', 'Import as new template', '', 'btn-secondary')}</div>`
            : ''
        }`;
    }
    function editor() {
      const step = configuration.steps[selected];
      return `<h1 class="text-2xl font-bold">Configure template</h1>${status()}
        <div class="flex flex-wrap gap-4"><label class="grow flex flex-col gap-1">Template name<input class="input w-full" data-config="name" maxlength="100" value="${esc(configuration.name)}"></label><label class="flex flex-col gap-1 w-40 max-w-full">Path type<select class="select w-full" data-config="type">${['supply', 'return'].map((t) => `<option ${configuration.type === t ? 'selected' : ''}>${t}</option>`).join('')}</select></label></div>
        <div class="grid lg:grid-cols-[24rem_minmax(0,1fr)] gap-6">
          <aside class="space-y-3"><h2 class="font-bold">Sections</h2>${configuration.steps.map((s, i) => `<div class="grid grid-cols-[minmax(0,1fr)_auto_auto] items-center gap-1 p-2 rounded bg-base-200">${button('select-step', esc(s.title), `data-index="${i}"`, `min-w-0 h-auto min-h-10 whitespace-normal [overflow-wrap:anywhere] ${i === selected ? 'btn-primary' : ''}`)}${button('move-up', '↑', `data-index="${i}" aria-label="Move ${esc(s.title)} up" ${i === 0 ? 'disabled' : ''}`, 'btn-sm')}${button('move-down', '↓', `data-index="${i}" aria-label="Move ${esc(s.title)} down" ${i === configuration.steps.length - 1 ? 'disabled' : ''}`, 'btn-sm')}${!allowed[configuration.type].includes(s.group) ? '<span class="text-error col-span-3">Choose a compatible group or remove this section.</span>' : ''}</div>`).join('')}
          <label>Add fitting group<select id="new-group" class="select w-full">${allowed[configuration.type].map((g) => `<option value="${g}">${g} · ${groups[g]}</option>`).join('')}</select></label>${button('add-step', 'Add section', '', 'w-full')}
          </aside>
          <section class="min-w-0 space-y-4">${
            step
              ? `<div class="flex gap-2"><label class="grow">Section name<input class="input w-full" data-step="title" maxlength="100" value="${esc(step.title)}"></label>${button('remove-step', 'Remove section', '', 'btn-ghost')}</div>
            <div class="space-y-1"><label for="section-behavior">Behavior</label><div class="flex flex-wrap items-center gap-4"><select id="section-behavior" class="select" data-step="behavior">${Object.entries(
              kinds
            )
              .map(
                ([v, l]) =>
                  `<option value="${v}" ${step.behavior === v ? 'selected' : ''}>${l}</option>`
              )
              .join(
                ''
              )}</select><label class="flex items-center gap-2"><input class="checkbox" type="checkbox" data-step="allowsSkipping" ${step.allowsSkipping ? 'checked' : ''}>Allow skipping this section</label></div></div>
            <h2 class="font-bold">Your usual fittings</h2>${step.choices
              .map((choice) => {
                const d = definitions.get(choice.fittingID);
                return `<div class="card bg-base-200 p-4 space-y-3"><h3 class="font-bold">${esc(d.sourceCode || 'Group ' + d.group)} · ${esc(d.name)}</h3><div class="grid sm:grid-cols-2 gap-3">${fields(d, choice.defaults ?? emptyInputs(d), 'defaults')}</div>${button('remove-choice', 'Remove choice', `data-id="${esc(d.id)}"`, 'btn-sm btn-ghost')}</div>`;
              })
              .join('')}
            <h2 class="font-bold">Group ${step.group} choices</h2><div class="grid sm:grid-cols-2 xl:grid-cols-3 gap-3">${data.definitions
              .filter((d) => d.group === step.group)
              .map(
                (d) =>
                  `<label class="card bg-base-100 border border-base-300 p-3 cursor-pointer">${artwork(d)}<span class="flex gap-2 mt-2"><input class="checkbox" type="checkbox" data-choice="${esc(d.id)}" ${step.choices.some((c) => c.fittingID === d.id) ? 'checked' : ''}><span><strong>${esc(d.sourceCode || 'Group ' + d.group)}</strong> ${esc(d.name)}</span></span>${kind(d) === 'unavailable' ? '<span class="text-sm text-warning mt-2">Guided inputs not available</span>' : ''}</label>`
              )
              .join('')}</div>`
              : '<p>Add a section to choose its fittings.</p>'
          }</section>
        </div><div class="sticky bottom-0 bg-base-100 border-t border-base-300 p-3 flex flex-wrap justify-end gap-2">${data.template ? button('delete-template', 'Delete template', '', 'btn-ghost') : ''}${button('export-template', 'Export JSON')}${button('duplicate', 'Save as new template')}${button('try', 'Try template')}${button('save-template', 'Save template', '', 'btn-secondary')}</div>`;
    }
    function rowList(rows) {
      return rows
        .map(
          (row) =>
            `<div class="flex items-center justify-between gap-2 border-b border-base-300 py-2"><span>${esc(definitions.get(row.fittingID)?.name || row.fittingID)} × ${row.quantity} · ${Number((row.value * row.quantity).toFixed(3))} ft</span>${button('edit-row', 'Edit', `data-row="${row.id}"`, 'btn-sm')}${button('remove-row', 'Remove', `data-row="${row.id}"`, 'btn-sm btn-ghost')}</div>`
        )
        .join('');
    }
    function review(total) {
      return `<div class="path-review">
        <fieldset class="path-review-fields">
          <legend>Path details</legend>
          <label for="review-path-name">Path name
            <input id="review-path-name" class="input" name="name" maxlength="200" required data-path="name" value="${esc(path.name)}" placeholder="e.g. Upstairs supply">
          </label>
          <label for="review-path-straight">Straight duct lengths <span class="path-review-muted">(ft)</span>
            <input id="review-path-straight" class="input" name="straight" data-path="straight" value="${esc(path.straight)}" placeholder="10, 25, 15" aria-describedby="review-straight-help">
            <span id="review-straight-help" class="path-review-help">Separate whole-foot lengths with commas. Leave blank if there are none.</span>
          </label>
        </fieldset>
        <section class="path-review-fittings" aria-labelledby="review-fittings-heading">
          <div class="path-review-heading"><h3 id="review-fittings-heading">Fittings</h3>${button('browse', 'Add fitting', '', 'btn-outline btn-sm')}</div>
          ${path.rows.length ? `<table class="path-review-table">
            <caption class="sr-only">Fittings in this path</caption>
            <thead><tr><th scope="col">Fitting</th><th scope="col" class="path-review-number">Quantity</th><th scope="col" class="path-review-number">Equivalent length</th><th scope="col"><span class="sr-only">Actions</span></th></tr></thead>
            <tbody>${path.rows.map(row => {
              const d = definitions.get(row.fittingID);
              const name = d?.name || row.fittingID;
              return `<tr>
                <th scope="row"><span class="path-review-name">${esc(name)}</span><span class="path-review-help">${esc(d?.sourceCode || row.fittingID)} · ${Number(row.value.toFixed(3))} ft each</span></th>
                <td class="path-review-number" data-label="Quantity">${row.quantity}</td>
                <td class="path-review-number" data-label="Equivalent length">${Number((row.value * row.quantity).toFixed(3))} ft</td>
                <td><div class="path-review-actions">${button('remove-row', document.getElementById('path-review-remove-icon').innerHTML, `data-row="${esc(row.id)}" aria-label="Remove ${esc(name)}" title="Remove fitting"`, 'btn-sm btn-ghost text-error')}${button('edit-row', document.getElementById('path-review-edit-icon').innerHTML, `data-row="${esc(row.id)}" aria-label="Edit ${esc(name)}" title="Edit fitting"`, 'btn-sm btn-ghost')}</div></td>
              </tr>`;
            }).join('')}</tbody>
          </table>` : '<p class="path-review-empty">No fittings in this path. Add a fitting or go back to a section to choose one.</p>'}
          <div class="path-review-total"><span>Total fitting equivalent length</span><strong>${Number(total.toFixed(3))} <span>ft</span></strong></div>
        </section>
      </div>`;
    }
    function flow() {
      const step = currentStep(),
        total = path.rows.reduce((sum, r) => sum + r.value * r.quantity, 0);
      return `<h1 class="text-2xl font-bold">${path.trial ? 'Try template' : data.path ? 'Edit path' : 'Build path'} · ${esc(path.config.name)}</h1>${status()}
        <div class="grid lg:grid-cols-[16rem_1fr] gap-6"><nav aria-label="Path sections" class="space-y-2">${path.config.steps.map((s, i) => button('visit', `${i + 1}. ${esc(s.title)}${path.completed[s.id] ? ' ✓' : ''}`, `data-index="${i}" ${i > path.visited ? 'disabled' : ''}`, `w-full ${i === path.cursor ? 'btn-primary' : ''}`)).join('')}${button('visit', 'Review path', `data-index="${path.config.steps.length}" ${path.visited < path.config.steps.length ? 'disabled' : ''}`, 'w-full')}${path.trial ? button('exit-trial', 'Back to template', '', 'w-full') : ''}</nav>
        <form id="path-step-form" class="min-w-0 space-y-4" novalidate aria-labelledby="section-heading"><h2 id="section-heading" tabindex="-1" class="text-xl font-bold">${step ? esc(step.title) : 'Review path'}</h2>
        ${
          step
            ? `${step.allowsSkipping && step.behavior !== 'quantities' ? `<p>Do you want to add ${esc(step.title === 'Supply trunk branch takeoff' ? 'a Supply trunk branch takeoff' : 'a fitting from this section')} to the path?</p>` : ''}${
                step.behavior === 'quantities'
                  ? `<div class="space-y-3">${step.choices
                      .map((choice) => {
                        const d = definitions.get(choice.fittingID),
                          key = `${step.id}:${d.id}`;
                        return `<div class="card bg-base-200 p-4"><h3 class="font-bold">${esc(d.name)}</h3><div class="grid sm:grid-cols-2 gap-3">${artwork(d)}<div class="space-y-3"><label>Quantity<input class="input w-full" type="number" min="0" step="1" data-quantity="${esc(d.id)}" value="${esc(path.quantities[key] ?? '0')}"></label>${button('quantity-details', 'Fitting details', `data-id="${esc(d.id)}"`)}<p class="text-sm">${d.id === '8A-4-or-5-piece' ? `R/D: ${esc(inputsFor(step, choice)?.sourceTable?.choices[0] === '1' ? '1.0' : inputsFor(step, choice)?.sourceTable?.choices[0] || 'Choose')}` : 'Zero omits this fitting.'}</p></div></div>${source(d)}</div>`;
                      })
                      .join('')}</div>`
                  : `<div data-fitting-choices class="grid sm:grid-cols-2 xl:grid-cols-3 gap-3">${step.choices
                      .map((choice) => {
                        const d = definitions.get(choice.fittingID);
                        return fittingCard(d, 'choose');
                      })
                      .join('')}</div>`
              }<div id="step-fitting-rows">${rowList(stepRows(step))}</div>`
            : review(total)
        }
        ${step ? button('browse', 'Browse all fittings') : ''}<div class="path-flow-actions sticky bottom-0 bg-base-100 border-t border-base-300 p-3 flex flex-wrap gap-2 justify-end"><span class="path-flow-key-help">${step && step.behavior !== 'quantities' ? `<kbd>${esc(fittingNavigationHint())}</kbd> fittings · ` : ''}<kbd>Enter</kbd> ${step ? step.behavior === 'quantities' ? 'continue' : 'select / continue' : path.trial ? 'finish trial' : 'save'} · <kbd>Shift + Enter</kbd> back</span>${button('back', 'Back', path.cursor === 0 ? 'disabled' : '')}${step && canSkip(step) ? button('skip', stepRows(step).length ? 'Clear and skip' : 'Skip') : ''}<button type="submit" class="btn btn-secondary" data-action="${step ? 'done' : path.trial ? 'exit-trial' : 'save-path'}">${step ? step.behavior === 'chooseOne' ? 'Continue' : `Done with ${esc(step.title)}` : path.trial ? 'Back to template' : 'Save path'}</button></div></form></div>`;
    }
    function render(focus = false) {
      const fileInput = mode === 'import' ? root.querySelector('#import-template-file') : null;
      root.innerHTML = mode === 'editor' ? editor() : mode === 'import' ? importView() : flow();
      if (mode === 'path') {
        const bindings = window.ductCalcKeybindings?.() ?? {};
        root.querySelector('[data-action="back"]').setAttribute('aria-keyshortcuts',
          ['Shift+Enter', bindings.previousStep].filter(Boolean).join(' '));
        root.querySelector('#path-step-form button[type="submit"]').setAttribute('aria-keyshortcuts',
          ['Enter', bindings.nextStep, bindings.primaryAction].filter(Boolean).join(' '));
      }
      window.ductCalcRequestErrors.appendActions(root.querySelector('#workspace-status'), message.actions);
      if (fileInput) root.querySelector('#import-template-file').replaceWith(fileInput);
      if (focus) focusNext = true;
    }
    function notify(text) {
      message = text;
      const target = root.querySelector('#workspace-status');
      if (target) {
        window.ductCalcRequestErrors.render(target, text);
        target.className = text ? 'alert alert-warning' : '';
      }
    }
    async function request(url, body, method = 'POST', invalidMessage = null) {
      const response = await fetch(url, {
        method,
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json', 'X-DuctCalc-Request': 'true' },
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      });
      await window.ductCalcRequestErrors.check(response, invalidMessage);
      const document = new DOMParser().parseFromString(await response.text(), 'text/html');
      const error = document.querySelector('[data-workspace-error]');
      if (error) throw new Error(error.dataset.workspaceError);
      if (!response.ok && invalidMessage && [400, 404, 413, 422].includes(response.status))
        throw new Error(invalidMessage);
      if (!response.ok || response.redirected)
        throw new Error(
          'Your session or request could not be completed. Keep this page open and try again.'
        );
      return document;
    }
    async function previewImport(file) {
      const result = await request(
        '/path-templates/import-preview',
        file,
        'POST',
        'This is not a supported template file. Check its format, required fields, and 1 MB size limit. Nothing was imported.'
      );
      const preview = result.querySelector('#import-preview-data');
      if (!preview)
        throw new Error(
          'This is not a supported template file. Check its format and required fields. Nothing was imported.'
        );
      return JSON.parse(preview.textContent);
    }
    async function evaluate(row) {
      const saved = data.path?.groups.find((g) => g.rowID === row.id);
      if (
        saved?.calculation?.fittingID === row.fittingID &&
        JSON.stringify(saved.calculation.inputs) === JSON.stringify(row.inputs)
      )
        return saved.value;
      const result = await request('/path-templates/evaluate', {
        type: path.config.type,
        fittingID: row.fittingID,
        inputs: row.inputs,
      });
      const feet = result.querySelector('[data-feet]');
      if (!feet || !Number.isFinite(Number(feet.dataset.feet)))
        throw new Error('The fitting could not be evaluated. Try again.');
      return Number(feet.dataset.feet);
    }
    function advance() {
      path.cursor++;
      path.visited = Math.max(path.visited, path.cursor);
      message = '';
      render(true);
    }
    async function use(row, advanceAfter = false, renderResult = true) {
      const hadDialog = Boolean(root.querySelector('#fitting-details'));
      row.value = await evaluate(row);
      const step = path.config.steps.find((s) => s.id === row.stepID);
      const existingIndex = path.rows.findIndex((r) => r.id === row.id);
      if (step?.behavior === 'chooseOne') {
        path.rows = path.rows.filter((r) => r.stepID !== step.id);
        path.rows.push(row);
      } else if (existingIndex >= 0) path.rows[existingIndex] = row;
      else path.rows.push(row);
      const order = new Map(path.config.steps.map((s, index) => [s.id, index]));
      path.rows.sort(
        (a, b) => (order.get(a.stepID) ?? order.size) - (order.get(b.stepID) ?? order.size)
      );
      rememberChoice(row);
      dirty = true;
      if (advanceAfter) {
        path.completed[step.id] = true;
        advance();
      } else if (renderResult) render(hadDialog);
    }
    function openDetails(row, advanceAfter, quantityOnly = false) {
      const d = definitions.get(row.fittingID);
      dialogDraft = { row: clone(row), advanceAfter, quantityOnly };
      const dialog = document.createElement('dialog');
      dialog.className = 'modal';
      dialog.id = 'fitting-details';
      dialog.innerHTML = `<form id="fitting-details-form" class="modal-box space-y-4" novalidate><h2 class="text-xl font-bold">${esc(d.name)}</h2>${artwork(d)}<div id="detail-error" class="text-error" role="alert"></div><div class="space-y-3">${fields(d, row.inputs, 'details')}</div><label class="block">Quantity<input class="input w-full" type="number" min="${quantityOnly ? 0 : 1}" step="1" data-detail-quantity value="${row.quantity}"></label>${source(d)}<div class="modal-action">${button('cancel-details', 'Cancel')}<button type="submit" class="btn btn-secondary" data-action="apply-details">Apply</button></div></form>`;
      root.append(dialog);
      dialog.showModal();
      dialog.addEventListener(
        'cancel',
        () => {
          dialogDraft = null;
          dialog.remove();
        },
        { once: true }
      );
    }
    function canSkip(step) {
      return step.allowsSkipping || (Boolean(data.path) && !path.trial);
    }
    function sectionReady(step) {
      const rows = stepRows(step);
      if (step.behavior === 'quantities') {
        for (const c of step.choices) {
          const q = path.quantities[`${step.id}:${c.fittingID}`] ?? '0',
            n = Number(q);
          if (
            q === '' ||
            !Number.isSafeInteger(n) ||
            n < 0 ||
            (n > 0 && !rows.some((r) => r.fittingID === c.fittingID && r.quantity === n))
          )
            return false;
        }
      }
      return rows.length > 0 || canSkip(step);
    }
    async function act(action, target) {
      const i = Number(target.dataset.index),
        id = target.dataset.id;
      if (action === 'select-step') {
        selected = i;
        render();
        return;
      }
      if (action === 'add-step') {
        const group = Number(root.querySelector('#new-group').value);
        configuration.steps.push({
          id: uuid(),
          title: groups[group],
          group,
          behavior: 'chooseOne',
          allowsSkipping: false,
          choices: [],
        });
        selected = configuration.steps.length - 1;
        dirty = true;
        render();
        return;
      }
      if (action === 'move-up' || action === 'move-down') {
        const next = i + (action === 'move-up' ? -1 : 1);
        [configuration.steps[i], configuration.steps[next]] = [
          configuration.steps[next],
          configuration.steps[i],
        ];
        selected = next;
        dirty = true;
        render();
        return;
      }
      if (action === 'remove-step') {
        configuration.steps.splice(selected, 1);
        selected = Math.max(0, Math.min(selected, configuration.steps.length - 1));
        dirty = true;
        render();
        return;
      }
      if (action === 'remove-choice') {
        configuration.steps[selected].choices = configuration.steps[selected].choices.filter(
          (c) => c.fittingID !== id
        );
        dirty = true;
        render();
        return;
      }
      if (action === 'export-template') {
        const file = portableTemplate();
        await previewImport(file);
        const url = URL.createObjectURL(
          new Blob([JSON.stringify(file, null, 2) + '\n'], { type: 'application/json' })
        );
        const link = document.createElement('a');
        link.href = url;
        link.download =
          (configuration.name.replace(/[^a-z0-9_-]+/gi, '-').slice(0, 80) || 'path-template') +
          '.json';
        document.body.append(link);
        link.click();
        link.remove();
        setTimeout(() => URL.revokeObjectURL(url), 1000);
        notify('Template exported. The file includes your current configuration.');
        return;
      }
      if (action === 'save-template' || action === 'duplicate' || action === 'import-template') {
        const result = await request(data.saveURL, {
          id: action === 'duplicate' || action === 'import-template' ? null : data.template?.id,
          revision: data.template?.revision,
          configuration,
        });
        const redirect = result.querySelector('[data-redirect]')?.dataset.redirect;
        if (!redirect) throw new Error('Template save did not complete.');
        dirty = false;
        navigate(templateURL(redirect));
        return;
      }
      if (action === 'delete-template') {
        if (!confirm('Delete this template? Existing paths will keep their saved configuration.'))
          return;
        await request(`/path-templates/${data.template.id}`, undefined, 'DELETE');
        dirty = false;
        navigate(data.backURL);
        return;
      }
      if (action === 'try') {
        if (
          !configuration.steps.length ||
          configuration.steps.some(
            (s) => !s.choices.length || !allowed[configuration.type].includes(s.group)
          )
        )
          throw new Error(
            'Add fitting choices to each compatible section before trying this template.'
          );
        await previewImport(portableTemplate());
        startPath(true);
        return;
      }
      if (action === 'exit-trial') {
        mode = 'editor';
        path = null;
        message = '';
        dirty = trialWasDirty;
        render();
        return;
      }
      if (action === 'visit') {
        path.cursor = i;
        message = '';
        render(true);
        return;
      }
      if (action === 'back') {
        path.cursor--;
        message = '';
        render(true);
        return;
      }
      if (action === 'skip') {
        const step = currentStep();
        path.rows = path.rows.filter((r) => r.stepID !== step.id);
        step.choices.forEach((c) => {
          path.quantities[`${step.id}:${c.fittingID}`] = '0';
        });
        path.completed[step.id] = true;
        dirty = true;
        advance();
        return;
      }
      if (action === 'done') {
        const step = currentStep();
        if (!sectionReady(step))
          throw new Error('Complete the fitting inputs and quantities before continuing.');
        path.completed[step.id] = true;
        advance();
        return;
      }
      if (action === 'choose' || action === 'quantity-details' || action === 'extra') {
        const d = definitions.get(id),
          step = currentStep()?.group === d.group ? currentStep() : null,
          choice = step?.choices.find((c) => c.fittingID === id),
          advanceAfter = step?.behavior === 'chooseOne';
        const existing =
          step?.behavior === 'quantities' ? stepRows(step).find((r) => r.fittingID === id) : null;
        const inputs = choice ? inputsFor(step, choice) : emptyInputs(d),
          quantity =
            action === 'quantity-details' ? Number(path.quantities[`${step.id}:${id}`] ?? 0) : existing?.quantity ?? 1;
        const row = {
          id: existing?.id || uuid(),
          stepID: step?.id ?? null,
          fittingID: id,
          inputs: clone(inputs),
          quantity,
        };
        root.querySelector('#browse-fittings')?.remove();
        if (action === 'quantity-details' || missing(d, inputs))
          openDetails(
            row,
            advanceAfter,
            action === 'quantity-details'
          );
        else await use(row, advanceAfter);
        return;
      }
      if (action === 'edit-row') {
        const row = path.rows.find((r) => r.id === target.dataset.row);
        openDetails(
          row,
          false,
          path.config.steps.find((s) => s.id === row.stepID)?.behavior === 'quantities'
        );
        return;
      }
      if (action === 'remove-row') {
        const row = path.rows.find((r) => r.id === target.dataset.row);
        path.rows = path.rows.filter((r) => r.id !== target.dataset.row);
        if (row?.stepID) {
          const step = path.config.steps.find((s) => s.id === row.stepID);
          path.quantities[`${row.stepID}:${row.fittingID}`] = '0';
          path.completed[step.id] = stepRows(step).length > 0 || canSkip(step);
        }
        dirty = true;
        render(true);
        return;
      }
      if (action === 'cancel-details') {
        root.querySelector('#fitting-details').close();
        root.querySelector('#fitting-details').remove();
        dialogDraft = null;
        focusNext = true;
        return;
      }
      if (action === 'apply-details') {
        const draft = dialogDraft,
          row = draft.row,
          d = definitions.get(row.fittingID);
        if (!Number.isSafeInteger(row.quantity) || row.quantity < (draft.quantityOnly ? 0 : 1))
          throw new Error('Enter a whole quantity.');
        if (row.quantity > 0 && missing(d, row.inputs))
          throw new Error('Complete the fitting inputs.');
        if (draft.quantityOnly) {
          path.quantities[`${row.stepID}:${row.fittingID}`] = String(row.quantity);
          path.inputs[`${row.stepID}:${row.fittingID}`] = clone(row.inputs);
        }
        if (row.quantity === 0) {
          path.rows = path.rows.filter(
            (r) => r.stepID !== row.stepID || r.fittingID !== row.fittingID
          );
          dirty = true;
          render(true);
        } else await use(row, draft.advanceAfter);
        dialogDraft = null;
        return;
      }
      if (action === 'browse') {
        const group = currentStep()?.group ?? allowed[path.config.type][0];
        const dialog = document.createElement('dialog');
        dialog.className = 'modal';
        dialog.id = 'browse-fittings';
        dialog.setAttribute('aria-labelledby', 'browse-heading');
        dialog.innerHTML = `<div class="modal-box max-w-4xl space-y-4"><h2 id="browse-heading" class="text-xl font-bold">Add a fitting to this path</h2><p>Choose a fitting for this section, or switch groups to add an extra fitting to the path. Your saved template stays the same.</p><div class="flex flex-col gap-2"><label for="browse-group">Fitting group</label><select class="select w-full appearance-auto bg-none border-base-content/50 cursor-pointer" id="browse-group">${allowed[path.config.type].map((g) => `<option value="${g}" ${g === group ? 'selected' : ''}>${g} · ${groups[g]}</option>`).join('')}</select></div><div id="browse-choices" data-fitting-choices class="grid sm:grid-cols-2 gap-3"></div><div class="modal-action">${button('close-browse', 'Close')}</div></div>`;
        root.append(dialog);
        renderBrowse();
        dialog.showModal();
        dialog.addEventListener('cancel', () => dialog.remove(), { once: true });
        return;
      }
      if (action === 'close-browse') {
        root.querySelector('#browse-fittings').remove();
        return;
      }
      if (action === 'save-path') {
        if (path.config.steps.some((s) => !path.completed[s.id] || !sectionReady(s)))
          throw new Error('Complete every required section before saving.');
        const tokens = path.straight.trim() ? path.straight.split(',').map((x) => x.trim()) : [];
        if (tokens.some((x) => !/^\d+$/.test(x) || Number(x) <= 0))
          throw new Error('Enter positive whole-foot lengths separated by commas.');
        const snapshot = data.path?.templateSnapshot || {
          templateID: data.template.id,
          revision: data.template.revision,
          configuration,
        };
        const result = await request(data.saveURL, {
          id: data.path?.id,
          revision: data.path?.revision,
          name: path.name,
          straightLengths: tokens.map(Number),
          snapshot,
          rows: path.rows,
        });
        const redirect = result.querySelector('[data-redirect]')?.dataset.redirect;
        if (!redirect) throw new Error('Path save did not complete.');
        dirty = false;
        navigate(redirect, true);
      }
    }
    function renderBrowse() {
      const group = Number(root.querySelector('#browse-group').value);
      root.querySelector('#browse-choices').innerHTML = data.definitions
        .filter((d) => d.group === group)
        .map((d) => fittingCard(d, 'extra'))
        .join('');
    }
    function showError(error) {
      const detail = root.querySelector('#detail-error');
      if (detail) window.ductCalcRequestErrors.render(detail, error);
      else notify(error);
    }
    async function updateQuantity(step, id, value) {
      const n = Number(value),
        key = `${step.id}:${id}`;
      path.quantities[key] = value;
      path.completed[step.id] = false;
      const index = path.config.steps.indexOf(step);
      const sectionButton = root.querySelector(`[data-action="visit"][data-index="${index}"]`);
      if (sectionButton) sectionButton.textContent = `${index + 1}. ${step.title}`;
      dirty = true;
      if (value === '' || !Number.isSafeInteger(n) || n < 0)
        throw new Error('Enter a whole quantity of zero or more.');
      const existing = path.rows.find((r) => r.stepID === step.id && r.fittingID === id);
      path.rows = path.rows.filter((r) => r.stepID !== step.id || r.fittingID !== id);
      if (n > 0) {
        const row = {
          id: existing?.id || uuid(),
          stepID: step.id,
          fittingID: id,
          inputs: clone(
            inputsFor(
              step,
              step.choices.find((c) => c.fittingID === id)
            )
          ),
          quantity: n,
        };
        if (missing(definitions.get(id), row.inputs)) openDetails(row, false, true);
        else await use(row, false, false);
      }
      const rows = root.querySelector('#step-fitting-rows');
      if (rows) rows.innerHTML = rowList(stepRows(step));
      const skip = root.querySelector('[data-action="skip"]');
      if (skip) skip.textContent = stepRows(step).length ? 'Clear and skip' : 'Skip';
      notify('');
    }
    async function run(operation) {
      if (busy) return;
      busy = true;
      root.inert = true;
      root.querySelectorAll('dialog').forEach((d) => {
        d.inert = true;
      });
      root.setAttribute('aria-busy', 'true');
      try {
        await quantityUpdates;
        await operation();
      } catch (error) {
        showError(error);
      } finally {
        busy = false;
        root.inert = false;
        root.querySelectorAll('dialog').forEach((d) => {
          d.inert = false;
        });
        if (!pendingQuantities) root.removeAttribute('aria-busy');
        if (focusNext) {
          root.querySelector('#section-heading')?.focus();
          focusNext = false;
        }
      }
    }
    root.addEventListener('submit', (event) => {
      if (!['fitting-details-form', 'path-step-form'].includes(event.target.id)) return;
      event.preventDefault();
      if (event.target.id === 'fitting-details-form') {
        run(() => act('apply-details', event.submitter ?? event.target));
        return;
      }
      if (document.activeElement?.matches('[data-quantity]')) document.activeElement.blur();
      const target = event.target.querySelector('button[type="submit"]');
      run(() => {
        // Committing a quantity may open fitting details that must be completed first.
        if (!root.querySelector('dialog[open]')) return act(target.dataset.action, target);
      });
    });
    root.addEventListener('keydown', (event) => {
      if (mode !== 'path' || busy || event.defaultPrevented || event.isComposing
        || event.getModifierState('AltGraph')) return;
      const action = Object.keys(fittingDirections).find(action => window.ductCalcMatches?.(event, action));
      const directionKey = action ? fittingDirections[action]
        : !event.ctrlKey && !event.altKey && !event.metaKey && !event.shiftKey ? event.key : null;
      if (!Object.values(fittingDirections).includes(directionKey)) return;
      const card = event.target.closest('[data-fitting-choice]');
      const grid = card?.closest('[data-fitting-choices]')
        ?? (event.target.matches('h1, #section-heading') ? root.querySelector('#path-step-form [data-fitting-choices]') : null);
      if (!grid || [...root.querySelectorAll('dialog[open]')].some(dialog => !dialog.contains(grid))) return;
      const cards = [...grid.querySelectorAll('[data-fitting-choice]:not(:disabled)')];
      if (!cards.length) return;
      event.preventDefault();
      let next = cards[0];
      if (card) {
        const index = cards.indexOf(card);
        if (directionKey === 'ArrowLeft' || directionKey === 'ArrowRight') {
          next = cards[Math.max(0, Math.min(cards.length - 1, index + (directionKey === 'ArrowRight' ? 1 : -1)))];
        } else {
          // Use the rendered rows so vertical movement follows every responsive layout.
          const position = card.closest('article').getBoundingClientRect();
          const direction = directionKey === 'ArrowDown' ? 1 : -1;
          const candidates = cards.map(button => ({ button, rect: button.closest('article').getBoundingClientRect() }))
            .filter(({ rect }) => (rect.top - position.top) * direction > 1)
            .sort((a, b) => Math.abs(a.rect.top - position.top) - Math.abs(b.rect.top - position.top)
              || Math.abs(a.rect.left - position.left) - Math.abs(b.rect.left - position.left));
          next = candidates[0]?.button ?? card;
        }
      }
      next.focus({ preventScroll: true });
      next.scrollIntoView({ block: 'nearest', inline: 'nearest' });
    });
    root.addEventListener('keydown', (event) => {
      if (mode !== 'path' || event.defaultPrevented || event.isComposing || event.getModifierState('AltGraph')
        || root.querySelector('dialog[open]')) return;
      const plainEnter = event.key === 'Enter' && !event.ctrlKey && !event.altKey && !event.metaKey;
      const previous = (plainEnter && event.shiftKey) || window.ductCalcMatches?.(event, 'previousStep');
      const next = window.ductCalcMatches?.(event, 'nextStep') || window.ductCalcMatches?.(event, 'primaryAction');
      const interactive = event.target.closest('button, a, input, select, textarea, summary, [contenteditable], [role="button"], [role="combobox"], [role="textbox"]');
      if (!previous && !next && !(plainEnter && !interactive)) return;
      event.preventDefault();
      if (event.repeat || busy) return;
      if (previous) root.querySelector('[data-action="back"]')?.click();
      else root.querySelector('#path-step-form').requestSubmit();
    });
    root.addEventListener('pointerdown', (event) => {
      // A quantity blur can add rows and move the pressed button before pointerup.
      // Keep focus until click, then commit the quantity before running the action.
      if (
        event.button === 0 &&
        document.activeElement?.matches('[data-quantity]') &&
        event.target.closest('[data-action]')
      ) event.preventDefault();
    });
    root.addEventListener('click', (event) => {
      const target = event.target.closest('[data-action]');
      if (target && !target.disabled && target.type !== 'submit') {
        if (document.activeElement?.matches('[data-quantity]')) document.activeElement.blur();
        run(() => act(target.dataset.action, target));
      }
    });
    root.addEventListener('input', (event) => {
      const t = event.target;
      if (t.dataset.config === 'name') {
        configuration.name = t.value;
        dirty = true;
      }
      if (t.dataset.path) {
        path[t.dataset.path] = t.value;
        dirty = true;
      }
      if (t.hasAttribute('data-detail-quantity') && dialogDraft)
        dialogDraft.row.quantity = t.value === '' ? NaN : Number(t.value);
      if (t.dataset.field !== undefined) {
        const d = definitions.get(t.dataset.fitting);
        if (t.dataset.scope === 'defaults') {
          const c = configuration.steps[selected].choices.find((c) => c.fittingID === d.id);
          c.defaults ??= emptyInputs(d);
          updateInput(c.defaults, t.dataset.field, t.value);
          dirty = true;
        } else if (dialogDraft) updateInput(dialogDraft.row.inputs, t.dataset.field, t.value);
      }
    });
    root.addEventListener('change', (event) => {
      const t = event.target;
      if (t.id === 'import-template-file') {
        const file = t.files[0];
        run(async () => {
          importReady = false;
          message = '';
          render();
          if (!file) return;
          if (file.size > 1024 * 1024) throw new Error('Choose a template file smaller than 1 MB.');
          let parsed;
          try {
            parsed = JSON.parse(await file.text());
          } catch {
            throw new Error('This file is not valid JSON. Nothing was imported.');
          }
          configuration = await previewImport(parsed);
          importReady = true;
          render();
        });
        return;
      }
      if (t.dataset.config === 'type') {
        configuration.type = t.value;
        dirty = true;
        render();
      }
      if (t.dataset.step) {
        const step = configuration.steps[selected];
        step[t.dataset.step] = t.type === 'checkbox' ? t.checked : t.value;
        dirty = true;
        if (t.dataset.step === 'title') {
          root.querySelector(`[data-action="select-step"][data-index="${selected}"]`).textContent =
            step.title;
          root
            .querySelector(`[data-action="move-up"][data-index="${selected}"]`)
            .setAttribute('aria-label', `Move ${step.title} up`);
          root
            .querySelector(`[data-action="move-down"][data-index="${selected}"]`)
            .setAttribute('aria-label', `Move ${step.title} down`);
        }
      }
      if (t.dataset.choice) {
        const step = configuration.steps[selected];
        step.choices = t.checked
          ? [...step.choices, { fittingID: t.dataset.choice, defaults: null }]
          : step.choices.filter((c) => c.fittingID !== t.dataset.choice);
        dirty = true;
        render();
      }
      if (t.id === 'browse-group') renderBrowse();
      if (t.dataset.quantity) {
        const step = currentStep(),
          id = t.dataset.quantity,
          value = t.value;
        pendingQuantities++;
        root.setAttribute('aria-busy', 'true');
        // Keep the inputs and navigation mounted and interactive during a blur update.
        // An explicit action waits for these updates in run(), so its click is retained.
        quantityUpdates = quantityUpdates
          .then(() => updateQuantity(step, id, value))
          .catch(showError)
          .finally(() => {
            pendingQuantities--;
            if (!busy && !pendingQuantities) root.removeAttribute('aria-busy');
          });
      }
    });
    window.addEventListener('beforeunload', (event) => {
      if (root.isConnected && dirty) {
        event.preventDefault();
        event.returnValue = '';
      }
    });
    root.addEventListener('path-template:leave', event => {
      if (busy || pendingQuantities || ((dirty || event.detail?.force) && !confirm('Discard unsaved changes to this template path?'))) event.preventDefault();
    });
    if (mode === 'path') startPath();
    else render();
  }
  if (document.readyState === 'loading')
    document.addEventListener('DOMContentLoaded', initialize, { once: true });
  else initialize();
  document.addEventListener('htmx:afterSwap', initialize);
  document.addEventListener('path-template:mount', initialize);
})();
