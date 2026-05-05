USE pocketwise;

-- ============================================================
-- FIX: Change all procedures/functions to use VARCHAR(36)
--      because user_id is a UUID, not an INT
-- ============================================================

-- Fix Function 1
DROP FUNCTION IF EXISTS get_user_balance;
DELIMITER $$
CREATE FUNCTION get_user_balance(p_user_id VARCHAR(36))
RETURNS DECIMAL(12, 2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_income  DECIMAL(12, 2) DEFAULT 0.00;
    DECLARE v_expense DECIMAL(12, 2) DEFAULT 0.00;

    SELECT COALESCE(SUM(amount), 0) INTO v_income
    FROM transactions WHERE user_id = p_user_id AND type = 'income';

    SELECT COALESCE(SUM(amount), 0) INTO v_expense
    FROM transactions WHERE user_id = p_user_id AND type = 'expense';

    RETURN v_income - v_expense;
END$$
DELIMITER ;

-- Fix Function 2
DROP FUNCTION IF EXISTS get_category_total_spent;
DELIMITER $$
CREATE FUNCTION get_category_total_spent(
    p_user_id     VARCHAR(36),
    p_category_id INT,
    p_month       TINYINT,
    p_year        SMALLINT
)
RETURNS DECIMAL(12, 2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(12, 2) DEFAULT 0.00;

    SELECT COALESCE(SUM(amount), 0) INTO v_total
    FROM transactions
    WHERE user_id = p_user_id
      AND category_id = p_category_id
      AND type = 'expense'
      AND MONTH(transaction_date) = p_month
      AND YEAR(transaction_date)  = p_year;

    RETURN v_total;
END$$
DELIMITER ;

-- Fix Procedure 1
DROP PROCEDURE IF EXISTS get_monthly_summary;
DELIMITER $$
CREATE PROCEDURE get_monthly_summary(
    IN p_user_id VARCHAR(36),
    IN p_month   TINYINT,
    IN p_year    SMALLINT
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

-- Fix Procedure 2 (cursor)
DROP PROCEDURE IF EXISTS get_category_breakdown;
DELIMITER $$
CREATE PROCEDURE get_category_breakdown(
    IN p_user_id VARCHAR(36),
    IN p_month   TINYINT,
    IN p_year    SMALLINT
)
BEGIN
    DECLARE v_done          INT DEFAULT FALSE;
    DECLARE v_category_id   INT;
    DECLARE v_category_name VARCHAR(100);
    DECLARE v_icon          VARCHAR(50);
    DECLARE v_color         VARCHAR(20);
    DECLARE v_total_spent   DECIMAL(12, 2);
    DECLARE v_budget_limit  DECIMAL(12, 2);

    DECLARE cur_categories CURSOR FOR
        SELECT DISTINCT c.category_id, c.name, c.icon, c.color
        FROM   transactions t
        JOIN   categories   c ON t.category_id = c.category_id
        WHERE  t.user_id = p_user_id
          AND  t.type    = 'expense'
          AND  MONTH(t.transaction_date) = p_month
          AND  YEAR(t.transaction_date)  = p_year;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

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

    OPEN cur_categories;

    category_loop: LOOP
        FETCH cur_categories INTO v_category_id, v_category_name, v_icon, v_color;
        IF v_done THEN LEAVE category_loop; END IF;

        SET v_total_spent = get_category_total_spent(p_user_id, v_category_id, p_month, p_year);

        SELECT COALESCE(amount, 0) INTO v_budget_limit
        FROM budgets
        WHERE user_id = p_user_id AND category_id = v_category_id
          AND month = p_month AND year = p_year
        LIMIT 1;

        INSERT INTO tmp_category_breakdown VALUES (
            v_category_id, v_category_name, v_icon, v_color,
            v_total_spent, v_budget_limit,
            IF(v_budget_limit > 0 AND v_total_spent > v_budget_limit, 1, 0)
        );
    END LOOP;

    CLOSE cur_categories;

    SELECT * FROM tmp_category_breakdown ORDER BY total_spent DESC;
    DROP TEMPORARY TABLE IF EXISTS tmp_category_breakdown;
END$$
DELIMITER ;

-- Verify
SELECT 'All fixed!' AS status;
CALL get_monthly_summary('fe29c611-3dc8-11f1-bed8-04d4c4dfdfd1', 4, 2026);
