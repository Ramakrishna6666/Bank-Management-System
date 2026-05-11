using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Windows.Forms;
using BankDatabaseAccess;

namespace BankManagementSystem
{
    static class Program
    {
        private static HealthCheckService _healthCheckService;

        /// <summary>
        /// The main entry point for the application.
        /// </summary>
        [STAThread]
        static void Main()
        {
            // Start health check endpoint for containerization
            _healthCheckService = new HealthCheckService();
            _healthCheckService.Start();

            // Register cleanup on application exit
            Application.ApplicationExit += OnApplicationExit;

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new WelcomeUI());
        }

        private static void OnApplicationExit(object sender, EventArgs e)
        {
            _healthCheckService?.Stop();
            _healthCheckService?.Dispose();
        }
    }
}
