-- ============================================================
-- PocketWise - Advanced SQL: Triggers, Procedures, Cursors, Functions
-- Run this file AFTER schema.sql
-- Usage: mysql -u root -p pocketwise < pocketwise_advanced.sql
-- ============================================================

USE pocketwise;

-- ============================================================
-- SECTION 1: AUDIT LOG TABLE (needed by triggers)
-- ============================================================

CREATE TABLE IF NOT EXISTS user_deletion_log (
    log_id       INT AUTO_INCREMENT PRIMARY KEY,
    user_id      INT NOT NULL,
    email        VARCHAR(150),
    name         VARCHAR(100),
    deleted_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_by   VARCHAR(50) DEFAULT 'system'
);

-- ============================================================
-- SECTION 2: TRIGGERS
-- ============================================================

-- ------------------------------------------------------------
-- TRIGGER 1: After a transaction is inserted, auto-update
--            the `spent` column in the budgets table.
--            This replaces the manual UPDATE in transactions.js.
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_after_transaction_insert;

DELIMITER $$

CREATE TRIGGER trg_after_transaction_insert
AFTER INSERT ON transactions
FOR EACH ROW
BEGIN
    -- Only update budgets for expense transactions that have a category
    IF NEW.type = 'expense' AND NEW.category_id IS NOT NULL THEN
        UPDATE budgets
        SET    spent = spent + NEW.amount
        WHERE  user_id     = NEW.user_id
          AND  category_id = NEW.category_id
          AND  month       = MONTH(NEW.transaction_date)
          AND  year        = YEAR(NEW.transaction_date);
    END IF;
END$$

DELIMITER ;

-- ------------------------------------------------------------
-- TRIGGER 2: After a transaction is deleted, reverse its
--            contribution to the budgets.spent column.
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_after_transaction_delete;

DELIMITER $$

CREATE TRIGGER trg_after_transaction_delete
AFTER DELETE ON transactions
FOR EACH ROW
BEGIN
    IF OLD.type = 'expense' AND OLD.category_id IS NOT NULL THEN
        UPDATE budgets
        SET    spent = GREATEST(0, spent - OLD.amount)   -- prevent negatives
        WHERE  user_id     = OLD.user_id
          AND  category_id = OLD.category_id
          AND  month       = MONTH(OLD.transaction_date)
          AND  year        = YEAR(OLD.transaction_date);
    END IF;
END$$

DELIMITER ;

-- ------------------------------------------------------------
-- TRIGGER 3: Before a user is deleted, write a record to the
--            audit log so there is a permanent trail.
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_before_user_delete;

DELIMITER $$

CREATE TRIGGER trg_before_user_delete
BEFORE DELETE ON users
FOR EACH ROW
BEGIN
    INSERT INTO user_deletion_log (user_id, email, name)
    VALUES (OLD.user_id, OLD.email, OLD.name);
END$$

DELIMITER ;

-- ============================================================
-- SECTION 3: STORED FUNCTIONS
-- ============================================================

-- ------------------------------------------------------------
-- FUNCTION 1: get_user_balance(p_user_id)
--   Returns total income - total expenses for a user (all time).
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS get_user_balance;

DELIMITER $$

CREATE FUNCTION get_user_balance(p_user_id INT)
RETURNS DECIMAL(12, 2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_income  DECIMAL(12, 2) DEFAULT 0.00;
    DECLARE v_expense DECIMAL(12, 2) DEFAULT 0.00;

    SELECT COALESCE(SUM(amount), 0)
    INTO   v_income
    FROM   transactions
    WHERE  user_id = p_user_id AND type = 'income';

    SELECT COALESCE(SUM(amount), 0)
    INTO   v_expense
    FROM   transactions
    WHERE  user_id = p_user_id AND type = 'expense';

    RETURN v_income - v_expense;
END$$

DELIMITER ;

-- ------------------------------------------------------------
-- FUNCTION 2: get_category_total_spent(p_user_id, p_category_id, p_month, p_year)
--   Returns total amount spent in a given category for a
--   specific month/year.
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS get_category_total_spent;

DELIMITER $$

CREATE FUNCTION get_category_total_spent(
    p_user_id     INT,
    p_category_id INT,
    p_month       TINYINT,
    p_year        SMALLINT
)
RETURNS DECIMAL(12, 2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(12, 2) DEFAULT 0.00;

    SELECT COALESCE(SUM(amount), 0)
    INTO   v_total
    FROM   transactions
    WHERE  user_id       = p_user_id
      AND  category_id   = p_category_id
      AND  type          = 'expense'
      AND  MONTH(transaction_date) = p_month
      AND  YEAR(transaction_date)  = p_year;

    RETURN v_total;
END$$

DELIMITER ;

-- ============================================================
-- SECTION 4: STORED PROCEDURES
-- ============================================================

-- ------------------------------------------------------------
-- PROCEDURE 1: get_monthly_summary(p_user_id, p_month, p_year)
--   Returns total income, total expenses, and net balance
--   for the specified month. Called from the /summary route.
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS get_monthly_summary;

DELIMITER $$

CREATE PROCEDURE get_monthly_summary(
    IN  p_user_id INT,
    IN  p_month   TINYINT,
    IN  p_year    SMALLINT
)
BEGIN
    SELECT
        COALESCE(SUM(CASE WHEN type = 'income'  THEN amount ELSE 0 END), 0) AS total_income,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS total_expense,
        COALESCE(SUM(CASE WHEN type = 'income'  THEN amount ELSE 0 END), 0) -
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS net_balance
    FROM transactions
    WHERE user_id = p_user_id
      AND MONTH(transaction_date) = p_month
      AND YEAR(transaction_date)  = p_year;
END$$

DELIMITER ;

-- ------------------------------------------------------------
-- PROCEDURE 2: get_category_breakdown(p_user_id, p_month, p_year)
--   Uses a CURSOR to loop through every category that has
--   transactions in the given month, calculate totals, and
--   return a result set with category name, total spent,
--   budget limit, and whether the budget was exceeded.
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS get_category_breakdown;

DELIMITER $$

CREATE PROCEDURE get_category_breakdown(
    IN p_user_id INT,
    IN p_month   TINYINT,
    IN p_year    SMALLINT
)
BEGIN
    -- ── Variables for the cursor ──────────────────────────────
    DECLARE v_done          INT DEFAULT FALSE;
    DECLARE v_category_id   INT;
    DECLARE v_category_name VARCHAR(100);
    DECLARE v_icon          VARCHAR(50);
    DECLARE v_color         VARCHAR(20);
    DECLARE v_total_spent   DECIMAL(12, 2);
    DECLARE v_budget_limit  DECIMAL(12, 2);

    -- ── Temporary results table ───────────────────────────────
    DROP TEMPORARY TABLE IF EXISTS tmp_category_breakdown;
    CREATE TEMPORARY TABLE tmp_category_breakdown (
        category_id    INT,
        category_name  VARCHAR(100),
        icon           VARCHAR(50),
        color          VARCHAR(20),
        total_spent    DECIMAL(12, 2),
        budget_limit   DECIMAL(12, 2),
        over_budget    TINYINT(1)
    );

    -- ── Cursor: one row per category the user spent in ────────
    -- The cursor itself fetches category metadata; we calculate
    -- the spending total inside the loop using our function.
    DECLARE cur_categories CURSOR FOR
        SELECT DISTINCT c.category_id, c.name, c.icon, c.color
        FROM   transactions t
        JOIN   categories   c ON t.category_id = c.category_id
        WHERE  t.user_id = p_user_id
          AND  t.type    = 'expense'
          AND  MONTH(t.transaction_date) = p_month
          AND  YEAR(t.transaction_date)  = p_year;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    OPEN cur_categories;

    category_loop: LOOP
        FETCH cur_categories
        INTO  v_category_id, v_category_name, v_icon, v_color;

        IF v_done THEN
            LEAVE category_loop;
        END IF;

        -- Use our stored function to get the spending total
        SET v_total_spent = get_category_total_spent(
            p_user_id, v_category_id, p_month, p_year
        );

        -- Look up budget limit (0 if no budget set)
        SELECT COALESCE(amount, 0)
        INTO   v_budget_limit
        FROM   budgets
        WHERE  user_id     = p_user_id
          AND  category_id = v_category_id
          AND  month       = p_month
          AND  year        = p_year
        LIMIT 1;

        INSERT INTO tmp_category_breakdown
        VALUES (
            v_category_id,
            v_category_name,
            v_icon,
            v_color,
            v_total_spent,
            v_budget_limit,
            IF(v_budget_limit > 0 AND v_total_spent > v_budget_limit, 1, 0)
        );

    END LOOP;

    CLOSE cur_categories;

    -- Return the assembled result set
    SELECT * FROM tmp_category_breakdown
    ORDER BY total_spent DESC;

    DROP TEMPORARY TABLE IF EXISTS tmp_category_breakdown;
END$$

DELIMITER ;

-- ============================================================
-- SECTION 5: QUICK SMOKE-TEST QUERIES
-- (Run these manually to verify everything works)
-- ============================================================
/*
-- Test triggers (run after inserting a transaction):
SELECT * FROM budgets WHERE user_id = 1;

-- Test function 1:
SELECT get_user_balance(1) AS balance;

-- Test function 2:
SELECT get_category_total_spent(1, 2, 4, 2025) AS spent;

-- Test procedure 1:
CALL get_monthly_summary(1, 4, 2025);

-- Test procedure 2 (cursor):
CALL get_category_breakdown(1, 4, 2025);

-- Check audit log after deleting a user:
SELECT * FROM user_deletion_log;
*/
