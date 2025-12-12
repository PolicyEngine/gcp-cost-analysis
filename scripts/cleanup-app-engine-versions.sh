#!/bin/bash
# Clean up old App Engine versions
# Run with: ./scripts/cleanup-app-engine-versions.sh

set -e

PROJECT="policyengine-api"
SERVICE="default"
KEEP_VERSIONS=5  # Number of recent versions to keep

echo "=== App Engine Version Cleanup ==="
echo "Project: $PROJECT"
echo "Service: $SERVICE"
echo "Keeping: $KEEP_VERSIONS most recent versions"
echo ""

# Get all stopped versions, sorted by creation time (oldest first)
echo "Stopped versions that could be deleted:"
echo ""

VERSIONS=$(gcloud app versions list \
  --project="$PROJECT" \
  --service="$SERVICE" \
  --filter="version.servingStatus=STOPPED" \
  --sort-by="~version.createTime" \
  --format="value(version.id)" 2>/dev/null)

# Count versions
TOTAL=$(echo "$VERSIONS" | wc -l | tr -d ' ')
TO_DELETE=$((TOTAL - KEEP_VERSIONS))

if [ "$TO_DELETE" -le 0 ]; then
  echo "Only $TOTAL stopped versions found. Nothing to delete."
  exit 0
fi

echo "Found $TOTAL stopped versions."
echo "Will delete $TO_DELETE versions (keeping $KEEP_VERSIONS most recent)."
echo ""

# Get versions to delete (all except the last N)
DELETE_VERSIONS=$(echo "$VERSIONS" | head -n "$TO_DELETE")

echo "Versions to delete:"
echo "$DELETE_VERSIONS"
echo ""

read -p "Proceed with deletion? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  for version in $DELETE_VERSIONS; do
    echo "Deleting $version..."
    gcloud app versions delete "$version" \
      --service="$SERVICE" \
      --project="$PROJECT" \
      --quiet 2>/dev/null || echo "  Failed to delete $version"
  done
  echo ""
  echo "Cleanup complete!"
else
  echo "Aborted."
fi
