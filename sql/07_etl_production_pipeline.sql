-- ============================================================
-- 07_ETL_PRODUCTION_PIPELINE.SQL
-- Logistics Commission Abuse Detection
-- Author: K M Kadir Koushik
--
-- Purpose:
--   Scheduled ETL pipeline for the ongoing fraud monitoring
--   table. Designed to run on a weekly schedule, maintaining
--   a rolling 90-day window of order and device data for
--   continuous commission abuse monitoring.
--
-- Production deployment notes:
--   - Deployed via Alibaba MaxCompute Scheduled Workflow
--   - Node type: SQL (.sql) with paired DDL (.ddl) node
--   - Schedule: Weekly (every Monday at 01:00 AM)
--   - Partition: ds (date), venture
--   - Auto-rerun enabled on failure (up to 3 attempts)
--   - Smoke testing required before production deployment
--   - Code review required from Data Engineering POC
--
-- Table structure:
--   Buyer-seller device connection table linking seller
--   accounts to buyer accounts through shared device IDs.
--   Used by the risk engine to detect coordinated ordering
--   between sellers and buyers on the same physical device.
--
-- Key design:
--   UNION (not UNION ALL) used to deduplicate connection
--   keys across different linkage types. Each row represents
--   one unique seller-buyer connection of a specific type.
-- ============================================================

-- ============================================================
-- STEP 1: DDL DEFINITION (buyer_seller_device_connection.ddl)
-- Run once to create the production table structure
-- ============================================================

DROP TABLE IF EXISTS buyer_seller_device_connection_monitoring;

CREATE TABLE IF NOT EXISTS buyer_seller_device_connection_monitoring
(
    seller_shop_id      STRING
    ,connection_key     STRING
    ,connection_type    STRING
)
PARTITIONED BY
(
    ds                  STRING      -- Partition date (bizdate)
    ,venture            STRING      -- Market code
)
LIFECYCLE 7  -- Table auto-expires after 7 days, refreshed weekly
;

-- ============================================================
-- STEP 2: INSERT STATEMENT (buyer_seller_device_connection.sql)
-- Runs on weekly schedule via Scheduled Workflow
-- ============================================================

-- Performance tuning: increase mapper split size for large datasets
SET odps.sql.mapper.split.size = 4096;

INSERT OVERWRITE TABLE buyer_seller_device_connection_monitoring
PARTITION (ds = '${bizdate}', venture)

WITH seller_device_mapping AS (
    -- Identify devices used to log into seller accounts
    -- Links seller user IDs to device fingerprints
    SELECT  DISTINCT
            app_events.user_id
            ,app_events.venture_code                        AS venture
            ,app_events.device_fingerprint                  AS seller_device_id
            ,seller_accounts.seller_shop_id

    FROM    (
                SELECT  user_id
                        ,venture_code
                        ,device_fingerprint
                FROM    analytics.app_user_device_events
                WHERE   SUBSTR(ds, 1, 8)
                            BETWEEN TO_CHAR(DATEADD(GETDATE(), -30, 'dd'), 'yyyymmdd')
                            AND     TO_CHAR(DATEADD(GETDATE(),   0, 'dd'), 'yyyymmdd')
            ) app_events
    JOIN    (
                SELECT  user_id
                        ,seller_shop_id
                FROM    analytics.seller_user_mapping
                WHERE   ds = '${bizdate}'
            ) seller_accounts
    ON      app_events.user_id = seller_accounts.user_id
)

,buyer_profile AS (
    -- Buyer-side attributes from order creation events
    -- Used to link buyer accounts to seller devices
    SELECT  DISTINCT
            TOLOWER(venture_code)                           AS venture
            ,device_fingerprint                             AS buyer_device_id
            ,buyer_email
            ,buyer_account_id
            ,shipping_phone_number

    FROM    analytics.order_checkout_events
    WHERE   TO_CHAR(TO_DATE(SUBSTR(ds, 1, 8), 'yyyymmdd'), 'yyyy-mm-dd')
                BETWEEN DATE_ADD(GETDATE(), -30) AND DATE_ADD(GETDATE(), -1)
)

-- Connection type 1: Seller device matches buyer device
-- Same physical device used by both seller and buyer account
SELECT  seller_device_mapping.venture
        ,seller_device_mapping.seller_shop_id
        ,CONCAT(seller_device_mapping.seller_shop_id, '_', buyer_profile.buyer_device_id)
                                                            AS connection_key
        ,'shared_device'                                    AS connection_type
FROM    seller_device_mapping
JOIN    buyer_profile
ON      seller_device_mapping.seller_device_id = buyer_profile.buyer_device_id
AND     seller_device_mapping.venture          = buyer_profile.venture

UNION

-- Connection type 2: Seller device user email matches buyer email
SELECT  seller_device_mapping.venture
        ,seller_device_mapping.seller_shop_id
        ,CONCAT(seller_device_mapping.seller_shop_id, '_', buyer_profile.buyer_email)
                                                            AS connection_key
        ,'shared_email'                                     AS connection_type
FROM    seller_device_mapping
JOIN    buyer_profile
ON      seller_device_mapping.seller_device_id = buyer_profile.buyer_device_id
AND     seller_device_mapping.venture          = buyer_profile.venture

UNION

-- Connection type 3: Seller device user linked to buyer account ID
SELECT  seller_device_mapping.venture
        ,seller_device_mapping.seller_shop_id
        ,CONCAT(seller_device_mapping.seller_shop_id, '_', buyer_profile.buyer_account_id)
                                                            AS connection_key
        ,'shared_account'                                   AS connection_type
FROM    seller_device_mapping
JOIN    buyer_profile
ON      seller_device_mapping.seller_device_id = buyer_profile.buyer_device_id
AND     seller_device_mapping.venture          = buyer_profile.venture

UNION

-- Connection type 4: Seller device user linked to buyer shipping phone
SELECT  seller_device_mapping.venture
        ,seller_device_mapping.seller_shop_id
        ,CONCAT(seller_device_mapping.seller_shop_id, '_', buyer_profile.shipping_phone_number)
                                                            AS connection_key
        ,'shared_phone'                                     AS connection_type
FROM    seller_device_mapping
JOIN    buyer_profile
ON      seller_device_mapping.seller_device_id = buyer_profile.buyer_device_id
AND     seller_device_mapping.venture          = buyer_profile.venture
;

-- ============================================================
-- PRODUCTION DEPLOYMENT CHECKLIST
-- ============================================================
-- 1. Submit DDL node for review (.ddl file)
-- 2. Submit SQL node for review (.sql file)
-- 3. Request production table access for all source tables
--    outside the current project scope
-- 4. Configure schedule: Weekly, Monday 01:00 AM
-- 5. Enable Auto Rerun: on failure only, max 3 attempts
-- 6. Set rerun interval: 30 minutes between attempts
-- 7. Run smoke test (dry-run) before production deployment
-- 8. Review smoke test logs for logical and resource errors
-- 9. Deploy to production after successful smoke test
-- 10. Monitor first scheduled run for row count validation
-- ============================================================
