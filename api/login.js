const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');

// Login panitia untuk halaman rekap (pendaftaran-masuk.html) dan check-in
// (checkin.html). Dua akun, keduanya dari environment variable Vercel:
//   admin      -> PANITIA_USERNAME / PANITIA_PASSWORD_HASH
//                 boleh buka rekap, ubah data pendaftaran, lihat bukti transfer,
//                 tapi tiap login harus disetujui superadmin dulu
//   superadmin -> SUPERADMIN_USERNAME / SUPERADMIN_PASSWORD_HASH
//                 semua hak admin + halaman check-in + log login
// Setiap login dicatat di api.admin_sessions (perangkat, IP, waktu). JWT
// memuat klaim role (nama role Postgres untuk PostgREST, lihat
// vps-db/init/06-roles.sql dan 08-admin-sessions.sql), level (untuk
// tampilan), dan sid (id baris log; policy web_admin hanya lolos kalau
// sesi itu sudah disetujui).
var ACCOUNTS = [
  { level: 'superadmin', role: 'web_superadmin', userEnv: 'SUPERADMIN_USERNAME', hashEnv: 'SUPERADMIN_PASSWORD_HASH' },
  { level: 'admin',      role: 'web_admin',      userEnv: 'PANITIA_USERNAME',    hashEnv: 'PANITIA_PASSWORD_HASH' },
];

// Masa berlaku login. Superadmin tidak dibatasi 12 jam lagi (permintaan panitia, 4 Okt 2026):
// 30 hari, dan diperpanjang otomatis tiap halaman hari-H dibuka (lihat "perpanjang" di bawah).
var UMUR_LOGIN = { superadmin: '30d', admin: '12h' };

// Nama perangkat singkat dari user agent, cukup untuk dikenali pemiliknya
// (konsep "find my device"), bukan sidik jari lengkap.
function describeDevice(ua) {
  ua = ua || '';
  var os = /iPhone/.test(ua) ? 'iPhone'
    : /iPad/.test(ua) ? 'iPad'
    : /Android/.test(ua) ? 'Android'
    : /Windows/.test(ua) ? 'Windows'
    : /Macintosh|Mac OS X/.test(ua) ? 'Mac'
    : /CrOS/.test(ua) ? 'Chromebook'
    : /Linux/.test(ua) ? 'Linux'
    : 'Perangkat lain';
  var model = ua.match(/Android [^;)]+; ([^;)]*?)(?: Build\/| Build|[;)])/);
  if (os === 'Android' && model) os = 'Android ' + model[1].trim();
  var br = /Edg(e|A|iOS)?\//.test(ua) ? 'Edge'
    : /OPR\/|Opera/.test(ua) ? 'Opera'
    : /FxiOS|Firefox\//.test(ua) ? 'Firefox'
    : /CriOS|Chrome\//.test(ua) ? 'Chrome'
    : /Safari\//.test(ua) ? 'Safari'
    : 'browser lain';
  if (/\bwv\b/.test(ua)) br += ' (WebView)';
  return os + ' · ' + br;
}

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  var body = req.body || {};

  // Perpanjang login superadmin tanpa mengetik ulang password (dipanggil hari-h.js tiap halaman
  // dibuka). Token superadmin yang masih berlaku ditukar dengan token baru, supaya login tidak
  // habis di tengah acara.
  if (body.perpanjang) {
    var lama = null;
    try {
      lama = jwt.verify(String((req.headers || {}).authorization || '').replace(/^Bearer /, ''), process.env.PGRST_JWT_SECRET);
    } catch (e) {}
    if (!lama || lama.role !== 'web_superadmin' || lama.level !== 'superadmin') {
      res.status(401).json({ error: 'Login dulu' });
      return;
    }
    res.status(200).json({
      token: jwt.sign({ role: lama.role, level: lama.level, sid: lama.sid }, process.env.PGRST_JWT_SECRET, { expiresIn: UMUR_LOGIN.superadmin }),
      level: lama.level,
    });
    return;
  }

  var username = body.username;
  var password = body.password;

  if (!username || !password) {
    res.status(400).json({ error: 'Username dan password wajib diisi' });
    return;
  }

  var jwtSecret = process.env.PGRST_JWT_SECRET;
  var apiUrl = process.env.PETBLESSING_API_URL;
  if (!jwtSecret || !apiUrl) {
    res.status(500).json({ error: 'Login belum dikonfigurasi di server' });
    return;
  }

  var account = null;
  for (var i = 0; i < ACCOUNTS.length; i++) {
    var a = ACCOUNTS[i];
    if (process.env[a.userEnv] && username === process.env[a.userEnv]) { account = a; break; }
  }
  var hash = account ? process.env[account.hashEnv] : null;
  var ok = !!hash && await bcrypt.compare(password, hash);
  if (!ok) {
    res.status(401).json({ error: 'Username atau password salah' });
    return;
  }

  var sid = crypto.randomUUID();
  var userAgent = String(req.headers['user-agent'] || '').slice(0, 500);
  var device = describeDevice(userAgent);
  var ip = String(req.headers['x-forwarded-for'] || req.headers['x-real-ip'] || '').split(',')[0].trim() || null;
  var status = account.level === 'superadmin' ? 'approved' : 'pending';

  try {
    var serviceToken = jwt.sign({ role: 'web_superadmin' }, jwtSecret, { expiresIn: '2m' });
    var r = await fetch(apiUrl + '/admin_sessions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Prefer': 'return=minimal', 'Authorization': 'Bearer ' + serviceToken },
      body: JSON.stringify({ id: sid, level: account.level, device: device, user_agent: userAgent, ip: ip, status: status, decided_at: status === 'approved' ? new Date().toISOString() : null }),
    });
    if (!r.ok) throw new Error('admin_sessions ' + r.status);
  } catch (e) {
    console.error('login log failed', e.message);
    res.status(500).json({ error: 'Gagal mencatat login, coba lagi sebentar lagi' });
    return;
  }

  var token = jwt.sign({ role: account.role, level: account.level, sid: sid }, jwtSecret, { expiresIn: UMUR_LOGIN[account.level] });
  res.status(200).json({ token: token, level: account.level, status: status, device: device, ip: ip });
};
