# Устранение сбоя модуля Features в Asterisk 22 Docker

При старте Asterisk вы видите:

```
Unable to initialize configuration info for features  
… Couldn't find function FEATURE in XML documentation …  
*** Failed to load module features  
ASTERISK EXITING!
```

Это означает, что отсутствует или недоступен XML-файл `features.conf.xml`, необходимый для загрузчика xmldoc. Без него модуль **features** не инициализируется, что влечёт за собой каскад отказа всех зависимых модулей (`res_stasis`, `res_ari_*`, `chan_pjsip` и т. д.).

## 1. Проверка наличия XML-документации

Войдите в контейнер и убедитесь, что файл `features.conf.xml` присутствует:

```bash
docker-compose exec asterisk bash
ls -l /usr/share/asterisk/documentation/en_US/features.conf.xml
```

Если файл не найден, продолжайте к разделу восстановления.

## 2. Восстановление XML-файлов

### Вариант A: Установка пакетной документации

Если вы используете Alpine или Debian-образ, просто установите пакет документации:

```bash
# Alpine
apk add --no-cache asterisk-doc

# Debian/Ubuntu
apt-get update && apt-get install -y asterisk-doc
```

Пакет развернёт полный набор XML (включая `features.conf.xml`) и выставит правильные права.

### Вариант B: Копирование из исходников

Если образ собирается из исходников, выполните:

```bash
# В том же исходном дереве Asterisk
make install-core-docs
```

Это скопирует все `doc/*.xml` в `/usr/share/asterisk/documentation/en_US/`.

### Вариант C: Отключить проверку XML

Если документация не нужна, пересоберите Asterisk без xmldoc:

```bash
./configure --disable-xmldoc …
make && make install
```

В этом случае загрузчик не будет проверять XML, но вы потеряете встроенную справку CLI.

## 3. Создание минимального `features.conf`

Даже при наличии XML без корректного конфига модуль не запустится. Добавьте простой `/etc/asterisk/features.conf`:

```ini
[general]
transferdigittimeout = 3
atxfernoanswertimeout = 15
atxferdropcall = no
pickupexten = *8

[featuremap]
blindxfer = *2
atxfer     = *3
```

Это позволит модулю загрузить секции и опции без ошибок.

## 4. Перезапуск и проверка

```bash
docker-compose restart asterisk

# Убедитесь, что модуль features загружен
docker-compose exec asterisk asterisk -rx "module show like features"
# Проверить отсутствие ошибок в логе
docker-compose logs --tail=50 asterisk | grep -i "ERROR\|Failed"
```

Если `res_stasis`, `res_ari_*` и `chan_pjsip.so` загрузились, проблема решена.

**Вывод:** фатальная ошибка «Unable to initialize configuration info for features» происходит из-за отсутствия XML-документации (`features.conf.xml`) или некорректного `features.conf`. Восстановите XML с помощью пакетного `asterisk-doc` или `make install-core-docs` и создайте минимальный конфиг, затем перезапустите контейнер.