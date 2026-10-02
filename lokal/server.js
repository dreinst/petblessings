// Server lokal hari-H Pet Blessing (jalan di Mac, di jaringan router lokasi).
//   node lokal/server.js
//
// * HTTPS :8443 dan HTTP :8080 untuk semua device di router (kamera di HP
//   butuh HTTPS; HTTP untuk laptop booth yang memakai Python urllib).
// * Menyajikan halaman yang sama dengan Vercel. api-config.js diganti supaya
//   halaman memakai API lokal (/rest -> PostgREST lokal).
// * /api/login memakai api/login.js yang sama, akunnya dari lokal/.env.
// * Penyelaras: tiap SYNC_MS menyamakan data dengan VPS kalau internet ada.
//   Data pendaftaran: VPS yang benar (kecuali peserta walk-in, dibuat di sini).
//   Data hari-H (nomor, panggilan, hadir, sertifikat): database yang sedang
//   jadi pemberi nomor yang benar. Hanya satu database yang memberi nomor.
const fs = require('fs');
const path = require('path');
const http = require('http');
const https = require('https');
const os = require('os');

const DIR = __dirname;
const ROOT = path.join(DIR, '..');
for (const line of fs.readFileSync(path.join(DIR, '.env'), 'utf8').split('\n')) {
  const m = line.match(/^([A-Z_]+)=(.*)$/);
  if (m && !(m[1] in process.env)) process.env[m[1]] = m[2];
}
const jwt = require(path.join(ROOT, 'node_modules/jsonwebtoken'));
const LOCAL = 'http://127.0.0.1:3101';
const VPS = process.env.VPS_API_URL;
const SECRET = process.env.JWT_SECRET;
const SYNC_MS = 4000;
process.env.PGRST_JWT_SECRET = SECRET;
process.env.PETBLESSING_API_URL = LOCAL;
const loginHandler = require(path.join(ROOT, 'api/login.js'));
const SYNC_TOKEN = jwt.sign({ role: 'sync_worker' }, SECRET);

// ---------- Penyelaras ----------
const OWNER_COLS = 'id,name,phone,is_parishioner,parish_origin,donation_amount,donation_has_proof,agreed_tos,submitted_at,queue_number,companions,is_test,is_walkin';
const PET_REG = ['id', 'owner_id', 'name', 'type', 'has_photo', 'notes', 'sticker_letter'];
const PET_HARI_H = ['hadir', 'mcfbooth_session_code', 'certificate_url', 'photo_folder_url'];
const CHECKIN_COLS = 'id,owner_id,post,checked_in_at,desk,arrival_number';

const state = { vps_ok: false, lokal_ok: false, pemberi: null, terakhir_sinkron: null, pesan: '', konflik: [], log: [] };
function catat(msg) {
  state.log.unshift(new Date().toLocaleTimeString('id-ID') + ' ' + msg);
  state.log.length = Math.min(state.log.length, 40);
  console.log(msg);
}

