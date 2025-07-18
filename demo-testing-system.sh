#!/bin/bash

# Демонстрация системы тестирования VoIP архитектур
# Быстрый старт для ознакомления с возможностями

set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_demo() { echo -e "${PURPLE}[DEMO]${NC} $1"; }

# Заголовок демонстрации
show_header() {
    clear
    echo -e "${PURPLE}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║    🎯 ДЕМОНСТРАЦИЯ СИСТЕМЫ ТЕСТИРОВАНИЯ VoIP АРХИТЕКТУР      ║
║                                                              ║
║    Безопасное тестирование различных подходов к             ║
║    голосовому агенту без влияния на продакшн систему        ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo ""
}

# Показать архитектуры
show_architectures() {
    log_demo "Доступные архитектуры для тестирования:"
    echo ""
    
    echo -e "${GREEN}📋 Архитектура A: Текущая (LiveKit + ARI)${NC}"
    echo "   Novofon → Asterisk → ARI → LiveKit Agent → AI Services"
    echo "   ✅ Максимальная функциональность"
    echo "   ❌ Сложность настройки"
    echo ""
    
    echo -e "${BLUE}📋 Архитектура B: Прямая интеграция${NC}"
    echo "   Novofon → Asterisk → Direct Python Agent → AI Services"
    echo "   ✅ Простота и надежность"
    echo "   ❌ Ограниченная функциональность"
    echo ""
    
    echo -e "${YELLOW}📋 Архитектура C: Микросервисы${NC}"
    echo "   Novofon → Asterisk → Message Queue → Multiple Agents → AI Services"
    echo "   ✅ Масштабируемость"
    echo "   ❌ Сложность управления"
    echo ""
}

# Демонстрация создания среды
demo_create_environment() {
    log_demo "Создание тестовой среды A..."
    echo ""
    
    log_info "Команда: ./testing/shared/scripts/test-env-manager.sh create env-a"
    
    if [ -d "testing/env-a" ]; then
        log_warning "Среда env-a уже существует"
    else
        log_info "Создание структуры директорий..."
        mkdir -p testing/env-a/{configs,results,logs}
        log_success "✓ Структура создана"
    fi
    
    log_info "Что создается:"
    echo "  📁 testing/env-a/configs/     - Конфигурации"
    echo "  📁 testing/env-a/results/     - Результаты тестов"
    echo "  📁 testing/env-a/logs/        - Логи"
    echo "  📄 docker-compose.test-a.yml  - Docker конфигурация"
    echo "  📄 .env.test                  - Переменные окружения"
    echo ""
}

# Демонстрация изоляции
demo_isolation() {
    log_demo "Демонстрация изоляции сред..."
    echo ""
    
    log_info "Каждая среда полностью изолирована:"
    echo ""
    
    echo -e "${GREEN}🔒 Сетевая изоляция:${NC}"
    echo "  • Среда A: сеть test-a-network (172.21.0.0/16)"
    echo "  • Среда B: сеть test-b-network (172.22.0.0/16)"
    echo "  • Среда C: сеть test-c-network (172.23.0.0/16)"
    echo ""
    
    echo -e "${BLUE}🔒 Изоляция портов:${NC}"
    echo "  • Среда A: HTTP 8081, SIP 5081, Redis 6371"
    echo "  • Среда B: HTTP 8082, SIP 5082, Redis 6372"
    echo "  • Среда C: HTTP 8083, SIP 5083, Redis 6373"
    echo ""
    
    echo -e "${YELLOW}🔒 Изоляция данных:${NC}"
    echo "  • Отдельные Docker volumes"
    echo "  • Независимые базы данных"
    echo "  • Изолированные конфигурации"
    echo ""
}

# Демонстрация тестирования
demo_testing() {
    log_demo "Демонстрация автоматизированного тестирования..."
    echo ""
    
    log_info "Доступные типы тестов:"
    echo ""
    
    echo -e "${GREEN}🧪 Базовое тестирование:${NC}"
    echo "  ./testing/shared/scripts/run-tests.sh test env-a"
    echo "  ✓ Подключение к Asterisk"
    echo "  ✓ SIP регистрация"
    echo "  ✓ ARI интерфейс"
    echo "  ✓ База данных"
    echo "  ✓ Redis"
    echo "  ✓ Производительность"
    echo ""
    
    echo -e "${BLUE}🔄 Сравнительное тестирование:${NC}"
    echo "  ./testing/shared/scripts/run-tests.sh compare env-a env-b"
    echo "  📊 Сравнение производительности"
    echo "  📈 Анализ надежности"
    echo "  📋 Автоматический отчет"
    echo ""
    
    echo -e "${YELLOW}⚡ Нагрузочное тестирование:${NC}"
    echo "  ./testing/shared/scripts/run-tests.sh load env-a 10"
    echo "  🔥 Тест с множественными звонками"
    echo "  📊 Метрики производительности"
    echo ""
}

