#!/bin/bash

# Скрипт обновления системы для работы с аудио мостом
# Обновляет конфигурации и перезапускает сервисы

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

# Проверка, что скрипт запущен из корневой директории проекта
if [ ! -f "docker-compose.yml" ]; then
    error "Скрипт должен быть запущен из корневой директории проекта"
    exit 1
fi

log "🚀 === ОБНОВЛЕНИЕ СИСТЕМЫ ДЛЯ АУДИО МОСТА ==="

# Остановка старых контейнеров
log "🛑 Остановка контейнеров..."
docker-compose down

# Пересборка образов
log "🔨 Пересборка образов..."
docker-compose build --no-cache livekit-agent

# Обновление конфигураций Asterisk
log "📋 Обновление конфигураций Asterisk..."

# Создаем резервную копию старых конфигураций
if [ -d "./data/asterisk/config" ]; then
    log "💾 Создание резервной копии конфигураций..."
    cp -r ./data/asterisk/config ./data/asterisk/config.backup.$(date +%Y%m%d_%H%M%S)
fi

# Создаем директории если их нет
mkdir -p ./data/asterisk/config
mkdir -p ./data/logs/agent
mkdir -p ./data/agent

# Копируем обновленный диалплан
log "📋 Копирование обновленного диалплана..."
cp ./configs/dialplan/extensions_dialplan.conf ./data/asterisk/config/

# Проверка переменных окружения
log "🔍 Проверка переменных окружения..."

if [ ! -f ".env" ]; then
    warn "Файл .env не найден. Создайте его на основе .env.example"
    cp .env.example .env
    warn "Отредактируйте файл .env с вашими настройками"
fi

# Проверяем обязательные переменные
required_vars=(
    "LIVEKIT_URL"
    "LIVEKIT_API_KEY"
    "LIVEKIT_API_SECRET"
    "OPENAI_API_KEY"
    "DEEPGRAM_API_KEY"
    "CARTESIA_API_KEY"
)

missing_vars=()
for var in "${required_vars[@]}"; do
    if ! grep -q "^${var}=" .env 2>/dev/null || grep -q "^${var}=$" .env 2>/dev/null; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -gt 0 ]; then
    error "Отсутствуют или пусты следующие переменные в .env:"
    for var in "${missing_vars[@]}"; do
        error "  - $var"
    done
    error "Заполните эти переменные перед продолжением"
    exit 1
fi

log "✅ Все обязательные переменные окружения настроены"

# Запуск обновленной системы
log "🚀 Запуск обновленной системы..."
docker-compose up -d

# Ожидание готовности сервисов
log "⏳ Ожидание готовности сервисов..."

# Ждем FreePBX
log "📞 Ожидание FreePBX..."
timeout=300
counter=0
while [ $counter -lt $timeout ]; do
    if docker exec freepbx-server asterisk -rx "core show version" >/dev/null 2>&1; then
        log "✅ FreePBX готов"
        break
    fi
    echo -n "."
    sleep 5
    counter=$((counter + 5))
done

if [ $counter -ge $timeout ]; then
    error "FreePBX не готов после $timeout секунд"
    exit 1
fi

# Ждем LiveKit агента
log "🤖 Ожидание LiveKit агента..."
counter=0
while [ $counter -lt 60 ]; do
    if curl -s http://localhost:8081/health >/dev/null 2>&1; then
        log "✅ LiveKit агент готов"
        break
    fi
    echo -n "."
    sleep 2
    counter=$((counter + 2))
done

if [ $counter -ge 60 ]; then
    warn "LiveKit агент не отвечает на health check, но продолжаем..."
fi

# Применение конфигураций Asterisk
log "🔧 Применение конфигураций Asterisk..."

# Копируем диалплан в контейнер
docker cp ./configs/dialplan/extensions_dialplan.conf freepbx-server:/tmp/

# Добавляем диалплан к конфигурации
docker exec freepbx-server bash -c '
    if ! grep -q "from-novofon" /etc/asterisk/extensions_custom.conf; then
        echo "" >> /etc/asterisk/extensions_custom.conf
        cat /tmp/extensions_dialplan.conf >> /etc/asterisk/extensions_custom.conf
        echo "Диалплан добавлен"
    else
        echo "Диалплан уже существует"
    fi
'

# Настройка ARI
log "🔧 Настройка ARI..."
docker exec freepbx-server bash -c 'cat > /etc/asterisk/ari.conf << EOF
[general]
enabled = yes
pretty = yes
allowed_origins = *

[livekit-agent]
type = user
read_only = no
password = livekit_ari_secret
EOF'

# Перезагрузка конфигураций
log "🔄 Перезагрузка конфигураций Asterisk..."
docker exec freepbx-server asterisk -rx "dialplan reload"
docker exec freepbx-server asterisk -rx "module reload res_ari.so"

# Проверка статуса системы
log "🔍 Проверка статуса системы..."

# Проверка ARI
if docker exec freepbx-server asterisk -rx "ari show apps" | grep -q "livekit-agent"; then
    log "✅ ARI приложение зарегистрировано"
else
    warn "⚠️ ARI приложение не зарегистрировано"
fi

# Проверка диалплана
if docker exec freepbx-server asterisk -rx "dialplan show from-novofon" | grep -q "79952227978"; then
    log "✅ Диалплан загружен"
else
    warn "⚠️ Диалплан не найден"
fi

# Проверка LiveKit агента
if curl -s http://localhost:8081/health | grep -q "healthy"; then
    log "✅ LiveKit агент работает"
else
    warn "⚠️ LiveKit агент не отвечает"
fi

# Показать статус контейнеров
log "📊 Статус контейнеров:"
docker-compose ps

# Показать логи агента
log "📋 Последние логи LiveKit агента:"
docker logs livekit-agent --tail=10

log "🎉 === ОБНОВЛЕНИЕ ЗАВЕРШЕНО ==="
log ""
log "📞 Система готова к работе!"
log "🌐 Health check: http://localhost:8081/health"
log "📊 Статистика: http://localhost:8081/stats"
log "🔍 Мониторинг: docker logs livekit-agent -f"
log ""
log "🧪 Тестовые номера:"
log "  • 9999 - тест AI агента"
log "  • 8888 - тест эхо"
log "  • 7777 - тест воспроизведения"
log ""
log "📱 Основной номер: ${NOVOFON_NUMBER:-+79952227978}"