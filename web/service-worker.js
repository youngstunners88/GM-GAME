/* === LIL BLUNT — Offline PWA Cache === */

const CACHE_NAME = 'lilblunt-v3';
const CORE_ASSETS = [
	'./',
	'./index.html',
	'./styles.css',
	'./launcher.js',
	'./manifest.json',
	'./icon.svg'
];

self.addEventListener('install', (e) => {
	e.waitUntil(
		caches.open(CACHE_NAME).then(cache => cache.addAll(CORE_ASSETS).catch(() => {}))
	);
	self.skipWaiting();
});

self.addEventListener('activate', (e) => {
	e.waitUntil(
		caches.keys().then(keys =>
			Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))
		)
	);
	self.clients.claim();
});

// Everything is network-first with cache fallback: game re-exports overwrite
// the SAME filenames (index.wasm/pck/js), so cache-first would pin stale builds.
// Offline play still works via the fallback.
self.addEventListener('fetch', (e) => {
	if (e.request.method !== 'GET') return;
	const sameOrigin = e.request.url.startsWith(self.location.origin);
	if (!sameOrigin) return;

	e.respondWith(
		fetch(e.request).then(res => {
			if (res.ok) {
				const copy = res.clone();
				caches.open(CACHE_NAME).then(cache => cache.put(e.request, copy));
			}
			return res;
		}).catch(() => caches.match(e.request))
	);
});
