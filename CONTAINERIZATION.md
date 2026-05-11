# Containerization Configuration Guide

## Overview
This application has been configured for containerization with environment-based configuration instead of Web.config/App.config transforms.

## Environment Variables

### Database Configuration
The application supports two methods for database configuration:

#### Method 1: Full Connection String
```
DB_CONNECTION_STRING=Data Source=sqlserver;Initial Catalog=OpenBankLocal;User ID=sa;Password=YourPassword
```

#### Method 2: Individual Components
```
DB_HOST=sqlserver
DB_NAME=OpenBankLocal
DB_USER=sa
DB_PASSWORD=YourPassword
DB_INTEGRATED_SECURITY=False
```

**Default Values (if not specified):**
- `DB_HOST`: `.` (local instance)
- `DB_NAME`: `OpenBankLocal`
- `DB_INTEGRATED_SECURITY`: `True`

### Health Check Configuration
```
HEALTH_CHECK_PORT=8080
```

**Default Value:** `8080`

## Health Check Endpoint

The application exposes a health check endpoint for container orchestration:

- **URL:** `http://localhost:8080/health`
- **Method:** GET
- **Response Format:** JSON

**Healthy Response (200 OK):**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-01T12:00:00Z"
}
```

**Unhealthy Response (503 Service Unavailable):**
```json
{
  "status": "unhealthy",
  "timestamp": "2024-01-01T12:00:00Z"
}
```

## Docker Example

### Dockerfile
```dockerfile
FROM mcr.microsoft.com/dotnet/framework/runtime:4.7.2-windowsservercore-ltsc2019
WORKDIR /app
COPY . .

# Set environment variables
ENV DB_HOST=sqlserver
ENV DB_NAME=OpenBankLocal
ENV DB_USER=sa
ENV DB_PASSWORD=YourPassword
ENV DB_INTEGRATED_SECURITY=False
ENV HEALTH_CHECK_PORT=8080

EXPOSE 8080

ENTRYPOINT ["BankManagementSystem.exe"]
```

### Docker Compose
```yaml
version: '3.8'
services:
  bank-app:
    build: .
    environment:
      - DB_HOST=sqlserver
      - DB_NAME=OpenBankLocal
      - DB_USER=sa
      - DB_PASSWORD=YourPassword
      - DB_INTEGRATED_SECURITY=False
      - HEALTH_CHECK_PORT=8080
    ports:
      - "8080:8080"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

## Kubernetes Example

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bank-management-system
spec:
  replicas: 2
  selector:
    matchLabels:
      app: bank-app
  template:
    metadata:
      labels:
        app: bank-app
    spec:
      containers:
      - name: bank-app
        image: bank-management-system:latest
        ports:
        - containerPort: 8080
        env:
        - name: DB_HOST
          value: "sqlserver.default.svc.cluster.local"
        - name: DB_NAME
          value: "OpenBankLocal"
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
        - name: DB_INTEGRATED_SECURITY
          value: "False"
        - name: HEALTH_CHECK_PORT
          value: "8080"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
```

## AWS Systems Manager Parameter Store Integration

For production deployments on AWS, you can integrate with AWS Systems Manager Parameter Store:

1. Store sensitive configuration in Parameter Store:
   ```bash
   aws ssm put-parameter --name /bank-app/db-host --value "sqlserver.example.com" --type String
   aws ssm put-parameter --name /bank-app/db-name --value "OpenBankLocal" --type String
   aws ssm put-parameter --name /bank-app/db-user --value "sa" --type SecureString
   aws ssm put-parameter --name /bank-app/db-password --value "YourPassword" --type SecureString
   ```

2. Use ECS task definition or EC2 user data to retrieve and set environment variables:
   ```bash
   export DB_HOST=$(aws ssm get-parameter --name /bank-app/db-host --query Parameter.Value --output text)
   export DB_NAME=$(aws ssm get-parameter --name /bank-app/db-name --query Parameter.Value --output text)
   export DB_USER=$(aws ssm get-parameter --name /bank-app/db-user --with-decryption --query Parameter.Value --output text)
   export DB_PASSWORD=$(aws ssm get-parameter --name /bank-app/db-password --with-decryption --query Parameter.Value --output text)
   ```

## Migration Notes

### Blocker Fixed: cz-dotnet-0055 - Web.config Transforms

**Original Issue:**
- Application used `System.Configuration.ConfigurationManager.ConnectionStrings["OpenBankLocal"].ConnectionString`
- This relied on Web.config/App.config with build-time XDT transforms
- Not compatible with containerization where configuration must be runtime-based

**Solution Applied:**
- Replaced static configuration with environment variable-based configuration
- Connection string is now built at runtime from environment variables
- Supports both full connection string and individual component configuration
- Maintains backward compatibility with default values

**Files Modified:**
- `BankDatabaseAccess/DatabaseConnection.cs` - Line 12 and surrounding code
- `BankManagementSystem/Program.cs` - Added health check service initialization

## Testing

### Local Testing
1. Set environment variables in your development environment
2. Run the application
3. Verify health check endpoint: `curl http://localhost:8080/health`
4. Verify database connectivity

### Container Testing
1. Build the Docker image
2. Run with environment variables
3. Check health endpoint
4. Verify application functionality

## Security Considerations

1. **Never hardcode credentials** - Always use environment variables or secrets management
2. **Use Integrated Security** when possible in trusted environments
3. **Encrypt sensitive environment variables** in production
4. **Use AWS Secrets Manager or Parameter Store** for production deployments
5. **Rotate credentials regularly**
6. **Limit network access** to database servers
7. **Use TLS/SSL** for database connections in production

## Troubleshooting

### Health Check Returns Unhealthy
- Verify database connection string is correctly configured
- Check if database server is accessible
- Review application logs for connection errors

### Application Cannot Connect to Database
- Verify all required environment variables are set
- Check database server hostname/IP is correct
- Ensure database credentials are valid
- Verify network connectivity to database server
- Check firewall rules

### Health Check Endpoint Not Accessible
- Verify `HEALTH_CHECK_PORT` environment variable
- Check if port is exposed in container configuration
- Ensure no firewall blocking the port
- Verify application started successfully
