#!/bin/bash

# Менеджер тестовых сред для VoIP платформы
# Обеспечивает безопасное тестирование различных архитектур

set -euo pipefail

# Конфигурация
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTING_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
PROJECT_ROOT="$(dirname "$TESTING_ROOT")"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Логирование
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка зависимостей
check_dependencies() {
    local deps=("docker" "docker-compose" "jq")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "Зависимость '$dep' не найдена"
            exit 1
        fi
    done
}

# Список доступных сред
list_environments() {
    log_info "Доступные тестовые среды:"
    echo "  env-a: Текущая архитектура (Asterisk + ARI + LiveKit)"
    echo "  env-b: Прямая интеграция (Asterisk + Python Agent)"
    echo "  env-c: Микросервисная архитектура (Message Queue)"
}

# Проверка изоляции среды
check_isolation() {
    local env_name="$1"
    local env_dir="$TESTING_ROOT/$env_name"
    
    if [ ! -d "$env_dir" ]; then
        log_error "Среда '$env_name' не существует"
        return 1
    fi
    
    log_info "Проверка изоляции среды '$env_name'..."
    
    # Проверка портов
    local compose_file="$env_dir/docker-compose.test-${env_name#env-}.yml"
    if [ -f "$compose_file" ]; then
        log_info "✓ Docker Compose файл найден"
    else
        log_warning "Docker Compose файл не найден: $compose_file"
    fi
    
    # Проверка конфигурации
    if [ -d "$env_dir/configs" ]; then
        log_info "✓ Директория конфигураций найдена"
    else
        log_warning "Директория конфигураций не найдена"
    fi
    
    # Проверка переменных окружения
    local env_file="$env_dir/.env.test"
    if [ -f "$env_file" ]; then
        log_info "✓ Файл переменных окружения найден"
    else
        log_warning "Файл переменных окружения не найден: $env_file"
    fi
}

# Создание тестовой среды
create_environment() {
    local env_name="$1"
    local env_dir="$TESTING_ROOT/$env_name"
    
    log_info "Создание тестовой среды '$env_name'..."
    
    # Создание директорий
    mkdir -p "$env_dir"/{configs,results,logs}
    
    # Создание базового docker-compose файла
    create_compose_file "$env_name"
    
    # Создание файла переменных окружения
    create_env_file "$env_name"
    
    # Создание базовых конфигураций
    create_base_configs "$env_name"
    
    log_success "Тестовая среда '$env_name' создана"
}

# Создание docker-compose файла
create_compose_file() {
    local env_name="$1"
    local env_suffix="${env_name#env-}"
    local compose_file="$TESTING_ROOT/$env_name/docker-compose.test-$env_suffix.yml"
    
    cat > "$compose_file" << EOF
# Docker Compose для тестовой среды $env_name
# Изолированная среда для тестирования архитектуры

version: '3.8'

services:
  traefik-test-$env_suffix:
    image: traefik:v3.4
    container_name: traefik-test-$env_suffix
    restart: unless-stopped
    ports:
      - "808$env_suffix:80"      # HTTP (8081, 8082, 8083)
      - "844$env_suffix:443"     # HTTPS (8441, 8442, 8443)
      - "808${env_suffix}0:8080" # Dashboard (8080, 8081, 8082)
      - "508$env_suffix:5060/udp" # SIP UDP (5081, 5082, 5083)
      - "516$env_suffix:5160/tcp" # SIP TCP (5161, 5162, 5163)
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - test-$env_suffix-traefik-certs:/letsencrypt
      - ./configs/traefik:/etc/traefik:ro
    networks:
      - test-$env_suffix-network
    environment:
      - TZ=Europe/Moscow

  asterisk-test-$env_suffix:
    build:
      context: ../../docker/freepbx
      dockerfile: Dockerfile
    container_name: asterisk-test-$env_suffix
    restart: unless-stopped
    expose:
      - "80"
      - "5060"
      - "5160"
    volumes:
      - test-$env_suffix-asterisk-data:/data
      - ./configs/asterisk:/etc/asterisk/custom:ro
      - ./logs:/var/log/asterisk
    environment:
      - TZ=Europe/Moscow
      - DB_HOST=db-test-$env_suffix
    networks:
      - test-$env_suffix-network
    depends_on:
      - db-test-$env_suffix

  db-test-$env_suffix:
    image: mariadb:10.6
    container_name: db-test-$env_suffix
    restart: unless-stopped
    volumes:
      - test-$env_suffix-db-data:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=test_root_password_$env_suffix
      - MYSQL_DATABASE=asterisk_test_$env_suffix
      - MYSQL_USER=asterisk_test_$env_suffix
      - MYSQL_PASSWORD=test_password_$env_suffix
    networks:
      - test-$env_suffix-network

  redis-test-$env_suffix:
    image: redis:7-alpine
    container_name: redis-test-$env_suffix
    restart: unless-stopped
    ports:
      - "637$env_suffix:6379"  # Redis (6371, 6372, 6373)
    volumes:
      - test-$env_suffix-redis-data:/data
    networks:
      - test-$env_suffix-network

volumes:
  test-$env_suffix-traefik-certs:
  test-$env_suffix-asterisk-data:
  test-$env_suffix-db-data:
  test-$env_suffix-redis-data:

networks:
  test-$env_suffix-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.2$env_suffix.0.0/16
EOF

    log_info "Docker Compose файл создан: $compose_file"
}

