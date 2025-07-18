# VoIP Platform с AI Agent

Современная VoIP платформа на базе Asterisk 22 с поддержкой AI агентов, интеграцией с LiveKit Cloud, Traefik для проксирования и SSL, и полной интеграцией с Novofon SIP провайдером.

## 🏗️ Архитектура

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Traefik       │    │   FreePBX       │    │  LiveKit Agent  │
│   (Proxy/SSL)   │◄──►│   (Asterisk)    │◄──►│   (AI Voice)    │
│   Port: 80/443  │    │   Port: 80      │    │   Port: 8081    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Let's Encrypt │    │   SIP Provider  │    │   AI Services   │
│   (SSL Certs)   │    │   (Novofon)     │    │   OpenAI/etc    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🚀 Быстрый старт

### 1. Клонирование и подготовка
```bash
git clone https://github.com/YuriyZhabov/voip-platform.git
cd voip-platform

# Создание внешней сети для Traefik
docker network create traefik-public
```

### 2. Настройка переменных окружения
```bash
cp .env.example .env
# Отредактируйте .env файл с вашими настройками
```

### 3. Автоматический запуск системы
```bash
# Обычный запуск
./scripts/start-system.sh

# Запуск с очисткой данных (полная пересборка)
./scripts/start-system.sh --clean
```

### 4. Проверка системы
```bash
# Запуск тестирования всех компонентов
./scripts/test_system.sh

# Детальная информация о системе
./scripts/test_system.sh --detailed
```

### 5. Мониторинг входящих звонков
```bash
# Мониторинг в реальном времени
./scripts/monitor_incoming_calls.sh
```

## 🔧 Компоненты

### Traefik Proxy
- **Порты**: 80 (HTTP), 443 (HTTPS), 8080 (Dashboard), 8089 (WebSocket), 5060/5160 (SIP)
- **Функции**: 
  - Автоматическое получение SSL сертификатов Let's Encrypt
  - Проксирование HTTP/HTTPS, WebSocket, SIP TCP/UDP
  - Безопасные заголовки и rate limiting
  - Мониторинг и health checks

### FreePBX Server (Asterisk 22)
- **Веб-интерфейс**: https://pbx.stellaragents.ru/admin
- **Протоколы**: HTTP/HTTPS, WebSocket (WSS), SIP TCP/UDP
- **RTP**: 18000-18100/UDP
- **База данных**: MariaDB (отдельный контейнер)

### LiveKit Agent
- **Порт**: 8081
- **AI сервисы**: OpenAI, Deepgram, Cartesia
- **Функции**: Распознавание речи, синтез речи, обработка диалогов

### Redis Cache
- **Порт**: 6379
- **Функции**: Кэширование, сессии, очереди

## 📋 Настройка

### Traefik
Traefik настроен автоматически и обеспечивает:
- Автоматическое перенаправление HTTP → HTTPS
- SSL сертификаты Let's Encrypt для домена pbx.stellaragents.ru
- Проксирование всех протоколов FreePBX
- Безопасность с аутентификацией Dashboard

**Доступ к Dashboard**: https://traefik.stellaragents.ru (admin:TraefikAdmin2025!)

### FreePBX
1. Откройте https://pbx.stellaragents.ru/admin
2. Пройдите мастер первоначальной настройки
3. Настройте SIP транк для Novofon:
   - Connectivity → Trunks → Add SIP (chan_pjsip)
   - Username: ваш логин Novofon
   - Secret: ваш пароль Novofon
   - SIP Server: sip.novofon.ru

### LiveKit Agent
Агент автоматически подключается к LiveKit Cloud с настройками из .env файла.

## 🔐 Переменные окружения

### LiveKit
```env
LIVEKIT_URL=wss://your-livekit-server
LIVEKIT_API_KEY=your_api_key
LIVEKIT_API_SECRET=your_api_secret
LIVEKIT_PUBLIC_IP=your_public_ip
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

### Автоматические скрипты управления

**Запуск системы:**
```bash
# Обычный запуск (восстанавливает конфигурации после пересборки)
./scripts/start-system.sh

