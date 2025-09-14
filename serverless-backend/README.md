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
