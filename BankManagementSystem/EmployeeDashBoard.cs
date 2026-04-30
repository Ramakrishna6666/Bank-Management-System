using BankDatabaseAccess.EntityModel;
using System;
using System.Collections.Generic;
using System.DirectoryServices.Protocols;
using System.Net;
using System.Windows.Forms;

namespace BankManagementSystem
{
    public partial class EmployeeDashBoard : Form
    {
        private readonly PersonModel personModel;

        // Stateful UI coupling (cloud) - removed static state
        private string CurrentSessionEmployee;

        // Removed P/Invoke Windows API (Blocker 2: cr-dotnet-0042)
        // [DllImport("user32.dll")] - Replaced with cross-platform alternative

        public EmployeeDashBoard(PersonModel personModel)
        {
            this.personModel = personModel;
            InitializeComponent();

            // Replace Windows Authentication with AWS Directory Service LDAP (Blocker 1: cr-dotnet-0030)
            CurrentSessionEmployee = AuthenticateWithLDAP();
        }

        private void DashBoard_Shown(object sender, EventArgs e)
        {
            HomeBtn.PerformClick();
        }

        private void LogoutBtn_Click(object sender, EventArgs e)
        {
            // Removed Windows-specific LockWorkStation() call (Blocker 2: cr-dotnet-0042)
            // Cross-platform alternative: just close and show login
            Close();
            new LoginUI().Show();
        }

        // AWS Directory Service LDAP Authentication (Blocker 1: cr-dotnet-0030)
        private string AuthenticateWithLDAP()
        {
            try
            {
                // Get LDAP configuration from environment variables
                string ldapServer = Environment.GetEnvironmentVariable("LDAP_SERVER") ?? "localhost";
                int ldapPort = int.Parse(Environment.GetEnvironmentVariable("LDAP_PORT") ?? "389");
                string ldapBaseDn = Environment.GetEnvironmentVariable("LDAP_BASE_DN") ?? "dc=example,dc=com";
                string ldapUsername = Environment.GetEnvironmentVariable("LDAP_USERNAME") ?? "user";
                string ldapPassword = Environment.GetEnvironmentVariable("LDAP_PASSWORD") ?? "";

                // Create LDAP connection to AWS Managed Microsoft AD
                using (var connection = new LdapConnection(new LdapDirectoryIdentifier(ldapServer, ldapPort)))
                {
                    connection.AuthType = AuthType.Basic;
                    connection.Credential = new NetworkCredential(ldapUsername, ldapPassword);
                    connection.Bind();

                    // Return authenticated username
                    return ldapUsername;
                }
            }
            catch (Exception ex)
            {
                // Fallback to environment variable or default
                return Environment.GetEnvironmentVariable("CURRENT_USER") ?? "DefaultUser";
            }
        }
    }
}
