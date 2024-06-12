# WHMCS-Cron-Deployer Manager

WHMCS-Cron-Deployer Manager is a comprehensive solution for managing WHMCS cron jobs with enhanced monitoring and notification capabilities. This script sets up necessary cron jobs based on your control panel and system preferences, ensuring optimal performance and ease of management.

## Features

- Automated setup of WHMCS cron jobs.
- Supports Plesk, cPanel, and FastPanel.
- Optional Telegram and Slack notifications for monitoring cron job success and errors.
- Enhanced logging and error handling.

## Cron Job Setup
- *Main System Cron Job:* Runs every 5 minutes to ensure regular execution of WHMCS automation tasks, excluding specific tasks that are handled separately for better control.
- *Ticket Escalations:* Ensures timely responses to support tickets during business hours on weekdays.
- *Auto Suspensions:* Manages unpaid services by suspending them daily on weekdays.
- *Process Email Queue:* Sends scheduled emails every 5 minutes to ensure timely communication with clients.
- *Email Campaigns:* Updates and schedules email campaigns for marketing purposes.
- *WHMCS Software Updates:* Checks for software updates every 8 hours to keep the system up-to-date.
- *Domain Status Sync:* Ensures accurate domain information by syncing domain status hourly.
- *Server Remote Meta Data:* Updates server metadata hourly for accurate server information.
- *Database Backup:* Creates daily backups of the WHMCS database for data recovery purposes.
- *Overage Billing:* Processes overage billing charges monthly to bill clients for usage exceeding their plan limits.
- *Affiliate Reports:* Sends monthly affiliate reports to keep affiliates informed about their earnings.
- *Process Credit Card Payments:* Processes daily credit card payments to ensure timely collection of payments.
- *Auto Prune Ticket Attachments:* Removes inactive ticket attachments hourly to manage disk space.
- *Currency Exchange Rates Update:* Updates currency exchange rates daily to ensure accurate pricing.
- *Invoice Reminders:* Sends daily reminders for unpaid and overdue invoices to improve cash flow.
- *Domain Renewal Notices:* Sends daily domain renewal notices to inform clients about upcoming expirations.
- *Fixed Term Terminations:* Processes daily terminations for services with a fixed term.

## Prerequisites

- WHMCS installation with access to the cron directory.
- PHP installed Path on the server
- Control panel access (Plesk, cPanel, or FastPanel).
- Optional: Telegram Bot Token and Chat ID for notifications.
- Optional: Slack Webhook URL for notifications.

----

## Usage

### Clone the Repository

```bash
git clone --depth 1 https://github.com/yashodhank/WHMCS-Cron-Deployer.git
cd WHMCS-Cron-Deployer
```

### Make the Script Executable

```bash
chmod +x setup_whmcs_cron.sh
```

### Run the Script

```bash
./setup_whmcs_cron.sh
```

Alternatively, you can pass arguments directly to the script:

```bash
./setup_whmcs_cron.sh <cron_dir> <php_path> <user> <control_panel> [telegram_bot_token] [telegram_chat_id] [slack_webhook_url]
```

- `cron_dir`: The WHMCS cron directory path.
- `php_path`: The PHP executable path.
- `user`: The system user.
- `control_panel`: The control panel in use (Plesk, cPanel, FastPanel).
- `telegram_bot_token` (optional): Your Telegram Bot Token for notifications.
- `telegram_chat_id` (optional): Your Telegram Chat ID for notifications.
- `slack_webhook_url` (optional): Your Slack Webhook URL for notifications.

### Example

```bash
./setup_whmcs_cron.sh /var/www/my_whmcs_usr/Private/cron /usr/bin/php8.1 myuser Plesk your_bot_token your_chat_id your_slack_webhook_url
```
----

### Repository Structure

```
WHMCS-Cron-Manager/
├── LICENSE
├── README.md
├── setup_whmcs_cron.sh
```

## Monitoring and Notifications

If Telegram and Slack credentials are provided, the script will set up monitoring to send detailed notifications to the specified channels.

### Monitoring Script

The monitoring script checks the WHMCS cron log for errors and notifies the sys admin if any issues are detected. It also ensures that cron jobs are running successfully.

## Contributing

Contributions are welcome! Please fork the repository and submit a pull request with your improvements.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