# Полная пересборка с очисткой данных
./scripts/start-system.sh --clean

# Справка по опциям
./scripts/start-system.sh --help
```

**Тестирование системы:**
```bash
# Быстрое тестирование всех компонентов (6 тестов)
./scripts/test_system.sh

# Детальная информация о системе
./scripts/test_system.sh --detailed
```

**Мониторинг:**
```bash
# Мониторинг входящих звонков в реальном времени
./scripts/monitor_incoming_calls.sh
```

### Что делает скрипт start-system.sh

Скрипт автоматически решает проблему потери конфигураций при пересборке FreePBX:

1. **Подготавливает инфраструктуру** - создает сети, запускает контейнеры
2. **Ожидает готовности FreePBX** - до 30 минут на полную инициализацию
3. **Восстанавливает ARI конфигурацию** - настройки для связи с LiveKit
4. **Восстанавливает диалплан** - из файла `configs/dialplan/extensions_dialplan.conf`
5. **Запускает ARI клиент** - исправленную версию для стабильной работы
6. **Проверяет все компоненты** - SIP регистрация, endpoints, LiveKit агент
7. **Выводит статус системы** - готовность к приему звонков

### Что проверяет test_system.sh

Скрипт тестирования проверяет 6 ключевых компонентов:

1. ✅ **Asterisk** - основной движок VoIP системы
2. ✅ **SIP регистрация** - подключение к провайдеру Novofon
3. ✅ **ARI приложение** - интерфейс для LiveKit агента
4. ✅ **LiveKit агент** - AI голосовой помощник
5. ✅ **Диалплан** - маршрутизация входящих звонков
6. ✅ **Внутренние звонки** - тестовые номера (9999, 8888)

### Ручное управление Docker

**Просмотр статуса:**
```bash
docker-compose ps
```

**Просмотр логов:**
```bash
docker-compose logs freepbx
docker-compose logs traefik
docker-compose logs livekit-agent
```

**Перезапуск сервисов:**
```bash
docker-compose restart freepbx
docker-compose restart traefik
docker-compose restart livekit-agent
```

**Остановка платформы:**
```bash
docker-compose down
```

## 📊 Мониторинг

### Health Checks
- FreePBX: https://pbx.stellaragents.ru/admin
- Traefik Dashboard: https://traefik.stellaragents.ru
- LiveKit Agent: Проверка через логи
- Redis: `redis-cli ping`

### Проверка SSL сертификатов
```bash
# Проверка сертификата
curl -I https://pbx.stellaragents.ru

# Информация о сертификате
openssl s_client -connect pbx.stellaragents.ru:443 -servername pbx.stellaragents.ru
```

### Логи
- FreePBX: `docker-compose logs freepbx`
- Traefik: `docker-compose logs traefik`
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

### Проблемы с Traefik
```bash
# Проверка маршрутов
curl http://localhost:8080/api/http/routers

# Проверка сертификатов
curl http://localhost:8080/api/http/routers | jq '.[] | select(.tls)'

# Логи доступа
docker exec traefik-proxy tail -f /var/log/traefik/access.log
```

## 🔒 Безопасность

### Настроенные меры безопасности
- **HTTPS принудительно**: Все HTTP запросы перенаправляются на HTTPS
- **HSTS заголовки**: Принудительное использование HTTPS браузерами
- **Rate Limiting**: Защита от DDoS атак (100 burst, 50 avg/sec)
- **Безопасные заголовки**: X-Frame-Options, X-Content-Type-Options, etc.
- **Basic Auth**: Защита Traefik Dashboard

### Рекомендации для продакшена
1. Смените пароли по умолчанию
2. Ограничьте доступ к Dashboard по IP
3. Регулярно обновляйте компоненты
4. Мониторьте логи доступа
5. Настройте backup сертификатов

## 🏗️ Архитектурные особенности

### Traefik как единая точка входа
Traefik обрабатывает все типы трафика FreePBX:
- **HTTP/HTTPS** (L7): Веб-интерфейс с SSL терминацией
- **WebSocket (WSS)** (L7): WebRTC соединения с TLS
- **SIP TCP/UDP** (L4): Прозрачное проксирование без модификации
- **RTP UDP**: Прямой проброс диапазона портов 18000-18100

### Сетевая архитектура
- **traefik-public**: Внешняя сеть для Traefik и FreePBX
- **default**: Внутренняя сеть для FreePBX, БД и других сервисов
- **Порты**: Только необходимые порты открыты наружу через Traefik

## 🔄 Backup и восстановление

### Backup сертификатов Let's Encrypt
```bash
# Создание backup
docker run --rm -v voip-platform_traefik-letsencrypt:/data -v $(pwd):/backup alpine tar czf /backup/letsencrypt-backup.tar.gz -C /data .

