-- ============================================================
-- 02_TREND_ANALYSIS.SQL
-- Logistics Commission Abuse Detection
-- Author: K M Kadir Koushik
--
-- Purpose:
--   Month-over-month regional package volume trend analysis
--   spanning 15 months of historical data. Identifies the
--   specific delivery region and time window where the
--   volume anomaly concentrated.
--
-- Key insight this query surfaces:
--   Genuine demand growth is gradual and distributed across
--   multiple regions. Abuse-driven volume spikes are sudden,
--   concentrated in a specific region, and disproportionate
--   to any campaign or seasonal effect.
-- ============================================================

WITH monthly_regional_volume AS (
    SELECT  TO_CHAR(fulfillment_create_date, 'yyyy-MM')     AS month
            ,shipping_sub_region_name                       AS delivery_region
            ,delivery_partner_name
            ,venture
            ,COUNT(DISTINCT tracking_number)                AS total_packages
            ,COUNT(DISTINCT order_number)                   AS total_orders
            ,COUNT(DISTINCT buyer_id)                       AS unique_buyers
            ,COUNT(DISTINCT seller_id)                      AS unique_sellers
            ,ROUND(
                COUNT(DISTINCT tracking_number) * 1.0
                / NULLIF(COUNT(DISTINCT order_number), 0)
            , 2)                                            AS packages_per_order

    FROM    analytics.transaction_line_items
    WHERE   ds = MAX_PT('analytics.transaction_line_items')
    AND     venture IN ('MARKET_CODE_1', 'MARKET_CODE_2', 'MARKET_CODE_3')
    AND     is_fulfilled = 1
    AND     payment_method IS NOT NULL
    AND     TO_CHAR(fulfillment_create_date, 'yyyy-mm-dd')
                BETWEEN DATE_ADD(GETDATE(), -456) AND DATE_ADD(GETDATE(), -1)
    GROUP BY
        TO_CHAR(fulfillment_create_date, 'yyyy-MM')
        ,shipping_sub_region_name
        ,delivery_partner_name
        ,venture
)

,regional_baseline AS (
    -- Calculate 12-month baseline average per region
    -- Used to identify anomalous spikes vs normal growth
    SELECT  delivery_region
            ,delivery_partner_name
            ,venture
            ,ROUND(AVG(total_packages), 0)                  AS baseline_avg_packages
            ,ROUND(AVG(packages_per_order), 2)              AS baseline_avg_packages_per_order

    FROM    monthly_regional_volume
    -- Use older months as baseline window (before suspected abuse period)
    WHERE   month < FORMAT_DATE(DATE_ADD(GETDATE(), -90), 'yyyy-MM')
    GROUP BY delivery_region, delivery_partner_name, venture
)

SELECT  v.month
        ,v.delivery_region
        ,v.delivery_partner_name
        ,v.venture
        ,v.total_packages
        ,v.total_orders
        ,v.unique_buyers
        ,v.unique_sellers
        ,v.packages_per_order
        ,b.baseline_avg_packages
        ,b.baseline_avg_packages_per_order
        -- Spike ratio: how many times above baseline
        ,ROUND(
            v.total_packages * 1.0
            / NULLIF(b.baseline_avg_packages, 0)
        , 2)                                                AS spike_ratio_vs_baseline
        -- Flag regions exceeding 2x baseline as anomalous
        ,CASE
            WHEN v.total_packages > b.baseline_avg_packages * 2
            THEN 'ANOMALOUS'
            ELSE 'NORMAL'
         END                                                AS volume_flag

FROM    monthly_regional_volume v
LEFT JOIN regional_baseline b
ON      v.delivery_region       = b.delivery_region
AND     v.delivery_partner_name = b.delivery_partner_name
AND     v.venture               = b.venture

ORDER BY v.venture ASC, v.delivery_region ASC, v.month ASC
;
