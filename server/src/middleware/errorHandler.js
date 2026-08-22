const ApiError = require('../utils/ApiError');

module.exports = function errorHandler(err, req, res, next) {
  if (err instanceof ApiError) {
    return res.status(err.status).json({ error: err.message });
  }
  if (err && err.code === 'ER_DUP_ENTRY') {
    return res.status(409).json({ error: 'Already recorded' });
  }
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
};
