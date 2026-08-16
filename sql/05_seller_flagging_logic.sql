-- ============================================================
-- 05_SELLER_FLAGGING_LOGIC.SQL
-- Logistics Commission Abuse Detection
-- Author: K M Kadir Koushik
--
-- Purpose:
--   Multi-metric seller abuse scoring and flagging.
--   Combines behavioral signals across package structure,
--   item characteristics, logistics patterns, and geographic
--   concentration to identify sellers with high confidence
--   of participating in the commission abuse scheme.
--
-- Flagging logic:
--   A seller is flagged when multiple signals align:
--   - Packages per order significantly above 1 (split packaging)
--   - Items per package at or near 1 (no consolidation)
--   - Low item weight (lightweight items)
--   - Small max package dimension (consistent with low-value items)
--   - Average price per item below commission rate threshold
--   - High 3PL package share (over-reliance on partner)
--   - High packages per rider (concentration risk)
--   - High intra-region delivery share (geographic concentration)
--
-- Note:
--   All thresholds are relative and should be calibrated to
--   the specific commission structure and product mix of the
--   deployment market. The logic pattern is transferable
--   across markets with threshold adjustment.
-- ============================================================

WITH seller_package_metrics AS (
    SELECT  t.venture
            ,t.seller_id
            ,t.shop_account_name
            ,TO_CHAR(t.fulfillment_create_date, 'yyyy-MM')  AS month
            -- Package-level metrics
            ,COUNT(DISTINCT t.tracking_number)              AS total_packages
            ,COUNT(DISTINCT t.order_number)                 AS total_orders
            ,COUNT(DISTINCT t.line_item_id)                 AS total_items
            ,COUNT(DISTINCT t.buyer_id)                     AS unique_buyers
            -- Split packaging indicators
            ,ROUND(
                COUNT(DISTINCT t.tracking_number) * 1.0
                / NULLIF(COUNT(DISTINCT t.order_number), 0)
            , 2)                                            AS packages_per_order
            ,ROUND(
                COUNT(DISTINCT t.line_item_id) * 1.0
                / NULLIF(COUNT(DISTINCT t.tracking_number), 0)
            , 2)                                            AS items_per_package
            -- Item value metrics
            ,ROUND(AVG(t.paid_price * t.exchange_rate), 4) AS avg_paid_price_usd
            -- 3PL concentration metrics
            ,COUNT(DISTINCT CASE
                WHEN t.delivery_partner_name = '3PL_PARTNER'
                THEN t.tracking_number END)                 AS partner_packages
            ,ROUND(
                COUNT(DISTINCT CASE
                    WHEN t.delivery_partner_name = '3PL_PARTNER'
                    THEN t.tracking_number END) * 100.0
                / NULLIF(COUNT(DISTINCT t.tracking_number), 0)
            , 2)                                            AS partner_package_share_pct
            -- Geographic concentration metrics
            ,ROUND(
                COUNT(DISTINCT CASE
                    WHEN t.seller_region_id = t.shipping_region_id
                    THEN t.tracking_number END) * 100.0
                / NULLIF(COUNT(DISTINCT t.tracking_number), 0)
            , 2)                                            AS intra_region_share_pct

    FROM    analytics.transaction_line_items t
    WHERE   t.ds = MAX_PT('analytics.transaction_line_items')
    AND     t.venture IN ('MARKET_CODE_1', 'MARKET_CODE_2', 'MARKET_CODE_3')
    AND     t.is_fulfilled = 1
    AND     t.payment_method IS NOT NULL
    AND     TO_CHAR(t.fulfillment_create_date, 'yyyy-mm-dd')
                BETWEEN DATE_ADD(GETDATE(), -91) AND DATE_ADD(GETDATE(), -1)
    GROUP BY t.venture, t.seller_id, t.shop_account_name
            ,TO_CHAR(t.fulfillment_create_date, 'yyyy-MM')
)

