#!/bin/bash
# Скрипт для перезагрузки конфигурации Asterisk и проверки диалплана
# Автор: Kiro AI
# Дата: 2025-07-17

echo "=== Перезагрузка конфигурации Asterisk ==="
docker exec freepbx-server asterisk -rx "dialplan reload"
docker exec freepbx-server asterisk -rx "module reload res_pjsip.so"

echo -e "\n=== Проверка диалплана from-novofon ==="
docker exec freepbx-server asterisk -rx "dialplan show from-novofon"

echo -e "\n=== Проверка регистрации на Novofon ==="
docker exec freepbx-server asterisk -rx "pjsip show registrations"

echo -e "\n=== Проверка endpoint 0053248 ==="
docker exec freepbx-server asterisk -rx "pjsip show endpoint 0053248"

echo -e "\n=== Проверка identify правил ==="
docker exec freepbx-server asterisk -rx "pjsip show identifies"

echo -e "\n=== Готово! Теперь можно тестировать входящие звонки ==="