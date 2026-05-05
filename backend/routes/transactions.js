const express = require('express');
const db = require('../config/db');
const auth = require('../middleware/auth');

const router = express.Router();
router.use(auth);

// ─── GET /api/transactions/summary ───────────────────────────
router.get('/summary', async (req, res) => {
    const { month, year } = req.query;
    const user_id = req.user.user_id;

    try {
        const [rows] = await db.query(
            'CALL get_monthly_summary(?, ?, ?)',
            [user_id, month, year]
        );
        const result = rows[0][0];
        const total_income = result?.total_income ?? 0;
        const total_expense = result?.total_expense ?? 0;
        const net_balance = result?.net_balance ?? 0; res.json({ income: total_income, expense: total_expense, balance: net_balance });
    } catch (err) {
        res.status(500).json({ error: 'Failed to fetch summary.' });
    }
});

// ─── GET /api/transactions/breakdown ─────────────────────────
router.get('/breakdown', async (req, res) => {
    const { month, year } = req.query;
    const user_id = req.user.user_id;

    if (!month || !year)
        return res.status(400).json({ error: 'month and year are required.' });

    try {
        const [rows] = await db.query(
            'CALL get_category_breakdown(?, ?, ?)',
            [user_id, month, year]
        );
        res.json({ breakdown: rows[0] });
    } catch (err) {
        res.status(500).json({ error: 'Failed to fetch breakdown.' });
    }
});

// ─── GET /api/transactions ────────────────────────────────────
router.get('/', async (req, res) => {
    const { month, year, type, category_id, limit = 50 } = req.query;
    const user_id = req.user.user_id;

    let query = `
        SELECT t.*, c.name AS category_name, c.icon, c.color
        FROM transactions t
        LEFT JOIN categories c ON t.category_id = c.category_id
        WHERE t.user_id = ?
    `;
    const params = [user_id];

    if (month) { query += ' AND MONTH(t.transaction_date) = ?'; params.push(month); }
    if (year) { query += ' AND YEAR(t.transaction_date) = ?'; params.push(year); }
    if (type) { query += ' AND t.type = ?'; params.push(type); }
    if (category_id) { query += ' AND t.category_id = ?'; params.push(category_id); }

    query += ' ORDER BY t.transaction_date DESC, t.created_at DESC LIMIT ?';
    params.push(parseInt(limit));

    try {
        const [rows] = await db.query(query, params);
        res.json({ transactions: rows });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to fetch transactions.' });
    }
});

// ─── POST /api/transactions ───────────────────────────────────
router.post('/', async (req, res) => {
    const { category_id, amount, description, transaction_date, type } = req.body;
    const user_id = req.user.user_id;

    if (!amount || !transaction_date || !type)
        return res.status(400).json({ error: 'amount, transaction_date, and type are required.' });

    if (!['income', 'expense'].includes(type))
        return res.status(400).json({ error: 'type must be income or expense.' });

    if (category_id) {
        const [cat] = await db.query(
            'SELECT category_id FROM categories WHERE category_id = ? AND user_id = ?',
            [category_id, user_id]
        );
        if (cat.length === 0)
            return res.status(403).json({ error: 'Category not found.' });
    }

    try {
        const [result] = await db.query(
            'INSERT INTO transactions (user_id, category_id, amount, description, transaction_date, type) VALUES (?, ?, ?, ?, ?, ?)',
            [user_id, category_id || null, amount, description || '', transaction_date, type]
        );

        // Note: budget `spent` is now updated automatically by the DB trigger

        const [newTxn] = await db.query(
            `SELECT t.*, c.name AS category_name, c.icon, c.color
             FROM transactions t LEFT JOIN categories c ON t.category_id = c.category_id
             WHERE t.transaction_id = ?`,
            [result.insertId]
        );

        res.status(201).json({ message: 'Transaction added!', transaction: newTxn[0] });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to add transaction.' });
    }
});

// ─── PUT /api/transactions/:id ────────────────────────────────
router.put('/:id', async (req, res) => {
    const { amount, description, transaction_date, type, category_id } = req.body;
    const user_id = req.user.user_id;
    const transaction_id = req.params.id;

    const [existing] = await db.query(
        'SELECT * FROM transactions WHERE transaction_id = ? AND user_id = ?',
        [transaction_id, user_id]
    );
    if (existing.length === 0)
        return res.status(404).json({ error: 'Transaction not found.' });

    try {
        await db.query(
            `UPDATE transactions SET
                amount = COALESCE(?, amount),
                description = COALESCE(?, description),
                transaction_date = COALESCE(?, transaction_date),
                type = COALESCE(?, type),
                category_id = COALESCE(?, category_id)
             WHERE transaction_id = ? AND user_id = ?`,
            [amount, description, transaction_date, type, category_id, transaction_id, user_id]
        );
        res.json({ message: 'Transaction updated!' });
    } catch (err) {
        res.status(500).json({ error: 'Failed to update transaction.' });
    }
});

// ─── DELETE /api/transactions/:id ────────────────────────────
router.delete('/:id', async (req, res) => {
    const user_id = req.user.user_id;
    const transaction_id = req.params.id;

    try {
        const [result] = await db.query(
            'DELETE FROM transactions WHERE transaction_id = ? AND user_id = ?',
            [transaction_id, user_id]
        );
        if (result.affectedRows === 0)
            return res.status(404).json({ error: 'Transaction not found.' });

        res.json({ message: 'Transaction deleted.' });
    } catch (err) {
        res.status(500).json({ error: 'Failed to delete transaction.' });
    }
});

module.exports = router;
