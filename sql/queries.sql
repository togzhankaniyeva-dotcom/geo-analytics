-- ============================================================
-- ЭТАП 2. Сбор и выгрузка данных
-- SQLite. Таблицы: customers, cards, devices, merchants, transactions
-- ============================================================

-- ------------------------------------------------------------
-- Q1. Проверка объёмов и уникальности ключей (агрегаты + COUNT DISTINCT)
-- ------------------------------------------------------------
SELECT 'customers'    AS table_name, COUNT(*) AS rows, COUNT(DISTINCT customer_id) AS uniq FROM customers
UNION ALL
SELECT 'cards',        COUNT(*), COUNT(DISTINCT card_id)      FROM cards
UNION ALL
SELECT 'devices',      COUNT(*), COUNT(DISTINCT device_id)    FROM devices
UNION ALL
SELECT 'merchants',    COUNT(*), COUNT(DISTINCT merchant_id)  FROM merchants
UNION ALL
SELECT 'transactions', COUNT(*), COUNT(DISTINCT transaction_id) FROM transactions;


-- ------------------------------------------------------------
-- Q2. Города: сколько клиентов и мерчантов в каждом
--     (агрегаты + LEFT JOIN, чтобы увидеть города без мерчантов)
-- ------------------------------------------------------------
WITH cust_city AS (
    SELECT city, COUNT(DISTINCT customer_id) AS n_customers
    FROM customers
    GROUP BY city
),
merch_city AS (
    SELECT city, COUNT(DISTINCT merchant_id) AS n_merchants
    FROM merchants
    GROUP BY city
)
SELECT
    COALESCE(c.city, m.city) AS city,
    COALESCE(n_customers, 0) AS n_customers,
    COALESCE(n_merchants, 0) AS n_merchants
FROM cust_city c
LEFT JOIN merch_city m ON c.city = m.city
ORDER BY n_customers DESC;


-- ------------------------------------------------------------
-- Q3. Средний чек (AOV) по городам и категориям мерчантов
--     JOIN (transactions → customers → merchants) + агрегаты
-- ------------------------------------------------------------
SELECT
    c.city,
    m.category,
    COUNT(*)             AS tx_count,
    ROUND(AVG(t.amount), 2) AS avg_check,
    ROUND(SUM(t.amount), 2) AS total_amount
FROM transactions t
JOIN customers c ON t.customer_id = c.customer_id
JOIN merchants m ON t.merchant_id = m.merchant_id
GROUP BY c.city, m.category
ORDER BY c.city, avg_check DESC;


-- ------------------------------------------------------------
-- Q4. Средний чек по городам в категории Food (для гипотезы H1)
-- ------------------------------------------------------------
SELECT
    c.city,
    COUNT(*)                 AS tx_food,
    ROUND(AVG(t.amount), 2)  AS avg_check_food
FROM transactions t
JOIN customers c ON t.customer_id = c.customer_id
JOIN merchants m ON t.merchant_id = m.merchant_id
WHERE m.category = 'Food'
GROUP BY c.city
ORDER BY avg_check_food DESC;


-- ------------------------------------------------------------
-- Q5. Помесячные траты на клиента (CTE + strftime)
-- ------------------------------------------------------------
WITH monthly AS (
    SELECT
        t.customer_id,
        strftime('%Y-%m', t.timestamp) AS month,
        SUM(t.amount)  AS total_spent,
        COUNT(*)       AS n_tx
    FROM transactions t
    GROUP BY t.customer_id, month
)
SELECT *
FROM monthly
ORDER BY customer_id, month
LIMIT 50;


-- ------------------------------------------------------------
-- Q6. Ранг городов по среднему чеку (оконная функция RANK)
-- ------------------------------------------------------------
WITH city_avg AS (
    SELECT
        c.city,
        AVG(t.amount) AS avg_check
    FROM transactions t
    JOIN customers c ON t.customer_id = c.customer_id
    GROUP BY c.city
)
SELECT
    city,
    ROUND(avg_check, 2) AS avg_check,
    RANK() OVER (ORDER BY avg_check DESC) AS city_rank
FROM city_avg
ORDER BY city_rank;


-- ------------------------------------------------------------
-- Q7. Нарастающий итог трат по месяцам в разрезе города (оконная SUM OVER)
-- ------------------------------------------------------------
WITH city_month AS (
    SELECT
        c.city,
        strftime('%Y-%m', t.timestamp) AS month,
        SUM(t.amount) AS month_amount
    FROM transactions t
    JOIN customers c ON t.customer_id = c.customer_id
    GROUP BY c.city, month
)
SELECT
    city,
    month,
    ROUND(month_amount, 2) AS month_amount,
    ROUND(SUM(month_amount) OVER (PARTITION BY city ORDER BY month), 2) AS cumulative_amount
FROM city_month
ORDER BY city, month;


-- ------------------------------------------------------------
-- Q8. Топ-5 мерчантов по обороту в каждом городе (RANK + PARTITION BY)
-- ------------------------------------------------------------
WITH merch_city_rev AS (
    SELECT
        m.city,
        m.merchant_id,
        m.merchant_name,
        m.category,
        SUM(t.amount) AS revenue
    FROM transactions t
    JOIN merchants m ON t.merchant_id = m.merchant_id
    GROUP BY m.city, m.merchant_id, m.merchant_name, m.category
),
ranked AS (
    SELECT
        *,
        RANK() OVER (PARTITION BY city ORDER BY revenue DESC) AS rnk
    FROM merch_city_rev
)
SELECT city, rnk, merchant_id, merchant_name, category, ROUND(revenue, 2) AS revenue
FROM ranked
WHERE rnk <= 5
ORDER BY city, rnk;


-- ------------------------------------------------------------
-- Q9. Доля транзакций по типам и способам оплаты (агрегаты + проценты)
-- ------------------------------------------------------------
SELECT
    transaction_type,
    payment_method,
    COUNT(*) AS n,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM transactions), 2) AS pct
FROM transactions
GROUP BY transaction_type, payment_method
ORDER BY n DESC;


-- ------------------------------------------------------------
-- Q10. Проверка качества: отрицательные суммы, NULL в ключевых полях, диапазон дат
-- ------------------------------------------------------------
SELECT
    SUM(CASE WHEN amount < 0 THEN 1 ELSE 0 END)              AS negative_amounts,
    SUM(CASE WHEN amount IS NULL THEN 1 ELSE 0 END)          AS null_amounts,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END)     AS null_customer,
    SUM(CASE WHEN merchant_id IS NULL THEN 1 ELSE 0 END)     AS null_merchant,
    MIN(timestamp) AS min_ts,
    MAX(timestamp) AS max_ts
FROM transactions;