,seller_logistics_metrics AS (
    -- Package physical attributes per seller
    SELECT  t.seller_id
            ,TO_CHAR(t.fulfillment_create_date, 'yyyy-MM')  AS month
            ,ROUND(AVG(l.max_package_dimension_cm), 2)      AS avg_max_dimension_cm
            ,ROUND(AVG(l.package_weight_kg), 4)             AS avg_package_weight_kg
            ,COUNT(DISTINCT l.last_mile_courier_id)         AS unique_couriers
            ,ROUND(
                COUNT(DISTINCT t.tracking_number) * 1.0
                / NULLIF(COUNT(DISTINCT l.last_mile_courier_id), 0)
            , 2)                                            AS packages_per_courier

    FROM    analytics.transaction_line_items t
    JOIN    analytics.logistics_package_data l
    ON      t.venture       = l.venture
    AND     t.order_number  = l.order_reference_number
    AND     t.tracking_number = l.tracking_number
    WHERE   t.ds = MAX_PT('analytics.transaction_line_items')
    AND     t.venture IN ('MARKET_CODE_1', 'MARKET_CODE_2', 'MARKET_CODE_3')
    AND     t.is_fulfilled = 1
    AND     TO_CHAR(t.fulfillment_create_date, 'yyyy-mm-dd')
                BETWEEN DATE_ADD(GETDATE(), -91) AND DATE_ADD(GETDATE(), -1)
    GROUP BY t.seller_id
            ,TO_CHAR(t.fulfillment_create_date, 'yyyy-MM')
)

,seller_scored AS (
    SELECT  p.venture
            ,p.seller_id
            ,p.shop_account_name
            ,p.month
            ,p.total_packages
            ,p.total_orders
            ,p.total_items
            ,p.unique_buyers
            ,p.packages_per_order
            ,p.items_per_package
            ,p.avg_paid_price_usd
            ,p.partner_packages
            ,p.partner_package_share_pct
            ,p.intra_region_share_pct
            ,l.avg_max_dimension_cm
            ,l.avg_package_weight_kg
            ,l.packages_per_courier
            -- Individual signal flags
            ,CASE WHEN p.packages_per_order > 2
                  THEN 1 ELSE 0 END                         AS flag_split_packaging
            ,CASE WHEN p.items_per_package <= 1.2
                  THEN 1 ELSE 0 END                         AS flag_no_consolidation
            ,CASE WHEN l.avg_package_weight_kg < 0.2
                  THEN 1 ELSE 0 END                         AS flag_low_weight
            ,CASE WHEN l.avg_max_dimension_cm BETWEEN 10 AND 30
                  THEN 1 ELSE 0 END                         AS flag_small_dimension
            ,CASE WHEN p.avg_paid_price_usd < 0.25
                  THEN 1 ELSE 0 END                         AS flag_below_arbitrage_threshold
            ,CASE WHEN p.partner_package_share_pct > 50
                  THEN 1 ELSE 0 END                         AS flag_high_partner_share
            ,CASE WHEN l.packages_per_courier > 100
                  THEN 1 ELSE 0 END                         AS flag_high_packages_per_courier
            ,CASE WHEN p.intra_region_share_pct > 50
                  THEN 1 ELSE 0 END                         AS flag_geographic_concentration

    FROM    seller_package_metrics p
    LEFT JOIN seller_logistics_metrics l
    ON      p.seller_id = l.seller_id
    AND     p.month     = l.month
)

SELECT  venture
        ,seller_id
        ,shop_account_name
        ,month
        ,total_packages
        ,total_orders
        ,total_items
        ,unique_buyers
        ,packages_per_order
        ,items_per_package
        ,avg_paid_price_usd
        ,partner_package_share_pct
        ,intra_region_share_pct
        ,avg_max_dimension_cm
        ,avg_package_weight_kg
        ,packages_per_courier
        -- Total abuse signal score (sum of all flags)
        ,(flag_split_packaging + flag_no_consolidation + flag_low_weight
          + flag_small_dimension + flag_below_arbitrage_threshold
          + flag_high_partner_share + flag_high_packages_per_courier
          + flag_geographic_concentration)                  AS abuse_signal_score
        -- Final classification
        ,CASE
            WHEN (flag_split_packaging + flag_no_consolidation + flag_low_weight
                  + flag_small_dimension + flag_below_arbitrage_threshold
                  + flag_high_partner_share + flag_high_packages_per_courier
                  + flag_geographic_concentration) >= 6
            THEN 'HIGH CONFIDENCE FRAUD'
            WHEN (flag_split_packaging + flag_no_consolidation + flag_low_weight
                  + flag_small_dimension + flag_below_arbitrage_threshold
                  + flag_high_partner_share + flag_high_packages_per_courier
                  + flag_geographic_concentration) >= 4
            THEN 'INVESTIGATE'
            ELSE 'NORMAL'
         END                                                AS seller_risk_classification

FROM    seller_scored
ORDER BY abuse_signal_score DESC, total_packages DESC
;
