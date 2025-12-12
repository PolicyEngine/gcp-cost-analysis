#!/bin/bash
# Quick cost analysis script - run periodically to check infrastructure
# Run with: ./scripts/analyze-costs.sh

set -e

echo "=== PolicyEngine GCP Cost Analysis ==="
echo "Date: $(date)"
echo ""

# Cloud SQL
echo "=== Cloud SQL ==="
gcloud sql instances list --project=policyengine-api 2>/dev/null || echo "No access"
echo ""

# App Engine
echo "=== App Engine Services ==="
gcloud app services list --project=policyengine-api 2>/dev/null || echo "No access"
echo ""

echo "=== App Engine Versions (Serving) ==="
gcloud app versions list --project=policyengine-api --filter="version.servingStatus=SERVING" 2>/dev/null || echo "No access"
echo ""

# Storage
echo "=== Artifact Registry ==="
gcloud artifacts repositories list --project=policyengine-api --format="table(REPOSITORY,SIZE)" 2>/dev/null || echo "No access"
echo ""

echo "=== Storage Buckets ==="
for bucket in gs://us.artifacts.policyengine-api.appspot.com gs://policyengine-api_cloudbuild; do
  echo -n "$bucket: "
  gsutil du -sh "$bucket" 2>/dev/null | awk '{print $1, $2}' || echo "No access"
done
echo ""

# Cloud Run
echo "=== Cloud Run Services (policyengine-apps) ==="
gcloud run services list --project=policyengine-apps --format="table(SERVICE,REGION,LAST_DEPLOYED_AT)" 2>/dev/null || echo "No access"
echo ""

# Summary
echo "=== Quick Estimates ==="
echo "Cloud SQL (db-custom-2-13312, Regional): ~\$180-220/month"
echo "App Engine (4 vCPU, 24GB RAM): ~\$250-300/month"
echo "Artifact Storage (~620GB): ~\$19/month"
echo "Cloud Run: ~\$5-10/month (usage-based)"
echo "---"
echo "Total estimated: ~\$450-550/month"
