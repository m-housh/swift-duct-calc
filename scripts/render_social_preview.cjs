// Regenerate the share image with `node scripts/render_social_preview.cjs`.
const { chromium } = require('playwright');
const fs = require('node:fs');
const path = require('node:path');

async function main() {
  const root = path.resolve(__dirname, '..');
  const css = fs.readFileSync(path.join(root, 'Public/css/ductcalc-wordmark.css'), 'utf8');
  const mark = fs.readFileSync(path.join(root, 'Public/images/brand/ductcalc-mark-light.webp'));
  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage({ viewport: { width: 1200, height: 630 }, deviceScaleFactor: 1 });
    await page.setContent(`<!doctype html><html lang="en"><head><meta charset="utf-8">
      <style>${css}
        * { box-sizing: border-box; }
        body { margin: 0; width: 1200px; height: 630px; background: #f5f6f8;
          display: flex; align-items: center; justify-content: center; }
        .dc-wordmark { gap: 28px; }
        .dc-wordmark-name { font-size: 112px; letter-spacing: -.04em; }
        .dc-wordmark-description { font-size: 28px; letter-spacing: .175em; }
        .domain { position: absolute; bottom: 64px; margin: 0;
          font: 500 24px system-ui, sans-serif; color: #586675; }
      </style></head><body>
      <div class="dc-wordmark">
        <div class="dc-wordmark-name">
          <span class="dc-wordmark-icon"><img alt="" src="data:image/webp;base64,${mark.toString('base64')}"></span>
          <span>uct</span><span class="dc-wordmark-c">C</span><span>alc</span>
        </div>
        <div class="dc-wordmark-description">Residential duct design</div>
      </div>
      <p class="domain">ductcalc.pro</p>
      </body></html>`);
    await page.locator('img').evaluate(image => image.decode());
    await page.screenshot({ path: path.join(root, 'Public/images/brand/social-preview.png') });
  } finally {
    await browser.close();
  }
}

main().catch(error => { console.error(error); process.exitCode = 1; });
