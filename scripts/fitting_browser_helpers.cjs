const assert = require('node:assert/strict');

// Exercise the list destination after saving, then reopen through its Edit link.
async function saveAndReopen(page) {
  const name = await page.locator('#path-name').inputValue();
  const endpoint = await page.locator('#fitting-path').getAttribute('data-endpoint');
  await page.locator('#save-path').click();
  await page.waitForURL(url => url.pathname === endpoint && !url.search);
  assert.equal(await page.locator('#fitting-path').count(), 0);
  const row = page.getByRole('row').filter({ has: page.getByRole('cell', { name, exact: true }) });
  await row.getByRole('link', { name: 'Edit', exact: true }).click();
  await page.locator('#fitting-path').waitFor({ state: 'visible' });
  assert(await page.locator('#fitting-path').evaluate(dialog => dialog.matches(':modal')));
}
module.exports = { saveAndReopen };
