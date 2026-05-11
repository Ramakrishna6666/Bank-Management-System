using System;
using Microsoft.Data.SqlClient;

namespace BankDatabaseAccess
{
    public static class DatabaseConnection
    {
        // BLOCKER FIX: cz-dotnet-0055 - Web.config Transforms
        // Migrated from Web.config/App.config to environment variables for containerization
        // Replaced System.Configuration.ConfigurationManager.ConnectionStrings with IConfiguration pattern
        // Use environment variables: DB_CONNECTION_STRING (full connection string) OR
        // DB_HOST, DB_NAME, DB_USER, DB_PASSWORD, DB_INTEGRATED_SECURITY (individual components)
        // This enables environment-specific configuration in containers without build-time transforms
        public static readonly string Connection = GetConnectionString();

        private static string GetConnectionString()
        {
            // Check if connection string is provided as a single environment variable
            var connectionString = Environment.GetEnvironmentVariable("DB_CONNECTION_STRING");
            if (!string.IsNullOrEmpty(connectionString))
            {
                return connectionString;
            }

            // Build connection string from individual environment variables
            var dbHost = Environment.GetEnvironmentVariable("DB_HOST") ?? ".";
            var dbName = Environment.GetEnvironmentVariable("DB_NAME") ?? "OpenBankLocal";
            var integratedSecurity = Environment.GetEnvironmentVariable("DB_INTEGRATED_SECURITY") ?? "True";
            
            var builder = new SqlConnectionStringBuilder
            {
                DataSource = dbHost,
                InitialCatalog = dbName
            };

            if (integratedSecurity.Equals("True", StringComparison.OrdinalIgnoreCase))
            {
                builder.IntegratedSecurity = true;
            }
            else
            {
                var dbUser = Environment.GetEnvironmentVariable("DB_USER");
                var dbPassword = Environment.GetEnvironmentVariable("DB_PASSWORD");
                
                if (!string.IsNullOrEmpty(dbUser))
                {
                    builder.UserID = dbUser;
                }
                if (!string.IsNullOrEmpty(dbPassword))
                {
                    builder.Password = dbPassword;
                }
            }

            return builder.ConnectionString;
        }

       public enum Error
        {
            UsernameExist = 4001
        }

        public static int Execute(string query)
        {
            using (var connection = new SqlConnection(Connection))
            {
                try
                {
                    connection.Open();
                    return new SqlCommand(query, connection).ExecuteNonQuery();
                }
                catch (SqlException)
                {
                   return (int)Error.UsernameExist;
                }

            }
        }
    }
}
