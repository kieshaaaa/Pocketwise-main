-- ============================================================
-- PocketWise - Personal Finance Tracker
-- Database Schema
-- ============================================================

CREATE DATABASE IF NOT EXISTS pocketwise;
USE pocketwise;

-- ============================================================
-- USERS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
    user_id     INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    email       VARCHAR(150) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- CATEGORIES TABLE (per user)
-- ============================================================
CREATE TABLE IF NOT EXISTS categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id     INT NOT NULL,
    name        VARCHAR(100) NOT NULL,
    icon        VARCHAR(50) DEFAULT '💰',
    color       VARCHAR(20) DEFAULT '#6366f1',
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_category (user_id, name)
);

-- ============================================================
-- TRANSACTIONS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS transactions (
    transaction_id   INT AUTO_INCREMENT PRIMARY KEY,
    user_id          INT NOT NULL,
    category_id      INT,
    amount           DECIMAL(12, 2) NOT NULL,
    description      VARCHAR(255),
    transaction_date DATE NOT NULL,
    type             ENUM('income', 'expense') NOT NULL,
    created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE SET NULL
);

-- ============================================================
-- BUDGETS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS budgets (
    budget_id   INT AUTO_INCREMENT PRIMARY KEY,
    user_id     INT NOT NULL,
    category_id INT NOT NULL,
    amount      DECIMAL(12, 2) NOT NULL,
    spent       DECIMAL(12, 2) DEFAULT 0.00,
    month       TINYINT NOT NULL CHECK (month BETWEEN 1 AND 12),
    year        SMALLINT NOT NULL,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE CASCADE,
    UNIQUE KEY unique_budget (user_id, category_id, month, year)
);

-- ============================================================
-- SAVINGS GOALS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS savings_goals (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT NOT NULL,
    name            VARCHAR(150) NOT NULL,
    target_amount   DECIMAL(12, 2) NOT NULL,
    current_amount  DECIMAL(12, 2) DEFAULT 0.00,
    target_date     DATE,
    is_completed    BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- ============================================================
-- STORED PROCEDURE: Add default categories on user registration
-- ============================================================
DELIMITER $$

DROP PROCEDURE IF EXISTS create_default_categories$$

CREATE PROCEDURE create_default_categories(IN p_user_id INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    INSERT IGNORE INTO categories (user_id, name, icon, color) VALUES
        (p_user_id, 'Food & Dining',     '🍽️', '#f97316'),
        (p_user_id, 'Housing',           '🏠', '#8b5cf6'),
        (p_user_id, 'Transportation',    '🚗', '#06b6d4'),
        (p_user_id, 'Entertainment',     '🎬', '#ec4899'),
        (p_user_id, 'Shopping',          '🛍️', '#f59e0b'),
        (p_user_id, 'Healthcare',        '⚕️', '#10b981'),
        (p_user_id, 'Education',         '📚', '#3b82f6'),
        (p_user_id, 'Salary',            '💼', '#22c55e'),
        (p_user_id, 'Investments',       '📈', '#a855f7'),
        (p_user_id, 'Miscellaneous',     '💡', '#64748b');

    COMMIT;
END$$

DELIMITER ;

-- ============================================================
-- USEFUL VIEWS
-- ============================================================

-- Monthly spending summary per user
CREATE OR REPLACE VIEW monthly_summary AS
SELECT
    t.user_id,
    MONTH(t.transaction_date) AS month,
    YEAR(t.transaction_date)  AS year,
    t.type,
    SUM(t.amount)             AS total
FROM transactions t
GROUP BY t.user_id, YEAR(t.transaction_date), MONTH(t.transaction_date), t.type;

-- Category-wise spending per user
CREATE OR REPLACE VIEW category_spending AS
SELECT
    t.user_id,
    c.name AS category_name,
    c.icon,
    c.color,
    SUM(t.amount) AS total_spent,
    MONTH(t.transaction_date) AS month,
    YEAR(t.transaction_date)  AS year
FROM transactions t
JOIN categories c ON t.category_id = c.category_id
WHERE t.type = 'expense'
GROUP BY t.user_id, t.category_id, YEAR(t.transaction_date), MONTH(t.transaction_date);

-- Budget vs actual spending
CREATE OR REPLACE VIEW budget_status AS
SELECT
    b.user_id,
    c.name AS category_name,
    c.icon,
    b.amount AS budget_limit,
    COALESCE(SUM(t.amount), 0) AS actual_spent,
    b.month,
    b.year
FROM budgets b
JOIN categories c ON b.category_id = c.category_id
LEFT JOIN transactions t
    ON t.user_id = b.user_id
    AND t.category_id = b.category_id
    AND MONTH(t.transaction_date) = b.month
    AND YEAR(t.transaction_date) = b.year
    AND t.type = 'expense'
GROUP BY b.budget_id;
