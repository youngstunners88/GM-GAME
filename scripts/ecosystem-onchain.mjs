#!/usr/bin/env node
/**
 * ECOSYSTEM ON-CHAIN AUDIT — read-only facts about the SMOKE / DIAMONDS / GOLD / BLAZE contracts,
 * with Jev (typed decisions on NUMBERS) as the judge. See .claude/skills/gm-game-ecosystem-funding-audit.
 *
 * Data sources, all keyless and READ-ONLY:
 *   Blockscout v2  https://eth.blockscout.com/api/v2   names, verified source, balances, holders, txs
 *   Public RPC     https://ethereum-rpc.publicnode.com eth_call (owner())     override: ETH_RPC_URL
 * Etherscan V2 needs an API key (ETHERSCAN_API_KEY); none is present in this environment, so it is NOT used here.
 * Blockscout covers the same questions for free. A second source is the cross-check if a key is ever added.
 *
 * Nothing here signs, sends, approves or writes on-chain. Addresses it prints are public protocol contracts for
 * ANALYSIS; they are not game code (CLAUDE.md: never hardcode addresses in game code, use config.json).
 *
 * Usage
 *   discover <url...>            scrape dApp JS bundles for addresses, resolve names, write the registry
 *   inspect <addr...>            name, verified, proxy, ETH balance, owner(), source red flags
 *   holders <token> [--top N]    top holders of a token (share of supply)
 *   flows <addr> [--pages N]     ETH in/out by month (normal + internal txs), last N*50 items
 *   tokenflows <addr> [--pages N] ERC-20 sent out by a contract, by token and destination (the split after wrapping/swapping)
 *   destinations <addr>          where the ETH a contract sends out actually goes (empirical split)
 *   methods <addr> [--pages N]   fingerprint a contract from the methods called on it (works when source is unverified)
 *   balance <addr>               daily ETH balance history
 *   source <addr> [--grep RE]    matching lines of the verified source (find constants / splits)
 *   audit                        run the standard question set over the registry -> facts.json + table
 *   jev [facts.json]             ask Jev typed questions about those NUMBERS (cost ~ $0.00002 / call)
 */
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const BS = process.env.BLOCKSCOUT_URL || 'https://eth.blockscout.com/api/v2';
const RPC = process.env.ETH_RPC_URL || 'https://ethereum-rpc.publicnode.com';
const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const DIR = resolve(ROOT, 'tools/ecosystem-audit');
const REGISTRY = resolve(DIR, 'registry.json');
const FACTS = resolve(DIR, 'facts.json');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const ADDR = /0x[0-9a-fA-F]{40}(?![0-9a-fA-F])/g;
// Noise that appears in every web3 bundle: not protocol contracts.
const NOISE = new Set([
  '0x0000000000000000000000000000000000000000', '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
  '0xca11bde05977b3631167028862be2a173976ca11', '0xeeeeeeee14d718c2b47d9923deab1335e144eeee',
  '0x00000000000c2e074ec69a0dfb2997ba6c7d2e1e', '0xc0497e381f536be9ce14b0dd3817cbcae57d2f62',
  '0x6492649264926492649264926492649264926492', '0x8010801080108010801080108010801080108010',
]);
const INFRA = /uniswap|wrapped ether|wrapped btc|^weth|usd coin|tether|multicall|ens |permit2|swaprouter|universalrouter|quoter|entrypoint/i;

/** GET JSON with polite spacing and retry on 429/5xx. Blockscout rate-limits free callers. */
async function getJson(url, tries = 5) {
  let timeouts = 0;
  for (let i = 0; i < tries; i++) {
    // Bound every call: one stalled socket must not hang a whole audit.
    const res = await fetch(url, { headers: { accept: 'application/json' }, signal: AbortSignal.timeout(15000) }).catch(() => null);
    if (res && res.ok) { await sleep(220); return res.json(); }
    if (res && res.status === 404) return null;
    // A timeout means the endpoint is too heavy for this address; retrying will not help. 429/5xx do get retried.
    if (!res && ++timeouts >= 2) break;
    await sleep(900 * (i + 1));
  }
  throw new Error(`GET failed after retries: ${url}`);
}

async function rpc(method, params) {
  const res = await fetch(RPC, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ jsonrpc: '2.0', id: 1, method, params }),
    signal: AbortSignal.timeout(20000),
  });
  const j = await res.json();
  if (j.error) throw new Error(`${method}: ${j.error.message}`);
  return j.result;
}

