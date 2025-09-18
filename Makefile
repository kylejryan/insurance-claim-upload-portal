# =========================================
# Makefile (root)
# =========================================

SHELL := /bin/bash

# -------- Defaults (take-home) --------
PROJECT ?= claims
ENV     ?= dev                 # default env
REGION  ?= us-east-1
TAG     ?= dev                 # default image tag
PLATFORM ?= linux/amd64

# Sanitize (strip) to avoid hidden spaces/newlines
PROJECT_SAN := $(strip $(PROJECT))
ENV_SAN     := $(strip $(ENV))
REGION_SAN  := $(strip $(REGION))
TAG_SAN     := $(strip $(TAG))

# var-file location (stored under infra/)
TFVARS      ?= env/$(ENV_SAN).tfvars
TFVARS_PATH := infra/$(TFVARS)

# -------- Derived --------
ACCOUNT_ID ?= $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null)
REPO_BASE  := $(ACCOUNT_ID).dkr.ecr.$(REGION_SAN).amazonaws.com

REPO_PRESIGN_NAME := $(PROJECT_SAN)-$(ENV_SAN)-api-presign
REPO_LIST_NAME    := $(PROJECT_SAN)-$(ENV_SAN)-api-list
REPO_INDEXER_NAME := $(PROJECT_SAN)-$(ENV_SAN)-indexer

REPO_PRESIGN := $(REPO_BASE)/$(REPO_PRESIGN_NAME)
REPO_LIST    := $(REPO_BASE)/$(REPO_LIST_NAME)
REPO_INDEXER := $(REPO_BASE)/$(REPO_INDEXER_NAME)

# POSIX-safe confirm. Set NO_CONFIRM=1 to skip prompts.
ifdef NO_CONFIRM
confirm = @:
else
confirm = @printf "%s" "$(1) [y/N] " ; read ans ; case "$$ans" in y|Y) ;; *) echo "✋ aborted"; exit 1;; esac
endif

# ---------------- Help ------------------
.PHONY: help
help:
	@echo "Targets:"
	@echo "  deploy     -> tf-ecr -> build/push -> digests -> tf-plan -> tf-apply"
	@echo "  destroy    -> terraform destroy (uses $(TFVARS_PATH))"
	@echo "  outputs    -> terraform output"
	@echo "  build      -> docker build 3 images (TAG=$(TAG_SAN))"
	@echo "  push       -> docker push 3 images  (TAG=$(TAG_SAN))"
	@echo "  digests    -> write ECR digests to $(TFVARS_PATH)"
	@echo "  tf-init    -> terraform init"
	@echo "  tf-ecr     -> terraform apply only ECR repos"
	@echo "  tf-plan    -> terraform plan       (uses $(TFVARS_PATH))"
	@echo "  tf-apply   -> terraform apply      (uses $(TFVARS_PATH))"
	@echo "  clean      -> remove local image tags"
	@echo "  print-vars -> show resolved repo/image names"
	@echo ""
	@echo "Vars: ENV=$(ENV_SAN) REGION=$(REGION_SAN) TAG=$(TAG_SAN) PROJECT=$(PROJECT_SAN) PLATFORM=$(PLATFORM)"
	@echo "Tips: NO_CONFIRM=1 make deploy   # non-interactive"

# -------- Terraform (under infra/) -----
.PHONY: tf-init
tf-init:
	terraform -chdir=infra init

.PHONY: tf-ecr
tf-ecr: tf-init
	$(call confirm,Create/ensure ECR repos for $(ENV_SAN)); \
	terraform -chdir=infra apply \
	  -target=aws_ecr_repository.api_presign \
	  -target=aws_ecr_repository.api_list \
	  -target=aws_ecr_repository.indexer

.PHONY: tf-plan
tf-plan:
	terraform -chdir=infra plan -var-file=$(TFVARS)

.PHONY: tf-apply
tf-apply:
	$(call confirm,Apply full Terraform with $(TFVARS_PATH)); \
	terraform -chdir=infra apply -var-file=$(TFVARS)

.PHONY: outputs
outputs:
	terraform -chdir=infra output

.PHONY: destroy
destroy:
	$(call confirm,Destroy all Terraform resources for $(ENV_SAN)); \
	terraform -chdir=infra destroy -var-file=$(TFVARS)

# ------------- Docker / ECR ------------
.PHONY: login-ecr
login-ecr:
	@if [ -z "$(ACCOUNT_ID)" ]; then echo "ERROR: No AWS account id. Set AWS_PROFILE/REGION?"; exit 1; fi
	$(call confirm,Login to ECR $(REPO_BASE)); \
	aws ecr get-login-password --region $(REGION_SAN) | docker login --username AWS --password-stdin "$(REPO_BASE)"

.PHONY: build

# Force single-arch, non-index images for Lambda
# Lambda requires single-architecture images, not manifest lists
USE_BUILDX ?= 1

build:
	@echo "==> Building (TAG=$(TAG_SAN), PLATFORM=$(PLATFORM), USE_BUILDX=$(USE_BUILDX))"