# Восстановление
docker run --rm -v voip-platform_traefik-letsencrypt:/data -v $(pwd):/backup alpine tar xzf /backup/letsencrypt-backup.tar.gz -C /data
```

### Backup FreePBX
```bash
# Backup данных FreePBX
docker run --rm -v voip-platform_freepbx-data:/data -v $(pwd):/backup alpine tar czf /backup/freepbx-data-backup.tar.gz -C /data .

# Backup базы данных
docker exec freepbx-database mysqldump -u root -proot_password asterisk > freepbx-db-backup.sql
```

## 🚨 Устранение неполадок

### FreePBX не запускается
1. Проверьте логи: `docker-compose logs freepbx`
2. Убедитесь, что база данных запущена: `docker-compose ps freepbx-db`
3. Проверьте права доступа к volumes

### Traefik не получает сертификаты
1. Проверьте DNS записи для домена
2. Убедитесь, что порт 80 открыт для HTTP Challenge
3. Проверьте логи ACME: `docker-compose logs traefik | grep -i acme`

### Проблемы с аудио (RTP)
1. Убедитесь, что порты 18000-18100/UDP открыты
2. Проверьте NAT настройки в FreePBX
3. Убедитесь, что external_media_address указан правильно

### SIP регистрация не работает
1. Проверьте настройки SIP транка в FreePBX
2. Убедитесь, что порты 5060/5160 проксируются корректно
3. Проверьте логи Asterisk: `docker exec freepbx-server asterisk -rx "pjsip set logger on"`

## � Структиура проекта

```
voip-platform/
├── docker-compose.yml          # Основная конфигурация Docker
├── .env.example               # Пример переменных окружения
├── fixed_ari_client.py        # Исправленный ARI клиент для LiveKit
├── init-asterisk-config.sh    # Скрипт инициализации Asterisk
├── configs/
│   ├── asterisk/             # Конфигурация Asterisk 22
│   │   ├── pjsip_custom.conf # Настройки PJSIP (SIP провайдер)
│   │   ├── extensions_custom.conf # Базовый диалплан
│   │   ├── ari.conf         # Asterisk REST Interface
│   │   └── http.conf        # HTTP сервер
│   ├── dialplan/            # Диалплан системы
│   │   ├── extensions_dialplan.conf # Основной диалплан
│   │   └── README.md        # Документация диалплана
│   └── agent/               # AI Agent
│       ├── agent.py         # Основной код агента
│       ├── voice_agent.py   # Голосовой агент
│       ├── ari_watchdog.py  # Мониторинг ARI соединения
│       ├── validate_url.py  # Валидация URL
│       ├── requirements.txt # Python зависимости
│       └── Dockerfile       # Docker образ агента
├── scripts/                 # Скрипты управления
│   ├── start-system.sh      # Автоматический запуск системы
│   ├── test_system.sh       # Тестирование всех компонентов
│   └── monitor_incoming_calls.sh # Мониторинг звонков
└── docker/
    ├── traefik/
    │   ├── traefik.yml      # Статическая конфигурация Traefik
    │   └── dynamic.yml      # Динамическая конфигурация
    └── freepbx/
        ├── Dockerfile       # Docker образ FreePBX
        └── entrypoint.sh    # Скрипт запуска
