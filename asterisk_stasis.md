# Руководство по оптимальной настройке Asterisk 22 с акцентом на модуль StasisВажные выводы:  
-  Правильная работа Stasis/ARI опирается на три слоя — HTTP/WebSocket-службу, ядро шины Stasis и диалплан‐вызов `Stasis()`. Чтобы избежать перегрузок, задайте реалистичный пул потоков (`stasis.conf`), откажитесь от лишних типов сообщений и отслеживайте очереди `taskprocessor`.  
-  Для производительных приложений ARI используйте «автоматические» контексты, persistent WebSocket-подключения и короткий диалплан.  
-  Любая «лавина» предупреждений `stasis/pool-control reached 500 tasks` означает, что внешнее приложение или CDR/CEL генерирует больше событий, чем ядро успевает отработать; лечение — тюнинг пула, фильтрация событий, пересмотр логики ARI.

## 1. Обзор Stasis и его ролиStasis — внутренняя message-bus шина Asterisk, через которую модули (PJSIP, CDR, CEL, AMI и т. д.) публикуют события. Приложение ARI подключается к этой шине по WebSocket и получает события, когда канал входит в dialplan-команду `Stasis(app[,args])`[1][2].### 1.1 Минимальный стек для ARI
1. `http.conf` — включает HTTP-сервер (`enabled=yes`, `bindaddr=0.0.0.0`).  
2. `ari.conf` — создаёт пользователей REST / WebSocket (`[myuser] type=user password=…`).  
3. `extensions.conf` — строка `Stasis(myapp)` или авто-контекст `stasis-myapp` (с Asterisk ≥ 16)[3].  
4. Внешний сервис держит постоянный WebSocket и обрабатывает события `StasisStart/End`.

## 2. Конфигурация `stasis.conf`### 2.1 Потоковый пул| Параметр | Назначение | Рекомендация |
|----------|------------|--------------|
| `initial_size` | стартовое число потоков | = числу ядер CPU, но не менее 5[4] |
| `max_size` | потолок потоков | 4–6× ядер при ARI/AMI нагрузке[5] |
| `idle_timeout_sec` | время простоя до убийства | 20–60 с |

Пример:
```ini```hreadpool]
initial_size```8
max_size    ```48
idle_timeout_sec =```
```

### 2.2 Отключение «шумных» сообщений  
Секция `[declined_message_types]` позволяет блокировать ненужные типы, например события CDR при внешнем биллинге:

```ini
[declined_message_types]
decline =```r_write_message_type
decl``` = cdr_read_message_type```cline = st```s_app_recording_snapshot```pe
```
Это снижает нагрузки на `stasis/pool-control`[6][7].

## 3. Диалплан и регистрация приложения### 3.1 Автоконтексты  
С Asterisk 22 не требуется явная строка `Stasis()` — достаточно задать SIP-конечному устройству контекст `stasis-myapp`, шина сама создаст правило `_. → Stasis(myapp)`[3].

### 3.2 Передача аргументов  
```
exten =>```XX,1,Stasis(order-app,```ALLERID(num)},${EXTEN})
```
Доступ в ARI через `event.args[]`[8].

## 4. Тюнинг под нагрузку### 4.1 Мониторинг очередей
```
core show```skprocessors like```asis
stasis statistics```ow topics
```
Если `stasis/pool-control` или `stasis/m:channel:all` регулярно превышают «High water 500», это сигнал перегрузки[9][10].

### 4.2 Приёмы разгрузки
1. **Увеличить пул** (`max_size`, перезапуск Asterisk).  
2. **Снизить объём событий** — отключить CEL/CDR или ненужные `device_state` события.  
3. **Перевести ARI-приложение на batch-обработку**: агрегируйте события и уменьшайте REST-вызовы.  
4. **Разнести функции**: вынесите записи (`mixmonitor`) в отдельный сервер.  
5. **Профилировать** — включить `core set debug 1 stasis` и искать «тяжёлые» топики[5].

## 5. Практический чек-лист внедрения1. **Установите Asterisk 22-LTS** с параметром `--with-pjproject-bundled`.  
2. Создайте `ari.conf`:
   ```ini
  ```eneral]
  ```abled = yes``` pretty  =```s
   allowed```igins = *
  ```ashboard]
  ```pe = user
  ```ad_only = no``` password =```RONGPASS
  ````
3. Пропишите в `pjsip.conf`:
   ```
   context```asis-dashboard
  ```low_transports=ws,wss
  ````
4. Установите пул в `stasis.conf` как выше.  
5. Перезапустите Asterisk (`systemctl restart asterisk`).  
6. Поднимите WebSocket-клиент (`wscat -c ws://pbx/ari/events?api_key=dashboard:STRONGPASS&app=myapp`).  
7. Проверьте, что входящий звонок вызывает событие `StasisStart`.  
8. Наблюдайте `core show taskprocessors`  - глубина очередей ≤ 100 в пике.

## 6. Частые ошибки и их лечение| Симптом | Причина | Решение |
|---------|---------|---------|
| `Channel not in Stasis application` | WebSocket ещё не подключён | Инициировать WS до вызова, или включить persistent-outbound WS[11] |
| Очередь `stasis/m:devicestate` растёт | Много BLF/Presence | сократить BLF, отключить ненужные events |
| Продолжительные `stasis/pool-control` 500 | CDR/CEL пишут в медленный SQL | вынести БД на SSD, включить `skipcdr=yes` где возможно |
| segfault в `libasteriskpj.so` при пике | Чрезмерные одновременные originate | добавьте задержку, ограничьте `originate` потоком |