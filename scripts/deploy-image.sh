#!/bin/bash

# Deploy to AWS ECS Fargate Script for BankManagementSystem
# This script deploys the Docker image to AWS ECS Fargate

set -e
set -o pipefail

echo "=========================================="
echo "BankManagementSystem - ECS Fargate Deployment"
echo "=========================================="
echo ""

# Project configuration
PROJECT_NAME="bankmanagementsystem"
TASK_FAMILY="${PROJECT_NAME}-task"
SERVICE_NAME="${PROJECT_NAME}-service"

# Prompt for AWS configuration
echo "=== AWS Configuration ==="
read -p "Enter AWS Region (e.g., us-east-1): " AWS_REGION
read -p "Enter ECS Cluster Name (e.g., my-ecs-cluster): " CLUSTER_NAME

echo ""
echo "=== Network Configuration ==="
read -p "Enter VPC ID (e.g., vpc-0abc123def456): " VPC_ID
read -p "Enter Subnet IDs comma-separated (e.g., subnet-0abc123,subnet-0def456): " SUBNET_IDS
read -p "Enter Security Group ID (e.g., sg-0abc123def): " SECURITY_GROUP

# Split subnet IDs
IFS=',' read -ra SUBNETS <<< "$SUBNET_IDS"
SUBNET_1="${SUBNETS[0]}"
SUBNET_2="${SUBNETS[1]:-$SUBNET_1}"

echo ""
echo "=== Docker Image Configuration ==="
read -p "Enter Docker Image URI (e.g., 123456789.dkr.ecr.us-east-1.amazonaws.com/app:latest): " IMAGE_URI

echo ""
echo "=== Database Configuration ==="
read -p "Enter Database Connection String: " DB_CONNECTION_STRING

echo ""
echo "=== Load Balancer Configuration ==="
read -p "Do you need a load balancer for this service? (y/n): " NEED_LB

# Get AWS Account ID
echo ""
echo "Retrieving AWS Account ID..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $ACCOUNT_ID"

# Check if ECS cluster exists, create if it doesn't
echo ""
echo "Checking if ECS cluster exists..."
aws ecs describe-clusters --clusters "$CLUSTER_NAME" --region "$AWS_REGION" >/dev/null 2>&1 || {
    echo "Cluster does not exist. Creating ECS cluster: $CLUSTER_NAME"
    aws ecs create-cluster --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION"
    echo "ECS cluster created successfully"
}

# Create CloudWatch log group if it doesn't exist
LOG_GROUP="/ecs/$PROJECT_NAME"
echo ""
echo "Creating CloudWatch log group: $LOG_GROUP"
aws logs create-log-group --log-group-name "$LOG_GROUP" --region "$AWS_REGION" 2>/dev/null || echo "Log group already exists"

# Handle load balancer creation if needed
if [[ "$NEED_LB" == "y" || "$NEED_LB" == "Y" ]]; then
    echo ""
    echo "=== Creating Application Load Balancer ==="
    
    # Create ALB
    ALB_NAME="${PROJECT_NAME}-alb"
    echo "Creating Application Load Balancer: $ALB_NAME"
    ALB_ARN=$(aws elbv2 create-load-balancer \
        --name "$ALB_NAME" \
        --subnets "$SUBNET_1" "$SUBNET_2" \
        --security-groups "$SECURITY_GROUP" \
        --scheme internet-facing \
        --type application \
        --ip-address-type ipv4 \
        --region "$AWS_REGION" \
        --query 'LoadBalancers[0].LoadBalancerArn' \
        --output text)
    
    echo "ALB created: $ALB_ARN"
    
    # Create Target Group with target-type ip (required for Fargate)
    TG_NAME="${PROJECT_NAME}-tg"
    echo "Creating Target Group: $TG_NAME"
    TARGET_GROUP_ARN=$(aws elbv2 create-target-group \
        --name "$TG_NAME" \
        --protocol HTTP \
        --port 8080 \
        --vpc-id "$VPC_ID" \
        --target-type ip \
        --health-check-enabled \
        --health-check-protocol HTTP \
        --health-check-path "/health" \
        --health-check-interval-seconds 30 \
        --health-check-timeout-seconds 5 \
        --healthy-threshold-count 2 \
        --unhealthy-threshold-count 3 \
        --region "$AWS_REGION" \
        --query 'TargetGroups[0].TargetGroupArn' \
        --output text)
    
    echo "Target Group created: $TARGET_GROUP_ARN"
    
    # Create Listener
    echo "Creating ALB Listener..."
    aws elbv2 create-listener \
        --load-balancer-arn "$ALB_ARN" \
        --protocol HTTP \
        --port 80 \
        --default-actions Type=forward,TargetGroupArn="$TARGET_GROUP_ARN" \
        --region "$AWS_REGION" >/dev/null
    
    echo "ALB Listener created successfully"
    
    # Get ALB DNS name
    ALB_DNS=$(aws elbv2 describe-load-balancers \
        --load-balancer-arns "$ALB_ARN" \
        --region "$AWS_REGION" \
        --query 'LoadBalancers[0].DNSName' \
        --output text)
    
    echo "ALB DNS Name: $ALB_DNS"
else
    TARGET_GROUP_ARN=""
fi

# Prepare task definition JSON
echo ""
echo "Preparing ECS task definition..."
TASK_DEF_FILE="ecs/task-definition.json"
TASK_DEF_TEMP="ecs/task-definition-temp.json"