```

## 🔄 Автоматическое восстановление конфигураций

### Проблема пересборки
При пересборке FreePBX теряет пользовательские конфигурации (диалплан, ARI настройки). Система решает эту проблему автоматически.

### Решение
Скрипт `start-system.sh` автоматически:

1. **Восстанавливает диалплан** из файла `configs/dialplan/extensions_dialplan.conf`
2. **Настраивает ARI интерфейс** с правильными учетными данными
3. **Запускает ARI клиент** для связи с LiveKit
4. **Проверяет все компоненты** системы

### Редактирование диалплана
Диалплан теперь хранится в отдельном файле для удобства редактирования:

```bash
# Отредактируйте диалплан
nano configs/dialplan/extensions_dialplan.conf

# Перезапустите систему для применения изменений
./scripts/start-system.sh
```

**Преимущества вынесения диалплана в отдельный файл:**
- ✅ Легко редактировать без изменения скрипта запуска
- ✅ Версионирование изменений в Git
- ✅ Автоматическое восстановление после пересборки FreePBX
- ✅ Возможность создания разных версий диалплана для разных сред

## 🔧 Интеграция с Novofon SIP

### Настройка PJSIP для Novofon

**Файл pjsip.conf:**

```ini
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0
external_media_address=94.131.122.253
external_signaling_address=94.131.122.253

[0053248_reg]
type=registration
transport=transport-udp
outbound_auth=0053248_auth
server_uri=sip:sip.novofon.ru:5060
client_uri=sip:0053248@sip.novofon.ru:5060
retry_interval=20
forbidden_retry_interval=600
expiration=120
contact_user=0053248

[0053248_auth]
type=auth
auth_type=userpass
password=P5Nt8yKbey
username=0053248

[0053248]
type=aor
contact=sip:sip.novofon.ru:5060

[0053248]
type=endpoint
transport=transport-udp
context=novofon-in
disallow=all
allow=alaw,ulaw
outbound_auth=0053248_auth
aors=0053248
from_user=0053248
from_domain=sip.novofon.ru
direct_media=no
rtp_symmetric=yes
force_rport=yes

[0053248]
type=identify
endpoint=0053248
match=sip.novofon.ru
```

### Настройка внутренних номеров

```ini
[101]
type=endpoint
transport=transport-udp
context=novofon-out
disallow=all
allow=alaw,ulaw
auth=101
aors=101

[101]
type=auth
auth_type=userpass
password=101
username=101

[101]
type=aor
max_contacts=10
```

### Маршрутизация в extensions.conf

```ini
[novofon-in]
exten => 79952227978,1,Answer()
same => n,Stasis(livekit-agent)
exten => +79952227978,1,Answer()
same => n,Stasis(livekit-agent)

[novofon-out]
exten => _XXX,1,Dial(PJSIP/${EXTEN})
exten => _XXX.,1,Dial(PJSIP/${EXTEN}@0053248)
```

### Настройка в FreePBX

1. **Connectivity → Trunks** → добавить SIP(chan_pjsip) Trunk
2. **PJSIP Settings → General:**
   - Username: `0053248`
   - Auth username: `0053248`
   - Secret: `P5Nt8yKbey`
3. **PJSIP Settings → Advanced:**
   - Contact User: `0053248`
   - From Domain: `sip.novofon.ru`
   - From User: `0053248`
   - Client URI: `sip:0053248@sip.novofon.ru:5060`
   - Server URI: `sip:sip.novofon.ru:5060`
   - AOR Contact: `sip:sip.novofon.ru:5060`

### Тестирование подключения к Novofon

```bash
# Проверка регистрации
docker exec freepbx-server asterisk -rx "pjsip show registrations"

# Проверка статуса endpoint
docker exec freepbx-server asterisk -rx "pjsip show endpoint 0053248"

