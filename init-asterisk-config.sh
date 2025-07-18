#!/bin/bash
# Скрипт инициализации конфигураций Asterisk
# Автоматически применяется при запуске контейнера
set -e
echo "=== Инициализация конфигураций Asterisk ==="

# Ожидание готовности Asterisk
wait_for_asterisk() {
    local max_attempts=60
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if asterisk -rx "core show version" >/dev/null 2>&1; then
            echo "✅ Asterisk готов"
            # Дополнительное ожидание для загрузки модулей
            echo "⏳ Ожидание загрузки модулей..."
            sleep 10
            return 0
        fi
        echo "⏳ Ожидание Asterisk... ($attempt/$max_attempts)"
        sleep 3
        ((attempt++))
    done
    echo "❌ Asterisk не готов после $max_attempts попыток"
    return 1
}

# Применение конфигураций
apply_configs() {
    echo "📋 Применение конфигураций..."
    
    # Копирование конфигураций из монтированной папки
    if [ -d "/etc/asterisk/custom" ]; then
        echo "📁 Копирование пользовательских конфигураций..."
        
        # PJSIP конфигурация
        if [ -f "/etc/asterisk/custom/pjsip_custom.conf" ]; then
            cp /etc/asterisk/custom/pjsip_custom.conf /etc/asterisk/
            echo "✅ pjsip_custom.conf скопирован"
        fi
        
        # Extensions конфигурация
        if [ -f "/etc/asterisk/custom/extensions_custom.conf" ]; then
            cp /etc/asterisk/custom/extensions_custom.conf /etc/asterisk/
            # Также копируем в override файл для FreePBX
            cp /etc/asterisk/custom/extensions_custom.conf /etc/asterisk/extensions_override_freepbx.conf
            echo "✅ extensions_custom.conf скопирован и добавлен в override"
        fi
        
        # ARI конфигурация
        if [ -f "/etc/asterisk/custom/ari.conf" ]; then
            cp /etc/asterisk/custom/ari.conf /etc/asterisk/
            echo "✅ ari.conf скопирован"
        fi
        
        # HTTP конфигурация
        if [ -f "/etc/asterisk/custom/http.conf" ]; then
            rm -f /etc/asterisk/http.conf
            cp /etc/asterisk/custom/http.conf /etc/asterisk/
            echo "✅ http.conf скопирован"
        fi
    fi
    
    # Включение pjsip_custom.conf в основной файл
    if [ -f "/etc/asterisk/pjsip.conf" ]; then
        if grep -q "#include pjsip_custom.conf" /etc/asterisk/pjsip.conf; then
            sed -i 's/#include pjsip_custom.conf/include pjsip_custom.conf/' /etc/asterisk/pjsip.conf
            echo "✅ pjsip_custom.conf включен в pjsip.conf"
        elif ! grep -q "include pjsip_custom.conf" /etc/asterisk/pjsip.conf; then
            echo "#include pjsip_custom.conf" >> /etc/asterisk/pjsip.conf
            echo "✅ pjsip_custom.conf добавлен в pjsip.conf"
        fi
    else
        # Создаем базовый pjsip.conf если его нет
        cat > /etc/asterisk/pjsip.conf << 'PJSIPEOF'
[global]
type=global
user_agent=Asterisk PBX
#include pjsip_custom.conf
PJSIPEOF
        echo "✅ pjsip.conf создан с включением pjsip_custom.conf"
    fi
    
    # Включение extensions_custom.conf в основной файл
    if [ ! -f "/etc/asterisk/extensions.conf" ]; then
        touch /etc/asterisk/extensions.conf
        cat > /etc/asterisk/extensions.conf << 'EXTEOF'
[general]
include extensions_custom.conf
EXTEOF
        echo "✅ extensions.conf создан с включением extensions_custom.conf"
    elif ! grep -q "include extensions_custom.conf" /etc/asterisk/extensions.conf 2>/dev/null; then
        echo "include extensions_custom.conf" >> /etc/asterisk/extensions.conf
        echo "✅ extensions_custom.conf включен в extensions.conf"
    fi
    
    # Убедимся, что наши конфигурации всегда доступны в override файле
    if [ -f "/etc/asterisk/extensions_custom.conf" ]; then
        cp /etc/asterisk/extensions_custom.conf /etc/asterisk/extensions_override_freepbx.conf
        echo "✅ Конфигурации добавлены в extensions_override_freepbx.conf"
    fi
}

