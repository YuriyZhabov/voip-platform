#!/bin/bash
# Скрипт для проверки доступных звуковых файлов
# Автор: Kiro AI
# Дата: 2025-07-17

echo "=== Проверка доступных звуковых файлов ==="
docker exec freepbx-server ls -la /var/lib/asterisk/sounds/ru/
docker exec freepbx-server ls -la /var/lib/asterisk/sounds/en/

echo -e "\n=== Проверка файла hello-world ==="
docker exec freepbx-server find /var/lib/asterisk/sounds/ -name "hello-world*"

echo -e "\n=== Проверка файла goodbye ==="
docker exec freepbx-server find /var/lib/asterisk/sounds/ -name "goodbye*"