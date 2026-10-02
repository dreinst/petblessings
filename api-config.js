// URL API pendaftaran (PostgREST di VPS dreinst). Insert langsung dari
// client sudah ditutup (lihat vps-db/init/04-captcha-gate.sql) -- form
// sekarang menulis lewat /api/register (Vercel) yang verifikasi captcha
// dulu. URL ini tetap dipakai untuk baca data (halaman rekap/check-in,
// setelah login panitia).
window.PETBLESSING_API_URL = 'https://petblessing-api.187.53.129.205.sslip.io';

// Site key Cloudflare Turnstile -- aman ditaruh di client (bukan rahasia,
// beda dengan secret key yang cuma ada di server/Vercel env var).
// Nomor WhatsApp tujuan tombol "Minta QR". Sementara nomor superadmin (Andrew) selama nomor kantor
// 6282232999900 dibatasi WhatsApp (1 Okt 2026); kembalikan setelah pembatasan selesai.
window.WA_PANITIA = '6282228555254';

window.TURNSTILE_SITE_KEY = '0x4AAAAAAEv82S-01dyodu4-';
