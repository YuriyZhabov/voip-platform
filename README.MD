# VoIP Platform с AI Agent

Современная VoIP платформа на базе Asterisk 22 с поддержкой AI агентов и интеграцией с LiveKit Cloud.

## 🚀 Быстрый старт

### 1. Клонирование репозитория
```bash
git clone https://github.com/YuriyZhabov/voip-platform.git
cd voip-platform
```

### 2. Настройка окружения
```bash
# Скопируйте файл с примером переменных окружения
cp .env.example .env

# Отредактируйте .env файл, добавив ваши API ключи и настройки
nano .env
```

### 3. Запуск платформы
```bash
# Запуск всех сервисов
docker-compose up -d

# Просмотр логов
docker-compose logs -f
```

## 📋 Архитектура системы

Система использует облачную архитектуру LiveKit с локальными компонентами:

- **Novofon SIP Provider** - входящие звонки через SIP-транк
- **Asterisk 22 PBX** - локальная АТС с PJSIP для обработки звонков
- **LiveKit Cloud** - облачный сервис для WebRTC и медиа-обработки
- **AI Agent** - локальный ИИ-агент с интеграцией OpenAI, Deepgram, Cartesia
- **Redis** - кеширование и хранение сессий

## 🏗️ Структура проекта

```
voip-platform/
├── docker-compose.yml          # Основная конфигурация Docker
├── .env.example               # Пример переменных окружения
├── configs/
│   ├── asterisk/             # Конфигурация Asterisk 22
│   │   ├── pjsip.conf       # Настройки PJSIP
│   │   ├── extensions.conf   # Диалплан
│   │   ├── modules.conf     # Модули Asterisk
│   │   ├── ari.conf         # Asterisk REST Interface
│   │   ├── stasis.conf      # Stasis приложения
│   │   ├── http.conf        # HTTP сервер
│   │   ├── manager.conf     # AMI интерфейс
│   │   ├── logger.conf      # Логирование
│   │   ├── security.conf    # Безопасность
│   │   ├── cdr.conf         # Call Detail Records
│   │   ├── cel.conf         # Channel Event Logging
│   │   └── features.conf    # Функции звонков
│   ├── agent/               # AI Agent
│   │   ├── agent.py         # Основной код агента
│   │   ├── tools.py         # Дополнительные инструменты
│   │   ├── config.py        # Конфигурация агента
│   │   ├── requirements.txt # Python зависимости
│   │   └── Dockerfile       # Docker образ агента
│   └── redis/
│       └── redis.conf       # Конфигурация Redis
├── docker/
│   └── asterisk/
│       ├── Dockerfile       # Docker образ Asterisk 22
│       └── entrypoint.sh    # Скрипт запуска с XML документацией
├── scripts/
│   ├── init-asterisk.sh     # Инициализация Asterisk
│   ├── init-agent.sh        # Инициализация агента
│   └── backup.sh            # Резервное копирование
└── docs/                    # Документация
    ├── asterisk.md          # Документация Asterisk
    ├── asterisk_22_upgrade.md
    ├── asterisk_stasis.md
    ├── res_ari.md
    ├── res_statsd.md
    └── pjsip.md
```

## ⚙️ Основные компоненты

### Asterisk 22
- Современная версия с улучшенной поддержкой WebRTC
- PJSIP для SIP коммуникации
- ARI (Asterisk REST Interface) для интеграции с внешними приложениями
- Stasis приложения для обработки звонков
- Полная XML документация для всех модулей

### AI Agent
- Основан на LiveKit Agents Framework
- Интеграция с OpenAI GPT-4o-mini для понимания языка
- Deepgram для распознавания речи (STT)
- Cartesia для синтеза речи (TTS)
- Поддержка русского языка
- Health check endpoints

### Redis
- Кеширование данных сессий
- Хранение временных данных агента
- Координация между компонентами

## 🔧 Конфигурация

### Переменные окружения (.env)

