#!/bin/bash

# Автоматизированное тестирование VoIP архитектур
# Запускает комплексные тесты для сравнения различных подходов

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTING_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
RESULTS_DIR="$TESTING_ROOT/results"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Создание директории результатов
mkdir -p "$RESULTS_DIR"

# Функция для записи результатов
write_result() {
    local test_name="$1"
    local env_name="$2"
    local result="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "$timestamp,$env_name,$test_name,$result" >> "$RESULTS_DIR/test_results.csv"
}

# Инициализация файла результатов
init_results() {
    if [ ! -f "$RESULTS_DIR/test_results.csv" ]; then
        echo "timestamp,environment,test_name,result" > "$RESULTS_DIR/test_results.csv"
    fi
}

# Тест подключения к Asterisk
test_asterisk_connection() {
    local env_name="$1"
    local env_suffix="${env_name#env-}"
    
    log_info "Тестирование подключения к Asterisk в среде $env_name..."
    
    local container_name="asterisk-test-$env_suffix"
    
    if docker exec "$container_name" asterisk -rx "core show version" &>/dev/null; then
        log_success "✓ Asterisk доступен"
        write_result "asterisk_connection" "$env_name" "PASS"
        return 0
    else
        log_error "✗ Asterisk недоступен"
        write_result "asterisk_connection" "$env_name" "FAIL"
        return 1
    fi
}

# Тест SIP регистрации
test_sip_registration() {
    local env_name="$1"
    local env_suffix="${env_name#env-}"
    
    log_info "Тестирование SIP регистрации в среде $env_name..."
    
    local container_name="asterisk-test-$env_suffix"
    
    # Проверка PJSIP endpoints
    if docker exec "$container_name" asterisk -rx "pjsip show endpoints" | grep -q "Endpoint"; then
        log_success "✓ PJSIP endpoints настроены"
        write_result "sip_endpoints" "$env_name" "PASS"
    else
        log_warning "⚠ PJSIP endpoints не найдены"
        write_result "sip_endpoints" "$env_name" "WARN"
    fi
    
    # Проверка регистраций
    if docker exec "$container_name" asterisk -rx "pjsip show registrations" | grep -q "Registered"; then
        log_success "✓ SIP регистрация активна"
        write_result "sip_registration" "$env_name" "PASS"
        return 0
    else
        log_warning "⚠ SIP регистрация не активна"
        write_result "sip_registration" "$env_name" "WARN"
        return 1
    fi
}

# Тест ARI интерфейса
test_ari_interface() {
    local env_name="$1"
    local env_suffix="${env_name#env-}"
    
    log_info "Тестирование ARI интерфейса в среде $env_name..."
    
    local container_name="asterisk-test-$env_suffix"
    local http_port="808$env_suffix"
    
    # Проверка HTTP сервера Asterisk
    if docker exec "$container_name" asterisk -rx "http show status" | grep -q "HTTP Server Status"; then
        log_success "✓ HTTP сервер Asterisk активен"
        write_result "ari_http_server" "$env_name" "PASS"
    else
        log_error "✗ HTTP сервер Asterisk неактивен"
        write_result "ari_http_server" "$env_name" "FAIL"
        return 1
    fi
    
    # Проверка ARI приложений
    if docker exec "$container_name" asterisk -rx "ari show apps" | grep -q "Application"; then
        log_success "✓ ARI приложения найдены"
        write_result "ari_applications" "$env_name" "PASS"
        return 0
    else
        log_warning "⚠ ARI приложения не найдены"
        write_result "ari_applications" "$env_name" "WARN"
        return 1
    fi
}

# Тест базы данных
test_database_connection() {
    local env_name="$1"
    local env_suffix="${env_name#env-}"
    
    log_info "Тестирование подключения к базе данных в среде $env_name..."
    
    local container_name="db-test-$env_suffix"
    
    if docker exec "$container_name" mysqladmin ping -h localhost &>/dev/null; then
        log_success "✓ База данных доступна"
        write_result "database_connection" "$env_name" "PASS"
        return 0
    else
        log_error "✗ База данных недоступна"
        write_result "database_connection" "$env_name" "FAIL"
        return 1
    fi
}

