const { default: makeWASocket, useMultiFileAuthState, DisconnectReason, fetchLatestBaileysVersion } = require('@whiskeysockets/baileys');
const { Boom } = require('@hapi/boom');
const qrcodeTerminal = require('qrcode-terminal');
const QRCode = require('qrcode');
const { Pool } = require('pg');
const pino = require('pino');

const logger = pino({ level: process.env.LOG_LEVEL || 'info' });

const pool = new Pool({
  host: process.env.PGHOST || 'db',
  port: Number(process.env.PGPORT || 5432),
  database: process.env.PGDATABASE || 'petblessing',
  user: process.env.PGUSER || 'wa_worker',
  password: process.env.PGPASSWORD,
});

// Banyak variasi caption + potongan sapaan/penutup yang dikombinasikan acak,
// supaya tidak ada dua pesan yang identik persis -- baik dari sisi pola kalimat
// maupun byte teksnya sendiri.
// Sapaan netral saja, tanpa 'Selamat siang/malam': bot kirim dengan delay
// acak, jadi sapaan berdasarkan waktu bisa meleset dari jam pesan terkirim.
const GREETINGS = ['Halo', 'Hai', 'Hai halo', 'Halo halo'];
const CLOSERS = [
  'Terima kasih sudah mendaftar 🙏',
  'Sampai ketemu di acaranya ya 🐾',
  'Ditunggu kedatangannya!',
  'Terima kasih ya 🙏',
  '',
];
const EMOJI_SETS = ['🐾', '🐶🐱', '✅', '👋', ''];

// Kontak panitia, disisipkan di setiap blast supaya pendaftar yang butuh bantuan
// tidak membalas ke nomor ini (nomor ini cuma untuk kirim, bukan tanya jawab).
const COMMITTEE_CONTACTS = [
  { name: 'Lala', phone: '6281234320977' },
  { name: 'Livvy', phone: '6281130588892' },
];

function committeeContactBlock() {
  var lines = COMMITTEE_CONTACTS.map(function (c) {
    return '- ' + c.name + ': https://wa.me/' + c.phone;
  });
  return 'Ada kendala atau pertanyaan seputar pendaftaran? Hubungi panitia:\n' + lines.join('\n');
}

const CAPTION_TEMPLATES = [
  (name, code, g, c, e) => `${g} ${name} ${e}\n\nIni QR bukti pendaftaran Pet Blessing 2026 kamu.\nKode: *${code}*\n\nSimpan gambar ini, nanti ditunjukkan ke panitia saat reg ulang di lokasi acara ya.${c ? '\n\n' + c : ''}`,
  (name, code, g, c, e) => `${g} ${name}! ${e}\n\nBerikut QR pendaftaran Pet Blessing 2026 kamu (kode ${code}). Mohon disimpan untuk ditunjukkan saat check-in di hari acara.${c ? '\n' + c : ''}`,
  (name, code, g, c, e) => `${g} ${name},\n\nPendaftaran Pet Blessing 2026 kamu sudah tercatat. QR di atas adalah bukti pendaftaran, kode: ${code}.\nJangan lupa dibawa/ditunjukkan pas reg ulang di lokasi ya${e ? ' ' + e : ''}`,
  (name, code, g, c, e) => `${g} ${name} ${e}\n\nQR ini bukti kamu sudah terdaftar di Pet Blessing 2026 (kode: ${code}). Simpan baik-baik dan tunjukkan ke panitia saat kedatangan.${c ? '\n\n' + c : ''}`,
  (name, code, g, c, e) => `${name}, pendaftaran Pet Blessing 2026 kamu berhasil ${e}\n\nKode pendaftaran: ${code}\nQR di atas mewakili kamu dan semua hewan yang didaftarkan.${c ? '\n' + c : ''}`,
];

