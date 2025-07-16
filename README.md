# VoIP Platform с FreePBX и LiveKit

Комплексная VoIP платформа, объединяющая FreePBX для управления телефонией, LiveKit для обработки медиа и AI агентов для интеллектуальной обработки звонков.

## 🏗️ Архитектура

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   FreePBX       │    │  LiveKit Agent  │    │   LiveKit       │
│   (Asterisk)    │◄──►│   (AI Voice)    │◄──►│   (Media)       │
│   Port: 80/443  │    │   Port: 8081    │    │   Cloud Service │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   SIP Provider  │    │   AI Services   │    │   WebRTC        │
│   (Novofon)     │    │   OpenAI/etc    │    │   Clients       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🚀 Быстрый старт

### 1. Клонирование репозитория
```bash
git clone https://github.com/YuriyZhabov/voip-platform.git
cd voip-platform
```

### 2. Настройка переменных окружения
```bash
cp .env.example .env
# Отредактируйте .env файл с вашими настройками
```

### 3. Запуск платформы
```bash
docker-compose up -d
```

### 4. Ожидание инициализации
FreePBX требует до 30 минут для первоначальной установки. Следите за логами:
```bash
docker-compose logs -f freepbx
```

## 🔧 Компоненты

### FreePBX Server
- **Порты**: 80 (HTTP), 443 (HTTPS), 5060 (SIP), 5061 (SIP TLS)
- **RTP**: 18000-20000/UDP
- **Веб-интерфейс**: http://your-server/admin
- **База данных**: MariaDB (отдельный контейнер)

### LiveKit Agent
- **Порт**: 8081
- **AI сервисы**: OpenAI, Deepgram, Cartesia
- **Функции**: Распознавание речи, синтез речи, обработка диалогов

### Redis Cache
- **Порт**: 6379
- **Функции**: Кэширование, сессии, очереди

## 📋 Настройка

### FreePBX
1. Откройте http://your-server/admin
2. Пройдите мастер первоначальной настройки
3. Настройте SIP транк для Novofon:
   - Connectivity → Trunks → Add SIP (chan_pjsip)
   - Username: ваш логин Novofon
   - Secret: ваш пароль Novofon
   - SIP Server: sip.novofon.ru

### Novofon SIP
Подробная инструкция в файле [novofon.md](novofon.md)

### LiveKit Agent
Агент автоматически подключается к LiveKit Cloud с настройками из .env файла.

## 🔐 Переменные окружения

### LiveKit
```env
LIVEKIT_URL=wss://your-livekit-server
LIVEKIT_API_KEY=your_api_key
LIVEKIT_API_SECRET=your_api_secret
```

### Novofon SIP
```env
NOVOFON_USERNAME=your_username
NOVOFON_PASSWORD=your_password
NOVOFON_NUMBER=your_phone_number
```

### AI сервисы
```env
OPENAI_API_KEY=your_openai_key
DEEPGRAM_API_KEY=your_deepgram_key
CARTESIA_API_KEY=your_cartesia_key
```

## 🛠️ Управление

### Просмотр статуса
```bash
docker-compose ps
```

### Просмотр логов
```bash
docker-compose logs freepbx
docker-compose logs livekit-agent
```

### Перезапуск сервисов
```bash
docker-compose restart freepbx
docker-compose restart livekit-agent
```

### Остановка платформы
```bash
docker-compose down
```

## 📊 Мониторинг

### Health Checks
- FreePBX: http://your-server/admin
- LiveKit Agent: Проверка через логи
- Redis: `redis-cli ping`

### Логи
- FreePBX: `docker-compose logs freepbx`
- Asterisk CLI: `docker exec freepbx-server asterisk -rx "core show version"`

## 🔧 Отладка

### Проверка SIP регистрации
```bash
docker exec freepbx-server asterisk -rx "pjsip show registrations"
```

### Проверка endpoints
```bash
docker exec freepbx-server asterisk -rx "pjsip show endpoints"
```

### Тестовый звонок
```bash
docker exec freepbx-server asterisk -rx "channel originate Local/8888@from-internal application Wait 5"
```

## 📚 Документация

- [Интеграция с Novofon](novofon.md) - Подробная настройка SIP
- [FreePBX Documentation](https://wiki.freepbx.org/)
- [LiveKit Documentation](https://docs.livekit.io/)

## 🤝 Поддержка

Для вопросов и поддержки создавайте Issues в GitHub репозитории.

## 📄 Лицензия

MIT License - см. файл LICENSE для деталей.