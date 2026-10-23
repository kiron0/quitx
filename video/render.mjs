import { spawn } from 'node:child_process';
import { createRequire } from 'node:module';
import { mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
function loadPlaywright() {
  for (const name of ['playwright', '@playwright/test', 'playwright-core']) {
    try { return require(name); } catch {}
  }
  throw new Error('Playwright not found. Run: npm i playwright && npx playwright install chromium');
}
const playwright = loadPlaywright();

const here = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const stillsArg = args.indexOf('--stills');
const stills = stillsArg >= 0 ? args[stillsArg + 1].split(',').map(Number) : null;
const out = resolve(args.find(a => a.endsWith('.mp4')) ?? resolve(here, '../site/assets/demo.mp4'));
const fps = 30;

const browser = await playwright.chromium.launch();
const page = await browser.newPage({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 4 / 3 });
await page.goto('file://' + resolve(here, 'demo.html'));
await page.evaluate(() => document.fonts.ready);
await page.waitForFunction(() => window.READY && [...document.images].every(i => i.complete));
await page.waitForFunction(() => [...document.images].every(i => i.complete));
const total = await page.evaluate(() => window.TOTAL);
const sfx = await page.evaluate(() => window.SFX || []);

if (stills) {
  mkdirSync(resolve(here, 'stills'), { recursive: true });
  for (const t of stills) {
    await page.evaluate(t => window.render(t), t);
    writeFileSync(resolve(here, `stills/t${t}.png`), await page.screenshot());
  }
  await browser.close();
  console.log('Wrote stills to video/stills/');
  process.exit(0);
}

const work = resolve(tmpdir(), `quitx-demo-${process.pid}`);
mkdirSync(work, { recursive: true });
const silent = resolve(work, 'video.mp4');
const ffmpeg = spawn('ffmpeg', [
  '-y', '-loglevel', 'error',
  '-f', 'image2pipe', '-framerate', String(fps), '-c:v', 'mjpeg', '-i', '-',
  '-c:v', 'libx264', '-preset', 'slow', '-crf', '22', '-pix_fmt', 'yuv420p',
  '-movflags', '+faststart', '-an', silent,
], { stdio: ['pipe', 'inherit', 'inherit'] });

const frames = Math.round(total * fps);
for (let i = 0; i < frames; i++) {
  await page.evaluate(t => window.render(t), i / fps);
  const buf = await page.screenshot({ type: 'jpeg', quality: 92 });
  if (!ffmpeg.stdin.write(buf)) await new Promise(r => ffmpeg.stdin.once('drain', r));
  if (i % 60 === 0) process.stdout.write(`frame ${i}/${frames}\r`);
}
ffmpeg.stdin.end();
await new Promise(r => ffmpeg.on('close', r));
await browser.close();

const run = (cmd, args) => new Promise((ok, fail) => spawn(cmd, args, { stdio: 'inherit' }).on('close', c => c === 0 ? ok() : fail(new Error(`${cmd} exited ${c}`))));
const events = resolve(work, 'sfx.json');
const wav = resolve(work, 'audio.wav');
writeFileSync(events, JSON.stringify(sfx));
await run('python3', [resolve(here, 'sfx.py'), events, String(total), wav]);
await run('ffmpeg', ['-y', '-loglevel', 'error', '-i', silent, '-i', wav, '-c:v', 'copy', '-af', 'acompressor=threshold=-24dB:ratio=3:attack=5:release=120,loudnorm=I=-16:TP=-1.5:LRA=9', '-ar', '48000', '-c:a', 'aac', '-b:a', '160k', '-shortest', '-movflags', '+faststart', out]);
rmSync(work, { recursive: true, force: true });
console.log(`\nWrote ${out}`);