cp "$TASK_DEF_FILE" "$TASK_DEF_TEMP"

# Replace placeholders in task definition
sed -i "s|{{IMAGE_URI}}|$IMAGE_URI|g" "$TASK_DEF_TEMP"
sed -i "s|{{AWS_REGION}}|$AWS_REGION|g" "$TASK_DEF_TEMP"
sed -i "s|{{ACCOUNT_ID}}|$ACCOUNT_ID|g" "$TASK_DEF_TEMP"
sed -i "s|{{DB_CONNECTION_STRING}}|$DB_CONNECTION_STRING|g" "$TASK_DEF_TEMP"

# Register task definition
echo "Registering ECS task definition..."
TASK_DEF_ARN=$(aws ecs register-task-definition \
    --cli-input-json file://"$TASK_DEF_TEMP" \
    --region "$AWS_REGION" \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)

echo "Task definition registered: $TASK_DEF_ARN"

# Clean up temp file
rm "$TASK_DEF_TEMP"

# Prepare service definition JSON
echo ""
echo "Preparing ECS service definition..."
SERVICE_DEF_FILE="ecs/service-definition.json"
SERVICE_DEF_TEMP="ecs/service-definition-temp.json"

cp "$SERVICE_DEF_FILE" "$SERVICE_DEF_TEMP"

# Replace placeholders in service definition
sed -i "s|{{CLUSTER_NAME}}|$CLUSTER_NAME|g" "$SERVICE_DEF_TEMP"
sed -i "s|{{SUBNET_1}}|$SUBNET_1|g" "$SERVICE_DEF_TEMP"
sed -i "s|{{SUBNET_2}}|$SUBNET_2|g" "$SERVICE_DEF_TEMP"
sed -i "s|{{SECURITY_GROUP}}|$SECURITY_GROUP|g" "$SERVICE_DEF_TEMP"
sed -i "s|{{TARGET_GROUP_ARN}}|$TARGET_GROUP_ARN|g" "$SERVICE_DEF_TEMP"

# Remove loadBalancers section if no load balancer
if [[ -z "$TARGET_GROUP_ARN" ]]; then
    # Remove loadBalancers and healthCheckGracePeriodSeconds from JSON
    python3 -c "
import json
with open('$SERVICE_DEF_TEMP', 'r') as f:
    data = json.load(f)
data.pop('loadBalancers', None)
data.pop('healthCheckGracePeriodSeconds', None)
with open('$SERVICE_DEF_TEMP', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null || {
    # Fallback if python3 is not available
    sed -i '/"loadBalancers":/,/],/d' "$SERVICE_DEF_TEMP"
    sed -i '/"healthCheckGracePeriodSeconds":/d' "$SERVICE_DEF_TEMP"
}
fi

# Check if service exists
echo ""
echo "Checking if ECS service exists..."
SERVICE_EXISTS=$(aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --region "$AWS_REGION" \
    --query 'services[?status==`ACTIVE`].serviceName' \
    --output text)

if [[ -z "$SERVICE_EXISTS" ]]; then
    # Create new service
    echo "Creating new ECS service: $SERVICE_NAME"
    aws ecs create-service \
        --cli-input-json file://"$SERVICE_DEF_TEMP" \
        --region "$AWS_REGION" >/dev/null
    
    echo "ECS service created successfully"
else
    # Update existing service
    echo "Updating existing ECS service: $SERVICE_NAME"
    aws ecs update-service \
        --cluster "$CLUSTER_NAME" \
        --service "$SERVICE_NAME" \
        --task-definition "$TASK_DEF_ARN" \
        --region "$AWS_REGION" >/dev/null
    
    echo "ECS service updated successfully"
fi

# Clean up temp file
rm "$SERVICE_DEF_TEMP"

# Wait for service to stabilize
echo ""
echo "Waiting for service to stabilize (this may take a few minutes)..."
aws ecs wait services-stable \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --region "$AWS_REGION"

echo "Service is stable"

# Verify deployment
echo ""
echo "=========================================="
echo "Deployment Verification"
echo "=========================================="

SERVICE_INFO=$(aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --region "$AWS_REGION" \
    --query 'services[0]')

RUNNING_COUNT=$(echo "$SERVICE_INFO" | grep -o '"runningCount": [0-9]*' | grep -o '[0-9]*')
DESIRED_COUNT=$(echo "$SERVICE_INFO" | grep -o '"desiredCount": [0-9]*' | grep -o '[0-9]*')

echo "Service Name: $SERVICE_NAME"
echo "Cluster: $CLUSTER_NAME"
echo "Running Tasks: $RUNNING_COUNT"
echo "Desired Tasks: $DESIRED_COUNT"
echo "Task Definition: $TASK_DEF_ARN"

if [[ -n "$ALB_DNS" ]]; then
    echo ""
    echo "Application Load Balancer:"
    echo "  DNS Name: $ALB_DNS"
    echo "  Access URL: http://$ALB_DNS"
    echo "  Health Check: http://$ALB_DNS/health"
fi

echo ""
echo "CloudWatch Logs:"
echo "  Log Group: $LOG_GROUP"
echo "  Region: $AWS_REGION"
echo ""
echo "To view logs, run:"
echo "  aws logs tail $LOG_GROUP --follow --region $AWS_REGION"

echo ""
echo "=========================================="
echo "Deployment Completed Successfully"
echo "=========================================="
echo ""
