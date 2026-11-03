// Rasterizes Design/AppIcon/saccade-app-icon.svg into App/Resources/Assets.xcassets/AppIcon.appiconset (every size).
// Dev-only design tool (not part of the app): needs Node + Playwright's Chromium.
// Usage: node scripts/icons/render-app-icon.mjs
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const svg = readFileSync(join(root, 'Design/AppIcon/saccade-app-icon.svg'), 'utf8');
const set = join(root, 'App/Resources/Assets.xcassets/AppIcon.appiconset');
const { images } = JSON.parse(readFileSync(join(set, 'Contents.json'), 'utf8'));

const browser = await chromium.launch();
for (const image of images) {
  const px = parseInt(image.size, 10) * parseInt(image.scale, 10);
  const page = await browser.newPage({ viewport: { width: px, height: px }, deviceScaleFactor: 1 });
  await page.setContent(`<style>html,body{margin:0;background:transparent}svg{width:${px}px;height:${px}px;display:block}</style>${svg}`);
  await page.screenshot({ path: join(set, image.filename), omitBackground: true });
  await page.close();
}
await browser.close();
console.log(`rendered ${images.length} app icon sizes`);
