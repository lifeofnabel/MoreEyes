import { VideoRTC } from '/vendor/video-rtc.js';
customElements.define('video-rtc', VideoRTC);

const grid = document.getElementById('grid');
const emptyHint = document.getElementById('emptyHint');
const whoami = document.getElementById('whoami');
const logoutBtn = document.getElementById('logout');

logoutBtn.addEventListener('click', async () => {
  await fetch('/api/logout', { method: 'POST' });
  location.href = '/login';
});

function setBadge(badge, state) {
  badge.className = 'badge ' + state;
  badge.textContent = { wait: 'Verbindung…', live: 'Live', err: 'Verbindung verloren – erneuter Versuch…' }[state] || state;
}

function buildTile(cam) {
  const tile = document.createElement('div');
  tile.className = 'tile';

  const wrap = document.createElement('div');
  wrap.className = 'video-wrap';

  const player = document.createElement('video-rtc');
  // Sprint-2-Antwort #6: Substream ist Standard (fluessiger, weniger Bandbreite im LAN).
  let currentQuality = 'sd';

  const badge = document.createElement('span');
  setBadge(badge, 'wait');

  wrap.append(player, badge);

  const footer = document.createElement('div');
  footer.className = 'tile-footer';

  const label = document.createElement('span');
  label.className = 'label';
  label.textContent = cam.label;

  const controls = document.createElement('div');
  controls.className = 'controls';

  const qualityBtn = document.createElement('button');
  qualityBtn.textContent = 'HD anzeigen';
  qualityBtn.title = 'Zwischen Haupt- und Substream wechseln';

  const muteBtn = document.createElement('button');
  // Sprint-2-Antwort #7: Ton ist standardmaessig an (Browser kann Autoplay mit Ton blockieren,
  // video-rtc faellt dann automatisch auf stumm zurueck - der Knopf schaltet wieder frei).
  muteBtn.textContent = '🔊 Ton';

  controls.append(qualityBtn, muteBtn);
  footer.append(label, controls);
  tile.append(wrap, footer);

  function connect(quality) {
    currentQuality = quality;
    const streamName = cam.streams[quality];
    setBadge(badge, 'wait');
    player.src = `/api/ws?src=${encodeURIComponent(streamName)}`;
    qualityBtn.textContent = quality === 'sd' ? 'HD anzeigen' : 'SD anzeigen (sparsamer)';
  }

  qualityBtn.addEventListener('click', () => connect(currentQuality === 'sd' ? 'hd' : 'sd'));

  muteBtn.addEventListener('click', () => {
    const v = player.video;
    if (!v) return;
    v.muted = !v.muted;
    if (!v.muted) player.play();
    muteBtn.textContent = v.muted ? '🔇 Ton aus' : '🔊 Ton';
  });

  // Status aus dem zugrundeliegenden <video>-Element ableiten (video-rtc feuert keine eigenen Events).
  const watchVideo = () => {
    const v = player.video;
    if (!v) { requestAnimationFrame(watchVideo); return; }
    v.addEventListener('playing', () => setBadge(badge, 'live'));
    v.addEventListener('waiting', () => setBadge(badge, 'wait'));
    v.addEventListener('stalled', () => setBadge(badge, 'err'));
    v.addEventListener('emptied', () => setBadge(badge, 'wait'));
    v.addEventListener('error', () => setBadge(badge, 'err'));
  };
  requestAnimationFrame(watchVideo);

  connect(cam.defaultStream === cam.streams.hd ? 'hd' : 'sd');
  return tile;
}

async function init() {
  const me = await fetch('/api/me').then(r => (r.ok ? r.json() : null)).catch(() => null);
  if (me) whoami.textContent = `· angemeldet als ${me.user}`;

  const cameras = await fetch('/api/cameras').then(r => r.json()).catch(() => []);
  if (!cameras.length) { emptyHint.hidden = false; return; }
  for (const cam of cameras) grid.appendChild(buildTile(cam));
}

init();