# Перезагрузка модулей
reload_modules() {
    echo "🔄 Настройка модулей Asterisk..."
    
    # Проверяем текущие загруженные модули
    echo "📋 Проверка текущих модулей..."
    local current_modules=$(asterisk -rx "module show" | wc -l)
    echo "📊 Загружено модулей: $current_modules"
    
    # Используем FreePBX команды для активации модулей
    echo "🔧 Активация модулей через FreePBX..."
    
    # Попытка использовать fwconsole для управления модулями
    if command -v fwconsole >/dev/null 2>&1; then
        echo "📋 Используем fwconsole для настройки..."
        fwconsole reload 2>/dev/null || echo "⚠️ fwconsole reload не удался"
        fwconsole restart 2>/dev/null || echo "⚠️ fwconsole restart не удался"
    fi
    
    # Принудительная загрузка критически важных модулей
    echo "🔧 Принудительная загрузка модулей..."
    # Загружаем модули без проверки ошибок, так как они могут быть уже загружены
    asterisk -rx "module load res_pjsip.so" >/dev/null 2>&1
    asterisk -rx "module load chan_pjsip.so" >/dev/null 2>&1
    asterisk -rx "module load res_pjsip_session.so" >/dev/null 2>&1
    asterisk -rx "module load res_pjsip_registrar.so" >/dev/null 2>&1
    asterisk -rx "module load res_pjsip_outbound_registration.so" >/dev/null 2>&1
    asterisk -rx "module load res_ari.so" >/dev/null 2>&1
    asterisk -rx "module load res_ari_channels.so" >/dev/null 2>&1
    asterisk -rx "module load res_ari_bridges.so" >/dev/null 2>&1
    asterisk -rx "module load res_ari_endpoints.so" >/dev/null 2>&1
    asterisk -rx "module load res_ari_applications.so" >/dev/null 2>&1
    asterisk -rx "module load res_http_websocket.so" >/dev/null 2>&1
    
    # Пауза для стабилизации
    sleep 5
    
    # Перезагрузка конфигураций
    echo "🔄 Перезагрузка конфигураций..."
    asterisk -rx "core reload" 2>/dev/null || echo "⚠️ Не удалось выполнить core reload"
    asterisk -rx "dialplan reload" 2>/dev/null || echo "⚠️ Не удалось выполнить dialplan reload"
    
    # Проверяем результат
    local final_modules=$(asterisk -rx "module show" | wc -l)
    echo "📊 Итого загружено модулей: $final_modules"
    
    if [ "$final_modules" -gt "$current_modules" ]; then
        echo "✅ Дополнительные модули успешно загружены"
    else
        echo "⚠️ Количество модулей не изменилось, возможно они уже были загружены"
    fi
    
    echo "✅ Настройка модулей завершена"
}

# Проверка конфигураций
check_configs() {
    echo "🔍 Проверка конфигураций..."
    
    # Проверка PJSIP endpoints
    local endpoints_output=$(asterisk -rx "pjsip show endpoints" 2>/dev/null || echo "")
    local endpoints=$(echo "$endpoints_output" | grep -c "Endpoint:" 2>/dev/null || echo "0")
    echo "📊 PJSIP endpoints: $endpoints"
    
    # Проверка регистраций
    local registrations=$(asterisk -rx "pjsip show registrations" | grep -c "Objects found:" || echo "0")
    echo "📊 PJSIP registrations проверены"
    
    # Проверка ARI приложений
    local ari_output=$(asterisk -rx "ari show apps" 2>/dev/null || echo "")
    local ari_apps=$(echo "$ari_output" | grep -v "Application Name" | grep -v "=" | grep -v "^$" | wc -l 2>/dev/null || echo "0")
    echo "📊 ARI приложения: $ari_apps"
    
    # Проверка HTTP статуса
    local http_output=$(asterisk -rx "http show status" 2>/dev/null || echo "")
    local http_status=$(echo "$http_output" | grep -c "Server Enabled" 2>/dev/null || echo "0")
    echo "📊 HTTP сервер: $([ "$http_status" -gt 0 ] && echo 'включен' || echo 'отключен')"
    
    # Проверка диалплана
    local dialplan_output=$(asterisk -rx "dialplan show from-novofon" 2>/dev/null || echo "")
    if [[ "$dialplan_output" == *"from-novofon"* ]]; then
        echo "📊 Диалплан from-novofon загружен"
    else
        echo "⚠️ Диалплан from-novofon не найден"
    fi
}

# Основная функция
main() {
    echo "🚀 Запуск инициализации конфигураций Asterisk..."
    
    if wait_for_asterisk; then
        apply_configs
        sleep 2
        reload_modules
        sleep 3
        check_configs
        echo "🎉 Инициализация завершена успешно!"
    else
        echo "💥 Ошибка инициализации: Asterisk недоступен"
        exit 1
    fi
}

# Запуск только если скрипт вызван напрямую
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi