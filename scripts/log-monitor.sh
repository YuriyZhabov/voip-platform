#!/bin/bash

# VoIP Platform Log Monitor
# Мониторинг логов в реальном времени
# Версия: 1.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Функция для мониторинга конкретного лога
monitor_log() {
    local container="$1"
    local log_path="$2"
    local log_name="$3"
    
    echo -e "${GREEN}=== Мониторинг: $container:$log_path ===${NC}"
    
    if docker ps --format "table {{.Names}}" | grep -q "^$container$"; then
        docker exec "$container" tail -f "$log_path" 2>/dev/null | while read line; do
            # Раскрашиваем вывод в зависимости от типа сообщения
            if [[ "$line" =~ ERROR|CRITICAL|FATAL ]]; then
                echo -e "${RED}[$container]${NC} $line"
            elif [[ "$line" =~ WARNING|WARN ]]; then
                echo -e "${YELLOW}[$container]${NC} $line"
            elif [[ "$line" =~ INFO ]]; then
                echo -e "${BLUE}[$container]${NC} $line"
            elif [[ "$line" =~ DEBUG ]]; then
                echo -e "${PURPLE}[$container]${NC} $line"
            else
                echo -e "${CYAN}[$container]${NC} $line"
            fi
        done
    else
        echo -e "${RED}Контейнер не запущен: $container${NC}"
    fi
}

# Мониторинг всех критических логов
monitor_all() {
    echo -e "${GREEN}=== Мониторинг всех критических логов ===${NC}"
    echo -e "${YELLOW}Нажмите Ctrl+C для выхода${NC}"
    echo
    
    # FreePBX основные логи
    (monitor_log "freepbx-server" "/var/log/asterisk/freepbx.log" "freepbx" &)
    (monitor_log "freepbx-server" "/var/log/asterisk/full" "asterisk" &)
    (monitor_log "freepbx-server" "/var/log/apache2/freepbx_error.log" "apache-error" &)
    
    # Traefik логи
    (monitor_log "traefik-proxy" "/var/log/traefik/traefik.log" "traefik" &)
    
    wait
}

# Показать последние ошибки
show_recent_errors() {
    local hours="${1:-1}"
    echo -e "${GREEN}=== Ошибки за последние $hours час(ов) ===${NC}"
    
    local containers=("freepbx-server" "traefik-proxy")
    
    for container in "${containers[@]}"; do
        if docker ps --format "table {{.Names}}" | grep -q "^$container$"; then
            echo -e "${BLUE}--- $container ---${NC}"
            
            case "$container" in
                "freepbx-server")
                    # Ищем ошибки в логах FreePBX
                    docker exec "$container" bash -c "
                        find /var/log -name '*.log' -newermt '$hours hours ago' -exec grep -l 'ERROR\|CRITICAL\|FATAL' {} \; 2>/dev/null | while read logfile; do
                            echo \"=== \$logfile ===\"
                            grep 'ERROR\|CRITICAL\|FATAL' \"\$logfile\" | tail -5
                            echo
                        done
                    " 2>/dev/null || echo "Нет ошибок или логи недоступны"
                    ;;
                "traefik-proxy")
                    docker exec "$container" sh -c "
                        find /var/log -name '*.log' -newermt '$hours hours ago' -exec grep -l 'error\|ERROR\|fatal\|FATAL' {} \; 2>/dev/null | while read logfile; do
                            echo \"=== \$logfile ===\"
                            grep 'error\|ERROR\|fatal\|FATAL' \"\$logfile\" | tail -5
                            echo
                        done
                    " 2>/dev/null || echo "Нет ошибок или логи недоступны"
                    ;;
            esac
            echo
        fi
    done
}

