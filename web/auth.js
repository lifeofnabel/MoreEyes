// Minimale, abhaengigkeitsfreie Session-Cookies (HMAC-signiert, 7 Tage gueltig).
// Kein externer Login-Anbieter, keine Datenbank - passend fuer einen einzelnen Admin-Account.
'use strict';
const crypto = require('crypto');

const COOKIE_NAME = 'moreeyes_session';
const MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000; // 7 Tage, siehe Sprint-2-Antwort #8

function sign(payload, secret) {
  const data = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const mac = crypto.createHmac('sha256', secret).update(data).digest('base64url');
  return `${data}.${mac}`;
}

function verify(token, secret) {
  if (!token || typeof token !== 'string' || !token.includes('.')) return null;
  const [data, mac] = token.split('.');
  const expected = crypto.createHmac('sha256', secret).update(data).digest('base64url');
  const a = Buffer.from(mac || '');
  const b = Buffer.from(expected);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return null;
  try {
    const payload = JSON.parse(Buffer.from(data, 'base64url').toString('utf8'));
    if (!payload.exp || Date.now() > payload.exp) return null;
    return payload;
  } catch {
    return null;
  }
}

// Laengenunabhaengiger Vergleich, damit die Antwortzeit das Passwort nicht verraet.
function safeEqual(a, b) {
  const ab = Buffer.from(String(a));
  const bb = Buffer.from(String(b));
  if (ab.length !== bb.length) {
    // Dummy-Vergleich gleicher Laenge, damit die Dauer nicht von der echten Laenge abhaengt.
    crypto.timingSafeEqual(ab, ab);
    return false;
  }
  return crypto.timingSafeEqual(ab, bb);
}

function issueCookie(res, secret, username) {
  const token = sign({ u: username, exp: Date.now() + MAX_AGE_MS }, secret);
  res.cookie(COOKIE_NAME, token, {
    httpOnly: true,
    sameSite: 'lax',
    maxAge: MAX_AGE_MS,
    secure: false, // Sprint 2: reines HTTP im LAN (Antwort #4); bei spaeterem HTTPS auf true stellen
  });
}

function clearCookie(res) {
  res.clearCookie(COOKIE_NAME);
}

function authMiddleware(secret) {
  return (req, res, next) => {
    const session = verify(req.cookies?.[COOKIE_NAME], secret);
    if (!session) {
      if (req.path.startsWith('/api/')) return res.status(401).json({ error: 'nicht angemeldet' });
      return res.redirect('/login');
    }
    req.user = session.u;
    next();
  };
}

// Fuer den rohen WebSocket-Upgrade (laeuft ausserhalb der Express-Middleware-Kette).
function usernameFromCookieHeader(cookieHeader, secret) {
  if (!cookieHeader) return null;
  const match = cookieHeader.split(';').map(s => s.trim()).find(s => s.startsWith(`${COOKIE_NAME}=`));
  if (!match) return null;
  const token = decodeURIComponent(match.slice(COOKIE_NAME.length + 1));
  const session = verify(token, secret);
  return session ? session.u : null;
}

module.exports = { issueCookie, clearCookie, authMiddleware, safeEqual, usernameFromCookieHeader, COOKIE_NAME };
