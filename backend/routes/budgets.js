const express = require('express');
const db      = require('../config/db');
const auth    = require('../middleware/auth');

const router = express.Router();
router.use(auth);

// GET /api/budgets?month=4&year=2025
router.get('/', async (req, res) => {
    const { month, year } = req.query;
    const user_id = req.user.user_id;

    const now = new Date();
    const m = month || now.getMonth() + 1;
    const y = year  || now.getFullYear();

    try {
        const [rows] = await db.query(
            `SELECT b.*, c.name AS category_name, c.icon, c.color,
                    COALESCE(
                        (SELECT SUM(t.amount) FROM transactions t
                         WHERE t.user_id = b.user_id AND t.category_id = b.category_id
                           AND MONTH(t.transaction_date) = b.month
                           AND YEAR(t.transaction_date) = b.year
                           AND t.type = 'expense'), 0
                    ) AS actual_spent
             FROM budgets b
             JOIN categories c ON b.category_id = c.category_id
             WHERE b.user_id = ? AND b.month = ? AND b.year = ?
             ORDER BY c.name`,
            [user_id, m, y]
        );
        res.json({ budgets: rows });
    } catch (err) {
        res.status(500).json({ error: 'Failed to fetch budgets.' });
    }
});

// POST /api/budgets
router.post('/', async (req, res) => {
    const { category_id, amount, month, year } = req.body;
    const user_id = req.user.user_id;

    if (!category_id || !amount || !month || !year)
        return res.status(400).json({ error: 'category_id, amount, month, year required.' });

    // Verify category ownership
    const [cat] = await db.query(
        'SELECT category_id FROM categories WHERE category_id = ? AND user_id = ?',
        [category_id, user_id]
    );
    if (cat.length === 0) return res.status(403).json({ error: 'Category not found.' });

    try {
        await db.query(
            `INSERT INTO budgets (user_id, category_id, amount, month, year)
             VALUES (?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE amount = ?`,
            [user_id, category_id, amount, month, year, amount]
        );
        res.status(201).json({ message: 'Budget set!' });
    } catch (err) {
        res.status(500).json({ error: 'Failed to set budget.' });
    }
});

// DELETE /api/budgets/:id
router.delete('/:id', async (req, res) => {
    const [result] = await db.query(
        'DELETE FROM budgets WHERE budget_id = ? AND user_id = ?',
        [req.params.id, req.user.user_id]
    );
    if (result.affectedRows === 0)
        return res.status(404).json({ error: 'Budget not found.' });
    res.json({ message: 'Budget removed.' });
});

module.exports = router;
