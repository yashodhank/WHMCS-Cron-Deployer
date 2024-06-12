#!/bin/bash

# Function to prompt for user input if not provided as an argument
prompt_input() {
    read -p "$1" input
    echo $input
}

# Function to create a cron job based on the control panel type
create_cron_job() {
    local cron_path=$1
    local php_path=$2
    local user=$3
    local cron_job=$4

    case $control_panel in
        Plesk)
            echo "$cron_job" | sudo tee -a /var/spool/cron/crontabs/$user > /dev/null
            sudo chown $user:root /var/spool/cron/crontabs/$user
            sudo chmod 600 /var/spool/cron/crontabs/$user
            ;;
        cPanel)
            echo "$cron_job" | sudo tee -a /var/spool/cron/$user > /dev/null
            sudo chown $user:root /var/spool/cron/$user
            sudo chmod 600 /var/spool/cron/$user
            ;;
        FastPanel)
            sudo su - $user -c "echo \"$cron_job\" | crontab -"
            ;;
        *)
            echo "Unsupported control panel: $control_panel"
            exit 1
            ;;
    esac
}

# Function to set up monitoring and notification
setup_monitoring() {
    local monitoring_script_path="/path/to/monitor_cron.sh"
    cat <<EOF > $monitoring_script_path
#!/bin/bash

# Paths to cron log and notification tokens/URLs
CRON_LOG="/var/log/whmcs_cron.log"
TELEGRAM_BOT_TOKEN="$telegram_bot_token"
TELEGRAM_CHAT_ID="$telegram_chat_id"
SLACK_WEBHOOK_URL="$slack_webhook_url"
HOSTNAME=\$(hostname)
SERVER_IP=\$(hostname -I | awk '{print \$1}')

# Function to send notification via Telegram and Slack
send_notification() {
    MESSAGE=\$1
    if [ -n "\$TELEGRAM_BOT_TOKEN" ] && [ -n "\$TELEGRAM_CHAT_ID" ]; then
        curl -s -X POST https://api.telegram.org/bot\$TELEGRAM_BOT_TOKEN/sendMessage -d chat_id=\$TELEGRAM_CHAT_ID -d text="\$MESSAGE"
    fi
    if [ -n "\$SLACK_WEBHOOK_URL" ]; then
        curl -s -X POST -H 'Content-type: application/json' --data "{\"text\":\"\$MESSAGE\"}" \$SLACK_WEBHOOK_URL
    fi
}

# Function to gather server details and stats
get_server_details() {
    UPTIME=\$(uptime -p)
    DISK_USAGE=\$(df -h / | grep / | awk '{print \$5}')
    MEMORY_USAGE=\$(free -m | grep Mem | awk '{printf("%.2f%%", \$3*100/\$2)}')
    LOAD_AVERAGE=\$(uptime | awk -F'[a-z]:' '{print \$2}')
    echo -e "Server Details:\nHostname: \$HOSTNAME\nIP Address: \$SERVER_IP\nUptime: \$UPTIME\nDisk Usage: \$DISK_USAGE\nMemory Usage: \$MEMORY_USAGE\nLoad Average: \$LOAD_AVERAGE"
}

# Check cron log for errors and send notifications
if grep -q "ERROR" \$CRON_LOG; then
    ERROR_MSG=\$(grep "ERROR" \$CRON_LOG | tail -1)
    CRON_HICCUP=\$(grep "ERROR" \$CRON_LOG | tail -1 | awk -F ' ' '{print \$NF}')
    SERVER_DETAILS=\$(get_server_details)
    ERROR_LOG=\$(tail -n 10 \$CRON_LOG | grep "ERROR")
    send_notification "WHMCS Cron Job Error:\n\$ERROR_MSG\nCron Path: \$CRON_HICCUP\n\n\$SERVER_DETAILS\n\nRecent Error Log:\n\$ERROR_LOG"
fi

# Check if cron jobs are running as expected
if ! tail -n 100 \$CRON_LOG | grep -q "Cron Job Completed Successfully"; then
    SERVER_DETAILS=\$(get_server_details)
    send_notification "WHMCS Cron Job Warning: No successful run detected in the last 100 log entries.\n\n\$SERVER_DETAILS"
fi
EOF

    # Make the monitoring script executable
    chmod +x $monitoring_script_path

    # Add the monitoring script to cron to run every 5 minutes
    echo "*/5 * * * * $monitoring_script_path" | sudo tee -a /var/spool/cron/crontabs/$user > /dev/null
}

