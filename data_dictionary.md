# Data Dictionary

## Source: Brazilian E-Commerce (Olist) — Kaggle

## Database: ECOMMERCE_ANALYTICS | Schemas: RAW, ANALYTICS

---

## RAW Schema — Source Tables

### orders (99,441 rows)

| Column                        | Type      | Description                               | Notes                                      |
| ----------------------------- | --------- | ----------------------------------------- | ------------------------------------------ |
| order_id                      | VARCHAR   | Unique order identifier                   | PK                                         |
| customer_id                   | VARCHAR   | Customer key for this order               | FK → customers                             |
| order_status                  | VARCHAR   | Order lifecycle stage                     | Values: delivered, shipped, canceled, etc. |
| order_purchase_timestamp      | TIMESTAMP | When customer placed the order            |                                            |
| order_approved_at             | TIMESTAMP | When payment was approved                 |                                            |
| order_delivered_carrier_date  | TIMESTAMP | When order was handed to carrier          |                                            |
| order_delivered_customer_date | TIMESTAMP | Actual delivery date                      | NULL if not yet delivered                  |
| order_estimated_delivery_date | TIMESTAMP | Estimated delivery date shown to customer | Used for late/on-time calculation          |

### customers (99,441 rows)

| Column                   | Type    | Description                      | Notes                                                   |
| ------------------------ | ------- | -------------------------------- | ------------------------------------------------------- |
| customer_id              | VARCHAR | Order-level customer key         | PK, FK → orders                                         |
| customer_unique_id       | VARCHAR | Deduplicated customer identifier | One person can have multiple customer_ids across orders |
| customer_zip_code_prefix | VARCHAR | First 5 digits of zip code       |                                                         |
| customer_city            | VARCHAR | Customer city name               | Inconsistent casing in raw data                         |
| customer_state           | VARCHAR | 2-letter Brazilian state code    | SP, RJ, MG, etc.                                        |

### order_items (112,650 rows)

| Column              | Type      | Description                         | Notes                                        |
| ------------------- | --------- | ----------------------------------- | -------------------------------------------- |
| order_id            | VARCHAR   | Order identifier                    | FK → orders. Composite PK with order_item_id |
| order_item_id       | INT       | Sequential item number within order | Starts at 1                                  |
| product_id          | VARCHAR   | Product identifier                  | FK → products                                |
| seller_id           | VARCHAR   | Seller identifier                   | FK → sellers                                 |
| shipping_limit_date | TIMESTAMP | Seller shipping deadline            |                                              |
| price               | FLOAT     | Item price ($)                      | Does NOT include freight                     |
| freight_value       | FLOAT     | Freight charge for this item ($)    |                                              |

### products (32,951 rows)

| Column                     | Type    | Description                     | Notes                          |
| -------------------------- | ------- | ------------------------------- | ------------------------------ |
| product_id                 | VARCHAR | Unique product identifier       | PK                             |
| product_category_name      | VARCHAR | Category in Portuguese          | FK → category_translation      |
| product_name_lenght        | INT     | Character count of product name | Typo in original data (lenght) |
| product_description_lenght | INT     | Character count of description  |                                |
| product_photos_qty         | INT     | Number of product photos        |                                |
| product_weight_g           | INT     | Product weight in grams         |                                |
| product_length_cm          | INT     | Package length                  |                                |
| product_height_cm          | INT     | Package height                  |                                |
| product_width_cm           | INT     | Package width                   |                                |

### payments (103,886 rows)

| Column               | Type    | Description                     | Notes                                             |
| -------------------- | ------- | ------------------------------- | ------------------------------------------------- |
| order_id             | VARCHAR | Order identifier                | FK → orders. Composite PK with payment_sequential |
| payment_sequential   | INT     | Payment sequence number         | 1 = primary payment, 2+ = splits                  |
| payment_type         | VARCHAR | Payment method                  | credit_card, boleto, voucher, debit_card          |
| payment_installments | INT     | Number of installments chosen   |                                                   |
| payment_value        | FLOAT   | Amount paid in this payment ($) | Sum across sequential = total order payment       |

### reviews (99,224 rows)

| Column                  | Type      | Description                    | Notes                                    |
| ----------------------- | --------- | ------------------------------ | ---------------------------------------- |
| review_id               | VARCHAR   | Unique review identifier       | PK                                       |
| order_id                | VARCHAR   | Order identifier               | FK → orders. Mostly 1:1, rare duplicates |
| review_score            | INT       | Star rating                    | 1 (worst) to 5 (best)                    |
| review_comment_title    | VARCHAR   | Review title                   | Often NULL                               |
| review_comment_message  | VARCHAR   | Review body text               | Often NULL                               |
| review_creation_date    | TIMESTAMP | When customer submitted review |                                          |
| review_answer_timestamp | TIMESTAMP | When seller responded          |                                          |

### sellers (3,095 rows)

| Column                 | Type    | Description                  | Notes |
| ---------------------- | ------- | ---------------------------- | ----- |
| seller_id              | VARCHAR | Unique seller identifier     | PK    |
| seller_zip_code_prefix | VARCHAR | Seller zip code prefix       |       |
| seller_city            | VARCHAR | Seller city                  |       |
| seller_state           | VARCHAR | Seller state (2-letter code) |       |

### category_translation (71 rows)

| Column                        | Type    | Description                 | Notes |
| ----------------------------- | ------- | --------------------------- | ----- |
| product_category_name         | VARCHAR | Category name in Portuguese | PK    |
| product_category_name_english | VARCHAR | Category name in English    |       |

---

## ANALYTICS Schema — Views

### View Dependency Chain

```
RAW tables
    ↓
v_order_analytics (order grain)  ←── Dashboards 1, 2, 3
v_product_analytics (item grain) ←── Dashboard 4
    ↓
18 aggregated views (one per chart)
```

### Aggregation Logic Notes

- **Revenue** = SUM(total_payment) from payments table, NOT SUM(price) from order_items. Payment captures actual money collected including discounts and vouchers.
- **Primary Payment Type** = MAX_BY(payment_type, payment_value) — takes the payment method with the highest value in split-payment orders, not alphabetical MAX.
- **Review Score** = latest review per order using QUALIFY ROW_NUMBER() — handles rare duplicate reviews.
- **Customer Segment** = based on lifetime order count: 1 order = One-Time, 2-3 = Returning, 4+ = Loyal.
- **Delivery Status** = "Late" if order_delivered_customer_date > order_estimated_delivery_date, else "On Time".
