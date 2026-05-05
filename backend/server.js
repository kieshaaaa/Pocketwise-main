const express = require('express');
const cors    = require('cors');
require('dotenv').config();

const app = express();

// ─── Middleware ───────────────────────────────────────────────
app.use(cors({
    origin: ['http://localhost:3000', 'http://127.0.0.1:5500', 'https://pocketwise-production.up.railway.app', 'https://pocketwise-eta.vercel.app'],
    credentials: true
}));
app.use(express.json());

// ─── Routes ──────────────────────────────────────────────────
app.use('/api/auth',         require('./routes/auth'));
app.use('/api/transactions', require('./routes/transactions'));
app.use('/api/categories',   require('./routes/categories'));
app.use('/api/budgets',      require('./routes/budgets'));
app.use('/api/savings',      require('./routes/savings'));

// ─── Health Check ─────────────────────────────────────────────
app.get('/api/health', (req, res) => {
    res.json({ status: 'ok', message: 'PocketWise API is running 🚀' });
});

// ─── 404 Handler ──────────────────────────────────────────────
app.use((req, res) => {
    res.status(404).json({ error: 'Route not found.' });
});

// ─── Error Handler ────────────────────────────────────────────
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({ error: 'Something went wrong.' });
});

// ─── Start Server ─────────────────────────────────────────────
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
    console.log(`🚀 PocketWise server running on http://localhost:${PORT}`);
});