# Get user input or arguments
cron_dir=${1:-$(prompt_input "Enter the WHMCS cron directory path: ")}
php_path=${2:-$(prompt_input "Enter the PHP path: ")}
user=${3:-$(prompt_input "Enter the system user: ")}
control_panel=${4:-$(prompt_input "Enter the control panel (Plesk, cPanel, FastPanel): ")}
telegram_bot_token=${5:-$(prompt_input "Enter the Telegram Bot Token (optional): ")}
telegram_chat_id=${6:-$(prompt_input "Enter the Telegram Chat ID (optional): ")}
slack_webhook_url=${7:-$(prompt_input "Enter the Slack Webhook URL (optional): ")}

# Validate required inputs
if [ -z "$cron_dir" ] || [ -z "$php_path" ] || [ -z "$user" ] || [ -z "$control_panel" ]; then
    echo "Error: Missing required inputs."
    exit 1
fi

# Define the cron jobs

# Main system cron job: Runs every 5 minutes. This job excludes Ticket Escalations, Auto Suspensions, Email Campaigns,
# and Process Email Queue tasks to be run separately. It ensures regular execution of WHMCS automation tasks.
main_cron_job="*/5 * * * * $php_path -q $cron_dir/cron.php skip --TicketEscalations --AutoSuspensions --EmailCampaigns --ProcessEmailQueue -vvv --email-report=1"

# Ticket Escalations: Runs every hour during business hours on weekdays. This job processes and escalates tickets based
# on predefined rules, ensuring timely responses to support tickets.
ticket_escalations_job="0 9,10,11,12,13,14,15,16 * * 1-5 $php_path -q $cron_dir/cron.php do --TicketEscalations -vvv --email-report=1"

# Auto Suspensions: Runs once daily on weekdays. This job processes overdue suspensions, automatically suspending
# services that are overdue, which helps in managing unpaid services.
auto_suspensions_job="0 9 * * 1-5 $php_path -q $cron_dir/cron.php do --AutoSuspensions -vvv --email-report=1"

# Process Email Queue: Runs every 5 minutes. This job processes the email queue, ensuring that scheduled emails are sent
# in a timely manner, which is essential for communication with clients.
process_email_queue_job="*/5 * * * * $php_path -q $cron_dir/cron.php do --ProcessEmailQueue -vvv --email-report=1"

# Email Campaigns: Runs every 5 minutes. This job updates the status of email campaigns and schedules emails, which is
# important for marketing and communication with clients.
email_campaigns_job="*/5 * * * * $php_path -q $cron_dir/cron.php do --EmailCampaigns -vvv --email-report=1"

# WHMCS Software Updates: Runs every 8 hours. This job checks for WHMCS software updates, ensuring that the system is
# up-to-date with the latest features and security patches.
whmcs_update_job="0 */8 * * * $php_path -q $cron_dir/cron.php do --CheckForWhmcsUpdate -vvv --email-report=1"

# Domain Status Sync: Runs hourly. This job syncs the status of domains, ensuring that the domain information in WHMCS
# is accurate and up-to-date.
domain_status_sync_job="0 * * * * $php_path -q $cron_dir/cron.php do --DomainStatusSync -vvv --email-report=1"

# Server Remote Meta Data: Runs hourly. This job updates the server metadata, which helps in maintaining accurate
# information about server usage and status.
server_meta_data_job="0 * * * * $php_path -q $cron_dir/cron.php do --ServerRemoteMetaData -vvv --email-report=1"

# Database Backup: Runs daily at 2 AM. This job creates a backup of the WHMCS database, ensuring that data is
# regularly backed up and can be restored in case of data loss.
database_backup_job="0 2 * * * $php_path -q $cron_dir/cron.php do --DatabaseBackup -vvv --email-report=1"

