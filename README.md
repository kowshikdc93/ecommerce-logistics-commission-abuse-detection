# Logistics Commission Abuse Detection
### E-Commerce Risk Analytics | 3PL Rider Commission Fraud Framework

**Author:** K M Kadir Koushik  
**Domain:** Risk Analytics | Logistics Fraud Detection | Cost Leakage Quantification  
**Stack:** ODPS SQL (MaxCompute) | Alibaba Cloud Data Warehouse | FineBI (Dashboard)  
**Venture:** South Asian E-Commerce Platform

---

## Overview

This project documents a full-cycle fraud detection and mitigation framework built to investigate, quantify, and prevent a logistics commission abuse scheme operating across a major South Asian e-commerce platform.

The scheme involved coordinated collusion between third-party logistics (3PL) riders and sellers, who artificially split single multi-item orders into individual packages to inflate commission payouts. Since the platform paid a fixed commission per package to 3PL partners — significantly higher than the per-item wholesale cost — this created a clear financial arbitrage that bad actors exploited at scale.

The investigation identified the root cause, quantified the financial leakage, and resulted in three approved recommendations that were implemented into the platform's compliance policy and risk engine.

---

## The Problem

The finance team flagged an unusual surge in 3PL partner payouts in a specific delivery region. Monthly package volumes in the region jumped from a normal baseline of 5K to 15K packages to 40K to 62K packages within a three-month window, representing a four to five times increase with no corresponding growth in genuine buyer demand.

The cost per delivery had risen significantly from the historical baseline, and the platform's gross-to-net (G2N) ratio had deteriorated in the same period, with logistics costs identified as a primary contributor.

```
Normal monthly volume:   5,000 - 15,000 packages
Abuse window volume:    40,000 - 62,000 packages
Abnormal packages:      ~180,000 over the abuse window
Packages linked to abuse: ~94% of total volume
```

---

## Root Cause: Split Packaging

Sellers processed multi-item orders by issuing individual airway bills for each item rather than consolidating them into a single shipment. A genuine seller with 100 items in a single order would typically ship one or two packages. The fraudulent sellers were generating 100 individual packages from the same order.

Since the 3PL partner was paid a fixed commission per package regardless of package size or item value, splitting items into individual packages multiplied the commission payout by the number of items. Items valued at a fraction of the commission rate per package created a significant arbitrage opportunity for riders who placed or coordinated these orders.

```
Item value per unit:        Very low (fraction of commission rate)
3PL commission per package: Fixed rate regardless of item value
Arbitrage ratio:            Commission >> Item value
Result:                     Each artificially split package generates net positive 
                            income for the colluding rider
```

---

## Methodology

### Data Sources

| Source | Purpose |
|---|---|
| `analytics.order_checkout_events` | Buyer device ID, account ID, order ID at checkout |
| `analytics.transaction_line_items` | Fulfillment details, GMV, payment method, delivery status |
| `analytics.subsidy_transactions` | Platform and seller-funded subsidies per order |
| `analytics.logistics_package_data` | Package dimensions, weight, courier ID, last-mile node |

### Analytical Techniques

**1. Trend Analysis**
Month-over-month package volume comparison across 3PL-covered delivery regions, spanning 15 months of historical data. Identified the specific region and time window where the anomaly concentrated.

**2. Price Bucket Analysis**
Segmented orders by item price range to identify whether low-value items disproportionately drove the volume spike. Confirmed that the vast majority of abusive packages contained items priced at a fraction of the commission payout rate.

**3. Device-Level Retention Analysis**
Computed month-over-month device retention for buyers ordering in the high-risk region. Platform-wide buyer retention typically runs 5% to 20% depending on campaign effects. The abusive cohort showed retention significantly above this baseline, confirming coordinated repeat ordering rather than genuine organic demand.

**4. Economic Analysis**
Compared the average item value per order against the fixed commission payout per package. Identified the price threshold below which commission exceeds item value, creating the arbitrage condition that makes the scheme profitable.

**5. Multi-Metric Seller Flagging**
Combined multiple behavioral signals to identify fraudulent sellers with high precision:

| Signal | Fraudulent Pattern | Genuine Pattern |
|---|---|---|
| Packages per order | High (one package per item) | Low (multiple items per package) |
| Items per package | 1 | Greater than 1 |
| Item weight | Very low (under 200g) | Varies by category |
| Max package dimension | Very small (10 to 30 cm) | Varies by category |
| Average price per item | Below commission rate | Normal range |
| 3PL package share | High (above 50%) | Varies |
| Packages per rider | Very high | Normal distribution |
| Intra-region delivery share | High | Normal distribution |

---

## Key Findings

**Finding 1: Volume Anomaly is Highly Concentrated**
The surge was not distributed across the region but concentrated among a small number of sellers operating with near-identical behavioral patterns, confirming coordination rather than coincidence.

**Finding 2: Split Packaging is the Core Mechanism**
Approximately 94% of the abnormal package volume traced back to sellers issuing individual airway bills per item. This is structurally inconsistent with genuine seller behavior, where consolidation reduces costs.

**Finding 3: Low-Value Items Dominate**
Price bucket analysis confirmed that the overwhelming majority of abnormal packages contained extremely low-value items (stationery, small accessories) whose individual unit value was a small fraction of the commission rate per package, confirming the arbitrage logic.

