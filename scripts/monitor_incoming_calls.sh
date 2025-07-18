#!/bin/bash

# Скрипт мониторинга входящих звонков
# Показывает логи в реальном времени для диагностики

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

# Проверка статуса системы
check_system_status() {
    log "=== 🔍 СТАТУС СИСТЕМЫ ==="
    
    # Проверка контейнеров
    echo ""
    info "📦 Статус контейнеров:"
    docker-compose ps
    
    # Проверка SIP регистрации
    echo ""
    info "📞 SIP регистрация:"
    docker exec freepbx-server asterisk -rx "pjsip show registrations" 2>/dev/null || error "Не удалось получить статус SIP"
    
    # Проверка ARI приложений
    echo ""
    info "🔗 ARI приложения:"
    docker exec freepbx-server asterisk -rx "ari show apps" 2>/dev/null || error "Не удалось получить статус ARI"
    
    # Проверка активных каналов
    echo ""
    info "📡 Активные каналы:"
    docker exec freepbx-server asterisk -rx "core show channels" 2>/dev/null || error "Не удалось получить статус каналов"
    
    echo ""
    log "=== 🎧 НАЧИНАЮ МОНИТОРИНГ ЗВОНКОВ ==="
    echo "Нажмите Ctrl+C для остановки"
    echo ""
}

# Мониторинг логов
monitor_logs() {
    # Запуск мониторинга в фоне для разных источников
    {
        log "📋 Мониторинг Asterisk логов..."
        docker exec freepbx-server tail -f /var/log/asterisk/full 2>/dev/null | while read line; do
            if echo "$line" | grep -q "PJSIP\|Stasis\|from-novofon\|livekit-agent"; then
                echo -e "${BLUE}[ASTERISK]${NC} $line"
            fi
        done
    } &
    
    {
        log "📋 Мониторинг ARI клиента..."
        docker logs livekit-agent -f 2>/dev/null | while read line; do
            if echo "$line" | grep -q "ARI\|Stasis\|событие\|звонок\|канал"; then
                echo -e "${GREEN}[ARI]${NC} $line"
            fi
        done
    } &
    
    {
        log "📋 Мониторинг LiveKit агента..."
        docker logs livekit-agent -f 2>/dev/null | while read line; do
            if echo "$line" | grep -q "registered worker\|connection\|room"; then
                echo -e "${YELLOW}[LIVEKIT]${NC} $line"
            fi
        done
    } &
    
    # Ожидание завершения
    wait
}

# Функция очистки при завершении
cleanup() {
    log "🛑 Остановка мониторинга..."
    # Убиваем все фоновые процессы
    jobs -p | xargs -r kill
    exit 0
}

# Обработка сигналов
trap cleanup INT TERM

# Основная функция
main() {
    log "🚀 === МОНИТОРИНГ ВХОДЯЩИХ ЗВОНКОВ ==="
    
    # Проверка статуса системы
    check_system_status
    
    # Запуск мониторинга
    monitor_logs
}

# Запуск
main "$@"