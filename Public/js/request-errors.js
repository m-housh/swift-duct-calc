// Only application error responses contain text intended for the user. Proxy pages stay private.
window.ductCalcRequestErrors = {
  message(failure) {
    if (typeof failure?.message !== 'string') return null;
    const fields = Array.isArray(failure.fields) ? failure.fields : [];
    return [failure.title, failure.message, ...fields.map(field => field?.message),
      failure.reference ? `Error reference: ${failure.reference}` : ''].filter(Boolean).join('\n');
  },
  async check(response, invalidMessage = null) {
    if (!response.headers.get('Content-Type')?.startsWith('application/vnd.ductcalc.error+json')) return;
    let failure;
    try { failure = await response.json(); } catch { return; }
    const message = this.message(failure);
    if (!message) return;
    if (invalidMessage && [400, 404, 413].includes(response.status)) throw Error(invalidMessage);
    throw Error(message);
  }
};
