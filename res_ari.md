# Комплексное руководство: устранение повторных сбоев Asterisk 22 в Docker из-за недостающих XML-документов CDR/CEL  

Asterisk вновь выходит сразу после старта, теперь жалуясь на опции `scheduleronly`, `safeshutdown`, `size`, `time`, `channeldefaultenabled`, `ignorestatechanges`, `ignoredialchanges` модуля `cdr` и на отсутствие типа `general` в модуле `cel`. Ошибка ведёт к каскадному отклонению `res_ari_*`, `res_stasis_*`, `chan_pjsip`, после чего ядро завершается. Ниже — подробное, многоуровневое руководство: от диагностики до долговременного решения.

## Обзор проблемы  

Asterisk запускается с x​m​l​d​o​c-проверкой. При загрузке каждого модуля движок «подключает» соответствующий XML-файл, чтобы:

- сформировать встроенную справку CLI;  
- построить таблицы CLI-autocomplete;  
- инициализировать метаданные конфигурационных структур.  

Если XML отсутствует, функция `xmldoc_update_config_option()` возвращает ошибку, модуль помечается `DECLINED`, а его зависимости снимаются с очереди[1][2]. Ранее вы починили `stasis` и `res_statsd`, но **файлы `cdr.conf.xml` и `cel.conf.xml` не попали в контейнер** — именно на них указывает нынешний лог[3][4].

## Каталоги документации: где их ищет Asterisk  

| Дистрибутивный путь | Признак «core»/«thirdparty» | Кто создает | Чтение от UID |
|---------------------|-----------------------------|-------------|---------------|
| `/usr/share/asterisk/documentation/en_US/` | core-en_US.xml, cdr.conf.xml, cel.conf.xml | `make install` или пакет `asterisk-doc` | `asterisk` (uid 2600) |
| `/var/lib/asterisk/documentation/en_US/` | Симлинк на `/usr/share/...` в пакетных сборках Debian/NixOS[5][6] | Скрипт post-install | `asterisk` |
| `/usr/share/asterisk/documentation/thirdparty/` | сторонние модули, например `codec_opus`[1] | Ручная копия | `asterisk` |

Важно: если bind-mount перекрывает любой из этих путей, Asterisk не увидит XML даже при наличии файлов[7].

## Шаг 1. Проверяем, есть ли CDR/CEL доки  

```bash
docker compose exec asterisk bash
ls -l /usr/share/asterisk/documentation/en_US | egrep 'cdr|cel'
# ↳ Пустой вывод = нет файлов
```

Также удостоверьтесь, что симлинк `/var/lib/asterisk/documentation → /usr/share/...` существует:

```bash
namei -l /var/lib/asterisk/documentation
```

## Шаг 2. Три варианта восстановления XML  

| Сценарий | Команда | Примечание |
|----------|---------|------------|
| **Официальный пакет Alpine/Debian** | `apk add asterisk-doc` или `apt-get update && apt-get install -y asterisk -doc` | Пакет разворачивает *все*XML-файлы, ставит симлинк. |
| **Сборка из исходников** | `make install-core-docs` (Asterisk ≥ 20) или повторный `make install` | Цель `install-core-docs` копирует только XML, без пересборки бинарей. |
| **Отключаем проверку навсегда** | Пересобрать с `./configure --disable-xmldoc` + `make && make install` | Уменьшает размер образа, но лишает `help`/`autocomplete`, требуется постоянный rebuild при обновлениях. |

## Шаг 3. Минимальный cdr.conf / cel.conf, чтобы убрать ворнинги  

Даже после восстановления XML Asterisk будет ругаться на отсутствие конфигов. Добавьте заглушки:

```ini
; /etc/asterisk/cdr.conf
[general]
enabled = yes
unanswered = no
batch = no

; /etc/asterisk/cel.conf
[general]
enable = no
```

Это снимет ERROR-уровень и переведёт сообщения в NOTICE[3][4].

## Шаг 4. Перезапуск и контроль загрузки  

