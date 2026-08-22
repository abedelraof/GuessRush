const app = require('./app');
const env = require('./config/env');
const { sweepStaleTempAudio } = require('./utils/audioStorage');
const { sweepStaleTempImages } = require('./utils/imageStorage');

sweepStaleTempAudio();
sweepStaleTempImages();

app.listen(env.port, () => {
  console.log(`GuessRush API listening on port ${env.port}`);
});
