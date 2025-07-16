#!/bin/bash

# FreePBX Permissions Fix Script
# Исправляет критические ошибки с правами доступа
# Версия: 1.0

echo "=== Исправление прав доступа FreePBX ==="

# 1. Исправляем права на /tmp
echo "1. Исправление прав доступа к /tmp..."
chmod 1777 /tmp
rm -f /tmp/cron.error
touch /tmp/cron.error
chmod 777 /tmp/cron.error

# 2. Исправляем права FreePBX
echo "2. Исправление прав FreePBX..."
chown -R asterisk:asterisk /admin
chown -R asterisk:asterisk /var/lib/asterisk
chown -R asterisk:asterisk /var/log/asterisk
chown -R asterisk:asterisk /var/spool/asterisk

# 3. Создаем необходимые директории
echo "3. Создание необходимых директорий..."
mkdir -p /var/spool/asterisk/tmp
chown -R asterisk:asterisk /var/spool/asterisk/tmp
chmod 755 /var/spool/asterisk/tmp

# 4. Исправляем права на конфигурационные файлы
echo "4. Исправление прав конфигурационных файлов..."
chown -R asterisk:asterisk /etc/asterisk
chmod 644 /etc/asterisk/*.conf

# 5. Исправляем права на сокеты и PID файлы
echo "5. Исправление прав на runtime файлы..."
mkdir -p /var/run/asterisk
chown asterisk:asterisk /var/run/asterisk
chmod 755 /var/run/asterisk

echo "=== Исправление завершено ==="
echo "Рекомендуется выполнить: fwconsole reload"