#!/usr/bin/env node
// Build the Fort Knox Vault architectural shell in Pascal Editor, headlessly,
// by driving @pascal-app/mcp over stdio JSON-RPC. Emits a Pascal scene JSON
// that the Pascal editor can open — and, in a browser, GLB-export.
//
// WHY THIS EXISTS
// The founder's Pascal spec assumes "build in Pascal -> export GLB" is a
// headless pipeline. Half of that is true and half isn't, verified 2026-09-07:
//
//   * Authoring headlessly:  WORKS (this script is the proof).
//   * GLB export headlessly: DOES NOT WORK. Pascal's own export_glb tool
//     returns {"status":"not_implemented","reason":"GLB export requires the
//     Three.js renderer, which is browser-only"}. exportSceneToGlb() takes a
//     live rendered Object3D and calls requestAnimationFrame +
//     WebGPUTextureUtils, so it needs the running editor in a browser.
//
// So the real pipeline is:
//   this script (headless)  ->  *.pascal.json  ->  open in Pascal editor
//   (browser)  ->  GLB export  ->  game engine.
//
// TWO WORKAROUNDS ARE REQUIRED (both upstream defects in @pascal-app/mcp@0.3.2):
//
//   1. zod MUST be pinned to 4.3.5. Pascal declares "zod": "^4.3.5", but on
//      zod 4.5.4 every node-creating tool dies with "Duplicate discriminator
//      value \"undefined\"" from its discriminated-union registry. Reproduced
//      under both node and bun; pinning 4.3.5 fixes it completely.
//   2. The package ships 179 extensionless relative ESM imports (plus bare
//      directory imports) while being "type": "module" — valid under a
//      bundler, invalid under plain Node ESM. Run under `bun`, or under node
//      with ./ext-resolver.mjs registered (see RUN below).
//
// RUN
//   mkdir -p /tmp/pascal && cd /tmp/pascal && npm init -y
//   npm i @pascal-app/mcp@0.3.2 @pascal-app/core@0.9.2 zod@4.3.5
//   cp <repo>/tools/pascal/{build_fort_knox.mjs,ext-resolver.mjs} .
//   node build_fort_knox.mjs            # spawns the server under bun
//
// Output: fort_knox_shell.pascal.json (committed under
// artifacts/episode2-gold-mine/assets/chambers/fort_knox/).

import { spawn } from 'node:child_process'
import { writeFileSync } from 'node:fs'

const SERVER = 'node_modules/@pascal-app/mcp/dist/bin/pascal-mcp.js'
// bun resolves the extensionless imports natively; node needs ext-resolver.mjs.
const BUN = process.env.BUN_BIN ?? '/root/.bun/bin/bun'

const server = spawn(BUN, [SERVER], { stdio: ['pipe', 'pipe', 'pipe'] })

let buf = ''
const pending = new Map()
server.stdout.on('data', (d) => {
	buf += d.toString()
	let i
	while ((i = buf.indexOf('\n')) >= 0) {
		const line = buf.slice(0, i).trim()
		buf = buf.slice(i + 1)
		if (!line) continue
		try {
			const m = JSON.parse(line)
			if (m.id && pending.has(m.id)) {
				pending.get(m.id)(m)
				pending.delete(m.id)
			}
		} catch {
			/* server logs non-JSON banner lines on stdout; ignore */
		}
	}
})
server.stderr.on('data', (d) => process.stderr.write('[pascal] ' + d))

let id = 1
const rpc = (method, params) =>
	new Promise((res, rej) => {
		const myId = id++
		pending.set(myId, res)
		server.stdin.write(JSON.stringify({ jsonrpc: '2.0', id: myId, method, params }) + '\n')
		setTimeout(() => rej(new Error('timeout ' + method)), 25000)
	})

let failures = 0
async function tool(name, args = {}) {
	const r = await rpc('tools/call', { name, arguments: args })
	const isErr = Boolean(r.result?.isError || r.error)
	let parsed = r.result?.structuredContent
	if (!parsed && r.result?.content?.[0]?.text) {
		try {
			parsed = JSON.parse(r.result.content[0].text)
		} catch {
			parsed = r.result.content[0].text
		}
	}
	if (isErr) failures++
	console.log(`  ${isErr ? 'FAIL' : 'ok  '} ${name}: ${JSON.stringify(parsed ?? r.error).slice(0, 200)}`)
	return parsed
}

