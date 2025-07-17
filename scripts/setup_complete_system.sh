#!/bin/bash

# Комплексная настройка VoIP системы
# Автор: Kiro AI Assistant
# Дата: $(date)

set -e

echo "=== Комплексная настройка VoIP системы ==="

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция логирования
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Проверка готовности FreePBX
wait_for_freepbx() {
    log "Ожидание готовности FreePBX..."
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if docker exec freepbx-server asterisk -rx "core show version" >/dev/null 2>&1; then
            log "FreePBX готов к работе"
            return 0
        fi
        
        echo -n "."
        sleep 10
        ((attempt++))
    done
    
    error "FreePBX не готов после $max_attempts попыток"
    return 1
}

# Применение конфигураций Asterisk
apply_asterisk_configs() {
    log "Применение конфигураций Asterisk..."
    
    # Копирование конфигурационных файлов
    docker cp configs/asterisk/pjsip.conf freepbx-server:/etc/asterisk/pjsip_custom.conf
    docker cp configs/asterisk/extensions_custom.conf freepbx-server:/etc/asterisk/extensions_custom.conf
    docker cp configs/asterisk/ari.conf freepbx-server:/etc/asterisk/ari.conf
    docker cp configs/asterisk/http_custom.conf freepbx-server:/etc/asterisk/http_custom.conf
    
    # Перезагрузка конфигурации
    docker exec freepbx-server asterisk -rx "core reload"
    docker exec freepbx-server asterisk -rx "pjsip reload"
    
    log "Конфигурации Asterisk применены"
}

# Проверка SIP регистрации
check_sip_registration() {
    log "Проверка SIP регистрации с Novofon..."
    
    local registration_status=$(docker exec freepbx-server asterisk -rx "pjsip show registrations" | grep novofon || echo "not_found")
    
    if [[ "$registration_status" == "not_found" ]]; then
        warn "SIP регистрация с Novofon не найдена"
        return 1
    else
        log "SIP регистрация найдена: $registration_status"
        return 0
    fi
}

# Проверка LiveKit подключения
check_livekit_connection() {
    log "Проверка подключения LiveKit агента..."
    
    local livekit_logs=$(docker logs livekit-agent --tail=5 2>&1)
    
    if echo "$livekit_logs" | grep -q "registered worker"; then
        log "LiveKit агент успешно подключен"
        return 0
    else
        warn "LiveKit агент не подключен корректно"
        return 1
    fi
}

# Тестирование ARI подключения
test_ari_connection() {
    log "Тестирование ARI подключения..."
    
    # Запуск простого теста ARI
    docker exec livekit-agent python /app/configs/agent/simple_ari_client.py &
    local ari_pid=$!
    
    sleep 5
    
    if kill -0 $ari_pid 2>/dev/null; then
        log "ARI подключение работает"
        kill $ari_pid 2>/dev/null || true
        return 0
    else
        warn "Проблемы с ARI подключением"
        return 1
    fi
}

# Создание тестового звонка
create_test_call() {
    log "Создание тестового звонка..."
    
    # Создание тестового канала для проверки диалплана
    docker exec freepbx-server asterisk -rx "channel originate Local/test@novofon-incoming extension test@novofon-incoming"
    
    sleep 3
    
    # Проверка активных каналов
    local active_channels=$(docker exec freepbx-server asterisk -rx "core show channels" | grep -c "active channel" || echo "0")
    
    if [ "$active_channels" -gt 0 ]; then
        log "Тестовый звонок создан успешно"
        return 0
    else
        warn "Не удалось создать тестовый звонок"
        return 1
    fi
}

# Основная функция настройки
main() {
    log "Начало комплексной настройки системы"
    
    # Шаг 1: Ожидание готовности FreePBX
    if ! wait_for_freepbx; then
        error "FreePBX не готов, прерывание настройки"
        exit 1
    fi
    
    # Шаг 2: Применение конфигураций
    apply_asterisk_configs
    
    # Шаг 3: Проверка компонентов
    local checks_passed=0
    local total_checks=4
    
    if check_sip_registration; then
        ((checks_passed++))
    fi
    
    if check_livekit_connection; then
        ((checks_passed++))
    fi
    
    if test_ari_connection; then
        ((checks_passed++))
    fi
    
    if create_test_call; then
        ((checks_passed++))
    fi
    
    # Результат
    log "Проверок пройдено: $checks_passed из $total_checks"
    
    if [ $checks_passed -eq $total_checks ]; then
        log "✅ Система настроена успешно!"
        log "Готова к приему входящих звонков на номер: $NOVOFON_NUMBER"
    elif [ $checks_passed -ge 2 ]; then
        warn "⚠️ Система частично настроена. Некоторые компоненты требуют внимания."
    else
        error "❌ Система не настроена корректно. Требуется диагностика."
        exit 1
    fi
    
    # Показать статус системы
    show_system_status
}

# Показать статус системы
show_system_status() {
    log "=== Статус системы ==="
    
    echo "📞 Номер телефона: $NOVOFON_NUMBER"
    echo "🌐 LiveKit URL: $LIVEKIT_URL"
    echo "🔗 SIP URI: $LIVEKIT_SIP_URI"
    echo "🏠 Домен: $MY_DOMAIN"
    echo "🌍 Публичный IP: $MY_PUBLIC_IP"
    
    echo ""
    echo "📊 Статус контейнеров:"
    docker-compose ps
    
    echo ""
    echo "📋 Для мониторинга используйте:"
    echo "  - docker-compose logs -f livekit-agent"
    echo "  - docker exec freepbx-server asterisk -rvvv"
    echo "  - ./scripts/monitor_incoming_calls.sh"
}

# Запуск основной функции
main "$@"