# Тест Redis
test_redis_connection() {
    local env_name="$1"
    local env_suffix="${env_name#env-}"
    
    log_info "Тестирование подключения к Redis в среде $env_name..."
    
    local container_name="redis-test-$env_suffix"
    
    if docker exec "$container_name" redis-cli ping | grep -q "PONG"; then
        log_success "✓ Redis доступен"
        write_result "redis_connection" "$env_name" "PASS"
        return 0
    else
        log_error "✗ Redis недоступен"
        write_result "redis_connection" "$env_name" "FAIL"
        return 1
    fi
}

# Тест производительности
test_performance() {
    local env_name="$1"
    local env_suffix="${env_name#env-}"
    
    log_info "Тестирование производительности в среде $env_name..."
    
    local container_name="asterisk-test-$env_suffix"
    local start_time=$(date +%s.%N)
    
    # Тест времени отклика Asterisk CLI
    docker exec "$container_name" asterisk -rx "core show version" &>/dev/null
    
    local end_time=$(date +%s.%N)
    local response_time=$(echo "$end_time - $start_time" | bc -l)
    
    log_info "Время отклика Asterisk CLI: ${response_time}s"
    write_result "asterisk_response_time" "$env_name" "$response_time"
    
    # Проверка использования ресурсов
    local cpu_usage=$(docker stats --no-stream --format "{{.CPUPerc}}" "$container_name" | sed 's/%//')
    local mem_usage=$(docker stats --no-stream --format "{{.MemUsage}}" "$container_name")
    
    log_info "Использование CPU: ${cpu_usage}%"
    log_info "Использование памяти: $mem_usage"
    
    write_result "cpu_usage" "$env_name" "$cpu_usage"
    write_result "memory_usage" "$env_name" "$mem_usage"
}

# Тест диалплана
test_dialplan() {
    local env_name="$1"
    local env_suffix="${env_name#env-}"
    
    log_info "Тестирование диалплана в среде $env_name..."
    
    local container_name="asterisk-test-$env_suffix"
    
    # Проверка загрузки диалплана
    if docker exec "$container_name" asterisk -rx "dialplan show" | grep -q "Context"; then
        log_success "✓ Диалплан загружен"
        write_result "dialplan_loaded" "$env_name" "PASS"
    else
        log_error "✗ Диалплан не загружен"
        write_result "dialplan_loaded" "$env_name" "FAIL"
        return 1
    fi
    
    # Проверка тестовых номеров
    if docker exec "$container_name" asterisk -rx "dialplan show 8888@from-internal" | grep -q "8888"; then
        log_success "✓ Тестовый номер 8888 найден"
        write_result "test_extension_8888" "$env_name" "PASS"
    else
        log_warning "⚠ Тестовый номер 8888 не найден"
        write_result "test_extension_8888" "$env_name" "WARN"
    fi
}

# Комплексный тест среды
run_environment_tests() {
    local env_name="$1"
    
    log_info "Запуск комплексного тестирования среды $env_name"
    echo "=================================================="
    
    local tests_passed=0
    local tests_total=0
    
    # Список тестов
    local tests=(
        "test_asterisk_connection"
        "test_database_connection"
        "test_redis_connection"
        "test_sip_registration"
        "test_ari_interface"
        "test_dialplan"
        "test_performance"
    )
    
    for test_func in "${tests[@]}"; do
        ((tests_total++))
        if $test_func "$env_name"; then
            ((tests_passed++))
        fi
        echo ""
    done
    
    echo "=================================================="
    log_info "Результаты тестирования среды $env_name:"
    log_info "Пройдено: $tests_passed из $tests_total тестов"
    
    local success_rate=$(echo "scale=2; $tests_passed * 100 / $tests_total" | bc -l)
    log_info "Успешность: ${success_rate}%"
    
    write_result "overall_success_rate" "$env_name" "$success_rate"
    
    if [ "$tests_passed" -eq "$tests_total" ]; then
        log_success "✓ Все тесты пройдены успешно!"
        return 0
    else
        log_warning "⚠ Некоторые тесты не пройдены"
        return 1
    fi
}

# Сравнительное тестирование
run_comparative_tests() {
    local environments=("$@")
    
    log_info "Запуск сравнительного тестирования"
    log_info "Среды для тестирования: ${environments[*]}"
    
    for env in "${environments[@]}"; do
        log_info "Тестирование среды: $env"
        run_environment_tests "$env"
        echo ""
    done
    
    # Генерация отчета
    generate_comparison_report "${environments[@]}"
}

