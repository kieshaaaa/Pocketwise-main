const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const db = require('../config/db');
const auth = require('../middleware/auth');

const router = express.Router();

// ─── POST /api/auth/register ─────────────────────────────────
router.post('/register', async (req, res) => {
    const { name, email, password } = req.body;

    if (!name || !email || !password)
        return res.status(400).json({ error: 'Name, email, and password are required.' });

    if (password.length < 6)
        return res.status(400).json({ error: 'Password must be at least 6 characters.' });

    try {
        // Check if email already exists
        const [existing] = await db.query('SELECT user_id FROM users WHERE email = ?', [email]);
        if (existing.length > 0)
            return res.status(409).json({ error: 'Email already registered.' });

        // Hash password
        const password_hash = await bcrypt.hash(password, 10);

        // Insert user
        await db.query(
            'INSERT INTO users (name, email, password_hash) VALUES (?, ?, ?)',
            [name.trim(), email.toLowerCase().trim(), password_hash]
        );

        // Fetch the actual user_id (UUID) back from DB
        const [newUser] = await db.query(
            'SELECT user_id FROM users WHERE email = ?',
            [email.toLowerCase().trim()]
        );
        const user_id = newUser[0].user_id;

        // Call stored procedure to create default categories
        await db.query('CALL create_default_categories(?)', [user_id]);

        // Generate JWT
        const token = jwt.sign(
            { user_id, email: email.toLowerCase(), name: name.trim() },
            process.env.JWT_SECRET,
            { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
        );

        res.status(201).json({
            message: 'Account created successfully!',
            token,
            user: { user_id, name: name.trim(), email: email.toLowerCase() }
        });

    } catch (err) {
        console.error('Register error:', err);
        res.status(500).json({ error: 'Server error. Please try again.' });
    }
});

// ─── POST /api/auth/login ─────────────────────────────────────
router.post('/login', async (req, res) => {
    const { email, password } = req.body;

    if (!email || !password)
        return res.status(400).json({ error: 'Email and password are required.' });

    try {
        const [rows] = await db.query(
            'SELECT user_id, name, email, password_hash FROM users WHERE email = ?',
            [email.toLowerCase().trim()]
        );

        if (rows.length === 0)
            return res.status(401).json({ error: 'Invalid email or password.' });

        const user = rows[0];
        const isValid = await bcrypt.compare(password, user.password_hash);

        if (!isValid)
            return res.status(401).json({ error: 'Invalid email or password.' });

        const token = jwt.sign(
            { user_id: user.user_id, email: user.email, name: user.name },
            process.env.JWT_SECRET,
            { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
        );

        res.json({
            message: 'Login successful!',
            token,
            user: { user_id: user.user_id, name: user.name, email: user.email }
        });

    } catch (err) {
        console.error('Login error:', err);
        res.status(500).json({ error: 'Server error. Please try again.' });
    }
});

// ─── PUT /api/auth/change-password ───────────────────────────
router.put('/change-password', auth, async (req, res) => {
    const { current_password, new_password } = req.body;

    if (!current_password || !new_password)
        return res.status(400).json({ error: 'Current and new password are required.' });

    if (new_password.length < 6)
        return res.status(400).json({ error: 'New password must be at least 6 characters.' });

    try {
        const [rows] = await db.query(
            'SELECT password_hash FROM users WHERE user_id = ?',
            [req.user.user_id]
        );
        if (rows.length === 0)
            return res.status(404).json({ error: 'User not found.' });

        const isValid = await bcrypt.compare(current_password, rows[0].password_hash);
        if (!isValid)
            return res.status(401).json({ error: 'Current password is incorrect.' });

        const new_hash = await bcrypt.hash(new_password, 10);
        await db.query(
            'UPDATE users SET password_hash = ? WHERE user_id = ?',
            [new_hash, req.user.user_id]
        );

        res.json({ message: 'Password changed successfully.' });
    } catch (err) {
        console.error('Change password error:', err);
        res.status(500).json({ error: 'Server error. Please try again.' });
    }
});

// ─── GET /api/auth/me ─────────────────────────────────────────
// Returns current logged-in user info (requires token)
router.get('/me', auth, async (req, res) => {
    try {
        const [rows] = await db.query(
            'SELECT user_id, name, email, created_at FROM users WHERE user_id = ?',
            [req.user.user_id]
        );

        if (rows.length === 0)
            return res.status(404).json({ error: 'User not found.' });

        res.json({ user: rows[0] });
    } catch (err) {
        res.status(500).json({ error: 'Server error.' });
    }
});

module.exports = router;