await rpc('initialize', {
	protocolVersion: '2024-11-05',
	capabilities: {},
	clientInfo: { name: 'gm-game-fort-knox', version: '1.0.0' },
})
server.stdin.write(JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' }) + '\n')

// Pascal seeds every scene with a site -> building. Use that building NODE id
// (a project id from create_project is a different namespace and is rejected).
const scene0 = await tool('get_scene')
const buildingId = Object.values(scene0?.nodes ?? {}).find((n) => n?.type === 'building')?.id
if (!buildingId) {
	console.error('no building node in the seeded scene')
	server.kill()
	process.exit(1)
}

// --- Fort Knox Vault, metres, origin at the SW corner of the main hall -------
// Heavy vault language: 0.6m perimeter walls, 6m ceiling. Interior screens are
// waist-high (1.2m) so they read as shooter cover, not as rooms.
//
// Layout reviewed by Grok 4.5 (docs/model-responses/2026-09-07-grok-ep2-chamber-
// architecture.md). Its corrections to the first pass, all applied here:
//   * the first pass was a SEALED BOX — no openings at all, and the melt alcove
//     was walled off completely. Now: 4m entry on south, 4m exit throat on
//     north, and a 4m alcove mouth so the player commits inside to melt while
//     the fight stays out in the hall.
//   * cover screens moved off the even x=6/x=12 grid to x=7/x=13 and staggered
//     in y, so the hall is not a symmetrical shooting gallery.
//   * staking lockers added as 1.2m cover along the north wall, positioned to
//     feed the exit throat rather than block it.
//   * entry south / exit north (not the same wall) forces a through-line past
//     the furnace.
const H = 6
const lvl = await tool('create_level', { buildingId, label: 'Vault Floor', elevation: 0, height: H })
const levelId = lvl?.levelId
if (!levelId) {
	console.error('create_level failed — is zod pinned to 4.3.5? See header.')
	server.kill()
	process.exit(1)
}

// Walls that later need an opening cut into them are built by name.
const walls = {
	south: { start: [0, 0], end: [24, 0], thickness: 0.6, height: H },   // entry side
	east: { start: [24, 0], end: [24, 16], thickness: 0.6, height: H },
	north: { start: [24, 16], end: [0, 16], thickness: 0.6, height: H }, // exit to tracks
	west: { start: [0, 16], end: [0, 0], thickness: 0.6, height: H },
	// Melt-furnace alcove (7 x 6) on the east side, y=5..11.
	alcoveMouth: { start: [17, 5], end: [17, 11], thickness: 0.4, height: H },
	alcoveSouth: { start: [17, 5], end: [24, 5], thickness: 0.4, height: H },
	alcoveNorth: { start: [17, 11], end: [24, 11], thickness: 0.4, height: H },
	// Staggered shooter cover across the staking floor.
	screenA: { start: [7, 5], end: [7, 9], thickness: 0.4, height: 1.2 },
	screenB: { start: [13, 7], end: [13, 11], thickness: 0.4, height: 1.2 },
	// Staking lockers along the north wall — cover that feeds the exit throat
	// (x=10..14) instead of blocking it.
	lockerW: { start: [2, 14], end: [5, 14], thickness: 0.4, height: 1.2 },
	lockerC: { start: [6, 14], end: [9, 14], thickness: 0.4, height: 1.2 },
	lockerE: { start: [15, 14], end: [18, 14], thickness: 0.4, height: 1.2 },
}
const wallId = {}
for (const [name, w] of Object.entries(walls)) {
	const r = await tool('create_wall', { levelId, ...w })
	if (r?.wallId) wallId[name] = r.wallId
}

// Openings. `position` is 0..1 along the wall from its start point.
// South entry and north exit are both centred at x=12 on 24m walls -> t=0.5.
await tool('cut_opening', { wallId: wallId.south, type: 'door', position: 0.5, width: 4, height: 3.5 })
await tool('cut_opening', { wallId: wallId.north, type: 'door', position: 0.5, width: 4, height: 3.5 })
// Alcove mouth: 6m wall from y=5..11, opening centred at y=8 -> t=0.5.
await tool('cut_opening', { wallId: wallId.alcoveMouth, type: 'door', position: 0.5, width: 4, height: 4 })

// Zones make the design intent legible inside the scene file itself.
const zones = [
	{ label: 'Entry apron', polygon: [[0, 0], [24, 0], [24, 3], [0, 3]] },
	{ label: 'Staking hall', polygon: [[2, 3], [22, 3], [22, 12], [2, 12]] },
	{ label: 'Melt furnace alcove', polygon: [[17, 5], [24, 5], [24, 11], [17, 11]] },
	{ label: 'Exit throat', polygon: [[10, 14], [14, 14], [14, 16], [10, 16]] },
]
for (const z of zones) await tool('set_zone', { levelId, ...z })

const validation = await tool('validate_scene')
await tool('check_collisions')
await tool('export_glb') // expected: not_implemented — see header
const json = await tool('export_json', { pretty: true })

if (json?.json) {
	writeFileSync('fort_knox_shell.pascal.json', json.json)
	console.log(`\nwrote fort_knox_shell.pascal.json (${json.json.length} bytes)`)
}
console.log(`validation: ${JSON.stringify(validation)}`)
console.log(failures === 0 ? 'FORT_KNOX_SHELL: ALL STEPS OK' : `FORT_KNOX_SHELL: ${failures} FAILURE(S)`)

server.kill()
process.exit(failures === 0 ? 0 : 1)
