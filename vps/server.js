// Server untuk menjalankan situs ini di VPS (Coolify), pengganti hosting Vercel.
// Halaman statis dilayani apa adanya, /api/<nama> memanggil api/<nama>.js yang sama
// dengan Vercel lewat pembungkus req.body / res.status().json().
const fs = require('fs');
const path = require('path');
const http = require('http');

const ROOT = path.join(__dirname, '..');
const API = ['login', 'register', 'register-pawrade', 'tautan-petugas'];
const handlers = Object.fromEntries(API.map((n) => [n, require(path.join(ROOT, 'api', n + '.js'))]));
const TYPES = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css', '.svg': 'image/svg+xml', '.png': 'image/png', '.webp': 'image/webp', '.jpg': 'image/jpeg', '.ico': 'image/x-icon', '.json': 'application/json' };

function bacaBody(req) {
  return new Promise((ok, gagal) => {
    const c = []; let n = 0;
    req.on('data', (d) => { n += d.length; if (n > 6e6) { gagal(new Error('terlalu besar')); req.destroy(); } else c.push(d); });
    req.on('end', () => ok(Buffer.concat(c).toString()));
  });
}

async function tangani(req, res) {
  const p = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  const json = (code, o) => { res.writeHead(code, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' }); res.end(JSON.stringify(o)); };

  const api = p.match(/^\/api\/([\w-]+)$/);
  if (api) {
    if (!handlers[api[1]]) return json(404, { error: 'tidak ada' });
    let body = {};
    if (!['GET', 'HEAD'].includes(req.method)) { try { body = JSON.parse((await bacaBody(req)) || '{}'); } catch (e) { body = {}; } }
    const r = { code: 200, status(c) { this.code = c; return this; }, json(o) { json(this.code, o); } };
    return handlers[api[1]]({ method: req.method, body, headers: req.headers }, r);
  }

  // Hanya berkas di akar repo (.html/.js/.css) dan isi folder assets yang boleh diambil.
  const f = p === '/' ? '/index.html' : p;
  const full = path.normalize(path.join(ROOT, f));
  const diAssets = full.startsWith(path.join(ROOT, 'assets') + path.sep);
  const diAkar = path.dirname(full) === ROOT && /^[^.][^/]*\.(html|js|css)$/.test(path.basename(full));
  if (f.includes('\0') || !(diAkar || diAssets) || !fs.existsSync(full) || fs.statSync(full).isDirectory()) {
    res.writeHead(404, { 'Content-Type': 'text/plain' }); return res.end('Tidak ada');
  }
  res.writeHead(200, { 'Content-Type': TYPES[path.extname(full)] || 'application/octet-stream', 'Cache-Control': 'public, max-age=0, must-revalidate' });
  fs.createReadStream(full).pipe(res);
}

http.createServer((req, res) => tangani(req, res).catch((e) => { try { res.writeHead(500); res.end(); } catch (_) {} })).listen(3000);
console.log('Pet Blessing jalan di port 3000');
