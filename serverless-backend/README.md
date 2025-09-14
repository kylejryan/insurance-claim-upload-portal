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
