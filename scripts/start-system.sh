#!/bin/bash

# Скрипт автоматического запуска и настройки VoIP системы
# Решает проблему потери конфигураций при перезапуске
#
# Использование:
#   ./scripts/start-system.sh           - обычный запуск
#   ./scripts/start-system.sh --clean   - запуск с очисткой volumes
#   ./scripts/start-system.sh -c        - то же самое (короткая форма)

set -e

# Показать справку
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Скрипт автоматического запуска VoIP системы"
    echo ""
    echo "Использование:"
    echo "  $0 [ОПЦИИ]"
    echo ""
    echo "Опции:"
    echo "  -c, --clean    Очистить volumes перед запуском"
    echo "  -h, --help     Показать эту справку"
    echo ""
    echo "Примеры:"
    echo "  $0              # Обычный запуск"
    echo "  $0 --clean      # Запуск с очисткой данных"
    exit 0
fi

# Параметры командной строки
CLEAN_VOLUMES=false
if [ "$1" = "--clean" ] || [ "$1" = "-c" ]; then
    CLEAN_VOLUMES=true
    shift
fi

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

# Очистка volumes
clean_volumes() {
    log "🧹 Очистка старых volumes..."
    
    # Остановка и удаление контейнеров с volumes
    if docker-compose ps -q | grep -q .; then
        log "Остановка контейнеров..."
        docker-compose down -v
    fi
    
    # Удаление неиспользуемых volumes
    log "Удаление неиспользуемых volumes..."
    docker volume prune -f
    
    log "✅ Volumes очищены"
}

# Подготовка инфраструктуры
prepare_infrastructure() {
    log "🔧 Подготовка инфраструктуры..."
    
    # Создание внешней сети traefik-public если она не существует
    if ! docker network ls | grep -q "traefik-public"; then
        log "Создание сети traefik-public..."
        docker network create traefik-public
        log "✅ Сеть traefik-public создана"
    else
        log "✅ Сеть traefik-public уже существует"
    fi
}

# Проверка готовности контейнера
wait_for_container() {
    local container_name=$1
    local max_attempts=60
    local attempt=0
    
    log "Ожидание готовности контейнера $container_name..."
    
    while [ $attempt -lt $max_attempts ]; do
        if docker exec $container_name echo "ready" >/dev/null 2>&1; then
            log "✅ Контейнер $container_name готов"
            return 0
        fi
        
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    error "❌ Контейнер $container_name не готов после $max_attempts попыток"
    return 1
}

# Проверка готовности FreePBX
wait_for_freepbx() {
    local max_attempts=120  # 20 минут максимум
    local attempt=0
    
    log "Ожидание завершения установки FreePBX (может занять до 30 минут)..."
    
    while [ $attempt -lt $max_attempts ]; do
        # Проверяем здоровье контейнера
        local health_status=$(docker inspect freepbx-server --format='{{.State.Health.Status}}' 2>/dev/null || echo "none")
        
        if [ "$health_status" = "healthy" ]; then
            log "✅ FreePBX контейнер здоров"
            break
        fi
        
        # Проверяем логи на предмет завершения установки
        if docker logs freepbx-server 2>&1 | grep -q "FreePBX installation complete" || \
           docker logs freepbx-server 2>&1 | grep -q "Starting Asterisk" || \
           docker logs freepbx-server 2>&1 | grep -q "Asterisk Ready"; then
            log "✅ FreePBX установка завершена"
            break
        fi
        
        # Показываем прогресс каждые 30 секунд
        if [ $((attempt % 6)) -eq 0 ]; then
            log "⏳ Ожидание FreePBX... ($((attempt * 10 / 60)) мин)"
        fi
        
        echo -n "."
        sleep 10
        ((attempt++))
    done
    
    if [ $attempt -ge $max_attempts ]; then
        error "❌ FreePBX не готов после $((max_attempts * 10 / 60)) минут"
        return 1
    fi
    
    return 0
}

# Проверка готовности Asterisk
wait_for_asterisk() {
    local max_attempts=60
    local attempt=0
    
    log "Ожидание готовности Asterisk..."
    
    while [ $attempt -lt $max_attempts ]; do
        if docker exec freepbx-server asterisk -rx "core show version" >/dev/null 2>&1; then
            log "✅ Asterisk готов"
            # Дополнительное ожидание для полной загрузки модулей
            log "⏳ Ожидание полной загрузки модулей..."
            sleep 15
            return 0
        fi
        
        echo -n "."
        sleep 5
        ((attempt++))
    done
    
    error "❌ Asterisk не готов после $max_attempts попыток"
    return 1
}