function pick(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function buildCaption(name, code, queueNumber) {
  var template = pick(CAPTION_TEMPLATES);
  var text = template(name, code, pick(GREETINGS), pick(CLOSERS), pick(EMOJI_SETS));
  if (queueNumber) {
    text += `\n\nNomor pendaftaran: *${queueNumber}*\nNomor urut pemberkatan dibagikan saat reg ulang di lokasi, sesuai urutan kedatangan.`;
  }
  text += '\n\n' + committeeContactBlock();
  // Variasi kecil whitespace di akhir, supaya byte teks tidak pernah identik
  // persis walau template & isi kebetulan sama.
  return text + (Math.random() < 0.5 ? ' ' : '');
}

// Caption koreksi: dipakai saat pendaftaran ganda digabung dan pendaftar perlu
// tahu QR mana yang berlaku di hari H (QR lama, dari data yang dihapus, sudah
// tidak valid). Pola kalimat & sisipan sama seperti CAPTION_TEMPLATES supaya
// gaya bahasanya konsisten dengan blast biasa.
const CORRECTION_CAPTION_TEMPLATES = [
  (name, code, g, c, e) => `${g} ${name} ${e}\n\nAda sedikit koreksi data pendaftaran Pet Blessing 2026 kamu, jadi ini kami kirim ulang QR-nya.\n\n*Ini QR yang fix* (kode: ${code}). Saat hari H, pakai QR ini untuk reg ulang ya, bukan yang dikirim sebelumnya.${c ? '\n\n' + c : ''}`,
  (name, code, g, c, e) => `${g} ${name}! ${e}\n\nData pendaftaran Pet Blessing 2026 kamu barusan kami rapikan, jadi QR-nya kami kirim ulang.\n\nQR ini yang fix (kode ${code}) -- saat hari H, ini yang dipakai untuk reg ulang.${c ? '\n' + c : ''}`,
];

function buildCorrectionCaption(name, code, queueNumber) {
  var template = pick(CORRECTION_CAPTION_TEMPLATES);
  var text = template(name, code, pick(GREETINGS), pick(CLOSERS), pick(EMOJI_SETS));
  if (queueNumber) {
    text += `\n\nNomor pendaftaran: *${queueNumber}*\nNomor urut pemberkatan dibagikan saat reg ulang di lokasi, sesuai urutan kedatangan.`;
  }
  text += '\n\n' + committeeContactBlock();
  return text + (Math.random() < 0.5 ? ' ' : '');
}

const SHORT_INTROS = [
  'QR pendaftaran kamu ya, ditunggu di acaranya 🙏',
  'Ini QR bukti pendaftaran kamu.',
  'Berikut QR-nya, disimpan ya.',
];

function randomBetween(minMs, maxMs) {
  return Math.floor(Math.random() * (maxMs - minMs + 1)) + minMs;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function normalizePhone(raw) {
  var digits = String(raw || '').replace(/\D/g, '');
  if (digits.startsWith('0')) digits = '62' + digits.slice(1);
  else if (!digits.startsWith('62')) digits = '62' + digits;
  return digits + '@s.whatsapp.net';
}

async function fetchNextPending() {
  var res = await pool.query(
    `select * from api.wa_queue where status = 'pending' and attempts < 3 order by created_at asc limit 1`
  );
  return res.rows[0] || null;
}

async function markSent(id) {
  await pool.query(`update api.wa_queue set status = 'sent', sent_at = now() where id = $1`, [id]);
}

async function markAttemptFailed(id, attempts, errMessage) {
  var status = attempts + 1 >= 3 ? 'failed' : 'pending';
  await pool.query(
    `update api.wa_queue set attempts = $2, status = $3, error = $4 where id = $1`,
    [id, attempts + 1, status, errMessage]
  );
}

async function fetchNextCorrection() {
  var res = await pool.query(
    `select * from api.wa_correction_queue where status = 'pending' and attempts < 3 order by created_at asc limit 1`
  );
  return res.rows[0] || null;
}

async function markCorrectionSent(id) {
  await pool.query(`update api.wa_correction_queue set status = 'sent', sent_at = now() where id = $1`, [id]);
}

async function markCorrectionAttemptFailed(id, attempts, errMessage) {
  var status = attempts + 1 >= 3 ? 'failed' : 'pending';
  await pool.query(
    `update api.wa_correction_queue set attempts = $2, status = $3, error = $4 where id = $1`,
    [id, attempts + 1, status, errMessage]
  );
}

async function sendCorrection(sock, row) {
  var jid = normalizePhone(row.phone);
  var queueNumber = await fetchQueueNumber(row.owner_id);
  var caption = buildCorrectionCaption(row.owner_name, row.short_code, queueNumber);

  var base64 = row.qr_image_base64.replace(/^data:image\/\w+;base64,/, '');
  var buffer = Buffer.from(base64, 'base64');
  var fileName = `QR-PetBlessing-${row.short_code}.png`;

  await typingPause(sock, jid);
  await sock.sendMessage(jid, {
    document: buffer,
    mimetype: 'image/png',
    fileName: fileName,
    caption: caption,
  });
}

// Antrian susulan: pesan singkat berisi info kontak panitia saja (tanpa QR ulang),
// dipakai sekali untuk pendaftar yang sudah menerima blast QR sebelum info kontak
// ditambahkan ke caption utama.
const FOLLOWUP_INTROS = [
  'Ada info tambahan untuk pendaftaran Pet Blessing 2026 kamu.',
  'Sedikit tambahan info untuk pendaftaran Pet Blessing 2026 kamu kemarin.',
  'Menyusul info untuk pendaftaran Pet Blessing 2026 kamu.',
];

function buildFollowupCaption(name) {
  var greeting = pick(GREETINGS) + ' ' + name + ',';
  var intro = pick(FOLLOWUP_INTROS);
  var text = greeting + '\n\n' + intro + '\n\n' + committeeContactBlock();
  return text + (Math.random() < 0.5 ? ' ' : '');
}

async function fetchNextFollowup() {
  var res = await pool.query(
    `select * from api.wa_followup_queue where status = 'pending' and attempts < 3 order by created_at asc limit 1`
  );
  return res.rows[0] || null;
}

async function markFollowupSent(id) {
  await pool.query(`update api.wa_followup_queue set status = 'sent', sent_at = now() where id = $1`, [id]);
}

async function markFollowupAttemptFailed(id, attempts, errMessage) {
  var status = attempts + 1 >= 3 ? 'failed' : 'pending';
  await pool.query(
    `update api.wa_followup_queue set attempts = $2, status = $3, error = $4 where id = $1`,
    [id, attempts + 1, status, errMessage]
  );
}

// Info nomor urut (30 Sep 2026): pendaftar lama menerima teks "Nomor urut
// pendaftaran ... cocokkan dengan stiker". Sekarang nomor urut = urutan
// kedatangan saat reg ulang, jadi mereka dikabari sekali.
const INFO_NOMOR_TEMPLATES = [
  (name, e) => `Halo ${name} ${e}\n\nTerima kasih sudah mendaftar Pet Blessing 2026. Ada info kecil soal nomor ya.\n\nNomor di pesan QR sebelumnya adalah nomor pendaftaran, bukan nomor urut pemberkatan. Nomor urut akan dibagikan saat reg ulang di lokasi, sesuai urutan kedatangan. Jadi yang datang lebih awal akan dipanggil lebih dulu.\n\nCukup bawa QR yang sudah kami kirim dan tunjukkan di meja reg ulang. Sampai jumpa hari Minggu, 4 Oktober!`,
  (name, e) => `Hai ${name} ${e}\n\nSedikit info untuk Pet Blessing 2026 hari Minggu, 4 Oktober: nomor di pesan QR kamu sebelumnya adalah nomor pendaftaran. Nomor urut pemberkatan dibagikan saat reg ulang di lokasi, urut sesuai kedatangan.\n\nJadi cukup datang dan tunjukkan QR yang sudah kami kirim di meja reg ulang ya. Sampai ketemu!`,
  (name, e) => `Halo ${name}! ${e}\n\nMenjelang Pet Blessing 2026 (Minggu, 4 Oktober), kami mau kabari: nomor urut pemberkatan akan dibagikan saat reg ulang di lokasi sesuai urutan kedatangan. Nomor di pesan QR sebelumnya adalah nomor pendaftaran saja.\n\nBawa QR yang sudah kami kirim dan tunjukkan di meja reg ulang ya. Terima kasih!`,
];

async function sendFollowup(sock, row) {
  var jid = normalizePhone(row.phone);
  var caption = row.pesan ? row.pesan : row.jenis === 'info_nomor'
    ? pick(INFO_NOMOR_TEMPLATES)(row.owner_name, pick(EMOJI_SETS)) + (Math.random() < 0.5 ? ' ' : '')
    : buildFollowupCaption(row.owner_name);
  await typingPause(sock, jid);
  await sock.sendMessage(jid, { text: caption });
}

const PAWRADE_CAPTION_TEMPLATES = [
  (name, code, g, c, e) => `${g} ${name} ${e}\n\nIni QR bukti pendaftaran kamu di Fashion Pawrade Competition 2026 (Colorful Carnival 2026).\nKode: *${code}*\n\nSimpan gambar ini, nanti ditunjukkan ke panitia saat check-in di lokasi lomba ya.${c ? '\n\n' + c : ''}`,
  (name, code, g, c, e) => `${g} ${name}! ${e}\n\nBerikut QR pendaftaran kamu di Fashion Pawrade Competition 2026 (kode ${code}). Mohon disimpan untuk ditunjukkan saat check-in di hari lomba.${c ? '\n' + c : ''}`,
  (name, code, g, c, e) => `${g} ${name},\n\nPendaftaran kamu di Fashion Pawrade Competition 2026 sudah tercatat. QR di atas adalah bukti pendaftaran, kode: ${code}.\nJangan lupa dibawa/ditunjukkan saat check-in di lokasi ya${e ? ' ' + e : ''}`,
  (name, code, g, c, e) => `${g} ${name} ${e}\n\nQR ini bukti kamu sudah terdaftar di Fashion Pawrade Competition 2026 (kode: ${code}). Simpan baik-baik dan tunjukkan ke panitia saat kedatangan.${c ? '\n\n' + c : ''}`,
  (name, code, g, c, e) => `${name}, pendaftaran kamu di Fashion Pawrade Competition 2026 berhasil ${e}\n\nKode pendaftaran: ${code}\nQR di atas mewakili kamu dan semua hewan yang didaftarkan.${c ? '\n' + c : ''}`,
];

function buildPawradeCaption(name, code, queueNumber) {
  var template = pick(PAWRADE_CAPTION_TEMPLATES);
  var text = template(name, code, pick(GREETINGS), pick(CLOSERS), pick(EMOJI_SETS));
  if (queueNumber) {
    text += `\n\nNomor urut pendaftaran: *${queueNumber}*\n(cocokkan dengan stiker nomor saat check-in)`;
  }
  text += '\n\n' + committeeContactBlock();
  return text + (Math.random() < 0.5 ? ' ' : '');
}

async function fetchNextPawrade() {
  var res = await pool.query(
    `select * from api.pawrade_wa_queue where status = 'pending' and attempts < 3 order by created_at asc limit 1`
  );
  return res.rows[0] || null;
}

async function markPawradeSent(id) {
  await pool.query(`update api.pawrade_wa_queue set status = 'sent', sent_at = now() where id = $1`, [id]);
}

async function markPawradeAttemptFailed(id, attempts, errMessage) {
  var status = attempts + 1 >= 3 ? 'failed' : 'pending';
  await pool.query(
    `update api.pawrade_wa_queue set attempts = $2, status = $3, error = $4 where id = $1`,
    [id, attempts + 1, status, errMessage]
  );
}

async function fetchPawradeQueueNumber(ownerId) {
  var res = await pool.query(`select queue_number from api.pawrade_owners where id = $1`, [ownerId]);
  return res.rows[0] ? res.rows[0].queue_number : null;
}

async function sendPawrade(sock, row, toJid) {
  var jid = toJid || normalizePhone(row.phone);
  var queueNumber = await fetchPawradeQueueNumber(row.owner_id);
  var caption = buildPawradeCaption(row.owner_name, row.short_code, queueNumber);

  var base64 = row.qr_image_base64.replace(/^data:image\/\w+;base64,/, '');
  var buffer = Buffer.from(base64, 'base64');
  var fileName = `QR-Fashion-Pawrade-Competition-2026-${row.short_code}.png`;

  var useTwoStep = Math.random() < 0.35;
  await typingPause(sock, jid);

  if (useTwoStep) {
    await sock.sendMessage(jid, { text: pick(SHORT_INTROS) });
    await sleep(randomBetween(2500, 7000));
    await typingPause(sock, jid);
  }
  await sock.sendMessage(jid, {
    document: buffer,
    mimetype: 'image/png',
    fileName: fileName,
    caption: caption,
  });
}

async function fetchQueueNumber(ownerId) {
  var res = await pool.query(`select queue_number from api.owners where id = $1`, [ownerId]);
  return res.rows[0] ? res.rows[0].queue_number : null;
}

async function typingPause(sock, jid) {
  try {
    await sock.presenceSubscribe(jid);
    await sock.sendPresenceUpdate('composing', jid);
    await sleep(randomBetween(1200, 4000));
    await sock.sendPresenceUpdate('paused', jid);
  } catch (e) {
    // presence update gagal bukan alasan untuk batal kirim
  }
}

async function sendOne(sock, row, toJid) {
  var jid = toJid || normalizePhone(row.phone);
  var queueNumber = await fetchQueueNumber(row.owner_id);
  // koreksi = pendaftar ini sempat mendaftar ganda dan QR lamanya sudah
  // terkirim (lihat vps-db/init/25), jadi QR ini dikirim sebagai "QR yang fix".
  var caption = row.koreksi
    ? buildCorrectionCaption(row.owner_name, row.short_code, queueNumber)
    : buildCaption(row.owner_name, row.short_code, queueNumber);

  var base64 = row.qr_image_base64.replace(/^data:image\/\w+;base64,/, '');
  var buffer = Buffer.from(base64, 'base64');
  var fileName = `QR-PetBlessing-${row.short_code}.png`;

  // Dua alur pengiriman berbeda, dipilih acak per nomor -- supaya tidak ada satu
  // pola perilaku identik yang berulang untuk semua penerima.
  var useTwoStep = Math.random() < 0.35;

  await typingPause(sock, jid);

  if (useTwoStep) {
    await sock.sendMessage(jid, { text: pick(SHORT_INTROS) });
    await sleep(randomBetween(2500, 7000));
    await typingPause(sock, jid);
    // Kirim sebagai dokumen (bukan foto) supaya WhatsApp tidak mengompres ulang
    // gambar QR -- kompresi foto biasa bikin QR jadi buram dan sulit discan.
    await sock.sendMessage(jid, {
      document: buffer,
      mimetype: 'image/png',
      fileName: fileName,
      caption: caption,
    });
  } else {
    await sock.sendMessage(jid, {
      document: buffer,
      mimetype: 'image/png',
      fileName: fileName,
      caption: caption,
    });
  }
}

// Satu-satunya worker loop. Dulu tiap event 'open' (termasuk setiap
// reconnect) memulai loop baru tanpa mematikan yang lama; loop lama memegang
// socket yang sudah mati, jadi pesan yang diambilnya gagal "Connection Closed"
// tiga kali beruntun dan ditandai failed. Sekarang loop dimulai sekali dan
// selalu memakai currentSock, serta menunggu kalau koneksi sedang putus.
var currentSock = null;
var connected = false;
var workerStarted = false;

// Layanan pelanggan: chat dari nomor pendaftar ditaruh di INBOX untuk worker CS (bot D'Pro Ops di VPS, Kimi),
// balasannya kembali lewat OUTBOX ({ jid, text }). Chat yang baru dibalas admin dari HP (30 menit) tidak disentuh.
const fs = require('node:fs');
const INBOX = '/data/inbox';
const OUTBOX = '/data/outbox';
// ID pesan yang dikirim bot ini (blast dan balasan CS), supaya worker CS bisa membedakan balasan bot dari balasan admin.
const SENT_IDS = '/data/sent-ids.txt';

// Chat dulu, baru QR (1 Okt 2026, setelah nomor kantor dibatasi WhatsApp karena kiriman massal): QR tidak lagi
// dikirim otomatis ke nomor di formulir. Pendaftar menekan tombol WhatsApp di halaman konfirmasi atau beranda,
// pesannya memuat kode 8 huruf; bot menanyakan screenshot QR dulu (lihat mintaQr). Tanpa kode, nomor HP
// pengirim dicocokkan dengan nomor di formulir. KIRIM_OTOMATIS=1 menyalakan lagi kiriman otomatis antrian QR.
const KIRIM_OTOMATIS = process.env.KIRIM_OTOMATIS === '1';
// Antrian pesan susulan (pengingat, info H-1) dikirim bertahap: hanya JAM_KIRIM_MULAI sampai JAM_KIRIM_SELESAI WIB,
// paling banyak PENGINGAT_PER_JAM pesan per jam, jeda 4 sampai 8 menit. PENGINGAT=0 mematikannya.
const PENGINGAT = process.env.PENGINGAT !== '0';
const PENGINGAT_PER_JAM = Number(process.env.PENGINGAT_PER_JAM || 8);
const JAM_KIRIM_MULAI = Number(process.env.JAM_KIRIM_MULAI || 8);
const JAM_KIRIM_SELESAI = Number(process.env.JAM_KIRIM_SELESAI || 20);
// Mode nomor pribadi (PRIBADI=1): sama dengan bot KUWERA. Sesi login sendiri (AUTH_DIR), hanya chat pendaftar yang
// disentuh, kiriman hanya ke chat yang sudah menghubungi nomor ini. Nomor PRIBADI_IZIN (owner, staf) bukan pendaftar.
const PRIBADI = process.env.PRIBADI === '1';
const AUTH_DIR = process.env.AUTH_DIR || '/data/auth';
const PRIBADI_IZIN = (process.env.PRIBADI_IZIN || '').split(',').map((x) => x.replace(/\D/g, '')).filter(Boolean);
const PRIBADI_FILE = '/data/pribadi-chat.json';
const OUTBOX_TAHAN = '/data/outbox-ditahan';
const PRIBADI_INFO = process.env.PRIBADI_INFO || 'Halo Kak 🙏 Untuk sementara WhatsApp kantor D\'Production sedang gangguan, jadi layanan Pet Blessing 2026 kami jalankan dari nomor ini dulu ya. Semua data pendaftaran tetap tercatat seperti biasa.';
var pribadiChat = {};
try { pribadiChat = JSON.parse(fs.readFileSync(PRIBADI_FILE, 'utf8')); } catch (e) { pribadiChat = {}; }
const phoneOf = (msg) => String(msg.key.senderPn || msg.key.remoteJidAlt || msg.key.remoteJid || '').replace(/@.*/, '').replace(/:.*/, '').replace(/\D/g, '');
const internal = (phone) => PRIBADI_IZIN.some((n) => phone.endsWith(n.slice(-10)));
const textOf = (msg) => { const m = msg.message || {}; return (m.conversation || (m.extendedTextMessage && m.extendedTextMessage.text) || '').trim(); };

// Chat pendaftar yang pertama kali menghubungi nomor pribadi: dicatat dan dikabari sekali.
async function catatPelanggan(sock, jid) {
  if (!PRIBADI || pribadiChat[jid]) return;
  pribadiChat[jid] = Date.now();
  fs.writeFileSync(PRIBADI_FILE, JSON.stringify(pribadiChat));
  await sock.sendMessage(jid, { text: PRIBADI_INFO }).catch((e) => logger.error({ jid, err: e.message }, 'gagal kirim kabar nomor sementara'));
}

async function cariQr(kode, phone) {
  var byPhone = phone.length >= 10 ? phone : '';
  var pb = await pool.query(
    `select q.* from api.wa_queue q join api.owners o on o.id = q.owner_id
      where upper(q.short_code) = $1 or ($2 <> '' and right(regexp_replace(q.phone, '\\D', '', 'g'), 10) = right($2, 10))
      order by q.created_at desc`, [kode || '', byPhone]);
  var pr = await pool.query(
    `select q.* from api.pawrade_wa_queue q join api.pawrade_owners o on o.id = q.owner_id
      where upper(q.short_code) = $1 or ($2 <> '' and right(regexp_replace(q.phone, '\\D', '', 'g'), 10) = right($2, 10))
      order by q.created_at desc`, [kode || '', byPhone]);
  var seen = {};
  var hasil = [];
  pb.rows.map((r) => ({ row: r, pawrade: false })).concat(pr.rows.map((r) => ({ row: r, pawrade: true }))).forEach((x) => {
    var key = (x.pawrade ? 'pr:' : 'pb:') + x.row.owner_id;
    if (!seen[key]) { seen[key] = true; hasil.push(x); }
  });
  return hasil.slice(0, 3);
}

var terakhirMinta = {}; // jid -> waktu QR terakhir dikirim, supaya pesan beruntun tidak membuat QR dobel
async function kirimQr(sock, jid, hasil) {
  if (Date.now() - (terakhirMinta[jid] || 0) < 10 * 60000) return;
  terakhirMinta[jid] = Date.now();
  for (var x of hasil) {
    if (x.pawrade) await sendPawrade(sock, x.row, jid);
    else await sendOne(sock, x.row, jid);
    if (x.row.status !== 'sent') {
      if (x.pawrade) await markPawradeSent(x.row.id); else await markSent(x.row.id);
    }
    logger.info({ jid, id: x.row.id, kode: x.row.short_code, pawrade: x.pawrade }, 'QR dikirim atas permintaan pendaftar');
    await sleep(randomBetween(2000, 5000));
  }
}

// Alur tombol WhatsApp (Donny 1 Okt): pendaftar menyapa "aku udah daftar", bot bertanya apakah QR di halaman
// konfirmasi sudah di-screenshot. SUDAH = chat selesai, BELUM = QR dikirim. Permintaan QR yang jelas ("minta QR")
// langsung dikirimi QR. Pertanyaan yang belum dijawab disimpan di TANYA_FILE (jid -> kode, nomor, waktu).
const TANYA_FILE = '/data/tanya-screenshot.json';
var tanyaSs = {};
try { tanyaSs = JSON.parse(fs.readFileSync(TANYA_FILE, 'utf8')); } catch (e) { tanyaSs = {}; }
const simpanTanya = () => fs.writeFileSync(TANYA_FILE, JSON.stringify(tanyaSs));

async function mintaQr(sock, msg) {
  var jid = msg.key.remoteJid;
  var text = textOf(msg);
  var phone = phoneOf(msg);
  if (!text || internal(phone)) return false;

  var tanya = tanyaSs[jid];
  // Sapaan tombol ("aku udah daftar Pet Blessing") bukan jawaban, walau memuat kata "udah".
  if (tanya && Date.now() - tanya.waktu < 24 * 3600000 && !/pet ?blessing|pawrade/i.test(text)) {
    var belum = /\b(belum|blm|belom|lom|tidak|tdk|gak|ga|nggak|ngga|enggak)\b/i.test(text);
    var sudah = !belum && /\b(sudah|udah|udh|sdh|dah|done|ok|oke|okay|siap)\b/i.test(text);
    if (belum || sudah) {
      delete tanyaSs[jid];
      simpanTanya();
      if (belum) {
        await kirimQr(sock, jid, await cariQr(tanya.kode, tanya.phone));
      } else {
        await typingPause(sock, jid);
        await sock.sendMessage(jid, { text: 'Siap Kak, terima kasih! 🙏 QR di screenshot itu yang ditunjukkan ke panitia saat reg ulang di lokasi acara ya. Sampai jumpa 🐾' });
        logger.info({ jid }, 'pendaftar sudah screenshot QR, chat selesai');
      }
      return true;
    }
  }

  var kodeMatch = text.match(/\b[0-9A-F]{8}\b/i);
  var kode = kodeMatch ? kodeMatch[0].toUpperCase() : '';
  var sebutAcara = /pet ?blessing|pawrade/i.test(text);
  if (!kode && !(sebutAcara && /\bqr\b|reg(istrasi)? ?ulang|kode|daftar/i.test(text))) return false;
  var cariPhone = sebutAcara ? phone : '';
  var hasil = await cariQr(kode, cariPhone);
  if (!hasil.length) {
    if (!sebutAcara) return false;
    await catatPelanggan(sock, jid);
    await typingPause(sock, jid);
    await sock.sendMessage(jid, { text: 'Mohon maaf Kak, pendaftarannya belum kami temukan 🙏 Boleh kirimkan kode pendaftaran 8 huruf yang ada di halaman konfirmasi? Kalau tidak ada, silakan hubungi panitia ya.\n\n' + committeeContactBlock() });
    logger.info({ jid, kode }, 'minta QR: pendaftaran tidak ditemukan');
    return true;
  }
  await catatPelanggan(sock, jid);
  if (/(minta|kirim)\w*\s+(ulang\s+)?qr|\bqr\b.*\b(lagi|ulang|hilang)\b/i.test(text)) {
    await kirimQr(sock, jid, hasil);
    return true;
  }
  tanyaSs[jid] = { kode: kode, phone: cariPhone, waktu: Date.now() };
  simpanTanya();
  var acara = hasil[0].pawrade ? 'Fashion Pawrade 2026' : 'Pet Blessing 2026';
  await typingPause(sock, jid);
  await sock.sendMessage(jid, { text: 'Halo Kak ' + (hasil[0].row.owner_name || '') + ' 🐾 Terima kasih sudah mendaftar ' + acara + '!\n\nApakah Kakak sudah screenshot QR di halaman konfirmasi pendaftaran? Balas *SUDAH* kalau sudah, atau *BELUM* kalau belum, nanti QR-nya kami kirimkan di sini.' });
  logger.info({ jid, kode }, 'pendaftar ditanya sudah screenshot QR');
  return true;
}

async function jumlahPengingatSejam() {
  var res = await pool.query(`select count(*)::int as n from api.wa_followup_queue where sent_at > now() - interval '1 hour'`);
  return res.rows[0].n;
}
const jamWib = () => Number(new Date().toLocaleString('en-US', { timeZone: 'Asia/Jakarta', hour: 'numeric', hourCycle: 'h23' }));

async function registrantName(phone) {
  if (phone.length < 10) return null;
  const res = await pool.query(
    `select owner_name from api.wa_queue where right(regexp_replace(phone, '\\D', '', 'g'), 10) = right($1, 10)
     union all select owner_name from api.pawrade_wa_queue where right(regexp_replace(phone, '\\D', '', 'g'), 10) = right($1, 10)
     limit 1`,
    [phone]
  );
  return res.rows.length ? res.rows[0].owner_name || '-' : null;
}

async function csInbox(msg) {
  const jid = msg.key.remoteJid || '';
  if (msg.key.fromMe || !jid || jid.endsWith('@g.us') || jid === 'status@broadcast' || jid.endsWith('@newsletter')) return;
  const m = msg.message || {};
  const text = (m.conversation || (m.extendedTextMessage && m.extendedTextMessage.text) || '').trim();
  if (!text) return;
  const phone = String(msg.key.senderPn || msg.key.remoteJidAlt || jid).replace(/@.*/, '').replace(/\D/g, '');
  if (internal(phone)) return;
  const owner = await registrantName(phone);
  if (owner === null) return; // bukan pendaftar Pet Blessing
  await catatPelanggan(currentSock, jid);
  fs.mkdirSync(INBOX, { recursive: true });
  fs.writeFileSync(INBOX + '/' + msg.key.id + '.json', JSON.stringify({
    id: msg.key.id, bot: 'petblessing', jid: jid, phone: phone, nama: msg.pushName || '', pendaftar: owner,
    text: text.slice(0, 1000), waktu: Date.now(),
  }));
}

async function processOutbox() {
  if (!connected || !currentSock) return;
  fs.mkdirSync(OUTBOX, { recursive: true });
  for (const f of fs.readdirSync(OUTBOX).filter((x) => x.endsWith('.json')).sort()) {
    const item = JSON.parse(fs.readFileSync(OUTBOX + '/' + f, 'utf8'));
    if (PRIBADI && !(pribadiChat[item.jid] || internal(String(item.jid || '').replace(/@.*/, '')))) {
      fs.mkdirSync(OUTBOX_TAHAN, { recursive: true });
      fs.renameSync(OUTBOX + '/' + f, OUTBOX_TAHAN + '/' + f);
      logger.warn({ f, jid: item.jid }, 'mode pribadi: kiriman outbox ditahan');
      continue;
    }
    fs.unlinkSync(OUTBOX + '/' + f);
    try {
      await currentSock.sendPresenceUpdate('composing', item.jid).catch(() => {});
      await sleep(randomBetween(1500, 4000));
      await currentSock.sendMessage(item.jid, { text: item.text });
      logger.info({ jid: item.jid, topik: item.topik }, 'balasan CS terkirim');
    } catch (e) {
      logger.error({ jid: item.jid, err: e.message }, 'gagal kirim balasan CS');
    }
  }
}
setInterval(() => processOutbox().catch((e) => logger.error({ err: e.message }, 'outbox CS gagal')), 5000);

async function runWorkerLoop() {
  var sentCount = 0;
  while (true) {
    if (!connected || !currentSock) {
      await sleep(5000);
      continue;
    }
    var sock = currentSock;
    var row = null;
    var isFollowup = false;
    var isPawrade = false;
    var isCorrection = false;
    try {
      if (KIRIM_OTOMATIS) {
        row = await fetchNextPending();
        if (!row) {
          row = await fetchNextPawrade();
          isPawrade = Boolean(row);
        }
        if (!row) {
          row = await fetchNextCorrection();
          isCorrection = Boolean(row);
        }
      }
      var jam = jamWib();
      if (!row && PENGINGAT && jam >= JAM_KIRIM_MULAI && jam < JAM_KIRIM_SELESAI && (await jumlahPengingatSejam()) < PENGINGAT_PER_JAM) {
        row = await fetchNextFollowup();
        isFollowup = Boolean(row);
      }
    } catch (e) {
      logger.error({ err: e.message }, 'gagal query antrian');
    }

    if (!row) {
      await sleep(randomBetween(15000, 30000));
      continue;
    }

    try {
      logger.info({ id: row.id, phone: row.phone, followup: isFollowup, pawrade: isPawrade, correction: isCorrection }, 'mengirim pesan WhatsApp');
      if (isCorrection) {
        await sendCorrection(sock, row);
        await markCorrectionSent(row.id);
      } else if (isFollowup) {
        await sendFollowup(sock, row);
        await markFollowupSent(row.id);
      } else if (isPawrade) {
        await sendPawrade(sock, row);
        await markPawradeSent(row.id);
      } else {
        await sendOne(sock, row);
        await markSent(row.id);
      }
      sentCount++;
      logger.info({ id: row.id }, 'terkirim');
    } catch (e) {
      if (/connection closed/i.test(e.message)) {
        // Socket sedang putus/tersambung ulang, bukan masalah pesannya.
        // Jangan habiskan jatah percobaan; tunggu lalu coba lagi.
        logger.warn({ id: row.id }, 'koneksi sedang putus, pesan ditunda 20 detik');
        await sleep(20000);
        continue;
      }
      logger.error({ id: row.id, err: e.message }, 'gagal kirim, akan dicoba lagi');
      if (isCorrection) await markCorrectionAttemptFailed(row.id, row.attempts, e.message);
      else if (isFollowup) await markFollowupAttemptFailed(row.id, row.attempts, e.message);
      else if (isPawrade) await markPawradeAttemptFailed(row.id, row.attempts, e.message);
      else await markAttemptFailed(row.id, row.attempts, e.message);
    }

    // Delay acak antar pengiriman -- inti dari "tidak dianggap spam".
    // 1-3 menit per pesan (Donny 30 Sep, sebelumnya 2-5 menit), supaya pola
    // kirim beruntun tetap terlihat seperti orang membalas satu-satu, bukan bot.
    // Pesan susulan dijeda lebih lama (4 sampai 8 menit) karena dikirim ke banyak orang sekaligus.
    var delay = isFollowup ? randomBetween(240000, 480000) : randomBetween(60000, 180000);
    logger.info({ delayMs: delay }, 'jeda sebelum pesan berikutnya');
    await sleep(delay);
  }
}

async function start() {
  const { state, saveCreds } = await useMultiFileAuthState(AUTH_DIR);
  const { version, isLatest } = await fetchLatestBaileysVersion();
  logger.info({ version, isLatest }, 'pakai versi protokol WhatsApp Web');

  const sock = makeWASocket({
    auth: state,
    version: version,
    logger: pino({ level: 'silent' }),
  });

  sock.ev.on('creds.update', saveCreds);
  const send = sock.sendMessage.bind(sock);
  sock.sendMessage = async (...args) => {
    const sent = await send(...args);
    if (sent && sent.key && sent.key.id) fs.appendFileSync(SENT_IDS, sent.key.id + '\n');
    return sent;
  };

  sock.ev.on('messages.upsert', async ({ messages, type }) => {
    if (type !== 'notify') return;
    for (const m of messages) {
      const jid = m.key.remoteJid || '';
      if (m.key.fromMe || !jid || jid.endsWith('@g.us') || jid === 'status@broadcast' || jid.endsWith('@newsletter')) continue;
      try {
        if (!(await mintaQr(sock, m))) await csInbox(m);
      } catch (e) { logger.error({ err: e.message }, 'gagal memproses pesan masuk'); }
    }
  });

  sock.ev.on('connection.update', (update) => {
    const { connection, lastDisconnect, qr } = update;
    if (qr) {
      logger.info('Scan QR ini dengan WhatsApp di nomor khusus Pet Blessing:');
      qrcodeTerminal.generate(qr, { small: true });
      QRCode.toFile('/data/latest-qr.png', qr, { width: 400 }).catch((e) => {
        logger.error({ err: e.message }, 'gagal simpan QR sebagai PNG');
      });
    }
    if (connection === 'close') {
      connected = false;
      var statusCode = new Boom(lastDisconnect && lastDisconnect.error).output.statusCode;
      var shouldReconnect = statusCode !== DisconnectReason.loggedOut;
      logger.warn({ statusCode, shouldReconnect }, 'koneksi WhatsApp terputus');
      if (shouldReconnect) start();
    } else if (connection === 'open') {
      currentSock = sock;
      connected = true;
      logger.info('WhatsApp bot terhubung');
      if (!workerStarted) {
        workerStarted = true;
        runWorkerLoop().catch((e) => { workerStarted = false; logger.error({ err: e.message }, 'worker loop berhenti'); });
      }
    }
  });
}

start().catch((e) => {
  logger.error({ err: e.message }, 'gagal start bot');
  process.exit(1);
});
