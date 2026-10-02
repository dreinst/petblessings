#!/bin/bash
# Menyiapkan server lokal hari-H di Mac (sekali, sebelum acara, butuh internet).
#   bash lokal/siapkan.sh
# Aman dijalankan ulang: yang sudah ada tidak ditimpa. Untuk mulai dari nol:
#   docker compose -f lokal/docker-compose.yml down && rm -rf lokal/data
set -euo pipefail
cd "$(dirname "$0")"
VPS=root@187.53.129.205

# 1. Rahasia. JWT_SECRET disamakan dengan VPS supaya token login dan token
#    booth berlaku di dua server (penting saat pindah ke cadangan).
if [ ! -f .env ]; then
  JWT=$(ssh "$VPS" "grep '^JWT_SECRET=' /root/petblessing-db/.env | cut -d= -f2-")
  [ -n "$JWT" ] || { echo "Gagal ambil JWT_SECRET dari VPS"; exit 1; }
  cat > .env <<ENV
JWT_SECRET=$JWT
DB_PW=$(openssl rand -hex 16)
AUTH_PW=$(openssl rand -hex 16)
VPS_API_URL=https://petblessing-api.187.53.129.205.sslip.io
ENV
  chmod 600 .env
  echo "lokal/.env dibuat"
fi
# Hanya tiga nilai yang dibutuhkan skrip ini. .env tidak di-source utuh karena
# hash password ($2b$...) di dalamnya dibaca bash sebagai variabel.
for k in JWT_SECRET DB_PW AUTH_PW; do export "$k=$(grep "^$k=" .env | cut -d= -f2-)"; done

# 2. Sertifikat HTTPS untuk IP Mac di jaringan (kamera di HP butuh HTTPS).
#    Kalau IP Mac berubah (router lain), hapus data/cert.pem lalu jalankan ulang.
mkdir -p data
if [ ! -f data/cert.pem ]; then
  SAN="DNS:localhost,IP:127.0.0.1"
  for ip in $(ifconfig | awk '/inet / && $2 != "127.0.0.1" {print $2}'); do SAN="$SAN,IP:$ip"; done
  openssl req -x509 -newkey rsa:2048 -nodes -days 30 -subj "/CN=Pet Blessing lokal" \
    -addext "subjectAltName=$SAN" -keyout data/key.pem -out data/cert.pem 2>/dev/null
  echo "Sertifikat dibuat untuk: $SAN"
fi

# 3. Database + API (container di Mac ini, bukan di VPS).
docker compose up -d db
until docker exec pblokal-db pg_isready -U petblessing >/dev/null 2>&1; do sleep 1; done
sleep 2
PSQL="docker exec -i pblokal-db psql -v ON_ERROR_STOP=1 -q -U petblessing -d petblessing"
if ! $PSQL -Atc "select 1 from pg_roles where rolname='authenticator'" | grep -q 1; then
  $PSQL -v auth_pw="$AUTH_PW" < 00-peran.sql
  $PSQL < skema-vps.sql
  echo "Skema VPS dimuat"
fi
# 22 tidak aman diulang (policy), jadi hanya dimuat sekali.
$PSQL -Atc "select to_regclass('api.hari_h')" | grep -q hari_h || $PSQL < ../vps-db/init/22-hari-h.sql
for m in 24-perbaiki-trigger-huruf-stiker 25-gabung-pendaftaran-ganda 26-pos-ganjil-genap 27-hasil-foto-publik; do $PSQL < ../vps-db/init/$m.sql; done
# Server lokal baru memberi nomor setelah "Ambil alih" ditekan di halaman kendali.
$PSQL -c "update api.hari_h set pemberi_nomor = false where id = 1 and lantai = 0 and not exists (select 1 from api.checkins)"
docker compose up -d postgrest
docker exec pblokal-db psql -U petblessing -d petblessing -qc "notify pgrst, 'reload schema'"

# 4. Modul Node (jsonwebtoken, bcryptjs) untuk login.
(cd .. && { [ -d node_modules/jsonwebtoken ] || npm install --silent; })

grep -q '^SUPERADMIN_PASSWORD_HASH=' .env || echo "Belum ada akun login lokal. Jalankan: node lokal/atur-akun.js"
echo "Siap. Jalankan server: node lokal/server.js"
