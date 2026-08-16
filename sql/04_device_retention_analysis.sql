-- ============================================================
-- 04_DEVICE_RETENTION_ANALYSIS.SQL
-- Logistics Commission Abuse Detection
-- Author: K M Kadir Koushik
--
-- Purpose:
--   Month-over-month device retention analysis for buyers
--   ordering in the high-risk delivery region.
--
--   Definition:
--   MoM device retention = share of devices that placed an
--   order in month T that also placed an order in month T+1.
--
--   Baseline context:
--   Platform-wide genuine buyer MoM retention typically runs
--   5% to 20% depending on campaign effects. Retention
--   significantly above this baseline in a specific region
--   indicates coordinated repeat ordering rather than organic
--   consumer demand.
--
-- Key insight:
--   Genuine buyers exhibit natural churn. Colluding actors
--   return consistently month after month because their
--   ordering is financially motivated, not demand-driven.
--   High retention in a low-value product, high-risk region
--   cohort is a strong fraud signal.
-- ============================================================

WITH monthly_devices AS (
    -- Distinct devices placing orders in the high-risk region each month
    SELECT  TO_CHAR(t.fulfillment_create_date, 'yyyy-MM')   AS order_month
            ,c.buyer_device_id

    FROM    analytics.transaction_line_items t
    JOIN    analytics.order_checkout_events c
    ON      c.buyer_account_id  = t.buyer_id
    AND     c.order_id          = t.order_number
    WHERE   t.ds = MAX_PT('analytics.transaction_line_items')
    AND     t.venture IN ('MARKET_CODE_1', 'MARKET_CODE_2', 'MARKET_CODE_3')
    AND     t.is_fulfilled = 1
    AND     t.payment_method IS NOT NULL
    AND     t.delivery_partner_name = '3PL_PARTNER'
    AND     t.shipping_sub_region_name = 'HIGH_RISK_REGION'
    AND     TO_CHAR(t.fulfillment_create_date, 'yyyy-mm-dd')
                BETWEEN DATE_ADD(GETDATE(), -180) AND DATE_ADD(GETDATE(), -1)
    GROUP BY
        TO_CHAR(t.fulfillment_create_date, 'yyyy-MM')
        ,c.buyer_device_id
)

,month_pairs AS (
    -- Self-join to find devices appearing in consecutive months
    SELECT  m1.order_month                                  AS month_t
            ,m2.order_month                                 AS month_t1
            ,COUNT(DISTINCT m1.buyer_device_id)             AS devices_in_month_t
            ,COUNT(DISTINCT m2.buyer_device_id)             AS devices_retained_in_month_t1

    FROM    monthly_devices m1
    LEFT JOIN monthly_devices m2
    ON      m1.buyer_device_id = m2.buyer_device_id
    -- Match to the immediately following month
    AND     TO_DATE(CONCAT(m2.order_month, '-01'), 'yyyy-MM-dd') =
            DATEADD(TO_DATE(CONCAT(m1.order_month, '-01'), 'yyyy-MM-dd'), 1, 'mm')

    GROUP BY m1.order_month, m2.order_month
)

SELECT  month_t                                             AS cohort_month
        ,month_t1                                           AS next_month
        ,devices_in_month_t
        ,devices_retained_in_month_t1
        ,ROUND(
            devices_retained_in_month_t1 * 100.0
            / NULLIF(devices_in_month_t, 0)
        , 2)                                                AS mom_retention_pct
        -- Flag cohorts with retention significantly above platform baseline
        ,CASE
            WHEN devices_retained_in_month_t1 * 100.0
                 / NULLIF(devices_in_month_t, 0) > 40
            THEN 'HIGH RETENTION - INVESTIGATE'
            WHEN devices_retained_in_month_t1 * 100.0
                 / NULLIF(devices_in_month_t, 0) > 20
            THEN 'ABOVE BASELINE'
            ELSE 'NORMAL'
         END                                                AS retention_flag

FROM    month_pairs
ORDER BY cohort_month ASC
;
