#!/bin/bash

# Скрипт тестирования VoIP системы

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO: $1${NC}"
}

# Тест подключения к Asterisk
test_asterisk() {
    log "🔧 Тестирование Asterisk..."
    
    if docker exec freepbx-server asterisk -rx "core show version" >/dev/null 2>&1; then
        log "✅ Asterisk работает"
        return 0
    else
        error "❌ Asterisk не отвечает"
        return 1
    fi
}

# Тест SIP регистрации
test_sip_registration() {
    log "📞 Тестирование SIP регистрации..."
    
    local registrations=$(docker exec freepbx-server asterisk -rx "pjsip show registrations" 2>/dev/null | grep "Registered" | wc -l)
    
    if [ "$registrations" -gt 0 ]; then
        log "✅ SIP регистрация активна ($registrations)"
        return 0
    else
        error "❌ SIP регистрация не найдена"
        return 1
    fi
}

# Тест ARI приложения
test_ari_application() {
    log "🔗 Тестирование ARI приложения..."
    
    if docker exec freepbx-server asterisk -rx "ari show apps" 2>/dev/null | grep -q "livekit-agent"; then
        log "✅ ARI приложение зарегистрировано"
        return 0
    else
        error "❌ ARI приложение не зарегистрировано"
        return 1
    fi
}

# Тест LiveKit агента
test_livekit_agent() {
    log "🎤 Тестирование LiveKit агента..."
    
    if docker logs livekit-agent --tail=10 2>&1 | grep -q "registered worker"; then
        log "✅ LiveKit агент подключен"
        return 0
    else
        warn "⚠️ LiveKit агент может быть не подключен"
        return 1
    fi
}

# Тест диалплана
test_dialplan() {
    log "📋 Тестирование диалплана..."
    
    if docker exec freepbx-server asterisk -rx "dialplan show from-novofon" 2>/dev/null | grep -q "79952227978"; then
        log "✅ Диалплан настроен"
        return 0
    else
        error "❌ Диалплан не найден"
        return 1
    fi
}

# Тест внутреннего звонка
test_internal_call() {
    log "📞 Тестирование внутреннего звонка..."
    
    # Создаем тестовый звонок на номер 9999
    if docker exec freepbx-server asterisk -rx "channel originate Local/9999@from-internal-custom application Echo" >/dev/null 2>&1; then
        sleep 2
        
        # Проверяем, был ли создан канал
        local channels=$(docker exec freepbx-server asterisk -rx "core show channels" 2>/dev/null | grep -c "Local/9999")
        
        if [ "$channels" -gt 0 ]; then
            log "✅ Внутренний звонок работает"
            
            # Завершаем тестовые каналы
            docker exec freepbx-server asterisk -rx "channel request hangup all" >/dev/null 2>&1
            return 0
        else
            warn "⚠️ Тестовый звонок не создал каналы"
            return 1
        fi
    else
        error "❌ Не удалось создать тестовый звонок"
        return 1
    fi
}

# Показать детальную информацию
show_detailed_info() {
    log "=== 📊 ДЕТАЛЬНАЯ ИНФОРМАЦИЯ ==="
    
    echo ""
    info "📦 Контейнеры:"
    docker-compose ps
    
    echo ""
    info "📞 SIP endpoints:"
    docker exec freepbx-server asterisk -rx "pjsip show endpoints" 2>/dev/null | head -20
    
    echo ""
    info "🔗 ARI приложения:"
    docker exec freepbx-server asterisk -rx "ari show apps" 2>/dev/null
    
    echo ""
    info "📡 Активные каналы:"
    docker exec freepbx-server asterisk -rx "core show channels concise" 2>/dev/null
    
    echo ""
    info "🎤 LiveKit агент (последние 5 строк):"
    docker logs livekit-agent --tail=5 2>/dev/null
}

# Основная функция
main() {
    log "🧪 === ТЕСТИРОВАНИЕ VoIP СИСТЕМЫ ==="
    
    local tests_passed=0
    local total_tests=6
    
    # Запуск тестов
    test_asterisk && ((tests_passed++))
    test_sip_registration && ((tests_passed++))
    test_ari_application && ((tests_passed++))
    test_livekit_agent && ((tests_passed++))
    test_dialplan && ((tests_passed++))
    test_internal_call && ((tests_passed++))
    
    echo ""
    log "📊 === РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ ==="
    log "Пройдено тестов: $tests_passed из $total_tests"
    
    if [ $tests_passed -eq $total_tests ]; then
        log "🎉 Все тесты пройдены! Система готова к работе."
        echo ""
        info "Теперь можно звонить на номер: +79952227978"
    elif [ $tests_passed -ge 4 ]; then
        warn "⚠️ Большинство тестов пройдено. Система частично готова."
        echo ""
        info "Рекомендуется проверить предупреждения выше."
    else
        error "❌ Много тестов не пройдено. Система требует настройки."
        echo ""
        info "Запустите: ./scripts/start-system.sh для исправления проблем."
    fi
    
    # Показать детальную информацию если запрошено
    if [ "$1" = "--detailed" ] || [ "$1" = "-d" ]; then
        echo ""
        show_detailed_info
    fi
    
    echo ""
    log "=== 🛠️ ПОЛЕЗНЫЕ КОМАНДЫ ==="
    echo "  - Мониторинг звонков: ./scripts/monitor_incoming_calls.sh"
    echo "  - Перезапуск системы: ./scripts/start-system.sh"
    echo "  - Детальная информация: ./scripts/test_system.sh --detailed"
    echo "  - Логи LiveKit: docker logs livekit-agent -f"
    echo "  - Консоль Asterisk: docker exec freepbx-server asterisk -rvvv"
}

# Запуск
main "$@"