# Проверка аутентификации
docker exec freepbx-server asterisk -rx "pjsip show auth 0053248_auth"
```

## 🛡️ Безопасность системы

### Firewall (UFW)
- **Статус**: Активен
- **Политика по умолчанию**: Запретить входящие, разрешить исходящие
- **Открытые порты**:
  - 22/tcp (SSH)
  - 80/tcp (HTTP)
  - 443/tcp (HTTPS)
  - 5060/udp (SIP)
  - 5061/tcp (SIP TLS)
  - 18000-18100/udp (RTP)
  - 6379/tcp (Redis)

### Fail2ban
- **Статус**: Активен
- **Защищенные сервисы**:
  - SSH (3 попытки, бан на 30 минут)
  - Asterisk SIP (5 попыток, бан на 24 часа)
  - FreePBX Web (10 попыток, бан на 1 час)
  - Asterisk Security (3 попытки, бан на 24 часа)
  - Recidive (повторные нарушители, бан на 7 дней)

### Команды управления безопасностью

**UFW (Firewall):**
```bash
# Проверить статус
sudo ufw status numbered

# Добавить правило
sudo ufw allow from <IP> to any port <PORT>

# Удалить правило
sudo ufw delete <RULE_NUMBER>

# Заблокировать IP
sudo ufw insert 1 deny from <IP>
```

**Fail2ban:**
```bash
# Проверить статус
sudo fail2ban-client status

# Проверить конкретный jail
sudo fail2ban-client status <JAIL_NAME>

# Разблокировать IP
sudo fail2ban-client set <JAIL_NAME> unbanip <IP>

# Заблокировать IP вручную
sudo fail2ban-client set <JAIL_NAME> banip <IP>
```

### Логи безопасности

**Основные файлы логов:**
- `/var/log/fail2ban.log` - Логи Fail2ban
- `/var/log/ufw.log` - Логи UFW
- `/var/log/voip-security.log` - Логи мониторинга безопасности
- `/var/log/asterisk/security` - Логи безопасности Asterisk
- `/var/log/asterisk/messages` - Основные логи Asterisk
- `/var/log/auth.log` - Логи аутентификации системы

**Мониторинг в реальном времени:**
```bash
# Логи Fail2ban
sudo tail -f /var/log/fail2ban.log

# Логи UFW
sudo tail -f /var/log/ufw.log

# Логи Asterisk
sudo tail -f /var/log/asterisk/messages

# Логи безопасности
sudo tail -f /var/log/voip-security.log
```

### Команды экстренного реагирования

```bash
# Заблокировать IP немедленно
sudo ufw insert 1 deny from <MALICIOUS_IP>

# Заблокировать диапазон IP
sudo ufw insert 1 deny from <NETWORK/MASK>

# Временно отключить SIP порт
sudo ufw delete allow 5060/udp

# Перезапустить Fail2ban
sudo systemctl restart fail2ban
```

## 📚 Дополнительная информация

### Версии компонентов
- **Traefik**: v3.4
- **FreePBX**: Latest (на базе Asterisk 22)
- **MariaDB**: 10.6
- **Redis**: 7-alpine

### Полезные команды Asterisk
```bash
# Версия Asterisk
docker exec freepbx-server asterisk -rx "core show version"

# Статус модулей
docker exec freepbx-server asterisk -rx "module show"

# SIP статистика
docker exec freepbx-server asterisk -rx "pjsip show endpoints"
docker exec freepbx-server asterisk -rx "pjsip show registrations"

# Активные каналы
docker exec freepbx-server asterisk -rx "core show channels"

# Статус HTTP сервера
docker exec freepbx-server asterisk -rx "http show status"
```

### Мониторинг производительности
```bash
# Использование ресурсов контейнерами
docker stats

# Статус задач Asterisk
docker exec freepbx-server asterisk -rx "core show taskprocessors"

# Статистика Stasis (для ARI)
docker exec freepbx-server asterisk -rx "stasis statistics show topics"
```

## 🤝 Поддержка

Для вопросов и поддержки:
1. Проверьте логи всех сервисов
2. Убедитесь, что все API ключи корректны
3. Проверьте сетевые настройки и firewall
4. Создавайте Issues в GitHub репозитории

## 📄 Лицензия

MIT License - см. файл LICENSE для деталей.

---

**Важно**: После первого запуска дождитесь полной инициализации FreePBX (до 30 минут) перед настройкой SIP транков и других компонентов.