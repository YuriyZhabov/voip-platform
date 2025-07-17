#!/bin/bash
# Скрипт для перезагрузки конфигурации Asterisk
# Автор: Kiro AI
# Дата: 2025-07-17

echo "Перезагрузка конфигурации Asterisk..."
docker exec freepbx-server asterisk -rx "core reload"
echo "Проверка статуса модулей..."
docker exec freepbx-server asterisk -rx "module show like pjsip"
echo "Проверка регистрации на Novofon..."
docker exec freepbx-server asterisk -rx "pjsip show registrations"
echo "Готово!"