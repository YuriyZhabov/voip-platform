# Диалплан для VoIP системы

Этот каталог содержит файлы диалплана для Asterisk, которые автоматически восстанавливаются после пересборки системы.

## 🔄 Автоматическое восстановление

**Проблема**: При пересборке FreePBX теряет пользовательские конфигурации диалплана.

**Решение**: Скрипт `start-system.sh` автоматически восстанавливает диалплан из файла `extensions_dialplan.conf`.

## 📁 Файлы

### extensions_dialplan.conf
Основной файл диалплана, который автоматически загружается скриптом `start-system.sh` при каждом запуске системы.

**Преимущества вынесения в отдельный файл:**
- ✅ Легко редактировать без изменения скрипта
- ✅ Версионирование изменений в Git
- ✅ Автоматическое восстановление после пересборки
- ✅ Возможность создания разных версий диалплана

## 📋 Структура диалплана

### [from-novofon]
Контекст для обработки входящих звонков от провайдера Novofon:
- `79952227978` - основной номер для входящих звонков
- Звонки перенаправляются в LiveKit агент через ARI Stasis
- Установка hangup handler для корректного завершения

### [hangup-handler]
Обработчик завершения звонков для логирования и очистки ресурсов.

### [from-internal-custom]
Контекст для внутренних и тестовых звонков:
- `9999` - тестовый номер с воспроизведением приветствия
- `8888` - тестовый номер с эхо-тестом (новый)

## ✏️ Редактирование диалплана

### Способ 1: Через файл (рекомендуется)
```bash
# Отредактируйте файл диалплана
nano configs/dialplan/extensions_dialplan.conf

# Перезапустите систему для применения изменений
./scripts/start-system.sh
```

### Способ 2: Применение без перезапуска
```bash
# Скопируйте файл в контейнер
docker cp configs/dialplan/extensions_dialplan.conf freepbx-server:/tmp/

# Добавьте к существующему диалплану
docker exec freepbx-server bash -c 'cat /tmp/extensions_dialplan.conf >> /etc/asterisk/extensions_custom.conf'

# Перезагрузите диалплан
docker exec freepbx-server asterisk -rx "dialplan reload"
```

## 🔍 Проверка диалплана

### Проверка загруженного диалплана
```bash
# Проверить контекст from-novofon
docker exec freepbx-server asterisk -rx "dialplan show from-novofon"

# Проверить тестовые номера
docker exec freepbx-server asterisk -rx "dialplan show from-internal-custom"

# Показать весь диалплан
docker exec freepbx-server asterisk -rx "dialplan show"
```

### Тестирование диалплана
```bash
# Тест через скрипт (рекомендуется)
./scripts/test_system.sh

# Ручной тест внутреннего номера
docker exec freepbx-server asterisk -rx "channel originate Local/9999@from-internal-custom application Wait 5"

# Тест эхо номера
docker exec freepbx-server asterisk -rx "channel originate Local/8888@from-internal-custom application Wait 10"
```

## ➕ Добавление новых номеров

### Шаблон для входящих звонков (LiveKit)
```ini
exten => НОВЫЙ_НОМЕР,1,NoOp(Incoming call to ${EXTEN})
 same => n,Set(CHANNEL(hangup_handler_push)=hangup-handler,s,1)
 same => n,Answer()
 same => n,Wait(1)
 same => n,Stasis(livekit-agent,incoming,${CALLERID(num)})
 same => n,Hangup()
```

### Шаблон для тестовых номеров
```ini
exten => ТЕСТ_НОМЕР,1,NoOp(Test call to ${EXTEN})
 same => n,Answer()
 same => n,Playback(demo-congrats)
 same => n,Hangup()
```

### Шаблон для эхо-теста
```ini
exten => ЭХО_НОМЕР,1,NoOp(Echo test call)
 same => n,Answer()
 same => n,Echo()
 same => n,Hangup()
```

## 🔧 Расширенные возможности

### Условная маршрутизация по времени
```ini
exten => 79952227978,1,NoOp(Time-based routing)
 same => n,GotoIfTime(09:00-18:00,mon-fri,*,*?working_hours,s,1)
 same => n,Goto(after_hours,s,1)

[working_hours]
exten => s,1,Stasis(livekit-agent,business,${CALLERID(num)})

[after_hours]
exten => s,1,Stasis(livekit-agent,after_hours,${CALLERID(num)})
```

### Маршрутизация по номеру звонящего
```ini
exten => 79952227978,1,NoOp(Caller-based routing)
 same => n,GotoIf($["${CALLERID(num):0:2}" = "+7"]?russian_caller,s,1)
 same => n,Stasis(livekit-agent,international,${CALLERID(num)})

[russian_caller]
exten => s,1,Stasis(livekit-agent,russian,${CALLERID(num)})
```

## 📊 Мониторинг и логирование

### Включение детального логирования
```bash
# Включить логирование диалплана
docker exec freepbx-server asterisk -rx "core set verbose 5"
docker exec freepbx-server asterisk -rx "core set debug 3"

# Просмотр логов в реальном времени
docker exec freepbx-server asterisk -rx "core show channels verbose"
```

### Просмотр статистики
```bash
# Статистика по контекстам
docker exec freepbx-server asterisk -rx "dialplan show counters"

# Активные каналы
docker exec freepbx-server asterisk -rx "core show channels concise"
```

## 🚨 Устранение неполадок

### Диалплан не загружается
1. Проверьте синтаксис файла
2. Убедитесь, что файл скопирован в контейнер
3. Проверьте логи Asterisk

### Звонки не проходят через диалплан
1. Проверьте контекст в настройках SIP транка
2. Убедитесь, что номер точно совпадает
3. Проверьте приоритеты (priority) в диалплане

### ARI приложение не получает звонки
1. Убедитесь, что ARI клиент запущен
2. Проверьте регистрацию приложения: `asterisk -rx "ari show apps"`
3. Проверьте логи LiveKit агента

## 📝 Примеры использования

### Простой IVR
```ini
[ivr-main]
exten => s,1,Answer()
 same => n,Background(welcome)
 same => n,WaitExten(10)

exten => 1,1,Stasis(livekit-agent,sales,${CALLERID(num)})
exten => 2,1,Stasis(livekit-agent,support,${CALLERID(num)})
exten => t,1,Goto(s,1)
exten => i,1,Playback(invalid)
 same => n,Goto(s,1)
```

### Запись разговоров
```ini
exten => 79952227978,1,NoOp(Recording call)
 same => n,Set(FILENAME=call-${STRFTIME(${EPOCH},,%Y%m%d-%H%M%S)}-${CALLERID(num)})
 same => n,MixMonitor(/var/spool/asterisk/monitor/${FILENAME}.wav)
 same => n,Stasis(livekit-agent,recorded,${CALLERID(num)})
```