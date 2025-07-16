# VoIP Platform Security Guide

## Обзор безопасности

Данная VoIP платформа защищена несколькими уровнями безопасности:

### 1. Firewall (UFW)
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

### 2. Fail2ban
- **Статус**: Активен
- **Защищенные сервисы**:
  - SSH (3 попытки, бан на 30 минут)
  - Asterisk SIP (5 попыток, бан на 24 часа)
  - FreePBX Web (10 попыток, бан на 1 час)
  - Asterisk Security (3 попытки, бан на 24 часа)
  - Recidive (повторные нарушители, бан на 7 дней)

## Команды управления

### UFW (Firewall)
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

### Fail2ban
```bash
# Проверить статус
sudo fail2ban-client status

# Проверить конкретный jail
sudo fail2ban-client status <JAIL_NAME>

# Разблокировать IP
sudo fail2ban-client set <JAIL_NAME> unbanip <IP>

# Заблокировать IP вручную
sudo fail2ban-client set <JAIL_NAME> banip <IP>

# Перезагрузить конфигурацию
sudo fail2ban-client reload
```

### Мониторинг безопасности
```bash
# Запустить проверку безопасности
./scripts/security-monitor.sh status

# Заблокировать IP вручную
./scripts/security-monitor.sh ban <IP>

# Разблокировать IP
./scripts/security-monitor.sh unban <IP>

# Просмотр логов безопасности
./scripts/security-monitor.sh logs
```

## Логи безопасности

### Основные файлы логов:
- `/var/log/fail2ban.log` - Логи Fail2ban
- `/var/log/ufw.log` - Логи UFW
- `/var/log/voip-security.log` - Логи мониторинга безопасности
- `/var/log/asterisk/security` - Логи безопасности Asterisk
- `/var/log/asterisk/messages` - Основные логи Asterisk
- `/var/log/auth.log` - Логи аутентификации системы

### Мониторинг в реальном времени:
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

## Автоматизация

### Cron задачи:
- **Каждые 15 минут**: Проверка статуса безопасности
- **Каждые 6 часов**: Перезагрузка Fail2ban

### Настройка cron:
```bash
# Редактировать crontab
sudo crontab -e

# Просмотр текущих задач
sudo crontab -l
```

## Рекомендации по безопасности

### 1. Регулярное обновление
```bash
# Обновление системы
sudo apt update && sudo apt upgrade -y

# Обновление Docker образов
docker-compose pull && docker-compose up -d
```

### 2. Мониторинг
- Регулярно проверяйте логи на подозрительную активность
- Настройте уведомления о критических событиях
- Используйте внешние системы мониторинга

### 3. Пароли и ключи
- Используйте сложные пароли для всех сервисов
- Регулярно меняйте пароли
- Используйте SSH ключи вместо паролей для SSH доступа

### 4. Сетевая безопасность
- Ограничьте доступ к административным интерфейсам по IP
- Используйте VPN для удаленного доступа
- Настройте TLS/SRTP для SIP трафика

### 5. Резервное копирование
- Регулярно создавайте резервные копии конфигураций
- Тестируйте процедуры восстановления
- Храните копии в безопасном месте

## Реагирование на инциденты

### При обнаружении атаки:
1. **Немедленно заблокировать** подозрительные IP адреса
2. **Проанализировать логи** для понимания масштаба атаки
3. **Уведомить** администраторов системы
4. **Документировать** инцидент для анализа

### Команды экстренного реагирования:
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

## Контакты поддержки

При возникновении проблем с безопасностью:
1. Проверьте логи системы
2. Запустите диагностику безопасности
3. Обратитесь к администратору системы

---

**Важно**: Регулярно обновляйте эту документацию при изменении конфигурации безопасности.