# Генерация отчета сравнения
generate_comparison_report() {
    local environments=("$@")
    local report_file="$RESULTS_DIR/comparison_report_$(date +%Y%m%d_%H%M%S).md"
    
    log_info "Генерация отчета сравнения: $report_file"
    
    cat > "$report_file" << EOF
# Отчет сравнительного тестирования VoIP архитектур

**Дата:** $(date '+%Y-%m-%d %H:%M:%S')
**Тестируемые среды:** ${environments[*]}

## Результаты тестирования

EOF
    
    # Добавление результатов для каждой среды
    for env in "${environments[@]}"; do
        echo "### Среда: $env" >> "$report_file"
        echo "" >> "$report_file"
        
        # Извлечение результатов из CSV
        grep ",$env," "$RESULTS_DIR/test_results.csv" | tail -20 | while IFS=',' read -r timestamp environment test_name result; do
            echo "- **$test_name**: $result" >> "$report_file"
        done
        
        echo "" >> "$report_file"
    done
    
    cat >> "$report_file" << EOF

## Рекомендации

На основе результатов тестирования:

1. **Производительность**: Сравните время отклика и использование ресурсов
2. **Надежность**: Проверьте количество пройденных тестов
3. **Стабильность**: Оцените стабильность SIP соединений

## Следующие шаги

1. Проанализируйте результаты тестирования
2. Выберите оптимальную архитектуру
3. Проведите дополнительные нагрузочные тесты
4. Задокументируйте выбранное решение

---
*Отчет сгенерирован автоматически*
EOF
    
    log_success "Отчет сохранен: $report_file"
}

# Нагрузочное тестирование
run_load_tests() {
    local env_name="$1"
    local concurrent_calls="${2:-5}"
    
    log_info "Запуск нагрузочного тестирования среды $env_name"
    log_info "Количество одновременных звонков: $concurrent_calls"
    
    # Здесь можно добавить интеграцию с SIPp или другими инструментами
    log_warning "Нагрузочное тестирование требует дополнительной настройки SIPp"
    write_result "load_test_${concurrent_calls}_calls" "$env_name" "PENDING"
}

# Очистка результатов
clean_results() {
    log_warning "Очистка результатов тестирования..."
    read -p "Вы уверены? Все результаты будут удалены! (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$RESULTS_DIR"/*
        log_success "Результаты очищены"
    else
        log_info "Отменено"
    fi
}

# Показать результаты
show_results() {
    if [ ! -f "$RESULTS_DIR/test_results.csv" ]; then
        log_error "Файл результатов не найден"
        return 1
    fi
    
    log_info "Последние результаты тестирования:"
    echo ""
    
    # Показать последние 20 результатов
    tail -20 "$RESULTS_DIR/test_results.csv" | column -t -s ','
}

# Помощь
show_help() {
    cat << EOF
Автоматизированное тестирование VoIP архитектур

Использование: $0 <команда> [аргументы]

Команды:
  test <env>                    - Комплексное тестирование среды
  compare <env1> <env2> ...     - Сравнительное тестирование
  load <env> [calls]            - Нагрузочное тестирование
  results                       - Показать результаты
  clean                         - Очистить результаты
  help                          - Показать справку

Примеры:
  $0 test env-a                 # Тестировать среду A
  $0 compare env-a env-b        # Сравнить среды A и B
  $0 load env-a 10              # Нагрузочный тест на 10 звонков
  $0 results                    # Показать результаты

EOF
}

# Основная функция
main() {
    init_results
    
    case "${1:-help}" in
        test)
            if [ $# -lt 2 ]; then
                log_error "Укажите имя среды"
                show_help
                exit 1
            fi
            run_environment_tests "$2"
            ;;
        compare)
            if [ $# -lt 3 ]; then
                log_error "Укажите минимум две среды для сравнения"
                show_help
                exit 1
            fi
            shift
            run_comparative_tests "$@"
            ;;
        load)
            if [ $# -lt 2 ]; then
                log_error "Укажите имя среды"
                show_help
                exit 1
            fi
            run_load_tests "$2" "${3:-5}"
            ;;
        results)
            show_results
            ;;
        clean)
            clean_results
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