```bash
# LiveKit Cloud настройки
LIVEKIT_URL=wss://your-livekit-instance.livekit.cloud
LIVEKIT_API_KEY=your_api_key
LIVEKIT_API_SECRET=your_api_secret
LIVEKIT_DOMAIN=your-domain.com
LIVEKIT_PUBLIC_IP=your.public.ip

# SIP провайдер (Novofon)
NOVOFON_NUMBER=+7XXXXXXXXXX
NOVOFON_SIP_SERVER=sip.novofon.ru
NOVOFON_USERNAME=your_username
NOVOFON_PASSWORD=your_password

# AI сервисы
OPENAI_API_KEY=sk-proj-your_openai_key
DEEPGRAM_API_KEY=your_deepgram_key
CARTESIA_API_KEY=sk_car_your_cartesia_key

# Asterisk
ASTERISK_USER=asterisk
ASTERISK_MANAGER_SECRET=your_manager_secret
```

### Docker Compose сервисы

- **asterisk** - Asterisk 22 PBX с network_mode: host
- **livekit-agent** - AI агент с health check
- **redis** - Redis для кеширования

## 🚀 Запуск и управление

### Запуск системы
```bash
# Запуск всех сервисов
docker-compose up -d

# Просмотр статуса
docker-compose ps

# Просмотр логов
docker-compose logs -f asterisk
docker-compose logs -f livekit-agent
```

### Проверка работоспособности
```bash
# Health check агента
curl http://localhost:8081/health

# Статус Asterisk
docker exec asterisk-pbx asterisk -rx "core show version"

# Регистрация SIP
docker exec asterisk-pbx asterisk -rx "pjsip show registrations"

# Проверка Redis
docker exec redis-cache redis-cli ping
```

### Обновление и перезапуск
```bash
# Перезапуск отдельного сервиса
docker-compose restart livekit-agent

# Пересборка с обновлениями
docker-compose build --no-cache
docker-compose up -d
```

## 🔍 Мониторинг и отладка

### Логи
- Asterisk: `/var/log/asterisk/`
- Agent: контейнер логи + `/logs/agent.log`
- Redis: контейнер логи

### Health Check endpoints
- Agent: `http://localhost:8081/health`
- Agent status: `http://localhost:8081/status`

### Диагностические команды
```bash
# Asterisk CLI
docker exec -it asterisk-pbx asterisk -r

# Проверка PJSIP endpoints
docker exec asterisk-pbx asterisk -rx "pjsip show endpoints"

# Проверка активных каналов
docker exec asterisk-pbx asterisk -rx "core show channels"

# Тестирование агента
docker exec -it livekit-agent python agent.py console
```

## 🔒 Безопасность

### Рекомендации
1. Используйте сильные пароли для всех сервисов
2. Ограничьте доступ к портам через firewall
3. Регулярно обновляйте API ключи
4. Мониторьте использование API квот
5. Используйте HTTPS/WSS для всех соединений

### Файлы безопасности
- `.env` - исключен из git, содержит секреты
- `configs/asterisk/security.conf` - настройки безопасности Asterisk
- `configs/asterisk/manager.conf` - ограничения AMI доступа

## 📚 Документация

Подробная документация доступна в папке проекта:
- [Asterisk 22 Setup](asterisk.md)
- [Asterisk 22 Upgrade Guide](asterisk_22_upgrade.md)
- [Stasis Applications](asterisk_stasis.md)
- [ARI Integration](res_ari.md)
- [StatsD Monitoring](res_statsd.md)
- [PJSIP Configuration](pjsip.md)
- [Quick Start Guide](QUICKSTART.md)

## 🤝 Поддержка

Для получения поддержки:
1. Проверьте документацию в папке проекта
2. Изучите логи сервисов
3. Используйте health check endpoints для диагностики
4. Создайте issue в GitHub репозитории

## 📄 Лицензия

Этот проект распространяется под лицензией MIT. См. файл LICENSE для подробностей.

---

**Примечание**: Перед использованием в продакшене убедитесь, что все API ключи и пароли настроены правильно, а система протестирована в вашей среде.