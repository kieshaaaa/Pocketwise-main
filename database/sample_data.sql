-- ============================================================
-- PocketWise - Sample Data (for testing)
-- Run AFTER schema.sql
-- ============================================================
USE pocketwise;

-- Insert test users (passwords are bcrypt hashes of "password123")
INSERT INTO users (name, email, password_hash) VALUES
('Yashika Sharma', 'yashika@example.com', '$2b$10$examplehash1'),
('Kiesha Kapoor',  'kiesha@example.com',  '$2b$10$examplehash2');

-- Create default categories for both users
CALL create_default_categories(1);
CALL create_default_categories(2);

-- Sample transactions for user 1
INSERT INTO transactions (user_id, category_id, amount, description, transaction_date, type) VALUES
(1, 1,  450.00, 'Zomato order',         '2025-04-01', 'expense'),
(1, 1,  200.00, 'Canteen lunch',        '2025-04-03', 'expense'),
(1, 3,  150.00, 'Metro card recharge',  '2025-04-05', 'expense'),
(1, 8, 5000.00, 'Freelance payment',    '2025-04-01', 'income'),
(1, 5,  800.00, 'Amazon order',         '2025-04-10', 'expense'),
(1, 7,  999.00, 'Coursera subscription','2025-04-12', 'expense'),
(1, 8, 2000.00, 'Part-time stipend',    '2025-04-15', 'income');

-- Sample budgets for user 1 (April 2025)
INSERT INTO budgets (user_id, category_id, amount, month, year) VALUES
(1, 1, 2000.00, 4, 2025),
(1, 3,  500.00, 4, 2025),
(1, 5, 1500.00, 4, 2025),
(1, 7, 1000.00, 4, 2025);

-- Sample savings goals for user 1
INSERT INTO savings_goals (user_id, name, target_amount, current_amount, target_date) VALUES
(1, 'New Laptop',      50000.00, 12000.00, '2025-08-01'),
(1, 'Emergency Fund',  20000.00,  5000.00, '2025-12-31'),
(1, 'Trip to Manali',  15000.00,  3000.00, '2025-06-01');
