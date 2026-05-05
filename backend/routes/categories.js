// ============================================================
// categories.js
// ============================================================
const express = require('express');
const db      = require('../config/db');
const auth    = require('../middleware/auth');

const router = express.Router();
router.use(auth);

router.get('/', async (req, res) => {
    const [rows] = await db.query(
        'SELECT * FROM categories WHERE user_id = ? ORDER BY name',
        [req.user.user_id]
    );
    res.json({ categories: rows });
});

router.post('/', async (req, res) => {
    const { name, icon, color } = req.body;
    if (!name) return res.status(400).json({ error: 'Category name is required.' });

    try {
        const [result] = await db.query(
            'INSERT INTO categories (user_id, name, icon, color) VALUES (?, ?, ?, ?)',
            [req.user.user_id, name, icon || '💰', color || '#6366f1']
        );
        res.status(201).json({ message: 'Category created!', category_id: result.insertId });
    } catch (err) {
        if (err.code === 'ER_DUP_ENTRY')
            return res.status(409).json({ error: 'Category already exists.' });
        res.status(500).json({ error: 'Failed to create category.' });
    }
});

router.delete('/:id', async (req, res) => {
    const [result] = await db.query(
        'DELETE FROM categories WHERE category_id = ? AND user_id = ?',
        [req.params.id, req.user.user_id]
    );
    if (result.affectedRows === 0)
        return res.status(404).json({ error: 'Category not found.' });
    res.json({ message: 'Category deleted.' });
});

module.exports = router;
