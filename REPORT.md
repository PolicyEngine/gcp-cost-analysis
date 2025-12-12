# PolicyEngine GCP Cost Analysis Report

**Date:** December 12, 2025
**Analyzed Projects:** policyengine-api, policyengine-apps, and related projects

---

## Executive Summary

Estimated monthly GCP spend: **~$450-550/month** (~$5,400-6,600/year)

| Category | Monthly Cost | % of Total |
|----------|-------------|------------|
| App Engine Flexible | $250-300 | 55% |
| Cloud SQL | $180-220 | 40% |
| Artifact Storage | $15-20 | 4% |
| Cloud Run | ~$5-10 | 1% |

**Top Optimization Opportunities:**
1. Add lifecycle policies to delete old container images → Save ~$10-15/month on storage
2. Clean up 63 unused App Engine versions → Reduce storage and complexity
3. Review Cloud SQL HA requirement → Could save ~$90/month if HA not needed
4. Review App Engine sizing → May be over-provisioned

---

## Detailed Infrastructure Analysis

### 1. Cloud SQL (policyengine-api)

**Instance:** `policyengine-api-data`

| Setting | Value |
|---------|-------|
| Type | MySQL 8.0 |
| Machine | db-custom-2-13312 (2 vCPU, 13GB RAM) |
| Storage | 118 GB SSD (auto-resize enabled) |
| Availability | **REGIONAL** (High Availability) |
| Region | us-central1 |
| Backups | 7 retained, binary logging enabled |
| Created | December 6, 2022 |

**Cost Breakdown:**
- Base instance: ~$100-120/month
- Regional HA: ~$80-100/month (doubles cost)
- Storage (118GB SSD): ~$20/month
- **Total: ~$180-220/month**

**Recommendations:**
- [ ] Evaluate if Regional HA is necessary. Switching to ZONAL could save ~$90/month
- [ ] Review if 13GB RAM is needed - could potentially downsize
- [ ] Storage is auto-resizing with no limit - consider setting a cap

---

### 2. App Engine Flexible (policyengine-api)

**Services:** 2 (default, policyengine-compute-api)

#### Default Service (Active)
| Setting | Value |
|---------|-------|
| Runtime | Custom (Ubuntu 22) |
| CPU | 4 vCPU |
| Memory | 24 GB |
| Disk | 32 GB |
| Instances | 1 (min=1, max=1) |
| Scaling | Automatic (80% CPU target) |

**Current Version:** `20251211t120139` (deployed Dec 11, 2025)

**Cost Breakdown:**
- 4 vCPU × $0.0526/hour × 730 hours = ~$154/month
- 24 GB RAM × $0.0071/hour × 730 hours = ~$124/month
- Disk and network: ~$10-20/month
- **Total: ~$250-300/month**

#### policyengine-compute-api Service (Inactive)
- 10 versions, all STOPPED
- Last deployed: April 2023
- No current cost, but still has 100% traffic allocation (misconfiguration)

**Recommendations:**
- [ ] Review if 4 vCPU / 24GB RAM is necessary - may be over-provisioned
- [ ] Clean up compute-api service if no longer needed
- [ ] Delete 63 old stopped versions (currently 64 total, only 1 serving)

---

### 3. Artifact Storage

#### policyengine-api Project

| Repository | Size | Location |
|------------|------|----------|
| us.gcr.io (Container Registry) | **553 GB** | us |
| gae-flexible | 22.8 GB | us-central1 |
| gcr.io | 4.3 GB | us |
| cloud-run-source-deploy | 0.2 GB | us-central1 |
| **Total** | **~580 GB** | |

**Key Finding:** The `us.artifacts.policyengine-api.appspot.com` bucket contains **6,512 container images** dating back to January 2023 with **NO lifecycle policy**.

Storage cost: ~580 GB × $0.026/GB = **~$15/month**

#### policyengine-apps Project

| Repository | Size | Location |
|------------|------|----------|
| cloud-run-source-deploy | 15.8 GB | europe-west1 |
| cloud-run-source-deploy | 15.7 GB | us-central1 |
| cloud-run-source-deploy | 7.3 GB | europe-west2 |
| gcr.io | 2.1 GB | us |
| **Total** | **~41 GB** | |

Storage cost: ~41 GB × $0.10/GB = **~$4/month**

**Recommendations:**
- [ ] Add lifecycle policy to delete container images older than 90 days
- [ ] Clean up unused image tags regularly

---

### 4. Cloud Run (policyengine-apps)

**10 Active Services:**

