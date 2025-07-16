#!/bin/bash

# VoIP Platform Log Management System
# Автоматическое архивирование и очистка логов
# Версия: 1.0
# Дата: 2025-07-16

set -euo pipefail

# Конфигурация
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_REGISTRY="$SCRIPT_DIR/log-registry.json"
ARCHIVE_DIR="$PROJECT_DIR/data/log-archives"
MAX_ARCHIVE_SIZE_MB=500
RETENTION_DAYS=30

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

# Проверка зависимостей
check_dependencies() {
    local deps=("docker" "docker-compose" "jq" "gzip")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            error "Зависимость не найдена: $dep"
            exit 1
        fi
    done
}

# Создание директории архивов
create_archive_dir() {
    mkdir -p "$ARCHIVE_DIR"
    log "Директория архивов создана: $ARCHIVE_DIR"
}

# Получение размера файла в MB
get_file_size_mb() {
    local container="$1"
    local file_path="$2"
    
    local size_bytes
    size_bytes=$(docker exec "$container" stat -c%s "$file_path" 2>/dev/null || echo "0")
    echo $((size_bytes / 1024 / 1024))
}

# Архивирование лога
archive_log() {
    local container="$1"
    local log_path="$2"
    local log_name="$3"
    local is_critical="$4"
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local archive_name="${container}_${log_name}_${timestamp}.gz"
    local temp_file="/tmp/${log_name}_${timestamp}"
    
    # Копируем лог из контейнера
    if docker exec "$container" test -f "$log_path"; then
        local file_size_mb
        file_size_mb=$(get_file_size_mb "$container" "$log_path")
        
        if [ "$file_size_mb" -gt 0 ]; then
            info "Архивирование: $container:$log_path (${file_size_mb}MB)"
            
            # Копируем файл
            docker cp "$container:$log_path" "$temp_file"
            
            # Сжимаем
            gzip -c "$temp_file" > "$ARCHIVE_DIR/$archive_name"
            
            # Очищаем оригинальный лог
            docker exec "$container" bash -c "> '$log_path'"
            
            # Удаляем временный файл
            rm -f "$temp_file"
            
            log "Заархивирован: $archive_name"
        else
            info "Пропуск пустого лога: $container:$log_path"
        fi
    else
        warning "Лог не найден: $container:$log_path"
    fi
}

# Очистка старых архивов
cleanup_old_archives() {
    log "Очистка архивов старше $RETENTION_DAYS дней..."
    
    find "$ARCHIVE_DIR" -name "*.gz" -type f -mtime +$RETENTION_DAYS -delete
    
    local deleted_count
    deleted_count=$(find "$ARCHIVE_DIR" -name "*.gz" -type f -mtime +$RETENTION_DAYS 2>/dev/null | wc -l)
    
    if [ "$deleted_count" -gt 0 ]; then
        log "Удалено старых архивов: $deleted_count"
    fi
}

# Контроль размера архивов
control_archive_size() {
    log "Контроль размера архивов (лимит: ${MAX_ARCHIVE_SIZE_MB}MB)..."
    
    local total_size_mb
    total_size_mb=$(du -sm "$ARCHIVE_DIR" 2>/dev/null | cut -f1 || echo "0")
    
    info "Текущий размер архивов: ${total_size_mb}MB"
    
    if [ "$total_size_mb" -gt "$MAX_ARCHIVE_SIZE_MB" ]; then
        warning "Превышен лимит размера архивов!"
        
        # Удаляем самые старые архивы
        while [ "$total_size_mb" -gt "$MAX_ARCHIVE_SIZE_MB" ]; do
            local oldest_file
            oldest_file=$(find "$ARCHIVE_DIR" -name "*.gz" -type f -printf '%T+ %p\n' | sort | head -n1 | cut -d' ' -f2-)
            
            if [ -n "$oldest_file" ]; then
                local file_size_mb
                file_size_mb=$(du -sm "$oldest_file" | cut -f1)
                rm -f "$oldest_file"
                total_size_mb=$((total_size_mb - file_size_mb))
                warning "Удален старый архив: $(basename "$oldest_file") (${file_size_mb}MB)"
            else
                break
            fi
        done
        
        log "Размер архивов после очистки: ${total_size_mb}MB"
    fi
}

