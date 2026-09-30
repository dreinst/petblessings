// Bagian bersama halaman hari-H Pet Blessing (checkin, monitor, panggil,
// layar-panggil, kendali): login superadmin, akses API, status server.
// Halaman yang sama jalan di Vercel (API VPS) dan di server lokal Mac
// (API lokal, lihat lokal/server.js yang mengganti api-config.js).
//
// Pakai: <div id="loginWrap"></div> + <div id="appWrap" hidden> di halaman,
// lalu HariH.mulai(function(){ ...halaman siap... }).
(function(){
  var TOKEN_KEY = 'petblessing_panitia_token';
  var q = new URLSearchParams(location.search);
  var H = window.HariH = {
    API: window.PETBLESSING_API_URL,
    LOKAL: window.PB_SERVER === 'lokal',
    UJI: q.get('uji') === '1',
    param: function(k){ return q.get(k); }
  };

  // Token disimpan juga di localStorage supaya layar monitor yang dimuat ulang
  // tidak perlu login lagi (token berlaku 12 jam).
  H.token = function(){ return sessionStorage.getItem(TOKEN_KEY) || localStorage.getItem(TOKEN_KEY); };
  function simpanToken(t){ sessionStorage.setItem(TOKEN_KEY, t); localStorage.setItem(TOKEN_KEY, t); }
  H.keluar = function(){ sessionStorage.removeItem(TOKEN_KEY); localStorage.removeItem(TOKEN_KEY); location.reload(); };
  function klaim(){
    try{ var p = H.token().split('.')[1]; return JSON.parse(atob(p.replace(/-/g,'+').replace(/_/g,'/'))); }catch(e){ return null; }
  }

  H.esc = function(s){
    return String(s == null ? '' : s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
  };
  H.jam = function(iso){
    try{ return new Date(iso).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }); }catch(e){ return ''; }
  };

  // Panggil PostgREST. Error dari database (misal "Server ini sedang tidak
  // memberi nomor") dikembalikan sebagai Error dengan pesan yang bisa dibaca.
  H.api = async function(path, body, method){
    var res = await fetch(H.API + path, {
      method: method || (body ? 'POST' : 'GET'),
      headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + H.token() },
      body: body ? JSON.stringify(body) : undefined,
      signal: AbortSignal.timeout ? AbortSignal.timeout(10000) : undefined
    });
    if(res.status === 401){ H.keluar(); throw new Error('Sesi habis, silakan login lagi'); }
    var text = await res.text();
    var data = text ? JSON.parse(text) : null;
    if(!res.ok) throw new Error((data && (data.message || data.error)) || ('HTTP ' + res.status));
    return data;
  };
  H.rpc = function(fn, body){ return H.api('/rpc/' + fn, body || {}); };
  H.status = function(recent){ return H.rpc('hari_h_status', { p_uji: H.UJI, p_recent: recent || 10 }); };

  // Label server di pojok halaman: petugas harus tahu sedang di server mana.
  H.labelServer = function(st){
    var el = document.getElementById('serverBadge');
    if(!el) return;
    var nama = H.LOKAL ? 'Server lokal' : 'Server online';
    var aktif = st && st.pemberi_nomor;
    el.className = 'server-badge ' + (aktif ? 'on' : 'off');
    el.textContent = nama + (aktif ? ' (aktif memberi nomor)' : ' (tidak memberi nomor)') + (H.UJI ? ' · MODE UJI' : '');
  };

  function formLogin(){
    var w = document.getElementById('loginWrap');
    w.hidden = false;
    w.innerHTML =
      '<form class="login-card" id="hhLogin">' +
        '<img src="assets/pet-blessing-badge.png" alt="" class="login-badge">' +
        '<h1>Login panitia</h1>' +
        '<p>Khusus superadmin. ' + (H.LOKAL ? 'Ini server lokal di lokasi.' : 'Ini server online.') + '</p>' +
        '<label for="hhUser">Username</label><input id="hhUser" autocomplete="username" required>' +
        '<label for="hhPass">Password</label><input id="hhPass" type="password" autocomplete="current-password" required>' +
        '<button type="submit">Masuk</button><div class="login-error" id="hhErr"></div>' +
      '</form>';
    document.getElementById('hhLogin').addEventListener('submit', async function(e){
      e.preventDefault();
      var btn = this.querySelector('button'), err = document.getElementById('hhErr');
      btn.disabled = true; btn.textContent = 'Memeriksa...'; err.textContent = '';
      try{
        var res = await fetch('/api/login', { method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ username: document.getElementById('hhUser').value.trim(), password: document.getElementById('hhPass').value }) });
        var data = await res.json().catch(function(){ return {}; });
        if(!res.ok || !data.token) throw new Error(data.error || 'Username atau password salah');
        if(data.level !== 'superadmin') throw new Error('Halaman ini khusus superadmin');
        simpanToken(data.token);
        location.reload();
      }catch(ex){ err.textContent = ex.message; }
      finally{ btn.disabled = false; btn.textContent = 'Masuk'; }
    });
  }

  H.mulai = function(siap){
    if(!H.API){ document.body.innerHTML = '<p style="padding:24px">API belum dikonfigurasi.</p>'; return; }
    var k = klaim();
    if(!k || k.level !== 'superadmin' || (k.exp && k.exp * 1000 < Date.now())){ formLogin(); return; }
    document.getElementById('loginWrap').hidden = true;
    document.getElementById('appWrap').hidden = false;
    var out = document.querySelectorAll('[data-keluar]');
    for(var i = 0; i < out.length; i++) out[i].addEventListener('click', H.keluar);
    siap();
  };

  // Ulangi fn tiap ms, tanpa menumpuk kalau jaringan lambat.
  H.ulang = function(fn, ms){
    var jalan = false;
    async function t(){ if(jalan) return; jalan = true; try{ await fn(); }catch(e){} finally{ jalan = false; } }
    t(); return setInterval(t, ms);
  };

  H.bunyi = function(freq, ms){
    try{
      var Ctx = window.AudioContext || window.webkitAudioContext, ctx = new Ctx();
      var o = ctx.createOscillator(), g = ctx.createGain();
      o.frequency.value = freq; o.connect(g); g.connect(ctx.destination);
      g.gain.setValueAtTime(0.2, ctx.currentTime);
      o.start(); o.stop(ctx.currentTime + ms / 1000); o.onended = function(){ ctx.close(); };
    }catch(e){}
  };
})();
