# Monitoring Dashboard: Metric Definitions

**Author:** K M Kadir Koushik

---

## Overview

The logistics commission abuse monitoring dashboard provides continuous visibility for the Risk team to detect new or recurring abuse patterns. Built on FineBI (Alibaba's BI platform, comparable to Power BI), the dashboard refreshes on a weekly schedule powered by the ETL pipeline in `sql/07_etl_production_pipeline.sql`.

---

## Dashboard Structure

### Section 1: Platform Overview

**Daily Package Trend with 3PL Share**
A dual-axis line and bar chart showing total daily packages (bar) against 3PL partner package share as a percentage (line). Provides a quick read on whether 3PL dependency is growing disproportionately.

**3PL Partner Distribution Pie Chart**
Breakdown of packages by 3PL partner. Identifies concentration risk when a single partner captures a disproportionate share of total volume.

---

### Section 2: Seller-Level Monitoring Table

The core monitoring view. One row per seller per week. Sorted by abuse signal score descending so highest-risk sellers appear at the top.

| Metric | Definition | Abuse Signal |
|---|---|---|
| Packages per Order | Total packages / total orders for the seller in the period | High (above 2) indicates split packaging |
| Items per Package | Total items / total packages | Low (at or near 1) indicates no consolidation |
| Packages per Region | Average packages delivered per delivery region | High concentration in a single region is a risk signal |
| Packages per Courier | Total packages / distinct couriers used | Very high (above 100) indicates courier concentration |
| 3PL Package Share (%) | 3PL-delivered packages / total packages | High (above 50%) in 3PL-exclusive regions warrants review |
| Max Dimension per Package (cm) | Average maximum dimension across all packages | Very small (10 to 30 cm) for high-volume sellers is suspicious |
| Average Item Weight per Package (kg) | Average package weight | Consistently under 0.2 kg combined with high volume is a signal |
| Items per Package | Average items consolidated per package | Close to 1.0 across a high-volume seller is a strong signal |
| Intra-Region Delivery Share (%) | Packages delivered within the seller's own region / total | Very high (above 50%) combined with other signals indicates geographic clustering |
| Average Price per Product (USD) | Average paid price per item | Below the commission rate threshold confirms arbitrage condition |
| Abuse Signal Score | Sum of all binary signal flags (0 to 8) | 6 or above: High Confidence Fraud. 4 to 5: Investigate. Below 4: Normal |

---

### Section 3: Risk Engine Rule Coverage

Tracks the real-time rule's daily blocking activity:

| Metric | Definition |
|---|---|
| Orders Blocked | Count of orders blocked by the commission abuse rule per day |
| Buyers Affected | Distinct buyer accounts whose orders were blocked |
| Estimated Commission Saving | Packages blocked multiplied by commission rate per package |
| False Positive Rate | Blocks that were subsequently reversed after review |

---

## Threshold Calibration Notes

All thresholds in this framework are calibrated to the commission structure and product mix of the deployment market. When deploying to a new market or after a commission rate change, the following thresholds must be recalibrated:

- **Minimum price threshold:** Set to the per-package commission rate of the primary 3PL partner to maintain the arbitrage prevention logic
- **Packages per order threshold:** Benchmark against the genuine seller population median for comparable categories. Typically 1.2 to 1.5 for multi-item categories
- **Packages per courier threshold:** Benchmark against the platform median for the same delivery region and product mix
- **Weight and dimension thresholds:** Calibrate to the physical characteristics of the most commonly abused product categories in the target market
