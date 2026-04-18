-- ═══════════════════════════════════════════════════════════════════
--
-- DASHBOARD 1: EXECUTIVE SUMMARY
-- Charts: KPI cards, monthly revenue trend, revenue by state,
--         revenue by payment type, orders by day of week
--
-- ═══════════════════════════════════════════════════════════════════

-- 1A.Overall KPIs (single row — use as Tableau text/BAN)
CREATE OR REPLACE VIEW ECOMMERCE_ANALYTICS.ANALYTICS.V_EXEC_KPIS AS
SELECT
    COUNT(DISTINCT ORDER_ID) AS TOTAL_ORDERS,
    COUNT(DISTINCT CUSTOMER_UNIQUE_ID) AS UNIQUE_CUSTOMERS,
    ROUND(SUM(TOTAL_PAYMENT),2) AS TOTAL_REVENUE,
    ROUND(AVG(TOTAL_PAYMENT),2) AS AVG_ORDER_VALUE,
    ROUND(AVG(REVIEW_SCORE),2) AS AVG_REVIEW_SCORE,
    ROUND(AVG(DELIVERY_DAYS),1) AS AVG_DELIVERY_DAYS,
    ROUND(SUM(CASE WHEN DELIVERY_STATUS = 'Late' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),1) AS LATE_DELIVERY_PCT,
    ROUND(AVG(ITEMS_IN_ORDER),1) AS AVG_ITEMS_PER_ORDER
FROM ECOMMERCE_ANALYTICS.ANALYTICS.V_ORDER_ANALYTICS;

--1B. Monthly revenue trand with MoM growth
CREATE OR REPLACE VIEW ECOMMERCE_ANALYTICS.ANALYTICS.V_MONTHLY_REVENUE AS
SELECT
    ORDER_MONTH,
    ORDER_YEAR,
    ORDER_QUARTER,
    COUNT(DISTINCT ORDER_ID) AS ORDERS,
    COUNT(DISTINCT CUSTOMER_UNIQUE_ID) AS UNIQUE_CUSTOMERS,
    ROUND(SUM(TOTAL_PAYMENT),2) AS REVENUE,
    ROUND(AVG(TOTAL_PAYMENT),2) AS AVG_ORDER_VALUE,
    ROUND(AVG(REVIEW_SCORE),2) AS AVG_REVIEW,
    ROUND(AVG(DELIVERY_DAYS),1) AS AVG_DELIVERY_DAYS,
    ROUND(SUM(CASE WHEN DELIVERY_STATUS = 'Late' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*),0),1) AS LATE_PCT,
    LAG(ROUND(SUM(TOTAL_PAYMENT),2)) OVER (ORDER BY ORDER_MONTH) AS PREV_MONTH_REVENUE,
    ROUND(
        (SUM(TOTAL_PAYMENT) - LAG(SUM(TOTAL_PAYMENT)) OVER (ORDER BY ORDER_MONTH)) / NULLIF(LAG(SUM(TOTAL_PAYMENT)) OVER (ORDER BY ORDER_MONTH),0) * 100, 1) AS MOM_GROWTH_PCT 
FROM ECOMMERCE_ANALYTICS.ANALYTICS.V_ORDER_ANALYTICS
GROUP BY ORDER_MONTH,ORDER_YEAR,ORDER_QUARTER
ORDER BY ORDER_MONTH;


--1C. Revenue by State (FOR THE MAP)
CREATE OR REPLACE VIEW ECOMMERCE_ANALYTICS.ANALYTICS.v_revenue_by_state AS
SELECT
    customer_state,
    COUNT(DISTINCT ORDER_ID) AS orders,
    COUNT(DISTINCT CUSTOMER_UNIQUE_ID) AS customers,
    ROUND(SUM(TOTAL_PAYMENT), 2) AS REVENUE,
    ROUND(AVG(TOTAL_PAYMENT), 2) AS AVG_ORDER_VALUE,
    ROUND(AVG(review_score), 2) AS AVG_REVIEW
FROM ECOMMERCE_ANALYTICS.ANALYTICS.V_ORDER_ANALYTICS
GROUP BY CUSTOMER_STATE
ORDER BY REVENUE DESC;

