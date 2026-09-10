// Kredensial publik Supabase (project URL + anon key).
// anon key aman ditaruh di kode client-side -- akses data diatur lewat
// Row Level Security di schema.sql, bukan lewat kerahasiaan key ini.
// JANGAN PERNAH taruh service_role key di file ini atau file manapun yang di-deploy.
window.SUPABASE_URL = 'REPLACE_WITH_PROJECT_URL';
window.SUPABASE_ANON_KEY = 'REPLACE_WITH_ANON_KEY';
