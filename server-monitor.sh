#!/bin/bash
# This script monitors the server and sends an alert if the server is down.
# Cron:    * * * * * /path/to/monitor_server.sh   (check every minute)

# ---------- Configuration ----------
SERVER_HOST="example.com"            # Host/IP to ping
SERVER_URL="https://example.com"     # URL to check over HTTP(S); leave empty to skip
PING_COUNT=3
TIMEOUT=10                           # Seconds before a check is considered failed
RETRIES=2                            # Extra attempts before declaring "down"
RETRY_DELAY=5

ALERT_EMAIL="you@example.com"        # Leave empty to disable email alerts
SLACK_WEBHOOK_URL=""                 # Leave empty to disable Slack alerts

STATE_FILE="/tmp/monitor_server.state"   # Remembers last status to avoid repeat alerts
LOG_FILE="/var/log/monitor_server.log"   # Falls back to /tmp if not writable
# -----------------------------------

[ -w "$(dirname "$LOG_FILE")" ] || LOG_FILE="/tmp/monitor_server.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG_FILE"
}

check_server() {
    # Ping check
    if ! ping -c "$PING_COUNT" -W "$TIMEOUT" "$SERVER_HOST" > /dev/null 2>&1; then
        return 1
    fi
    # HTTP check (optional)
    if [ -n "$SERVER_URL" ]; then
        local code
        code=$(curl -s -o /dev/null -m "$TIMEOUT" -w "%{http_code}" "$SERVER_URL")
        [[ "$code" =~ ^[23] ]] || return 1
    fi
    return 0
}

send_alert() {
    local subject="$1"
    local body="$2"

    if [ -n "$ALERT_EMAIL" ] && command -v mail > /dev/null 2>&1; then
        echo "$body" | mail -s "$subject" "$ALERT_EMAIL"
    fi

    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        curl -s -m "$TIMEOUT" -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"$subject - $body\"}" "$SLACK_WEBHOOK_URL" > /dev/null
    fi

    log "ALERT SENT: $subject"
}

# Run the check with retries to avoid false alarms
is_up=false
for ((i = 0; i <= RETRIES; i++)); do
    if check_server; then
        is_up=true
        break
    fi
    [ "$i" -lt "$RETRIES" ] && sleep "$RETRY_DELAY"
done

previous_status=$(cat "$STATE_FILE" 2>/dev/null || echo "up")

if $is_up; then
    log "OK: $SERVER_HOST is up"
    if [ "$previous_status" = "down" ]; then
        send_alert "[RECOVERED] $SERVER_HOST is back up" \
            "$SERVER_HOST recovered at $(date '+%Y-%m-%d %H:%M:%S')."
    fi
    echo "up" > "$STATE_FILE"
else
    log "FAIL: $SERVER_HOST is down"
    if [ "$previous_status" != "down" ]; then
        send_alert "[ALERT] $SERVER_HOST is DOWN" \
            "$SERVER_HOST failed checks at $(date '+%Y-%m-%d %H:%M:%S')."
    fi
    echo "down" > "$STATE_FILE"
fi