# Показать топ самых больших логов
show_largest_logs() {
    echo -e "${GREEN}=== Топ самых больших логов ===${NC}"
    
    local containers=("freepbx-server" "traefik-proxy")
    
    for container in "${containers[@]}"; do
        if docker ps --format "table {{.Names}}" | grep -q "^$container$"; then
            echo -e "${BLUE}--- $container ---${NC}"
            if [[ "$container" == "traefik-proxy" ]]; then
                docker exec "$container" sh -c "
                    find /var/log -name '*.log' -type f -exec du -h {} \; 2>/dev/null | sort -hr | head -10
                " 2>/dev/null || echo "Логи недоступны"
            else
                docker exec "$container" bash -c "
                    find /var/log -name '*.log' -type f -exec du -h {} \; 2>/dev/null | sort -hr | head -10
                " 2>/dev/null || echo "Логи недоступны"
            fi
            echo
        fi
    done
}

# Поиск в логах
search_logs() {
    local pattern="$1"
    local hours="${2:-24}"
    
    echo -e "${GREEN}=== Поиск '$pattern' в логах за последние $hours час(ов) ===${NC}"
    
    local containers=("freepbx-server" "traefik-proxy")
    
    for container in "${containers[@]}"; do
        if docker ps --format "table {{.Names}}" | grep -q "^$container$"; then
            echo -e "${BLUE}--- $container ---${NC}"
            if [[ "$container" == "traefik-proxy" ]]; then
                docker exec "$container" sh -c "
                    find /var/log -name '*.log' -newermt '$hours hours ago' -exec grep -l '$pattern' {} \; 2>/dev/null | while read logfile; do
                        echo \"=== \$logfile ===\"
                        grep '$pattern' \"\$logfile\" | tail -10
                        echo
                    done
                " 2>/dev/null || echo "Совпадений не найдено"
            else
                docker exec "$container" bash -c "
                    find /var/log -name '*.log' -newermt '$hours hours ago' -exec grep -l '$pattern' {} \; 2>/dev/null | while read logfile; do
                        echo \"=== \$logfile ===\"
                        grep '$pattern' \"\$logfile\" | tail -10
                        echo
                    done
                " 2>/dev/null || echo "Совпадений не найдено"
            fi
            echo
        fi
    done
}

# Показать справку
show_help() {
    cat << EOF
VoIP Platform Log Monitor

Использование: $0 [КОМАНДА] [ПАРАМЕТРЫ]

КОМАНДЫ:
    monitor [КОНТЕЙНЕР] [ПУТЬ]  Мониторить конкретный лог
    all                         Мониторить все критические логи
    errors [ЧАСЫ]              Показать ошибки за последние N часов (по умолчанию: 1)
    largest                     Показать самые большие логи
    search ПАТТЕРН [ЧАСЫ]      Поиск в логах (по умолчанию: 24 часа)
    help                        Показать эту справку

ПРИМЕРЫ:
    $0 all                                    # Мониторить все логи
    $0 monitor freepbx-server /var/log/asterisk/freepbx.log
    $0 errors 2                              # Ошибки за 2 часа
    $0 search "Cannot connect" 12            # Поиск за 12 часов
    $0 largest                               # Самые большие логи

ГОРЯЧИЕ КЛАВИШИ (в режиме мониторинга):
    Ctrl+C                      Выход из мониторинга

EOF
}

# Основная функция
main() {
    local command="${1:-help}"
    
    case "$command" in
        "monitor")
            if [ $# -ge 3 ]; then
                monitor_log "$2" "$3" "$(basename "$3")"
            else
                echo "Использование: $0 monitor КОНТЕЙНЕР ПУТЬ_К_ЛОГУ"
                exit 1
            fi
            ;;
        "all")
            monitor_all
            ;;
        "errors")
            show_recent_errors "${2:-1}"
            ;;
        "largest")
            show_largest_logs
            ;;
        "search")
            if [ $# -ge 2 ]; then
                search_logs "$2" "${3:-24}"
            else
                echo "Использование: $0 search ПАТТЕРН [ЧАСЫ]"
                exit 1
            fi
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            echo -e "${RED}Неизвестная команда: $command${NC}"
            show_help
            exit 1
            ;;
    esac
}

# Обработка сигналов
trap 'echo -e "\n${YELLOW}Мониторинг остановлен${NC}"; exit 0' INT TERM

# Запуск
main "$@"