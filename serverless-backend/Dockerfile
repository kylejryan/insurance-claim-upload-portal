# ---------- Builder ----------
FROM golang:1.25-alpine AS builder
WORKDIR /src
RUN apk add --no-cache git ca-certificates
COPY go.mod go.sum ./
RUN go mod download
COPY . .
ARG TARGET=presign
# build the program at ./cmd/${TARGET} (must be package main)
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags="-s -w" -o /out/bootstrap ./cmd/${TARGET}

# ---------- Runtime (Lambda custom runtime) ----------
FROM public.ecr.aws/lambda/provided:al2
# RIE path for SAM Local
RUN mkdir -p /var/rapid && \
    if [ -f /usr/local/bin/aws-lambda-rie ]; then \
      cp /usr/local/bin/aws-lambda-rie /var/rapid/aws-lambda-rie-x86_64; \
    elif [ -f /usr/local/bin/aws-lambda-rie-x86_64 ]; then \
      cp /usr/local/bin/aws-lambda-rie-x86_64 /var/rapid/aws-lambda-rie-x86_64; \
    else echo "RIE not found"; exit 1; fi

COPY --from=builder /out/bootstrap /var/runtime/bootstrap
RUN chmod +x /var/runtime/bootstrap
CMD ["bootstrap"]
