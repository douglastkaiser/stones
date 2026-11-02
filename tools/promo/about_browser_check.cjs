/* Exercise the real Flutter About -> external kit journey at production/preview bases. */
const assert = require('node:assert/strict');
const {chromium} = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
(async () => {
  const browser = await chromium.launch({executablePath: process.env.CHROMIUM_PATH || undefined, args: ['--no-sandbox']});
  const origin = process.env.PROMO_ORIGIN || 'http://127.0.0.1:8765';
  try {
    for (const base of ['/stones/', '/stones/pr/123/']) {
      const context = await browser.newContext({viewport: {width: 1280, height: 1200}});
      try {
        await context.route('**/*', async route => {
          const url = new URL(route.request().url());
          let target;
          if (url.origin === origin && url.pathname.startsWith(base)) {
            target = `${origin}/${url.pathname.slice(base.length)}${url.search}`;
          } else if (url.pathname.includes('/flutter-canvaskit/')) {
            const parts = url.pathname.split('/flutter-canvaskit/')[1].split('/').slice(1).join('/');
            target = `${origin}/canvaskit/${parts}`;
          } else { return route.abort(); }
          const response = await context.request.get(target);
          if (url.origin === origin && url.pathname === base) {
            return route.fulfill({response, body: (await response.text()).replace(/<base href="[^"]*">/, `<base href="${base}">`)});
          }
          return route.fulfill({response});
        });
        const page = await context.newPage();
        await page.goto(origin + base);
        await page.locator('flt-semantics-placeholder').waitFor({state: 'attached', timeout: 60000});
        await page.locator('flt-semantics-placeholder').evaluate(node => node.click());
        await page.getByRole('button', {name: 'About Stones', exact: true}).click({timeout: 60000});
        const target = page.getByRole('button', {name: /Get the Stones sharing kit/});
        const opened = context.waitForEvent('page');
        await target.click();
        const kit = await opened;
        await kit.waitForURL(origin + base + 'share/');
        await kit.waitForLoadState('load');
        await kit.locator('.card').last().waitFor();
        assert.equal(await kit.locator('.card').count(), 12);
        // Lazy images can start requests after the load event. Complete them
        // before teardown so no route is cancelled while its fetch is active.
        await kit.evaluate(async () => {
          const images = [...document.images];
          for (const image of images) image.loading = 'eager';
          await Promise.all(images.map(image => image.decode()));
          await document.fonts.ready;
        });
      } finally {
        // Drain asynchronous asset handlers before disposing their request API.
        await context.unrouteAll({behavior: 'wait'});
        await context.close();
      }
    }
    console.log('PASS: real Flutter About opens external kit at production and preview bases');
  } finally { await browser.close(); }
})().catch(error => {console.error(error); process.exitCode = 1;});
