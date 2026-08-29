const { WebSocketServer } = require('ws');
const { URL } = require('url');
const jwt = require('jsonwebtoken');
const env = require('../config/env');
const { DISCONNECT_GRACE_MS } = require('../config/match.config');

// playerId -> live WebSocket connection. At most one live connection per
// player — a fresh connection (e.g. app foregrounded again) simply replaces
// whatever was there, which is also what cancels a pending forfeit timer below.
const connections = new Map();

// playerId -> pending forfeit Timeout, running only while that player is
// currently disconnected and within their grace window.
const disconnectTimers = new Map();

// Set by matchProgress.service.js — kept as an injected callback (rather than
// this module requiring that one directly) purely to avoid a require() cycle,
// since matchProgress.service.js needs to call back into this module too.
let onGraceExpired = () => {};

function setGraceExpiredHandler(handler) {
  onGraceExpired = handler;
}

function attach(server) {
  const wss = new WebSocketServer({ server, path: '/ws' });

  wss.on('connection', (ws, req) => {
    let payload;
    try {
      const { searchParams } = new URL(req.url, 'http://localhost');
      payload = jwt.verify(searchParams.get('token') || '', env.jwtSecret);
    } catch (err) {
      ws.close(4001, 'Invalid or expired token');
      return;
    }

    const playerId = payload.id;

    const pendingTimer = disconnectTimers.get(playerId);
    if (pendingTimer) {
      clearTimeout(pendingTimer);
      disconnectTimers.delete(playerId);
    }
    connections.set(playerId, ws);

    ws.on('close', () => {
      // A reconnect may have already replaced this connection in the map —
      // only start a grace timer if this closing socket is still the one on record.
      if (connections.get(playerId) !== ws) return;
      connections.delete(playerId);
      const timer = setTimeout(() => {
        disconnectTimers.delete(playerId);
        onGraceExpired(playerId);
      }, DISCONNECT_GRACE_MS);
      disconnectTimers.set(playerId, timer);
    });
  });

  return wss;
}

/** Sends `event` (any JSON-serializable object) to `playerId` if they're currently connected. Returns whether it was actually delivered. */
function sendToPlayer(playerId, event) {
  const ws = connections.get(playerId);
  if (!ws || ws.readyState !== ws.OPEN) return false;
  ws.send(JSON.stringify(event));
  return true;
}

function isConnected(playerId) {
  const ws = connections.get(playerId);
  return Boolean(ws && ws.readyState === ws.OPEN);
}

module.exports = { attach, sendToPlayer, isConnected, setGraceExpiredHandler };
