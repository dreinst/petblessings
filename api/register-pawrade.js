const jwt = require('jsonwebtoken');

// Jalur menulis pendaftaran Pawrade (lomba costume parade, bagian dari
// Colorful Carnival 2026). Sama persis alurnya dengan /api/register (Pet
// Blessing): verifikasi captcha dulu, baru terbitkan JWT role
// "web_registrant" berumur pendek untuk insert ke PostgREST. Tabelnya
// terpisah (api.pawrade_owners / api.pawrade_pets / api.pawrade_wa_queue),
// lihat vps-db/init/12-pawrade.sql.

function isNonEmptyString(v, maxLen) {
  return typeof v === 'string' && v.trim().length > 0 && v.length <= maxLen;
}

async function verifyTurnstile(token, remoteIp) {
  var secret = process.env.TURNSTILE_SECRET_KEY;
  if (!secret) throw new Error('TURNSTILE_SECRET_KEY belum diatur di server');
  var params = new URLSearchParams();
  params.set('secret', secret);
  params.set('response', token || '');
  if (remoteIp) params.set('remoteip', remoteIp);

  var res = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: params.toString(),
  });
  var data = await res.json();
  return !!data.success;
}

function validatePayload(body) {
  var owner = body.owner;
  var pets = body.pets;

  if (!owner || typeof owner !== 'object') return 'Data pemilik tidak lengkap';
  if (!isNonEmptyString(owner.id, 100)) return 'ID pendaftaran tidak valid';
  if (!isNonEmptyString(owner.name, 200)) return 'Nama pemilik wajib diisi';
  if (!isNonEmptyString(owner.phone, 30)) return 'Nomor HP wajib diisi';
  if (owner.is_parishioner !== 'ya' && owner.is_parishioner !== 'bukan') return 'Status umat tidak valid';
  var companions = owner.companions == null ? 0 : owner.companions;
  if (!Number.isInteger(companions) || companions < 0 || companions > 20) return 'Jumlah pendamping tidak valid';
  var proof = owner.donation_proof_base64;
  if (proof != null && proof !== '') {
    if (typeof proof !== 'string' || proof.length > 2000000 || proof.indexOf('data:image/') !== 0) return 'Bukti transfer tidak valid';
  }

  if (!Array.isArray(pets) || pets.length < 1 || pets.length > 20) return 'Data hewan tidak valid';
  for (var i = 0; i < pets.length; i++) {
    var p = pets[i];
    if (!isNonEmptyString(p.id, 100) || !isNonEmptyString(p.owner_id, 100)) return 'ID hewan tidak valid';
    if (!isNonEmptyString(p.name, 100)) return 'Nama hewan wajib diisi';
    if (!isNonEmptyString(p.type, 50)) return 'Jenis hewan wajib diisi';
    if (p.photo_base64 != null && p.photo_base64 !== '') {
      if (typeof p.photo_base64 !== 'string' || p.photo_base64.length > 2000000 || p.photo_base64.indexOf('data:image/') !== 0) return 'Foto hewan tidak valid';
    }
    if (p.owner_id !== owner.id) return 'Data hewan tidak cocok dengan pemilik';
  }

  var wa = body.waQueue;
  if (wa) {
    if (!isNonEmptyString(wa.id, 100) || wa.owner_id !== owner.id) return 'Data antrian WhatsApp tidak valid';
    if (!isNonEmptyString(wa.phone, 30)) return 'Nomor HP antrian WhatsApp tidak valid';
    if (typeof wa.qr_image_base64 !== 'string' || wa.qr_image_base64.length > 2000000) return 'Gambar QR tidak valid';
  }

  return null;
}

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  var body = req.body || {};
  var jwtSecret = process.env.PGRST_JWT_SECRET;
  var apiUrl = process.env.PETBLESSING_API_URL;

  if (!jwtSecret || !apiUrl) {
    res.status(500).json({ error: 'Server belum dikonfigurasi lengkap' });
    return;
  }

  if (!body.turnstileToken) {
    res.status(400).json({ error: 'Captcha wajib diisi' });
    return;
  }

  var validationError = validatePayload(body);
  if (validationError) {
    res.status(400).json({ error: validationError });
    return;
  }

  try {
    var remoteIp = (req.headers['x-forwarded-for'] || '').split(',')[0].trim();
    var captchaOk = await verifyTurnstile(body.turnstileToken, remoteIp);
    if (!captchaOk) {
      res.status(400).json({ error: 'Verifikasi captcha gagal, coba lagi' });
      return;
    }

    var token = jwt.sign({ role: 'web_registrant' }, jwtSecret, { expiresIn: '2m' });

    async function insertRow(path, payload) {
      var r = await fetch(apiUrl + path, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
          'Authorization': 'Bearer ' + token,
        },
        body: JSON.stringify(payload),
      });
      if (!r.ok) {
        var detail = await r.text().catch(function () { return ''; });
        throw new Error(path + ' gagal (' + r.status + '): ' + detail);
      }
    }

    await insertRow('/pawrade_owners', {
      id: body.owner.id,
      name: body.owner.name,
      phone: body.owner.phone,
      is_parishioner: body.owner.is_parishioner,
      parish_origin: body.owner.parish_origin || null,
      companions: body.owner.companions || 0,
      donation_amount: body.owner.donation_amount || null,
      donation_has_proof: !!body.owner.donation_has_proof,
      donation_proof_base64: body.owner.donation_proof_base64 || null,
      agreed_tos: !!body.owner.agreed_tos,
      submitted_at: body.owner.submitted_at,
    });

    await insertRow('/pawrade_pets', body.pets.map(function (p) {
      return {
        id: p.id,
        owner_id: p.owner_id,
        name: p.name,
        type: p.type,
        has_photo: !!p.has_photo,
        photo_base64: p.photo_base64 || null,
        notes: p.notes || null,
      };
    }));

    if (body.waQueue) {
      // Best-effort -- kalau ini gagal, pendaftaran yang sudah tersimpan di
      // atas tetap dianggap berhasil, jadi jangan lempar error ke client.
      try {
        await insertRow('/pawrade_wa_queue', body.waQueue);
      } catch (e) {
        console.error('pawrade_wa_queue insert failed', e.message);
      }
    }

    res.status(200).json({ ok: true, ownerId: body.owner.id });
  } catch (e) {
    console.error('register-pawrade failed', e.message);
    res.status(500).json({ error: 'Gagal menyimpan pendaftaran, coba lagi sebentar lagi' });
  }
};
