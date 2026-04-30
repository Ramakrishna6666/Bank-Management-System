using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;

namespace BankDatabaseAccess
{
    public static class DatabaseConnection
    {
        // Replace Web.config with environment variable (Blocker 20: cr-dotnet-0010)
        // Use RDS Proxy connection string from environment (Blocker 16: cr-dotnet-0013)
        public static readonly string Connection = Environment.GetEnvironmentVariable("DATABASE_CONNECTION_STRING") 
            ?? System.Configuration.ConfigurationManager.ConnectionStrings["OpenBankLocal"]?.ConnectionString 
            ?? "Server=localhost;Database=BankDB;Integrated Security=true;";

       public enum Error
        {
            UsernameExist = 4001
        }

        // Replaced direct SqlConnection with connection pooling pattern (Blocker 16: cr-dotnet-0013)
        // This method is kept for backward compatibility but should use DbContext in production
        public static int Execute(string query)
        {
            // Use connection pooling by default in SqlConnection
            // For RDS Proxy, configure connection string with appropriate pooling settings
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

        // New method to get DbContextOptions for Entity Framework Core with RDS Proxy
        public static DbContextOptions<TContext> GetDbContextOptions<TContext>() where TContext : DbContext
        {
            var optionsBuilder = new DbContextOptionsBuilder<TContext>();
            optionsBuilder.UseSqlServer(Connection, sqlServerOptions =>
            {
                sqlServerOptions.EnableRetryOnFailure(
                    maxRetryCount: 5,
                    maxRetryDelay: TimeSpan.FromSeconds(30),
                    errorNumbersToAdd: null);
            });
            return optionsBuilder.Options;
        }
    }
}
