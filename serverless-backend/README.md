Rough plan for now

my-serverless-backend/
├── cmd/
│   ├── lambdaA/
│   │   └── main.go          # Entrypoint for Lambda A
│   └── lambdaB/
│       └── main.go          # Entrypoint for Lambda B
├── internal/
│   ├── helpers/
│   │   └── utils.go         # Shared helper functions
│   └── models/
│       └── types.go         # Structs/types shared by lambdas
├── go.mod                   # Go module file
├── go.sum                   # Go module checksums
├── Dockerfile               # Multi-stage Docker build for deployment
└── README.md

