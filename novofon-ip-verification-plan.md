# План подтверждения IP адреса для Novofon SIP

## Анализ текущей конфигурации

Изучив конфигурацию, я вижу, что:

1. У вас уже настроен SIP-транк с Novofon в `pjsip.conf`
2. Внешний IP адрес сервера: `94.131.122.253` (указан в .env и pjsip.conf)
3. Учетные данные Novofon: логин `0053248`, пароль `P5Nt8yKbey`
4. В `extensions.conf` уже есть тестовый диалплан для номера 8888:
   ```ini
   exten => 8888,1,NoOp(Test call to Novofon verification)
   same => n,Dial(PJSIP/8888@0053248,30)
   same => n,Hangup()
   ```

## План действий для подтверждения IP

### 1. Проверка текущей регистрации на Novofon

```bash
docker exec freepbx-server asterisk -rx "pjsip show registrations"
```

Убедитесь, что статус регистрации: `Registered`

### 2. Проверка настроек транспорта и внешнего IP

```bash
docker exec freepbx-server asterisk -rx "pjsip show transports"
```

Убедитесь, что `external_signaling_address` и `external_media_address` установлены в `94.131.122.253`

### 3. Проверка настроек endpoint для Novofon

```bash
docker exec freepbx-server asterisk -rx "pjsip show endpoint 0053248"
```

Убедитесь, что endpoint правильно настроен и активен

### 4. Выполнение тестового звонка на номер 8888

Есть два способа выполнить тестовый звонок:

#### Способ 1: Через Asterisk CLI (рекомендуется)

```bash
docker exec freepbx-server asterisk -rx "channel originate PJSIP/8888@0053248 application Wait 10"
```

#### Способ 2: Через диалплан (если у вас есть внутренний номер)

```bash
docker exec freepbx-server asterisk -rx "channel originate Local/8888@from-internal application Wait 10"
```

### 5. Проверка логов для подтверждения успешного вызова

```bash
docker exec freepbx-server asterisk -rx "core show channels"
```

Сразу после инициации вызова проверьте активные каналы

```bash
docker exec freepbx-server tail -f /var/log/asterisk/full
```

Проверьте логи на наличие ошибок или успешного соединения

### 6. Проверка статуса подтверждения

После выполнения тестового звонка подождите несколько минут (обычно 5-10 минут), чтобы Novofon обработал подтверждение IP.

### 7. Тестирование исходящего звонка на реальный номер

После подтверждения IP попробуйте сделать тестовый звонок на реальный номер:

```bash
docker exec freepbx-server asterisk -rx "channel originate PJSIP/79XXXXXXXXX@0053248 application Wait 10"
```

Замените `79XXXXXXXXX` на реальный номер для тестирования.

## Возможные проблемы и их решения

### 1. Ошибка регистрации

**Проблема**: Статус регистрации показывает `Request Sent` или `Auth Rejected`

**Решение**:
- Проверьте правильность логина и пароля в `pjsip.conf`
- Убедитесь, что `server_uri` и `client_uri` настроены правильно
- Проверьте логи на наличие ошибок аутентификации

### 2. Проблемы с NAT

**Проблема**: Звонок инициируется, но нет аудио или соединение обрывается

**Решение**:
- Убедитесь, что порты 5060/UDP и 18000-18100/UDP открыты на файрволе
- Проверьте настройки `external_media_address` и `external_signaling_address`
- Убедитесь, что параметры `rtp_symmetric=yes` и `force_rport=yes` включены

### 3. Ошибка при звонке на 8888

**Проблема**: Звонок на 8888 не проходит или завершается с ошибкой

**Решение**:
- Проверьте логи Asterisk для выявления причины ошибки
- Убедитесь, что контекст `from-internal` доступен и правильно настроен
- Проверьте, что endpoint `0053248` активен и правильно настроен

## Команды для выполнения плана

Вот последовательность команд, которые нужно выполнить для подтверждения IP:

```bash
# 1. Проверка регистрации
docker exec freepbx-server asterisk -rx "pjsip show registrations"

# 2. Проверка транспорта
docker exec freepbx-server asterisk -rx "pjsip show transports"

# 3. Проверка endpoint
docker exec freepbx-server asterisk -rx "pjsip show endpoint 0053248"

# 4. Выполнение тестового звонка
docker exec freepbx-server asterisk -rx "channel originate PJSIP/8888@0053248 application Wait 10"

# 5. Проверка активных каналов
docker exec freepbx-server asterisk -rx "core show channels"

# 6. Проверка логов
docker exec freepbx-server tail -f /var/log/asterisk/full

# 7. Тестирование после подтверждения (через 5-10 минут)
docker exec freepbx-server asterisk -rx "channel originate PJSIP/79XXXXXXXXX@0053248 application Wait 10"
```

## Заключение

После успешного выполнения этого плана ваш IP адрес `94.131.122.253` будет подтвержден в системе Novofon, и вы сможете совершать исходящие звонки на любые номера. Если возникнут проблемы на любом этапе, используйте предложенные решения для их устранения.

Важно отметить, что подтверждение IP обычно требуется только один раз, если ваш IP адрес не меняется. Если в будущем IP адрес сервера изменится, процедуру подтверждения придется повторить.