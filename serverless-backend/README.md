General repo structure to build

my-serverless-backend/
├─ cmd/
│  ├─ presign/      # Lambda 1: POST /claims/presign
│  │  └─ main.go
│  ├─ list/         # Lambda 2: GET /claims
│  │  └─ main.go
│  └─ indexer/      # Lambda 3: S3 ObjectCreated
│     └─ main.go
├─ internal/
│  ├─ authz/        # JWT verification (Cognito JWKs), user claims extraction
│  │  └─ authz.go
│  ├─ ddb/          # Dynamo repo (PutPending, UpsertComplete, ListByUser)
│  │  └─ repo.go
│  ├─ s3io/         # Presign PUT, Head/Get helpers, checksum helpers
│  │  └─ s3.go
│  ├─ validate/     # filename/.txt, content-type, tags, client info, limits
│  │  └─ validate.go
│  ├─ httpx/        # APIGW v2 helpers: JSON response, errors, request parsing
│  │  └─ httpx.go
│  ├─ observability/# logging, xray annotations, request id
│  │  └─ obs.go
│  ├─ config/       # env var load (DDB_TABLE, S3_BUCKET, KMS_KEY, REGION)
│  │  └─ config.go
│  └─ models/       # Claim, UserClaims, error types
│     └─ types.go
├─ Dockerfile       # Multi-stage; build all 3 handlers (separate images via args)
├─ go.mod / go.sum
└─ README.md

# 1) bring up LocalStack
docker compose up -d

# 2) create S3 bucket + DDB table
aws --endpoint-url=http://localhost:4566 s3 mb s3://local-claims-bucket

aws --endpoint-url=http://localhost:4566 dynamodb create-table \
  --table-name local-claims-table \
  --attribute-definitions AttributeName=PK,AttributeType=S AttributeName=SK,AttributeType=S \
  --key-schema AttributeName=PK,KeyType=HASH AttributeName=SK,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST
 
sam build 
sam local start-api --docker-network sam-local

# Save response to a file to grab variables
RESP=$(curl -s -X POST http://127.0.0.1:3000/claims/presign \
  -H 'Content-Type: application/json' \
  -H 'x-user-sub: 11111111-1111-1111-1111-111111111111' \
  -d '{"filename":"report.txt","tags":["car accident","urgent"],"client":"Acme Insurance","content_type":"text/plain"}')

CLAIM_ID=$(printf '%s' "$RESP" | jq -r .claim_id)
URL_CONTAINER=$(printf '%s' "$RESP" | jq -r .presigned_url)
URL_HOST=${URL_CONTAINER/localstack:4566/localhost:4566}

echo "hello claim portal" > /tmp/report.txt

# IMPORTANT: include the signed x-amz-meta-* headers
curl -v -X PUT "$URL_HOST" \
  -H 'Content-Type: text/plain' \
  -H "x-amz-meta-claim_id: $CLAIM_ID" \
  -H 'x-amz-meta-user_id: 11111111-1111-1111-1111-111111111111' \
  -H 'x-amz-meta-tags: car accident,urgent' \
  -H 'x-amz-meta-client: Acme Insurance' \
  --data-binary @/tmp/report.txt

cat > events/s3_put.json <<JSON
{
  "Records": [
    {
      "s3": {
        "bucket": { "name": "local-claims-bucket" },
        "object": { "key": "user/11111111-1111-1111-1111-111111111111/${CLAIM_ID}.txt" }
      }
    }
  ]
}
JSON

sam local invoke IndexerFunction --docker-network sam-local -e events/s3_put.json

curl -s http://127.0.0.1:3000/claims \
  -H 'x-user-sub: 11111111-1111-1111-1111-111111111111' | jq

