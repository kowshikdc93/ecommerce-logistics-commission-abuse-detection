-- ============================================================
-- 03_PRICE_BUCKET_ANALYSIS.SQL
-- Logistics Commission Abuse Detection
-- Author: K M Kadir Koushik
--
-- Purpose:
--   Segments orders by item price range to determine whether
--   low-value items disproportionately drive the volume spike.
--   Confirms the commission arbitrage condition: items priced
--   below the per-package commission rate create a financial
--   incentive for artificial package inflation.
--
-- Key insight:
--   In a genuine seller population, price distribution across
--   buckets follows a normal or category-driven pattern.
--   In an abusive population, volume concentrates sharply
--   in the lowest price buckets where the arbitrage is widest.
-- ============================================================

WITH item_price_buckets AS (
    SELECT  TO_CHAR(fulfillment_create_date, 'yyyy-MM')     AS month
            ,venture
            ,shipping_sub_region_name                       AS delivery_region
            ,delivery_partner_name
            ,tracking_number
            ,order_number
            ,seller_id
            ,paid_price * exchange_rate                     AS paid_price_usd
            -- Price bucket classification
            -- Thresholds normalised; actual values anonymised
            ,CASE
                WHEN paid_price * exchange_rate < 0.10      THEN 'Bucket 1: Below 0.10 USD'
                WHEN paid_price * exchange_rate < 0.25      THEN 'Bucket 2: 0.10 to 0.25 USD'
                WHEN paid_price * exchange_rate < 0.50      THEN 'Bucket 3: 0.25 to 0.50 USD'
                WHEN paid_price * exchange_rate < 1.00      THEN 'Bucket 4: 0.50 to 1.00 USD'
                WHEN paid_price * exchange_rate < 2.00      THEN 'Bucket 5: 1.00 to 2.00 USD'
                WHEN paid_price * exchange_rate < 5.00      THEN 'Bucket 6: 2.00 to 5.00 USD'
                ELSE                                             'Bucket 7: Above 5.00 USD'
             END                                            AS price_bucket

    FROM    analytics.transaction_line_items
    WHERE   ds = MAX_PT('analytics.transaction_line_items')
    AND     venture IN ('MARKET_CODE_1', 'MARKET_CODE_2', 'MARKET_CODE_3')
    AND     is_fulfilled = 1
    AND     payment_method IS NOT NULL
    AND     TO_CHAR(fulfillment_create_date, 'yyyy-mm-dd')
                BETWEEN DATE_ADD(GETDATE(), -456) AND DATE_ADD(GETDATE(), -1)
    -- Focus on 3PL-delivered packages in the high-risk region
    AND     delivery_partner_name = '3PL_PARTNER'
    AND     shipping_sub_region_name = 'HIGH_RISK_REGION'
)

,bucket_monthly AS (
    SELECT  month
            ,delivery_region
            ,price_bucket
            ,COUNT(DISTINCT tracking_number)                AS package_count
            ,COUNT(DISTINCT order_number)                   AS order_count
            ,COUNT(DISTINCT seller_id)                      AS seller_count
            ,ROUND(AVG(paid_price_usd), 4)                  AS avg_item_price_usd

    FROM    item_price_buckets
    GROUP BY month, delivery_region, price_bucket
)

-- Final output with share of total packages per bucket per month
SELECT  month
        ,delivery_region
        ,price_bucket
        ,package_count
        ,order_count
        ,seller_count
        ,avg_item_price_usd
        ,ROUND(
            package_count * 100.0
            / NULLIF(SUM(package_count) OVER (PARTITION BY month, delivery_region), 0)
        , 2)                                                AS pct_of_total_packages

FROM    bucket_monthly

ORDER BY
    month ASC
    ,CASE price_bucket
        WHEN 'Bucket 1: Below 0.10 USD'     THEN 1
        WHEN 'Bucket 2: 0.10 to 0.25 USD'   THEN 2
        WHEN 'Bucket 3: 0.25 to 0.50 USD'   THEN 3
        WHEN 'Bucket 4: 0.50 to 1.00 USD'   THEN 4
        WHEN 'Bucket 5: 1.00 to 2.00 USD'   THEN 5
        WHEN 'Bucket 6: 2.00 to 5.00 USD'   THEN 6
        ELSE 7
     END
;
