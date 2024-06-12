#!/bin/bash

# Function to prompt for user input if not provided as an argument
prompt_input() {
    read -p "$1" input
    echo $input
}

# Function to create or update a cron job based on the control panel type
create_or_update_cron_job() {
    local user=$1
    local cron_job=$2
    local cron_name=$3

    case $control_panel in
        Plesk|cPanel)
            (crontab -l -u $user 2>/dev/null; echo "$cron_job # $cron_name") | crontab -u $user -
            ;;
        FastPanel)
            sudo su - $user -c "(crontab -l 2>/dev/null; echo \"$cron_job # $cron_name\") | crontab -"
            ;;
        *)
            echo "Unsupported control panel: $control_panel"
            exit 1
            ;;
    esac
}

# Function to remove old cron jobs based on the job name
remove_old_cron_jobs() {
    local user=$1
    local cron_name=$2

    case $control_panel in
        Plesk|cPanel)
            (crontab -l -u $user 2>/dev/null | grep -v "# $cron_name") | crontab -u $user -
            ;;
        FastPanel)
            sudo su - $user -c "(crontab -l 2>/dev/null | grep -v '# $cron_name') | crontab -"
            ;;
        *)
            echo "Unsupported control panel: $control_panel"
            exit 1
            ;;
    esac
}

# Function to set up monitoring and notification
setup_monitoring() {
    local monitoring_script_path="/opt/whmcs_cron_monitor/whmcs_cron_monitor.sh"
    
    # Create directory if it does not exist
    sudo mkdir -p /opt/whmcs_cron_monitor

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
    sudo chmod +x $monitoring_script_path

    # Add the monitoring script to cron to run every 5 minutes
    sudo su - $user -c "(crontab -l 2>/dev/null; echo \"*/5 * * * * $monitoring_script_path\") | crontab -"
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

# Function to get user confirmation for enabling/disabling cron jobs
get_confirmation() {
    local message=$1
    local default=$2
    read -p "$message [${default}]: " confirmation
    confirmation=${confirmation:-$default}
    echo $confirmation
}

# Function to manage cron jobs
manage_cron_jobs() {
    local user=$1

    echo "Managing cron jobs..."
    echo "1. Enable/Disable Cron Job"
    echo "2. Add New Cron Job"
    echo "3. Update Existing Cron Job"
    echo "4. Delete Cron Job"
    echo "5. Exit"

    while true; do
        read -p "Choose an option: " option
        case $option in
            1)
                read -p "Enter the cron job name to enable/disable: " cron_name
                current_status=$(crontab -l -u $user 2>/dev/null | grep "# $cron_name")
                if [ -z "$current_status" ]; then
                    echo "Cron job not found!"
                else
                    echo "Current Status: $current_status"
                    new_status=$(get_confirmation "Enable or Disable (enable/disable): " "disable")
                    if [ "$new_status" == "enable" ]; then
                        sed -i "/# $cron_name/s/^#//" /tmp/crontab-$user
                    else
                        sed -i "/# $cron_name/s/^/#/" /tmp/crontab-$user
                    fi
                    crontab -u $user /tmp/crontab-$user
                    rm /tmp/crontab-$user
                fi
                ;;
            2)
                read -p "Enter the cron job command: " cron_job
                read -p "Enter the cron job name: " cron_name
                create_or_update_cron_job "$user" "$cron_job" "$cron_name"
                ;;
            3)
                read -p "Enter the cron job name to update: " cron_name
                current_job=$(crontab -l -u $user 2>/dev/null | grep "# $cron_name")
                if [ -z "$current_job" ]; then
                    echo "Cron job not found!"
                else
                    echo "Current Job: $current_job"
                    read -p "Enter the new cron job command: " cron_job
                    remove_old_cron_jobs "$user" "$cron_name"
                    create_or_update_cron_job "$user" "$cron_job" "$cron_name"
                fi
                ;;
            4)
                read -p "Enter the cron job name to delete: " cron_name
                remove_old_cron_jobs "$user" "$cron_name"
                ;;
            5)
                echo "Exiting..."
                break
                ;;
            *)
                echo "Invalid option!"
                ;;
        esac
    done
}

