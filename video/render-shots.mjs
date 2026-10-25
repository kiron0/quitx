import { createRequire } from 'node:module';
import { existsSync, mkdirSync } from 'node:fs';
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
const page = 'file://' + resolve(here, 'shots.html');
const readme = resolve(root, 'Support/Screenshots');
const site = resolve(root, 'site/assets/shots');
mkdirSync(readme, { recursive: true });
mkdirSync(site, { recursive: true });

const scenes = ['hero', 'force', 'confirm', 'background', 'exclude', 'stats', 'health', 'sleep', 'theme', 'sounds', 'updates', 'ports', 'portsSettings'];
const readmeOnly = new Set(['portsSettings']);
let browser;
try {
  browser = await chromium.launch();
} catch (error) {
  const systemBrowser = [
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/Applications/Chromium.app/Contents/MacOS/Chromium',
  ].find(existsSync);
  if (!systemBrowser) throw error;
  browser = await chromium.launch({ executablePath: systemBrowser });
}

async function open(hash) {
  const tab = await browser.newPage({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2 });
  await tab.goto(page + '#' + hash);
  await tab.evaluate(() => document.fonts.ready);
  await tab.waitForFunction(() => window.SHOT_READY && [...document.images].every(i => i.complete));
  return tab;
}

for (const id of scenes) {
  let tab = await open(id);
  await tab.screenshot({ path: resolve(readme, `${id}.jpg`), type: 'jpeg', quality: 86 });
  await tab.close();
  if (readmeOnly.has(id)) continue;

  tab = await open(`${id}-bare`);
  const ui = await tab.evaluate(() => window.UI_RECT);
  const focus = await tab.evaluate(() => window.FOCUS_RECT);
  const r = focus || ui;
  const aspect = 16 / 11;
  let w = r.x1 - r.x0 + 112;
  let h = r.y1 - r.y0 + 112;
  if (w / h > aspect) h = w / aspect; else w = h * aspect;
  w = Math.min(w, 1440);
  h = Math.min(h, 900);
  const cx = (r.x0 + r.x1) / 2;
  const cy = (r.y0 + r.y1) / 2;
  const x = Math.round(Math.min(Math.max(0, cx - w / 2), 1440 - w));
  const y = Math.round(Math.min(Math.max(0, cy - h / 2), 900 - h));
  await tab.screenshot({ path: resolve(site, `${id}.jpg`), type: 'jpeg', quality: 86, clip: { x, y, width: Math.round(w), height: Math.round(h) } });
  await tab.close();
}

const og = await open('hero');
await og.screenshot({ path: resolve(root, 'site/assets/og.jpg'), type: 'jpeg', quality: 86, clip: { x: 0, y: 45, width: 1440, height: 756 }, scale: 'css' });
await og.close();
await browser.close();
console.log('Wrote Support/Screenshots/*.jpg, site/assets/shots/*.jpg and site/assets/og.jpg');
