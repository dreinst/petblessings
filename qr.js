// Pembuat QR bukti pendaftaran Pet Blessing 2026, dengan logo di tengah.
// Dipakai index.html (form), tiket.html (halaman yang terbuka kalau QR
// dipindai kamera HP), dan alat kirim-ulang. Butuh qrcodejs (window.QRCode)
// sudah dimuat sebelum build() dipanggil.
//
// Isi QR = tautan tiket (bukan UUID polos), supaya kamera HP biasa langsung
// menawarkan membuka tautan. Halaman check-in mengambil UUID dari tautan itu
// lewat extractOwnerId(), jadi QR lama yang berisi UUID polos tetap terbaca.
(function(){
  var TICKET_BASE = 'https://petblessings.vercel.app/tiket.html?id=';
  var LOGO_SRC = 'assets/pet-blessing-badge.png';
  var UUID_RE = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i;
  var logoPromise = null;

  function loadLogo(){
    if(!logoPromise){
      logoPromise = new Promise(function(resolve){
        var img = new Image();
        img.onload = function(){ resolve(img); };
        img.onerror = function(){ resolve(null); };
        img.src = LOGO_SRC;
      });
    }
    return logoPromise;
  }

  function ticketUrl(ownerId){ return TICKET_BASE + ownerId; }

  function extractOwnerId(text){
    var m = String(text || '').match(UUID_RE);
    return m ? m[0].toLowerCase() : null;
  }

  // Mengembalikan Promise berisi data URL PNG (null kalau gagal).
  // Koreksi kesalahan level H (30%) supaya logo di tengah (diameter ~26%
  // sisi, sekitar 5% luas) tidak mengganggu pembacaan.
  function build(ownerId, size, colorDark, colorLight){
    var dark = colorDark || '#000000', light = colorLight || '#FFFFFF';
    var hidden = document.createElement('div');
    try{
      new QRCode(hidden, { text: ticketUrl(ownerId), width: size, height: size, colorDark: dark, colorLight: light, correctLevel: QRCode.CorrectLevel.H });
    }catch(e){ return Promise.resolve(null); }
    var qrCanvas = hidden.querySelector('canvas');
    if(!qrCanvas) return Promise.resolve(null);
    return loadLogo().then(function(logo){
      var canvas = document.createElement('canvas');
      canvas.width = size; canvas.height = size;
      var ctx = canvas.getContext('2d');
      ctx.drawImage(qrCanvas, 0, 0, size, size);
      if(logo){
        var d = Math.round(size * 0.26), pad = Math.max(3, Math.round(size * 0.025));
        var cx = size / 2, cy = size / 2;
        ctx.save();
        ctx.beginPath(); ctx.arc(cx, cy, d / 2 + pad, 0, Math.PI * 2); ctx.fillStyle = light; ctx.fill();
        ctx.beginPath(); ctx.arc(cx, cy, d / 2, 0, Math.PI * 2); ctx.clip();
        ctx.drawImage(logo, cx - d / 2, cy - d / 2, d, d);
        ctx.restore();
      }
      return canvas.toDataURL('image/png');
    });
  }

  window.PetQr = { build: build, ticketUrl: ticketUrl, extractOwnerId: extractOwnerId };
})();
