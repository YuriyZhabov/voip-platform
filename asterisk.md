# Руководство по установке и базовой настройке Asterisk PBXПеред вами практическое исследование, которое объединяет пошаговую процедуру установки Asterisk из исходных кодов, обзор ключевых конфигурационных файлов и рекомендации по защите системы.  

**Краткий вывод:** оптимальный способ получить предсказуемый и безопасный сервер — компиляция актуальной LTS-версии Asterisk 22/20 из исходников, выбор драйвера PJSIP, минимальная загрузка модулей через `modules.conf`, неизменяемый диапазон RTP-портов, логирование security-событий и связка Fail2Ban + iptables. Такой подход обеспечивает гибкость, контроль и совместимость как с классическими SIP-телефонами, так и с WebRTC.

## 1. Подготовка операционной системы### 1.1 Выбор дистрибутива  
* RHEL/Alma/Rocky 8-9 или Ubuntu 22/24 LTS — оба семейства предоставляют свежие toolchain-пакеты и ядро ≥ 5.15, что важно для DAHDI и SRTP[1][2].  
* Отключите SELinux (или переведите в permissive) до компиляции, иначе часть модулей не загрузится[3][4].

### 1.2 Базовые зависимости (пример для Rocky 9)  
```bash
dnf group```tall "Development Tools```y
dnf install```el-release -y
dnf install```  wget curl```t lua-devel j```son-devel \
 ```bedit-devel opens```devel \
  libs```-devel lib```d-devel sqlite```vel \
  nc```es-devel lib```2-devel spe```devel \
  pj```ject-devel ```
```
Скрипт `contrib/scripts/install_prereq install` внутри архива Asterisk автоматизирует подбор пакетов[2].

## 2. Сборка Asterisk из исходников### 2.1 Загрузка и распаковка  
```bash
cd /```/src
wget https```downloads.asterisk.org```b/telephony/asterisk/aster```-22-current.tar.gz
tar```f asterisk-22-current.tar```
cd asterisk-22.*/
```

### 2.2 Конфигурация  
```bash
./configure```with-jansson-bundled --with```project-bundled \
           ```with-crypto --enable-dev-mode
```
*Опция `--with-pjproject-bundled` упрощает переход на PJSIP и исключает борьбу с версиями библиотеки[5].*  

Добавьте `menuselect/menuselect --disable BUILD_NATIVE menuselect.makeopts`, если собираете в VM с нестандартным CPU[1].

### 2.3 Компиляция и установка  
```bash
make -j$(nproc```ake install```ke samples```  # базовые .```f
make config```   # скрипт system```dconfig
```
После `make install` обязательно прочитайте `/var/lib/asterisk/doc/security.txt` — это официальное резюме рекомендаций[1][6].

### 2.4 Проверка запуска  
```bash
system``` start asterisk
asterisk```vvr          ```CLI
```## 3. Ключевые конфигурационные файлы### 3.1 `asterisk.conf`  
Задаёт пути `astetcdir`, `astlogdir`, `astspooldir`. Совет — выносите логи на отдельный том, а звук (`sounds/`) — в NFS или S3-bucket для дальнейшего бэкапа.

### 3.2 `modules.conf`  
```ini
[modules]
autoload```
noload=chan_sip.so
; Мини```ьный набор```ad=res_pjproject.so
load```an_pjsip.so
load=res_p```p.so
load=res_rtp_aster```.so
load=res_http_websocket```
```
Такой whitelisting снижает поверхность атаки и ускоряет старт[7][8].

### 3.3 `pjsip.conf` — современный драйвер```ini
[transport-udp]
type=transport
protocol```p
bind=0.0.0.0
external```dia_address=203.0.113.```local_net=192.168.0.0/```
[provider-auth]
type=```h
username=300100
password```******

[provider-aor]
type```r
contact=sip:voip.isp```m

