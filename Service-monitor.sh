#!/bin/bash
#This script is used to monotor linux server services .

SERVICE=(ssh,ngnix,cron)
LOG_FILE="/VAR/LOG/SERVICE_MONITOR.LOG"

for service in "$"{SERVICE[@]}; do
    if systemctl is-active --quiet "$service"; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') $service is running" >> "$LOG_FILE"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') $service is NOT running" >> "$LOG_FILE"
        systemctl restart "$service"
        if systemctl is-active --quiet "$service"; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') $service restarted successfully" >> "$LOG_FILE"
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') Failed to restart $service" >> "$LOG_FILE"
        fi  
    fi
done