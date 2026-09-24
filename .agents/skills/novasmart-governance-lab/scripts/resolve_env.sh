#!/bin/bash
# ==============================================================================
# resolve_env.sh — Fast, Authoritative Session Environment Resolver (Option A)
# Caches environment variables to /tmp/novasmart_env.sh for sub-millisecond execution.
# Direct live Vertex AI queries — zero GCS seed bucket reliance for agent IDs/principals.
# ==============================================================================
CACHE_FILE="/tmp/novasmart_env.sh"

# 1. Fast Cache Hit Check: If cached and not forced to refresh, source immediately
if [ "$1" != "--refresh" ] && [ "$1" != "-f" ] && [ -s "$CACHE_FILE" ]; then
  # Optional: expire after 1 hour (3600 seconds)
  CACHE_AGE=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0) ))
  if [ $CACHE_AGE -lt 3600 ]; then
    source "$CACHE_FILE"
    return 0 2>/dev/null || exit 0
  fi
fi

# 2. Fast Local Metadata Discovery (< 5ms each on GCE, zero auth needed)
PROJECT=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/project/project-id 2>/dev/null)
[ -z "$PROJECT" ] && PROJECT=$(gcloud config get-value project 2>/dev/null)

PROJECT_NUMBER=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/project/numeric-project-id 2>/dev/null)
[ -z "$PROJECT_NUMBER" ] && PROJECT_NUMBER=$(gcloud projects describe "$PROJECT" --format='value(projectNumber)' 2>/dev/null)

# 2b. Discover region from NovaSmart Cloud Run services (zero location flag needed)
REGION=$(gcloud run services list --project="$PROJECT" --format="value(region)" --filter="metadata.name:novasmart OR metadata.name:promo" 2>/dev/null | head -n 1)
[ -z "$REGION" ] && REGION=$(gcloud config get-value compute/region 2>/dev/null)

# 3. Direct Vertex AI REST Query (1 live call)
TOKEN=$(gcloud auth print-access-token 2>/dev/null)
RE_JSON=""
if [ -n "$TOKEN" ] && [ -n "$PROJECT" ] && [ -n "$REGION" ]; then
  RE_JSON=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "https://${REGION}-aiplatform.googleapis.com/v1beta1/projects/${PROJECT}/locations/${REGION}/reasoningEngines")
fi

# 4. Direct In-Memory Extraction via Python (Engine IDs + SPIFFE Principals)
PARSED_ENV=$(echo "$RE_JSON" | python3 -c '
import sys, json

try:
    data = json.load(sys.stdin)
except Exception:
    data = {}

engines = data.get("reasoningEngines", [])

def get_engine(keyword):
    for e in engines:
        if keyword in e.get("displayName", "").lower():
            eid = e.get("name", "").split("/")[-1]
            eff = e.get("spec", {}).get("effectiveIdentity", "")
            princ = f"principal://{eff}" if eff and not eff.startswith("principal://") else eff
            return eid, princ
    return "", ""

msa_id, msa_princ = get_engine("markdown")
pma_id, pma_princ = get_engine("price match")
cpa_id, cpa_princ = get_engine("personalization")
if not cpa_id:
    cpa_id, cpa_princ = get_engine("customer")

print(f"export MSA_ID=\"{msa_id}\"")
print(f"export MSA_PRINCIPAL=\"{msa_princ}\"")
print(f"export PMA_ID=\"{pma_id}\"")
print(f"export PMA_PRINCIPAL=\"{pma_princ}\"")
print(f"export CPA_ID=\"{cpa_id}\"")
print(f"export CPA_PRINCIPAL=\"{cpa_princ}\"")
')

# 5. Write to Cache File
cat <<EOF > "$CACHE_FILE"
export PROJECT="${PROJECT}"
export PROJECT_ID="${PROJECT}"
export PROJECT_NUMBER="${PROJECT_NUMBER}"
export REGION="${REGION}"
$PARSED_ENV
export SEED_BUCKET="gs://novasmart-seed-bucket-${PROJECT}"
EOF

# 6. Source into Current Shell
source "$CACHE_FILE"
