# 🎤 VoIP AI Agent с Аудио Мостом

Полноценная система голосового ИИ ассистента с интеграцией Asterisk и LiveKit через аудио мост.

## 🎯 Что изменилось

### ✅ Новые компоненты:
- **AudioBridge** (`audio_bridge.py`) - мост между Asterisk и LiveKit
- **MainAgent** (`main_agent.py`) - главный агент системы
- **Обновленный диалплан** - поддержка аудио моста
- **Health check** - мониторинг состояния системы

### 🔧 Улучшения:
- Реальная передача аудио между Asterisk и LiveKit
- Русскоязычный ИИ ассистент с функциями (погода, время)
- Автоматическое управление звонками
- Мониторинг и логирование
- Тестовые номера для отладки

## 🚀 Быстрый старт

### 1. Обновление системы
```bash
# Запуск скрипта обновления
./scripts/update-to-audio-bridge.sh
```

### 2. Проверка системы
```bash
# Тестирование всех компонентов
./scripts/test-audio-bridge.sh
```

### 3. Мониторинг
```bash
# Логи агента
docker logs livekit-agent -f

# Health check
curl http://localhost:8081/health

# Статистика
curl http://localhost:8081/stats
```

## 📞 Как это работает

### Схема работы:
1. **Звонок поступает** на Novofon → Asterisk
2. **Диалплан** направляет звонок в Stasis приложение
3. **AudioBridge** получает событие и создает LiveKit комнату
4. **Аудио мост** соединяет Asterisk канал с LiveKit
5. **ИИ ассистент** подключается к комнате и начинает разговор

### Компоненты:

#### 🌉 AudioBridge
- Обрабатывает ARI события от Asterisk
- Создает LiveKit комнаты для каждого звонка
- Управляет аудио мостами между каналами
- Запускает ИИ ассистентов

#### 🤖 MainAgent
- Координирует работу всей системы
- Предоставляет HTTP API для мониторинга
- Управляет жизненным циклом компонентов

#### 📋 Диалплан
- `from-novofon` - обработка входящих звонков
- `livekit-bridge` - мостовые каналы для LiveKit
- Тестовые номера (9999, 8888, 7777, 6666)

## 🧪 Тестирование

### Тестовые номера:
- **9999** - тест ИИ агента
- **8888** - тест эхо
- **7777** - тест воспроизведения
- **6666** - тест записи

### Основной номер:
- **+79952227978** - рабочий номер с ИИ ассистентом

## 🔧 Конфигурация

### Обязательные переменные в `.env`:
```bash
# LiveKit
LIVEKIT_URL=wss://your-instance.livekit.cloud
LIVEKIT_API_KEY=your_api_key
LIVEKIT_API_SECRET=your_api_secret

# AI сервисы
OPENAI_API_KEY=sk-proj-your_key
DEEPGRAM_API_KEY=your_key
CARTESIA_API_KEY=sk_car_your_key

# Novofon
NOVOFON_USERNAME=your_username
NOVOFON_PASSWORD=your_password
NOVOFON_NUMBER=+79952227978
```

### Настройки ИИ:
```bash
# OpenAI
OPENAI_MODEL=gpt-4o-mini
OPENAI_TEMPERATURE=0.7

# Deepgram (STT)
DEEPGRAM_MODEL=nova-2
DEEPGRAM_LANGUAGE=ru

# Cartesia (TTS)
CARTESIA_MODEL=sonic-multilingual
CARTESIA_VOICE=87748186-23bb-4158-a1eb-332911b0b708
CARTESIA_LANGUAGE=ru
```

## 📊 Мониторинг

### HTTP API:
- `GET /health` - проверка работоспособности
- `GET /status` - детальный статус системы
- `GET /stats` - статистика звонков

### Логи:
```bash
# Все логи агента
docker logs livekit-agent -f

# Логи Asterisk
docker logs freepbx-server -f

# Системные логи
docker-compose logs -f
```

### Asterisk CLI:
```bash
# Подключение к консоли
docker exec -it freepbx-server asterisk -rvvv

# Полезные команды:
ari show apps              # ARI приложения
dialplan show from-novofon  # Диалплан
core show channels         # Активные каналы
```

## 🛠️ Отладка

### Частые проблемы:

#### 1. ARI приложение не регистрируется
```bash
# Проверка ARI конфигурации
docker exec freepbx-server cat /etc/asterisk/ari.conf

# Перезагрузка ARI модуля
docker exec freepbx-server asterisk -rx "module reload res_ari.so"
```

#### 2. Диалплан не работает
```bash
# Проверка диалплана
docker exec freepbx-server asterisk -rx "dialplan show from-novofon"

# Перезагрузка диалплана
docker exec freepbx-server asterisk -rx "dialplan reload"
```

#### 3. LiveKit агент не отвечает
```bash
# Проверка health check
curl -v http://localhost:8081/health

# Логи агента
docker logs livekit-agent --tail=50
```

#### 4. Нет звука в разговоре
```bash
# Проверка мостов
docker exec freepbx-server asterisk -rx "bridge show all"

# Проверка каналов
docker exec freepbx-server asterisk -rx "core show channels verbose"
```

## 🔄 Обновление

### Обновление кода:
```bash
# Остановка системы
docker-compose down

# Обновление образов
docker-compose build --no-cache

# Запуск обновленной системы
./scripts/update-to-audio-bridge.sh
```

### Откат к предыдущей версии:
```bash
# Восстановление из резервной копии
cp -r ./data/asterisk/config.backup.* ./data/asterisk/config/

# Перезапуск системы
docker-compose restart
```

## 📈 Производительность

### Рекомендуемые ресурсы:
- **CPU**: 2+ ядра
- **RAM**: 4+ GB
- **Диск**: 20+ GB SSD
- **Сеть**: стабильное соединение

### Ограничения:
- Максимум 10 одновременных звонков
- Максимальная длительность звонка: 30 минут
- Таймаут тишины: 5 минут

## 🆘 Поддержка

### Полезные команды:
```bash
# Полная диагностика
./scripts/test-audio-bridge.sh

# Перезапуск только агента
docker-compose restart livekit-agent

# Очистка логов
docker system prune -f
```

### Контакты:
- Логи системы: `/data/logs/`
- Конфигурации: `/configs/`
- Документация: `README.md`

---

🎉 **Система готова к работе!** Звоните на ваш номер и общайтесь с ИИ ассистентом!