# Демонстрация мониторинга
demo_monitoring() {
    log_demo "Система мониторинга..."
    echo ""
    
    log_info "Компоненты мониторинга:"
    echo ""
    
    echo -e "${GREEN}📊 Prometheus (http://localhost:9090):${NC}"
    echo "  • Сбор метрик со всех сред"
    echo "  • Мониторинг производительности"
    echo "  • Алерты и уведомления"
    echo ""
    
    echo -e "${BLUE}📈 Grafana (http://localhost:3000):${NC}"
    echo "  • Визуализация метрик"
    echo "  • Дашборды для каждой среды"
    echo "  • Сравнительные графики"
    echo ""
    
    echo -e "${YELLOW}🖥️ Системные метрики:${NC}"
    echo "  • Node Exporter - системные ресурсы"
    echo "  • cAdvisor - метрики контейнеров"
    echo "  • Custom exporters - VoIP метрики"
    echo ""
    
    log_info "Запуск мониторинга:"
    echo "  cd testing/shared/monitoring"
    echo "  docker-compose -f docker-compose.monitoring.yml up -d"
    echo ""
}

# Демонстрация результатов
demo_results() {
    log_demo "Анализ результатов тестирования..."
    echo ""
    
    log_info "Создание примера результатов..."
    
    # Создание примера CSV файла с результатами
    mkdir -p testing/results
    cat > testing/results/demo_results.csv << EOF
timestamp,environment,test_name,result
2025-01-18 10:00:01,env-a,asterisk_connection,PASS
2025-01-18 10:00:02,env-a,sip_registration,PASS
2025-01-18 10:00:03,env-a,ari_interface,PASS
2025-01-18 10:00:04,env-a,database_connection,PASS
2025-01-18 10:00:05,env-a,redis_connection,PASS
2025-01-18 10:00:06,env-a,asterisk_response_time,0.234
2025-01-18 10:00:07,env-a,cpu_usage,15.2
2025-01-18 10:00:08,env-a,overall_success_rate,100.0
2025-01-18 10:01:01,env-b,asterisk_connection,PASS
2025-01-18 10:01:02,env-b,sip_registration,PASS
2025-01-18 10:01:03,env-b,ari_interface,WARN
2025-01-18 10:01:04,env-b,database_connection,PASS
2025-01-18 10:01:05,env-b,redis_connection,PASS
2025-01-18 10:01:06,env-b,asterisk_response_time,0.189
2025-01-18 10:01:07,env-b,cpu_usage,12.8
2025-01-18 10:01:08,env-b,overall_success_rate,85.7
EOF
    
    log_success "✓ Пример результатов создан"
    echo ""
    
    log_info "Просмотр результатов:"
    echo "  ./testing/shared/scripts/run-tests.sh results"
    echo ""
    
    echo -e "${GREEN}📊 Пример результатов:${NC}"
    echo "┌─────────────────────┬─────────┬─────────────────────────┬────────┐"
    echo "│ Timestamp           │ Env     │ Test                    │ Result │"
    echo "├─────────────────────┼─────────┼─────────────────────────┼────────┤"
    echo "│ 2025-01-18 10:00:01 │ env-a   │ asterisk_connection     │ PASS   │"
    echo "│ 2025-01-18 10:00:06 │ env-a   │ asterisk_response_time  │ 0.234  │"
    echo "│ 2025-01-18 10:00:08 │ env-a   │ overall_success_rate    │ 100.0  │"
    echo "│ 2025-01-18 10:01:06 │ env-b   │ asterisk_response_time  │ 0.189  │"
    echo "│ 2025-01-18 10:01:08 │ env-b   │ overall_success_rate    │ 85.7   │"
    echo "└─────────────────────┴─────────┴─────────────────────────┴────────┘"
    echo ""
    
    log_info "Выводы из примера:"
    echo "  🏆 Среда B быстрее (0.189s vs 0.234s)"
    echo "  🏆 Среда A надежнее (100% vs 85.7%)"
    echo "  💡 Выбор зависит от приоритетов"
    echo ""
}

# Демонстрация безопасности
demo_security() {
    log_demo "Безопасность и откат изменений..."
    echo ""
    
    log_info "Механизмы безопасности:"
    echo ""
    
    echo -e "${GREEN}🛡️ Изоляция от продакшна:${NC}"
    echo "  • Отдельные SIP аккаунты для тестов"
    echo "  • Изолированные Docker сети"
    echo "  • Независимые конфигурации"
    echo "  • Отдельные API ключи"
    echo ""
    
    echo -e "${BLUE}🔄 Откат изменений:${NC}"
    echo "  • Остановка среды: test-env-manager.sh stop env-a"
    echo "  • Полная очистка: test-env-manager.sh clean env-a"
    echo "  • Версионирование конфигураций"
    echo "  • Автоматические бэкапы"
    echo ""
    
    echo -e "${YELLOW}📝 Аудит и логирование:${NC}"
    echo "  • Логирование всех действий"
    echo "  • Трассировка изменений"
    echo "  • Мониторинг доступа"
    echo "  • Отчеты о тестировании"
    echo ""
}

