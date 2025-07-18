#!/bin/bash

# Универсальный скрипт управления VoIP системой
# Объединяет все функции: запуск, обновление, тестирование, очистку
#
# Использование:
#   ./scripts/start-system.sh                    - обычный запуск
#   ./scripts/start-system.sh --clean           - запуск с очисткой volumes
#   ./scripts/start-system.sh --full-clean      - полная очистка системы
#   ./scripts/start-system.sh --update          - обновление до аудио моста
#   ./scripts/start-system.sh --test            - тестирование системы
#   ./scripts/start-system.sh --rebuild         - пересборка образов

set -e

# Показать справку
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "🎤 Универсальный скрипт управления VoIP системой"
    echo ""
    echo "Использование:"
    echo "  $0 [РЕЖИМ] [ОПЦИИ]"
    echo ""
    echo "Режимы работы:"
    echo "  (без параметров)   Обычный запуск системы"
    echo "  --clean, -c        Запуск с очисткой volumes"
    echo "  --full-clean       Полная очистка системы (УДАЛЯЕТ ВСЕ ДАННЫЕ!)"
    echo "  --update           Обновление до версии с аудио мостом"
    echo "  --test             Тестирование всех компонентов системы"
    echo "  --rebuild          Пересборка Docker образов"
    echo "  --status           Показать статус системы"
    echo ""
    echo "Примеры:"
    echo "  $0                 # Обычный запуск"
    echo "  $0 --clean         # Запуск с очисткой"
    echo "  $0 --full-clean    # Полная очистка (осторожно!)"
    echo "  $0 --update        # Обновление системы"
    echo "  $0 --test          # Тестирование"
    echo ""
    echo "🎯 Для первой установки рекомендуется:"
    echo "  $0 --full-clean && $0 --update"
    exit 0
fi

# Определение режима работы
MODE="start"
CLEAN_VOLUMES=false
FULL_CLEAN=false
UPDATE_MODE=false
TEST_MODE=false
REBUILD_MODE=false
STATUS_MODE=false

case "$1" in
    --clean|-c)
        MODE="start"
        CLEAN_VOLUMES=true
        ;;
    --full-clean)
        MODE="full-clean"
        FULL_CLEAN=true
        ;;
    --update)
        MODE="update"
        UPDATE_MODE=true
        ;;
    --test)
        MODE="test"
        TEST_MODE=true
        ;;
    --rebuild)
        MODE="rebuild"
        REBUILD_MODE=true
        ;;
    --status)
        MODE="status"
        STATUS_MODE=true
        ;;
    "")
        MODE="start"
        ;;
    *)
        echo "❌ Неизвестный параметр: $1"
        echo "Используйте --help для справки"
        exit 1
        ;;
esac

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
    if docker-compose ps -q 2>/dev/null | grep -q .; then
        log "Остановка контейнеров..."
        docker-compose down -v --remove-orphans
    fi
    
    # Удаление всех volumes проекта
    log "Удаление volumes проекта..."
    docker volume ls -q | grep -E "(voip-platform|freepbx|livekit|traefik|redis)" | xargs -r docker volume rm -f 2>/dev/null || true
    
    # Удаление неиспользуемых volumes
    log "Удаление неиспользуемых volumes..."
    docker volume prune -f
    
    # Удаление неиспользуемых сетей
    log "Удаление неиспользуемых сетей..."
    docker network prune -f
    
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
    
    # Создаем файл extensions_custom.conf если его нет
    docker exec freepbx-server bash -c '
        if [ ! -f /etc/asterisk/extensions_custom.conf ]; then
            touch /etc/asterisk/extensions_custom.conf
            echo "Файл extensions_custom.conf создан"
        fi
    '
    
    # Проверяем, нет ли уже дублирующих контекстов в extensions_custom.conf
    if docker exec freepbx-server grep -q "\[from-novofon\]" /etc/asterisk/extensions_custom.conf 2>/dev/null; then
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

