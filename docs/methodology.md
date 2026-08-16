# Methodology: Logistics Commission Abuse Detection

**Author:** K M Kadir Koushik

---

## Problem Identification

The investigation was triggered by the Finance team flagging an unusual surge in third-party logistics partner payouts in a specific delivery region. The cost per delivery had risen significantly above the platform target threshold, and the gross-to-net (G2N) ratio had deteriorated in the same period with logistics costs identified as a primary contributor.

The Business Risk team was tasked with determining whether the surge reflected genuine demand growth or underlying process exploitation.

---

## Data Architecture

The analysis drew from four source systems joined at order and package level:

**Order Checkout Events**
Captures buyer-side order creation including device fingerprint, buyer account ID, and IP address. This table is the bridge to device-level analysis and was essential for identifying coordinated ordering patterns. The device fingerprint (UMID) persists across account changes, making it harder to evade than account-level tracking alone.

**Transaction Line Items**
The core order fulfillment table containing payment method, product details, GMV, and delivery status at item level. Used as the primary analytical anchor for all volume, value, and behavioral metrics.

**Subsidy Transactions**
Captures platform-funded and seller-funded discounts applied at item level. Included to assess whether the abusive orders were also exploiting shipping subsidies alongside commission manipulation.

**Logistics Package Data**
Provides physical package attributes including dimensions, chargeable weight, and last-mile courier assignment. Critical for split packaging detection since package size and weight distribution are the most objective signals of artificial inflation.

---

## Analytical Techniques

### Trend Analysis (15 Months)
Built a month-over-month regional package volume comparison spanning 15 months of historical data. Used region as the row dimension and months as columns to enable visual identification of the anomaly window and geographic concentration point. Established a 12-month pre-abuse baseline average per region to quantify the spike ratio.

### Price Bucket Analysis
Segmented all packages in the high-risk region by item price range using fixed buckets. Calculated each bucket's share of total packages per month and tracked changes over time. The concentration of volume in the lowest price buckets during the abuse window confirmed the arbitrage condition: items priced at a fraction of the commission rate per package.

### Device-Level Retention Analysis
Computed month-over-month device retention for buyers ordering in the high-risk region. Definition: the share of unique device IDs placing orders in month T that also placed orders in month T+1. Platform-wide genuine buyer retention typically runs 5% to 20%. The abusive cohort showed retention significantly above this range, confirming coordinated repeat ordering driven by financial motivation rather than genuine consumer demand.

### Economic Analysis
Compared average item value per package against the fixed commission payout per package verified with the Finance team. Calculated an arbitrage ratio (commission / item value) per package. Packages with a ratio above 1.0 confirm the scheme is self-financing for the colluding actors. The distribution of this ratio across the package population established the economic scale of the abuse incentive.

### Multi-Metric Seller Scoring
Combined eight behavioral signals into a composite abuse score per seller. Each signal was coded as a binary flag (0 or 1). Sellers scoring 6 or above were classified as high-confidence fraud candidates. This approach minimized false positives by requiring multiple signals to align simultaneously rather than triggering on any single indicator.

---

## Validation Approach

The fraud rule logic was validated against historical data from the abuse window. Two criteria defined a high-confidence fraudulent seller: the pattern of behavioral signals must be internally consistent (all signals pointing in the same direction) and the pattern must be structurally inconsistent with genuine seller behavior (genuine sellers do not consolidate every item in a separate package as it increases their own costs).

The risk engine rule was shadow-tested against the same historical period, confirming that abusive orders were blocked at high accuracy with minimal impact on genuine orders.

---

## Limitations

**Geographic scope:** The investigation focused on the identified high-risk region and 3PL partner. The framework is transferable to other regions but requires recalibration of thresholds based on local commission structures and product mix.

**Rider direct identification:** No single courier ID was directly tied to the abuse with certainty. The evidence pointed to systemic involvement rather than isolated individual actors. Direct rider-level attribution would require access to courier-side operational data beyond the platform's current data access.

**Threshold dependency:** The economic arbitrage analysis depends on the commission rate provided by the Finance team. Changes to the commission structure require corresponding recalibration of the price thresholds in the buyer rule.