**Finding 4: Coordinated Repeat Ordering**
Device-level retention analysis showed the same devices repeatedly ordering maximum allowed quantities of the same low-value items month over month, with retention rates far above the platform baseline. This pattern is inconsistent with genuine consumer demand.

**Finding 5: Economic Arbitrage Confirmed**
At the item value levels observed, the financial return from commission per package substantially exceeded the cost of purchasing the items, making the scheme self-financing for colluding riders.

**Finding 6: Buyer-Seller Region Overlap**
Over 80% of suspicious orders showed geographic overlap between seller warehouse location and buyer delivery address, suggesting buyers and sellers were either the same entity or closely coordinated.

---

## Impact Assessment

The financial leakage from the scheme was quantified across the abuse window and expressed as a share of the platform's profitability metric (PM2):

- Leakage represented a significant portion of the PM2 shortfall during the abuse period
- The scheme directly inflated cost per delivery above the platform's target threshold
- Restoration of normal package volumes to the pre-abuse baseline was the primary financial recovery lever

---

## Recommendations and Outcomes

### Recommendation 1: Seller Compliance Policy Amendment
Introduced a specific clause against split-packaging practices with a penalty framework, empowering the compliance team to take action against non-compliant sellers without legal ambiguity.

**Status: Approved and implemented**

### Recommendation 2: Minimum Product Price Threshold
Established a minimum per-item price threshold to eliminate the commission arbitrage condition. Items priced below this threshold cannot qualify for standard 3PL commission payouts, removing the economic incentive for the scheme.

**Status: Approved and implemented**

### Recommendation 3: Risk Engine Rule Deployment
Deployed a real-time rule in the platform's risk engine to block shipping discounts for new buyers whose order patterns match the abuse profile:

```
IF average_item_price < THRESHOLD_USD
   AND items_below_threshold_price > 10
   AND buyer_type = 'New Buyer'
   AND seller_type NOT IN ('Flagship', 'Certified')
   AND shipping_region = 'HIGH_RISK_REGION'
THEN
   block_shipping_discount
```

Shadow run validation on historical data: 99% of abusive orders correctly blocked, minimal impact on genuine orders.

**Status: Approved and implemented**

### Long-Term: End-to-End Process Flow
Designed a structured cross-functional process flow covering detection ownership (Risk), initial preventive action (Compliance and Finance), package interception (Operations), and enforcement consequences for sellers, riders, and 3PL staff.

---

## Monitoring Framework

Built a fraud monitoring dashboard covering daily package trends, 3PL partner share, and seller-level metrics. The dashboard provides continuous visibility for ongoing abuse prevention.

**Seller-level metrics monitored:**

| Metric | Purpose |
|---|---|
| Packages per order | Detect abnormal splitting behavior |
| Items per package | Confirm consolidation or splitting |
| Packages per rider | Identify disproportionate rider concentration |
| 3PL package share | Track outsourcing dependency |
| Max dimension per package | Validate physical package characteristics |
| Average item weight per package | Detect low-weight abuse patterns |
| Average price per product | Monitor for commission arbitrage conditions |
| Intra-region delivery share | Detect geographic concentration |

---

## Repository Structure

```
ecommerce-logistics-commission-abuse-detection/
├── README.md                                    # This file
├── sql/
│   ├── 01_base_extraction.sql                   # Multi-source data extraction and join architecture
│   ├── 02_trend_analysis.sql                    # Month-over-month regional package volume trend
│   ├── 03_price_bucket_analysis.sql             # Item price distribution and bucket segmentation
│   ├── 04_device_retention_analysis.sql         # Device-level MoM retention for coordinated buyer detection
│   ├── 05_seller_flagging_logic.sql             # Multi-metric seller abuse scoring and flagging
│   ├── 06_economic_analysis.sql                 # Commission vs item value arbitrage quantification
│   └── 07_etl_production_pipeline.sql           # Scheduled ETL pipeline for ongoing monitoring table
├── docs/
│   ├── methodology.md                           # Full analytical methodology
│   ├── findings.md                              # Pattern-level findings
│   └── process_flow.md                          # Cross-functional response and enforcement SOP
└── assets/
    └── dashboard_metrics.md                     # Monitoring dashboard metric definitions
```

---

## Skills Demonstrated

- **Advanced ODPS SQL:** Multi-source join architecture across checkout, transaction, subsidy, and logistics tables; rolling window analytics; conditional aggregation; ETL pipeline development with scheduled automation
- **Fraud Pattern Recognition:** Split packaging detection, device-level coordination analysis, price arbitrage quantification, geographic concentration analysis
- **Economic Analysis:** Commission structure modeling, arbitrage condition identification, financial leakage quantification
- **Risk Engine Rule Design:** Behavioral rule logic, shadow run validation methodology, false positive minimization
- **Cross-Functional SOP Design:** End-to-end process flow covering detection, interception, enforcement, and accountability across Risk, Compliance, Finance, and Operations
- **Production Data Engineering:** DDL creation, INSERT OVERWRITE with partition management, scheduled workflow configuration, smoke testing, and production deployment on Alibaba MaxCompute

---

*This project was conducted as part of a logistics risk investigation at a major South Asian e-commerce platform. All table names, column names, schema references, company names, region names, and financial figures have been anonymised or generalised for public sharing. The analytical logic, methodology, rule design, and process framework are original work.*