# Восстановление диалплана
restore_dialplan() {
    log "📋 Проверка диалплана..."
    
    # Проверяем, существует ли уже контекст from-novofon
    if docker exec freepbx-server asterisk -rx "dialplan show from-novofon" 2>/dev/null | grep -q "79952227978"; then
        log "✅ Диалплан уже настроен и работает"
        return 0
    fi
    
    log "🔧 Диалплан требует восстановления..."
    
    local dialplan_file="./configs/dialplan/extensions_dialplan.conf"
    
    # Проверка существования файла диалплана
    if [ ! -f "$dialplan_file" ]; then
        error "❌ Файл диалплана не найден: $dialplan_file"
        return 1
    fi
    
    # Копирование файла диалплана в контейнер
    log "📋 Копирование диалплана из файла: $dialplan_file"
    if docker cp "$dialplan_file" freepbx-server:/tmp/extensions_dialplan.conf; then
        log "✅ Файл диалплана скопирован в контейнер"
    else
        error "❌ Ошибка копирования файла диалплана"
        return 1
    fi
    
    # Проверяем, нет ли уже дублирующих контекстов в extensions_custom.conf
    if docker exec freepbx-server grep -q "\[from-novofon\]" /etc/asterisk/extensions_custom.conf; then
        log "⚠️ Контекст from-novofon уже существует в extensions_custom.conf"
        # Просто перезагружаем диалплан
        docker exec freepbx-server asterisk -rx "dialplan reload" >/dev/null 2>&1
    else
        # Добавление диалплана к существующему файлу конфигурации
        log "🔧 Добавление диалплана в конфигурацию..."
        docker exec freepbx-server bash -c 'cat /tmp/extensions_dialplan.conf >> /etc/asterisk/extensions_custom.conf'
        
        # Перезагрузка диалплана
        docker exec freepbx-server asterisk -rx "dialplan reload" >/dev/null 2>&1
    fi
    
    # Проверка диалплана
    if docker exec freepbx-server asterisk -rx "dialplan show from-novofon" 2>/dev/null | grep -q "79952227978"; then
        log "✅ Диалплан восстановлен из файла: $dialplan_file"
        return 0
    else
        error "❌ Ошибка восстановления диалплана"
        return 1
    fi
}

# Применение конфигураций Asterisk
apply_asterisk_configs() {
    log "📋 Применение конфигураций Asterisk..."
    
    # Настройка ARI конфигурации с паролем
    log "🔧 Настройка ARI конфигурации..."
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
    
    # Перезагрузка модуля ARI
    docker exec freepbx-server asterisk -rx "module reload res_ari.so" >/dev/null 2>&1
    
    # Запуск скрипта инициализации внутри контейнера
    if docker exec freepbx-server /usr/local/bin/init-asterisk-config.sh; then
        log "✅ Конфигурации Asterisk применены"
    else
        error "❌ Ошибка применения конфигураций Asterisk"
        return 1
    fi
    
    # Восстановление диалплана
    if ! restore_dialplan; then
        error "❌ Ошибка восстановления диалплана"
        return 1
    fi
    
    return 0
}

# Проверка готовности LiveKit агента
wait_for_livekit_agent() {
    local max_attempts=30
    local attempt=0
    
    log "🤖 Ожидание готовности LiveKit агента..."
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s http://localhost:8081/health >/dev/null 2>&1; then
            log "✅ LiveKit агент готов"
            return 0
        fi
        
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    warn "⚠️ LiveKit агент не отвечает на health check после $((max_attempts * 2)) секунд"
    return 1
}

# Проверка ARI интеграции
check_ari_integration() {
    log "🔍 Проверка ARI интеграции..."
    
    local max_attempts=15
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if docker exec freepbx-server asterisk -rx "ari show apps" 2>/dev/null | grep -q "livekit-agent"; then
            log "✅ ARI приложение зарегистрировано"
            return 0
        fi
        
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    warn "⚠️ ARI приложение не зарегистрировано после $((max_attempts * 2)) секунд"
    
    # Показываем логи для диагностики
    log "📋 Логи LiveKit агента:"
    docker logs livekit-agent --tail=10 2>/dev/null || true
    
    return 1
}

