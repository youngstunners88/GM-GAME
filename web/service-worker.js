/* === LIL BLUNT — Offline PWA Cache === */

const CACHE_NAME = 'lilblunt-v1';
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

self.addEventListener('fetch', (e) => {
	if (e.request.method !== 'GET') return;
	e.respondWith(
		caches.match(e.request).then(cached => {
			return cached || fetch(e.request).then(res => {
				if (res.ok && e.request.url.startsWith(self.location.origin)) {
					const copy = res.clone();
					caches.open(CACHE_NAME).then(cache => cache.put(e.request, copy));
				}
				return res;
			}).catch(() => cached);
		})
	);
});
