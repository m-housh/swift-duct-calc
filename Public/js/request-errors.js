// Only application error responses contain text intended for the user. Proxy pages stay private.
window.ductCalcRequestErrors = {
  message(failure) {
    if (typeof failure?.message !== 'string') return null;
    const fields = Array.isArray(failure.fields) ? failure.fields : [];
    return [failure.title, failure.message, ...fields.map(field => field?.message),
      failure.reference ? `Error reference: ${failure.reference}` : ''].filter(Boolean).join('\n');
  },
  appendActions(target, actions) {
    if (!target || !Array.isArray(actions)) return;
    for (const action of actions) {
      if (typeof action?.label !== 'string' || typeof action.href !== 'string' || !/^\/(?![\\/])/.test(action.href)) continue;
      const link = document.createElement('a');
      link.className = 'link block'; link.textContent = action.label; link.href = action.href;
      link.target = '_blank'; link.rel = 'noopener'; target.append(link);
    }
  },
  render(target, error) {
    target.textContent = typeof error === 'string' ? error : error.message;
    this.appendActions(target, error.actions);
  },
  async check(response, invalidMessage = null) {
    if (!response.headers.get('Content-Type')?.startsWith('application/vnd.ductcalc.error+json')) return;
    let failure;
    try { failure = await response.json(); } catch { return; }
    const message = this.message(failure);
    if (!message) return;
    if (invalidMessage && [400, 404, 413].includes(response.status)) throw Error(invalidMessage);
    throw Object.assign(Error(message), { actions: failure.actions });
  }
};