# Создание файла переменных окружения
create_env_file() {
    local env_name="$1"
    local env_suffix="${env_name#env-}"
    local env_file="$TESTING_ROOT/$env_name/.env.test"
    
    cat > "$env_file" << EOF
# Переменные окружения для тестовой среды $env_name

# Базовые настройки
ENV_NAME=$env_name
ENV_SUFFIX=$env_suffix
TZ=Europe/Moscow

# Тестовые настройки Novofon (используйте отдельный аккаунт для тестов!)
NOVOFON_TEST_USERNAME=test_user_$env_suffix
NOVOFON_TEST_PASSWORD=test_password_$env_suffix
NOVOFON_TEST_NUMBER=+7999000000$env_suffix

# База данных
MYSQL_ROOT_PASSWORD=test_root_password_$env_suffix
MYSQL_DATABASE=asterisk_test_$env_suffix
MYSQL_USER=asterisk_test_$env_suffix
MYSQL_PASSWORD=test_password_$env_suffix

# LiveKit (тестовые ключи)
LIVEKIT_TEST_URL=wss://test-$env_suffix.livekit.cloud
LIVEKIT_TEST_API_KEY=test_api_key_$env_suffix
LIVEKIT_TEST_API_SECRET=test_api_secret_$env_suffix

# AI сервисы (тестовые ключи с ограничениями)
OPENAI_TEST_API_KEY=sk-test-$env_suffix
DEEPGRAM_TEST_API_KEY=test_deepgram_$env_suffix
CARTESIA_TEST_API_KEY=test_cartesia_$env_suffix

# Порты для изоляции
HTTP_PORT=808$env_suffix
HTTPS_PORT=844$env_suffix
SIP_UDP_PORT=508$env_suffix
SIP_TCP_PORT=516$env_suffix
REDIS_PORT=637$env_suffix
EOF

    log_info "Файл переменных окружения создан: $env_file"
}