--ID. Revenue by payment type
CREATE OR REPLACE VIEW ECOMMERCE_ANALYTICS.ANALYTICS.V_PAYMENT_BREAKDOWN AS
SELECT
    PRIMARY_PAYMENT_TYPE,
    COUNT(*) AS ORDER_COUNT,
    ROUND(SUM(TOTAL_PAYMENT),2) AS REVENUE,
    ROUND(AVG(TOTAL_PAYMENT),2) AS AVG_ORDER_VALUE,
    ROUND(SUM(TOTAL_PAYMENT) * 100.0 / SUM(SUM(TOTAL_PAYMENT)) OVER (),1) AS REVENUE_SHARE_PCT
FROM ECOMMERCE_ANALYTICS.ANALYTICS.V_ORDER_ANALYTICS
GROUP BY PRIMARY_PAYMENT_TYPE
ORDER BY REVENUE DESC;

--1E. ORDER BY DAY OF WEEK (BAR CHART - SHOW PEAK DAYS)
CREATE OR REPLACE VIEW ECOMMERCE_ANALYTICS.ANALYTICS.V_ORDERS_BY_DAY AS
SELECT
    DAY_OF_WEEK,
    COUNT(*) AS ORDERS,
    ROUND(SUM(TOTAL_PAYMENT), 2) AS REVENUE,
    ROUND(AVG(TOTAL_PAYMENT),2) AS AVG_ORDER_VALUE
FROM ECOMMERCE_ANALYTICS.ANALYTICS.V_ORDER_ANALYTICS
GROUP BY DAY_OF_WEEK
ORDER BY
    CASE DAY_OF_WEEK
        WHEN 'Mon' THEN 1 WHEN 'Tue' THEN 2 WHEN 'Wed' THEN 3
        WHEN 'Thu' THEN 4 WHEN 'Fri' THEN 5 WHEN 'Sat' THEN 6
        WHEN 'Sun' THEN 7
    END;

-- ═══════════════════════════════════════════════════════════════════
--
-- DASHBOARD 2: CUSTOMER INTELLIGENCE
-- Charts: Segment breakdown, lifetime value by segment,
--         customer geography, repeat rate, cohort retention
--
-- ═══════════════════════════════════════════════════════════════════

-- 2A. Customer Segments Summary
CREATE OR REPLACE VIEW ECOMMERCE_ANALYTICS.ANALYTICS.V_CUSTOMER_SEGMENTS AS
SELECT
    CUSTOMER_SEGMENT,
    COUNT(DISTINCT CUSTOMER_UNIQUE_ID) AS CUSTOMER_COUNT, 
    ROUND(AVG(LIFETIME_VALUE),2) AS AVG_LIFETIME_VALUE,
    ROUND(AVG(CUSTOMER_ORDER_COUNT),1) AS AVG_ORDERS,
    ROUND(AVG(REVIEW_SCORE),2) AS AVG_REVIEW,
    ROUND(COUNT(DISTINCT CUSTOMER_UNIQUE_ID) * 100.0 / SUM(COUNT(DISTINCT CUSTOMER_UNIQUE_ID)) OVER(),1) AS SEGMENT_PCT
FROM ECOMMERCE_ANALYTICS.ANALYTICS.V_ORDER_ANALYTICS
GROUP BY CUSTOMER_SEGMENT;

-- 2B. CUSTOMER SEGMENTS BY STATE ( Which states retain better?)
CREATE OR REPLACE VIEW ECOMMERCE_ANALYTICS.ANALYTICS.V_SEGMENTS_BY_STATE AS
SELECT 
    CUSTOMER_STATE,
    CUSTOMER_SEGMENT,
    COUNT(DISTINCT CUSTOMER_UNIQUE_ID) AS CUSTOMERS,
    ROUND(AVG(LIFETIME_VALUE), 2) AS AVG_LTV,
    ROUND(AVG(REVIEW_SCORE),2) AS AVG_REVIEW