[provider-ep]
type=```point
transport=transport```p
outbound_auth=provider```th
aors=provider-aor
context```om-pstn
disallow=all
allow```aw,alaw

[reg-provider]
type=registration
server```i=sip:voip.isp.com
client```i=sip:300100@voip.isp.com```ntact_user=300100
outbound```th=provider-auth
retry```terval=60
```
Команда `pjsip show registrations` должна отображать `State: Registered`[9][10].

### 3.4 `extensions.conf` — минимальный dial-plan```ini
[from-internal]
exten => _1XX,1,NoOp(Local call```same  => n```al(PJSIP/${EXTEN})

[from-pstn]
exten => _```1,NoOp(Inbound)
 same```> n,Dial(PJSIP/101)

[globals]
CONSOLE=Console/1
```
Используйте директиву `same =>` и label-ы для гибкости[11][12][13].

### 3.5 `rtp.conf`  
```ini
[general]
rtpstart```000
rtpend=20000
```
Открываем диапазон UDP 10000-20000 на фаерволе. Не сокращайте порты излишне, иначе рискуете получить «No RTP ports remaining» при массовых вызовах[14][15][16].

### 3.6 `logger.conf` и Security-лог  
```ini
[general]
date```mat=%F %T.%3q
use_call```=yes

[logfiles]
messages```g => notice```rning,error
security.log``` security
full.log    ``` notice,warning,error,```bose(3),dtmf
```
Перезагрузите логгер: `logger reload`[17][18][19]. Security-журнал обязателен для Fail2Ban.

## 4. Защита: Fail2Ban + iptables1. Включите Security-framework как показано выше.  
2. Шаблон фильтра `/etc/fail2ban/filter.d/asterisk.conf` уже включает регулярные выражения событий `FailedACL`, `InvalidPassword`[20][21][22].  
3. Пример jаil:  
   ```ini
  ```sterisk-udp]
  ```abled  = true``` port     =```60,5061
  ```lter   = a```risk
   log```h  = /var/log/asterisk```curity.log
  ```ntime  = 86400
  ```xretry = 8
  ````
4. Базовые правила `iptables` (IPv4):  
   ```bash
   ip```les -A INPUT``` udp --dport ```0 -j ACCEPT``` iptables -A INPUT``` udp --dport ```00:20000 -j ACCEPT``` iptables -A INPUT``` state --state EST```ISHED,RELATED -j ACCEPT``` iptables -A INPUT``` DROP
   ```
   Аналогично для `nftables` или `firewalld`[23][24][25][26].

## 5. Практические сценарии инфраструктуры| Сценарий | Особенности | Файлы/параметры |
|----------|-------------|-----------------|
| Корпоративная АТС на 20-50 внутренних SIP-аппаратов | один SIP-провайдер, регистрация по паролю | `pjsip.conf`: одна `registration`; `extensions.conf`: внутренний контекст `from-internal` |
| Call-центр 100+ агентов | несколько провайдеров, балансировка по SRV, очередь `app_queue` | добавьте `res_statsd.so`, настроить `queues.conf`; отдельный `transport-tls` |
| WebRTC-клиенты (браузер) | TLS 5061, DTLS-SRTP, certbot | `pjsip.conf` sections `transport-wss`, `endpoint allow=opus,vp8` |
| Виртуальный номер + IVR | Inbound‐only DID, ответ + `Background()` | диалплан: `exten => s,1,Answer()` → `Goto(ivr-main,s,1)` |

## 6. Системная эксплуатация  

* **Ротация логов** — файл `/etc/logrotate.d/asterisk` с параметром `postrotate /usr/sbin/asterisk -rx 'logger reload'`[27][19].  
* **Обновления** — при выходе патч-релиза (`22.3.x`) выполните `make uninstall` + повторите сборку; конфигурация сохраняется.  
* **Мониторинг** — `ari show stats`, `pjsip list channels`, экспорт CDR в SQL через `cdr_adaptive_odbc` и Grafana.  

## 7. ЗаключениеКомпиляция из исходников, минимальная загрузка модулей и логирование security-событий — фундамент стабильной и устойчивой к атакам Asterisk-системы. Выбрав PJSIP, вы получаете поддержку современного SIP RFC, WebRTC и DTLS-SRTP.  