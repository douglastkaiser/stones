/* Run against a local web/ server. See README.md. */
const assert = require('node:assert/strict');
const { pathToFileURL } = require('node:url');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
(async () => {
  const browser = await chromium.launch({executablePath: process.env.CHROMIUM_PATH || undefined, args: ['--no-sandbox']});
  try {
    const context = await browser.newContext();
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    const origin = process.env.PROMO_ORIGIN || 'http://127.0.0.1:8765';
    await page.goto(`${origin}/share/`);
    await page.locator('.card').last().waitFor();
    assert.equal(await page.locator('.card').count(), 12);
    for (const width of [320, 390, 1280]) {
      await page.setViewportSize({width, height: 900});
      assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), `overflow at ${width}`);
      await page.evaluate(() => { document.body.style.zoom = '2'; });
      assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), `zoom overflow at ${width}`);
      await page.evaluate(() => { document.body.style.zoom = ''; });
    }
    // All image and download URLs must work, including font and SVG/ZIP downloads.
    for (const src of await page.locator('img').evaluateAll(nodes => nodes.map(n => n.src))) {
      assert((await context.request.get(src)).ok(), src);
    }
    for (const href of await page.locator('a[download]').evaluateAll(nodes => nodes.map(n => n.href))) {
      assert((await context.request.get(href)).ok(), href);
    }
    await page.evaluate(() => Object.defineProperty(navigator, 'clipboard', {configurable: true, value: {writeText: async text => {window.copied = text;}}}));
    const items = await page.locator('#kit-config').evaluate(node => JSON.parse(node.textContent).items);
    for (let i = 0; i < items.length; i++) {
      const card = page.locator('.card').nth(i);
      await card.getByRole('button', {name: 'Copy HTML', exact: true}).click();
      let copied = await page.evaluate(() => window.copied);
      assert(copied.includes(`href="${items[i].destination}"`));
      assert(copied.includes(`/assets/${items[i].name}.png`));
      await card.getByRole('button', {name: 'Copy Markdown', exact: true}).click();
      copied = await page.evaluate(() => window.copied);
      assert(copied.endsWith(`](${items[i].destination})`));
    }
    await page.getByRole('button', {name: 'Copy HTML', exact: true}).first().click();
    const snippet = await page.evaluate(() => window.copied);
    assert(snippet.includes('https://www.douglastkaiser.com/stones/share/assets/'));
    assert(snippet.includes('max-width:100%;height:auto;'));
    assert(snippet.includes('alt="Stones'));
    // Render copied HTML in an independent host, routing production images to the local build.
    const host = await context.newPage();
    await host.route('https://www.douglastkaiser.com/stones/share/assets/**', async route => route.fulfill({response: await context.request.get(route.request().url().replace('https://www.douglastkaiser.com/stones', origin))}));
    await host.setContent(snippet);
    await host.locator('img').evaluate(img => img.decode());
    assert.equal(await host.locator('a').getAttribute('href'), 'https://www.douglastkaiser.com/stones/');
    await page.getByRole('button', {name: 'Copy Markdown', exact: true}).first().click();
    const markdown = await page.evaluate(() => window.copied);
    assert(/^\[!\[.+\]\(https:\/\/.+\.png\)\]\(https:\/\/.+\)$/.test(markdown));
    const { marked } = await import(process.env.MARKED_MODULE ? pathToFileURL(process.env.MARKED_MODULE).href : 'marked');
    await host.setContent(marked.parse(markdown));
    await host.locator('img').evaluate(img => img.decode());
    assert.equal(await host.locator('a').getAttribute('href'), 'https://www.douglastkaiser.com/stones/');
    await page.evaluate(() => Object.defineProperty(navigator, 'clipboard', {configurable: true, value: {writeText: async () => {throw Error('denied');}}}));
    await page.getByRole('button', {name: 'Copy image URL', exact: true}).first().click();
    assert(await page.locator('dialog').isVisible());
    assert((await page.locator('textarea').inputValue()).startsWith('https://'));
    await page.keyboard.press('Escape');
    assert(!(await page.locator('dialog').isVisible()));
    await page.keyboard.press('Tab');
    assert(await page.evaluate(() => document.activeElement.tagName !== 'BODY'));
    await page.setViewportSize({width: 1280, height: 1000});
    await page.locator('img').evaluateAll(images => images.forEach(img => { img.loading = 'eager'; }));
    await page.locator('img').evaluateAll(images => Promise.all(images.map(img => img.decode())));
    await page.screenshot({path: '/tmp/stones-share-desktop.png', fullPage: true});
    await page.setViewportSize({width: 390, height: 844});
    await page.screenshot({path: '/tmp/stones-share-mobile.png', fullPage: true});
    // Exercise the public-release UI using a different configuration, without editing sources.
    const html = await (await context.request.get(`${origin}/share/`)).text();
    const kit = await page.locator('#kit-config').evaluate(node => JSON.parse(node.textContent));
    const publicKit = {...kit, android_status: 'public', android: {
      title: 'Available on Android', action: 'Get it on Google Play',
      destination: kit.android_url, qr_action: 'install on Android',
      qr_note: 'Links to Google Play', instructions: 'Install from Google Play.'
    }};
    publicKit.availability = 'Play on web. Available on Android. Coming soon to iOS.';
    publicKit.items = kit.items.map(item => item.name === 'qr-android' ? {...item, destination: kit.android_url} : item);
    const publicPage = await context.newPage();
    await publicPage.route(`${origin}/share/`, route => route.fulfill({
      contentType: 'text/html', body: html.replace(/(<script id="kit-config" type="application\/json">)[\s\S]*?(<\/script>)/,
        (_, start, end) => start + JSON.stringify(publicKit) + end)
    }));
    await publicPage.goto(`${origin}/share/`);
    await publicPage.locator('.card').last().waitFor();
    assert.equal(await publicPage.locator('#android-primary').getAttribute('href'), kit.android_url);
    assert.equal(await publicPage.locator('#android-title').textContent(), 'Available on Android');
    assert(!(await publicPage.locator('#android-store-wrap').isVisible()));
    assert(!(await publicPage.locator('body').innerText()).includes('Join Android testing'));
    assert(!(await publicPage.locator('body').innerText()).includes('Links to tester enrollment'));
    assert.deepEqual(errors, []);
    console.log('PASS: responsive layouts, downloads, copy success/fallback, HTML embed, rendered Markdown, public-release controls, keyboard, screenshots');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
