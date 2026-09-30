// Uji penomoran kedatangan + sinkron lokal <-> VPS tiruan.
//   node lokal/uji/uji-hari-h.js
// Butuh: VPS tiruan (siapkan-vps-tiruan.sh), server lokal (siapkan.sh), dan
// node lokal/server.js sedang jalan. Mengubah data di KEDUA database uji.
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const ROOT = path.join(__dirname, '../..');
const jwt = require(path.join(ROOT, 'node_modules/jsonwebtoken'));
const env = Object.fromEntries(fs.readFileSync(path.join(__dirname, '../.env'), 'utf8').split('\n').filter(Boolean).map((l) => [l.split('=')[0], l.slice(l.indexOf('=') + 1)]));
if (!/127\.0\.0\.1/.test(env.VPS_API_URL)) { console.error('lokal/.env tidak menunjuk VPS tiruan, uji dibatalkan'); process.exit(1); }
const TOKEN = jwt.sign({ role: 'web_superadmin', level: 'superadmin' }, env.JWT_SECRET);
const LOKAL = 'http://127.0.0.1:8080/rest';
const VPS = env.VPS_API_URL;
const SERVER = 'http://127.0.0.1:8080';

let lulus = 0, gagal = 0;
function cek(ok, nama, info) {
  if (ok) { lulus++; console.log('  ok   ' + nama); }
  else { gagal++; console.log('  GAGAL ' + nama + (info !== undefined ? '  -> ' + JSON.stringify(info) : '')); }
}
async function call(base, p, body, method) {
  const r = await fetch(base + p, {
    method: method || (body ? 'POST' : 'GET'),
    headers: { Authorization: 'Bearer ' + TOKEN, 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  const t = await r.text();
  return { status: r.status, data: t ? JSON.parse(t) : null };
}
const rpc = (base, fn, body) => call(base, '/rpc/' + fn, body || {});
const tunggu = (ms) => new Promise((r) => setTimeout(r, ms));
const psql = (db, sql) => execSync(`docker exec ${db} psql -U petblessing -d petblessing -Atc "${sql}"`).toString().trim();
const sinkronSekarang = () => call(SERVER, '/lokal/sinkron', {});

(async () => {
  console.log('Persiapan: kosongkan data hari-H di dua database');
  for (const db of ['pblokal-db', 'pbuji-vps-db']) {
    psql(db, "delete from api.panggilan; delete from api.checkins; delete from api.owners where is_walkin; update api.pets set hadir = null; update api.hari_h set pemberi_nomor = " + (db === 'pbuji-vps-db') + ", lantai = 0");
  }
  await sinkronSekarang();
  const owners = (await call(LOKAL, '/owners?select=id,queue_number,is_test,pets(id,sticker_letter)&is_test=eq.false&order=queue_number')).data;
  cek(owners.length === 37, '37 pemilik asli tersalin ke lokal', owners.length);

  console.log('1. Sebelum ambil alih, lokal menolak memberi nomor');
  let r = await rpc(LOKAL, 'reg_ulang', { p_owner: owners[0].id, p_desk: 'A' });
  cek(r.status >= 400 && /tidak memberi nomor/.test(r.data.message), 'lokal menolak', r);

  console.log('2. Ambil alih: lokal jadi pemberi nomor, VPS berhenti');
  r = await call(SERVER, '/lokal/ambil-alih', {});
  cek(r.status === 200, 'ambil alih berhasil', r.data);
  r = await rpc(VPS, 'reg_ulang', { p_owner: owners[0].id, p_desk: 'A' });
  cek(r.status >= 400, 'VPS sekarang menolak', r.status);

  console.log('3. Dua meja reg ulang 20 pemilik bersamaan');
  const hasil = await Promise.all(owners.slice(0, 20).map((o, i) => rpc(LOKAL, 'reg_ulang', { p_owner: o.id, p_desk: i % 2 ? 'B' : 'A' })));
  const nomor = hasil.map((h) => h.data.nomor).sort((a, b) => a - b);
  cek(hasil.every((h) => h.status === 200 && h.data.status === 'baru'), 'semua dapat nomor baru');
  cek(JSON.stringify(nomor) === JSON.stringify([...Array(20)].map((_, i) => i + 1)), 'nomor 1 sampai 20 tanpa ganda dan tanpa lompat', nomor);

  console.log('4. Scan ulang orang yang sama');
  r = await rpc(LOKAL, 'reg_ulang', { p_owner: owners[0].id, p_desk: 'B' });
  cek(r.data.status === 'sudah' && r.data.nomor === hasil[0].data.nomor, 'nomor lama dikembalikan, tidak ada nomor baru', r.data);

  console.log('5. Hewan yang tidak dibawa');
  const multi = owners.slice(20).find((o) => o.pets.length >= 2);
  r = await rpc(LOKAL, 'reg_ulang', { p_owner: multi.id, p_desk: 'A', p_hadir: [multi.pets[0].id] });
  cek(r.data.nomor === 21, 'dapat nomor 21', r.data);
  const hadir = (await call(LOKAL, '/pets?owner_id=eq.' + multi.id + '&select=id,hadir')).data;
  cek(hadir.filter((p) => p.hadir).length === 1 && hadir.filter((p) => p.hadir === false).length === multi.pets.length - 1, 'hanya hewan yang dicentang tercatat hadir', hadir);

  console.log('6. Walk-in');
  r = await rpc(LOKAL, 'walkin', { p_name: 'Bu Walkin', p_phone: '0813', p_umat: 'bukan', p_pets: [{ name: 'Mochi', type: 'Kucing' }, { name: 'Boba', type: 'Anjing' }], p_desk: 'B' });
  cek(r.status === 200 && r.data.nomor === 22, 'walk-in dapat nomor 22', r.data);
  const wpets = (await call(LOKAL, '/pets?owner_id=eq.' + r.data.owner_id + '&select=name,sticker_letter&order=sticker_letter')).data;
  cek(wpets.map((p) => p.sticker_letter).join('') === 'AB', 'hewan walk-in dapat huruf A dan B', wpets);
  const walkinId = r.data.owner_id;
  // Pemilik yang belum dipakai di langkah sebelumnya.
  const bebas = owners.slice(20).filter((o) => o.id !== multi.id);

  console.log('7. Sinkron ke VPS');
  await sinkronSekarang();
  const vpsC = psql('pbuji-vps-db', "select count(*), max(arrival_number) from api.checkins where post='reg_ulang'");
  cek(vpsC === '22|22', 'VPS punya 22 nomor yang sama', vpsC);
  cek(psql('pbuji-vps-db', "select count(*) from api.owners where id='" + walkinId + "'") === '1', 'walk-in ikut masuk VPS');
  cek(psql('pbuji-vps-db', "select count(*) from api.pets where owner_id='" + multi.id + "' and hadir is false") === String(multi.pets.length - 1), 'status hewan tidak hadir ikut ke VPS');

  console.log('8. Panggilan ruang tunggu');
  r = await rpc(LOKAL, 'panggil', {});
  cek(r.data.nomor === 1, 'panggil berikutnya = 1', r.data);
  r = await rpc(LOKAL, 'panggil', {});
  cek(r.data.nomor === 2, 'panggil berikutnya = 2', r.data);
  r = await rpc(LOKAL, 'panggil', { p_nomor: 1 });
  cek(r.data.nomor === 1, 'panggil ulang nomor 1', r.data);
  const st = (await rpc(LOKAL, 'hari_h_status', {})).data;
  cek(st.dipanggil.nomor === 1 && st.menunggu[0].nomor === 3 && st.hadir === 22, 'status: sedang dipanggil 1, berikutnya 3, hadir 22', { d: st.dipanggil && st.dipanggil.nomor, m: st.menunggu[0], h: st.hadir });
  await sinkronSekarang();
  cek(psql('pbuji-vps-db', 'select string_agg(arrival_number||\':\'||jumlah, \',\' order by arrival_number) from api.panggilan') === '1:2,2:1', 'panggilan ikut ke VPS');

  console.log('9. Internet putus: lokal tetap jalan');
  execSync('docker stop pbuji-vps-api', { stdio: 'ignore' });
  r = await rpc(LOKAL, 'reg_ulang', { p_owner: bebas[0].id, p_desk: 'A' });
  cek(r.data.nomor === 23, 'reg ulang tetap jalan saat VPS putus (nomor 23)', r.data);
  await sinkronSekarang();
  const s1 = (await call(SERVER, '/lokal/status')).data;
  cek(s1.vps_ok === false && s1.pemberi === 'lokal', 'status: VPS tidak terjangkau, lokal tetap pemberi nomor', s1);
  execSync('docker start pbuji-vps-api', { stdio: 'ignore' });
  await tunggu(3000);
  await sinkronSekarang();
  cek(psql('pbuji-vps-db', "select max(arrival_number) from api.checkins") === '23', 'setelah internet kembali, nomor 23 terkirim ke VPS');

  console.log('10. Mac mati, cadangan online diaktifkan dari VPS (+10)');
  // Nomor 24 dibuat di lokal tapi belum sempat tersinkron ketika "Mac mati".
  r = await rpc(LOKAL, 'reg_ulang', { p_owner: bebas[1].id, p_desk: 'A' });
  cek(r.data.nomor === 24, 'nomor 24 di lokal, belum tersinkron');
  const maxVps = Number(psql('pbuji-vps-db', "select max(arrival_number) from api.checkins"));
  r = await rpc(VPS, 'ambil_alih', { p_lantai: maxVps + 10 });
  cek(r.status === 200 && r.data.lantai === 33, 'VPS jadi pemberi nomor, lantai 33', r.data);
  r = await rpc(VPS, 'reg_ulang', { p_owner: bebas[2].id, p_desk: 'A' });
  cek(r.data.nomor === 34, 'nomor berikutnya di VPS 34 (tidak bentrok dengan 24 yang belum tersinkron)', r.data);

  console.log('11. Mac hidup lagi: lokal melihat VPS pemberi nomor, lokal berhenti');
  await sinkronSekarang();
  const s2 = (await call(SERVER, '/lokal/status')).data;
  cek(s2.pemberi === 'vps', 'lokal tahu VPS pemberi nomor', s2.pemberi);
  r = await rpc(LOKAL, 'reg_ulang', { p_owner: bebas[3].id, p_desk: 'A' });
  cek(r.status >= 400, 'lokal menolak memberi nomor', r.status);
  await sinkronSekarang();
  cek(psql('pblokal-db', "select count(*) from api.checkins where arrival_number=34") === '1', 'nomor 34 dari VPS tersalin ke lokal');
  cek(psql('pbuji-vps-db', "select count(*) from api.checkins where arrival_number=24") === '0', 'nomor 24 lokal belum di VPS (lokal bukan sumber)');

  console.log('12. Kembali ke lokal');
  r = await call(SERVER, '/lokal/ambil-alih', {});
  cek(r.status === 200, 'ambil alih lagi', r.data);
  r = await rpc(LOKAL, 'reg_ulang', { p_owner: bebas[3].id, p_desk: 'B' });
  cek(r.data.nomor === 35, 'lanjut dari 35', r.data);
  await sinkronSekarang();
  cek(psql('pbuji-vps-db', "select string_agg(arrival_number::text, ',' order by arrival_number) from api.checkins where arrival_number > 22") === '23,24,34,35', 'VPS akhirnya punya 24 juga, semua nomor unik', psql('pbuji-vps-db', "select string_agg(arrival_number::text, ',' order by arrival_number) from api.checkins where arrival_number > 22"));
  const st2 = (await rpc(LOKAL, 'hari_h_status', {})).data;
  cek(st2.menunggu.map((m) => m.nomor).join(',').includes('24,34,35'), 'daftar tunggu melompati nomor 25 sampai 33 yang tidak dipakai');

  console.log('13. Data uji terpisah dari data asli');
  const tes = (await call(LOKAL, '/owners?is_test=eq.true&select=id&limit=1')).data[0];
  r = await rpc(LOKAL, 'reg_ulang', { p_owner: tes.id, p_desk: 'A' });
  const stU = (await rpc(LOKAL, 'hari_h_status', { p_uji: true })).data;
  const stA = (await rpc(LOKAL, 'hari_h_status', {})).data;
  cek(stU.hadir === 1 && stA.hadir === 26, 'monitor uji hanya menghitung data uji', { u: stU.hadir, a: stA.hadir });
  r = await rpc(LOKAL, 'panggil', {});
  cek(r.data.nomor === 3, 'panggilan data asli tidak mengambil nomor data uji', r.data);

  console.log('\n' + lulus + ' lulus, ' + gagal + ' gagal');
  process.exit(gagal ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
