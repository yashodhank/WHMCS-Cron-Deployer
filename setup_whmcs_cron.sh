
### setup_whmcs_cron.sh

```bash
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

# Check cron log for errors and send notifications
if grep -q "ERROR" \$CRON_LOG; then
    ERROR_MSG=\$(grep "ERROR" \$CRON_LOG | tail -1)
    send_notification "WHMCS Cron Job Error: \$ERROR_MSG"
fi

# Check if cron jobs are running as expected
if ! tail -n 100 \$CRON_LOG | grep -q "Cron Job Completed Successfully"; then
    send_notification "WHMCS Cron Job Warning: No successful run detected in the last 100 log entries."
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
main_cron_job="*/5 * * * * $php_path -q $cron_dir/cron.php skip --TicketEscalations --AutoSuspensions --EmailCampaigns --ProcessEmailQueue -vvv --email-report=1"
ticket_escalations_job="0 9,10,11,12,13,14,15,16 * * 1-5 $php_path -q $cron_dir/cron.php do --TicketEscalations -vvv --email-report=1"
auto_suspensions_job="0 9 * * 1-5 $php_path -q $cron_dir/cron.php do --AutoSuspensions -vvv --email-report=1"
process_email_queue_job="*/5 * * * * $php_path -q $cron_dir/cron.php do --ProcessEmailQueue -vvv --email-report=1"
email_campaigns_job="*/5 * * * * $php_path -q $cron_dir/cron.php do --EmailCampaigns -vvv --email-report=1"
whmcs_update_job="0 */8 * * * $php_path -q $cron_dir/cron.php do --CheckForWhmcsUpdate -vvv --email-report=1"
domain_status_sync_job="0 * * * * $php_path -q $cron_dir/cron.php do --DomainStatusSync -vvv --email-report=1"
server_meta_data_job="0 * * * * $php_path -q $cron_dir/cron.php do --ServerRemoteMetaData -vvv --email-report=1"
database_backup_job="0 2 * * * $php_path -q $cron_dir/cron.php do --DatabaseBackup -vvv --email-report=1"
overage_billing_job="0 3 1 * * $php_path -q $cron_dir/cron.php do --OverageBilling -vvv --email-report=1"
affiliate_reports_job="0 4 1 * * $php_path -q $cron_dir/cron.php do --AffiliateReports -vvv --email-report=1"
credit_card_payments_job="0 5 * * * $php_path -q $cron_dir/cron.php do --ProcessCreditCardPayments -vvv --email-report=1"
prune_ticket_attachments_job="0 * * * * $php_path -q $cron_dir/cron.php do --AutoPruneTicketAttachments -vvv --email-report=1"

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

# Set up monitoring and notification
setup_monitoring

# Success message
echo "Cron jobs have been successfully set up for WHMCS with monitoring and notification enhancements."