async function api(base, pathQ, opts = {}) {
  const res = await fetch(base + pathQ, {
    method: opts.method || 'GET',
    headers: Object.assign({ Authorization: 'Bearer ' + SYNC_TOKEN, 'Content-Type': 'application/json' }, opts.headers || {}),
    body: opts.body ? JSON.stringify(opts.body) : undefined,
    signal: AbortSignal.timeout(opts.timeout || 8000),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(pathQ.split('?')[0] + ' ' + res.status + ' ' + text.slice(0, 200));
  return text ? JSON.parse(text) : null;
}
async function upsert(base, table, rows, onConflict) {
  for (let i = 0; i < rows.length; i += 200) {
    await api(base, '/' + table + '?on_conflict=' + onConflict, {
      method: 'POST', body: rows.slice(i, i + 200),
      headers: { Prefer: 'resolution=merge-duplicates,return=minimal' },
    });
  }
}
const same = (a, b, cols) => cols.every((c) => JSON.stringify(a[c]) === JSON.stringify(b[c]));
const pick = (o, cols) => Object.fromEntries(cols.map((c) => [c, o[c] === undefined ? null : o[c]]));
const byId = (rows, key = 'id') => new Map(rows.map((r) => [r[key], r]));

async function ambilSemua(base) {
  const [hari, owners, pets, checkins, panggilan] = await Promise.all([
    api(base, '/hari_h?id=eq.1'),
    api(base, '/owners?select=' + OWNER_COLS),
    api(base, '/pets?select=' + PET_REG.concat(PET_HARI_H).join(',')),
    api(base, '/checkins?post=eq.reg_ulang&select=' + CHECKIN_COLS),
    api(base, '/panggilan?select=*'),
  ]);
  return { hari: hari[0], owners, pets, checkins, panggilan };
}

// Samakan dua database. sumber = database pemberi nomor ('lokal' / 'vps').
async function samakan(L, V, sumber) {
  const ownerCols = OWNER_COLS.split(',');
  // Pemilik: VPS yang benar untuk pendaftar online, lokal untuk walk-in.
  const vO = byId(V.owners), lO = byId(L.owners);
  const regLokal = new Set(L.checkins.map((c) => c.owner_id));
  const keLokal = [], keVps = [];
  for (const o of V.owners) {
    const l = lO.get(o.id);
    if (!o.is_walkin && (!l || !same(o, l, ownerCols))) keLokal.push(o);
  }
  for (const o of L.owners) {
    const v = vO.get(o.id);
    if (o.is_walkin && (!v || !same(o, v, ownerCols))) keVps.push(o);
  }
  // Pendaftar yang dihapus di VPS (misal pendaftaran ganda) ikut dihapus di
  // lokal, selama belum reg ulang.
  const hapus = L.owners.filter((o) => !o.is_walkin && !vO.has(o.id) && !regLokal.has(o.id)).map((o) => o.id);
  if (keLokal.length) await upsert(LOCAL, 'owners', keLokal.map((o) => pick(o, ownerCols)), 'id');
  if (keVps.length) await upsert(VPS, 'owners', keVps.map((o) => pick(o, ownerCols)), 'id');
  if (hapus.length) {
    await api(LOCAL, '/owners?id=in.(' + hapus.join(',') + ')', { method: 'DELETE', headers: { Prefer: 'return=minimal' } });
    catat('Dihapus di lokal (sudah dihapus di VPS): ' + hapus.length + ' pendaftar');
  }
  if (keLokal.length) catat('Pendaftar online diperbarui ke lokal: ' + keLokal.length);
  if (keVps.length) catat('Walk-in dikirim ke VPS: ' + keVps.length);

  // Hewan: kolom pendaftaran dari pemilik datanya, kolom hari-H dari pemberi nomor.
  const walkin = new Set(L.owners.filter((o) => o.is_walkin).map((o) => o.id));
  const vP = byId(V.pets), lP = byId(L.pets);
  const ids = new Set([...vP.keys(), ...lP.keys()]);
  const cols = PET_REG.concat(PET_HARI_H);
  const pL = [], pV = [];
  for (const id of ids) {
    const v = vP.get(id), l = lP.get(id);
    const reg = walkin.has((l || v).owner_id) ? (l || v) : (v || null);
    if (!reg) continue; // hewan lokal yang pemiliknya sudah dihapus di VPS
    const hh = (sumber === 'lokal' ? l : v) || l || v;
    const mau = Object.assign(pick(reg, PET_REG), pick(hh, PET_HARI_H));
    if (!l || !same(mau, l, cols)) pL.push(mau);
    if (!v || !same(mau, v, cols)) pV.push(mau);
  }
  if (pL.length) await upsert(LOCAL, 'pets', pL, 'id');
  if (pV.length) await upsert(VPS, 'pets', pV, 'id');

  // Nomor kedatangan dan panggilan: salin dari pemberi nomor ke yang lain.
  if (!sumber) return;
  const [S, T, tBase] = sumber === 'lokal' ? [L, V, VPS] : [V, L, LOCAL];
  const ccols = CHECKIN_COLS.split(',');
  const tC = new Map(T.checkins.map((c) => [c.owner_id, c]));
  const cKirim = S.checkins.filter((c) => !tC.has(c.owner_id) || !same(c, tC.get(c.owner_id), ccols));
  for (const c of cKirim) {
    try { await upsert(tBase, 'checkins', [c], 'owner_id,post'); }
    catch (e) {
      const k = 'Nomor ' + c.arrival_number + ' bentrok di ' + (sumber === 'lokal' ? 'VPS' : 'lokal') + ': ' + e.message.slice(0, 120);
      if (!state.konflik.includes(k)) { state.konflik.push(k); catat('KONFLIK ' + k); }
    }
  }
  const tPg = byId(T.panggilan, 'arrival_number');
  const pgKirim = S.panggilan.filter((p) => !tPg.has(p.arrival_number) || !same(p, tPg.get(p.arrival_number), ['called_at', 'jumlah']));
  if (pgKirim.length) await upsert(tBase, 'panggilan', pgKirim, 'arrival_number');
}

// Satu putaran pada satu waktu. Permintaan saat putaran berjalan menunggu
// putaran itu selesai lalu menjalankan putaran baru (data terbaru ikut).
let putaran = Promise.resolve();
function antrekan(fn) {
  const hasil = putaran.then(fn, fn);
  putaran = hasil.catch(() => {});
  return hasil;
}
const sinkron = () => antrekan(sinkronSekali);
async function sinkronSekali() {
  try {
    let L;
    try { L = await ambilSemua(LOCAL); state.lokal_ok = true; }
    catch (e) { state.lokal_ok = false; state.pesan = 'Database lokal tidak jalan: ' + e.message; return; }
    state.pemberi = L.hari.pemberi_nomor ? 'lokal' : null;
    let V;
    try { V = await ambilSemua(VPS); state.vps_ok = true; }
    catch (e) { state.vps_ok = false; state.pesan = 'Internet/VPS tidak terjangkau. Lokal tetap jalan.'; return; }
    if (!state.pemberi && V.hari.pemberi_nomor) state.pemberi = 'vps';
    // Cadangan online diaktifkan dari VPS saat lokal juga aktif: VPS menang,
    // lokal berhenti memberi nomor supaya tidak ada nomor ganda.
    if (L.hari.pemberi_nomor && V.hari.pemberi_nomor) {
      await api(LOCAL, '/rpc/serahkan', { method: 'POST', body: {} });
      state.pemberi = 'vps';
      catat('VPS sudah jadi pemberi nomor (cadangan diaktifkan). Lokal berhenti memberi nomor.');
      L = await ambilSemua(LOCAL);
    }
    await samakan(L, V, state.pemberi);
    await api(VPS, '/hari_h?id=eq.1', { method: 'PATCH', body: { lokal_terakhir: new Date().toISOString() }, headers: { Prefer: 'return=minimal' } });
    state.terakhir_sinkron = new Date().toISOString();
    state.pesan = 'Tersinkron dengan VPS';
  } catch (e) {
    state.pesan = 'Sinkron gagal: ' + e.message;
    catat(state.pesan);
  }
}

// Lokal jadi pemberi nomor. Normalnya VPS dihentikan dulu (serahkan), data
// terakhir ditarik, baru lokal mulai dari nomor tertinggi. paksa = VPS tidak
// terjangkau: lokal mulai dari nomor tertinggi yang diketahui + 10.
async function ambilAlih(paksa) {
  let lantai;
  try {
    const r = await api(VPS, '/rpc/serahkan', { method: 'POST', body: {} });
    const [L, V] = [await ambilSemua(LOCAL), await ambilSemua(VPS)];
    await samakan(L, V, 'vps');
    lantai = r.nomor_tertinggi;
  } catch (e) {
    if (!paksa) throw new Error('VPS tidak terjangkau (' + e.message + '). Pakai "Paksa ambil alih" kalau memang darurat.');
    const L = await ambilSemua(LOCAL);
    lantai = Math.max(0, ...L.checkins.map((c) => c.arrival_number || 0)) + 10;
    catat('Ambil alih PAKSA tanpa VPS, nomor dilanjutkan dari ' + (lantai + 1));
  }
  const r2 = await api(LOCAL, '/rpc/ambil_alih', { method: 'POST', body: { p_lantai: lantai } });
  state.pemberi = 'lokal';
  catat('Lokal jadi pemberi nomor, nomor berikutnya ' + (r2.lantai + 1) + ' atau lebih');
}

// Kembalikan pemberi nomor ke VPS secara terencana (misal Mac mau dimatikan).
async function serahkanKeVps() {
  const r = await api(LOCAL, '/rpc/serahkan', { method: 'POST', body: {} });
  const [L, V] = [await ambilSemua(LOCAL), await ambilSemua(VPS)];
  await samakan(L, V, 'lokal');
  await api(VPS, '/rpc/ambil_alih', { method: 'POST', body: { p_lantai: r.nomor_tertinggi } });
  state.pemberi = 'vps';
  catat('Pemberi nomor diserahkan ke VPS, lanjut dari ' + (r.nomor_tertinggi + 1));
}

// ---------- HTTP ----------
const TYPES = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css', '.svg': 'image/svg+xml', '.png': 'image/png', '.webp': 'image/webp', '.jpg': 'image/jpeg', '.ico': 'image/x-icon', '.json': 'application/json' };
function alamatLan() {
  return Object.values(os.networkInterfaces()).flat().filter((i) => i && i.family === 'IPv4' && !i.internal).map((i) => i.address);
}
function superadmin(req) {
  try { return jwt.verify(String(req.headers.authorization || '').replace(/^Bearer /, ''), SECRET).role === 'web_superadmin'; }
  catch (e) { return false; }
}
function kirimJson(res, code, obj) {
  res.writeHead(code, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(obj));
}
function bacaBody(req) {
  return new Promise((ok) => { let b = ''; req.on('data', (d) => { b += d; if (b.length > 2e6) req.destroy(); }); req.on('end', () => ok(b)); });
}

async function tangani(req, res) {
  const url = new URL(req.url, 'http://x');
  const p = decodeURIComponent(url.pathname);

  if (p.startsWith('/rest/')) {
    const body = ['GET', 'HEAD'].includes(req.method) ? undefined : await bacaBody(req);
    const headers = {};
    for (const h of ['authorization', 'content-type', 'prefer', 'accept', 'range']) if (req.headers[h]) headers[h] = req.headers[h];
    try {
      const r = await fetch(LOCAL + req.url.slice(5), { method: req.method, headers, body });
      const out = Buffer.from(await r.arrayBuffer());
      const h = { 'Content-Type': r.headers.get('content-type') || 'application/json', 'Cache-Control': 'no-store' };
      if (r.headers.get('content-range')) h['Content-Range'] = r.headers.get('content-range');
      res.writeHead(r.status, h);
      return res.end(out);
    } catch (e) {
      return kirimJson(res, 502, { message: 'Database lokal tidak menjawab: ' + e.message });
    }
  }
  if (p === '/api/login' && req.method === 'POST') {
    let body = {};
    try { body = JSON.parse(await bacaBody(req)); } catch (e) {}
    const r = { code: 200, status(c) { this.code = c; return this; }, json(o) { kirimJson(res, this.code, o); } };
    return loginHandler({ method: 'POST', body, headers: Object.assign({}, req.headers, { 'x-real-ip': req.socket.remoteAddress }) }, r);
  }
  if (p === '/api-config.js') {
    res.writeHead(200, { 'Content-Type': 'text/javascript', 'Cache-Control': 'no-store' });
    return res.end("window.PETBLESSING_API_URL = location.origin + '/rest';\nwindow.PB_SERVER = 'lokal';\n");
  }
  if (p === '/lokal/status') {
    return kirimJson(res, 200, Object.assign({}, state, { alamat: alamatLan() }));
  }
  if (p.startsWith('/lokal/') && req.method === 'POST') {
    if (!superadmin(req)) return kirimJson(res, 401, { error: 'Login superadmin dulu' });
    try {
      if (p === '/lokal/ambil-alih') { await antrekan(() => ambilAlih(url.searchParams.get('paksa') === '1')); await sinkron(); }
      else if (p === '/lokal/serahkan') await antrekan(serahkanKeVps);
      else if (p === '/lokal/sinkron') await sinkron();
      else if (p === '/lokal/hapus-konflik') state.konflik = [];
      else return kirimJson(res, 404, { error: 'tidak ada' });
      return kirimJson(res, 200, state);
    } catch (e) {
      return kirimJson(res, 500, { error: e.message });
    }
  }

  // File statis: hanya halaman dan aset di akar repo (bukan lokal/, api/, dst).
  let f = p === '/' ? '/kendali.html' : p;
  
  const full = path.join(ROOT, f);
  const boleh = full.startsWith(ROOT) && (/^\/[^/]+\.(html|js|css)$/.test(f) || f.startsWith('/assets/'));
  if (!boleh || !fs.existsSync(full) || fs.statSync(full).isDirectory()) { res.writeHead(404); return res.end('Tidak ada'); }
  res.writeHead(200, { 'Content-Type': TYPES[path.extname(full)] || 'application/octet-stream', 'Cache-Control': 'no-store' });
  fs.createReadStream(full).pipe(res);
}
const handler = (req, res) => tangani(req, res).catch((e) => { try { kirimJson(res, 500, { error: e.message }); } catch (_) {} });

https.createServer({ key: fs.readFileSync(path.join(DIR, 'data/key.pem')), cert: fs.readFileSync(path.join(DIR, 'data/cert.pem')) }, handler).listen(8443);
http.createServer(handler).listen(8080);
console.log('Server lokal Pet Blessing jalan. Buka di device lain:');
for (const ip of alamatLan()) console.log('  https://' + ip + ':8443/checkin.html   (kendali: https://' + ip + ':8443/)');
sinkron();
let antre = false;
setInterval(() => { if (antre) return; antre = true; sinkron().finally(() => { antre = false; }); }, SYNC_MS);