const eth = (wei) => Number(BigInt(wei || '0') / 10n ** 12n) / 1e6;       // wei -> ETH, 6 dp
const short = (a) => (a ? `${a.slice(0, 8)}…${a.slice(-4)}` : '-');

async function ownerOf(addr) {
  try {
    const r = await rpc('eth_call', [{ to: addr, data: '0x8da5cb5b' }, 'latest']);
    if (!r || r === '0x' || r.length < 66) return null;
    const o = '0x' + r.slice(-40);
    return /^0x0{40}$/.test(o) ? 'renounced(0x0)' : o;
  } catch { return null; }
}

async function info(addr) {
  const a = await getJson(`${BS}/addresses/${addr}`);
  if (!a) return { address: addr, kind: 'unknown' };
  const out = {
    address: addr, name: a.name || null, kind: a.is_contract ? 'contract' : 'EOA',
    verified: !!a.is_verified, proxy: a.proxy_type || null, eth: eth(a.coin_balance),
    isToken: !!a.token,
  };
  if (a.token || (a.name && a.is_contract)) {
    const t = await getJson(`${BS}/tokens/${addr}`).catch(() => null);
    if (t && t.symbol) {
      out.token = {
        symbol: t.symbol, type: t.type, holders: Number(t.holders_count || 0),
        decimals: Number(t.decimals || 0), supply: t.total_supply, price: t.exchange_rate,
        mcap: t.circulating_market_cap,
      };
    }
  }
  if (out.kind === 'contract') out.owner = await ownerOf(addr);
  return out;
}