FROM ECOMMERCE_ANALYTICS.ANALYTICS.V_ORDER_ANALYTICS
GROUP BY CUSTOMER_STATE,CUSTOMER_SEGMENT
HAVING COUNT(DISTINCT CUSTOMER_UNIQUE_ID) > 5
ORDER BY CUSTOMER_STATE, CUSTOMER_SEGMENT;

-- 2C. Monthly new vs returning customers
CREATE OR REPLACE VIEW ECOMMERCE_ANALYTICS.ANALYTICS.v_new_vs_returning AS
WITH first_month AS (
    SELECT
        customer_unique_id,
        DATE_TRUNC('month', MIN(order_purchase_timestamp)) AS first_order_month
    FROM ECOMMERCE_ANALYTICS.ANALYTICS.v_order_analytics
    GROUP BY customer_unique_id
)
SELECT
    o.order_month,
    COUNT(DISTINCT CASE
        WHEN o.order_month = fm.first_order_month THEN o.customer_unique_id
    END) AS new_customers,
    COUNT(DISTINCT CASE
        WHEN o.order_month != fm.first_order_month THEN o.customer_unique_id
    END) AS returning_customers,
    COUNT(DISTINCT o.customer_unique_id) AS total_customers
FROM ECOMMERCE_ANALYTICS.ANALYTICS.v_order_analytics o
JOIN first_month fm ON o.customer_unique_id = fm.customer_unique_id
GROUP BY o.order_month
ORDER BY o.order_month;

-- 2D. Cohort retention (advanced — the impressive one)
CREATE OR REPLACE VIEW ECOMMERCE_ANALYTICS.ANALYTICS.v_cohort_retention AS
WITH first_purchase AS (
    SELECT
        customer_unique_id,
        DATE_TRUNC('month', MIN(order_purchase_timestamp)) AS cohort_month
    FROM ECOMMERCE_ANALYTICS.ANALYTICS.v_order_analytics
    GROUP BY customer_unique_id
)
SELECT
    fp.cohort_month,
    COUNT(DISTINCT fp.customer_unique_id) AS cohort_size,
    COUNT(DISTINCT CASE
        WHEN DATEDIFF('month', fp.cohort_month, DATE_TRUNC('month', o.order_purchase_timestamp)) = 0
        THEN o.customer_unique_id END) AS month_0,
    COUNT(DISTINCT CASE
        WHEN DATEDIFF('month', fp.cohort_month, DATE_TRUNC('month', o.order_purchase_timestamp)) = 1
        THEN o.customer_unique_id END) AS month_1,
    COUNT(DISTINCT CASE
        WHEN DATEDIFF('month', fp.cohort_month, DATE_TRUNC('month', o.order_purchase_timestamp)) = 2
        THEN o.customer_unique_id END) AS month_2,
    COUNT(DISTINCT CASE
        WHEN DATEDIFF('month', fp.cohort_month, DATE_TRUNC('month', o.order_purchase_timestamp)) = 3
        THEN o.customer_unique_id END) AS month_3,
    COUNT(DISTINCT CASE
        WHEN DATEDIFF('month', fp.cohort_month, DATE_TRUNC('month', o.order_purchase_timestamp)) = 4
        THEN o.customer_unique_id END) AS month_4,
    COUNT(DISTINCT CASE
        WHEN DATEDIFF('month', fp.cohort_month, DATE_TRUNC('month', o.order_purchase_timestamp)) = 5
        THEN o.customer_unique_id END) AS month_5,
    COUNT(DISTINCT CASE
        WHEN DATEDIFF('month', fp.cohort_month, DATE_TRUNC('month', o.order_purchase_timestamp)) = 6
        THEN o.customer_unique_id END) AS month_6
FROM first_purchase fp
JOIN v_order_analytics o ON fp.customer_unique_id = o.customer_unique_id
GROUP BY fp.cohort_month
HAVING cohort_size > 10
ORDER BY fp.cohort_month;


-- ═══════════════════════════════════════════════════════════════════
--
-- DASHBOARD 3: DELIVERY PERFORMANCE & REVIEW IMPACT
-- Charts: Late % by state, on-time vs late review comparison,
--         delivery days distribution, delivery vs review scatter
--
-- ═══════════════════════════════════════════════════════════════════

