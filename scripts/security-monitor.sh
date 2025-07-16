#!/bin/bash

# VoIP Security Monitor Script
# Мониторинг безопасности для VoIP платформы

LOG_FILE="/var/log/voip-security.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$DATE] Starting VoIP Security Monitor" | tee -a $LOG_FILE

# Функция логирования
log_message() {
    echo "[$DATE] $1" | tee -a $LOG_FILE
}

# Проверка статуса UFW
check_ufw() {
    log_message "Checking UFW status..."
    if ufw status | grep -q "Status: active"; then
        log_message "✓ UFW is active"
    else
        log_message "✗ UFW is not active - SECURITY RISK!"
        ufw --force enable
    fi
}

# Проверка статуса Fail2ban
check_fail2ban() {
    log_message "Checking Fail2ban status..."
    if systemctl is-active --quiet fail2ban; then
        log_message "✓ Fail2ban is running"
        
        # Показать статистику jail'ов
        log_message "Fail2ban jail status:"
        fail2ban-client status | tee -a $LOG_FILE
        
        # Показать заблокированные IP
        for jail in $(fail2ban-client status | grep "Jail list:" | cut -d: -f2 | tr ',' ' '); do
            jail=$(echo $jail | xargs)  # trim whitespace
            if [ ! -z "$jail" ]; then
                banned_ips=$(fail2ban-client status $jail | grep "Banned IP list:" | cut -d: -f2)
                if [ ! -z "$banned_ips" ] && [ "$banned_ips" != " " ]; then
                    log_message "Banned IPs in $jail: $banned_ips"
                fi
            fi
        done
    else
        log_message "✗ Fail2ban is not running - SECURITY RISK!"
        systemctl start fail2ban
    fi
}

# Проверка подозрительной активности в логах
check_suspicious_activity() {
    log_message "Checking for suspicious SIP activity..."
    
    # Поиск неудачных попыток регистрации
    if [ -f "/var/log/asterisk/messages" ]; then
        recent_failures=$(tail -n 1000 /var/log/asterisk/messages | grep -c "failed to authenticate\|No matching endpoint\|Failed to authenticate")
        log_message "Recent authentication failures: $recent_failures"
        
        if [ $recent_failures -gt 50 ]; then
            log_message "⚠ HIGH number of authentication failures detected!"
        fi
    fi
}

# Проверка открытых портов
check_open_ports() {
    log_message "Checking open ports..."
    netstat -tuln | grep -E ":5060|:5061|:80|:443|:22" | tee -a $LOG_FILE
}

# Проверка ресурсов системы
check_system_resources() {
    log_message "System resource usage:"
    echo "Memory usage:" | tee -a $LOG_FILE
    free -h | tee -a $LOG_FILE
    echo "Disk usage:" | tee -a $LOG_FILE
    df -h | grep -v tmpfs | tee -a $LOG_FILE
    echo "Load average:" | tee -a $LOG_FILE
    uptime | tee -a $LOG_FILE
}

# Основная функция
main() {
    check_ufw
    check_fail2ban
    check_suspicious_activity
    check_open_ports
    check_system_resources
    
    log_message "Security monitor check completed"
    echo "----------------------------------------" >> $LOG_FILE
}

# Запуск с параметрами
case "$1" in
    "status")
        main
        ;;
    "ban")
        if [ -z "$2" ]; then
            echo "Usage: $0 ban <IP_ADDRESS>"
            exit 1
        fi
        log_message "Manually banning IP: $2"
        ufw insert 1 deny from $2
        ;;
    "unban")
        if [ -z "$2" ]; then
            echo "Usage: $0 unban <IP_ADDRESS>"
            exit 1
        fi
        log_message "Manually unbanning IP: $2"
        ufw --force delete deny from $2
        ;;
    "logs")
        tail -f $LOG_FILE
        ;;
    *)
        echo "VoIP Security Monitor"
        echo "Usage: $0 {status|ban <ip>|unban <ip>|logs}"
        echo ""
        echo "Commands:"
        echo "  status  - Run security status check"
        echo "  ban     - Manually ban an IP address"
        echo "  unban   - Manually unban an IP address"
        echo "  logs    - Show security logs"
        exit 1
        ;;
esac