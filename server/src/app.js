const path = require('path');
const express = require('express');
const cors = require('cors');
const cookieParser = require('cookie-parser');

const authRoutes = require('./routes/auth.routes');
const categoriesRoutes = require('./routes/categories.routes');
const sessionsRoutes = require('./routes/sessions.routes');
const leaderboardRoutes = require('./routes/leaderboard.routes');
const profileRoutes = require('./routes/profile.routes');
const dailyRushRoutes = require('./routes/dailyRush.routes');
const homeRoutes = require('./routes/home.routes');
const adminRoutes = require('./routes/admin.routes');
const errorHandler = require('./middleware/errorHandler');

const app = express();

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

app.use(cors());
app.use(express.json());
// Bumped from the 100kb default so admin bulk-JSON question imports can go through as a
// normal urlencoded form field (see admin/questions/import) without needing multipart upload.
app.use(express.urlencoded({ extended: true, limit: '15mb' }));
app.use(cookieParser());
app.use('/public', express.static(path.join(__dirname, '..', 'public')));

app.get('/api/health', (req, res) => res.json({ status: 'ok' }));

app.use('/api/auth', authRoutes);
app.use('/api/categories', categoriesRoutes);
app.use('/api/sessions', sessionsRoutes);
app.use('/api/leaderboard', leaderboardRoutes);
app.use('/api/profile', profileRoutes);
app.use('/api/daily-rush', dailyRushRoutes);
app.use('/api/home', homeRoutes);

app.use('/admin', adminRoutes);

app.use(errorHandler);

module.exports = app;
