#!/usr/bin/env node
// Local stand-in for the ICP price-feed canister's /prices route, used by
// tests/icp_contract_test.gd.
//
// WHY THIS FILE EXISTS: that gate asserts the ONLINE parse path (source ==
// "icp", ETH == 3456.78, sub-cent SMOKE precision) by hitting
// http://127.0.0.1:8788. Nothing in the repo ever served that port — the
// gate only passed when some unrelated dev server happened to be alive on
// 8788, and reported 6 failures the moment it wasn't. A gate whose result
// depends on ambient processes is not a gate; it is a coin flip that
// usually lands heads.
//
// The numbers below are the test's own expected values. Keep them in sync
// with tests/icp_contract_test.gd if that file's assertions change.
//
// Usage:
//   node scripts/icp-price-fixture.mjs [port]     # default 8788
//
// The real canister is Motoko (icp/ directory); this only imitates the one
// HTTP route the client parses, deliberately NOT the canister's logic.

import http from 'http';

const PORT = Number(process.argv[2] || 8788);

// Exactly the shape src/autoload/icp_backend.gd::fetch_prices() parses:
// a top-level object with a "prices" dictionary. Anything else makes the
// client latch icp_online = false and fall back to offline.
const PRICES = {
  ETH: 3456.78,
  BTC: 67890.12,
  SMOKE: 0.00042, // sub-cent: the reason the canister renders 8 decimals
  GOLD: 2345.67,
  TITANX: 0.0000123,
};

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  if (url.pathname === '/prices') {
    const body = JSON.stringify({ prices: PRICES });
    res.writeHead(200, {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(body),
    });
    res.end(body);
    return;
  }
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'not found' }));
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`icp price fixture listening on http://127.0.0.1:${PORT}/prices`);
});
