using BankDatabaseAccess.DatabaseOperation;
using BankDatabaseAccess.EntityModel;
using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using System.Windows.Forms;
using Amazon.S3;
using Amazon.S3.Model;
using Amazon.SQS;
using Amazon.SQS.Model;

namespace BankManagementSystem.Dashboard_Forms
{
    public partial class Tansfer : Form
    {
        private readonly PersonModel sender;
        private readonly PersonModel receiver = new CustomerModel();
        private readonly IAmazonSQS _sqsClient;
        private readonly IAmazonS3 _s3Client;

        // Replace MSMQ with Amazon SQS (Blockers 3, 4: cr-dotnet-0043)
        private readonly string _auditQueueUrl;

        public Tansfer(PersonModel customer)
        {
            sender = customer;
            InitializeComponent();

            // Initialize AWS clients
            _sqsClient = new AmazonSQSClient();
            _s3Client = new AmazonS3Client();

            // Get SQS queue URL from environment variable
            _auditQueueUrl = Environment.GetEnvironmentVariable("SQS_TRANSFER_QUEUE_URL") 
                ?? "https://sqs.us-east-1.amazonaws.com/123456789012/transfer-audit-queue";
        }

        private async void TransferBtn_Click(object senderObj, EventArgs e)
        {
            // Replace MSMQ with Amazon SQS (Blockers 3, 4: cr-dotnet-0043)
            await SendToSQSAsync("transfer");

            // Replace hard-coded path with S3 (Blockers 8, 11, 14: cr-dotnet-0001, cr-dotnet-0002, cr-dotnet-0003)
            // Replace DateTime.Now with UTC (Blocker 19: cr-dotnet-0121)
            await WriteTransferStateToS3Async();
        }

        // Replace MSMQ MessageQueue.Send with Amazon SQS (Blockers 3, 4: cr-dotnet-0043)
        private async Task SendToSQSAsync(string messageBody)
        {
            try
            {
                var sendMessageRequest = new SendMessageRequest
                {
                    QueueUrl = _auditQueueUrl,
                    MessageBody = messageBody,
                    MessageAttributes = new Dictionary<string, MessageAttributeValue>
                    {
                        {
                            "Timestamp",
                            new MessageAttributeValue
                            {
                                DataType = "String",
                                StringValue = DateTimeOffset.UtcNow.ToString("O")
                            }
                        },
                        {
                            "EventType",
                            new MessageAttributeValue
                            {
                                DataType = "String",
                                StringValue = "Transfer"
                            }
                        }
                    }
                };

                await _sqsClient.SendMessageAsync(sendMessageRequest);
            }
            catch (Exception ex)
            {
                // Handle SQS errors gracefully
                MessageBox.Show($"Failed to send audit message: {ex.Message}", "Warning", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        // Replace File.WriteAllText with S3 (Blockers 8, 11, 14, 19: cr-dotnet-0001, cr-dotnet-0002, cr-dotnet-0003, cr-dotnet-0121)
        private async Task WriteTransferStateToS3Async()
        {
            try
            {
                // Get S3 bucket name from environment variable
                string bucketName = Environment.GetEnvironmentVariable("S3_STATE_BUCKET") ?? "bank-app-state";
                
                // Use DateTimeOffset.UtcNow instead of DateTime.Now (Blocker 19: cr-dotnet-0121)
                string stateKey = $"transfer-state/transfer-{DateTimeOffset.UtcNow:yyyyMMddHHmmss}.txt";
                string stateContent = DateTimeOffset.UtcNow.ToString("O");

                var putRequest = new PutObjectRequest
                {
                    BucketName = bucketName,
                    Key = stateKey,
                    ContentBody = stateContent,
                    ContentType = "text/plain"
                };

                await _s3Client.PutObjectAsync(putRequest);
            }
            catch (Exception ex)
            {
                // Handle S3 errors gracefully
                MessageBox.Show($"Failed to write transfer state: {ex.Message}", "Warning", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }
    }
}
