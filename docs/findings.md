# Findings: Logistics Commission Abuse Detection

**Author:** K M Kadir Koushik

---

## Finding 1: Volume Anomaly is Sudden and Geographically Concentrated

The regional package volume trend revealed a sudden and dramatic surge confined to a single delivery region and a single 3PL partner. The surge began in a specific month and sustained at four to five times the historical baseline for multiple consecutive months.

This pattern is structurally inconsistent with genuine demand growth, which typically shows gradual acceleration across multiple regions and correlates with campaign activity or seasonal effects. The concentration in one region with no corresponding growth elsewhere confirmed coordination rather than organic expansion.

---

## Finding 2: Split Packaging is the Core Mechanism

Of the abnormal package volume identified in the abuse window, the overwhelming majority traced back to a specific seller behavior: issuing individual airway bills for each item in an order rather than consolidating items into a single shipment.

A genuine seller processing a multi-item order consolidates items to reduce handling complexity and cost. The abusive sellers were doing the opposite, creating the maximum number of packages from the minimum number of orders. This behavior has no rational explanation for a legitimate seller since it increases their operational effort without increasing their revenue.

Packages per order in the abusive population were significantly higher than the platform average for comparable product categories, and items per package were at or near one across the flagged seller population.

---

## Finding 3: Low-Value Items Dominate the Abuse Population

Price bucket analysis confirmed that the vast majority of abusive packages contained items in the lowest price categories. The distribution was sharply skewed toward item values that were a small fraction of the per-package commission rate.

This is the economic engine of the scheme. At these item price levels, the colluding actor recovers the item cost from commission alone and retains net positive income from each artificially inflated package. The lower the item value relative to the commission rate, the wider the arbitrage and the stronger the financial incentive.

---

## Finding 4: Coordinated Repeat Ordering Confirmed by Retention Analysis

Device-level month-over-month retention for the high-risk region cohort was significantly above the platform-wide baseline for the same period. The same devices returned in consecutive months placing near-identical orders for the same low-value items at maximum allowed quantities.

Genuine consumer demand does not produce this pattern. Consumers do not repeatedly purchase maximum quantities of the same stationery items month after month. The retention pattern confirmed that the ordering was financially motivated and coordinated, not driven by genuine demand.

---

## Finding 5: Economic Arbitrage Confirmed by Commission Analysis

Comparison of average item value per package against the verified commission rate per package confirmed that a significant proportion of abusive packages fell in the arbitrage zone where commission exceeded item value.

At the extreme end of the distribution, some packages had arbitrage ratios significantly above one, meaning the commission payout alone covered the item purchase cost multiple times over. This quantified the financial logic of the scheme and established why it was sustainable over multiple months.

---

## Finding 6: Geographic Concentration Suggests Coordinated Logistics

More than 80% of suspicious orders showed geographic overlap between the seller warehouse address and the buyer delivery address. While direct buyer-seller login matches were not detected, suggesting the actors had adapted to avoid known collusion detection algorithms, the geographic clustering strongly indicated that buyers and sellers were either the same entity or operated in close physical proximity.

---

## Finding 7: Scale of Financial Leakage

The total financial leakage was quantified across the abuse window and expressed as a share of the platform's profitability metric. The leakage represented a material portion of the PM2 shortfall during the period and directly inflated the cost per delivery above the platform's operational target.

The scheme was self-perpetuating: each month of unchecked activity compounded the leakage as more sellers adopted the pattern or scaled their existing abuse behavior.

---

## Key Takeaway

The commission structure created a clear arbitrage condition where the fixed per-package payout exceeded the item value for a specific range of low-cost products. Combined with loose controls on split packaging and a 3PL-exclusive delivery region where platform logistics did not operate, this created an environment where the scheme could scale significantly before detection.

The framework developed in this project addresses all three enablers: the policy gap (seller compliance amendment), the economic incentive (minimum price threshold), and the real-time enforcement gap (risk engine rule with shadow-validated accuracy).
