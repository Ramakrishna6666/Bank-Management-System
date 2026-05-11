#!/bin/bash

# Build and Push Script for BankManagementSystem
# This script builds the Docker image and pushes it to the selected registry

set -e

echo "=========================================="
echo "BankManagementSystem - Build & Push Script"
echo "=========================================="
echo ""

# Project configuration
PROJECT_NAME="BankManagementSystem"

# Sanitize project name for Docker image naming (lowercase, hyphenate)
IMAGE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')

echo "Project: $PROJECT_NAME"
echo "Image Name: $IMAGE_NAME"
echo ""

# Prompt for registry selection
echo "Select Docker Registry:"
echo "1. AWS ECR (Elastic Container Registry)"
echo "2. Docker Hub"
read -p "Enter your choice (1 or 2): " REGISTRY_CHOICE

if [ "$REGISTRY_CHOICE" == "1" ]; then
    echo ""
    echo "=== AWS ECR Configuration ==="
    read -p "Enter AWS Region (e.g., us-east-1): " AWS_REGION
    read -p "Enter AWS Account ID: " AWS_ACCOUNT_ID
    read -p "Enter ECR Repository Name (default: $IMAGE_NAME): " ECR_REPO
    ECR_REPO=${ECR_REPO:-$IMAGE_NAME}
    
    REGISTRY_URL="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
    FULL_IMAGE_NAME="$REGISTRY_URL/$ECR_REPO"
    
    echo ""
    echo "Authenticating with AWS ECR..."
    aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$REGISTRY_URL"
    
    if [ $? -ne 0 ]; then
        echo "ERROR: ECR authentication failed"
        exit 1
    fi
    
    echo "ECR authentication successful"
    
    # Check if repository exists, create if it doesn't
    echo "Checking if ECR repository exists..."
    aws ecr describe-repositories --repository-names "$ECR_REPO" --region "$AWS_REGION" >/dev/null 2>&1 || {
        echo "Repository does not exist. Creating ECR repository: $ECR_REPO"
        aws ecr create-repository --repository-name "$ECR_REPO" --region "$AWS_REGION"
        echo "ECR repository created successfully"
    }
    
elif [ "$REGISTRY_CHOICE" == "2" ]; then
    echo ""
    echo "=== Docker Hub Configuration ==="
    read -p "Enter Docker Hub Username: " DOCKER_USERNAME
    read -sp "Enter Docker Hub Password/Token: " DOCKER_PASSWORD
    echo ""
    read -p "Enter Repository Name (default: $IMAGE_NAME): " DOCKER_REPO
    DOCKER_REPO=${DOCKER_REPO:-$IMAGE_NAME}
    
    FULL_IMAGE_NAME="$DOCKER_USERNAME/$DOCKER_REPO"
    
    echo ""
    echo "Authenticating with Docker Hub..."
    echo "$DOCKER_PASSWORD" | docker login --username "$DOCKER_USERNAME" --password-stdin
    
    if [ $? -ne 0 ]; then
        echo "ERROR: Docker Hub authentication failed"
        exit 1
    fi
    
    echo "Docker Hub authentication successful"
else
    echo "ERROR: Invalid choice. Please select 1 or 2."
    exit 1
fi

# Prompt for image tag
echo ""
read -p "Enter image tag (default: latest): " IMAGE_TAG
IMAGE_TAG=${IMAGE_TAG:-latest}

# Sanitize tag (lowercase, hyphenate, trim hyphens)
IMAGE_TAG=$(echo "$IMAGE_TAG" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9.-' '-' | sed 's/^-*//;s/-*$//')

# Build full image name with tag
FULL_IMAGE_WITH_TAG="$FULL_IMAGE_NAME:$IMAGE_TAG"

echo ""
echo "=========================================="
echo "Building Docker Image"
echo "=========================================="
echo "Image: $FULL_IMAGE_WITH_TAG"
echo ""

# Build the Docker image
docker build -f Dockerfile -t "$FULL_IMAGE_WITH_TAG" .

if [ $? -ne 0 ]; then
    echo "ERROR: Docker build failed"
    exit 1
fi

echo ""
echo "Docker build completed successfully"

echo ""
echo "=========================================="
echo "Pushing Docker Image"
echo "=========================================="
echo "Pushing: $FULL_IMAGE_WITH_TAG"
echo ""

# Push the Docker image
docker push "$FULL_IMAGE_WITH_TAG"

if [ $? -ne 0 ]; then
    echo "ERROR: Docker push failed"
    exit 1
fi

echo ""
echo "=========================================="
echo "Build & Push Completed Successfully"
echo "=========================================="
echo "Image: $FULL_IMAGE_WITH_TAG"
echo ""
echo "Next Steps:"
echo "1. Update ECS task definition with this image URI"
echo "2. Run deploy-image.sh to deploy to AWS ECS"
echo ""
