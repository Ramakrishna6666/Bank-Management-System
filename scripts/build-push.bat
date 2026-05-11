@echo off
setlocal enabledelayedexpansion

REM Build and Push Script for BankManagementSystem
REM This script builds the Docker image and pushes it to the selected registry

echo ==========================================
echo BankManagementSystem - Build and Push Script
echo ==========================================
echo.

REM Project configuration
set PROJECT_NAME=BankManagementSystem

REM Sanitize project name for Docker image naming (lowercase, hyphenate)
set IMAGE_NAME=%PROJECT_NAME%
for %%i in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    set IMAGE_NAME=!IMAGE_NAME:%%i=%%i!
)
set IMAGE_NAME=%IMAGE_NAME: =-%
set IMAGE_NAME=%IMAGE_NAME%
powershell -Command "$name='%IMAGE_NAME%'; $name=$name.ToLower(); $name=$name -replace '[^a-z0-9]+','-'; $name=$name.Trim('-'); Write-Host $name" > temp_name.txt
set /p IMAGE_NAME=<temp_name.txt
del temp_name.txt

echo Project: %PROJECT_NAME%
echo Image Name: %IMAGE_NAME%
echo.

REM Prompt for registry selection
echo Select Docker Registry:
echo 1. AWS ECR (Elastic Container Registry)
echo 2. Docker Hub
set /p REGISTRY_CHOICE="Enter your choice (1 or 2): "

if "!REGISTRY_CHOICE!"=="1" (
    echo.
    echo === AWS ECR Configuration ===
    set /p AWS_REGION="Enter AWS Region (e.g., us-east-1): "
    set /p AWS_ACCOUNT_ID="Enter AWS Account ID: "
    set /p ECR_REPO="Enter ECR Repository Name (default: %IMAGE_NAME%): "
    if "!ECR_REPO!"=="" set ECR_REPO=%IMAGE_NAME%
    
    set REGISTRY_URL=!AWS_ACCOUNT_ID!.dkr.ecr.!AWS_REGION!.amazonaws.com
    set FULL_IMAGE_NAME=!REGISTRY_URL!/!ECR_REPO!
    
    echo.
    echo Authenticating with AWS ECR...
    aws ecr get-login-password --region !AWS_REGION! | docker login --username AWS --password-stdin !REGISTRY_URL!
    
    if !ERRORLEVEL! neq 0 (
        echo ERROR: ECR authentication failed
        exit /b 1
    )
    
    echo ECR authentication successful
    
    REM Check if repository exists, create if it doesn't
    echo Checking if ECR repository exists...
    aws ecr describe-repositories --repository-names !ECR_REPO! --region !AWS_REGION! >nul 2>&1
    if !ERRORLEVEL! neq 0 (
        echo Repository does not exist. Creating ECR repository: !ECR_REPO!
        aws ecr create-repository --repository-name !ECR_REPO! --region !AWS_REGION!
        if !ERRORLEVEL! neq 0 (
            echo ERROR: Failed to create ECR repository
            exit /b 1
        )
        echo ECR repository created successfully
    )
    
) else if "!REGISTRY_CHOICE!"=="2" (
    echo.
    echo === Docker Hub Configuration ===
    set /p DOCKER_USERNAME="Enter Docker Hub Username: "
    set /p DOCKER_PASSWORD="Enter Docker Hub Password/Token: "
    set /p DOCKER_REPO="Enter Repository Name (default: %IMAGE_NAME%): "
    if "!DOCKER_REPO!"=="" set DOCKER_REPO=%IMAGE_NAME%
    
    set FULL_IMAGE_NAME=!DOCKER_USERNAME!/!DOCKER_REPO!
    
    echo.
    echo Authenticating with Docker Hub...
    echo !DOCKER_PASSWORD! | docker login --username !DOCKER_USERNAME! --password-stdin
    
    if !ERRORLEVEL! neq 0 (
        echo ERROR: Docker Hub authentication failed
        exit /b 1
    )
    
    echo Docker Hub authentication successful
) else (
    echo ERROR: Invalid choice. Please select 1 or 2.
    exit /b 1
)

REM Prompt for image tag
echo.
set /p IMAGE_TAG="Enter image tag (default: latest): "
if "!IMAGE_TAG!"=="" set IMAGE_TAG=latest

REM Sanitize tag (lowercase, hyphenate, trim hyphens)
powershell -Command "$tag='!IMAGE_TAG!'; $tag=$tag.ToLower(); $tag=$tag -replace '[^a-z0-9.-]+','-'; $tag=$tag.Trim('-'); Write-Host $tag" > temp_tag.txt
set /p IMAGE_TAG=<temp_tag.txt
del temp_tag.txt

REM Build full image name with tag
set FULL_IMAGE_WITH_TAG=!FULL_IMAGE_NAME!:!IMAGE_TAG!

echo.
echo ==========================================
echo Building Docker Image
echo ==========================================
echo Image: !FULL_IMAGE_WITH_TAG!
echo.

REM Build the Docker image
docker build -f Dockerfile -t "!FULL_IMAGE_WITH_TAG!" .

if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker build failed
    exit /b 1
)

echo.
echo Docker build completed successfully

echo.
echo ==========================================
echo Pushing Docker Image
echo ==========================================
echo Pushing: !FULL_IMAGE_WITH_TAG!
echo.

REM Push the Docker image
docker push "!FULL_IMAGE_WITH_TAG!"

if !ERRORLEVEL! neq 0 (
    echo ERROR: Docker push failed
    exit /b 1
)

echo.
echo ==========================================
echo Build and Push Completed Successfully
echo ==========================================
echo Image: !FULL_IMAGE_WITH_TAG!
echo.
echo Next Steps:
echo 1. Update ECS task definition with this image URI
echo 2. Run deploy-image.bat to deploy to AWS ECS
echo.

endlocal
