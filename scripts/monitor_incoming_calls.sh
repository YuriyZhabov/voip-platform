#!/bin/bash
# Скрипт для мониторинга входящих звонков с Novofon
# Автор: Kiro AI
# Дата: 2025-07-17

# Настройки
LOG_FILE="/var/log/asterisk/incoming_calls.log"
ASTERISK_LOG="/var/log/asterisk/full"
NOVOFON_NUMBER="79952227978"
ALERT_EMAIL="admin@stellaragents.ru"
MONITOR_INTERVAL=60  # секунды
MAX_LOG_SIZE=10485760  # 10MB

# Создаем лог-файл, если он не существует
touch $LOG_FILE

# Функция для логирования
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> $LOG_FILE
}

# Функция для отправки уведомлений
send_alert() {
    local subject="$1"
    local message="$2"
    
    echo "$message" | mail -s "$subject" $ALERT_EMAIL
    log_message "Отправлено уведомление: $subject"
}

# Функция для ротации логов
rotate_log() {
    if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE") -gt $MAX_LOG_SIZE ]; then
        local timestamp=$(date '+%Y%m%d-%H%M%S')
        mv "$LOG_FILE" "${LOG_FILE}.${timestamp}"
        gzip "${LOG_FILE}.${timestamp}"
        touch "$LOG_FILE"
        log_message "Лог-файл был ротирован"
    fi
}

# Функция для проверки входящих звонков
check_incoming_calls() {
    local last_check=$(date -d "1 minute ago" '+%Y-%m-%d %H:%M:%S')
    
    # Проверяем логи Asterisk на наличие входящих звонков с Novofon
    local calls=$(grep -a "from-novofon" $ASTERISK_LOG | grep -a "Incoming call from Novofon" | grep -a -A 5 "$last_check")
    
    if [ ! -z "$calls" ]; then
        log_message "Обнаружены входящие звонки с Novofon:"
        log_message "$calls"
        
        # Проверяем успешность обработки звонков
        if echo "$calls" | grep -q "Hangup"; then
            log_message "Звонки были успешно обработаны"
        else
            log_message "ВНИМАНИЕ: Возможны проблемы с обработкой звонков"
            send_alert "Проблемы с входящими звонками Novofon" "Обнаружены проблемы с обработкой входящих звонков с Novofon. Проверьте логи: $LOG_FILE"
        fi
    fi
}

# Функция для проверки регистрации на Novofon
check_novofon_registration() {
    local reg_status=$(asterisk -rx "pjsip show registrations" | grep "0053248")
    
    if [[ $reg_status == *"Registered"* ]]; then
        log_message "Регистрация на Novofon активна"
    else
        log_message "ВНИМАНИЕ: Проблемы с регистрацией на Novofon"
        log_message "Статус регистрации: $reg_status"
        send_alert "Проблемы с регистрацией на Novofon" "Обнаружены проблемы с регистрацией на Novofon. Проверьте настройки SIP-транка."
    fi
}

# Функция для проверки доступности IP-адресов Novofon
check_novofon_ips() {
    local novofon_ips=(
        "37.139.38.224"
        "37.139.38.236"
        "37.139.38.237"
        "37.139.38.131"
        "37.139.38.56"
    )
    
    local unreachable_ips=""
    
    for ip in "${novofon_ips[@]}"; do
        if ! ping -c 1 -W 2 $ip > /dev/null 2>&1; then
            unreachable_ips="$unreachable_ips $ip"
        fi
    done
    
    if [ ! -z "$unreachable_ips" ]; then
        log_message "ВНИМАНИЕ: Недоступны IP-адреса Novofon:$unreachable_ips"
        send_alert "Проблемы с доступностью IP-адресов Novofon" "Следующие IP-адреса Novofon недоступны:$unreachable_ips"
    fi
}

# Функция для проверки активных каналов
check_active_channels() {
    local channels=$(asterisk -rx "core show channels" | grep "active channel")
    log_message "Активные каналы: $channels"
}

# Функция для проверки статистики звонков
check_call_stats() {
    local start_time=$(date -d "24 hours ago" '+%Y-%m-%d %H:%M:%S')
    local end_time=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Подсчет входящих звонков за последние 24 часа
    local incoming_count=$(grep -a "from-novofon" $ASTERISK_LOG | grep -a "Incoming call from Novofon" | grep -a -A 5 "$start_time" | wc -l)
    
    # Подсчет успешных звонков
    local successful_count=$(grep -a "from-novofon" $ASTERISK_LOG | grep -a "Incoming call from Novofon" | grep -a -A 5 "$start_time" | grep -a "Hangup" | wc -l)
    
    log_message "Статистика звонков за последние 24 часа:"
    log_message "Всего входящих звонков: $incoming_count"
    log_message "Успешно обработано: $successful_count"
    
    # Если есть проблемы с обработкой звонков
    if [ $incoming_count -gt 0 ] && [ $successful_count -eq 0 ]; then
        log_message "КРИТИЧЕСКАЯ ОШИБКА: Все входящие звонки не обрабатываются!"
        send_alert "Критическая ошибка с входящими звонками" "Все входящие звонки с Novofon не обрабатываются. Требуется немедленное вмешательство!"
    elif [ $incoming_count -gt $successful_count ]; then
        local failed_percent=$(( ($incoming_count - $successful_count) * 100 / $incoming_count ))
        log_message "ВНИМАНИЕ: $failed_percent% входящих звонков не обрабатываются"
        
        if [ $failed_percent -gt 50 ]; then
            send_alert "Высокий процент необработанных звонков" "$failed_percent% входящих звонков с Novofon не обрабатываются. Проверьте настройки диалплана."
        fi
    fi
}

# Основная функция мониторинга
monitor_incoming_calls() {
    log_message "Запуск мониторинга входящих звонков с Novofon"
    
    # Проверка регистрации
    check_novofon_registration
    
    # Проверка IP-адресов (раз в час)
    if [ $(date +%M) -eq 0 ]; then
        check_novofon_ips
    fi
    
    # Проверка входящих звонков
    check_incoming_calls
    
    # Проверка активных каналов
    check_active_channels
    
    # Проверка статистики (раз в день в полночь)
    if [ $(date +%H%M) -eq 0000 ]; then
        check_call_stats
    fi
    
    # Ротация логов
    rotate_log
    
    log_message "Мониторинг завершен"
}

# Запуск в режиме демона или однократно
if [ "$1" == "daemon" ]; then
    log_message "Запуск в режиме демона с интервалом $MONITOR_INTERVAL секунд"
    
    while true; do
        monitor_incoming_calls
        sleep $MONITOR_INTERVAL
    done
else
    # Однократный запуск
    monitor_incoming_calls
fi

exit 0