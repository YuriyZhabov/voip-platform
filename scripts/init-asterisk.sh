#!/bin/bash

# Скрипт инициализации Asterisk

echo "Initializing Asterisk..."

# Создаем необходимые директории
mkdir -p data/asterisk
mkdir -p data/logs/asterisk
mkdir -p volumes/asterisk-db

# Устанавливаем права доступа
chmod -R 755 data/asterisk
chmod -R 755 data/logs/asterisk

echo "Asterisk directories created successfully!"

# Проверяем конфигурационные файлы
if [ -f configs/asterisk/pjsip.conf ]; then
    echo "✓ pjsip.conf found"
else
    echo "✗ pjsip.conf not found!"
    exit 1
fi

if [ -f configs/asterisk/extensions.conf ]; then
    echo "✓ extensions.conf found"
else
    echo "✗ extensions.conf not found!"
    exit 1
fi

if [ -f configs/asterisk/modules.conf ]; then
    echo "✓ modules.conf found"
else
    echo "✗ modules.conf not found!"
    exit 1
fi

echo "Asterisk initialization completed!"