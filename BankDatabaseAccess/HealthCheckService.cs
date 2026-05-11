using System;
using System.Net;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace BankDatabaseAccess
{
    /// <summary>
    /// Simple HTTP health check endpoint for containerization
    /// Listens on the port specified by HEALTH_CHECK_PORT environment variable (default: 8080)
    /// Responds to GET /health with JSON status
    /// </summary>
    public class HealthCheckService : IDisposable
    {
        private HttpListener _listener;
        private CancellationTokenSource _cancellationTokenSource;
        private Task _listenerTask;
        private readonly int _port;

        public HealthCheckService()
        {
            var portString = Environment.GetEnvironmentVariable("HEALTH_CHECK_PORT");
            _port = int.TryParse(portString, out var port) ? port : 8080;
        }

        public void Start()
        {
            if (_listener != null)
            {
                return; // Already started
            }

            _listener = new HttpListener();
            _listener.Prefixes.Add($"http://+:{_port}/");
            _cancellationTokenSource = new CancellationTokenSource();

            try
            {
                _listener.Start();
                _listenerTask = Task.Run(() => ListenAsync(_cancellationTokenSource.Token));
                Console.WriteLine($"Health check endpoint started on port {_port}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Failed to start health check endpoint: {ex.Message}");
            }
        }

        private async Task ListenAsync(CancellationToken cancellationToken)
        {
            while (!cancellationToken.IsCancellationRequested && _listener.IsListening)
            {
                try
                {
                    var context = await _listener.GetContextAsync();
                    await HandleRequestAsync(context);
                }
                catch (HttpListenerException)
                {
                    // Listener was stopped
                    break;
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Error handling health check request: {ex.Message}");
                }
            }
        }

        private async Task HandleRequestAsync(HttpListenerContext context)
        {
            var request = context.Request;
            var response = context.Response;

            // Only respond to /health endpoint
            if (request.Url.AbsolutePath.Equals("/health", StringComparison.OrdinalIgnoreCase))
            {
                var healthStatus = CheckHealth();
                var responseString = $"{{\"status\":\"{healthStatus.Status}\",\"timestamp\":\"{DateTime.UtcNow:O}\"}}";
                var buffer = Encoding.UTF8.GetBytes(responseString);

                response.ContentType = "application/json";
                response.ContentLength64 = buffer.Length;
                response.StatusCode = healthStatus.IsHealthy ? 200 : 503;

                await response.OutputStream.WriteAsync(buffer, 0, buffer.Length);
                response.OutputStream.Close();
            }
            else
            {
                response.StatusCode = 404;
                response.Close();
            }
        }

        private HealthStatus CheckHealth()
        {
            try
            {
                // Check if database connection string is configured
                var connectionString = DatabaseConnection.Connection;
                if (string.IsNullOrEmpty(connectionString))
                {
                    return new HealthStatus { Status = "unhealthy", IsHealthy = false };
                }

                // Optionally, you could test the database connection here
                // For now, just check if the connection string is available
                return new HealthStatus { Status = "healthy", IsHealthy = true };
            }
            catch (Exception)
            {
                return new HealthStatus { Status = "unhealthy", IsHealthy = false };
            }
        }

        public void Stop()
        {
            if (_listener != null && _listener.IsListening)
            {
                _cancellationTokenSource?.Cancel();
                _listener.Stop();
                _listenerTask?.Wait(TimeSpan.FromSeconds(5));
                Console.WriteLine("Health check endpoint stopped");
            }
        }

        public void Dispose()
        {
            Stop();
            _listener?.Close();
            _cancellationTokenSource?.Dispose();
        }

        private class HealthStatus
        {
            public string Status { get; set; }
            public bool IsHealthy { get; set; }
        }
    }
}
