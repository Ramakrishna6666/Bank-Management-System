# BankManagementSystem - AWS ECS Fargate Deployment Guide

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Project Architecture](#project-architecture)
4. [Local Development Setup](#local-development-setup)
5. [Docker Containerization](#docker-containerization)
6. [AWS ECS Fargate Deployment](#aws-ecs-fargate-deployment)
7. [Configuration Management](#configuration-management)
8. [Monitoring and Logging](#monitoring-and-logging)
9. [Troubleshooting](#troubleshooting)
10. [Security Considerations](#security-considerations)
11. [Scaling and Performance](#scaling-and-performance)

---

## Overview

BankManagementSystem is a .NET 8.0 Windows Forms application that has been containerized for deployment on AWS ECS Fargate. This guide provides comprehensive instructions for building, deploying, and managing the application in a containerized environment.

### Technology Stack
- **Framework**: .NET 8.0
- **Application Type**: Windows Forms Application
- **Database**: SQL Server (Microsoft.Data.SqlClient)
- **Container Runtime**: Docker
- **Orchestration**: AWS ECS Fargate
- **Logging**: CloudWatch Logs

### Key Features
- Health check endpoint on port 8080
- SQL Server database connectivity
- CloudWatch logging integration
- Auto-scaling capabilities
- High availability with multiple tasks

---

## Prerequisites

### Required Tools
1. **Docker Desktop** (version 20.10 or later)
   - Download: https://www.docker.com/products/docker-desktop
   - Ensure Docker is running before building images

2. **AWS CLI** (version 2.x)
   - Download: https://aws.amazon.com/cli/
   - Configure with: `aws configure`

3. **.NET 8.0 SDK** (for local development)
   - Download: https://dotnet.microsoft.com/download/dotnet/8.0

4. **Git** (for version control)
   - Download: https://git-scm.com/

### AWS Account Requirements
- Active AWS account with appropriate permissions
- IAM user with the following permissions:
  - ECS full access
  - ECR full access
  - CloudWatch Logs write access
  - VPC and networking permissions
  - IAM role creation (for task execution)

### AWS Infrastructure Prerequisites
1. **VPC Configuration**
   - VPC with at least 2 subnets in different availability zones
   - Internet Gateway attached to VPC
   - Route tables configured for internet access

2. **Security Groups**
   - Inbound rule: Port 8080 (health check)
   - Inbound rule: Port 80 (if using ALB)
   - Outbound rule: All traffic (for database and external services)

3. **IAM Roles**
   - **ecsTaskExecutionRole**: Allows ECS to pull images and write logs
   - **ecsTaskRole**: Allows tasks to access AWS services (optional)

---

## Project Architecture

### Application Structure
```
BankManagementSystem/
├── BankManagementSystem/          # Main application project
│   ├── Program.cs                 # Entry point with health check service
│   ├── LoginUI.cs                 # Login interface
│   ├── EmployeeDashboardForms/    # Employee UI components
│   ├── CustomerDashboardForms/    # Customer UI components
│   └── App.config                 # Configuration file
├── BankDatabaseAccess/            # Database access layer
│   ├── DatabaseConnection.cs     # Database connection management
│   ├── HealthCheckService.cs     # HTTP health check endpoint
│   ├── EntityModel/              # Data models
│   └── DatabaseOperation/        # Database operations
└── BankManagementSystem.sln      # Solution file
```

### Containerization Architecture
```
┌─────────────────────────────────────────┐
│         Application Load Balancer       │
│              (Port 80)                  │
└─────────────────┬───────────────────────┘
                  │
    ┌─────────────┴─────────────┐
    │                           │
┌───▼────────┐          ┌───────▼───┐
│  ECS Task  │          │ ECS Task  │
│  (Fargate) │          │ (Fargate) │
│            │          │           │
│  Port 8080 │          │ Port 8080 │
└────────────┘          └───────────┘
     │                       │
     └───────────┬───────────┘
                 │
         ┌───────▼────────┐
         │   SQL Server   │
         │   Database     │
         └────────────────┘
```

### Health Check Endpoint
The application includes a built-in HTTP health check service that:
- Listens on port 8080 (configurable via `HEALTH_CHECK_PORT` environment variable)
- Responds to `GET /health` requests
- Returns JSON status: `{"status":"healthy","timestamp":"2024-01-01T00:00:00Z"}`
- Validates database connection string availability

---

## Local Development Setup

### 1. Clone the Repository
```bash
git clone <repository-url>
cd Banktest
```

### 2. Restore Dependencies
```bash
dotnet restore BankManagementSystem.sln
```

### 3. Configure Database Connection
Edit `BankManagementSystem/App.config`:
```xml
<connectionStrings>
  <add name="OpenBankLocal"
       providerName="System.Data.ProviderName"
       connectionString="Data Source=localhost;Initial Catalog=OpenBankLocal;User ID=sa;Password=YourPassword;TrustServerCertificate=True" />
</connectionStrings>
```

### 4. Build the Application
```bash
cd BankManagementSystem
dotnet build -c Release
```

### 5. Run Locally
```bash
dotnet run
```

---

## Docker Containerization

### Understanding the Dockerfile

The Dockerfile uses a multi-stage build approach:

**Stage 1: Builder (SDK Image)**
- Uses `mcr.microsoft.com/dotnet/sdk:8.0`
- Copies project files and restores dependencies
- Builds and publishes the application

**Stage 2: Runtime (Runtime Image)**
- Uses `mcr.microsoft.com/dotnet/runtime:8.0`
- Copies only the published output
- Creates non-root user for security
- Exposes port 8080 for health checks

### Build Docker Image Locally

```bash
# Build the image
docker build -t bankmanagementsystem:latest .

# Verify the image
docker images | grep bankmanagementsystem
```

### Test Docker Image Locally

```bash
# Run the container
docker run -d \
  --name bankapp \
  -p 8080:8080 \
  -e HEALTH_CHECK_PORT=8080 \
  -e ConnectionStrings__OpenBankLocal="Data Source=host.docker.internal;Initial Catalog=OpenBankLocal;User ID=sa;Password=YourPassword;TrustServerCertificate=True" \
  bankmanagementsystem:latest

# Check health endpoint
curl http://localhost:8080/health

# View logs
docker logs bankapp

# Stop and remove
docker stop bankapp
docker rm bankapp
```

### Using Docker Compose

```bash
# Set environment variables
export DB_HOST=your-db-host
export DB_NAME=OpenBankLocal
export DB_USER=sa
export DB_PASSWORD=YourPassword

# Start the application
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the application
docker-compose down
```

---

## AWS ECS Fargate Deployment

### Step 1: Build and Push Docker Image

#### Option A: Using AWS ECR

**Linux/macOS:**
```bash
cd scripts
chmod +x build-push.sh
./build-push.sh
```

**Windows:**
```cmd
cd scripts
build-push.bat
```

**Interactive Prompts:**
1. Select registry type: `1` (AWS ECR)
2. Enter AWS Region: `us-east-1`
3. Enter AWS Account ID: `123456789012`
4. Enter ECR Repository Name: `bankmanagementsystem`
5. Enter image tag: `latest` (or version number)

The script will:
- Authenticate with AWS ECR
- Create ECR repository if it doesn't exist
- Build the Docker image
- Push to ECR

**Expected Output:**
```
Image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/bankmanagementsystem:latest
```

#### Option B: Using Docker Hub

Follow the same steps but select option `2` for Docker Hub and provide your Docker Hub credentials.

### Step 2: Create IAM Roles

#### Create ECS Task Execution Role

```bash
# Create trust policy file
cat > ecs-task-execution-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create the role
aws iam create-role \
  --role-name ecsTaskExecutionRole \
  --assume-role-policy-document file://ecs-task-execution-trust-policy.json

# Attach AWS managed policy
aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
```

#### Create ECS Task Role (Optional)

```bash
# Create the role
aws iam create-role \
  --role-name ecsTaskRole \
  --assume-role-policy-document file://ecs-task-execution-trust-policy.json

# Attach policies as needed (e.g., for S3, DynamoDB access)
```

### Step 3: Deploy to ECS Fargate

**Linux/macOS:**
```bash
cd scripts
chmod +x deploy-image.sh
./deploy-image.sh
```

**Windows:**
```cmd
cd scripts
deploy-image.bat
```

**Interactive Prompts:**

1. **AWS Configuration:**
   - AWS Region: `us-east-1`
   - ECS Cluster Name: `bankapp-cluster`

2. **Network Configuration:**
   - VPC ID: `vpc-0abc123def456`
   - Subnet IDs: `subnet-0abc123,subnet-0def456`
   - Security Group ID: `sg-0abc123def`

3. **Docker Image:**
   - Image URI: `123456789012.dkr.ecr.us-east-1.amazonaws.com/bankmanagementsystem:latest`

4. **Database Configuration:**
   - Connection String: `Data Source=your-rds-endpoint;Initial Catalog=OpenBankLocal;User ID=admin;Password=YourPassword;TrustServerCertificate=True`

5. **Load Balancer:**
   - Need load balancer? `y` or `n`

The script will:
- Create ECS cluster (if doesn't exist)
- Create CloudWatch log group
- Create Application Load Balancer and Target Group (if requested)
- Register ECS task definition
- Create or update ECS service
- Wait for service to stabilize

**Expected Output:**
```
Service Name: bankmanagementsystem-service
Cluster: bankapp-cluster
Running Tasks: 2
Desired Tasks: 2
Task Definition: arn:aws:ecs:us-east-1:123456789012:task-definition/bankmanagementsystem-task:1

Application Load Balancer:
  DNS Name: bankapp-alb-123456789.us-east-1.elb.amazonaws.com
  Access URL: http://bankapp-alb-123456789.us-east-1.elb.amazonaws.com
  Health Check: http://bankapp-alb-123456789.us-east-1.elb.amazonaws.com/health

CloudWatch Logs:
  Log Group: /ecs/bankmanagementsystem
  Region: us-east-1
```

### Step 4: Verify Deployment

#### Check Service Status
```bash
aws ecs describe-services \
  --cluster bankapp-cluster \
  --services bankmanagementsystem-service \
  --region us-east-1
```

#### Check Running Tasks
```bash
aws ecs list-tasks \
  --cluster bankapp-cluster \
  --service-name bankmanagementsystem-service \
  --region us-east-1
```

#### Test Health Endpoint
```bash
# If using ALB
curl http://your-alb-dns-name/health

# Expected response
{"status":"healthy","timestamp":"2024-01-01T00:00:00Z"}
```

---

## Configuration Management

### Environment Variables

The application supports the following environment variables:

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `DOTNET_ENVIRONMENT` | Application environment | Production | No |
| `HEALTH_CHECK_PORT` | Health check endpoint port | 8080 | No |
| `TZ` | Timezone | UTC | No |
| `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT` | Globalization settings | false | No |
| `ConnectionStrings__OpenBankLocal` | Database connection string | - | Yes |

### Updating Configuration

#### Update Task Definition
1. Edit `ecs/task-definition.json`
2. Modify environment variables in `containerDefinitions[0].environment`
3. Re-run deployment script

#### Update Service
```bash
# Update service with new task definition
aws ecs update-service \
  --cluster bankapp-cluster \
  --service bankmanagementsystem-service \
  --task-definition bankmanagementsystem-task \
  --force-new-deployment \
  --region us-east-1
```

### Database Connection String Format

**SQL Server with SQL Authentication:**
```
Data Source=your-rds-endpoint.rds.amazonaws.com;Initial Catalog=OpenBankLocal;User ID=admin;Password=YourPassword;TrustServerCertificate=True;Encrypt=True
```

**SQL Server with Integrated Security (Windows Auth):**
```
Data Source=your-server;Initial Catalog=OpenBankLocal;Integrated Security=True
```

---

## Monitoring and Logging

### CloudWatch Logs

#### View Logs in AWS Console
1. Navigate to CloudWatch → Log groups
2. Find `/ecs/bankmanagementsystem`
3. Select log stream to view logs

#### View Logs via CLI
```bash
# Tail logs in real-time
aws logs tail /ecs/bankmanagementsystem --follow --region us-east-1

# Get recent logs
aws logs tail /ecs/bankmanagementsystem --since 1h --region us-east-1

# Filter logs
aws logs filter-log-events \
  --log-group-name /ecs/bankmanagementsystem \
  --filter-pattern "ERROR" \
  --region us-east-1
```

### CloudWatch Metrics

Key metrics to monitor:
- **CPUUtilization**: Task CPU usage
- **MemoryUtilization**: Task memory usage
- **TargetResponseTime**: ALB response time
- **HealthyHostCount**: Number of healthy targets
- **UnHealthyHostCount**: Number of unhealthy targets

#### Create CloudWatch Dashboard
```bash
aws cloudwatch put-dashboard \
  --dashboard-name BankManagementSystem \
  --dashboard-body file://cloudwatch-dashboard.json \
  --region us-east-1
```

### Application Insights (Optional)

For advanced monitoring, consider integrating Application Insights:
1. Add `Microsoft.ApplicationInsights.AspNetCore` NuGet package
2. Configure instrumentation key in environment variables
3. Update Dockerfile to include Application Insights

---

## Troubleshooting

### Common Issues and Solutions

#### 1. Task Fails to Start

**Symptoms:**
- Tasks transition from PENDING to STOPPED
- No logs in CloudWatch

**Possible Causes:**
- Invalid CPU/memory combination
- Image pull failure
- Missing IAM permissions

**Solutions:**
```bash
# Check task stopped reason
aws ecs describe-tasks \
  --cluster bankapp-cluster \
  --tasks <task-id> \
  --region us-east-1 \
  --query 'tasks[0].stoppedReason'

# Verify IAM role
aws iam get-role --role-name ecsTaskExecutionRole

# Check ECR permissions
aws ecr get-repository-policy --repository-name bankmanagementsystem
```

#### 2. Health Check Failures

**Symptoms:**
- Tasks marked as unhealthy
- ALB shows unhealthy targets

**Possible Causes:**
- Application not listening on port 8080
- Security group blocking traffic
- Application startup taking too long

**Solutions:**
```bash
# Check security group rules
aws ec2 describe-security-groups --group-ids <sg-id>

# Increase health check grace period
aws ecs update-service \
  --cluster bankapp-cluster \
  --service bankmanagementsystem-service \
  --health-check-grace-period-seconds 300 \
  --region us-east-1

# Test health endpoint directly
aws ecs execute-command \
  --cluster bankapp-cluster \
  --task <task-id> \
  --container bankmanagementsystem \
  --interactive \
  --command "/bin/sh"
```

#### 3. Database Connection Failures

**Symptoms:**
- Application logs show connection errors
- Health check returns unhealthy status

**Possible Causes:**
- Incorrect connection string
- Database not accessible from ECS tasks
- Security group blocking database port

**Solutions:**
```bash
# Verify connection string format
# Check database security group allows inbound from ECS security group
# Test database connectivity from ECS task

# Update connection string
aws ecs update-service \
  --cluster bankapp-cluster \
  --service bankmanagementsystem-service \
  --force-new-deployment \
  --region us-east-1
```

#### 4. Out of Memory Errors

**Symptoms:**
- Tasks stop with exit code 137
- Logs show OutOfMemoryException

**Solutions:**
```bash
# Increase memory allocation in task definition
# Edit ecs/task-definition.json
# Change "memory": "1024" to "memory": "2048"

# Valid Fargate CPU/Memory combinations:
# CPU: 512  → Memory: 1024, 2048, 3072, 4096
# CPU: 1024 → Memory: 2048-8192 (increments of 1024)
# CPU: 2048 → Memory: 4096-16384 (increments of 1024)
```

#### 5. Service Update Failures

**Symptoms:**
- Service update stuck in progress
- New tasks not starting

**Solutions:**
```bash
# Check service events
aws ecs describe-services \
  --cluster bankapp-cluster \
  --services bankmanagementsystem-service \
  --region us-east-1 \
  --query 'services[0].events[0:10]'

# Force new deployment
aws ecs update-service \
  --cluster bankapp-cluster \
  --service bankmanagementsystem-service \
  --force-new-deployment \
  --region us-east-1

# If stuck, delete and recreate service
aws ecs delete-service \
  --cluster bankapp-cluster \
  --service bankmanagementsystem-service \
  --force \
  --region us-east-1
```

### Debugging Commands

```bash
# Get task details
aws ecs describe-tasks \
  --cluster bankapp-cluster \
  --tasks <task-id> \
  --region us-east-1

# Get container logs
aws logs get-log-events \
  --log-group-name /ecs/bankmanagementsystem \
  --log-stream-name ecs/bankmanagementsystem/<task-id> \
  --region us-east-1

# Check ALB target health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn> \
  --region us-east-1

# List all tasks in cluster
aws ecs list-tasks \
  --cluster bankapp-cluster \
  --region us-east-1
```

---

## Security Considerations

### 1. Container Security

**Best Practices:**
- Use official Microsoft base images
- Run as non-root user (implemented in Dockerfile)
- Scan images for vulnerabilities
- Keep base images updated

**Image Scanning:**
```bash
# Enable ECR image scanning
aws ecr put-image-scanning-configuration \
  --repository-name bankmanagementsystem \
  --image-scanning-configuration scanOnPush=true \
  --region us-east-1

# View scan results
aws ecr describe-image-scan-findings \
  --repository-name bankmanagementsystem \
  --image-id imageTag=latest \
  --region us-east-1
```

### 2. Network Security

**Security Group Configuration:**
```bash
# ECS Task Security Group
# Inbound: Port 8080 from ALB security group
# Outbound: Port 1433 to database security group

# ALB Security Group
# Inbound: Port 80 from 0.0.0.0/0
# Outbound: Port 8080 to ECS task security group

# Database Security Group
# Inbound: Port 1433 from ECS task security group
```

### 3. Secrets Management

**Using AWS Secrets Manager:**

1. Store database password in Secrets Manager:
```bash
aws secretsmanager create-secret \
  --name bankmanagementsystem/db-password \
  --secret-string "YourSecurePassword" \
  --region us-east-1
```

2. Update task definition to use secrets:
```json
{
  "secrets": [
    {
      "name": "DB_PASSWORD",
      "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789012:secret:bankmanagementsystem/db-password"
    }
  ]
}
```

3. Grant task execution role access:
```bash
aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite
```

### 4. IAM Permissions

**Principle of Least Privilege:**
- Task execution role: Only ECR pull and CloudWatch write
- Task role: Only required AWS service access
- Avoid using root AWS account credentials

### 5. Encryption

**Enable Encryption:**
- ECS task storage: Encrypted by default
- CloudWatch Logs: Enable encryption with KMS
- Database: Enable encryption at rest and in transit
- ALB: Use HTTPS with SSL/TLS certificates

---

## Scaling and Performance

### Auto Scaling Configuration

#### Target Tracking Scaling

```bash
# Create scaling policy for CPU utilization
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --scalable-dimension ecs:service:DesiredCount \
  --resource-id service/bankapp-cluster/bankmanagementsystem-service \
  --min-capacity 2 \
  --max-capacity 10 \
  --region us-east-1

aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --scalable-dimension ecs:service:DesiredCount \
  --resource-id service/bankapp-cluster/bankmanagementsystem-service \
  --policy-name cpu-scaling-policy \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration file://scaling-policy.json \
  --region us-east-1
```

**scaling-policy.json:**
```json
{
  "TargetValue": 70.0,
  "PredefinedMetricSpecification": {
    "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
  },
  "ScaleInCooldown": 300,
  "ScaleOutCooldown": 60
}
```

#### Step Scaling

```bash
# Create CloudWatch alarm
aws cloudwatch put-metric-alarm \
  --alarm-name bankmanagementsystem-high-cpu \
  --alarm-description "Scale up when CPU > 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --region us-east-1

# Create scaling policy
aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --scalable-dimension ecs:service:DesiredCount \
  --resource-id service/bankapp-cluster/bankmanagementsystem-service \
  --policy-name step-scaling-policy \
  --policy-type StepScaling \
  --step-scaling-policy-configuration file://step-scaling-policy.json \
  --region us-east-1
```

### Performance Optimization

#### 1. .NET Runtime Optimization

**Enable ReadyToRun (R2R) Compilation:**
```xml
<!-- Add to .csproj -->
<PropertyGroup>
  <PublishReadyToRun>true</PublishReadyToRun>
  <PublishReadyToRunShowWarnings>true</PublishReadyToRunShowWarnings>
</PropertyGroup>
```

#### 2. Container Optimization

**Multi-stage Build Benefits:**
- Smaller runtime image (no SDK)
- Faster deployment
- Reduced attack surface

**Layer Caching:**
- Copy project files before source code
- Restore dependencies in separate layer
- Maximize Docker layer cache hits

#### 3. Database Connection Pooling

**Configure in Connection String:**
```
Data Source=your-server;Initial Catalog=OpenBankLocal;User ID=admin;Password=YourPassword;Min Pool Size=5;Max Pool Size=100;Pooling=true
```

#### 4. Resource Allocation

**Recommended Fargate Configurations:**

| Workload | CPU | Memory | Cost/Hour |
|----------|-----|--------|-----------|
| Development | 256 | 512 MB | $0.01 |
| Testing | 512 | 1024 MB | $0.04 |
| Production (Low) | 1024 | 2048 MB | $0.08 |
| Production (High) | 2048 | 4096 MB | $0.16 |

### Blue/Green Deployment

```bash
# Create new task definition revision
aws ecs register-task-definition \
  --cli-input-json file://ecs/task-definition.json \
  --region us-east-1

# Update service with new task definition
aws ecs update-service \
  --cluster bankapp-cluster \
  --service bankmanagementsystem-service \
  --task-definition bankmanagementsystem-task:2 \
  --deployment-configuration "maximumPercent=200,minimumHealthyPercent=100" \
  --region us-east-1

# Monitor deployment
aws ecs describe-services \
  --cluster bankapp-cluster \
  --services bankmanagementsystem-service \
  --region us-east-1 \
  --query 'services[0].deployments'
```

---

## Additional Resources

### AWS Documentation
- [ECS Fargate Documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html)
- [ECR User Guide](https://docs.aws.amazon.com/AmazonECR/latest/userguide/)
- [CloudWatch Logs](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/)

### .NET Documentation
- [.NET 8.0 Documentation](https://docs.microsoft.com/en-us/dotnet/core/)
- [Containerize .NET Apps](https://docs.microsoft.com/en-us/dotnet/core/docker/introduction)
- [ASP.NET Core Health Checks](https://docs.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks)

### Docker Documentation
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Multi-stage Builds](https://docs.docker.com/develop/develop-images/multistage-build/)

---

## Support and Maintenance

### Regular Maintenance Tasks

1. **Weekly:**
   - Review CloudWatch logs for errors
   - Check service health metrics
   - Monitor cost and usage

2. **Monthly:**
   - Update base images
   - Review and optimize resource allocation
   - Scan images for vulnerabilities
   - Review and rotate secrets

3. **Quarterly:**
   - Update .NET runtime version
   - Review and update dependencies
   - Performance testing and optimization
   - Disaster recovery testing

### Getting Help

For issues or questions:
1. Check CloudWatch logs for error messages
2. Review this deployment guide
3. Consult AWS documentation
4. Contact your DevOps team or AWS support

---

## Conclusion

This deployment guide provides comprehensive instructions for containerizing and deploying the BankManagementSystem application on AWS ECS Fargate. Follow the steps carefully, and refer to the troubleshooting section for common issues.

For production deployments, ensure you:
- Use proper secrets management
- Enable encryption at rest and in transit
- Configure auto-scaling appropriately
- Set up comprehensive monitoring and alerting
- Implement proper backup and disaster recovery procedures

**Happy Deploying! 🚀**
