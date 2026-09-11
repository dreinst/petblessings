const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');

// Login panitia untuk halaman pendaftaran-masuk.html.
// Kredensial dicek dari environment variable Vercel (PANITIA_USERNAME,
// PANITIA_PASSWORD_HASH), bukan dari database -- cukup untuk skala
// beberapa akun panitia. Berhasil login -> JWT dengan klaim role
// "web_panitia", dipakai PostgREST (lihat vps-db/init.sql) untuk
// mengizinkan SELECT ke tabel owners/pets.
module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  var body = req.body || {};
  var username = body.username;
  var password = body.password;

  if (!username || !password) {
    res.status(400).json({ error: 'Username dan password wajib diisi' });
    return;
  }

  var expectedUsername = process.env.PANITIA_USERNAME;
  var expectedHash = process.env.PANITIA_PASSWORD_HASH;
  var jwtSecret = process.env.PGRST_JWT_SECRET;

  if (!expectedUsername || !expectedHash || !jwtSecret) {
    res.status(500).json({ error: 'Login belum dikonfigurasi di server' });
    return;
  }

  if (username !== expectedUsername) {
    res.status(401).json({ error: 'Username atau password salah' });
    return;
  }

  var ok = await bcrypt.compare(password, expectedHash);
  if (!ok) {
    res.status(401).json({ error: 'Username atau password salah' });
    return;
  }

  var token = jwt.sign({ role: 'web_panitia' }, jwtSecret, { expiresIn: '12h' });
  res.status(200).json({ token: token });
};
