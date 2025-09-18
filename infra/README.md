# AWS Serverless Application Architecture

## 🚀 Overview

This repository contains the Terraform code for deploying a full-stack, serverless web application on AWS. The architecture is designed to be highly scalable, secure, and cost-effective, leveraging managed services for compute, data storage, and frontend hosting. The application allows users to upload files and then lists those files, demonstrating a common asynchronous processing pattern.

***

## 🏛️ Architecture

The application is built on a modern serverless stack, with each component fulfilling a specific role in the system.

### **Frontend**

* **AWS Amplify:** The frontend is a React application hosted on **AWS Amplify**. It provides a fully managed hosting solution with a built-in CI/CD pipeline. The frontend communicates with the backend API and directly with the S3 bucket for file uploads.

### **Backend**

* **API Gateway:** The backend API is a **REST API (v1)** managed by **API Gateway**. It acts as the public entry point for the application.
    * **Cognito Authorizer:** API endpoints are secured using a **Cognito User Pool Authorizer**, ensuring only authenticated users can access the protected resources.
    * **WAF Integration:** A **WAFv2 Web ACL** is associated with the API Gateway stage to protect against common web exploits and enforce rate limiting.
    * **Access Logging:** All API requests are logged to **CloudWatch Logs** for monitoring and debugging.

* **Lambda Functions:** The API Gateway routes requests to three backend Lambda functions, all of which run inside a **VPC** for enhanced security.
    * `api-presign`: An API endpoint that generates secure, temporary **presigned S3 URLs** for client-side file uploads. It also creates a placeholder item in the DynamoDB table.
    * `api-list`: An API endpoint that **queries DynamoDB** to retrieve a list of a user's uploaded files.
    * `indexer`: An **S3 event-triggered Lambda** that processes new files as they are uploaded to the S3 bucket. It updates the DynamoDB item with metadata from the uploaded file.

* **Data and Storage:**
    * **DynamoDB:** A NoSQL table (`claims`) is used to store metadata about each uploaded file. It is configured with **Pay-Per-Request** billing and is encrypted at rest using a dedicated **KMS key**.
    * **S3:** A private S3 bucket (`claims`) stores the raw uploaded files. It is configured to **block all public access** and **enforces server-side encryption with KMS**.

### **Security and Networking**

* **VPC:** All backend services (**Lambda functions, VPC Endpoints**) are deployed within a **VPC**. This isolates them from the public internet.
* **VPC Endpoints:** Instead of using an Internet Gateway and NAT Gateway, services communicate with other AWS services (**S3, DynamoDB, KMS, CloudWatch Logs**) through **VPC Endpoints**. This keeps traffic on the private AWS network, reducing data transfer costs and improving security.
* **IAM:** Each Lambda function has a dedicated **IAM Role** with a **fine-grained inline policy**, adhering to the principle of least privilege. This ensures each function can only access the resources it needs.
* **KMS:** Two separate **KMS keys** are used to encrypt data at rest in S3 and DynamoDB, providing an extra layer of security.

***

## 🏗️ Deployment

The entire architecture is deployed using **Terraform**. The configuration is organized into separate files for each service, with shared variables managed in `locals.tf` and `variables.tf`. This modular design makes the code easy to read, modify, and maintain.

To deploy this infrastructure, you will need to:

1.  Configure your AWS credentials.
2.  Review and modify variables in `variables.tf` as needed.
3.  Run `terraform init`, `terraform plan`, and `terraform apply`.

***

## 🤝 Key Design Decisions

* **Serverless First:** Choosing Lambda, API Gateway, DynamoDB, and S3 provides a **scalable, fully managed, and pay-per-use** architecture, eliminating the need to manage servers.
* **Security by Default:** The network architecture is built around a private VPC with VPC endpoints, minimizing attack surfaces. The S3 and DynamoDB resources are secured with KMS encryption and strict access policies.
* **Event-Driven Processing:** Using S3 events to trigger the `indexer` Lambda decouples the file upload process from the processing logic, making the system more resilient and scalable.
* **Centralized Configuration:** The use of `locals.tf` and `variables.tf` centralizes all configuration, making it easy to manage environments and shared values.