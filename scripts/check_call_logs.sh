#!/bin/bash
# Скрипт для проверки логов звонков в Asterisk
# Автор: Kiro AI
# Дата: 2025-07-17

# Количество строк для вывода
LINES=100

echo "=== Проверка логов входящих звонков ==="
echo "Последние $LINES строк из лога Asterisk:"
docker exec freepbx-server tail -n $LINES /var/log/asterisk/full | grep -a "from-novofon\|Incoming call\|PJSIP\|0053248"

echo -e "\n=== Проверка активных каналов ==="
docker exec freepbx-server asterisk -rx "core show channels"

echo -e "\n=== Проверка статуса регистрации ==="
docker exec freepbx-server asterisk -rx "pjsip show registrations"

echo -e "\n=== Проверка диалплана ==="
docker exec freepbx-server asterisk -rx "dialplan show novofon-in"

echo -e "\n=== Проверка последних звонков ==="
docker exec freepbx-server asterisk -rx "core show calls"