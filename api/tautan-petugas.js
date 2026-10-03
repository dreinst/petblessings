const jwt = require('jsonwebtoken');

// Tautan tanpa login untuk petugas pos reg ulang dan goodie bag.
// Hanya superadmin yang bisa memintanya (halaman kendali). Token yang dikembalikan
// ditempel di belakang alamat halaman ("checkin.html?meja=A#kunci=<token>"), jadi petugas
// cukup membuka tautan itu. Token memakai peran database web_petugas
// (vps-db/init/30-petugas-pos.sql): cukup untuk scan, memberi nomor urut, dan mencatat
// goodie bag, tanpa akses ke rekap, bukti transfer, atau hapus data.
// Dipakai di Vercel dan di server lokal (lokal/server.js meneruskan ke berkas ini).
var UMUR_JAM = 20;

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
  if (!klaim || klaim.role !== 'web_superadmin') {
    res.status(401).json({ error: 'Login superadmin dulu' });
    return;
  }
  // noTimestamp: token lebih pendek, jadi QR tautannya lebih mudah discan.
  var token = jwt.sign({ role: 'web_petugas', level: 'petugas' }, secret, { expiresIn: UMUR_JAM + 'h', noTimestamp: true });
  res.status(200).json({ token: token, berlaku_sampai: new Date(Date.now() + UMUR_JAM * 3600 * 1000).toISOString() });
};
