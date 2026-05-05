const express = require('express');
const db      = require('../config/db');
const auth    = require('../middleware/auth');

const router = express.Router();
router.use(auth);

router.get('/', async (req, res) => {
    const [rows] = await db.query(
        'SELECT * FROM savings_goals WHERE user_id = ? ORDER BY is_completed, target_date',
        [req.user.user_id]
    );
    res.json({ goals: rows });
});

router.post('/', async (req, res) => {
    const { name, target_amount, current_amount, target_date } = req.body;
    if (!name || !target_amount)
        return res.status(400).json({ error: 'name and target_amount are required.' });

    try {
        const [result] = await db.query(
            'INSERT INTO savings_goals (user_id, name, target_amount, current_amount, target_date) VALUES (?, ?, ?, ?, ?)',
            [req.user.user_id, name, target_amount, current_amount || 0, target_date || null]
        );
        res.status(201).json({ message: 'Goal created!', id: result.insertId });
    } catch (err) {
        res.status(500).json({ error: 'Failed to create goal.' });
    }
});

// Add money to a goal
router.patch('/:id/contribute', async (req, res) => {
    const { amount } = req.body;
    const user_id = req.user.user_id;

    try {
        const [rows] = await db.query(
            'SELECT * FROM savings_goals WHERE id = ? AND user_id = ?',
            [req.params.id, user_id]
        );
        if (rows.length === 0) return res.status(404).json({ error: 'Goal not found.' });

        const goal = rows[0];
        const newAmount = parseFloat(goal.current_amount) + parseFloat(amount);
        const is_completed = newAmount >= goal.target_amount;

        await db.query(
            'UPDATE savings_goals SET current_amount = ?, is_completed = ? WHERE id = ? AND user_id = ?',
            [Math.min(newAmount, goal.target_amount), is_completed, req.params.id, user_id]
        );

        res.json({ message: is_completed ? '🎉 Goal completed!' : 'Contribution added!', is_completed });
    } catch (err) {
        res.status(500).json({ error: 'Failed to update goal.' });
    }
});

router.delete('/:id', async (req, res) => {
    const [result] = await db.query(
        'DELETE FROM savings_goals WHERE id = ? AND user_id = ?',
        [req.params.id, req.user.user_id]
    );
    if (result.affectedRows === 0) return res.status(404).json({ error: 'Goal not found.' });
    res.json({ message: 'Goal deleted.' });
});

module.exports = router;
