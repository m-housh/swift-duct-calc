const fs = require('node:fs');
const { JSDOM } = require('jsdom');
const dom = new JSDOM(fs.readFileSync('Tests/ViewControllerTests/__Snapshots__/ViewControllerTests/userProfile.1.html', 'utf8'));
const serialized = dom.window.document.querySelector('[data-keybindings]').dataset.keybindings;
dom.window.close();
exports.defaults = JSON.parse(serialized);
exports.script = source => `if (!document.querySelector('[data-keybindings]')) document.body.dataset.keybindings = ${JSON.stringify(serialized)};\n` + source;
exports.wrap = html => `<div data-keybindings='${serialized.replaceAll("'", '&#39;')}'>${html}</div>`;
