#!/bin/bash
# Add lifecycle policy to delete container images older than 90 days
# Run with: ./scripts/add-lifecycle-policy.sh

set -e

LIFECYCLE_FILE="/tmp/gcp-lifecycle-policy.json"

# Create lifecycle policy
cat > "$LIFECYCLE_FILE" << 'EOF'
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

echo "Lifecycle policy created at $LIFECYCLE_FILE"
echo ""
echo "Contents:"
cat "$LIFECYCLE_FILE"
echo ""

# List buckets that need the policy
BUCKETS=(
  "gs://us.artifacts.policyengine-api.appspot.com/"
)

for bucket in "${BUCKETS[@]}"; do
  echo ""
  echo "=== $bucket ==="
  echo "Current lifecycle policy:"
  gsutil lifecycle get "$bucket" 2>/dev/null || echo "  (none)"
  echo ""
  read -p "Apply new lifecycle policy to $bucket? (y/N) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    gsutil lifecycle set "$LIFECYCLE_FILE" "$bucket"
    echo "  Done!"
  else
    echo "  Skipped"
  fi
done

echo ""
echo "Cleanup complete. Old images will be deleted automatically over the next few days."
