-- ============================================================
-- 06_ECONOMIC_ANALYSIS.SQL
-- Logistics Commission Abuse Detection
-- Author: K M Kadir Koushik
--
-- Purpose:
--   Quantifies the commission arbitrage condition that makes
--   the abuse scheme financially viable for bad actors.
--   Compares average item value per package against the
--   fixed commission payout per package to identify the
--   price range where delivery cost exceeds item value.
--
-- Key concept:
--   When the 3PL commission per package (fixed rate regardless
--   of item value) exceeds the item value in the package,
--   a colluding rider can profit purely from the commission
--   payout without needing the item to have real consumer value.
--   This is the economic engine of the scheme.
--
-- Output interpretation:
--   Rows where arbitrage_ratio > 1.0 indicate packages where
--   the commission paid exceeds the item value, confirming
--   the abuse incentive exists at that price point.
-- ============================================================

WITH package_economics AS (
    SELECT  t.venture
            ,t.order_number
            ,t.tracking_number
            ,t.seller_id
            ,t.shop_account_name
            ,t.delivery_partner_name
            ,t.shipping_sub_region_name                     AS delivery_region
            ,TO_CHAR(t.fulfillment_create_date, 'yyyy-MM')  AS month
            -- Item value per package
            ,SUM(t.paid_price * t.exchange_rate)            AS total_item_value_usd
            ,COUNT(DISTINCT t.line_item_id)                 AS items_in_package
            ,ROUND(
                SUM(t.paid_price * t.exchange_rate)
                / NULLIF(COUNT(DISTINCT t.line_item_id), 0)
            , 4)                                            AS avg_item_value_usd
            -- Package physical attributes
            ,AVG(l.package_weight_kg)                       AS avg_weight_kg
            ,AVG(l.chargeable_weight_kg)                    AS avg_chargeable_weight_kg

    FROM    analytics.transaction_line_items t
    LEFT JOIN analytics.logistics_package_data l
    ON      t.venture       = l.venture
    AND     t.order_number  = l.order_reference_number
    AND     t.tracking_number = l.tracking_number
    WHERE   t.ds = MAX_PT('analytics.transaction_line_items')
    AND     t.venture IN ('MARKET_CODE_1', 'MARKET_CODE_2', 'MARKET_CODE_3')
    AND     t.is_fulfilled = 1
    AND     t.payment_method IS NOT NULL
    AND     t.delivery_partner_name = '3PL_PARTNER'
    AND     t.shipping_sub_region_name = 'HIGH_RISK_REGION'
    AND     TO_CHAR(t.fulfillment_create_date, 'yyyy-mm-dd')
                BETWEEN DATE_ADD(GETDATE(), -120) AND DATE_ADD(GETDATE(), -1)
    GROUP BY
        t.venture, t.order_number, t.tracking_number
        ,t.seller_id, t.shop_account_name
        ,t.delivery_partner_name, t.shipping_sub_region_name
        ,TO_CHAR(t.fulfillment_create_date, 'yyyy-MM')
)

,economics_with_commission AS (
    SELECT  venture
            ,month
            ,delivery_region
            ,total_item_value_usd
            ,items_in_package
            ,avg_item_value_usd
            ,avg_weight_kg
            ,avg_chargeable_weight_kg
            -- Commission rate per package (anonymised as relative threshold)
            -- In practice this is sourced from the finance team's verified rate card
            -- Replace COMMISSION_RATE_USD with the actual verified rate
            ,COMMISSION_RATE_USD                            AS commission_per_package_usd
            -- Arbitrage ratio: commission / item value
            -- Ratio > 1 means commission exceeds item value (abuse zone)
            ,ROUND(
                COMMISSION_RATE_USD
                / NULLIF(total_item_value_usd, 0)
            , 2)                                            AS arbitrage_ratio
            -- Classify packages by arbitrage zone
            ,CASE
                WHEN COMMISSION_RATE_USD / NULLIF(total_item_value_usd, 0) > 3
                THEN 'Extreme Arbitrage (>3x)'
                WHEN COMMISSION_RATE_USD / NULLIF(total_item_value_usd, 0) > 2
                THEN 'High Arbitrage (2x to 3x)'
                WHEN COMMISSION_RATE_USD / NULLIF(total_item_value_usd, 0) > 1
                THEN 'Arbitrage Zone (1x to 2x)'
                ELSE 'No Arbitrage (<1x)'
             END                                            AS arbitrage_zone

    FROM    package_economics
)

-- Summary by month and arbitrage zone
SELECT  month
        ,delivery_region
        ,arbitrage_zone
        ,COUNT(*)                                           AS package_count
        ,ROUND(SUM(total_item_value_usd), 2)               AS total_item_value_usd
        ,ROUND(SUM(commission_per_package_usd), 2)         AS total_commission_usd
        ,ROUND(SUM(commission_per_package_usd)
             - SUM(total_item_value_usd), 2)               AS net_commission_over_value_usd
        ,ROUND(AVG(arbitrage_ratio), 2)                    AS avg_arbitrage_ratio
        ,ROUND(
            COUNT(*) * 100.0
            / NULLIF(SUM(COUNT(*)) OVER (PARTITION BY month, delivery_region), 0)
        , 2)                                                AS pct_of_packages

FROM    economics_with_commission
GROUP BY month, delivery_region, arbitrage_zone
ORDER BY month ASC
        ,CASE arbitrage_zone
            WHEN 'Extreme Arbitrage (>3x)'      THEN 1
            WHEN 'High Arbitrage (2x to 3x)'    THEN 2
            WHEN 'Arbitrage Zone (1x to 2x)'    THEN 3
            ELSE 4
         END
;