# Интерактивное меню
interactive_menu() {
    while true; do
        echo ""
        log_demo "Выберите демонстрацию:"
        echo "  1) 🏗️  Архитектуры для тестирования"
        echo "  2) 🔧 Создание тестовой среды"
        echo "  3) 🔒 Изоляция и безопасность"
        echo "  4) 🧪 Автоматизированное тестирование"
        echo "  5) 📊 Система мониторинга"
        echo "  6) 📈 Анализ результатов"
        echo "  7) 🛡️  Безопасность и откат"
        echo "  8) 📚 Документация"
        echo "  9) 🚀 Быстрый старт"
        echo "  0) ❌ Выход"
        echo ""
        
        read -p "Ваш выбор (0-9): " choice
        
        case $choice in
            1) show_architectures ;;
            2) demo_create_environment ;;
            3) demo_isolation ;;
            4) demo_testing ;;
            5) demo_monitoring ;;
            6) demo_results ;;
            7) demo_security ;;
            8) show_documentation ;;
            9) quick_start ;;
            0) log_info "До свидания!"; exit 0 ;;
            *) log_error "Неверный выбор. Попробуйте еще раз." ;;
        esac
        
        echo ""
        read -p "Нажмите Enter для продолжения..."
    done
}

# Показать документацию
show_documentation() {
    log_demo "Документация системы тестирования..."
    echo ""
    
    log_info "Основные документы:"
    echo ""
    
    echo -e "${GREEN}📋 testing-methodology.md${NC}"
    echo "  • Полное описание методики"
    echo "  • Архитектурные варианты"
    echo "  • Принципы безопасности"
    echo ""
    
    echo -e "${BLUE}📖 testing/README.md${NC}"
    echo "  • Подробное руководство пользователя"
    echo "  • Примеры команд"
    echo "  • Устранение неполадок"
    echo ""
    
    echo -e "${YELLOW}🔧 Скрипты:${NC}"
    echo "  • testing/shared/scripts/test-env-manager.sh"
    echo "  • testing/shared/scripts/run-tests.sh"
    echo "  • Автоматизация всех процессов"
    echo ""
    
    log_info "Для изучения документации:"
    echo "  cat testing-methodology.md"
    echo "  cat testing/README.md"
    echo ""
}

# Быстрый старт
quick_start() {
    log_demo "🚀 Быстрый старт системы тестирования"
    echo ""
    
    log_info "Пошаговая инструкция:"
    echo ""
    
    echo -e "${GREEN}Шаг 1: Создание тестовой среды${NC}"
    echo "  ./testing/shared/scripts/test-env-manager.sh create env-a"
    echo ""
    
    echo -e "${BLUE}Шаг 2: Настройка переменных окружения${NC}"
    echo "  nano testing/env-a/.env.test"
    echo "  # Укажите тестовые данные Novofon"
    echo ""
    
    echo -e "${YELLOW}Шаг 3: Запуск среды${NC}"
    echo "  ./testing/shared/scripts/test-env-manager.sh start env-a"
    echo ""
    
    echo -e "${PURPLE}Шаг 4: Запуск тестов${NC}"
    echo "  ./testing/shared/scripts/run-tests.sh test env-a"
    echo ""
    
    echo -e "${GREEN}Шаг 5: Просмотр результатов${NC}"
    echo "  ./testing/shared/scripts/run-tests.sh results"
    echo ""
    
    log_warning "⚠️  Важно: Используйте отдельные тестовые аккаунты!"
    echo ""
}

# Главная функция
main() {
    show_header
    
    log_info "Добро пожаловать в демонстрацию системы тестирования VoIP архитектур!"
    echo ""
    
    log_info "Эта система позволяет:"
    echo "  ✅ Безопасно тестировать различные архитектуры"
    echo "  ✅ Сравнивать производительность и надежность"
    echo "  ✅ Мониторить все аспекты работы"
    echo "  ✅ Легко откатывать изменения"
    echo ""
    
    if [ "${1:-}" = "--auto" ]; then
        # Автоматическая демонстрация
        show_architectures
        sleep 3
        demo_create_environment
        sleep 3
        demo_testing
        sleep 3
        demo_results
    else
        # Интерактивная демонстрация
        interactive_menu
    fi
}

# Запуск
main "$@"