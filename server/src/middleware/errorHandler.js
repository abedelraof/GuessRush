const ApiError = require('../utils/ApiError');

module.exports = function errorHandler(err, req, res, next) {
  if (err instanceof ApiError) {
    return res.status(err.status).json({ error: err.message });
  }
  if (err && err.code === 'ER_DUP_ENTRY') {
    return res.status(409).json({ error: 'Already recorded' });
  }
  // express.json() throws this SyntaxError for a request body that isn't
  // valid JSON — a client bug, not a server fault, so it gets a clean 400
  // like any other bad-input error instead of falling through to a raw 500.
  if (err instanceof SyntaxError && err.status === 400 && 'body' in err) {
    return res.status(400).json({ error: 'Malformed JSON in request body' });
  }
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
};
