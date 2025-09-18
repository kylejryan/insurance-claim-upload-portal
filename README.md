# Insurance Claim Upload Portal

A serverless, full‑stack demo that lets authenticated staff upload **.txt** claim files, tag them, and view their own uploads in a simple dashboard.

## High‑Level Architecture

* **Auth:** Amazon Cognito (user sign‑up/sign‑in) with a hosted UI.
* **Frontend:** React app hosted by AWS Amplify.
* **API:** Amazon API Gateway (REST) → AWS Lambda.
* **Lambdas:**

  * `presign` – POST `/claims/presign` returns a presigned S3 **PUT** URL and writes a pending item.
  * `list` – GET `/claims` lists uploads for the current user.
  * `indexer` – S3 **ObjectCreated** trigger; enriches the DynamoDB record from object metadata.
* **Storage:**

  * S3 bucket for raw files (KMS encryption, private).
  * DynamoDB table for metadata (PK/SK), pay‑per‑request.
* **Networking/Security:** All Lambdas run in a VPC; API is protected by a Cognito Authorizer and an AWS WAF WebACL.

> See `/docs/diagram.png` for the reference diagram.

## Project Structure

```
.
├─ cmd/
│  ├─ presign/       # Lambda handler for POST /claims/presign
│  ├─ list/          # Lambda handler for GET /claims
│  └─ indexer/       # Lambda handler for S3 event processing
├─ internal/
│  ├─ authz/         # JWT verification (Cognito JWKs), claims extraction
│  ├─ ddb/           # Dynamo access: PutPending, UpsertComplete, ListByUser
│  ├─ s3io/          # Presign PUT helpers, checksum & HEAD/GET utilities
│  ├─ validate/      # filename/content-type/tags/client validations
│  ├─ httpx/         # API Gateway v2 helpers (JSON/error responses)
│  ├─ config/        # env var loading (DDB_TABLE, S3_BUCKET, REGION, KMS_KEY)
│  ├─ observability/ # logging, xray annotations, request id
│  └─ models/        # Claim, UserClaims, error types
├─ terraform/        # Cognito, API Gateway, Lambdas, S3, DynamoDB, WAF, IAM
├─ frontend/         # React app (Amplify hosting)
├─ data/             # Sample .txt claim files for demos
├─ docs/             # System architecture diagram
├─ Makefile          # deploy/destroy/outputs helpers
└─ README.md
```

## Prerequisites

* macOS/Linux with **Homebrew** (or equivalents)
* **Terraform** and **AWS CLI** installed
* An **AWS account** with credentials configured (user or service account) and permissions to create Cognito, API Gateway, Lambda, S3, DynamoDB, WAF, and IAM resources

Quick install (macOS):

```bash
brew install terraform awscli
aws configure  
```

## Deploy (one command)

From the repo root:

```bash
make deploy
```

Follow the prompts to allow Terraform and any required approvals. When provisioning completes, the command prints an **Amplify URL**. Open it to access the app.

> **Outputs** are also written to `terraform output` (e.g., API URL, Cognito domain, Amplify app URL).

## Run the App

1. Visit the Amplify URL.
2. **Create an account** and confirm via email (Cognito hosted UI).
3. Sign in and go to the **Upload** screen.
4. Choose any sample file from `/data`, add tags and client name, then upload.
5. Open the **Dashboard** to see your uploads (filename, tags, upload time, client).

## Configuration

The backend reads these environment variables (in Terraform they’re set per function):

* `REGION`, `S3_BUCKET`, `DDB_TABLE`, `KMS_KEY_ARN`

Frontend config (Amplify) is injected via environment variables and the Terraform outputs for API base URL, Cognito domain, and user pool/client IDs.

## API (high‑level)

* `POST /claims/presign` → `{ claim_id, presigned_url, headers }`
* `GET /claims` → `[{ id, filename, tags, client, uploaded_at }]`

The upload **must** include the returned `x-amz-meta-*` headers so the `index` lambda can finalize the record.

## Design Decisions & Trade‑offs

* **Presigned PUT** keeps files off the API path and minimizes Lambda execution time/cost.
* **Event‑driven indexing** (S3 → Lambda) avoids race conditions and ensures DynamoDB reflects the actual object that landed in S3.
* **User isolation** is enforced by scoping keys by user sub (`s3://bucket/user/{sub}/{claimId}.txt`) and by querying on the same partition key in DynamoDB.
* **Least‑privilege IAM** per function (write‑only to S3 for presign; query‑only to DynamoDB for list; read S3 + write DDB for indexer).

## Cleaning Up

```bash
make destroy
```

This removes the Terraform stack and Amplify app to avoid ongoing charges.
