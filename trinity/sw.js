/**
 * TRINITY Service Worker v20.φ
 * Offline support with φ-optimized caching strategy
 * 
 * φ² + 1/φ² = 3
 */

const CACHE_NAME = 'trinity-v20-phi';
const PHI = 1.618033988749895;

// Assets to cache immediately
const PRECACHE_ASSETS = [
  '/',
  '/runtime.html',
  '/article.html'
];

// Cache strategies
const CACHE_STRATEGIES = {
  // Network first, fallback to cache
  networkFirst: ['runtime.html', 'article.html'],
  // Cache first, update in background
  cacheFirst: ['.wasm', '.png', '.jpg', '.svg', '.woff2'],
  // Stale while revalidate
  staleWhileRevalidate: ['.js', '.css']
};

// Install event - precache assets
self.addEventListener('install', (event) => {
  console.log('⚡ Service Worker installing (v20.φ)');
  
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('⚡ Precaching assets');
        return cache.addAll(PRECACHE_ASSETS);
      })
      .then(() => self.skipWaiting())
  );
});

// Activate event - clean old caches
self.addEventListener('activate', (event) => {
  console.log('⚡ Service Worker activating');
  
  event.waitUntil(
    caches.keys()
      .then((cacheNames) => {
        return Promise.all(
          cacheNames
            .filter((name) => name !== CACHE_NAME)
            .map((name) => {
              console.log('⚡ Deleting old cache:', name);
              return caches.delete(name);
            })
        );
      })
      .then(() => self.clients.claim())
  );
});

// Fetch event - serve from cache or network
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  
  // Skip non-GET requests
  if (event.request.method !== 'GET') return;
  
  // Skip external requests
  if (!url.origin.includes(self.location.origin)) return;
  
  // Determine strategy based on file type
  const strategy = getStrategy(url.pathname);
  
  event.respondWith(handleFetch(event.request, strategy));
});

/**
 * Get caching strategy for URL
 */
function getStrategy(pathname) {
  for (const [strategy, patterns] of Object.entries(CACHE_STRATEGIES)) {
    if (patterns.some(p => pathname.includes(p))) {
      return strategy;
    }
  }
  return 'networkFirst';
}

/**
 * Handle fetch with specified strategy
 */
async function handleFetch(request, strategy) {
  switch (strategy) {
    case 'cacheFirst':
      return cacheFirst(request);
    case 'staleWhileRevalidate':
      return staleWhileRevalidate(request);
    case 'networkFirst':
    default:
      return networkFirst(request);
  }
}

/**
 * Network first strategy
 * Try network, fallback to cache
 */
async function networkFirst(request) {
  try {
    const response = await fetch(request);
    
    // Cache successful responses
    if (response.ok) {
      const cache = await caches.open(CACHE_NAME);
      cache.put(request, response.clone());
    }
    
    return response;
  } catch (error) {
    // Network failed, try cache
    const cached = await caches.match(request);
    if (cached) {
      console.log('⚡ Serving from cache (offline):', request.url);
      return cached;
    }
    
    // Return offline page for navigation requests
    if (request.mode === 'navigate') {
      return caches.match('/runtime.html');
    }
    
    throw error;
  }
}

/**
 * Cache first strategy
 * Serve from cache, fetch in background
 */
async function cacheFirst(request) {
  const cached = await caches.match(request);
  
  if (cached) {
    // Update cache in background
    fetch(request)
      .then(async (response) => {
        if (response.ok) {
          const cache = await caches.open(CACHE_NAME);
          cache.put(request, response);
        }
      })
      .catch(() => {});
    
    return cached;
  }
  
  // Not in cache, fetch and cache
  const response = await fetch(request);
  
  if (response.ok) {
    const cache = await caches.open(CACHE_NAME);
    cache.put(request, response.clone());
  }
  
  return response;
}

/**
 * Stale while revalidate strategy
 * Serve stale, update in background
 */
async function staleWhileRevalidate(request) {
  const cache = await caches.open(CACHE_NAME);
  const cached = await cache.match(request);
  
  // Fetch fresh version in background
  const fetchPromise = fetch(request)
    .then((response) => {
      if (response.ok) {
        cache.put(request, response.clone());
      }
      return response;
    })
    .catch(() => cached);
  
  // Return cached immediately, or wait for fetch
  return cached || fetchPromise;
}

// Message handler for cache management
self.addEventListener('message', (event) => {
  if (event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
  
  if (event.data.type === 'CLEAR_CACHE') {
    caches.delete(CACHE_NAME)
      .then(() => {
        console.log('⚡ Cache cleared');
        event.ports[0].postMessage({ success: true });
      });
  }
  
  if (event.data.type === 'GET_CACHE_SIZE') {
    getCacheSize()
      .then((size) => {
        event.ports[0].postMessage({ size });
      });
  }
});

/**
 * Get total cache size
 */
async function getCacheSize() {
  const cache = await caches.open(CACHE_NAME);
  const keys = await cache.keys();
  
  let totalSize = 0;
  for (const request of keys) {
    const response = await cache.match(request);
    const blob = await response.blob();
    totalSize += blob.size;
  }
  
  return totalSize;
}

console.log('⚡ TRINITY Service Worker loaded | φ² + 1/φ² = 3');
