SHELL := /bin/bash

# -------- Defaults (take-home) --------
PROJECT ?= claims
ENV     ?= dev                 # <-- default env
REGION  ?= us-east-1
TAG     ?= dev                 # <-- default image tag
TFVARS  ?= env/$(ENV).tfvars
PLATFORM ?= linux/amd64

# -------- Derived --------
ACCOUNT_ID ?= $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null)
REPO_BASE  := $(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com

REPO_PRESIGN_NAME := $(PROJECT)-$(ENV)-api-presign
REPO_LIST_NAME    := $(PROJECT)-$(ENV)-api-list
REPO_INDEXER_NAME := $(PROJECT)-$(ENV)-indexer

REPO_PRESIGN := $(REPO_BASE)/$(REPO_PRESIGN_NAME)
REPO_LIST    := $(REPO_BASE)/$(REPO_LIST_NAME)
REPO_INDEXER := $(REPO_BASE)/$(REPO_INDEXER_NAME)

define confirm
	@read -p "$(1) [y/N] " ans; [[ $$ans == "y" || $$ans == "Y" ]]
endef

.PHONY: help
help:
	@echo "Targets:"
	@echo "  deploy   -> tf-ecr -> build/push -> digests -> tf-apply   (ENV=$(ENV), TAG=$(TAG))"
	@echo "  destroy  -> terraform destroy                         (ENV=$(ENV))"
	@echo "  build    -> docker build 3 images                     (TAG=$(TAG))"
	@echo "  push     -> docker push 3 images                      (TAG=$(TAG))"
	@echo "  digests  -> write ECR digests to $(TFVARS)"
	@echo "  tf-init  -> terraform init"
	@echo "  tf-ecr   -> terraform apply only ECR repos"
	@echo "  tf-plan  -> terraform plan                            (uses $(TFVARS))"
	@echo "  tf-apply -> terraform apply                           (uses $(TFVARS))"
	@echo "  clean    -> remove local image tags"

# ---------- Terraform ----------
.PHONY: tf-init
tf-init:
	terraform init

.PHONY: tf-ecr
tf-ecr: tf-init
	$(call confirm,"Create/ensure ECR repos for $(ENV)?") && \
	terraform apply \
	  -target=aws_ecr_repository.api_presign \
	  -target=aws_ecr_repository.api_list \
	  -target=aws_ecr_repository.indexer

.PHONY: tf-plan
tf-plan:
	terraform plan -var-file=$(TFVARS)

.PHONY: tf-apply
tf-apply:
	$(call confirm,"Apply full Terraform with $(TFVARS)?") && \
	terraform apply -var-file=$(TFVARS)

.PHONY: destroy
destroy:
	$(call confirm,"Destroy all Terraform resources for $(ENV)?") && \
	terraform destroy -var-file=$(TFVARS)

# ---------- Docker / ECR ----------
.PHONY: login-ecr
login-ecr:
	@if [ -z "$(ACCOUNT_ID)" ]; then echo "ERROR: No AWS account id. Set AWS_PROFILE/REGION?"; exit 1; fi
	$(call confirm,"Login to ECR $(REPO_BASE)?") && \
	aws ecr get-login-password --region $(REGION) | \
	docker login --username AWS --password-stdin $(REPO_BASE)

.PHONY: build
build:
	@echo "==> Building (TAG=$(TAG), PLATFORM=$(PLATFORM))"
	docker build --platform=$(PLATFORM) -t presign:$(TAG)  --build-arg TARGET=presign .
	docker build --platform=$(PLATFORM) -t list:$(TAG)     --build-arg TARGET=list .
	docker build --platform=$(PLATFORM) -t indexer:$(TAG)  --build-arg TARGET=indexer .

.PHONY: tag
tag:
	docker tag presign:$(TAG)  $(REPO_PRESIGN):$(TAG)
	docker tag list:$(TAG)     $(REPO_LIST):$(TAG)
	docker tag indexer:$(TAG)  $(REPO_INDEXER):$(TAG)

.PHONY: push
push: login-ecr tag
	$(call confirm,"Push images with tag '$(TAG)' to ECR?") && \
	docker push $(REPO_PRESIGN):$(TAG) && \
	docker push $(REPO_LIST):$(TAG) && \
	docker push $(REPO_INDEXER):$(TAG)

.PHONY: digests
digests:
	@mkdir -p env
	@echo "==> Writing digests to $(TFVARS)"
	@PRES=$$(aws ecr describe-images --repository-name $(REPO_PRESIGN_NAME) --image-ids imageTag=$(TAG) --region $(REGION) --query 'imageDetails[0].imageDigest' --output text); \
	LIST=$$(aws ecr describe-images --repository-name $(REPO_LIST_NAME)    --image-ids imageTag=$(TAG) --region $(REGION) --query 'imageDetails[0].imageDigest' --output text); \
	INDX=$$(aws ecr describe-images --repository-name $(REPO_INDEXER_NAME) --image-ids imageTag=$(TAG) --region $(REGION) --query 'imageDetails[0].imageDigest' --output text); \
	echo "presign_image_digest = \"$$PRES\"" >  $(TFVARS); \
	echo "list_image_digest    = \"$$LIST\"" >> $(TFVARS); \
	echo "indexer_image_digest = \"$$INDX\"" >> $(TFVARS); \
	echo "region               = \"$(REGION)\"" >> $(TFVARS); \
	echo "env                  = \"$(ENV)\""    >> $(TFVARS); \
	echo "project              = \"$(PROJECT)\"" >> $(TFVARS); \
	echo "WROTE $(TFVARS):"; cat $(TFVARS)

.PHONY: clean
clean:
	-@docker rmi presign:$(TAG) list:$(TAG) indexer:$(TAG) 2>/dev/null || true

# ---------- One-shot deploy ----------
.PHONY: deploy
deploy: tf-ecr build push digests tf-plan tf-apply
	@echo "✅ Deploy complete for ENV=$(ENV), TAG=$(TAG)"
