#!/bin/bash

# Скрипт для автоматического обновления API ключей LiveKit в контейнере
# Версия: 1.0
# Дата: 2025-07-17

set -euo pipefail

# Конфигурация
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/.env"
CONTAINER_NAME="livekit-agent"
NETWORK_NAME="voip-platform_default"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция логирования
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Проверка существования файла .env
check_env_file() {
    if [ ! -f "$ENV_FILE" ]; then
        error "Файл .env не найден: $ENV_FILE"
        exit 1
    fi
    log "Файл .env найден: $ENV_FILE"
}

# Загрузка переменных из .env файла
load_env_vars() {
    log "Загрузка переменных окружения из .env файла..."
    
    # Загружаем переменные из .env файла, игнорируя комментарии и пустые строки
    while IFS='=' read -r key value; do
        # Пропускаем комментарии и пустые строки
        [[ $key =~ ^[[:space:]]*# ]] && continue
        [[ -z $key ]] && continue
        
        # Удаляем пробелы в начале и конце
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        
        # Экспортируем переменную
        export "$key"="$value"
    done < "$ENV_FILE"
    
    # Проверяем обязательные переменные
    if [ -z "${LIVEKIT_URL:-}" ]; then
        error "LIVEKIT_URL не установлен в .env файле"
        exit 1
    fi
    
    if [ -z "${LIVEKIT_API_KEY:-}" ]; then
        error "LIVEKIT_API_KEY не установлен в .env файле"
        exit 1
    fi
    
    if [ -z "${LIVEKIT_API_SECRET:-}" ]; then
        error "LIVEKIT_API_SECRET не установлен в .env файле"
        exit 1
    fi
    
    if [ -z "${OPENAI_API_KEY:-}" ]; then
        warning "OPENAI_API_KEY не установлен в .env файле"
    fi
    
    if [ -z "${DEEPGRAM_API_KEY:-}" ]; then
        warning "DEEPGRAM_API_KEY не установлен в .env файле"
    fi
    
    if [ -z "${CARTESIA_API_KEY:-}" ]; then
        warning "CARTESIA_API_KEY не установлен в .env файле"
    fi
    
    log "Переменные окружения загружены успешно"
    info "LIVEKIT_URL: $LIVEKIT_URL"
    info "LIVEKIT_API_KEY: ${LIVEKIT_API_KEY:0:10}..."
    info "LIVEKIT_API_SECRET: ${LIVEKIT_API_SECRET:0:10}..."
}

# Остановка и удаление существующего контейнера
stop_existing_container() {
    if docker ps -a --format "table {{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
        log "Остановка существующего контейнера: $CONTAINER_NAME"
        docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
        docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
        log "Контейнер $CONTAINER_NAME удален"
    else
        info "Контейнер $CONTAINER_NAME не найден, пропускаем удаление"
    fi
}

# Создание нового контейнера с обновленными переменными окружения
create_new_container() {
    log "Создание нового контейнера LiveKit агента с обновленными API ключами..."
    
    docker run -d \
        --name "$CONTAINER_NAME" \
        --network "$NETWORK_NAME" \
        --restart unless-stopped \
        -v "$PROJECT_DIR/configs/agent:/app" \
        -v "$PROJECT_DIR/data/agent:/data" \
        -v "$PROJECT_DIR/data/logs/agent:/logs" \
        -e "LIVEKIT_URL=$LIVEKIT_URL" \
        -e "LIVEKIT_API_KEY=$LIVEKIT_API_KEY" \
        -e "LIVEKIT_API_SECRET=$LIVEKIT_API_SECRET" \
        -e "OPENAI_API_KEY=${OPENAI_API_KEY:-}" \
        -e "DEEPGRAM_API_KEY=${DEEPGRAM_API_KEY:-}" \
        -e "CARTESIA_API_KEY=${CARTESIA_API_KEY:-}" \
        -e "PYTHONUNBUFFERED=1" \
        -e "TZ=Europe/Moscow" \
        "voip-platform_livekit-agent" start
    
    log "Контейнер $CONTAINER_NAME создан успешно"
}

# Проверка статуса контейнера
check_container_status() {
    log "Проверка статуса контейнера..."
    
    # Ждем несколько секунд для запуска контейнера
    sleep 5
    
    if docker ps --format "table {{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
        log "Контейнер $CONTAINER_NAME запущен успешно"
        
        # Проверяем логи на наличие ошибок
        if docker logs "$CONTAINER_NAME" --tail 10 | grep -q "registered worker"; then
            log "LiveKit агент успешно зарегистрирован как воркер"
        elif docker logs "$CONTAINER_NAME" --tail 10 | grep -q "401"; then
            error "Ошибка авторизации (401) - проверьте API ключи"
            return 1
        else
            warning "Статус агента неясен, проверьте логи: docker logs $CONTAINER_NAME"
        fi
    else
        error "Контейнер $CONTAINER_NAME не запущен"
        return 1
    fi
}

# Показать логи контейнера
show_logs() {
    log "Последние логи контейнера $CONTAINER_NAME:"
    docker logs "$CONTAINER_NAME" --tail 20
}

# Показать помощь
show_help() {
    cat << EOF
Скрипт для автоматического обновления API ключей LiveKit в контейнере

Использование: $0 [ОПЦИИ]

ОПЦИИ:
    --logs, -l      Показать логи контейнера после обновления
    --help, -h      Показать эту справку

ОПИСАНИЕ:
    Этот скрипт автоматически:
    1. Загружает переменные окружения из файла .env
    2. Останавливает и удаляет существующий контейнер livekit-agent
    3. Создает новый контейнер с обновленными API ключами
    4. Проверяет статус нового контейнера

ПРИМЕРЫ:
    $0                  # Обновить контейнер с новыми ключами
    $0 --logs          # Обновить контейнер и показать логи

ФАЙЛЫ:
    .env               # Файл с переменными окружения (обязательный)

ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ (.env):
    LIVEKIT_URL        # URL LiveKit Cloud (обязательно)
    LIVEKIT_API_KEY    # API ключ LiveKit (обязательно)
    LIVEKIT_API_SECRET # API секрет LiveKit (обязательно)
    OPENAI_API_KEY     # API ключ OpenAI (опционально)
    DEEPGRAM_API_KEY   # API ключ Deepgram (опционально)
    CARTESIA_API_KEY   # API ключ Cartesia (опционально)

EOF
}

# Основная функция
main() {
    local show_logs_flag=false
    
    # Обработка аргументов командной строки
    while [[ $# -gt 0 ]]; do
        case $1 in
            --logs|-l)
                show_logs_flag=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                error "Неизвестная опция: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    log "Начало обновления API ключей LiveKit агента"
    
    # Переходим в директорию проекта
    cd "$PROJECT_DIR"
    
    # Выполняем основные операции
    check_env_file
    load_env_vars
    stop_existing_container
    create_new_container
    
    if check_container_status; then
        log "Обновление API ключей завершено успешно"
        
        if [ "$show_logs_flag" = true ]; then
            echo
            show_logs
        fi
    else
        error "Обновление API ключей завершилось с ошибками"
        echo
        show_logs
        exit 1
    fi
}

# Запуск основной функции
main "$@"