# WHMCS-Cron-Deployer Manager

WHMCS-Cron-Deployer Manager is a comprehensive solution for managing WHMCS cron jobs with enhanced monitoring and notification capabilities. This script sets up necessary cron jobs based on your control panel and system preferences, ensuring optimal performance and ease of management.

## Features

- Automated setup of WHMCS cron jobs.
- Supports Plesk, cPanel, and FastPanel.
- Optional Telegram and Slack notifications for monitoring cron job success and errors.
- Enhanced logging and error handling.

## Prerequisites

- WHMCS installation with access to the cron directory.
- PHP installed on the server (PHP 8.1 recommended).
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