ifneq ($(USE_BUILDX),0)
	# Use --provenance=false to avoid attestation manifests
	# Use --load to ensure single-arch image (not manifest list)
	docker buildx build --provenance=false --platform=$(PLATFORM) --load \
	  -f serverless-backend/Dockerfile -t "presign:$(TAG_SAN)"  --build-arg TARGET=presign  serverless-backend
	docker buildx build --provenance=false --platform=$(PLATFORM) --load \
	  -f serverless-backend/Dockerfile -t "list:$(TAG_SAN)"     --build-arg TARGET=list     serverless-backend
	docker buildx build --provenance=false --platform=$(PLATFORM) --load \
	  -f serverless-backend/Dockerfile -t "indexer:$(TAG_SAN)"  --build-arg TARGET=indexer  serverless-backend
else
	# Fallback to classic docker build
	DOCKER_DEFAULT_PLATFORM=$(PLATFORM) docker build \
	  -f serverless-backend/Dockerfile -t "presign:$(TAG_SAN)"  --build-arg TARGET=presign  serverless-backend
	DOCKER_DEFAULT_PLATFORM=$(PLATFORM) docker build \
	  -f serverless-backend/Dockerfile -t "list:$(TAG_SAN)"     --build-arg TARGET=list     serverless-backend
	DOCKER_DEFAULT_PLATFORM=$(PLATFORM) docker build \
	  -f serverless-backend/Dockerfile -t "indexer:$(TAG_SAN)"  --build-arg TARGET=indexer  serverless-backend
endif


.PHONY: tag
tag:
	@if [ -z "$(ACCOUNT_ID)" ]; then echo "ERROR: No AWS account id. Set AWS_PROFILE/REGION?"; exit 1; fi
	@echo "Tagging -> $(REPO_PRESIGN):$(TAG_SAN)"; \
	docker tag "presign:$(TAG_SAN)"  "$(REPO_PRESIGN):$(TAG_SAN)"
	@echo "Tagging -> $(REPO_LIST):$(TAG_SAN)"; \
	docker tag "list:$(TAG_SAN)"     "$(REPO_LIST):$(TAG_SAN)"
	@echo "Tagging -> $(REPO_INDEXER):$(TAG_SAN)"; \
	docker tag "indexer:$(TAG_SAN)"  "$(REPO_INDEXER):$(TAG_SAN)"

.PHONY: push
push: login-ecr tag
	$(call confirm,Push images with tag '$(TAG_SAN)' to ECR); \
	docker push "$(REPO_PRESIGN):$(TAG_SAN)" && \
	docker push "$(REPO_LIST):$(TAG_SAN)" && \
	docker push "$(REPO_INDEXER):$(TAG_SAN)"

.PHONY: digests
digests:
	@mkdir -p infra/env
	@echo "==> Writing digests to $(TFVARS_PATH)"
	@PRES=$$(aws ecr describe-images --repository-name "$(REPO_PRESIGN_NAME)" --image-ids imageTag=$(TAG_SAN) --region "$(REGION_SAN)" --query 'imageDetails[0].imageDigest' --output text); \
	LIST=$$(aws ecr describe-images --repository-name "$(REPO_LIST_NAME)"    --image-ids imageTag=$(TAG_SAN) --region "$(REGION_SAN)" --query 'imageDetails[0].imageDigest' --output text); \
	INDX=$$(aws ecr describe-images --repository-name "$(REPO_INDEXER_NAME)" --image-ids imageTag=$(TAG_SAN) --region "$(REGION_SAN)" --query 'imageDetails[0].imageDigest' --output text); \
	echo "presign_image_digest = \"$$PRES\"" >  "$(TFVARS_PATH)"; \
	echo "list_image_digest    = \"$$LIST\"" >> "$(TFVARS_PATH)"; \
	echo "indexer_image_digest = \"$$INDX\"" >> "$(TFVARS_PATH)"; \
	echo "region               = \"$(REGION_SAN)\"" >> "$(TFVARS_PATH)"; \
	echo "env                  = \"$(ENV_SAN)\""    >> "$(TFVARS_PATH)"; \
	echo "project              = \"$(PROJECT_SAN)\"" >> "$(TFVARS_PATH)"; \
	echo "WROTE $(TFVARS_PATH):"; cat "$(TFVARS_PATH)"

.PHONY: clean
clean:
	-@docker rmi "presign:$(TAG_SAN)" "list:$(TAG_SAN)" "indexer:$(TAG_SAN)" 2>/dev/null || true

# -------- One-shot deploy wrapper -------
.PHONY: deploy
deploy: tf-ecr build push digests tf-plan tf-apply fe-deploy
	@echo "✅ Backend + Frontend deployed for ENV=$(ENV_SAN), TAG=$(TAG_SAN)"


