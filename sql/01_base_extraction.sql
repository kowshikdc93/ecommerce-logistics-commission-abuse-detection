-- ============================================================
-- 01_BASE_EXTRACTION.SQL
-- Logistics Commission Abuse Detection
-- Author: K M Kadir Koushik
--
-- Purpose:
--   Multi-source data extraction joining four core tables:
--   checkout events, transaction line items, subsidy records,
--   and logistics package data. Produces the foundational
--   dataset used across all downstream analyses.
--
-- Key design decisions:
--   - Checkout table anchors the buyer device ID, enabling
--     device-level analysis downstream
--   - Logistics table provides package physical attributes
--     (dimensions, weight, courier) essential for split
--     packaging detection
--   - Subsidy table captures platform-funded discount exposure
--     per order
--   - Seller-buyer region match flag derived at join time to
--     identify geographic concentration patterns
--   - payment_method IS NOT NULL filter removes orders that
--     never reached payment execution
--   - Excluded internal seller categories (packaging material,
--     logistics services) to isolate genuine seller behavior
-- ============================================================

WITH checkout_events AS (
    -- Buyer-side order creation events
    -- Provides device fingerprint and account linkage
    SELECT  SUBSTR(ds, 1, 8)                        AS event_date
            ,buyer_device_id
            ,buyer_email
            ,buyer_account_id
            ,order_id
            ,ip_address

    FROM    analytics.order_checkout_events
    WHERE   TO_CHAR(TO_DATE(SUBSTR(ds, 1, 8), 'yyyymmdd'), 'yyyy-mm-dd')
                BETWEEN DATE_ADD(GETDATE(), -91) AND DATE_ADD(GETDATE(), -1)
    AND     venture IN ('MARKET_CODE_1', 'MARKET_CODE_2', 'MARKET_CODE_3')
)

,transaction_items AS (
    -- Item-level transaction and fulfillment data
    -- Core table for order analysis
    SELECT  TO_CHAR(fulfillment_create_date, 'yyyy-mm-dd')  AS fulfillment_date
            ,TO_CHAR(delivery_date, 'yyyy-mm-dd')           AS delivery_date
            ,WEEKOFYEAR(fulfillment_create_date)            AS fulfillment_week
            ,WEEKOFYEAR(delivery_date)                      AS delivery_week
            ,seller_region_id
            ,venture
            ,ready_to_ship_date
            ,payment_method
            ,shipping_region_id
            ,billing_region_id
            ,billing_region_name
            ,shipping_region_name
            ,shipping_sub_region_name
            ,shipping_address
            ,shop_account_name
            ,seller_id
            ,buyer_id
            ,order_number
            ,line_item_id
            ,tracking_number
            ,sku_id
            ,product_sku
            ,exchange_rate
            ,actual_gmv * exchange_rate                     AS gmv_usd
            ,paid_amount * exchange_rate                    AS paid_amount_usd
            ,list_price * exchange_rate                     AS list_price_usd
            ,paid_price * exchange_rate                     AS paid_price_usd
            ,shipping_fee_total * exchange_rate             AS shipping_fee_usd
            ,item_delivery_status
            ,deepest_category_name
            ,product_name
            ,delivery_partner_name

    FROM    analytics.transaction_line_items
    WHERE   ds = MAX_PT('analytics.transaction_line_items')
    AND     TO_CHAR(fulfillment_create_date, 'yyyy-mm-dd')
                BETWEEN DATE_ADD(GETDATE(), -91) AND DATE_ADD(GETDATE(), -1)
    AND     venture IN ('MARKET_CODE_1', 'MARKET_CODE_2', 'MARKET_CODE_3')
    AND     is_fulfilled = 1
    AND     payment_method IS NOT NULL
    -- Exclude internal platform seller categories
    AND     category_level2_name NOT IN (
                'Packaging Material',
                'Logistics Services',
                'Platform Services',
                'Seller Tools'
            )
)

,subsidy_records AS (
    -- Platform and seller-funded discount data per order
    SELECT  venture
            ,order_number
            ,line_item_id
            ,voucher_name
            ,collectible_discount_name
            ,platform_discount_total * exchange_rate        AS platform_discount_usd
            ,platform_shipping_discount * exchange_rate     AS platform_shipping_discount_usd
            ,partner_shipping_discount * exchange_rate      AS partner_shipping_discount_usd
            ,seller_shipping_discount * exchange_rate       AS seller_shipping_discount_usd
            ,platform_collectible_discount * exchange_rate  AS platform_collectible_discount_usd

    FROM    analytics.subsidy_transactions
    WHERE   ds = MAX_PT('analytics.subsidy_transactions')
)

