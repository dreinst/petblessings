const jwt = require('jsonwebtoken');

// Token petugas untuk halaman pos reg ulang dan goodie bag (checkin.html, goodie.html).
// Token memakai peran database web_petugas (vps-db/init/30-petugas-pos.sql dan 32): cukup
// untuk scan, memberi nomor urut, dan mencatat goodie bag, tanpa akses ke rekap, nomor HP,
// bukti transfer, atau hapus data. Dipakai di Vercel dan di server lokal (lokal/server.js
// meneruskan ke berkas ini).
//
// Dua jalan mendapat token:
// 1. Superadmin (Bearer token superadmin), kapan saja. Dipakai halaman kendali untuk
//    membuat tautan "checkin.html?meja=A#kunci=<token>" yang berlaku 20 jam.
// 2. Tanpa login selama "pintu pos" terbuka (jam acara). Halaman pos dan goodie bag
//    memintanya sendiri saat dibuka, jadi petugas cukup membuka alamat atau QR-nya.
//    Token ini berakhir satu jam setelah pintu tutup. Pintu ditutup lebih cepat dengan
//    PINTU_POS=tutup: di server lokal lewat tombol di halaman kendali, di Vercel lewat
//    variabel lingkungan.
var UMUR_JAM = 20;
var PINTU_BUKA = '2026-10-04T00:00:00+07:00';
var PINTU_TUTUP = '2026-10-04T17:00:00+07:00';

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }
  var secret = process.env.PGRST_JWT_SECRET;
  if (!secret) {
    res.status(500).json({ error: 'Server belum dikonfigurasi lengkap' });
    return;
  }
  var klaim = null;
  try {
    klaim = jwt.verify(String((req.headers || {}).authorization || '').replace(/^Bearer /, ''), secret);
  } catch (e) {}
  var superadmin = !!klaim && klaim.role === 'web_superadmin';

  var kini = Date.now();
  var buka = Date.parse(process.env.PINTU_POS_BUKA || PINTU_BUKA);
  var tutup = Date.parse(process.env.PINTU_POS_TUTUP || PINTU_TUTUP);
  var pintuTerbuka = process.env.PINTU_POS !== 'tutup' && kini >= buka && kini < tutup;
  if (!superadmin && !pintuTerbuka) {
    res.status(401).json({ error: 'Login superadmin dulu' });
    return;
  }

  var sampai = superadmin ? kini + UMUR_JAM * 3600 * 1000 : tutup + 3600 * 1000;
  // noTimestamp: token lebih pendek, jadi QR tautannya lebih mudah discan.
  var token = jwt.sign({ role: 'web_petugas', level: 'petugas', exp: Math.floor(sampai / 1000) }, secret, { noTimestamp: true });
  res.status(200).json({ token: token, berlaku_sampai: new Date(sampai).toISOString() });
};