# Архивирование всех логов
archive_all_logs() {
    log "Начало архивирования логов..."
    
    if [ ! -f "$LOG_REGISTRY" ]; then
        error "Реестр логов не найден: $LOG_REGISTRY"
        exit 1
    fi
    
    # Получаем список контейнеров
    local containers
    containers=$(jq -r '.log_registry.containers | keys[]' "$LOG_REGISTRY")
    
    for container in $containers; do
        log "Обработка контейнера: $container"
        
        # Проверяем, что контейнер запущен
        if ! docker ps --format "table {{.Names}}" | grep -q "^$container$"; then
            warning "Контейнер не запущен: $container"
            continue
        fi
        
        # Получаем группы логов
        local log_groups
        log_groups=$(jq -r ".log_registry.containers.\"$container\".logs | keys[]" "$LOG_REGISTRY")
        
        for group in $log_groups; do
            # Получаем файлы в группе
            local files_count
            files_count=$(jq -r ".log_registry.containers.\"$container\".logs.\"$group\".files | length" "$LOG_REGISTRY")
            
            for ((i=0; i<files_count; i++)); do
                local file_name path is_critical max_size_mb
                file_name=$(jq -r ".log_registry.containers.\"$container\".logs.\"$group\".files[$i].name" "$LOG_REGISTRY")
                path=$(jq -r ".log_registry.containers.\"$container\".logs.\"$group\".path" "$LOG_REGISTRY")
                is_critical=$(jq -r ".log_registry.containers.\"$container\".logs.\"$group\".files[$i].critical" "$LOG_REGISTRY")
                max_size_mb=$(jq -r ".log_registry.containers.\"$container\".logs.\"$group\".files[$i].max_size_mb" "$LOG_REGISTRY")
                
                local full_path="$path/$file_name"
                
                # Проверяем размер файла
                local current_size_mb
                current_size_mb=$(get_file_size_mb "$container" "$full_path")
                
                if [ "$current_size_mb" -ge "$max_size_mb" ]; then
                    warning "Лог превышает лимит размера: $container:$full_path (${current_size_mb}MB >= ${max_size_mb}MB)"
                    archive_log "$container" "$full_path" "$file_name" "$is_critical"
                elif [ "$current_size_mb" -gt 0 ]; then
                    info "Архивирование по расписанию: $container:$full_path (${current_size_mb}MB)"
                    archive_log "$container" "$full_path" "$file_name" "$is_critical"
                fi
            done
        done
    done
    
    log "Архивирование завершено"
}

