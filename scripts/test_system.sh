#!/bin/bash

# Тестирование VoIP системы
# Автор: Kiro AI Assistant

set -e

echo "=== Тестирование VoIP системы ==="

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ERROR: $1${NC}"
}

# Проверка статуса контейнеров
log "Проверка статуса контейнеров..."
docker-compose ps

echo ""

# Проверка SIP регистрации
log "Проверка SIP регистрации..."
docker exec freepbx-server asterisk -rx "pjsip show registrations"

echo ""

# Проверка endpoints
log "Проверка SIP endpoints..."
docker exec freepbx-server asterisk -rx "pjsip show endpoints" | head -20

echo ""

# Проверка LiveKit агента
log "Проверка LiveKit агента..."
if docker logs livekit-agent --tail=5 2>&1 | grep -q "registered worker"; then
    log "✅ LiveKit агент подключен"
else
    warn "⚠️ LiveKit агент может быть не подключен"
fi

echo ""

# Проверка ARI
log "Проверка ARI..."
if docker exec freepbx-server asterisk -rx "ari show apps" | grep -q "livekit-agent"; then
    log "✅ ARI приложение зарегистрировано"
else
    warn "⚠️ ARI приложение не найдено"
fi

echo ""

# Тест диалплана
log "Тестирование диалплана..."
docker exec freepbx-server asterisk -rx "dialplan show from-novofon" | head -10

echo ""

# Показать активные каналы
log "Активные каналы:"
docker exec freepbx-server asterisk -rx "core show channels"

echo ""

# Показать статистику
log "=== Итоговый статус ==="
echo "📞 Номер: +79952227978"
echo "🌐 LiveKit: $(echo $LIVEKIT_URL | cut -d'/' -f3)"
echo "🔗 SIP сервер: sip.novofon.ru:5060"

echo ""
echo "📋 Для мониторинга входящих звонков:"
echo "  ./scripts/monitor_incoming_calls.sh"

echo ""
echo "📋 Для проверки логов:"
echo "  docker logs livekit-agent -f"
echo "  docker exec freepbx-server asterisk -rvvv"