const CACHE_NAME = 'iron-grind-attendance-shell-v2';
const APP_SHELL = [
    './attendance-phone.html',
    './attendance-app.webmanifest',
    './assets/js/attendance-phone.js',
    './assets/js/supabase-client.js',
    './assets/css/style.css',
    './assets/images/iron-grind-mark.png',
    './assets/images/iron-grind-mark-192.png'
];

self.addEventListener('install', event => {
    event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll(APP_SHELL)));
    self.skipWaiting();
});

self.addEventListener('activate', event => {
    event.waitUntil(caches.keys().then(keys => Promise.all(
        keys.filter(key => key.startsWith('iron-grind-attendance-shell-') && key !== CACHE_NAME)
            .map(key => caches.delete(key))
    )));
    self.clients.claim();
});

self.addEventListener('fetch', event => {
    const requestUrl = new URL(event.request.url);
    if (event.request.method !== 'GET' || requestUrl.origin !== self.location.origin) return;

    if (event.request.mode === 'navigate' && requestUrl.pathname.endsWith('/attendance-phone.html')) {
        event.respondWith(fetch(event.request).catch(() => caches.match('./attendance-phone.html')));
        return;
    }

    if (APP_SHELL.some(path => new URL(path, self.registration.scope).pathname === requestUrl.pathname)) {
        event.respondWith(caches.match(event.request, { ignoreSearch: true }).then(cached => cached || fetch(event.request)));
    }
});