# Проверка статуса системы
check_system_status() {
    log "🔍 Проверка статуса системы..."
    
    local checks_passed=0
    local total_checks=4
    
    # Проверка SIP регистрации
    if docker exec freepbx-server asterisk -rx "pjsip show registrations" | grep -q "Registered"; then
        log "✅ SIP регистрация с Novofon активна"
        ((checks_passed++))
    else
        warn "⚠️ SIP регистрация с Novofon не найдена"
    fi
    
    # Проверка PJSIP endpoints
    local endpoints_output=$(docker exec freepbx-server asterisk -rx "pjsip show endpoints" 2>/dev/null || echo "")
    local endpoints=$(echo "$endpoints_output" | grep -c "Endpoint:" 2>/dev/null || echo "0")
    if [ "$endpoints" -gt 0 ]; then
        log "✅ PJSIP endpoints настроены ($endpoints)"
        ((checks_passed++))
    else
        warn "⚠️ PJSIP endpoints не найдены"
    fi
    
    # Проверка LiveKit агента
    if docker logs livekit-agent --tail=5 2>&1 | grep -q "registered worker"; then
        log "✅ LiveKit агент подключен"
        ((checks_passed++))
    else
        warn "⚠️ LiveKit агент не подключен"
    fi
    
    # Проверка ARI приложения
    if docker exec freepbx-server asterisk -rx "ari show apps" | grep -q "livekit-agent"; then
        log "✅ ARI приложение зарегистрировано"
        ((checks_passed++))
    else
        warn "⚠️ ARI приложение не зарегистрировано"
    fi
    
    # Итоговый результат
    log "📊 Проверок пройдено: $checks_passed из $total_checks"
    
    if [ $checks_passed -eq $total_checks ]; then
        log "🎉 Система полностью готова к работе!"
        return 0
    elif [ $checks_passed -ge 2 ]; then
        warn "⚠️ Система частично готова. Некоторые компоненты требуют внимания."
        return 0
    else
        error "❌ Система не готова. Требуется диагностика."
        return 1
    fi
}

# Показать информацию о системе
show_system_info() {
    log "=== 📋 Информация о системе ==="
    
    echo ""
    echo "📞 Номер телефона: ${NOVOFON_NUMBER:-+79952227978}"
    echo "🌐 LiveKit URL: ${LIVEKIT_URL:-не настроен}"
    echo "🔗 SIP сервер: sip.novofon.ru:5060"
    echo "🏠 Домен: ${MY_DOMAIN:-stellaragents.ru}"
    echo "🌍 Публичный IP: ${MY_PUBLIC_IP:-94.131.122.253}"
    
    echo ""
    echo "📊 Статус контейнеров:"
    docker-compose ps
    
    echo ""
    echo "🛠️ Полезные команды:"
    echo "  - Мониторинг звонков: ./scripts/monitor_incoming_calls.sh"
    echo "  - Логи LiveKit: docker logs livekit-agent -f"
    echo "  - Консоль Asterisk: docker exec freepbx-server asterisk -rvvv"
    echo "  - Тест системы: ./scripts/test_system.sh"
}

# Основная функция
main() {
    log "🚀 === АВТОМАТИЧЕСКИЙ ЗАПУСК VoIP СИСТЕМЫ ==="
    
    # Очистка volumes если запрошено
    if [ "$CLEAN_VOLUMES" = true ]; then
        clean_volumes
    fi
    
    # Подготовка инфраструктуры
    prepare_infrastructure
    
    # Запуск контейнеров
    log "📦 Запуск контейнеров..."
    docker-compose up -d
    
    # Ожидание готовности LiveKit агента
    if ! wait_for_container "livekit-agent"; then
        error "Не удалось запустить LiveKit агент"
        exit 1
    fi
    
    # Ожидание завершения установки FreePBX
    if ! wait_for_freepbx; then
        error "FreePBX не готов к работе"
        exit 1
    fi
    
    # Ожидание готовности Asterisk
    if ! wait_for_asterisk; then
        error "Asterisk не готов к работе"
        exit 1
    fi
    
    # Применение конфигураций
    if ! apply_asterisk_configs; then
        error "Не удалось применить конфигурации Asterisk"
        exit 1
    fi
    
    # Пауза для стабилизации системы
    log "⏳ Ожидание стабилизации системы..."
    sleep 20
    
    # Ожидание готовности LiveKit агента
    if ! wait_for_livekit_agent; then
        warn "LiveKit агент не готов, но продолжаем..."
    fi
    
    # Проверка ARI интеграции
    if ! check_ari_integration; then
        warn "ARI интеграция не готова, но продолжаем..."
    fi
    
    # Финальная проверка
    sleep 5
    check_system_status
    
    # Показать информацию о системе
    show_system_info
    
    log "🎯 === СИСТЕМА ГОТОВА К РАБОТЕ ==="
}

# Обработка сигналов
trap 'error "Received interrupt signal"; exit 1' INT TERM

# Запуск основной функции
main "$@"