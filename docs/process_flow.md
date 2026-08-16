# Cross-Functional Response and Enforcement Process Flow

**Author:** K M Kadir Koushik

---

## Overview

This document defines the end-to-end operational process for detecting, escalating, intercepting, and enforcing against logistics commission abuse. The process involves four functional teams with defined ownership at each stage.

---

## Stage 1: Detection (Risk Team)

**Owner:** Risk Analytics

**Trigger:** Daily monitoring dashboard flags a seller exceeding defined abuse signal thresholds across two or more consecutive weeks.

**Actions:**
- Risk analyst reviews the flagged seller against all eight behavioral signals
- Validates that the pattern is internally consistent and not attributable to campaign or seasonal effects
- Documents findings with supporting data output from the seller flagging query
- Escalates to Compliance team with confidence classification (High Confidence Fraud / Investigate)

**Output:** Seller risk report with signal scores, package metrics, and supporting trend data

---

## Stage 2: Initial Containment (Compliance and Finance)

**Owner:** Seller Compliance Team and Finance Team (joint action)

**Trigger:** Risk team escalation with High Confidence Fraud classification

**Compliance actions:**
- Flag the seller account in the platform system
- Impose a temporary daily order cap to limit further package inflation while investigation proceeds
- Issue a formal policy breach notification to the seller citing the split-packaging clause

**Finance actions:**
- Place a temporary hold on pending seller payouts to prevent financial leakage during the investigation window
- Quantify the estimated leakage amount for the seller based on abnormal package volume above the expected baseline

**Output:** Seller account flagged, payouts held, payout leakage estimate documented

---

## Stage 3: Package Interception (Operations)

**Owner:** Operations, 3PL Partnership Management

**Trigger:** Compliance team notification of active flagged seller

**Actions:**
- Operations team coordinates with the 3PL partner's hub-level management to intercept in-transit packages from flagged sellers before last-mile dispatch
- Prevents unnecessary commission payouts on packages already in the pipeline that belong to the flagged abuse pattern
- Documents intercepted package count and estimated commission saving

**Note:** Interception is only actionable for packages not yet dispatched for last-mile delivery. Packages already in last-mile delivery proceed normally. The interception window is therefore most effective when detection and escalation happen within the same processing cycle.

**Output:** Intercepted package count, commission leakage prevented

---

## Stage 4: Investigation and Evidence Collection (Risk Team)

**Owner:** Risk Analytics

**Actions:**
- Pull full historical transaction data for the flagged seller across the investigation window
- Run buyer-seller device connection analysis to identify any direct or indirect linkages between the seller and buyer accounts
- Document all linkage types found (shared device, email, phone, account) and the strength of each connection
- Prepare final investigation report summarizing evidence for enforcement decision

**Output:** Investigation report with evidence classification (confirmed fraud / unconfirmed / dismissed)

---

## Stage 5: Enforcement Decision and Consequence

**Owner:** Seller Compliance Team (decision), Risk Team (evidence), Legal (if required)

**For confirmed fraud cases:**

| Stakeholder | Consequence |
|---|---|
| Seller | Monetary penalty per split-packaged item, payout clawback for abuse window, account suspension or permanent deactivation for repeat offenders |
| Colluding riders or 3PL staff | Disciplinary action, contract termination, permanent blacklisting from platform logistics network |
| 3PL partner (if systemic) | Formal notification, SLA review, contractual penalty if partner-level enablement is confirmed |

**For unconfirmed cases:**
- Seller account unflagged after 30-day observation period with no recurrence
- Payout hold released
- Case documented for future reference if pattern re-emerges

---

## Monitoring Continuity

Following enforcement, the seller remains on the enhanced monitoring watchlist for 90 days. Any recurrence of the abuse pattern within this period triggers an accelerated enforcement process without the investigation stage.

The dashboard monitoring framework (defined in `assets/dashboard_metrics.md`) provides ongoing visibility for the Risk team to detect new sellers adopting the pattern.

---

## Escalation Matrix

| Scenario | Escalation Path |
|---|---|
| Single seller, first offence | Risk → Compliance → Finance |
| Multiple sellers, coordinated pattern | Risk → Head of Risk → Legal → Operations |
| 3PL partner-level involvement suspected | Risk → Head of Risk → 3PL Partnership Management → Legal |
| Internal team involvement suspected | Risk → Head of Risk → HR and Internal Audit |