# -------- Debug helpers ----------------
.PHONY: print-vars
print-vars:
	@echo "ACCOUNT_ID         = $(ACCOUNT_ID)"
	@echo "REGION_SAN         = $(REGION_SAN)"
	@echo "REPO_BASE          = $(REPO_BASE)"
	@echo "REPO_PRESIGN_NAME  = $(REPO_PRESIGN_NAME)"
	@echo "REPO_LIST_NAME     = $(REPO_LIST_NAME)"
	@echo "REPO_INDEXER_NAME  = $(REPO_INDEXER_NAME)"
	@echo "REPO_PRESIGN       = $(REPO_PRESIGN)"
	@echo "REPO_LIST          = $(REPO_LIST)"
	@echo "REPO_INDEXER       = $(REPO_INDEXER)"
	@echo "TAG_SAN            = $(TAG_SAN)"
	@echo "TFVARS_PATH        = $(TFVARS_PATH)"

# ===========================
# Frontend (Amplify Hosting)
# ===========================
FRONTEND_DIR ?= frontend
FE_DIST      := $(FRONTEND_DIR)/dist
FE_ZIP       := /tmp/$(PROJECT_SAN)-$(ENV_SAN)-web.zip

# Generate a production env file for Vite builds from Terraform outputs
.PHONY: fe-env-prod
fe-env-prod:
	@echo "==> Writing frontend/.env.production from Terraform outputs"
	@set -euo pipefail; \
	OUT=$$(terraform -chdir=infra output -json); \
	API=$$(jq -r '.api_base_url.value // empty' <<<"$$OUT"); \
	if [ -z "$$API" ]; then \
	  API=$$(jq -r '.api_endpoints.value.list_claims // empty' <<<"$$OUT"); \
	  [ -n "$$API" ] && API=$${API%/claims}; \
	fi; \
	POOL=$$(jq -r '.cognito_pool_id.value' <<<"$$OUT"); \
	CLIENT=$$(jq -r '.cognito_client_id.value' <<<"$$OUT"); \
	DOMAIN=$$(jq -r '.cognito_domain.value // empty' <<<"$$OUT"); \
	WEB=$$(jq -r '.amplify_branch_url.value // empty' <<<"$$OUT"); \
	[ -z "$$WEB" -o "$$WEB" = "null" ] && { echo "ERROR: amplify_branch_url output missing."; exit 1; }; \
	REDIRECT=$${WEB%/}/callback; \
	REGION="$(REGION_SAN)"; \
	: "$${API:?API base not found in outputs}"; \
	echo "VITE_AWS_REGION=$$REGION"            >  "frontend/.env.production"; \
	echo "VITE_USER_POOL_ID=$$POOL"           >> "frontend/.env.production"; \
	echo "VITE_USER_POOL_CLIENT_ID=$$CLIENT"  >> "frontend/.env.production"; \
	[ -n "$$DOMAIN" ] && echo "VITE_COGNITO_DOMAIN=$$DOMAIN" >> "frontend/.env.production"; \
	echo "VITE_REDIRECT_URI=$$REDIRECT"       >> "frontend/.env.production"; \
	echo "VITE_API_BASE=$$API"                >> "frontend/.env.production"; \
	cat "frontend/.env.production"


# Build the SPA with Vite
.PHONY: fe-build
fe-build: fe-env-prod
	@echo "==> Building frontend"
	@cd "$(FRONTEND_DIR)" && npm ci && npm run build

# Zip the built assets for Amplify file-upload deployment
.PHONY: fe-zip
fe-zip: fe-build
	@echo "==> Zipping $(FE_DIST) -> $(FE_ZIP)"
	@rm -f "$(FE_ZIP)"; \
	cd "$(FE_DIST)" && zip -qr "$(FE_ZIP)" .

# Upload the ZIP via create-deployment → PUT presigned URL → start-deployment
.PHONY: fe-deploy
fe-deploy: fe-zip
	@set -euo pipefail; \
	OUT=$$(terraform -chdir=infra output -json); \
	APPID=$$(jq -r '.amplify_app_id.value' <<<"$$OUT"); \
	BRANCH=$$(jq -r '.amplify_branch_name.value // "prod"' <<<"$$OUT"); \
	WEB=$$(jq -r '.amplify_branch_url.value // empty' <<<"$$OUT"); \
	echo "==> Creating deployment (app=$$APPID branch=$$BRANCH)"; \
	DEP=$$(aws amplify create-deployment --app-id "$$APPID" --branch-name "$$BRANCH" --query '{jobId:jobId, url:zipUploadUrl}' --output json --region "$(REGION_SAN)"); \
	JOB=$$(jq -r .jobId <<<"$$DEP"); \
	URL=$$(jq -r .url   <<<"$$DEP"); \
	echo "==> Uploading ZIP to pre-signed URL"; \
	curl -sS -X PUT -T "/tmp/$(PROJECT_SAN)-$(ENV_SAN)-web.zip" "$$URL" > /dev/null; \
	echo "==> Starting deployment (jobId=$$JOB)"; \
	aws amplify start-deployment --app-id "$$APPID" --branch-name "$$BRANCH" --job-id "$$JOB" --region "$(REGION_SAN)" > /dev/null; \
	echo ""; echo "🌐  Amplify URL: $$WEB"; echo ""

.PHONY: fe-open
fe-open:
	@URL=$$(terraform -chdir=infra output -raw amplify_branch_url); \
	if command -v open >/dev/null 2>&1; then open "$$URL"; \
	elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$$URL"; \
	else echo "$$URL"; fi
