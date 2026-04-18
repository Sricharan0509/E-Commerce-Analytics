-- ═══════════════════════════════════════════════════════════════════
-- DATA QUALITY VERIFICATION QUERIES
-- Run these after loading data and creating views to verify integrity
-- ═══════════════════════════════════════════════════════════════════

-- ══ CHECK 1: Raw table row counts ══
-- Expected counts are from the original Olist dataset
SELECT 'orders' AS tbl, COUNT(*) AS actual, 99441 AS expected FROM ECOMMERCE_ANALYTICS.RAW.orders
UNION ALL SELECT 'customers', COUNT(*), 99441 FROM ECOMMERCE_ANALYTICS.RAW.customers
UNION ALL SELECT 'payments', COUNT(*), 103886 FROM ECOMMERCE_ANALYTICS.RAW.payments
UNION ALL SELECT 'reviews', COUNT(*), 99224 FROM ECOMMERCE_ANALYTICS.RAW.reviews
UNION ALL SELECT 'order_items', COUNT(*), 112650 FROM ECOMMERCE_ANALYTICS.RAW.order_items
UNION ALL SELECT 'products', COUNT(*), 32951 FROM ECOMMERCE_ANALYTICS.RAW.products
UNION ALL SELECT 'sellers', COUNT(*), 3095 FROM ECOMMERCE_ANALYTICS.RAW.sellers
UNION ALL SELECT 'category_translation', COUNT(*), 71 FROM ECOMMERCE_ANALYTICS.RAW.category_translation
ORDER BY tbl;


-- ══ CHECK 2: v_order_analytics — one row per order ══
-- total_rows MUST equal unique_orders
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_orders,
    CASE WHEN COUNT(*) = COUNT(DISTINCT order_id) THEN '✅ PASS' ELSE '❌ FAIL — DUPLICATES' END AS status
FROM ECOMMERCE_ANALYTICS.ANALYTICS.v_order_analytics;


-- ══ CHECK 3: v_product_analytics — one row per item ══
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id || '-' || order_item_id) AS unique_items,
    CASE WHEN COUNT(*) = COUNT(DISTINCT order_id || '-' || order_item_id) THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM ECOMMERCE_ANALYTICS.ANALYTICS.v_product_analytics;


-- ══ CHECK 4: KPIs sanity check ══
SELECT
    *,
    CASE WHEN TOTAL_REVENUE BETWEEN 10000000 AND 20000000 THEN '✅ Revenue OK' ELSE '❌ Revenue WRONG' END AS rev_check,
    CASE WHEN TOTAL_ORDERS BETWEEN 90000 AND 100000 THEN '✅ Orders OK' ELSE '❌ Orders WRONG' END AS ord_check,
    CASE WHEN AVG_REVIEW_SCORE BETWEEN 3.5 AND 4.5 THEN '✅ Review OK' ELSE '❌ Review WRONG' END AS rev_score_check
FROM ECOMMERCE_ANALYTICS.ANALYTICS.v_exec_kpis;


-- ══ CHECK 5: No NULL payment types in payment breakdown ══
SELECT
    PRIMARY_PAYMENT_TYPE,
    ORDER_COUNT,
    CASE WHEN PRIMARY_PAYMENT_TYPE IS NULL THEN '⚠️ NULL payment type found' ELSE '✅ OK' END AS status
FROM ECOMMERCE_ANALYTICS.ANALYTICS.v_payment_breakdown
ORDER BY ORDER_COUNT DESC;


-- ══ CHECK 6: Delivery status values are clean ══
-- Should only have 'On Time' and 'Late' — no typos like 'On TIme'
SELECT DISTINCT delivery_status, COUNT(*) AS cnt
FROM ECOMMERCE_ANALYTICS.ANALYTICS.v_order_analytics
GROUP BY delivery_status;

SELECT DISTINCT delivery_status, COUNT(*) AS cnt
FROM ECOMMERCE_ANALYTICS.ANALYTICS.v_product_analytics
GROUP BY delivery_status;


-- ══ CHECK 7: All 20 views exist and have data ══
SELECT 'v_order_analytics' AS view_name, COUNT(*) AS rows FROM ANALYTICS.v_order_analytics
UNION ALL SELECT 'v_product_analytics', COUNT(*) FROM ANALYTICS.v_product_analytics
UNION ALL SELECT 'v_exec_kpis', COUNT(*) FROM ANALYTICS.v_exec_kpis
UNION ALL SELECT 'v_monthly_revenue', COUNT(*) FROM ANALYTICS.v_monthly_revenue
UNION ALL SELECT 'v_revenue_by_state', COUNT(*) FROM ANALYTICS.v_revenue_by_state
UNION ALL SELECT 'v_payment_breakdown', COUNT(*) FROM ANALYTICS.v_payment_breakdown
UNION ALL SELECT 'v_orders_by_day', COUNT(*) FROM ANALYTICS.v_orders_by_day
UNION ALL SELECT 'v_customer_segments', COUNT(*) FROM ANALYTICS.v_customer_segments
UNION ALL SELECT 'v_segments_by_state', COUNT(*) FROM ANALYTICS.v_segments_by_state
UNION ALL SELECT 'v_new_vs_returning', COUNT(*) FROM ANALYTICS.v_new_vs_returning
UNION ALL SELECT 'v_cohort_retention', COUNT(*) FROM ANALYTICS.v_cohort_retention
UNION ALL SELECT 'v_delivery_impact', COUNT(*) FROM ANALYTICS.v_delivery_impact
UNION ALL SELECT 'v_state_delivery', COUNT(*) FROM ANALYTICS.v_state_delivery
UNION ALL SELECT 'v_delivery_distribution', COUNT(*) FROM ANALYTICS.v_delivery_distribution
UNION ALL SELECT 'v_monthly_delivery', COUNT(*) FROM ANALYTICS.v_monthly_delivery
UNION ALL SELECT 'v_category_performance', COUNT(*) FROM ANALYTICS.v_category_performance
UNION ALL SELECT 'v_category_monthly', COUNT(*) FROM ANALYTICS.v_category_monthly
UNION ALL SELECT 'v_seller_performance', COUNT(*) FROM ANALYTICS.v_seller_performance
UNION ALL SELECT 'v_price_segments', COUNT(*) FROM ANALYTICS.v_price_segments
UNION ALL SELECT 'v_freight_ratio', COUNT(*) FROM ANALYTICS.v_freight_ratio
ORDER BY view_name;
