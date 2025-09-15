#!/usr/bin/env bash
set -euo pipefail

REGION="${REGION:-us-east-1}"
ACCT="${ACCT:-473700537115}"

# Repos already exist (from your TF state)
REPO_PRESIGN="$ACCT.dkr.ecr.$REGION.amazonaws.com/claims-dev-api-presign"
REPO_LIST="$ACCT.dkr.ecr.$REGION.amazonaws.com/claims-dev-api-list"
REPO_INDEXER="$ACCT.dkr.ecr.$REGION.amazonaws.com/claims-dev-indexer"

aws ecr get-login-password --region "$REGION" \
| docker login --username AWS --password-stdin "$ACCT.dkr.ecr.$REGION.amazonaws.com"

# Build
docker build -t presign:prod  --build-arg TARGET=presign .
docker build -t list:prod     --build-arg TARGET=list .
docker build -t indexer:prod  --build-arg TARGET=indexer .

# Tag + push
docker tag presign:prod  "$REPO_PRESIGN:prod"
docker tag list:prod     "$REPO_LIST:prod"
docker tag indexer:prod  "$REPO_INDEXER:prod"

docker push "$REPO_PRESIGN:prod"
docker push "$REPO_LIST:prod"
docker push "$REPO_INDEXER:prod"

# Capture immutable digests
PRESIGN_DIG=$(aws ecr describe-images --repository-name $(basename "$REPO_PRESIGN") --image-ids imageTag=prod --region "$REGION" --query 'imageDetails[0].imageDigest' --output text)
LIST_DIG=$(aws ecr describe-images --repository-name $(basename "$REPO_LIST")     --image-ids imageTag=prod --region "$REGION" --query 'imageDetails[0].imageDigest' --output text)
INDEXER_DIG=$(aws ecr describe-images --repository-name $(basename "$REPO_INDEXER") --image-ids imageTag=prod --region "$REGION" --query 'imageDetails[0].imageDigest' --output text)

mkdir -p env
cat > env/prod.auto.tfvars <<EOF
presign_image_digest = "${PRESIGN_DIG}"
list_image_digest    = "${LIST_DIG}"
indexer_image_digest = "${INDEXER_DIG}"
EOF

echo "Wrote env/prod.auto.tfvars with digests:"
cat env/prod.auto.tfvars
