'use strict';
const kit = JSON.parse(document.getElementById('kit-config').textContent);
const absolute = path => new URL(`share/${path}`, kit.base_url).href;
const dialog = document.getElementById('copy-dialog');
const value = document.getElementById('copy-value');
const status = document.getElementById('status');
let statusTimer;
function announce(message) {
  status.textContent = message;
  clearTimeout(statusTimer);
  statusTimer = setTimeout(() => { status.textContent = ''; }, 5000);
}
async function copy(text) {
  try {
    await navigator.clipboard.writeText(text);
    announce('Copied. Ready to share!');
  } catch (_) {
    value.value = text;
    document.getElementById('copy-help').textContent = 'Automatic copying is unavailable. Select and copy this text manually.';
    if (!dialog.open) dialog.showModal();
    value.focus();
    value.select();
  }
}
function button(label, text) {
  const node = document.createElement('button');
  node.type = 'button'; node.textContent = label;
  node.addEventListener('click', () => copy(text));
  return node;
}
function link(label, href, download = false) {
  const node = document.createElement('a');
  node.textContent = label; node.href = href;
  if (download) node.download = '';
  return node;
}
const escapeAttribute = text => text.replaceAll('&', '&amp;').replaceAll('"', '&quot;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
document.getElementById('availability').textContent = kit.availability;
document.getElementById('android-instructions').textContent = kit.android.instructions;
document.getElementById('android-title').textContent = kit.android.title;
document.getElementById('android-primary').textContent = `${kit.android.action} ↗`;
document.getElementById('android-primary').href = kit.android.destination;
document.getElementById('android-store-wrap').hidden = kit.android_status === 'public';
document.getElementById('android-store').href = kit.android_url;
for (const item of kit.items) {
  const relative = `assets/${item.name}.png`;
  const src = absolute(relative);
  const alt = item.name.startsWith('qr-') ? `Stones ${item.title}: scan to ${item.name === 'qr-web' ? 'play on web' : kit.android.qr_action}` : `Stones — Every stack changes the road. ${kit.availability}`;
  const card = document.createElement('article'); card.className = 'card';
  const preview = document.createElement('div'); preview.className = 'preview';
  const image = document.createElement('img'); image.src = relative; image.alt = alt;
  image.width = item.width; image.height = item.height; image.loading = 'lazy';
  preview.append(image);
  const details = document.createElement('div'); details.className = 'details';
  const title = document.createElement('h3'); title.textContent = item.title;
  const dimensions = document.createElement('p'); dimensions.className = 'dimensions';
  dimensions.textContent = `${item.width} × ${item.height} px${item.name === 'qr-android' ? ` · ${kit.android.qr_note}` : ''}`;
  const actions = document.createElement('div'); actions.className = 'actions';
  const snippet = `<a href="${escapeAttribute(item.destination)}"><img src="${escapeAttribute(src)}" alt="${escapeAttribute(alt)}" width="${item.width}" height="${item.height}" style="max-width:100%;height:auto;"></a>`;
  actions.append(link('Download PNG ↓', relative, true));
  if (item.svg) actions.append(link('Download SVG ↓', `assets/${item.name}.svg`, true));
  actions.append(button('Copy image URL', src), button('Copy HTML', snippet),
    button('Copy Markdown', `[![${alt}](${src})](${item.destination})`));
  details.append(title, dimensions, actions); card.append(preview, details);
  document.getElementById('gallery').append(card);
}
for (const [label, text] of [
  ['Short description', kit.short_description], ['Long description', kit.long_description],
  ['Platform availability', kit.availability], ['Play on web', kit.base_url],
  [kit.android.action, kit.android.destination], ['Android Play Store listing', kit.android_url],
  ['Share this kit', absolute('')]
]) {
  const block = document.createElement('div'); block.className = 'copy-block';
  const title = document.createElement('h3'); title.textContent = label;
  const content = document.createElement('p'); content.textContent = text;
  block.append(title, content, button(`Copy ${label.toLowerCase()}`, text));
  document.getElementById('copy-blocks').append(block);
}
document.getElementById('copy-again').addEventListener('click', () => copy(value.value));
document.getElementById('copy-close').addEventListener('click', () => dialog.close());