/** Red flags in verified source: who can change the rules? */
async function sourceFlags(addr) {
  const c = await getJson(`${BS}/smart-contracts/${addr}`);
  if (!c || !c.is_verified) return { verified: false };
  const files = [c.source_code || '', ...(c.additional_sources || []).map((f) => f.source_code || '')];
  const src = files.join('\n');
  const setters = [...new Set([...src.matchAll(/function\s+(set[A-Za-z0-9_]*|update[A-Za-z0-9_]*|withdraw[A-Za-z0-9_]*|rescue[A-Za-z0-9_]*|sweep[A-Za-z0-9_]*)\s*\(/g)].map((m) => m[1]))];
  return {
    verified: true, name: c.name, compiler: c.compiler_version, proxy: c.proxy_type || null,
    ownable: /Ownable|onlyOwner/.test(src), upgradeable: /upgradeTo|UUPS|TransparentUpgradeable/.test(src),
    delegatecall: /delegatecall/.test(src), selfdestruct: /selfdestruct/.test(src),
    setters, bytes: src.length,
  };
}

async function pagedItems(url, pages) {
  const items = [];
  let next = null;
  for (let p = 0; p < pages; p++) {
    const q = next ? (url.includes('?') ? '&' : '?') + new URLSearchParams(next).toString() : '';
    // A later page can time out on a heavy contract: keep what we already have and say so.
    const j = await getJson(url + q).catch(() => undefined);
    if (j === undefined) return { items, complete: false, failed: true };
    if (!j) break;
    items.push(...(j.items || []));
    next = j.next_page_params;
    if (!next) return { items, complete: true };
  }
  return { items, complete: false };
}

/** Where does the ETH a contract sends out actually go? Empirical split, newest `pages*50` internal transfers. */
async function destinations(addr, pages = 10) {
  const itx = await pagedItems(`${BS}/addresses/${addr}/internal-transactions`, pages);
  const me = addr.toLowerCase();
  const to = {};
  let total = 0;
  for (const t of itx.items) {
    if (t.from?.hash?.toLowerCase() !== me) continue;
    const v = Number(BigInt(t.value || '0') / 10n ** 12n) / 1e6;
    if (!v) continue;
    const k = t.to?.hash;
    const e = (to[k] ??= { name: t.to?.name || null, eth: 0, n: 0 });
    e.eth += v; e.n++; total += v;
  }
  const rows = Object.entries(to).map(([address, e]) => ({ address, name: e.name, eth: +e.eth.toFixed(4), n: e.n, share: total ? e.eth / total : 0 })).sort((a, b) => b.eth - a.eth);
  return { rows, total: +total.toFixed(4), scanned: itx.items.length, complete: itx.complete };
}

/** Token (ERC-20) transfers OUT of a contract, grouped by token then destination: the empirical split after ETH is wrapped/swapped. */
async function tokenflows(addr, pages = 12) {
  const r = await pagedItems(`${BS}/addresses/${addr}/token-transfers?type=ERC-20&filter=from`, pages);
  const me = addr.toLowerCase();
  const byTok = {};
  for (const t of r.items) {
    if (t.from?.hash?.toLowerCase() !== me) continue;
    const dec = Number(t.total?.decimals ?? t.token?.decimals ?? 18);
    const v = Number(BigInt(t.total?.value || '0') / 10n ** BigInt(Math.max(0, dec - 6))) / 1e6;
    const tok = (byTok[t.token?.symbol || '?'] ??= { total: 0, to: {}, first: t.timestamp, last: t.timestamp });
    const d = (tok.to[t.to?.hash] ??= { name: t.to?.name || null, v: 0, n: 0 });
    d.v += v; d.n++; tok.total += v;
    if (t.timestamp < tok.first) tok.first = t.timestamp;
    if (t.timestamp > tok.last) tok.last = t.timestamp;
  }
  return { byTok, scanned: r.items.length, complete: r.complete };
}

/** What does an unverified contract DO? Fingerprint it from the methods people call and the ETH sent with them. */
async function methods(addr, pages = 4) {
  const tx = await pagedItems(`${BS}/addresses/${addr}/transactions?filter=to`, pages);
  const m = {};
  for (const t of tx.items) {
    const k = t.method || (t.raw_input === '0x' ? '(plain transfer)' : t.raw_input?.slice(0, 10)) || '(unknown)';
    const e = (m[k] ??= { calls: 0, eth: 0, senders: new Set(), first: t.timestamp, last: t.timestamp });
    e.calls++; e.eth += Number(BigInt(t.value || '0') / 10n ** 12n) / 1e6; e.senders.add(t.from?.hash);
    if (t.timestamp < e.first) e.first = t.timestamp;
    if (t.timestamp > e.last) e.last = t.timestamp;
  }
  return { rows: Object.entries(m).map(([k, v]) => ({ method: k, calls: v.calls, ethSent: +v.eth.toFixed(4), senders: v.senders.size, first: v.first?.slice(0, 10), last: v.last?.slice(0, 10) })).sort((a, b) => b.calls - a.calls), scanned: tx.items.length, complete: tx.complete };
}

/** ETH in/out by month from normal + internal transactions. */
async function flows(addr, pages = 6) {
  // allSettled: a heavy contract can time out one endpoint; keep the other and say the result is partial.
  const [txR, itxR] = await Promise.allSettled([
    pagedItems(`${BS}/addresses/${addr}/transactions`, pages),
    pagedItems(`${BS}/addresses/${addr}/internal-transactions`, pages),
  ]);
  const empty = { items: [], complete: false };
  const tx = txR.status === 'fulfilled' ? txR.value : empty;
  const itx = itxR.status === 'fulfilled' ? itxR.value : empty;
  const partial = [txR, itxR].some((r) => r.status === 'rejected');
  const me = addr.toLowerCase();
  const months = {};
  const bucket = (ts) => (months[ts.slice(0, 7)] ??= { in: 0, out: 0, nIn: 0, senders: new Set() });
  const add = (ts, from, to, val) => {
    const v = Number(BigInt(val || '0') / 10n ** 12n) / 1e6;
    if (!v || !ts) return;
    const b = bucket(ts);
    if (to?.toLowerCase() === me) { b.in += v; b.nIn++; b.senders.add(from?.toLowerCase()); }
    else if (from?.toLowerCase() === me) b.out += v;
  };
  for (const t of tx.items) add(t.timestamp, t.from?.hash, t.to?.hash, t.value);
  for (const t of itx.items) add(t.timestamp, t.from?.hash, t.to?.hash, t.value);
  const rows = Object.entries(months).sort().map(([m, b]) => ({ month: m, ethIn: +b.in.toFixed(4), ethOut: +b.out.toFixed(4), nIn: b.nIn, senders: b.senders.size }));
  return { rows, complete: tx.complete && itx.complete && !partial, partial, txCount: tx.items.length, internalCount: itx.items.length };
}

async function balanceHistory(addr) {
  const j = await getJson(`${BS}/addresses/${addr}/coin-balance-history-by-day`);
  const it = (j?.items || []).map((x) => ({ date: x.date, eth: eth(x.value) }));
  if (!it.length) return null;
  const first = it[0], last = it[it.length - 1];
  return { days: it.length, first, last, perDay: +((last.eth - first.eth) / Math.max(1, it.length - 1)).toFixed(4), series: it };
}

async function holders(token, top = 10) {
  const t = await getJson(`${BS}/tokens/${token}`);
  const dec = Number(t?.decimals || 18);
  const supply = Number(BigInt(t?.total_supply || '0') / 10n ** BigInt(Math.max(0, dec - 6))) / 1e6;
  const j = await getJson(`${BS}/tokens/${token}/holders`);
  const rows = (j?.items || []).slice(0, top).map((x) => {
    const bal = Number(BigInt(x.value) / 10n ** BigInt(Math.max(0, dec - 6))) / 1e6;
    return { address: x.address.hash, name: x.address.name || null, contract: !!x.address.is_contract, balance: bal, share: supply ? bal / supply : 0 };
  });
  return { symbol: t?.symbol, supply, rows };
}

const arg = (name, def = null) => { const i = process.argv.indexOf(name); return i >= 0 ? process.argv[i + 1] : def; };
const positional = () => process.argv.slice(3).filter((x, i, a) => !x.startsWith('--') && !(a[i - 1] || '').startsWith('--'));
const fmt = (n) => (n >= 1e12 ? `${(n / 1e12).toFixed(2)}T` : n >= 1e9 ? `${(n / 1e9).toFixed(1)}B` : n >= 1e6 ? `${(n / 1e6).toFixed(1)}M` : n.toLocaleString('en-US', { maximumFractionDigits: 3 }));

async function discover(urls) {
  const found = new Map();
  for (const u of urls) {
    const html = await (await fetch(u)).text();
    const base = new URL(u);
    const scripts = [...html.matchAll(/src="([^"]+\.js)"/g)].map((m) => new URL(m[1], base).href);
    for (const s of scripts) {
      const js = await (await fetch(s)).text();
      for (const m of js.matchAll(ADDR)) {
        const a = m[0], k = a.toLowerCase();
        if (NOISE.has(k) || /^0x(.)\1{39}$/.test(k)) continue;
        if (!found.has(k)) found.set(k, { address: a, sources: new Set() });
        found.get(k).sources.add(base.host);
      }
    }
  }
  console.log(`found ${found.size} candidate addresses; resolving names…`);
  const contracts = [];
  for (const { address, sources } of found.values()) {
    const i = await info(address).catch(() => ({ address, kind: 'unknown' }));
    contracts.push({ ...i, sources: [...sources], infra: !!(i.name && INFRA.test(i.name)) });
  }
  contracts.sort((a, b) => (a.infra - b.infra) || String(a.name).localeCompare(String(b.name)));
  mkdirSync(DIR, { recursive: true });
  writeFileSync(REGISTRY, JSON.stringify({ generated: new Date().toISOString(), pages: urls, contracts }, null, 2) + '\n');
  for (const c of contracts) {
    console.log(`${c.infra ? ' infra ' : ' proto '} ${short(c.address)}  ${String(c.name ?? '(unnamed)').padEnd(24)} ${c.kind.padEnd(8)} ${c.verified ? 'verified' : 'unverified'}  ${c.eth ?? '-'} ETH  [${c.sources.join(',')}]`);
  }
  console.log(`\nregistry -> ${REGISTRY}`);
}

async function audit() {
  if (!existsSync(REGISTRY)) throw new Error('No registry. Run: node scripts/ecosystem-onchain.mjs discover <urls…>');
  const reg = JSON.parse(readFileSync(REGISTRY, 'utf8'));
  const targets = reg.contracts.filter((c) => c.kind === 'contract' && !c.infra);
  const pages = Number(arg('--pages', 2));
  const facts = { generated: new Date().toISOString(), contracts: [] };
  mkdirSync(DIR, { recursive: true });
  for (const [n, c] of targets.entries()) {
    const [src, bal, fl] = await Promise.all([
      sourceFlags(c.address).catch(() => ({ verified: false })), balanceHistory(c.address).catch(() => null),
      flows(c.address, pages).catch(() => null),
    ]);
    facts.contracts.push({ ...c, flags: src, balance: bal && { days: bal.days, first: bal.first, last: bal.last, perDay: bal.perDay }, flows: fl && { complete: fl.complete, partial: fl.partial, recent: fl.rows.slice(-4) } });
    console.log(`[${n + 1}/${targets.length}] ${String(c.name ?? short(c.address)).padEnd(24)} ${String(c.eth).padStart(9)} ETH  owner:${c.owner ? short(c.owner) : 'n/a'}  setters:${src.setters?.length ?? '?'}  upgradeable:${src.upgradeable ?? '?'}  verified:${src.verified}  ETH/day:${bal ? bal.perDay : '?'}`);
    // Incremental write: a killed or timed-out run still leaves usable facts.
    writeFileSync(FACTS, JSON.stringify(facts, null, 2) + '\n');
  }
  console.log(`\nfacts -> ${FACTS}`);
}

/** Build a plain-text state for Jev from facts.json: NUMBERS only, thresholds stated in the questions. */
function stateFromFacts(f) {
  const lines = [`On-chain facts, Ethereum mainnet, ${f.generated.slice(0, 10)}. All ETH figures are exact balances or flow sums.`];
  for (const c of f.contracts) {
    if (!c.name) continue;
    const b = c.balance;
    lines.push(`${c.name}: balance ${c.eth} ETH; ` + (b ? `balance change ${b.perDay} ETH/day over the last ${b.days} days; ` : '') +
      `owner key ${c.owner ? (c.owner.startsWith('renounced') ? 'renounced' : 'present') : 'unknown'}; ` +
      `${c.flags?.setters?.length ?? 0} owner-style setter/withdraw functions; upgradeable ${c.flags?.upgradeable ? 'yes' : 'no'}.`);
  }
  return lines.join('\n');
}

async function jev(file) {
  const { evaluate, decide } = await import('./jev.mjs');
  const f = JSON.parse(readFileSync(file || FACTS, 'utf8'));
  // Measured findings (curated, each reproducible by the command named in its line) are appended to the state.
  const findingsPath = resolve(DIR, 'findings.json');
  const findings = existsSync(findingsPath) ? JSON.parse(readFileSync(findingsPath, 'utf8')) : null;
  const state = stateFromFacts(f) + (findings ? `\n\nMeasured findings as of ${findings.asOf}:\n- ${findings.lines.join('\n- ')}` : '');
  const questions = {
    certificate_yield_below_12pct: { type: 'boolean', instructions: 'Based only on these numbers: is the ETH accruing to the probable certificate payout pot, per year, below 12% of the ETH raised from certificate sales? Compute accrual per year divided by ETH raised.' },
    mining_has_stalled: { type: 'boolean', instructions: 'Based only on these numbers: has new mining effectively stopped on both GOLD and DIAMONDS? Answer yes if the latest full month of mining ETH is below 10% of the launch month for each, and at most one week of any month accounts for most of that month.' },
    paying_base_under_100_wallets: { type: 'boolean', instructions: 'Based only on these numbers: is the number of distinct wallets that have ever paid ETH into certificates, GOLD mining or DIAMONDS mining combined below 100? Use the largest per-product count and the sum as the lower and upper bounds.' },
    unverified_money_contracts: { type: 'boolean', instructions: 'Based only on these numbers: do the contracts that hold or route the protocol money have unverified source code? Answer yes if more than a quarter of the audited protocol contracts are unverified.' },
    safe_to_promise_yield: { type: 'choice', instructions: 'Should the project promise a yield or ETH payout to new NFT buyers based on these flows?', criteria: { promise: 'Measured inflow clearly funds the promise.', do_not_promise: 'Measured inflow does not clearly fund a promise; sell on access and utility only.' } },
  };
  const out = await evaluate({ state, questions });
  console.log(`state sent to Jev:\n${state}\n`);
  console.log(`model: ${out.model}   cost: $${(out.usage?.cost ?? 0).toFixed(6)}`);
  for (const [name, a] of Object.entries(out.answers || {})) {
    if (a.type === 'boolean') console.log(`  ${name}: probability=${a.probability.toFixed(3)} -> ${decide(a.probability)}`);
    else console.log(`  ${name}: ${a.choice} (confidence ${a.confidence?.toFixed?.(2) ?? '?'})`);
  }
  console.log('\nJev is a lead, not a fact: re-derive every number above from the raw facts before it informs a decision.');
}

async function main() {
  const cmd = process.argv[2];
  const pos = positional();
  if (cmd === 'discover') return discover(pos);
  if (cmd === 'inspect') {
    for (const a of pos) {
      const [i, s] = await Promise.all([info(a), sourceFlags(a).catch(() => ({ verified: false }))]);
      console.log(JSON.stringify({ ...i, flags: s }, null, 2));
    }
    return;
  }
  if (cmd === 'holders') {
    const h = await holders(pos[0], Number(arg('--top', 10)));
    console.log(`${h.symbol} total supply ${fmt(h.supply)}`);
    for (const r of h.rows) console.log(`  ${short(r.address)}  ${String(r.name ?? (r.contract ? '(contract)' : '')).padEnd(26)} ${fmt(r.balance).padStart(10)}  ${(r.share * 100).toFixed(2)}%`);
    return;
  }
  if (cmd === 'flows') {
    const f = await flows(pos[0], Number(arg('--pages', 6)));
    console.log(`month     ETH in   ETH out   deposits  senders   (${f.txCount} txs + ${f.internalCount} internal; ${f.partial ? 'PARTIAL: one Blockscout endpoint timed out' : f.complete ? 'complete' : 'TRUNCATED: older history not shown'})`);
    for (const r of f.rows) console.log(`${r.month}  ${String(r.ethIn).padStart(8)}  ${String(r.ethOut).padStart(8)}  ${String(r.nIn).padStart(8)}  ${String(r.senders).padStart(7)}`);
    return;
  }
  if (cmd === 'tokenflows') {
    const r = await tokenflows(pos[0], Number(arg('--pages', 12)));
    console.log(`ERC-20 sent OUT by the contract, newest ${r.scanned} transfers (${r.complete ? 'complete' : 'older history not shown'})`);
    for (const [sym, t] of Object.entries(r.byTok).sort((a, b) => b[1].total - a[1].total)) {
      console.log(`\n${sym}  total ${fmt(t.total)}  (${t.first?.slice(0, 10)} .. ${t.last?.slice(0, 10)})`);
      for (const [a, d] of Object.entries(t.to).sort((x, y) => y[1].v - x[1].v).slice(0, 6)) console.log(`  ${short(a)}  ${String(d.name ?? '').padEnd(20)} ${fmt(d.v).padStart(10)}  ${((d.v / t.total) * 100).toFixed(1).padStart(5)}%  (${d.n})`);
    }
    return;
  }
  if (cmd === 'destinations') {
    const r = await destinations(pos[0], Number(arg('--pages', 10)));
    console.log(`ETH sent OUT by the contract: ${r.total} ETH over its newest ${r.scanned} internal transfers (${r.complete ? 'complete' : 'older history not shown'})`);
    for (const x of r.rows.slice(0, 12)) console.log(`  ${short(x.address)}  ${String(x.name ?? '').padEnd(24)} ${String(x.eth).padStart(9)} ETH  ${(x.share * 100).toFixed(1).padStart(5)}%  (${x.n} transfers)`);
    return;
  }
  if (cmd === 'methods') {
    const r = await methods(pos[0], Number(arg('--pages', 4)));
    console.log(`method                      calls   ETH sent  senders  first       last        (${r.scanned} newest calls scanned${r.complete ? ', complete' : ', older history not shown'})`);
    for (const x of r.rows) console.log(`${String(x.method).padEnd(26)}${String(x.calls).padStart(7)}${String(x.ethSent).padStart(11)}${String(x.senders).padStart(9)}  ${x.first}  ${x.last}`);
    return;
  }
  if (cmd === 'balance') {
    const b = await balanceHistory(pos[0]);
    console.log(b ? `${b.first.date} ${b.first.eth} ETH -> ${b.last.date} ${b.last.eth} ETH  (${b.perDay} ETH/day over ${b.days} days)` : 'no history');
    return;
  }
  if (cmd === 'source') {
    const c = await getJson(`${BS}/smart-contracts/${pos[0]}`);
    if (!c?.is_verified) { console.log('not verified'); return; }
    const re = new RegExp(arg('--grep', 'constant|immutable|BPS|PERCENT|percent|share'), 'i');
    const files = [{ path: c.file_path || c.name, code: c.source_code || '' }, ...(c.additional_sources || []).map((f) => ({ path: f.file_path, code: f.source_code || '' }))];
    for (const f of files) for (const [n, l] of f.code.split('\n').entries()) if (re.test(l)) console.log(`${String(f.path).split('/').pop()}:${n + 1}: ${l.trim().slice(0, 160)}`);
    return;
  }
  if (cmd === 'audit') return audit();
  if (cmd === 'jev') return jev(pos[0]);
  console.error(readFileSync(fileURLToPath(import.meta.url), 'utf8').split('*/')[0].split('\n').slice(1).join('\n'));
  process.exit(3);
}

main().catch((e) => { console.error(String(e.message || e)); process.exit(3); });
