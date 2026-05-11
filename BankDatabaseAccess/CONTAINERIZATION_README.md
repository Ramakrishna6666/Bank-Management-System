# BankDatabaseAccess - Containerization Changes

## Overview
This module has been updated to support containerization by replacing Web.config/App.config-based configuration with environment variables.

## Changes Made

### 1. Database Connection Configuration (blocker-1: cz-dotnet-0055)
**File**: `DatabaseConnection.cs` (Line 12)

**Before**:
```csharp
public static readonly string Connection = System.Configuration.ConfigurationManager.ConnectionStrings["OpenBankLocal"].ConnectionString;
```

**After**:
The connection string is now built from environment variables using the `GetConnectionString()` method.

### 2. Health Check Endpoint (Containerization Requirement)
**File**: `HealthCheckService.cs` (New)

A simple HTTP-based health check endpoint has been added for container orchestration platforms.

## Environment Variables

### Database Configuration

You can configure the database connection using either:

#### Option 1: Single Connection String
- `DB_CONNECTION_STRING`: Complete SQL Server connection string

#### Option 2: Individual Components
- `DB_HOST`: Database server hostname or IP (default: ".")
- `DB_NAME`: Database name (default: "OpenBankLocal")
- `DB_INTEGRATED_SECURITY`: Use Windows Authentication (default: "True")
- `DB_USER`: Database username (required if DB_INTEGRATED_SECURITY=False)
- `DB_PASSWORD`: Database password (required if DB_INTEGRATED_SECURITY=False)

### Health Check Configuration
- `HEALTH_CHECK_PORT`: Port for health check endpoint (default: 8080)

## Example Docker Environment Variables

```dockerfile
ENV DB_HOST=sqlserver.example.com
ENV DB_NAME=OpenBankLocal
ENV DB_INTEGRATED_SECURITY=False
ENV DB_USER=bankapp_user
ENV DB_PASSWORD=SecurePassword123
ENV HEALTH_CHECK_PORT=8080
```

## Example Kubernetes ConfigMap/Secret

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: bank-database-config
data:
  DB_HOST: "sqlserver.svc.cluster.local"
  DB_NAME: "OpenBankLocal"
  DB_INTEGRATED_SECURITY: "False"
  HEALTH_CHECK_PORT: "8080"
---
apiVersion: v1
kind: Secret
metadata:
  name: bank-database-secret
type: Opaque
stringData:
  DB_USER: "bankapp_user"
  DB_PASSWORD: "SecurePassword123"
```

## Health Check Endpoint

### Usage
To enable the health check endpoint in your application, instantiate and start the `HealthCheckService`:

```csharp
using BankDatabaseAccess;

var healthCheckService = new HealthCheckService();
healthCheckService.Start();

// Your application code here...

// When shutting down:
healthCheckService.Stop();
healthCheckService.Dispose();
```

### Endpoint Details
- **URL**: `http://localhost:8080/health` (or custom port via HEALTH_CHECK_PORT)
- **Method**: GET
- **Response Format**: JSON

**Healthy Response** (HTTP 200):
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

**Unhealthy Response** (HTTP 503):
```json
{
  "status": "unhealthy",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

## AWS Systems Manager Parameter Store Integration

For production deployments on AWS, you can store configuration in AWS Systems Manager Parameter Store:

```bash
# Store database configuration
aws ssm put-parameter --name /bankapp/db/host --value "sqlserver.example.com" --type String
aws ssm put-parameter --name /bankapp/db/name --value "OpenBankLocal" --type String
aws ssm put-parameter --name /bankapp/db/user --value "bankapp_user" --type String
aws ssm put-parameter --name /bankapp/db/password --value "SecurePassword123" --type SecureString
```

Then in your container startup script or ECS task definition, retrieve and set environment variables:

```bash
export DB_HOST=$(aws ssm get-parameter --name /bankapp/db/host --query Parameter.Value --output text)
export DB_NAME=$(aws ssm get-parameter --name /bankapp/db/name --query Parameter.Value --output text)
export DB_USER=$(aws ssm get-parameter --name /bankapp/db/user --query Parameter.Value --output text)
export DB_PASSWORD=$(aws ssm get-parameter --name /bankapp/db/password --with-decryption --query Parameter.Value --output text)
```

## Migration Notes

1. **Backward Compatibility**: The old App.config file is still present but no longer used by DatabaseConnection.cs
2. **Default Values**: If environment variables are not set, the application uses sensible defaults (localhost, integrated security)
3. **Security**: Never hardcode credentials in code or configuration files. Always use environment variables or secrets management systems
4. **Container Orchestration**: The health check endpoint enables proper health monitoring in Kubernetes, ECS, or other container platforms

## Testing Locally

To test with environment variables locally:

### Windows (PowerShell)
```powershell
$env:DB_HOST="localhost"
$env:DB_NAME="OpenBankLocal"
$env:DB_INTEGRATED_SECURITY="True"
$env:HEALTH_CHECK_PORT="8080"
```

### Windows (Command Prompt)
```cmd
set DB_HOST=localhost
set DB_NAME=OpenBankLocal
set DB_INTEGRATED_SECURITY=True
set HEALTH_CHECK_PORT=8080
```

### Linux/Mac
```bash
export DB_HOST=localhost
export DB_NAME=OpenBankLocal
export DB_INTEGRATED_SECURITY=True
export HEALTH_CHECK_PORT=8080
```
