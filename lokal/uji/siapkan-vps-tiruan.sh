#!/bin/bash
# VPS tiruan untuk menguji server lokal tanpa menyentuh produksi.
#   bash lokal/uji/siapkan-vps-tiruan.sh
# Butuh lokal/.env dengan VPS_API_URL=http://127.0.0.1:3102 (dan uji/.env = salinannya).
set -euo pipefail
cd "$(dirname "$0")"
set -a; . ./.env; set +a
docker compose up -d db
until docker exec pbuji-vps-db pg_isready -U petblessing >/dev/null 2>&1; do sleep 1; done
sleep 2
PSQL="docker exec -i pbuji-vps-db psql -v ON_ERROR_STOP=1 -q -U petblessing -d petblessing"
if ! $PSQL -Atc "select 1 from pg_roles where rolname='authenticator'" | grep -q 1; then
  $PSQL -v auth_pw="$AUTH_PW" < ../00-peran.sql
  $PSQL < ../skema-vps.sql
  # Data palsu: 40 pemilik, 1 sampai 3 hewan, 3 di antaranya data uji.
  $PSQL <<'SQL'
insert into api.owners (id, name, phone, is_parishioner, agreed_tos, queue_number, companions, is_test)
select gen_random_uuid(), 'Pemilik ' || i, '0812000' || lpad(i::text, 4, '0'), 'ya', true, i, i % 3, i > 37
from generate_series(1, 40) i;
insert into api.pets (id, owner_id, name, type)
select gen_random_uuid(), o.id, 'Hewan ' || o.queue_number || '-' || k, case when k = 2 then 'Kucing' else 'Anjing' end
from api.owners o, generate_series(1, 3) k where k <= 1 + o.queue_number % 3;
SQL
  echo "Skema + data palsu dimuat"
fi
# 22 tidak aman diulang (policy), jadi hanya dimuat sekali.
$PSQL -Atc "select to_regclass('api.hari_h')" | grep -q hari_h || $PSQL < ../../vps-db/init/22-hari-h.sql
$PSQL < ../../vps-db/init/26-pos-ganjil-genap.sql
$PSQL < ../../vps-db/init/27-hasil-foto-publik.sql
docker compose up -d postgrest
docker exec pbuji-vps-db psql -U petblessing -d petblessing -qc "notify pgrst, 'reload schema'"
echo "VPS tiruan siap di http://127.0.0.1:3102"