# Показать статистику логов
show_log_stats() {
    log "Статистика логов системы:"
    echo
    
    if [ ! -f "$LOG_REGISTRY" ]; then
        error "Реестр логов не найден: $LOG_REGISTRY"
        return 1
    fi
    
    local containers
    containers=$(jq -r '.log_registry.containers | keys[]' "$LOG_REGISTRY")
    
    printf "%-20s %-30s %-10s %-10s %-10s\n" "КОНТЕЙНЕР" "ЛОГ" "РАЗМЕР" "ЛИМИТ" "СТАТУС"
    printf "%-20s %-30s %-10s %-10s %-10s\n" "--------" "---" "------" "-----" "------"
    
    for container in $containers; do
        if ! docker ps --format "table {{.Names}}" | grep -q "^$container$"; then
            printf "%-20s %-30s %-10s %-10s %-10s\n" "$container" "N/A" "N/A" "N/A" "STOPPED"
            continue
        fi
        
        local log_groups
        log_groups=$(jq -r ".log_registry.containers.\"$container\".logs | keys[]" "$LOG_REGISTRY")
        
        for group in $log_groups; do
            local files_count
            files_count=$(jq -r ".log_registry.containers.\"$container\".logs.\"$group\".files | length" "$LOG_REGISTRY")
            
            for ((i=0; i<files_count; i++)); do
                local file_name path max_size_mb
                file_name=$(jq -r ".log_registry.containers.\"$container\".logs.\"$group\".files[$i].name" "$LOG_REGISTRY")
                path=$(jq -r ".log_registry.containers.\"$container\".logs.\"$group\".path" "$LOG_REGISTRY")
                max_size_mb=$(jq -r ".log_registry.containers.\"$container\".logs.\"$group\".files[$i].max_size_mb" "$LOG_REGISTRY")
                
                local full_path="$path/$file_name"
                local current_size_mb
                current_size_mb=$(get_file_size_mb "$container" "$full_path")
                
                local status="OK"
                if [ "$current_size_mb" -ge "$max_size_mb" ]; then
                    status="OVER_LIMIT"
                elif [ "$current_size_mb" -eq 0 ]; then
                    status="EMPTY"
                fi
                
                printf "%-20s %-30s %-10s %-10s %-10s\n" "$container" "$file_name" "${current_size_mb}MB" "${max_size_mb}MB" "$status"
            done
        done
    done
    
    echo
    
    # Статистика архивов
    if [ -d "$ARCHIVE_DIR" ]; then
        local archive_count
        archive_count=$(find "$ARCHIVE_DIR" -name "*.gz" -type f | wc -l)
        local archive_size_mb
        archive_size_mb=$(du -sm "$ARCHIVE_DIR" 2>/dev/null | cut -f1 || echo "0")
        
        info "Архивы: $archive_count файлов, ${archive_size_mb}MB (лимит: ${MAX_ARCHIVE_SIZE_MB}MB)"
    fi
}

# Установка cron задачи
install_cron() {
    log "Установка cron задачи для еженедельного архивирования..."
    
    local cron_command="0 2 * * 0 $SCRIPT_DIR/log-manager.sh archive >/dev/null 2>&1"
    
    # Проверяем, есть ли уже такая задача
    if crontab -l 2>/dev/null | grep -q "log-manager.sh"; then
        warning "Cron задача уже существует"
        return 0
    fi
    
    # Добавляем задачу
    (crontab -l 2>/dev/null; echo "$cron_command") | crontab -
    
    log "Cron задача установлена: каждое воскресенье в 02:00"
}

# Удаление cron задачи
uninstall_cron() {
    log "Удаление cron задачи..."
    
    crontab -l 2>/dev/null | grep -v "log-manager.sh" | crontab -
    
    log "Cron задача удалена"
}

# Показать помощь
show_help() {
    cat << EOF
VoIP Platform Log Management System

Использование: $0 [КОМАНДА]

КОМАНДЫ:
    archive         Архивировать все логи
    stats           Показать статистику логов
    cleanup         Очистить старые архивы
    install-cron    Установить автоматическое архивирование (еженедельно)
    uninstall-cron  Удалить автоматическое архивирование
    help            Показать эту справку

ПРИМЕРЫ:
    $0 stats                    # Показать текущее состояние логов
    $0 archive                  # Заархивировать все логи сейчас
    $0 install-cron            # Настроить автоматическое архивирование

КОНФИГУРАЦИЯ:
    Максимальный размер архивов: ${MAX_ARCHIVE_SIZE_MB}MB
    Срок хранения архивов: ${RETENTION_DAYS} дней
    Директория архивов: $ARCHIVE_DIR
    Реестр логов: $LOG_REGISTRY

EOF
}

# Основная функция
main() {
    local command="${1:-help}"
    
    case "$command" in
        "archive")
            check_dependencies
            create_archive_dir
            archive_all_logs
            cleanup_old_archives
            control_archive_size
            ;;
        "stats")
            check_dependencies
            show_log_stats
            ;;
        "cleanup")
            check_dependencies
            create_archive_dir
            cleanup_old_archives
            control_archive_size
            ;;
        "install-cron")
            install_cron
            ;;
        "uninstall-cron")
            uninstall_cron
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            error "Неизвестная команда: $command"
            show_help
            exit 1
            ;;
    esac
}

# Запуск
main "$@"