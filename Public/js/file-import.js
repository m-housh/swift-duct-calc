// File imports: the drop zone, the chosen file, and upload progress for [data-file-import] forms.
// Elements with data-import-when="state …" show only in those states, and data-import-format
// elements only for a chosen file with that extension. Forms with their own follow-up steps
// listen for `file-import:choose` and `file-import:state` and call `ductCalcFileImport.show`.
(() => {
  if (window.ductCalcFileImport) return;
  const MAX_BYTES = 10 * 1024 * 1024;
  const importForm = node => node?.closest?.('[data-file-import]');
  const part = (form, name) => form.querySelector(`[data-${name}]`);
  const fileInput = form => part(form, 'import-dropzone').querySelector('input[type=file]');

  function formatSize(bytes) {
    return bytes >= 1024 * 1024
      ? `${(bytes / 1024 / 1024).toFixed(1)} MB`
      : `${Math.max(1, Math.round(bytes / 1024))} KB`;
  }

  function showError(form, message) {
    const alert = form.querySelector(':scope > [role=alert]');
    alert.textContent = message;
    alert.hidden = !message;
  }

  function show(form, state) {
    form.dataset.importState = state;
    part(form, 'import-dropzone').hidden = state !== 'empty';
    part(form, 'import-file').hidden = state === 'empty';
    for (const button of part(form, 'import-file').querySelectorAll('button')) {
      button.hidden = state === 'uploading';
    }
    part(form, 'import-progress').hidden = state !== 'uploading';
    for (const element of form.querySelectorAll('[data-import-when]')) {
      element.hidden = !element.dataset.importWhen.split(' ').includes(state);
    }
    for (const element of form.querySelectorAll('[data-import-format]')) {
      element.hidden = element.dataset.importFormat !== form.dataset.chosenFormat;
    }
    form.dispatchEvent(new CustomEvent('file-import:state', { bubbles: true, detail: { state } }));
  }

  // The accepted type a file matches, as a format: "application/pdf" or ".pdf" → "pdf".
  // MIME types come first so a PDF without a matching suffix still selects the PDF route.
  function acceptedFormat(input, file) {
    const name = file.name.toLowerCase();
    const types = input.accept.split(',').map(type => type.trim().toLowerCase()).filter(Boolean);
    const mime = types.find(type => !type.startsWith('.') && type === file.type);
    if (mime) return mime.split('/').pop();
    return types.find(type => type.startsWith('.') && name.endsWith(type))?.slice(1);
  }

  function choose(form, file) {
    const input = fileInput(form);
    const format = file && acceptedFormat(input, file);
    const problem = !file ? ''
      : !format ? `“${file.name}” can't be imported here. Choose a ${form.dataset.fileTypes}.`
      : file.size > MAX_BYTES ? 'The file is too large. Choose a file smaller than 10 MB.' : '';
    form.dispatchEvent(new CustomEvent('file-import:choose', { bubbles: true }));
    showError(form, problem);
    if (!file || problem) {
      input.value = '';
      delete form.dataset.chosenFormat;
      show(form, 'empty');
      return;
    }
    if (input.files[0] !== file) {
      const transfer = new DataTransfer();
      transfer.items.add(file);
      input.files = transfer.files;
    }
    form.dataset.chosenFormat = format;
    part(form, 'import-file-name').textContent = file.name;
    part(form, 'import-file-size').textContent = formatSize(file.size);
    show(form, 'chosen');
    form.querySelector('[data-import-when~="chosen"] [type=submit]')?.focus();
  }

  document.addEventListener('click', event => {
    const form = importForm(event.target);
    if (!form) return;
    if (event.target.closest('[data-import-replace]')) fileInput(form).click();
    if (event.target.closest('[data-import-remove]')) {
      choose(form, null);
      fileInput(form).focus();
    }
  });

  document.addEventListener('change', event => {
    const form = importForm(event.target);
    if (form && event.target === fileInput(form)) choose(form, event.target.files[0]);
  });

  const dropTarget = event =>
    event.target.closest?.('[data-file-import] :is([data-import-dropzone], [data-import-file])');
  document.addEventListener('dragover', event => {
    const target = dropTarget(event);
    if (!target || importForm(target).dataset.importState === 'uploading') return;
    event.preventDefault();
    target.dataset.dragover = '';
  });
  document.addEventListener('dragleave', event => delete dropTarget(event)?.dataset.dragover);
  document.addEventListener('drop', event => {
    const target = dropTarget(event);
    if (!target) return;
    event.preventDefault();
    delete target.dataset.dragover;
    const form = importForm(target);
    if (form.dataset.importState !== 'uploading') choose(form, event.dataTransfer.files[0]);
  });

  document.addEventListener('htmx:configRequest', event => {
    const form = importForm(event.detail.elt);
    const action = form?.getAttribute(`data-import-action-${form.dataset.chosenFormat}`);
    if (action) event.detail.path = action;
  });

  document.addEventListener('htmx:beforeRequest', event => {
    const form = importForm(event.detail.elt);
    if (!form) return;
    form.dataset.returnState = form.dataset.importState;
    part(form, 'import-progress-label').textContent = 'Uploading…';
    part(form, 'import-progress-value').textContent = '0%';
    part(form, 'import-progress').querySelector('progress').value = 0;
    show(form, 'uploading');
  });

  document.addEventListener('htmx:beforeSend', event => {
    const form = importForm(event.detail.elt);
    if (!form) return;
    const bar = part(form, 'import-progress').querySelector('progress');
    const upload = event.detail.xhr.upload;
    upload.addEventListener('progress', progress => {
      if (!progress.lengthComputable) return;
      const percent = Math.round(progress.loaded / progress.total * 100);
      bar.value = percent;
      part(form, 'import-progress-value').textContent = `${percent}%`;
    });
    upload.addEventListener('load', () => {
      bar.removeAttribute('value');
      part(form, 'import-progress-label').textContent = form.dataset.readingLabel;
      part(form, 'import-progress-value').textContent = '';
    });
  });

  document.addEventListener('htmx:afterRequest', event => {
    const form = importForm(event.detail.elt);
    if (form?.dataset.importState === 'uploading') show(form, form.dataset.returnState || 'chosen');
  });

  window.ductCalcFileImport = { show };
})();
