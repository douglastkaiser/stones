'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"icons/Icon-512.png": "beecfab16d83e2ed97fd99faf5c360c9",
"icons/Icon-maskable-512.png": "beecfab16d83e2ed97fd99faf5c360c9",
"icons/Icon-192.png": "16edfb33f7e5134807b07e1787023bec",
"icons/Icon-maskable-192.png": "16edfb33f7e5134807b07e1787023bec",
"manifest.json": "ba363494bbf7037e8f3ffe49fcbd90e1",
"index.html": "103466aa1cfb3e541a3f39c602a0c54f",
"/": "103466aa1cfb3e541a3f39c602a0c54f",
"splash/img/light-4x.png": "fbdeabc1060b64b95d668b4c0704b758",
"splash/img/branding-1x.png": "d8d1e9127b76420c171eaa31305c408b",
"splash/img/dark-4x.png": "fbdeabc1060b64b95d668b4c0704b758",
"splash/img/branding-dark-1x.png": "d8d1e9127b76420c171eaa31305c408b",
"splash/img/branding-4x.png": "a99644239623c25947ad9cf2196506ab",
"splash/img/dark-3x.png": "8745ffe4a8bc93624821944cbb005d88",
"splash/img/branding-dark-2x.png": "2cdab3605e6eafcb11f7a88aa7f067c4",
"splash/img/dark-1x.png": "70fbdcdbbe2bae8805bfd697977f3f93",
"splash/img/branding-dark-4x.png": "a99644239623c25947ad9cf2196506ab",
"splash/img/dark-2x.png": "beecfab16d83e2ed97fd99faf5c360c9",
"splash/img/branding-3x.png": "bc1983490b4db20fbda63ec5d0eeeadc",
"splash/img/light-1x.png": "70fbdcdbbe2bae8805bfd697977f3f93",
"splash/img/branding-dark-3x.png": "bc1983490b4db20fbda63ec5d0eeeadc",
"splash/img/branding-2x.png": "2cdab3605e6eafcb11f7a88aa7f067c4",
"splash/img/light-3x.png": "8745ffe4a8bc93624821944cbb005d88",
"splash/img/light-2x.png": "beecfab16d83e2ed97fd99faf5c360c9",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.bin.json": "12f531cab015a8a6e19c6889304ddb73",
"assets/assets/splash/branding.png": "283b8861f88ee8ccc45d4f398ab814a5",
"assets/assets/icon/app_icon.png": "d17e57696f3eb10da364ded788f5f6cc",
"assets/assets/sounds/piece_place_marble.wav": "67d157f082ecfa179108db30584252be",
"assets/assets/sounds/achievement_unlock.wav": "67d157f082ecfa179108db30584252be",
"assets/assets/sounds/win.wav": "8c99f66a285f23fe48f0cad3ae28e951",
"assets/assets/sounds/piece_place_minimal.wav": "67d157f082ecfa179108db30584252be",
"assets/assets/sounds/stack_move_marble.wav": "ed306e547cdfe93c91d6e3e7d02b2428",
"assets/assets/sounds/wall_flatten.wav": "079f0435d0497243b141b5dc9060feef",
"assets/assets/sounds/stack_move.wav": "ed306e547cdfe93c91d6e3e7d02b2428",
"assets/assets/sounds/piece_place_stone.wav": "67d157f082ecfa179108db30584252be",
"assets/assets/sounds/illegal_move.wav": "e327ae836f4825c6f4edc269799eec4c",
"assets/assets/sounds/stack_move_carved.wav": "ed306e547cdfe93c91d6e3e7d02b2428",
"assets/assets/sounds/piece_place_pixel.wav": "67d157f082ecfa179108db30584252be",
"assets/assets/sounds/piece_place.wav": "67d157f082ecfa179108db30584252be",
"assets/fonts/MaterialIcons-Regular.otf": "a5c51b7e9811b7185dda29bf9b915c30",
"assets/NOTICES": "cdcf79935e2a1a5f337bfaa0f41a40ea",
"assets/FontManifest.json": "7b2a36307916a9721811788013e65289",
"assets/AssetManifest.bin": "e014072e53802926f762e5ea32c86c40",
"canvaskit/chromium/canvaskit.wasm": "a726e3f75a84fcdf495a15817c63a35d",
"canvaskit/chromium/canvaskit.js": "a80c765aaa8af8645c9fb1aae53f9abf",
"canvaskit/chromium/canvaskit.js.symbols": "e2d09f0e434bc118bf67dae526737d07",
"canvaskit/skwasm_heavy.wasm": "b0be7910760d205ea4e011458df6ee01",
"canvaskit/skwasm_heavy.js.symbols": "0755b4fb399918388d71b59ad390b055",
"canvaskit/skwasm.js": "8060d46e9a4901ca9991edd3a26be4f0",
"canvaskit/canvaskit.wasm": "9b6a7830bf26959b200594729d73538e",
"canvaskit/skwasm_heavy.js": "740d43a6b8240ef9e23eed8c48840da4",
"canvaskit/canvaskit.js": "8331fe38e66b3a898c4f37648aaf7ee2",
"canvaskit/skwasm.wasm": "7e5f3afdd3b0747a1fd4517cea239898",
"canvaskit/canvaskit.js.symbols": "a3c9f77715b642d0437d9c275caba91e",
"canvaskit/skwasm.js.symbols": "3a4aadf4e8141f284bd524976b1d6bdc",
"favicon.png": "c55a5587f3203031033bcf03aef062dc",
"privacy.html": "d6ccfc61ebfcdeeac5590564ea4e1985",
"flutter_bootstrap.js": "09622879bbab6a876da332dcb7d0ae98",
"version.json": "5e196233514c0d7d0311c263380c2147",
"main.dart.js": "6ecb56c8e85c4848064aae64a63cee6a"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
