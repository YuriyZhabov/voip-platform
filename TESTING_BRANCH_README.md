# Ветка: testing-methodology-v1.0

## 🎯 Цель ветки

Эта ветка содержит полную методику безопасного тестирования различных архитектурных подходов к голосовому агенту VoIP платформы.

## 🚀 Быстрый старт

```bash
# Клонировать ветку
git clone -b testing-methodology-v1.0 https://github.com/YuriyZhabov/voip-platform.git
cd voip-platform

# Запустить демонстрацию
./demo-testing-system.sh

# Или создать первую тестовую среду
./testing/shared/scripts/test-env-manager.sh create env-a
```

## 📋 Что добавлено

### Основные компоненты

1. **📖 testing-methodology.md** - Полное описание методики
2. **🎮 demo-testing-system.sh** - Интерактивная демонстрация
3. **📚 testing/README.md** - Подробное руководство пользователя

### Скрипты автоматизации

- **🔧 test-env-manager.sh** - Управление тестовыми средами
- **🧪 run-tests.sh** - Автоматизированное тестирование
- **📊 Мониторинг** - Prometheus + Grafana

### Тестовые среды

- **env-a/** - Текущая архитектура (LiveKit + ARI)
- **env-b/** - Прямая интеграция (Direct Agent)
- **env-c/** - Микросервисная архитектура

## 🏗️ Архитектуры для тестирования

### Архитектура A: Текущая
```
Novofon → Asterisk → ARI → LiveKit Agent → AI Services
```
- ✅ Максимальная функциональность
- ❌ Сложность настройки

### Архитектура B: Прямая интеграция
```
Novofon → Asterisk → Direct Python Agent → AI Services
```
- ✅ Простота и надежность
- ❌ Ограниченная функциональность

### Архитектура C: Микросервисы
```
Novofon → Asterisk → Message Queue → Multiple Agents → AI Services
```
- ✅ Масштабируемость
- ❌ Сложность управления

## 🔒 Принципы безопасности

### Полная изоляция
- 🌐 Отдельные Docker сети для каждой среды
- 🔌 Уникальные порты (8081/8082/8083)
- 💾 Изолированные volumes и базы данных
- 🔑 Отдельные API ключи и SIP аккаунты

### Безопасный откат
- ⏹️ Быстрая остановка: `test-env-manager.sh stop env-a`
- 🧹 Полная очистка: `test-env-manager.sh clean env-a`
- 📝 Версионирование конфигураций
- 🔄 Автоматические бэкапы

## 📊 Система тестирования

### Типы тестов

1. **🧪 Базовое тестирование**
   ```bash
   ./testing/shared/scripts/run-tests.sh test env-a
   ```
   - Подключение к Asterisk
   - SIP регистрация
   - ARI интерфейс
   - Производительность

2. **🔄 Сравнительное тестирование**
   ```bash
   ./testing/shared/scripts/run-tests.sh compare env-a env-b
   ```
   - Автоматическое сравнение архитектур
   - Генерация отчетов
   - Рекомендации по выбору

3. **⚡ Нагрузочное тестирование**
   ```bash
   ./testing/shared/scripts/run-tests.sh load env-a 10
   ```
   - Множественные звонки
   - Метрики производительности

### Мониторинг

```bash
cd testing/shared/monitoring
docker-compose -f docker-compose.monitoring.yml up -d
```

- **📊 Prometheus**: http://localhost:9090
- **📈 Grafana**: http://localhost:3000 (admin/admin123)
- **🖥️ Node Exporter**: http://localhost:9100
- **📦 cAdvisor**: http://localhost:8080

## 📈 Критерии оценки

### Весовые коэффициенты
1. **Производительность (40%)**
   - Время отклика < 2 секунд
   - Использование CPU < 50%
   - Использование памяти < 1GB

2. **Надежность (30%)**
   - Успешность тестов > 90%
   - Стабильность SIP соединений
   - Обработка ошибок

3. **Простота поддержки (20%)**
   - Сложность конфигурации
   - Количество компонентов
   - Документированность

4. **Масштабируемость (10%)**
   - Поддержка множественных звонков
   - Горизонтальное масштабирование

## 🛠️ Примеры использования

### Создание и тестирование среды
```bash
# Создать среду
./testing/shared/scripts/test-env-manager.sh create env-a

# Настроить переменные
nano testing/env-a/.env.test

# Запустить среду
./testing/shared/scripts/test-env-manager.sh start env-a

# Запустить тесты
./testing/shared/scripts/run-tests.sh test env-a

# Просмотреть результаты
./testing/shared/scripts/run-tests.sh results
```

### Сравнение архитектур
```bash
# Создать две среды
./testing/shared/scripts/test-env-manager.sh create env-a
./testing/shared/scripts/test-env-manager.sh create env-b

# Запустить обе среды
./testing/shared/scripts/test-env-manager.sh start env-a
./testing/shared/scripts/test-env-manager.sh start env-b

# Сравнительное тестирование
./testing/shared/scripts/run-tests.sh compare env-a env-b
```

## 📚 Документация

- **📋 testing-methodology.md** - Полная методика
- **📖 testing/README.md** - Руководство пользователя
- **🎮 demo-testing-system.sh** - Интерактивная демонстрация
- **🔧 Комментарии в скриптах** - Подробные объяснения

## 🤝 Интеграция с основной веткой

После выбора оптимальной архитектуры:

1. Проанализировать результаты тестирования
2. Выбрать лучший подход
3. Создать Pull Request с выбранной архитектурой
4. Обновить продакшн систему

## ⚠️ Важные замечания

- **Используйте отдельные тестовые аккаунты Novofon!**
- **Не запускайте тесты на продакшн данных**
- **Регулярно очищайте тестовые среды**
- **Мониторьте использование ресурсов**

## 🔗 Полезные ссылки

- [Основной репозиторий](https://github.com/YuriyZhabov/voip-platform)
- [Issues для вопросов](https://github.com/YuriyZhabov/voip-platform/issues)
- [Pull Requests](https://github.com/YuriyZhabov/voip-platform/pulls)

---

**Автор**: Kiro AI Assistant  
**Дата создания**: 18 января 2025  
**Версия**: 1.0  

*Эта ветка предоставляет полный набор инструментов для безопасного тестирования и сравнения различных архитектурных подходов к VoIP голосовому агенту.*