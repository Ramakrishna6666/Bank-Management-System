# Multi-stage Dockerfile for BankManagementSystem (.NET 8.0 Windows Forms Application)
# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS builder

WORKDIR /src

# Copy solution file
COPY BankManagementSystem.sln ./

# Copy project files for dependency caching
COPY BankDatabaseAccess/BankDatabaseAccess.csproj ./BankDatabaseAccess/
COPY BankManagementSystem/BankManagementSystem.csproj ./BankManagementSystem/

# Restore dependencies
RUN dotnet restore BankManagementSystem.sln

# Copy all source code
COPY BankDatabaseAccess/ ./BankDatabaseAccess/
COPY BankManagementSystem/ ./BankManagementSystem/

# Build the application
WORKDIR /src/BankManagementSystem
RUN dotnet build -c Release --no-restore

# Publish the application
RUN dotnet publish -c Release -o /app/publish --no-build

# Runtime stage
FROM mcr.microsoft.com/dotnet/runtime:8.0

# Create non-root user for security
RUN groupadd -r bankapp && useradd -r -g bankapp bankapp

WORKDIR /app

# Copy published application from builder stage
COPY --from=builder /app/publish .

# Set ownership to non-root user
RUN chown -R bankapp:bankapp /app

# Switch to non-root user
USER bankapp

# Set environment variables
ENV DOTNET_ENVIRONMENT=Production \
    HEALTH_CHECK_PORT=8080 \
    TZ=UTC \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false

# Expose health check port
EXPOSE 8080

# Set the entry point
ENTRYPOINT ["dotnet", "BankManagementSystem.dll"]
