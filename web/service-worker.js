/* === LIL BLUNT — Offline PWA Cache === */

const CACHE_NAME = 'lilblunt-v2';
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

// Immutable game engine assets are safe to serve cache-first;
// everything else is network-first so launcher updates reach users immediately.
function isImmutableAsset(url) {
	return /\/game\/.+\.(js|wasm|pck)$/.test(url);
}

self.addEventListener('fetch', (e) => {
	if (e.request.method !== 'GET') return;
	const sameOrigin = e.request.url.startsWith(self.location.origin);
	if (!sameOrigin) return;

	if (isImmutableAsset(e.request.url)) {
		e.respondWith(
			caches.match(e.request).then(cached =>
				cached || fetch(e.request).then(res => {
					if (res.ok) {
						const copy = res.clone();
						caches.open(CACHE_NAME).then(cache => cache.put(e.request, copy));
					}
					return res;
				})
			)
		);
		return;
	}

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