# Overage Billing: Runs monthly on the 1st at 3 AM. This job processes overage billing charges and generates invoices,
# ensuring that clients are billed correctly for any usage that exceeds their plan limits.
overage_billing_job="0 3 1 * * $php_path -q $cron_dir/cron.php do --OverageBilling -vvv --email-report=1"

# Affiliate Reports: Runs monthly on the 1st at 4 AM. This job sends affiliate reports, ensuring that affiliates are
# kept informed of their earnings and performance.
affiliate_reports_job="0 4 1 * * $php_path -q $cron_dir/cron.php do --AffiliateReports -vvv --email-report=1"

# Process Credit Card Payments: Runs daily at 5 AM. This job processes credit card payments, ensuring that payments are
# collected and recorded correctly.
credit_card_payments_job="0 5 * * * $php_path -q $cron_dir/cron.php do --ProcessCreditCardPayments -vvv --email-report=1"

# Auto Prune Ticket Attachments: Runs hourly. This job removes inactive ticket attachments in batches of 1000, helping
# to manage disk space and keep the system clean.
prune_ticket_attachments_job="0 * * * * $php_path -q $cron_dir/cron.php do --AutoPruneTicketAttachments -vvv --email-report=1"

# Additional Cron Jobs for better control:

# Currency Exchange Rates Update: Runs daily at 1 AM. This job updates currency exchange rates to ensure accurate
# pricing for clients in different currencies.
currency_update_job="0 1 * * * $php_path -q $cron_dir/cron.php do --CurrencyUpdateExchangeRates -vvv --email-report=1"

# Invoice Reminders: Runs daily at 6 AM. This job sends reminders for unpaid and overdue invoices, helping to improve
# cash flow by prompting clients to pay their invoices.
invoice_reminders_job="0 6 * * * $php_path -q $cron_dir/cron.php do --InvoiceReminders -vvv --email-report=1"

# Domain Renewal Notices: Runs daily at 7 AM. This job sends out domain renewal notices to clients, ensuring they are
# informed about upcoming domain expirations.
domain_renewal_notices_job="0 7 * * * $php_path -q $cron_dir/cron.php do --DomainRenewalNotices -vvv --email-report=1"

# Fixed Term Terminations: Runs daily at 8 AM. This job processes terminations for services with a fixed term, ensuring
# that services are terminated correctly at the end of their term.
fixed_term_terminations_job="0 8 * * * $php_path -q $cron_dir/cron.php do --FixedTermTerminations -vvv --email-report=1"

# Create the cron jobs
create_cron_job "$cron_dir" "$php_path" "$user" "$main_cron_job"
create_cron_job "$cron_dir" "$php_path" "$user" "$ticket_escalations_job"
create_cron_job "$cron_dir" "$php_path" "$user" "$auto_suspensions_job"
create_cron_job "$cron_dir" "$php_path" "$user" "$process_email_queue_job"
create_cron_job "$cron_dir" "$php_path" "$user" "$email_campaigns_job"
create_cron_job "$cron_dir" "$php_path" "$user" "$whmcs_update_job"
create_cron_job "$cron_dir" "$php_path" "$user" "$domain_status_sync_job"
create_cron_job "$cron_dir" "$php_path" "$user" "$server_meta_data_job"
create_cron_job "$cron_dir" "$php_path" "$user" "$database_backup_job"
create_cron_job "$cron_dir" "$php_path" "$user" "$overage_billing_job"
create_cron_job "$cron_dir" "$php_path" "$user" "$affiliate_reports_job"
create_cron_job "$cron_dir" "$php_path" "$user" "$credit_card_payments_job"
create_cron_job "$cron_dir" "$php_path" "$user" "$prune_ticket_attachments_job"
create_cron_job "$cron_dir" "$php_path" "$user" "$currency_update_job"
create_cron_job "$cron_dir" "$php_path" "$user" "$invoice_reminders_job"
create_cron_job "$cron_dir" "$php_path" "$user" "$domain_renewal_notices_job"
create_cron_job "$cron_dir" "$php_path" "$user" "$fixed_term_terminations_job"

# Set up monitoring and notification
setup_monitoring

# Success message
echo "Cron jobs have been successfully set up for WHMCS with monitoring and notification enhancements."
