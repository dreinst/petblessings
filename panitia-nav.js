// Navbar bersama untuk semua halaman panitia (rekap, dashboard, check-in,
// database QR). Satu sumber untuk daftar halaman dan hak akses per peran,
// supaya navigasi konsisten di tiap halaman (ui-ux-pro-max: navigation-
// consistency, nav-state-active, nav-label-icon, touch-target-size 44px).
//
// Cara pakai di halaman: <div id="panitiaNav"></div> di dalam #appWrap, lalu
// panggil PanitiaNav.render() di showApp(). Tombol Keluar memakai handler
// #logoutBtn milik halaman kalau ada (supaya timer dsb ikut dibersihkan).
(function(){
  var TOKEN_KEY = 'petblessing_panitia_token';

  var ICON = {
    dashboard: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="3" y="3" width="7" height="9" rx="1.5"/><rect x="14" y="3" width="7" height="5" rx="1.5"/><rect x="14" y="12" width="7" height="9" rx="1.5"/><rect x="3" y="16" width="7" height="5" rx="1.5"/></svg>',
    rekap: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="8" y1="13" x2="16" y2="13"/><line x1="8" y1="17" x2="13" y2="17"/></svg>',
    pawrade: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 3l2.4 4.9 5.4.8-3.9 3.8.9 5.4L12 15.3 7.2 17.9l.9-5.4L4.2 8.7l5.4-.8z"/></svg>',
    checkin: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 7V5a2 2 0 0 1 2-2h2"/><path d="M17 3h2a2 2 0 0 1 2 2v2"/><path d="M21 17v2a2 2 0 0 1-2 2h-2"/><path d="M7 21H5a2 2 0 0 1-2-2v-2"/><polyline points="8 12 11 15 16 9"/></svg>',
    qr: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><path d="M14 14h3v3h-3zM20 14h1M14 20h1M20 20h1M17 17h4"/></svg>',
    logout: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>'
  };

  // level: null = semua peran, 'superadmin' = hanya superadmin.
  var ITEMS = [
    { href: 'superadmin.html',       label: 'Dashboard',            icon: 'dashboard', level: 'superadmin' },
    { href: 'pendaftaran-masuk.html', label: 'Rekap Pet Blessing',  icon: 'rekap' },
    { href: 'pawrade-rekap.html',     label: 'Rekap Pawrade',       icon: 'pawrade' },
    { href: 'checkin.html',           label: 'Check-in Pet Blessing', icon: 'checkin', level: 'superadmin' },
    { href: 'pawrade-checkin.html',   label: 'Reg ulang Pawrade',   icon: 'checkin', level: 'superadmin' },
    { href: 'qr-database.html',       label: 'Database QR',         icon: 'qr', level: 'superadmin' }
  ];

  var CSS = [
    // Mobile dulu: baris 1 = peran + Keluar, baris 2 = tombol halaman dalam 2 kolom.
    // Di layar lebar (>=720px) semua tombol jadi satu baris, Keluar di ujung kanan.
    '.pnav{position:sticky;top:0;z-index:30;display:flex;align-items:center;flex-wrap:wrap;gap:10px;margin:-8px -4px 18px;padding:10px 4px;background:rgba(251,243,231,.94);backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px);border-bottom:1px solid var(--line,#E8DCC8);}',
    '.pnav-role{order:1;font-size:12px;font-weight:600;letter-spacing:.02em;text-transform:uppercase;color:var(--brand-deep,#3B1052);background:var(--brand-light,#DFF4F6);padding:6px 10px;border-radius:999px;white-space:nowrap;}',
    '.pnav-logout{order:2;margin-left:auto;display:inline-flex;align-items:center;gap:8px;min-height:44px;padding:10px 14px;border:1px solid var(--line,#E8DCC8);border-radius:12px;background:transparent;color:var(--danger,#A6423A);font-family:inherit;font-size:13.5px;font-weight:500;cursor:pointer;transition:background .18s ease,border-color .18s ease;}',
    '.pnav-items{order:3;flex:1 1 100%;display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;}',
    '.pnav-btn{display:inline-flex;align-items:center;gap:8px;min-height:44px;padding:10px 12px;border:1px solid var(--line,#E8DCC8);border-radius:12px;background:var(--card,#FFFDF8);color:var(--ink,#2A2024);font-family:inherit;font-size:13.5px;font-weight:500;line-height:1.2;text-decoration:none;cursor:pointer;transition:background .18s ease,border-color .18s ease,color .18s ease,transform .18s ease;}',
    '.pnav-btn svg,.pnav-logout svg{width:18px;height:18px;flex:none;}',
    '.pnav-btn:hover{background:var(--brand-light,#DFF4F6);border-color:var(--brand,#00A3B8);}',
    '.pnav-btn:active{transform:scale(.97);}',
    '.pnav-btn.active{background:var(--brand-deep,#3B1052);border-color:var(--brand-deep,#3B1052);color:#fff;}',
    '.pnav-btn:focus-visible,.pnav-logout:focus-visible{outline:3px solid var(--brand,#00A3B8);outline-offset:2px;}',
    '.pnav-logout:hover{background:var(--danger-bg,#F6E7E5);border-color:var(--danger,#A6423A);}',
    '@media (min-width:720px){.pnav-items{order:2;flex:1 1 auto;display:flex;flex-wrap:wrap;}.pnav-logout{order:3;}.pnav-btn{padding:10px 14px;}}',
    '@media (prefers-reduced-motion:reduce){.pnav-btn,.pnav-logout{transition:none;}.pnav-btn:active{transform:none;}}'
  ].join('\n');

  function level(){
    try{ var p = sessionStorage.getItem(TOKEN_KEY).split('.')[1]; return JSON.parse(atob(p.replace(/-/g,'+').replace(/_/g,'/'))).level || null; }catch(e){ return null; }
  }
  function currentPage(){ return location.pathname.split('/').pop() || 'index.html'; }

  function render(){
    var mount = document.getElementById('panitiaNav');
    if(!mount) return;
    var lv = level();
    if(!lv){ mount.innerHTML = ''; return; }
    var here = currentPage();
    var items = ITEMS.filter(function(i){ return !i.level || i.level === lv; });
    mount.innerHTML =
      '<nav class="pnav" aria-label="Navigasi panitia">' +
        '<span class="pnav-role">' + (lv === 'superadmin' ? 'Superadmin' : 'Admin') + '</span>' +
        '<div class="pnav-items">' +
          items.map(function(i){
            var active = i.href === here;
            return '<a class="pnav-btn' + (active ? ' active' : '') + '" href="' + i.href + '"' + (active ? ' aria-current="page"' : '') + '>' + ICON[i.icon] + '<span>' + i.label + '</span></a>';
          }).join('') +
        '</div>' +
        '<button type="button" class="pnav-logout" id="pnavLogout">' + ICON.logout + '<span>Keluar</span></button>' +
      '</nav>';
    document.getElementById('pnavLogout').addEventListener('click', function(){
      var pageLogout = document.getElementById('logoutBtn');
      if(pageLogout){ pageLogout.click(); return; }
      sessionStorage.removeItem(TOKEN_KEY);
      location.reload();
    });
  }

  var style = document.createElement('style');
  style.textContent = CSS;
  document.head.appendChild(style);

  window.PanitiaNav = { render: render };
})();
