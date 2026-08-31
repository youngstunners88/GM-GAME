import { chromium } from 'playwright';

const BASE = 'http://localhost:8934/index.html';
const OUT = '/home/user/GM-GAME/artifacts/founder_shots_2026-08-22_claim-jumper';

async function capture(boss, filename, waitMs) {
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const errors = [];
  const logs = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  page.on('console', (msg) => {
    logs.push(`[${msg.type()}] ${msg.text()}`);
    if (msg.type() === 'error') errors.push(msg.text());
  });
  await page.goto(`${BASE}?boss=${boss}`, { waitUntil: 'load', timeout: 30000 });
  await page.waitForTimeout(waitMs);
  await page.screenshot({ path: `${OUT}/${filename}` });
  await browser.close();
  console.log(`boss=${boss} -> ${filename} | console/page errors: ${errors.length}`);
  if (errors.length) console.log('ERRORS:\n' + errors.slice(0, 10).join('\n'));
  console.log('LAST LOGS:\n' + logs.slice(-15).join('\n'));
}

await capture(1, 'live_boss1_auditor_after_fix.png', 20000);
await capture(3, 'live_boss3_claim_jumper_after_fix.png', 20000);