,logistics_packages AS (
    -- Package-level logistics data
    -- Critical for split packaging detection
    SELECT  order_reference_number
            ,tracking_number
            ,venture
            ,first_mile_courier_id
            ,first_mile_courier_name
            ,last_mile_courier_id
            ,last_mile_courier_name
            ,last_mile_hub_id
            ,last_mile_hub_name
            -- Derive maximum package dimension for size analysis
            ,CASE
                WHEN package_height >= package_width
                 AND package_height >= package_length    THEN package_height
                WHEN package_width  >= package_height
                 AND package_width  >= package_length    THEN package_width
                ELSE package_length
             END                                            AS max_package_dimension_cm
            ,payment_type
            ,delivery_type
            ,partner_name
            ,origin_hub_name
            ,package_width_cm
            ,package_length_cm
            ,package_height_cm
            ,package_weight_kg
            ,chargeable_weight_kg

    FROM    analytics.logistics_package_data
    WHERE   ds = MAX_PT('analytics.logistics_package_data')
)

-- FINAL JOINED DATASET
SELECT  t.fulfillment_date
        ,t.fulfillment_week
        ,t.delivery_week
        ,t.delivery_date
        ,t.ready_to_ship_date
        ,t.venture
        ,t.seller_id
        ,t.shop_account_name
        ,t.seller_region_id
        ,t.buyer_id
        ,c.buyer_device_id
        ,c.ip_address
        ,t.order_number
        ,t.line_item_id
        ,t.tracking_number
        ,t.sku_id
        ,t.product_sku
        ,t.product_name
        ,t.deepest_category_name
        ,t.payment_method
        ,t.delivery_partner_name
        ,t.shipping_region_id
        ,t.billing_region_id
        ,t.shipping_region_name
        ,t.billing_region_name
        ,t.shipping_sub_region_name
        ,t.shipping_address
        ,t.exchange_rate
        ,t.gmv_usd
        ,t.paid_amount_usd
        ,t.paid_price_usd
        ,t.list_price_usd
        ,t.shipping_fee_usd
        ,l.last_mile_courier_id
        ,l.last_mile_courier_name
        ,l.last_mile_hub_id
        ,l.last_mile_hub_name
        ,l.max_package_dimension_cm
        ,l.package_weight_kg
        ,l.chargeable_weight_kg
        -- Seller-buyer region match flag for geographic concentration analysis
        ,CASE
            WHEN t.seller_region_id = t.shipping_region_id THEN 'REGION_MATCH'
            ELSE 'REGION_MISMATCH'
         END                                                AS seller_buyer_region_flag
        -- Package fulfillment stage classification
        ,CASE
            WHEN t.ready_to_ship_date IS NULL               THEN 'Pre-RTS'
            WHEN t.ready_to_ship_date IS NOT NULL
             AND t.delivery_date IS NULL                    THEN 'Post-RTS Pre-Delivery'
            WHEN t.ready_to_ship_date IS NOT NULL
             AND t.delivery_date IS NOT NULL                THEN 'Delivered'
            ELSE NULL
         END                                                AS package_stage
        ,SUM(t.gmv_usd)                                     AS total_gmv_usd
        ,SUM(t.shipping_fee_usd)                            AS total_shipping_fee_usd
        ,SUM(s.platform_discount_usd)                       AS total_platform_discount_usd
        ,SUM(s.platform_shipping_discount_usd)              AS total_platform_shipping_discount_usd

FROM    transaction_items t
JOIN    checkout_events c
ON      c.buyer_account_id  = t.buyer_id
AND     c.order_id          = t.order_number
JOIN    subsidy_records s
ON      t.order_number      = s.order_number
AND     t.line_item_id      = s.line_item_id
LEFT JOIN logistics_packages l
ON      t.venture           = l.venture
AND     t.order_number      = l.order_reference_number
AND     t.tracking_number   = l.tracking_number

GROUP BY
    t.fulfillment_date, t.fulfillment_week, t.delivery_week
    ,t.delivery_date, t.ready_to_ship_date, t.venture
    ,t.seller_id, t.shop_account_name, t.seller_region_id
    ,t.buyer_id, c.buyer_device_id, c.ip_address
    ,t.order_number, t.line_item_id, t.tracking_number
    ,t.sku_id, t.product_sku, t.product_name
    ,t.deepest_category_name, t.payment_method
    ,t.delivery_partner_name, t.shipping_region_id
    ,t.billing_region_id, t.shipping_region_name
    ,t.billing_region_name, t.shipping_sub_region_name
    ,t.shipping_address, t.exchange_rate
    ,t.gmv_usd, t.paid_amount_usd, t.paid_price_usd
    ,t.list_price_usd, t.shipping_fee_usd
    ,l.last_mile_courier_id, l.last_mile_courier_name
    ,l.last_mile_hub_id, l.last_mile_hub_name
    ,l.max_package_dimension_cm, l.package_weight_kg
    ,l.chargeable_weight_kg
    ,CASE WHEN t.seller_region_id = t.shipping_region_id THEN 'REGION_MATCH' ELSE 'REGION_MISMATCH' END
    ,CASE
        WHEN t.ready_to_ship_date IS NULL THEN 'Pre-RTS'
        WHEN t.ready_to_ship_date IS NOT NULL AND t.delivery_date IS NULL THEN 'Post-RTS Pre-Delivery'
        WHEN t.ready_to_ship_date IS NOT NULL AND t.delivery_date IS NOT NULL THEN 'Delivered'
        ELSE NULL
     END
;
