import { createRequire } from 'node:module';
import { mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
function loadPlaywright() {
  for (const name of ['playwright', '@playwright/test', 'playwright-core']) {
    try { return require(name); } catch {}
  }
  throw new Error('Playwright not found. Run: npm i playwright && npx playwright install chromium');
}
const { chromium } = loadPlaywright();

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');
const page = 'file://' + resolve(here, 'install.html');
const out = resolve(root, 'site/assets/install');
mkdirSync(out, { recursive: true });

const browser = await chromium.launch();
async function shoot(id, path) {
  const tab = await browser.newPage({ viewport: { width: 1200, height: 750 }, deviceScaleFactor: 2 });
  await tab.goto(page + '#' + id);
  await tab.evaluate(() => document.fonts.ready);
  await tab.waitForFunction(() => window.SHOT_READY && [...document.images].every(i => i.complete));
  for (const f of tab.frames()) await f.waitForFunction(() => window.SHOT_READY && [...document.images].every(i => i.complete)).catch(() => {});
  await tab.waitForTimeout(300);
  await tab.screenshot({ path, type: 'jpeg', quality: 84 });
  await tab.close();
}
for (const id of ['dmg', 'blocked', 'settings', 'confirm', 'ready', 'terminal']) {
  await shoot(`${id}-bare`, resolve(out, `${id}.jpg`));
}
await shoot('strip', resolve(root, 'Support/Screenshots/install.jpg'));
await browser.close();
console.log('Wrote site/assets/install/*.jpg and Support/Screenshots/install.jpg');
