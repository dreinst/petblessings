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
    text += `\n\nNomor urut pendaftaran: *${queueNumber}*\n(cocokkan dengan stiker nomor saat reg ulang)`;
  }
  text += '\n\n' + committeeContactBlock();
  // Variasi kecil whitespace di akhir, supaya byte teks tidak pernah identik
  // persis walau template & isi kebetulan sama.
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

async function sendFollowup(sock, row) {
  var jid = normalizePhone(row.phone);
  var caption = buildFollowupCaption(row.owner_name);
  await typingPause(sock, jid);
  await sock.sendMessage(jid, { text: caption });
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

async function sendOne(sock, row) {
  var jid = normalizePhone(row.phone);
  var queueNumber = await fetchQueueNumber(row.owner_id);
  var caption = buildCaption(row.owner_name, row.short_code, queueNumber);

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

async function runWorkerLoop(sock) {
  var sentCount = 0;
  while (true) {
    var row = null;
    var isFollowup = false;
    try {
      row = await fetchNextPending();
      if (!row) {
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
      logger.info({ id: row.id, phone: row.phone, followup: isFollowup }, 'mengirim pesan WhatsApp');
      if (isFollowup) {
        await sendFollowup(sock, row);
        await markFollowupSent(row.id);
      } else {
        await sendOne(sock, row);
        await markSent(row.id);
      }
      sentCount++;
      logger.info({ id: row.id }, 'terkirim');
    } catch (e) {
      logger.error({ id: row.id, err: e.message }, 'gagal kirim, akan dicoba lagi');
      if (isFollowup) await markFollowupAttemptFailed(row.id, row.attempts, e.message);
      else await markAttemptFailed(row.id, row.attempts, e.message);
    }

    // Delay acak antar pengiriman -- inti dari "tidak dianggap spam".
    // 2-5 menit per pesan, supaya pola kirim beruntun (misal 10+ pendaftar
    // sekaligus) tetap terlihat seperti orang membalas satu-satu, bukan bot.
    var delay = randomBetween(120000, 300000);
    // Sesekali kasih jeda lebih panjang lagi, meniru pola istirahat manusia.
    if (sentCount > 0 && sentCount % 10 === 0) {
      delay = randomBetween(600000, 1200000);
      logger.info('jeda panjang setelah 10 pesan berturut-turut');
    }
    logger.info({ delayMs: delay }, 'jeda sebelum pesan berikutnya');
    await sleep(delay);
  }
}

async function start() {
  const { state, saveCreds } = await useMultiFileAuthState('/data/auth');
  const { version, isLatest } = await fetchLatestBaileysVersion();
  logger.info({ version, isLatest }, 'pakai versi protokol WhatsApp Web');

  const sock = makeWASocket({
    auth: state,
    version: version,
    logger: pino({ level: 'silent' }),
  });

  sock.ev.on('creds.update', saveCreds);

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
      var statusCode = new Boom(lastDisconnect && lastDisconnect.error).output.statusCode;
      var shouldReconnect = statusCode !== DisconnectReason.loggedOut;
      logger.warn({ statusCode, shouldReconnect }, 'koneksi WhatsApp terputus');
      if (shouldReconnect) start();
    } else if (connection === 'open') {
      logger.info('WhatsApp bot terhubung');
      runWorkerLoop(sock).catch((e) => logger.error({ err: e.message }, 'worker loop berhenti'));
    }
  });
}

start().catch((e) => {
  logger.error({ err: e.message }, 'gagal start bot');
  process.exit(1);
});
