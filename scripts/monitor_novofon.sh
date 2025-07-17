#!/bin/bash
# Скрипт для мониторинга соединения с Novofon и автоматического перезапуска при проблемах

LOG_FILE="/var/log/asterisk/novofon_monitor.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Функция для логирования
log_message() {
    echo "$DATE - $1" >> $LOG_FILE
}

# Проверка, запущен ли Asterisk
check_asterisk() {
    if ! pgrep -x "asterisk" > /dev/null; then
        log_message "Asterisk не запущен, запускаем..."
        systemctl start asterisk
        sleep 10
        return 1
    fi
    return 0
}

# Проверка регистрации на Novofon
check_registration() {
    REGISTRATION_STATUS=$(asterisk -rx "pjsip show registrations" | grep "0053248")
    if [[ $REGISTRATION_STATUS == *"Registered"* ]]; then
        log_message "Регистрация на Novofon активна"
        return 0
    else
        log_message "Проблемы с регистрацией на Novofon: $REGISTRATION_STATUS"
        return 1
    fi
}

# Проверка доступности SIP-сервера Novofon
check_sip_server() {
    if ping -c 3 sip.novofon.ru > /dev/null; then
        log_message "SIP-сервер Novofon доступен"
        return 0
    else
        log_message "SIP-сервер Novofon недоступен"
        return 1
    fi
}

# Перезагрузка модуля PJSIP
reload_pjsip() {
    log_message "Перезагрузка модуля PJSIP..."
    asterisk -rx "module reload res_pjsip.so"
    sleep 5
}

# Перезапуск Asterisk
restart_asterisk() {
    log_message "Перезапуск Asterisk..."
    systemctl restart asterisk
    sleep 30
}

# Основная логика
log_message "Запуск мониторинга соединения с Novofon"

# Проверка Asterisk
check_asterisk
if [ $? -eq 1 ]; then
    log_message "Asterisk был запущен"
fi

# Проверка доступности SIP-сервера
check_sip_server
if [ $? -eq 1 ]; then
    log_message "SIP-сервер Novofon недоступен, повторная проверка через 5 минут"
    exit 1
fi

# Проверка регистрации
check_registration
if [ $? -eq 1 ]; then
    log_message "Попытка перезагрузки модуля PJSIP"
    reload_pjsip
    
    # Повторная проверка регистрации
    check_registration
    if [ $? -eq 1 ]; then
        log_message "Перезагрузка модуля не помогла, перезапуск Asterisk"
        restart_asterisk
        
        # Финальная проверка
        check_registration
        if [ $? -eq 1 ]; then
            log_message "КРИТИЧЕСКАЯ ОШИБКА: Не удалось восстановить регистрацию на Novofon"
            # Здесь можно добавить отправку уведомления администратору
        else
            log_message "Регистрация восстановлена после перезапуска Asterisk"
        fi
    else
        log_message "Регистрация восстановлена после перезагрузки модуля"
    fi
else
    log_message "Соединение с Novofon работает нормально"
fi

log_message "Мониторинг завершен"
exit 0