# Функция полной очистки системы
full_cleanup() {
    log "🧹 === ПОЛНАЯ ОЧИСТКА VOIP СИСТЕМЫ ==="
    
    if [ "$FULL_CLEAN" != true ]; then
        warn "⚠️  ВНИМАНИЕ: Этот режим удалит ВСЕ данные VoIP системы!"
        warn "⚠️  Включая базы данных, конфигурации, логи и записи звонков!"
        echo ""
        read -p "Вы уверены? Введите 'YES' для подтверждения: " confirmation
        
        if [ "$confirmation" != "YES" ]; then
            log "Операция отменена"
            exit 0
        fi
    fi
    
    # Остановка всех контейнеров
    log "🛑 Остановка всех контейнеров..."
    docker-compose down -v --remove-orphans 2>/dev/null || true
    
    # Удаление образов проекта
    log "🗑️ Удаление образов проекта..."
    docker images | grep -E "(voip-platform|freepbx|livekit|tiredofit)" | awk '{print $3}' | sort -u | xargs -r docker rmi -f 2>/dev/null || true
    
    # Удаление volumes
    log "📦 Удаление всех volumes..."
    docker volume ls -q | grep -E "(voip-platform|freepbx|livekit|traefik|redis|asterisk|mariadb)" | xargs -r docker volume rm -f 2>/dev/null || true
    
    # Полная очистка Docker
    log "🧽 Полная очистка Docker..."
    docker system prune -af --volumes
    
    # Удаление данных файловой системы
    log "🗂️ Удаление данных файловой системы..."
    sudo rm -rf ./data/* 2>/dev/null || rm -rf ./data/* 2>/dev/null || true
    sudo rm -rf ./volumes/* 2>/dev/null || rm -rf ./volumes/* 2>/dev/null || true
    
    # Создание чистой структуры
    log "📁 Создание чистой структуры директорий..."
    mkdir -p ./data/{freepbx,asterisk,logs,agent}
    mkdir -p ./data/logs/{agent,asterisk,freepbx}
    mkdir -p ./volumes/{asterisk-db,recordings}
    mkdir -p ./ssl/{certs,private}
    
    log "✅ Полная очистка завершена"
}

# Функция обновления системы
update_system() {
    log "🔄 === ОБНОВЛЕНИЕ СИСТЕМЫ ДО АУДИО МОСТА ==="
    
    # Проверка переменных окружения
    check_environment_variables
    
    # Полная очистка для чистой установки
    log "🧹 Полная очистка для чистой установки..."
    FULL_CLEAN=true
    full_cleanup
    
    # Пересборка образов
    log "🔨 Пересборка образов..."
    docker-compose build --no-cache livekit-agent
    
    # Запуск обновленной системы
    log "🚀 Запуск обновленной системы..."
    start_system
    
    log "🎉 === ОБНОВЛЕНИЕ ЗАВЕРШЕНО ==="
}

# Функция тестирования системы
test_system() {
    log "🧪 === ТЕСТИРОВАНИЕ СИСТЕМЫ ==="
    
    local tests_passed=0
    local tests_failed=0
    
    # Тест 1: Контейнеры
    if docker-compose ps | grep -q 'Up'; then
        log "✅ PASSED: Контейнеры запущены"
        ((tests_passed++))
    else
        error "❌ FAILED: Контейнеры не запущены"
        ((tests_failed++))
    fi
    
    # Тест 2: FreePBX
    if docker exec freepbx-server asterisk -rx 'core show version' >/dev/null 2>&1; then
        log "✅ PASSED: FreePBX доступен"
        ((tests_passed++))
    else
        error "❌ FAILED: FreePBX недоступен"
        ((tests_failed++))
    fi
    
    # Тест 3: LiveKit агент
    if curl -s http://localhost:8081/health | grep -q 'healthy' 2>/dev/null; then
        log "✅ PASSED: LiveKit агент работает"
        ((tests_passed++))
    else
        error "❌ FAILED: LiveKit агент не отвечает"
        ((tests_failed++))
    fi
    
    # Тест 4: ARI приложение
    if docker exec freepbx-server asterisk -rx 'ari show apps' | grep -q 'livekit-agent' 2>/dev/null; then
        log "✅ PASSED: ARI приложение зарегистрировано"
        ((tests_passed++))
    else
        error "❌ FAILED: ARI приложение не зарегистрировано"
        ((tests_failed++))
    fi
    
    # Тест 5: Диалплан
    if docker exec freepbx-server asterisk -rx 'dialplan show from-novofon' | grep -q '79952227978' 2>/dev/null; then
        log "✅ PASSED: Диалплан загружен"
        ((tests_passed++))
    else
        error "❌ FAILED: Диалплан не найден"
        ((tests_failed++))
    fi
    
    log "📊 === РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ ==="
    log "✅ Пройдено тестов: $tests_passed"
    if [ $tests_failed -gt 0 ]; then
        error "❌ Провалено тестов: $tests_failed"
        return 1
    else
        log "🎉 Все тесты пройдены успешно!"
        return 0
    fi
}

# Функция пересборки образов
rebuild_images() {
    log "🔨 === ПЕРЕСБОРКА ОБРАЗОВ ==="
    
    # Остановка контейнеров
    docker-compose down
    
    # Удаление старых образов
    docker images | grep -E "(voip-platform)" | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || true
    
    # Пересборка
    docker-compose build --no-cache
    
    log "✅ Образы пересобраны"
}

# Функция показа статуса
show_status() {
    log "📊 === СТАТУС СИСТЕМЫ ==="
    
    echo ""
    info "🐳 Статус контейнеров:"
    docker-compose ps 2>/dev/null || echo "Контейнеры не запущены"
    
    echo ""
    info "🤖 Статус LiveKit агента:"
    curl -s http://localhost:8081/status 2>/dev/null | head -10 || echo "LiveKit агент недоступен"
    
    echo ""
    info "📞 ARI приложения:"
    docker exec freepbx-server asterisk -rx "ari show apps" 2>/dev/null || echo "ARI недоступен"
    
    echo ""
    info "🔊 Последние логи агента:"
    docker logs livekit-agent --tail=5 2>/dev/null || echo "Логи недоступны"
}

# Функция проверки переменных окружения
check_environment_variables() {
    log "🔍 Проверка переменных окружения..."
    
    if [ ! -f ".env" ]; then
        warn "Файл .env не найден. Создаю из .env.example"
        cp .env.example .env
        warn "⚠️ Отредактируйте файл .env с вашими настройками!"
    fi
    
    local required_vars=(
        "LIVEKIT_URL"
        "LIVEKIT_API_KEY"
        "LIVEKIT_API_SECRET"
        "OPENAI_API_KEY"
        "DEEPGRAM_API_KEY"
        "CARTESIA_API_KEY"
    )
    
    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" .env 2>/dev/null || grep -q "^${var}=$" .env 2>/dev/null; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        error "❌ Отсутствуют переменные в .env:"
        for var in "${missing_vars[@]}"; do
            error "  - $var"
        done
        error "Заполните эти переменные перед продолжением"
        exit 1
    fi
    
    log "✅ Все переменные окружения настроены"
}

# Функция запуска системы
start_system() {
    log "🚀 === ЗАПУСК VoIP СИСТЕМЫ ==="
    
    # Очистка если запрошено
    if [ "$CLEAN_VOLUMES" = true ]; then
        clean_volumes
    fi
    
    # Подготовка инфраструктуры
    prepare_infrastructure
    
    # Запуск контейнеров
    log "📦 Запуск контейнеров..."
    docker-compose up -d
    
    # Ожидание готовности компонентов
    wait_for_components
    
    # Применение конфигураций
    apply_asterisk_configs
    
    # Финальная проверка
    check_system_status
    
    # Показать информацию
    show_system_info
    
    log "🎯 === СИСТЕМА ГОТОВА К РАБОТЕ ==="
}

# Функция ожидания компонентов
wait_for_components() {
    # LiveKit агент
    if ! wait_for_livekit_agent; then
        warn "LiveKit агент не готов, но продолжаем..."
    fi
    
    # FreePBX
    if ! wait_for_freepbx; then
        error "FreePBX не готов к работе"
        exit 1
    fi
    
    # Asterisk
    if ! wait_for_asterisk; then
        error "Asterisk не готов к работе"
        exit 1
    fi
    
    # ARI интеграция
    if ! check_ari_integration; then
        warn "ARI интеграция не готова, но продолжаем..."
    fi
}

# Основная функция
main() {
    case "$MODE" in
        "start")
            start_system
            ;;
        "full-clean")
            full_cleanup
            ;;
        "update")
            update_system
            ;;
        "test")
            test_system
            ;;
        "rebuild")
            rebuild_images
            ;;
        "status")
            show_status
            ;;
        *)
            error "Неизвестный режим: $MODE"
            exit 1
            ;;
    esac
}

# Обработка сигналов
trap 'error "Received interrupt signal"; exit 1' INT TERM

# Запуск основной функции
main "$@"