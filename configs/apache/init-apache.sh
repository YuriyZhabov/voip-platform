#!/bin/bash
# Скрипт инициализации Apache для FreePBX

# Включаем необходимые модули
a2enmod remoteip headers rewrite

# Включаем наши конфигурации
a2enconf freepbx freepbx-proxy

# Перезагружаем Apache
service apache2 reload

echo "Apache configuration for FreePBX initialized successfully"