| Service | Region | Last Deployed | Resources |
|---------|--------|---------------|-----------|
| givecalc | europe-west1 | Dec 11, 2025 | 1 vCPU, 4GB |
| policyengine-github-bot | europe-west2 | Dec 10, 2025 | Standard |
| uk-autumn-budget-dashboard | europe-west1 | Dec 10, 2025 | Standard |
| ctc-calculator | us-central1 | Dec 1, 2025 | Standard |
| uk-autumn-budget-lifecycle | europe-west1 | Nov 30, 2025 | Standard |
| us-10-year-scores | us-central1 | May 13, 2025 | Standard |
| salt-amt-calculator | us-central1 | May 2, 2025 | Standard |
| obr-forecast-household-calculator | us-central1 | Apr 22, 2025 | Standard |
| uk-local-areas-dashboard | us-central1 | Oct 2, 2025 | Standard |
| uk-vatlab-api | europe-west2 | Sep 9, 2025 | Standard |

**Cost:** Cloud Run is pay-per-use. With default scaling to 0, costs are minimal when idle.
- Estimated: **~$5-10/month** (depends on traffic)

**Recommendations:**
- [ ] Review services not deployed in 6+ months for potential decommissioning
- [ ] Ensure all services scale to 0 when not in use

---

### 5. Other Storage Buckets (policyengine-api)

| Bucket | Size | Purpose |
|--------|------|---------|
| policyengine-api_cloudbuild | 222 MB | Build artifacts |
| staging.policyengine-api.appspot.com | 3 MB | App Engine staging |
| crfb-ss-analysis-results | 1.2 MB | Analysis outputs |
| non-public-microdata | 0 B | Empty |
| policyengine-api.appspot.com | 0 B | Empty |
| policyengine-app-social-cards | 0 B | Empty |

**Cost:** Negligible (<$1/month)

---

## Cost Optimization Roadmap

### Quick Wins (Immediate)

1. **Add lifecycle policy to artifact storage**
   ```bash
   # Create lifecycle.json
   cat > /tmp/lifecycle.json << 'EOF'
   {
     "lifecycle": {
       "rule": [
         {
           "action": {"type": "Delete"},
           "condition": {"age": 90}
         }
       ]
     }
   }
   EOF

   # Apply to buckets
   gsutil lifecycle set /tmp/lifecycle.json gs://us.artifacts.policyengine-api.appspot.com/
   ```
   **Savings:** ~$10-15/month after old images are cleaned

2. **Delete old App Engine versions**
   ```bash
   # List all stopped versions
   gcloud app versions list --project=policyengine-api --filter="version.servingStatus=STOPPED"

   # Delete versions older than 6 months (review first!)
   gcloud app versions delete VERSION_ID --service=default --project=policyengine-api
   ```

### Medium-Term Optimizations

3. **Review Cloud SQL HA requirement**
   - If downtime during failover is acceptable, switch from REGIONAL to ZONAL
   - **Potential Savings:** ~$90/month (50% of SQL cost)

4. **Right-size App Engine**
   - Monitor CPU/memory utilization
   - Consider reducing from 4 vCPU/24GB if under-utilized
   - **Potential Savings:** $50-100/month

### Long-Term Improvements

5. **Enable BigQuery Billing Export**
   - Get detailed cost breakdown by service
   - Set up alerts for cost anomalies
   - See [setup instructions](#bigquery-billing-export-setup)

6. **Consider Cloud Run Migration**
   - App Engine Flexible → Cloud Run could reduce costs
   - Only pay for actual usage vs always-on instance

---

## BigQuery Billing Export Setup

The export must be configured via Cloud Console (not CLI):

1. **Create Dataset:**
   ```bash
   bq mk --dataset policyengine-api:billing_export
   ```

2. **Configure Export:**
   - Go to [Billing → Billing export](https://console.cloud.google.com/billing/export)
   - Select "BigQuery export" tab
   - Choose the `billing_export` dataset
   - Enable "Detailed usage cost"

3. **Query Costs:**
   ```sql
   SELECT
     service.description,
     SUM(cost) as total_cost,
     SUM(usage.amount) as usage
   FROM `policyengine-api.billing_export.gcp_billing_export_v1_*`
   WHERE invoice.month = '202512'
   GROUP BY service.description
   ORDER BY total_cost DESC
   ```

---

## Project Inventory

| Project | Purpose | Active Resources |
|---------|---------|------------------|
| policyengine-api | Main API | App Engine, Cloud SQL |
| policyengine-apps | Calculators/Dashboards | 10 Cloud Run services |
| policyengine-app | Legacy app | None identified |
| policyengine-app-v2 | App v2 | None identified |
| hivesight-app | HiveSight | Unknown |
| beta-api-v2-1b3f | Beta API v2 | None identified |
| prod-api-v2-c4d5 | Prod API v2 | None identified |

**Note:** 32 projects total were found. Many appear to be system-generated or inactive.

---

## Next Steps

1. [ ] Review and apply lifecycle policy to artifact storage
2. [ ] Delete old App Engine versions after review
3. [ ] Set up BigQuery billing export for ongoing monitoring
4. [ ] Evaluate Cloud SQL HA necessity with team
5. [ ] Monitor App Engine resource utilization for right-sizing
6. [ ] Audit inactive projects for potential deletion

---

*Report generated using gcloud CLI analysis. Costs are estimates based on GCP pricing as of December 2025.*
