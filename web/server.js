// MoreEyes Web - schlanke, passwortgeschuetzte Oberflaeche fuer den lokalen Kamera-Livestream.
// go2rtc selbst hat keinen Port im LAN offen (ausser dem WebRTC-Medienport): API, WebSocket-
// Signalisierung und die Seite laufen ausschliesslich hinter diesem authentifizierten Server.
'use strict';
const path = require('path');
const fs = require('fs');
const express = require('express');
const cookieParser = require('cookie-parser');
const { createProxyMiddleware } = require('http-proxy-middleware');
const { issueCookie, clearCookie, authMiddleware, safeEqual, usernameFromCookieHeader } = require('./auth');

const PORT = parseInt(process.env.WEB_PORT || '3000', 10);
const ADMIN_USER = process.env.ADMIN_USER;
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD;
const SESSION_SECRET = process.env.SESSION_SECRET;
const GO2RTC_URL = process.env.GO2RTC_URL || 'http://go2rtc:1984';

for (const [k, v] of Object.entries({ ADMIN_USER, ADMIN_PASSWORD, SESSION_SECRET })) {
  if (!v) { console.error(`FEHLER: ${k} fehlt in der Umgebung (.env).`); process.exit(1); }
}

const cameras = JSON.parse(fs.readFileSync(path.join(__dirname, 'config', 'cameras.json'), 'utf8'));
const requireAuth = authMiddleware(SESSION_SECRET);
const publicDir = path.join(__dirname, 'public');

const app = express();
app.disable('x-powered-by');
app.use(cookieParser());
app.use(express.json());

// --- Login (einziger Bereich ohne Auth-Pflicht) ---------------------------------------------
app.get('/login', (req, res) => res.sendFile(path.join(publicDir, 'login.html')));

app.post('/api/login', (req, res) => {
  const { username, password } = req.body || {};
  const ok = typeof username === 'string' && typeof password === 'string'
    && safeEqual(username, ADMIN_USER) && safeEqual(password, ADMIN_PASSWORD);
  if (!ok) return res.status(401).json({ error: 'Benutzername oder Passwort falsch' });
  issueCookie(res, SESSION_SECRET, username);
  res.json({ ok: true });
});

app.post('/api/logout', (req, res) => { clearCookie(res); res.json({ ok: true }); });

// --- Ab hier: alles nur mit gueltiger Session ------------------------------------------------
app.use(requireAuth);

app.get('/api/cameras', (req, res) => res.json(cameras));
app.get('/api/me', (req, res) => res.json({ user: req.user }));

// go2rtc ist im internen Compose-Netzwerk ohne eigenen Host-Port erreichbar; dieser Proxy ist
// der einzige Weg dorthin (HTTP-Teil der API, z.B. /api/go2rtc/streams). Der WebSocket-Teil
// (/api/ws, fuer den Live-Player) wird unten separat behandelt, weil Express WS-Upgrades
// nicht durch die normale Middleware-Kette laufen laesst.
app.use('/api/go2rtc', createProxyMiddleware({
  target: GO2RTC_URL, changeOrigin: true, pathRewrite: { '^/api/go2rtc': '/api' },
}));

app.get('/', (req, res) => res.sendFile(path.join(publicDir, 'index.html')));
app.use(express.static(publicDir, { index: false }));

// go2rtc prueft bei WebSockets, ob der Origin-Header zu seinem eigenen Host passt (CSRF-Schutz).
// Da der Browser mit unserem Origin (Caddy/Web) verbindet, muessen wir den Origin-Header beim
// Weiterreichen an go2rtc auf dessen eigene Adresse setzen - sonst lehnt go2rtc jede Verbindung ab.
const wsProxy = createProxyMiddleware({
  target: GO2RTC_URL, ws: true, changeOrigin: true, logLevel: 'warn',
  onProxyReqWs: (proxyReq) => proxyReq.setHeader('origin', GO2RTC_URL),
});

const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`MoreEyes Web hoert auf Port ${PORT} (go2rtc: ${GO2RTC_URL})`);
});

// Roher WebSocket-Upgrade fuer /api/ws: Auth-Pruefung hier, weil Express-Middleware hier nicht greift.
server.on('upgrade', (req, socket, head) => {
  if (!req.url.startsWith('/api/ws')) { socket.destroy(); return; }
  const user = usernameFromCookieHeader(req.headers.cookie, SESSION_SECRET);
  if (!user) { socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n'); socket.destroy(); return; }
  wsProxy.upgrade(req, socket, head);
});