# Function to perform initial setup
initial_setup() {
    echo "Performing initial setup..."
    
    # Get user confirmation for enabling/disabling specific cron jobs
    enable_email_campaigns=$(get_confirmation "Enable Process Email Campaigns cron job?" "no")
    enable_email_queue=$(get_confirmation "Enable Process Email Queue cron job?" "no")
    enable_domain_status_sync=$(get_confirmation "Enable Domain Status Synchronisation cron job?" "no")
    enable_domain_sync_report=$(get_confirmation "Enable Domain Synchronisation Cron Report job?" "no")
    enable_prune_ticket_attachments=$(get_confirmation "Enable Prune Ticket Attachments cron job?" "no")

    # Define the cron jobs with conditional enabling/disabling

    # Main system cron job: Runs every 5 minutes. This job excludes Ticket Escalations, Auto Suspensions, Email Campaigns,
    # and Process Email Queue tasks to be run separately. It ensures regular execution of WHMCS automation tasks.
    main_cron_job="*/5 * * * * $php_path -q $cron_dir/cron.php skip --TicketEscalations --AutoSuspensions --EmailCampaigns --ProcessEmailQueue -vvv --email-report=1"
    main_cron_name="whmcs_main_cron"

    # Ticket Escalations: Runs every hour during business hours on weekdays. This job processes and escalates tickets based
    # on predefined rules, ensuring timely responses to support tickets.
    ticket_escalations_job="0 9,10,11,12,13,14,15,16 * * 1-5 $php_path -q $cron_dir/cron.php do --TicketEscalations -vvv --email-report=1"
    ticket_escalations_name="whmcs_ticket_escalations"

    # Auto Suspensions: Runs once daily on weekdays. This job processes overdue suspensions, automatically suspending
    # services that are overdue, which helps in managing unpaid services.
    auto_suspensions_job="0 9 * * 1-5 $php_path -q $cron_dir/cron.php do --AutoSuspensions -vvv --email-report=1"
    auto_suspensions_name="whmcs_auto_suspensions"

    # Process Email Queue: Runs every 5 minutes. This job processes the email queue, ensuring that scheduled emails are sent
    # in a timely manner, which is essential for communication with clients.
    process_email_queue_job="*/5 * * * * $php_path -q $cron_dir/cron.php do --ProcessEmailQueue -vvv --email-report=1"
    process_email_queue_name="whmcs_process_email_queue"

    # Email Campaigns: Runs every 5 minutes. This job updates the status of email campaigns and schedules emails, which is
    # important for marketing and communication with clients.
    email_campaigns_job="*/5 * * * * $php_path -q $cron_dir/cron.php do --EmailCampaigns -vvv --email-report=1"
    email_campaigns_name="whmcs_email_campaigns"

    # WHMCS Software Updates: Runs every 8 hours. This job checks for WHMCS software updates, ensuring that the system is
    # up-to-date with the latest features and security patches.
    whmcs_update_job="0 */8 * * * $php_path -q $cron_dir/cron.php do --CheckForWhmcsUpdate -vvv --email-report=1"
    whmcs_update_name="whmcs_software_updates"

    # Domain Status Sync: Runs hourly. This job syncs the status of domains, ensuring that the domain information in WHMCS
    # is accurate and up-to-date.
    domain_status_sync_job="0 * * * * $php_path -q $cron_dir/cron.php do --DomainStatusSync -vvv --email-report=1"
    domain_status_sync_name="whmcs_domain_status_sync"

    # Domain Synchronisation Cron Report: Runs twice daily. This job generates a report on domain synchronisation activities.
    domain_sync_report_job="0 0,12 * * * $php_path -q $cron_dir/cron.php do --DomainSynchronisationCronReport -vvv --email-report=1"
    domain_sync_report_name="whmcs_domain_sync_report"

    # Server Remote Meta Data: Runs hourly. This job updates the server metadata, which helps in maintaining accurate
    # information about server usage and status.
    server_meta_data_job="0 * * * * $php_path -q $cron_dir/cron.php do --ServerRemoteMetaData -vvv --email-report=1"
    server_meta_data_name="whmcs_server_meta_data"

    # Database Backup: Runs daily at 2 AM. This job creates a backup of the WHMCS database, ensuring that data is
    # regularly backed up and can be restored in case of data loss.
    database_backup_job="0 2 * * * $php_path -q $cron_dir/cron.php do --DatabaseBackup -vvv --email-report=1"
    database_backup_name="whmcs_database_backup"

    # Overage Billing: Runs monthly on the 1st at 3 AM. This job processes overage billing charges and generates invoices,
    # ensuring that clients are billed correctly for any usage that exceeds their plan limits.
    overage_billing_job="0 3 1 * * $php_path -q $cron_dir/cron.php do --OverageBilling -vvv --email-report=1"
    overage_billing_name="whmcs_overage_billing"

    # Affiliate Reports: Runs monthly on the 1st at 4 AM. This job sends affiliate reports, ensuring that affiliates are
    # kept informed of their earnings and performance.
    affiliate_reports_job="0 4 1 * * $php_path -q $cron_dir/cron.php do --AffiliateReports -vvv --email-report=1"
    affiliate_reports_name="whmcs_affiliate_reports"

    # Process Credit Card Payments: Runs daily at 5 AM. This job processes credit card payments, ensuring that payments are
    # collected and recorded correctly.
    credit_card_payments_job="0 5 * * * $php_path -q $cron_dir/cron.php do --ProcessCreditCardPayments -vvv --email-report=1"
    credit_card_payments_name="whmcs_credit_card_payments"

    # Auto Prune Ticket Attachments: Runs once a week. This job removes inactive ticket attachments in batches of 1000, helping
    # to manage disk space and keep the system clean.
    prune_ticket_attachments_job="0 3 * * 0 $php_path -q $cron_dir/cron.php do --AutoPruneTicketAttachments -vvv --email-report=1"
    prune_ticket_attachments_name="whmcs_prune_ticket_attachments"

    # Additional Cron Jobs for better control:

    # Currency Exchange Rates Update: Runs daily at 1 AM. This job updates currency exchange rates to ensure accurate
    # pricing for clients in different currencies.
    currency_update_job="0 1 * * * $php_path -q $cron_dir/cron.php do --CurrencyUpdateExchangeRates -vvv --email-report=1"
    currency_update_name="whmcs_currency_update"

    # Invoice Reminders: Runs daily at 6 AM. This job sends reminders for unpaid and overdue invoices, helping to improve
    # cash flow by prompting clients to pay their invoices.
    invoice_reminders_job="0 6 * * * $php_path -q $cron_dir/cron.php do --InvoiceReminders -vvv --email-report=1"
    invoice_reminders_name="whmcs_invoice_reminders"

    # Domain Renewal Notices: Runs daily at 7 AM. This job sends out domain renewal notices to clients, ensuring they are
    # informed about upcoming domain expirations.
    domain_renewal_notices_job="0 7 * * * $php_path -q $cron_dir/cron.php do --DomainRenewalNotices -vvv --email-report=1"
    domain_renewal_notices_name="whmcs_domain_renewal_notices"

    # Fixed Term Terminations: Runs daily at 8 AM. This job processes terminations for services with a fixed term, ensuring
    # that services are terminated correctly at the end of their term.
    fixed_term_terminations_job="0 8 * * * $php_path -q $cron_dir/cron.php do --FixedTermTerminations -vvv --email-report=1"
    fixed_term_terminations_name="whmcs_fixed_term_terminations"

    # Create or update cron jobs
    create_or_update_cron_job "$user" "$main_cron_job" "$main_cron_name"
    create_or_update_cron_job "$user" "$ticket_escalations_job" "$ticket_escalations_name"
    create_or_update_cron_job "$user" "$auto_suspensions_job" "$auto_suspensions_name"
    create_or_update_cron_job "$user" "$whmcs_update_job" "$whmcs_update_name"
    create_or_update_cron_job "$user" "$server_meta_data_job" "$server_meta_data_name"
    create_or_update_cron_job "$user" "$database_backup_job" "$database_backup_name"
    create_or_update_cron_job "$user" "$overage_billing_job" "$overage_billing_name"
    create_or_update_cron_job "$user" "$affiliate_reports_job" "$affiliate_reports_name"
    create_or_update_cron_job "$user" "$credit_card_payments_job" "$credit_card_payments_name"
    create_or_update_cron_job "$user" "$currency_update_job" "$currency_update_name"
    create_or_update_cron_job "$user" "$invoice_reminders_job" "$invoice_reminders_name"
    create_or_update_cron_job "$user" "$domain_renewal_notices_job" "$domain_renewal_notices_name"
    create_or_update_cron_job "$user" "$fixed_term_terminations_job" "$fixed_term_terminations_name"

    # Conditionally create or update specific cron jobs
    if [[ $enable_email_campaigns == "yes" ]]; then
        create_or_update_cron_job "$user" "$email_campaigns_job" "$email_campaigns_name"
    fi

    if [[ $enable_email_queue == "yes" ]]; then
        create_or_update_cron_job "$user" "$process_email_queue_job" "$process_email_queue_name"
    fi

    if [[ $enable_domain_status_sync == "yes" ]]; then
        create_or_update_cron_job "$user" "$domain_status_sync_job" "$domain_status_sync_name"
    fi

    if [[ $enable_domain_sync_report == "yes" ]]; then
        create_or_update_cron_job "$user" "$domain_sync_report_job" "$domain_sync_report_name"
    fi

    if [[ $enable_prune_ticket_attachments == "yes" ]]; then
        create_or_update_cron_job "$user" "$prune_ticket_attachments_job" "$prune_ticket_attachments_name"
    fi
}

# Check if the script has been run before
if [ ! -f "/opt/whmcs_cron_monitor/setup_done" ]; then
    # Initial setup
    initial_setup
    setup_monitoring
    touch /opt/whmcs_cron_monitor/setup_done
else
    # Subsequent runs
    manage_cron_jobs "$user"
fi

# Success message
echo "Cron jobs have been successfully set up for WHMCS with monitoring and notification enhancements."
