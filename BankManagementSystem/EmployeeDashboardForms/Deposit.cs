using BankDatabaseAccess.DatabaseOperation;
using BankDatabaseAccess.EntityModel;
using System;
using System.IO;
using System.Threading.Tasks;
using System.Windows.Forms;
using Amazon.S3;
using Amazon.S3.Model;

namespace BankManagementSystem.EmployeeDashboardForms
{
    public partial class Deposit : Form
    {
        // Removed static state - stateful coupling (cloud)
        // private static decimal LastDepositAmount;
        
        private readonly IAmazonS3 _s3Client;

        public Deposit()
        {
            InitializeComponent();
            
            // Initialize AWS S3 client
            _s3Client = new AmazonS3Client();
        }

        private async void DepositBtn_Click(object sender, EventArgs e)
        {
            decimal lastDepositAmount;
            decimal.TryParse(AmountTextBox.Text, out lastDepositAmount);

            // Replace hard-coded path with S3 (Blockers 9, 12, 15: cr-dotnet-0001, cr-dotnet-0002, cr-dotnet-0003)
            await WriteDepositCacheToS3Async(lastDepositAmount);
        }

        // Replace File.WriteAllText with S3 (Blockers 9, 12, 15: cr-dotnet-0001, cr-dotnet-0002, cr-dotnet-0003)
        private async Task WriteDepositCacheToS3Async(decimal amount)
        {
            try
            {
                // Get S3 bucket name from environment variable
                string bucketName = Environment.GetEnvironmentVariable("S3_CACHE_BUCKET") ?? "bank-app-cache";
                string cacheKey = $"deposit-cache/last-{DateTimeOffset.UtcNow:yyyyMMdd}.txt";

                var putRequest = new PutObjectRequest
                {
                    BucketName = bucketName,
                    Key = cacheKey,
                    ContentBody = amount.ToString(),
                    ContentType = "text/plain"
                };

                await _s3Client.PutObjectAsync(putRequest);
            }
            catch (Exception ex)
            {
                // Handle S3 errors gracefully
                MessageBox.Show($"Failed to write deposit cache: {ex.Message}", "Warning", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }
    }
}
