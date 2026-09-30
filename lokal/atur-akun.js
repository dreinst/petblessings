// Mengatur akun login superadmin untuk server lokal (disimpan sebagai hash di lokal/.env).
//   node lokal/atur-akun.js
// Pakai username dan password yang sama dengan superadmin online supaya petugas tidak bingung.
const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');
const rl = require('readline').createInterface({ input: process.stdin, output: process.stdout });
const envPath = path.join(__dirname, '.env');

rl.question('Username superadmin: ', (user) => {
  rl.question('Password: ', (pw) => {
    rl.close();
    if (!user.trim() || pw.length < 6) { console.log('Username wajib, password minimal 6 karakter.'); process.exit(1); }
    const env = fs.readFileSync(envPath, 'utf8').split('\n').filter((l) => l.trim() && !/^SUPERADMIN_(USERNAME|PASSWORD_HASH)=/.test(l));
    env.push('SUPERADMIN_USERNAME=' + user.trim(), 'SUPERADMIN_PASSWORD_HASH=' + bcrypt.hashSync(pw, 10));
    fs.writeFileSync(envPath, env.join('\n') + '\n', { mode: 0o600 });
    console.log('Akun disimpan. Restart server.js supaya berlaku.');
  });
});
