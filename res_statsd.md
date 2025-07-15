### Ключевая причина очередного «падения домино»

* Asterisk-22 загружает все **PJSIP-модули** (и ещё пару десятков вспомогательных библиотек) **только после успешной инициализации `res_statsd.so`**.  
* `res_statsd` не стартует, потому что при проверке XML-справочника не находит описание конфигурационного блока `global`:  
  ```
  Cannot update type 'global' in module 'res_statsd' because it has no existing documentation!
  res_statsd declined to load.
  ```
  Как и в предыдущей аварии со Stasis, виноваты **отсутствующие или недоступные XML-файлы** документации. Из-за отказа `res_statsd` загрузчик блокирует все его явные/неявные зависимости, в том числе `res_pjsip*`, `chan_pjsip.so`, `res_ari_*`, `cdr`, и Asterisk покидает сцену [1][2].

## Что именно нужно поправить

1. Убедиться, что в контейнере **есть каталог `…/documentation/en_US/`**  
   (по умолчанию `/usr/share/asterisk/documentation/en_US` или `/var/lib/asterisk/documentation/en_US`).

2. Проверить наличие как минимум трёх файлов документации:  

   ```
   core-en_US.xml
   res_statsd.conf.xml
   statsd.conf.xml
   ```

   ```
   ls -l /usr/share/asterisk/documentation/en_US | grep statsd
   ```

   если вывод пуст, документации действительно нет.

3. Восстановить XML-доки **любыми из трёх способов**.

   | Способ | Команда / действие | Примечание |
   |--------|-------------------|------------|
   | Установка «doc»-пакета (дистрибутивный образ) | `apk add asterisk-doc` (Alpine) или `apt-get install asterisk -doc` (Debian/Ubuntu) | Пакет сразу кладёт XML в нужный путь и выставляет права. |
   | Повторная установка ядра **из исходников** | `make install-core-docs` или просто `make install` из того же дерева | После сборки все `*.xml` копируются в `/usr/share/asterisk/documentation/en_US/`. |
   | Если монтирован volume, перекрывающий `/usr/share/asterisk` | ① Копировать `documentation/` с хоста внутрь тома;② `chown -R 2600:2600 documentation` | Именно bind-mount чаще всего «прячет» файлы от Asterisk [3][4]. |

4. Создать минимальный `statsd.conf`, чтобы убрать последующие ворнинги:  

   ```
   [global]
   enabled = no
   ```

5. Перезапустить контейнер  
   `docker-compose restart asterisk`

## Быстрая самопроверка после перезапуска

```bash
docker compose exec asterisk asterisk -rx 'module show like statsd'
# должен появиться вывод примерно:
# res_statsd.so        StatsD client support            1
docker compose exec asterisk asterisk -rx 'pjsip show version'
# PJPROJECT version … (значит PJSIP модуль загружен)
```

Команда  
`asterisk -rx 'core show taskprocessors like stasis'`  
должна вернуть таблицу, а не ошибку «command not found».

## Как не поймать проблему вновь

1. **Не монтируйте volume поверх `/usr/share/asterisk` и `/var/lib/asterisk`,** если не копируете туда всё содержимое, включая `documentation/`.

2. В CI/Dockerfile добавьте явный шаг:

```dockerfile
RUN make install && make install-core-docs  # или apk/apt пакет asterisk-doc
```

3. Если документация не нужна вообще — соберите Asterisk с флагом  
   `./configure --disable-xmldoc` : тогда модульный загрузчик перестанет проверять XML, и ошибки вида *“no existing documentation”* исчезнут [5].

### Итог

`res_statsd` – единственный «первый костяшка» в новой цепочке зависимостей Asterisk 22: без его XML-справочника валятся PJSIP, ARI, CDR и все модули, перечисленные в вашем логе. Достаточно вернуть **три-четыре XML-файла** (или отключить xmldoc), и Asterisk запустится без красных строк, а Stasis и PJSIP вновь окажутся в строю.