-- 3A. Delivery impact on reviews (the key insight chart)
CREATE OR REPLACE VIEW ECOMMERCE_ANALYTICS.ANALYTICS.v_delivery_impact AS
SELECT
    delivery_status,
    COUNT(*) AS order_count,
    ROUND(AVG(review_score), 2) AS avg_review,
    ROUND(SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 1) AS pct_bad_reviews,
    ROUND(SUM(CASE WHEN review_score >= 4 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 1) AS pct_good_reviews,
    ROUND(AVG(delivery_days), 1) AS avg_delivery_days,
    ROUND(AVG(total_payment), 2) AS avg_order_value
FROM ECOMMERCE_ANALYTICS.ANALYTICS.v_order_analytics
WHERE review_score IS NOT NULL
GROUP BY delivery_status;


-- 3B. State-level delivery performance
CREATE OR REPLACE VIEW ECOMMERCE_ANALYTICS.ANALYTICS.v_state_delivery AS
SELECT
    customer_state,
    COUNT(*) AS orders,
    ROUND(AVG(delivery_days), 1) AS avg_delivery_days,
    ROUND(AVG(estimated_days), 1) AS avg_estimated_days,
    ROUND(AVG(delivery_days) - AVG(estimated_days), 1) AS avg_delay_vs_estimate,
    ROUND(SUM(CASE WHEN delivery_status = 'Late' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 1) AS late_pct,
    ROUND(AVG(review_score), 2) AS avg_review,
    ROUND(SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 1) AS pct_bad_reviews
FROM ECOMMERCE_ANALYTICS.ANALYTICS.v_order_analytics
WHERE review_score IS NOT NULL
GROUP BY customer_state
HAVING COUNT(*) > 50
ORDER BY late_pct DESC;


-- 3C. Delivery days distribution (for histogram)
CREATE OR REPLACE VIEW ECOMMERCE_ANALYTICS.ANALYTICS.v_delivery_distribution AS
SELECT
    CASE
        WHEN delivery_days <= 5 THEN '01. 0-5 days'
        WHEN delivery_days <= 10 THEN '02. 6-10 days'
        WHEN delivery_days <= 15 THEN '03. 11-15 days'
        WHEN delivery_days <= 20 THEN '04. 16-20 days'
        WHEN delivery_days <= 30 THEN '05. 21-30 days'
        WHEN delivery_days <= 45 THEN '06. 31-45 days'
        ELSE '07. 45+ days'
    END AS delivery_bucket,
    delivery_status,
    COUNT(*) AS orders,
    ROUND(AVG(review_score), 2) AS avg_review
FROM ECOMMERCE_ANALYTICS.ANALYTICS.v_order_analytics
WHERE delivery_days IS NOT NULL
GROUP BY 1, 2
ORDER BY 1;


-- 3D. Monthly delivery trend (is it getting better or worse?)
CREATE OR REPLACE VIEW ECOMMERCE_ANALYTICS.ANALYTICS.v_monthly_delivery AS
SELECT
    order_month,
    COUNT(*) AS orders,
    ROUND(AVG(delivery_days), 1) AS avg_delivery_days,
    ROUND(SUM(CASE WHEN delivery_status = 'Late' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 1) AS late_pct,
    ROUND(AVG(review_score), 2) AS avg_review
FROM ECOMMERCE_ANALYTICS.ANALYTICS.v_order_analytics
GROUP BY order_month
ORDER BY order_month;


-- ═══════════════════════════════════════════════════════════════════
--
-- DASHBOARD 4: PRODUCT & SELLER ANALYTICS
-- Charts: Top categories by revenue, category performance matrix,
--         seller geography, price distribution
-- NOTE: Uses v_product_analytics (item grain), NOT v_order_analytics
--
-- ═══════════════════════════════════════════════════════════════════

-- 4A. Category performance (the main product chart)
CREATE OR REPLACE VIEW ECOMMERCE_ANALYTICS.ANALYTICS.v_category_performance AS
SELECT
    category_english AS category,
    COUNT(*) AS items_sold,
    COUNT(DISTINCT order_id) AS orders,
    ROUND(SUM(item_price), 2) AS revenue,
    ROUND(AVG(item_price), 2) AS avg_price,
    ROUND(SUM(freight_value), 2) AS total_freight,
    ROUND(AVG(freight_value), 2) AS avg_freight,
    ROUND(AVG(review_score), 2) AS avg_review,
    ROUND(SUM(CASE WHEN delivery_status = 'Late' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 1) AS late_pct,
    DENSE_RANK() OVER (ORDER BY SUM(item_price) DESC) AS revenue_rank
FROM ECOMMERCE_ANALYTICS.ANALYTICS.v_product_analytics
WHERE category_english IS NOT NULL
GROUP BY category_english
HAVING COUNT(*) > 30
ORDER BY revenue DESC;


-- 4B. Category monthly trend (which categories are growing?)
CREATE OR REPLACE VIEW ECOMMERCE_ANALYTICS.ANALYTICS.v_category_monthly AS
SELECT
    order_month,
    order_year,
    category_english AS category,
    COUNT(*) AS items_sold,
    ROUND(SUM(item_price), 2) AS revenue,
    ROUND(AVG(review_score), 2) AS avg_review
FROM ECOMMERCE_ANALYTICS.ANALYTICS.v_product_analytics
WHERE category_english IS NOT NULL
GROUP BY order_month, order_year, category_english
HAVING COUNT(*) > 5
ORDER BY order_month, revenue DESC;


-- 4C. Seller performance
CREATE OR REPLACE VIEW ECOMMERCE_ANALYTICS.ANALYTICS.v_seller_performance AS
SELECT
    seller_id,
    seller_city,
    seller_state,
    COUNT(*) AS items_sold,
    COUNT(DISTINCT order_id) AS orders,
    ROUND(SUM(item_price), 2) AS revenue,
    ROUND(AVG(item_price), 2) AS avg_price,
    ROUND(AVG(review_score), 2) AS avg_review,
    ROUND(SUM(CASE WHEN delivery_status = 'Late' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 1) AS late_pct,
    COUNT(DISTINCT category_english) AS categories_sold
FROM ECOMMERCE_ANALYTICS.ANALYTICS.v_product_analytics

GROUP BY seller_id, seller_city, seller_state
HAVING COUNT(*) > 10
ORDER BY revenue DESC;


-- 4D. Price segment analysis
CREATE OR REPLACE VIEW ECOMMERCE_ANALYTICS.ANALYTICS.v_price_segments AS
SELECT
    CASE
        WHEN item_price < 50 THEN '01. Under R$50'
        WHEN item_price < 100 THEN '02. R$50-100'
        WHEN item_price < 200 THEN '03. R$100-200'
        WHEN item_price < 500 THEN '04. R$200-500'
        WHEN item_price < 1000 THEN '05. R$500-1000'
        ELSE '06. R$1000+'
    END AS price_segment,
    COUNT(*) AS items_sold,
    ROUND(SUM(item_price), 2) AS revenue,
    ROUND(AVG(review_score), 2) AS avg_review,
    ROUND(AVG(freight_value), 2) AS avg_freight,
    ROUND(SUM(CASE WHEN delivery_status = 'Late' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 1) AS late_pct
FROM ECOMMERCE_ANALYTICS.ANALYTICS.v_product_analytics
GROUP BY 1
ORDER BY 1;


-- 4E. Freight cost as % of item price by category
CREATE OR REPLACE VIEW ECOMMERCE_ANALYTICS.ANALYTICS.v_freight_ratio AS
SELECT
    category_english AS category,
    COUNT(*) AS items,
    ROUND(AVG(item_price), 2) AS avg_price,
    ROUND(AVG(freight_value), 2) AS avg_freight,
    ROUND(AVG(freight_value) * 100.0 / NULLIF(AVG(item_price), 0), 1) AS freight_pct_of_price
FROM ECOMMERCE_ANALYTICS.ANALYTICS.v_product_analytics
WHERE category_english IS NOT NULL
    AND item_price > 0
GROUP BY category_english
HAVING COUNT(*) > 30
ORDER BY freight_pct_of_price DESC;
