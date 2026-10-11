(function () {
  // Real screenshots. Once a file is in assets/screens/, list it here and that phone shows
  // the file instead of the HTML mockup. The key is the data-screen name without "scr-"
  // (plus "-dark" for a phone with class "dk"); the value is the file name.
  // Example: links: 'links.webp'
  var SHOTS = {};

  // Phone mockups: each [data-screen] slot is filled from its <template>, then its nav bar.
  document.querySelectorAll('[data-screen]').forEach(function (el) {
    var key = el.getAttribute('data-screen').replace(/^scr-/, '') + (el.classList.contains('dk') ? '-dark' : '');
    if (SHOTS[key]) {
      var img = new Image();
      img.alt = el.getAttribute('aria-label') || '';
      img.decoding = 'async';
      img.src = 'assets/screens/' + SHOTS[key];
      el.classList.add('shot');
      el.removeAttribute('role');
      el.removeAttribute('aria-label');
      el.appendChild(img);
      return;
    }
    var t = document.getElementById(el.getAttribute('data-screen'));
    if (!t) return;
    el.appendChild(t.content.cloneNode(true));
    el.querySelectorAll('slot[data-nav]').forEach(function (s) {
      s.replaceWith(document.getElementById(s.getAttribute('data-nav')).content.cloneNode(true));
    });
  });

  // Theme toggle. Follows the system until the visitor picks one.
  var root = document.documentElement;
  var btn = document.getElementById('theme');
  if (!btn) return;
  function isDark() {
    var t = root.getAttribute('data-theme');
    if (t) return t === 'dark';
    return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
  }
  function sync() {
    var dark = isDark();
    btn.setAttribute('aria-pressed', String(dark));
    btn.setAttribute('aria-label', dark ? 'Switch to light mode' : 'Switch to dark mode');
    btn.querySelector('use').setAttribute('href', dark ? '#i-sun' : '#i-moon');
  }
  btn.addEventListener('click', function () {
    var next = isDark() ? 'light' : 'dark';
    root.setAttribute('data-theme', next);
    try { localStorage.setItem('lh-theme', next); } catch (e) { /* storage blocked: theme still applies for this visit */ }
    sync();
  });
  sync();
})();
