const app = require('./app');
const env = require('./config/env');
const { sweepStaleTempAudio } = require('./utils/audioStorage');
const { sweepStaleTempImages } = require('./utils/imageStorage');
const { sweepStaleTempVideo } = require('./utils/videoStorage');
const realtimeService = require('./services/realtime.service');
const matchmakingService = require('./services/matchmaking.service');
// Registers matchmaking.service.js's disconnect-forfeit handler with realtime.service.js
// as a side effect of being required — see that file's own comment for why.
require('./services/matchProgress.service');

sweepStaleTempAudio();
sweepStaleTempImages();
sweepStaleTempVideo();

const server = app.listen(env.port, () => {
  console.log(`GuessRush API listening on port ${env.port}`);
});

realtimeService.attach(server);

// Evicts players who've been waiting in the random-match queue too long (see
// match.config.js's QUEUE_TIMEOUT_MS) and tells them so over the socket, if
// they're still connected to hear it.
setInterval(() => {
  const evicted = matchmakingService.sweepQueue();
  for (const playerId of evicted) {
    realtimeService.sendToPlayer(playerId, { type: 'queue:timeout' });
  }
}, 5000);