```bash
docker compose restart asterisk

# Убедимся, что критических ошибок нет
docker compose logs --tail=100 asterisk | egrep -i 'ERROR|DECLINED'

# Проверим ключевые модули
docker compose exec asterisk asterisk -rx 'module show like cel'
# cel.so                Channel Event Logging        1
docker compose exec asterisk asterisk -rx 'pjsip show version'
# PJPROJECT version ... (значит PJSIP загружен)
```

## Шаг 5. Постоянная защита от повторения  

1. **Не монтируйте volume поверх `/usr/share/asterisk` и `/var/lib/asterisk`**, если не копируете туда полный набор поддиректорий, включая `documentation/`.  
2. В Dockerfile добавьте явный слой с документацией:  

   ```dockerfile
   RUN make install && make install-core-docs
   # или
   RUN apk add --no-cache asterisk asterisk-doc
   ```

3. В CI после `docker build` выполняйте тест:  

   ```bash
   docker run --rm mypbx asterisk -rx 'core show file core-en_US.xml'
   ```

4. При переходе на новую минорную версию (22.5 → 22.6) **пересобирайте образ** — XML-схемы обновляются вместе с кодом[8].

## Теория: почему CDR/CEL критичны для ARI/Stasis  

- `cdr` и `cel` входят в compiled-time список модулей, которые **обязательны** для `res_stasis.so` (шина событий).  
- Если один из них DECLINED, `loader.c` помечает зависимости `res_ari_*`, `chan_pjsip` как «pending» и отклоняет их для предотвращения несогласованных структур в RAM[2].  
- Следовательно, любой XML-дефицит в базовых модулях роняет всю верхнюю часть стека SIP/ARI.

## Продвинутый тюнинг: сборка без XML в production  

Если требуется минимальный образ:  

```bash
./configure --without-pjproject-bundled --disable-xmldoc \
            --with-jansson-bundled
make -j$(nproc) && make install
```

Плюсы: минус 16–20 MB; быстрее старт.  
Минусы:  

- `core show application ` покажет лишь «No help text available».  
- DPMA, Sangoma D-Series и часть «wizard»-плагинов отказываются загружаться без XML[9].  
- При апгрейде надо **не забыть** повторять флаг `--disable-xmldoc`.

## Часто задаваемые вопросы  

| Вопрос | Ответ |
|--------|-------|
| **Можно ли хранить XML вне контейнера?** | Да. Смонтируйте `documentation/` из внешнего `ConfigMap`/volume, но **сохраняйте ту же иерархию**. |
| **Почему раньше Asterisk работал без XML?** | В версии ≤ 18 проверка была предупреждением. Начиная с 20 она стала фатальной для модулей, если в их коде есть `ACO_OPTION` или `sorcery_object_type`[7][4]. |
| **Я использую NixOS, после обновления всё сломалось** | Пакет `asterisk` в 22.11 перестал копировать `/usr/share/.../documentation` в `/var/lib/...`; баг-репорт #208165 описывает точный патч[6]. Симлинк решает проблему. |
| **Зачем тогда вообще нужна проверка?** | Чтобы не возникала рассинхронизация между CLI-справкой и фактическим набором опций. Также генератор docs питает docs.asterisk.org API Reference[3][4]. |

## Заключение  

Сбой «`xmldoc_update_config_option: ... modules 'cdr' not found`» — очередная «костяшка домино» в цепочке зависимостей. Корневое лекарство остаётся тем же: **полный комплект XML-файлов** либо явное отключение `xmldoc` на этапе сборки. Верните `cdr.conf.xml` и `cel.conf.xml` (или пересоберите Asterisk с `--disable-xmldoc`) — и контейнер вновь запустит Stasis, ARI, PJSIP и остальные модули без красных строк в логе.  

Следите, чтобы при любом bind-mount или CI-оптимизации не пропадали каталоги `documentation/en_US/`, и Asterisk 22 будет стабильно работать, не превращая обновление в рутинный пожар.