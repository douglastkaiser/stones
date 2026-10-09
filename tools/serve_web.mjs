import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { resolve, extname, sep } from 'node:path';

const root = resolve('build/web');
const port = Number(process.env.PORT ?? 4173);
const mime = {'.html': 'text/html', '.js': 'application/javascript',
  '.mjs': 'application/javascript', '.json': 'application/json', '.wasm': 'application/wasm',
  '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg',
  '.woff2': 'font/woff2', '.ttf': 'font/ttf', '.css': 'text/css'};

await stat(resolve(root, 'index.html'));
createServer(async (request, response) => {
  try {
    const path = decodeURIComponent(new URL(request.url, `http://localhost:${port}`).pathname);
    if (path === '/') { response.writeHead(302, {Location: '/stones/'}); response.end(); return; }
    const relative = path.replace(/^\/stones\//, '').replace(/^\/+/, '') || 'index.html';
    const file = resolve(root, relative);
    if (file !== root && !file.startsWith(root + sep)) { response.writeHead(403); response.end(); return; }
    const content = await readFile(file);
    response.writeHead(200, {'Content-Type': mime[extname(file)] ?? 'application/octet-stream',
      'Cache-Control': 'no-store'});
    response.end(content);
  } catch {
    response.writeHead(404); response.end('Not found');
  }
}).listen(port, '127.0.0.1', () => console.log(`Stones preview: http://127.0.0.1:${port}/stones/`));
