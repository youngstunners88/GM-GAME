#!/usr/bin/env node
/**
 * glb-shot.mjs — look at a GLB before it goes into the game: renders six views
 * (front, back, left, right, top, 3/4) of any .glb into one contact sheet with
 * three.js in headless Chromium, and prints its bounds, triangle count and meshes.
 *
 *   node scripts/glb-shot.mjs <model.glb> <out.png> [--size 360] [--bg 222222]
 *
 * Why: Meshy output arrives in arbitrary orientation and scale, sometimes as a
 * multi-object scene (the founder's "Gold Mine Stage" is three carts + Lil Blunt),
 * and "it imported" is not "it looks right". Every model placed in the runner gets
 * a contact sheet first (skill: ep2-meshy-studio).
 * Needs: `npm i --no-save three` (node_modules is gitignored) + the bundled Chromium.
 */
import http from 'http';
import { readFileSync, existsSync, statSync } from 'fs';
import { resolve, extname, join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { chromium } from 'playwright';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const [glb, out] = process.argv.slice(2);
const opt = (n, d) => { const i = process.argv.indexOf(n); return i >= 0 ? process.argv[i + 1] : d; };
const SIZE = +opt('--size', '360');
const BG = opt('--bg', '222222');
if (!glb || !out || !existsSync(glb)) { console.error('usage: glb-shot.mjs <model.glb> <out.png>'); process.exit(2); }

const page = `<!doctype html><html><body style="margin:0;background:#${BG}">
<script type="importmap">{"imports":{"three":"/node_modules/three/build/three.module.js","three/addons/":"/node_modules/three/examples/jsm/"}}</script>
<script type="module">
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
const S = ${SIZE};
const r = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
r.setSize(S * 3, S * 2); r.outputColorSpace = THREE.SRGBColorSpace;
document.body.appendChild(r.domElement);
const scene = new THREE.Scene(); scene.background = new THREE.Color(0x${BG});
scene.add(new THREE.HemisphereLight(0xffffff, 0x404040, 1.6));
const d1 = new THREE.DirectionalLight(0xffffff, 2.2); d1.position.set(3, 5, 4); scene.add(d1);
const d2 = new THREE.DirectionalLight(0xffffff, 0.8); d2.position.set(-4, 2, -3); scene.add(d2);
new GLTFLoader().load('/model.glb', (g) => {
  const root = g.scene; scene.add(root);
  const box = new THREE.Box3().setFromObject(root);
  const c = box.getCenter(new THREE.Vector3()), sz = box.getSize(new THREE.Vector3());
  let tris = 0, meshes = [];
  root.traverse(o => { if (o.isMesh) { const gi = o.geometry; tris += (gi.index ? gi.index.count : gi.attributes.position.count) / 3; meshes.push(o.name); } });
  const R = sz.length() * 0.62;
  const views = [['front', [0, 0, 1]], ['back', [0, 0, -1]], ['left', [-1, 0, 0]], ['right', [1, 0, 0]], ['top', [0, 1, 0.001]], ['3/4', [0.7, 0.45, 0.7]]];
  r.setScissorTest(true);
  views.forEach(([name, v], i) => {
    const cam = new THREE.PerspectiveCamera(35, 1, R / 100, R * 10);
    const dir = new THREE.Vector3(...v).normalize();
    cam.position.copy(c).addScaledVector(dir, R / Math.tan(THREE.MathUtils.degToRad(17.5)) * 0.62);
    cam.lookAt(c);
    const x = (i % 3) * S, y = (1 - Math.floor(i / 3)) * S;
    r.setViewport(x, y, S, S); r.setScissor(x, y, S, S); r.render(scene, cam);
  });
  window.__info = { min: box.min.toArray(), max: box.max.toArray(), size: sz.toArray(), tris: Math.round(tris), meshes: meshes.length };
  window.__done = true;
}, undefined, (e) => { window.__info = { error: String(e) }; window.__done = true; });
</script></body></html>`;

const server = http.createServer((req, res) => {
  const url = req.url.split('?')[0];
  if (url === '/') { res.writeHead(200, { 'Content-Type': 'text/html' }); return res.end(page); }
  if (url === '/model.glb') { res.writeHead(200, { 'Content-Type': 'model/gltf-binary' }); return res.end(readFileSync(glb)); }
  const f = join(ROOT, url);
  if (url.startsWith('/node_modules/') && existsSync(f) && statSync(f).isFile()) {
    res.writeHead(200, { 'Content-Type': extname(f) === '.js' ? 'text/javascript' : 'application/octet-stream' });
    return res.end(readFileSync(f));
  }
  res.writeHead(404); res.end();
}).listen(0);
const port = server.address().port;
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_BIN || '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
  args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const p = await browser.newPage({ viewport: { width: SIZE * 3, height: SIZE * 2 } });
await p.goto(`http://localhost:${port}/`);
await p.waitForFunction(() => window.__done, null, { timeout: 600000 });
const info = await p.evaluate(() => window.__info);
await p.locator('canvas').screenshot({ path: out });
console.log(JSON.stringify(info));
await browser.close(); server.close();
