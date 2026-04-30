using BankDatabaseAccess.DatabaseOperation;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.Windows.Forms;
using Amazon.SQS;
using Amazon.SQS.Model;

namespace BankManagementSystem.EmployeeDashboardForms
{
    public partial class CustomerInfo : Form
    {
        private readonly IAmazonSQS _sqsClient;
        
        // Replace MSMQ with Amazon SQS (Blockers 5, 6: cr-dotnet-0043)
        private readonly string _queueUrl;

        public CustomerInfo()
        {
            InitializeComponent();
            
            // Initialize AWS SQS client
            _sqsClient = new AmazonSQSClient();
            
            // Get SQS queue URL from environment variable
            _queueUrl = Environment.GetEnvironmentVariable("SQS_CUSTOMER_INFO_QUEUE_URL") 
                ?? "https://sqs.us-east-1.amazonaws.com/123456789012/customer-info-queue";
            
            // Replace MSMQ MessageQueue.Send with Amazon SQS (Blockers 5, 6: cr-dotnet-0043)
            SendToSQSAsync("viewed").Wait();
        }

        // Replace MSMQ MessageQueue.Send with Amazon SQS (Blockers 5, 6: cr-dotnet-0043)
        private async Task SendToSQSAsync(string messageBody)
        {
            try
            {
                var sendMessageRequest = new SendMessageRequest
                {
                    QueueUrl = _queueUrl,
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
                                StringValue = "CustomerInfoViewed"
                            }
                        }
                    }
                };

                await _sqsClient.SendMessageAsync(sendMessageRequest);
            }
            catch (Exception ex)
            {
                // Handle SQS errors gracefully
                // Don't block UI initialization if queue send fails
            }
        }
    }
}
