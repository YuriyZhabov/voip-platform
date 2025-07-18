#!/bin/bash

# Скрипт тестирования аудио моста
# Проверяет все компоненты системы

set -e

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

test_passed=0
test_failed=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    info "🧪 Тест: $test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        log "✅ PASSED: $test_name"
        ((test_passed++))
    else
        error "❌ FAILED: $test_name"
        ((test_failed++))
    fi
}

log "🧪 === ТЕСТИРОВАНИЕ АУДИО МОСТА ==="

# Тест 1: Проверка контейнеров
run_test "Контейнеры запущены" "docker-compose ps | grep -q 'Up'"

# Тест 2: Проверка FreePBX
run_test "FreePBX доступен" "docker exec freepbx-server asterisk -rx 'core show version'"

# Тест 3: Проверка LiveKit агента
run_test "LiveKit агент health check" "curl -s http://localhost:8081/health | grep -q 'healthy'"

# Тест 4: Проверка ARI
run_test "ARI приложение зарегистрировано" "docker exec freepbx-server asterisk -rx 'ari show apps' | grep -q 'livekit-agent'"

# Тест 5: Проверка диалплана
run_test "Диалплан загружен" "docker exec freepbx-server asterisk -rx 'dialplan show from-novofon' | grep -q '79952227978'"

# Тест 6: Проверка мостового контекста
run_test "Мостовой контекст загружен" "docker exec freepbx-server asterisk -rx 'dialplan show livekit-bridge' | grep -q '_X.'"

# Тест 7: Проверка тестовых номеров
run_test "Тестовые номера доступны" "docker exec freepbx-server asterisk -rx 'dialplan show from-internal-custom' | grep -q '9999'"

# Тест 8: Проверка переменных окружения
run_test "Переменные окружения LiveKit" "docker exec livekit-agent printenv | grep -q 'LIVEKIT_URL'"

# Тест 9: Проверка логов агента
run_test "Логи агента доступны" "docker logs livekit-agent 2>&1 | grep -q 'Запуск'"

# Тест 10: Проверка статистики агента
run_test "Статистика агента" "curl -s http://localhost:8081/stats | grep -q 'active_channels'"

log "📊 === РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ ==="
log "✅ Пройдено тестов: $test_passed"
if [ $test_failed -gt 0 ]; then
    error "❌ Провалено тестов: $test_failed"
else
    log "🎉 Все тесты пройдены успешно!"
fi

# Детальная информация о системе
log "📋 === ДЕТАЛЬНАЯ ИНФОРМАЦИЯ ==="

info "🐳 Статус контейнеров:"
docker-compose ps

info "🤖 Статус LiveKit агента:"
curl -s http://localhost:8081/status | jq . 2>/dev/null || curl -s http://localhost:8081/status

info "📞 ARI приложения:"
docker exec freepbx-server asterisk -rx "ari show apps" 2>/dev/null || echo "ARI недоступен"

info "📋 Диалплан (from-novofon):"
docker exec freepbx-server asterisk -rx "dialplan show from-novofon" 2>/dev/null | head -10 || echo "Диалплан недоступен"

info "🔊 Последние логи агента:"
docker logs livekit-agent --tail=5 2>/dev/null || echo "Логи недоступны"

log "🧪 === ТЕСТИРОВАНИЕ ЗАВЕРШЕНО ==="

if [ $test_failed -gt 0 ]; then
    error "Некоторые тесты провалились. Проверьте конфигурацию."
    exit 1
else
    log "Система готова к работе!"
    exit 0
fi