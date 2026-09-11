// URL API pendaftaran (PostgREST di VPS dreinst). Insert langsung dari
// client sudah ditutup (lihat vps-db/init/04-captcha-gate.sql) -- form
// sekarang menulis lewat /api/register (Vercel) yang verifikasi captcha
// dulu. URL ini tetap dipakai untuk baca data (halaman rekap/check-in,
// setelah login panitia).
window.PETBLESSING_API_URL = 'https://petblessing-api.187.53.129.205.sslip.io';

// Site key Cloudflare Turnstile -- aman ditaruh di client (bukan rahasia,
// beda dengan secret key yang cuma ada di server/Vercel env var).
window.TURNSTILE_SITE_KEY = 'REPLACE_WITH_TURNSTILE_SITE_KEY';
