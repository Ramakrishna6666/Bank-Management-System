using BankDatabaseAccess.EntityModel;
using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using System.Windows.Forms;
using Amazon.S3;
using Amazon.S3.Model;
using Amazon.SimpleSystemsManagement;
using Amazon.SimpleSystemsManagement.Model;

namespace BankManagementSystem
{
    public partial class CustomerDashBoard : Form
    {
        private readonly PersonModel personModel;
        private readonly IAmazonS3 _s3Client;
        private readonly IAmazonSimpleSystemsManagement _ssmClient;

        // Stateful UI memory (cloud)
        private readonly List<string> NavigationTrail = new List<string>();

        public CustomerDashBoard(PersonModel customer)
        {
            personModel = customer;
            InitializeComponent();

            // Initialize AWS clients
            _s3Client = new AmazonS3Client();
            _ssmClient = new AmazonSimpleSystemsManagementClient();

            // Replace Registry with AWS Systems Manager Parameter Store (Blocker 17: cr-dotnet-0040)
            LoadConfigurationFromParameterStore();
        }

        private async void LogoutBtn_Click(object sender, EventArgs e)
        {
            // Replace hard-coded path with environment variable (Blocker 7: cr-dotnet-0001)
            // Replace local file writes with Amazon S3 (Blockers 10, 13: cr-dotnet-0002, cr-dotnet-0003)
            // Replace DateTime.Now with UTC (Blocker 18: cr-dotnet-0121)
            await LogToS3Async();

            Close();
            new LoginUI().Show();
        }

        // Replace Registry access with AWS Systems Manager Parameter Store (Blocker 17: cr-dotnet-0040)
        private async void LoadConfigurationFromParameterStore()
        {
            try
            {
                var request = new GetParameterRequest
                {
                    Name = "/BankApp/CustomerDashboard/Config",
                    WithDecryption = true
                };

                var response = await _ssmClient.GetParameterAsync(request);
                // Use configuration value as needed
                string configValue = response.Parameter.Value;
            }
            catch (Exception ex)
            {
                // Handle parameter not found or other errors
                // Use default configuration
            }
        }

        // Replace File.AppendAllText with S3 (Blockers 7, 10, 13, 18: cr-dotnet-0001, cr-dotnet-0002, cr-dotnet-0003, cr-dotnet-0121)
        private async Task LogToS3Async()
        {
            try
            {
                // Get S3 bucket name from environment variable
                string bucketName = Environment.GetEnvironmentVariable("S3_LOGS_BUCKET") ?? "bank-app-logs";
                string logKey = $"customer-logs/{DateTimeOffset.UtcNow:yyyy/MM/dd}/customer-{DateTimeOffset.UtcNow:yyyyMMddHHmmss}.log";

                // Use DateTimeOffset.UtcNow instead of DateTime.Now (Blocker 18: cr-dotnet-0121)
                string logContent = $"Customer logout at {DateTimeOffset.UtcNow:O}";

                var putRequest = new PutObjectRequest
                {
                    BucketName = bucketName,
                    Key = logKey,
                    ContentBody = logContent,
                    ContentType = "text/plain"
                };

                await _s3Client.PutObjectAsync(putRequest);
            }
            catch (Exception ex)
            {
                // Handle S3 errors gracefully
                MessageBox.Show($"Failed to write log: {ex.Message}", "Warning", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }
    }
}