# Создание базовых конфигураций
create_base_configs() {
    local env_name="$1"
    local configs_dir="$TESTING_ROOT/$env_name/configs"
    
    # Создание структуры конфигураций
    mkdir -p "$configs_dir"/{asterisk,traefik,agent}
    
    # Копирование базовых конфигураций из продакшна
    if [ -d "$PROJECT_ROOT/configs/asterisk" ]; then
        cp -r "$PROJECT_ROOT/configs/asterisk"/* "$configs_dir/asterisk/"
        log_info "Базовые конфигурации Asterisk скопированы"
    fi
    
    # Создание README для конфигураций
    cat > "$configs_dir/README.md" << EOF
# Конфигурации для тестовой среды $env_name

Эта директория содержит конфигурации для изолированной тестовой среды.

## Структура
- \`asterisk/\` - Конфигурации Asterisk
- \`traefik/\` - Конфигурации Traefik
- \`agent/\` - Конфигурации AI агента

## Изменения
Все изменения в этой директории изолированы от продакшн системы.
EOF
}

# Запуск тестовой среды
start_environment() {
    local env_name="$1"
    local env_dir="$TESTING_ROOT/$env_name"
    local env_suffix="${env_name#env-}"
    local compose_file="$env_dir/docker-compose.test-$env_suffix.yml"
    
    if [ ! -f "$compose_file" ]; then
        log_error "Docker Compose файл не найден: $compose_file"
        log_info "Создайте среду командой: $0 create $env_name"
        return 1
    fi
    
    log_info "Запуск тестовой среды '$env_name'..."
    
    cd "$env_dir"
    docker-compose -f "docker-compose.test-$env_suffix.yml" --env-file .env.test up -d
    
    log_success "Тестовая среда '$env_name' запущена"
    log_info "Доступные порты:"
    echo "  HTTP: 808$env_suffix"
    echo "  HTTPS: 844$env_suffix"
    echo "  SIP UDP: 508$env_suffix"
    echo "  SIP TCP: 516$env_suffix"
    echo "  Redis: 637$env_suffix"
}

# Остановка тестовой среды
stop_environment() {
    local env_name="$1"
    local env_dir="$TESTING_ROOT/$env_name"
    local env_suffix="${env_name#env-}"
    local compose_file="$env_dir/docker-compose.test-$env_suffix.yml"
    
    if [ ! -f "$compose_file" ]; then
        log_error "Docker Compose файл не найден: $compose_file"
        return 1
    fi
    
    log_info "Остановка тестовой среды '$env_name'..."
    
    cd "$env_dir"
    docker-compose -f "docker-compose.test-$env_suffix.yml" down
    
    log_success "Тестовая среда '$env_name' остановлена"
}

# Статус тестовой среды
status_environment() {
    local env_name="$1"
    local env_dir="$TESTING_ROOT/$env_name"
    local env_suffix="${env_name#env-}"
    local compose_file="$env_dir/docker-compose.test-$env_suffix.yml"
    
    if [ ! -f "$compose_file" ]; then
        log_error "Тестовая среда '$env_name' не создана"
        return 1
    fi
    
    log_info "Статус тестовой среды '$env_name':"
    
    cd "$env_dir"
    docker-compose -f "docker-compose.test-$env_suffix.yml" ps
}

# Логи тестовой среды
logs_environment() {
    local env_name="$1"
    local service="${2:-}"
    local env_dir="$TESTING_ROOT/$env_name"
    local env_suffix="${env_name#env-}"
    local compose_file="$env_dir/docker-compose.test-$env_suffix.yml"
    
    if [ ! -f "$compose_file" ]; then
        log_error "Docker Compose файл не найден: $compose_file"
        return 1
    fi
    
    cd "$env_dir"
    if [ -n "$service" ]; then
        docker-compose -f "docker-compose.test-$env_suffix.yml" logs -f "$service"
    else
        docker-compose -f "docker-compose.test-$env_suffix.yml" logs -f
    fi
}

# Очистка тестовой среды
clean_environment() {
    local env_name="$1"
    local env_dir="$TESTING_ROOT/$env_name"
    local env_suffix="${env_name#env-}"
    local compose_file="$env_dir/docker-compose.test-$env_suffix.yml"
    
    log_warning "Очистка тестовой среды '$env_name'..."
    read -p "Вы уверены? Все данные будут удалены! (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Отменено"
        return 0
    fi
    
    if [ -f "$compose_file" ]; then
        cd "$env_dir"
        docker-compose -f "docker-compose.test-$env_suffix.yml" down -v --remove-orphans
    fi
    
    # Удаление volumes
    docker volume ls -q | grep "test-$env_suffix-" | xargs -r docker volume rm
    
    log_success "Тестовая среда '$env_name' очищена"
}

# Помощь
show_help() {
    cat << EOF
Менеджер тестовых сред VoIP платформы

Использование: $0 <команда> [аргументы]

Команды:
  list                    - Список доступных сред
  create <env>           - Создать тестовую среду
  start <env>            - Запустить тестовую среду
  stop <env>             - Остановить тестовую среду
  status <env>           - Статус тестовой среды
  logs <env> [service]   - Просмотр логов
  clean <env>            - Очистить тестовую среду
  check <env>            - Проверить изоляцию среды
  help                   - Показать эту справку

Доступные среды:
  env-a - Текущая архитектура (Asterisk + ARI + LiveKit)
  env-b - Прямая интеграция (Asterisk + Python Agent)
  env-c - Микросервисная архитектура (Message Queue)

Примеры:
  $0 create env-a        # Создать среду A
  $0 start env-a         # Запустить среду A
  $0 logs env-a asterisk # Логи Asterisk в среде A
  $0 clean env-a         # Очистить среду A

EOF
}

# Основная функция
main() {
    check_dependencies
    
    case "${1:-help}" in
        list)
            list_environments
            ;;
        create)
            if [ $# -lt 2 ]; then
                log_error "Укажите имя среды"
                show_help
                exit 1
            fi
            create_environment "$2"
            ;;
        start)
            if [ $# -lt 2 ]; then
                log_error "Укажите имя среды"
                show_help
                exit 1
            fi
            start_environment "$2"
            ;;
        stop)
            if [ $# -lt 2 ]; then
                log_error "Укажите имя среды"
                show_help
                exit 1
            fi
            stop_environment "$2"
            ;;
        status)
            if [ $# -lt 2 ]; then
                log_error "Укажите имя среды"
                show_help
                exit 1
            fi
            status_environment "$2"
            ;;
        logs)
            if [ $# -lt 2 ]; then
                log_error "Укажите имя среды"
                show_help
                exit 1
            fi
            logs_environment "$2" "${3:-}"
            ;;
        clean)
            if [ $# -lt 2 ]; then
                log_error "Укажите имя среды"
                show_help
                exit 1
            fi
            clean_environment "$2"
            ;;
        check)
            if [ $# -lt 2 ]; then
                log_error "Укажите имя среды"
                show_help
                exit 1
            fi
            check_isolation "$2"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Неизвестная команда: $1"
            show_help
            exit 1
            ;;
    esac
}

# Запуск
main "$@"