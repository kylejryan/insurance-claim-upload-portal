# ---- Builder: Chainguard Go 1.25
FROM cgr.dev/chainguard/go:latest AS builder
WORKDIR /src

# Prime modules
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download

# Copy source
COPY . .

# Build arg selects which cmd/* to build
ARG TARGET=presign
RUN --mount=type=cache,target=/go/pkg/mod \
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags="-s -w" -o /out/bootstrap ./cmd/${TARGET}

# ---- Runtime: AWS Lambda custom runtime (provided.al2)
FROM public.ecr.aws/lambda/provided:al2
# Lambda looks for /var/runtime/bootstrap
COPY --from=builder /out/bootstrap /var/runtime/bootstrap
