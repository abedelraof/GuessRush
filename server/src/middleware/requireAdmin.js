const jwt = require('jsonwebtoken');
const env = require('../config/env');

// For the server-rendered /admin panel: reads the httpOnly `admin_token` cookie.
function requireAdmin(req, res, next) {
  const token = req.cookies && req.cookies.admin_token;
  if (!token) return res.redirect('/admin/login');
  try {
    const payload = jwt.verify(token, env.jwtSecret);
    if (payload.role !== 'admin') return res.redirect('/admin/login');
    req.admin = payload;
    next();
  } catch (err) {
    res.redirect('/admin/login');
  }
}

module.exports = { requireAdmin };
