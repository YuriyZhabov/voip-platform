На основе текущих логов можно видеть, что проблема перешла от `res_statsd` и `cdr`/`cel` к модулю `features`. Сейчас Asterisk падает на том, что модуль `features` не может найти XML-документацию для конфигурационного типа `globals` и не может инициализироваться. Это вызывает каскадный отказ всех ARI и Stasis модулей.

# Диагностика и решение критического сбоя модуля `features` в Asterisk 22 Docker

## Причина текущего падения

Asterisk 22 теперь останавливается на этапе инициализации модуля `features` с ошибкой:

```
Cannot update type 'globals' in module 'features' because it has no existing documentation!
Unable to initialize configuration info for features
*** Failed to load module features
```

Модуль `features` является **критически важным** для функционирования Asterisk, поскольку он управляет базовыми функциями, такими как:
- Переводы звонков (transfer)
- Парковка звонков (parking)  
- Захват звонков (pickup)
- Одним словом — все DTMF-активируемые функции

Без него не загружается `res_stasis`, `res_ari_*`, `chan_pjsip` и другие модули, что делает Asterisk неработоспособным.

## Проблема: отсутствие `features.conf.xml`

Ошибка указывает на то, что отсутствует файл `features.conf.xml` в каталоге XML-документации. Кроме того, конфигурационный файл `cdr.conf` содержит некорректную опцию `enabled`, которая не поддерживается в версии 22.

## Решение по шагам

### 1. Восстановление XML-документации

Убедитесь, что в контейнере есть полный набор XML-файлов:

```bash
# Войти в контейнер
docker-compose exec asterisk bash

# Проверить наличие файлов документации
ls -la /usr/share/asterisk/documentation/en_US/ | grep -E "(features|cdr|cel)"
```

Если файлы отсутствуют, восстановите их одним из способов:

**Способ 1**: Установить пакет документации (если используется пакетный дистрибутив):
```bash
# Для Alpine
apk add asterisk-doc

# Для Debian/Ubuntu  
apt-get update && apt-get install -y asterisk-doc
```

**Способ 2**: Если сборка из исходников, пересобрать с документацией:
```bash
make install-core-docs
# или полная переустановка
make install
```

### 2. Исправление конфигурационного файла `cdr.conf`

Замените неправильную опцию `enabled` на `enable`:

```bash
# Исправить в контейнере
docker-compose exec asterisk sed -i 's/enabled=yes/enable=yes/g' /etc/asterisk/cdr.conf
```

Или создайте корректный файл:

```ini
# /etc/asterisk/cdr.conf
[general]
enable=yes
unanswered=no
batch=no
```

### 3. Создание минимального `features.conf`

Создайте базовый файл конфигурации features:

```bash
docker-compose exec asterisk sh -c 'cat > /etc/asterisk/features.conf  /etc/asterisk/cel.conf << EOF
[general]
enable=no
EOF'
```

### 5. Перезапуск контейнера

```bash
docker-compose restart asterisk
```

### 6. Проверка успешного запуска

```bash
# Проверить статус загрузки модулей
docker-compose exec asterisk asterisk -rx "module show like features"
docker-compose exec asterisk asterisk -rx "module show like stasis"
docker-compose exec asterisk asterisk -rx "pjsip show version"

# Проверить отсутствие критических ошибок
docker-compose logs asterisk | grep -i "error\|failed\|exiting"
```

## Альтернативное решение: отключение XML-документации

Если нужен минимальный образ без документации, пересоберите Asterisk с отключенной проверкой XML:

```dockerfile
# В Dockerfile
RUN ./configure --disable-xmldoc --with-pjproject-bundled
RUN make && make install
```

## Долгосрочная профилактика

1. **Не монтируйте volumes поверх системных путей** `/usr/share/asterisk` и `/var/lib/asterisk`
2. **В CI/CD добавьте проверку** наличия XML-файлов после сборки образа
3. **Используйте готовые образы** с полной документацией или явно отключайте её при сборке

## Заключение

Проблема связана с неполным набором XML-документации в контейнере, что стало критичным для модуля `features` в Asterisk 22. Восстановление файлов `features.conf.xml`, `cdr.conf.xml` и `cel.conf.xml` с исправлением синтаксиса конфигурационных файлов решит проблему инициализации. После этого Asterisk успешно загрузит все модули Stasis, ARI и PJSIP.