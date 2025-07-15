# Быстрый старт VoIP платформы с ИИ-агентом

## Предварительные требования

- Docker и Docker Compose
- Минимум 4GB RAM
- Открытые порты: 5060/udp, 10000-20000/udp, 6379, 8081

## Быстрый запуск

1. **Клонируйте проект и перейдите в директорию:**
   ```bash
   cd voip-platform
   ```

2. **Проверьте переменные окружения в .env файле:**
   ```bash
   cat .env
   ```

3. **Инициализируйте компоненты:**
   ```bash
   ./scripts/init-asterisk.sh
   ./scripts/init-agent.sh
   ```

4. **Запустите систему:**
   ```bash
   docker-compose up -d
   ```

5. **Проверьте статус сервисов:**
   ```bash
   docker-compose ps
   ```

## Проверка работоспособности

### Проверка Asterisk
```bash
# Проверка регистрации в Novofon
docker exec -it asterisk-pbx asterisk -rx "pjsip show registrations"

# Проверка endpoints
docker exec -it asterisk-pbx asterisk -rx "pjsip show endpoints"
```

### Проверка LiveKit Agent
```bash
# Health check
curl http://localhost:8081/health

# Детальный статус
curl http://localhost:8081/status

# Логи агента
docker logs -f livekit-agent
```

### Проверка Redis
```bash
docker exec -it redis-cache redis-cli ping
```

## Тестирование

### Тестовый звонок
1. Позвоните на номер +79952227978
2. Система должна ответить и передать звонок ИИ-агенту
3. Агент поприветствует вас на русском языке

### Тестирование через Agents Playground
1. Откройте https://agents-playground.livekit.io
2. Введите URL: `wss://voice-mz90cpgw.livekit.cloud`
3. Используйте API ключи из .env файла

## Устранение неполадок

### Asterisk не регистрируется в Novofon
```bash
# Проверьте логи Asterisk
docker logs asterisk-pbx

# Проверьте конфигурацию PJSIP
docker exec -it asterisk-pbx asterisk -rx "pjsip show auth 0053248_auth"
```

### Agent не подключается к LiveKit
```bash
# Проверьте переменные окружения
docker exec -it livekit-agent env | grep LIVEKIT

# Проверьте логи агента
docker logs livekit-agent
```

### Проблемы с аудио
- Убедитесь, что порты 10000-20000/udp открыты
- Проверьте NAT настройки в pjsip.conf
- Убедитесь, что external_media_address указан правильно

## Остановка системы

```bash
docker-compose down
```

## Резервное копирование

```bash
./scripts/backup.sh
```

## Логи

Все логи сохраняются в директории `data/logs/`:
- `data/logs/asterisk/` - логи Asterisk
- `data/logs/agent/` - логи LiveKit Agent

## Поддержка

При возникновении проблем:
1. Проверьте логи всех сервисов
2. Убедитесь, что все API ключи корректны
3. Проверьте сетевые настройки и firewall