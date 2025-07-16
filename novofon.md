# Интеграция Novofon SIP-номера с Asterisk
Передача номера Novofon на Аsterisk сводится к трём ключевым шагам:  
1) получить в личном кабинете Novofon логин, пароль и адрес `sip.novofon.ru`; 2) настроить на стороне Asterisk транспорт, учётную запись и маршруты; 3) убедиться, что маршрутизатор пропускает сигнальный порт 5060/UDP (или 5061/TLS) и диапазон RTP-портов. Ниже приводится подробное пошаговое руководство с примерами для PJSIP (рекомендуемый метод) и chan_sip, а также инструкция для FreePBX.

## 1. Предварительные условия
* Данные SIP-аккаунта берутся в личном кабинете: «Телефония → Пользователи АТС → ВАТС»[1][2].  
* Сервер оператора — `sip.novofon.ru`; по умолчанию используется порт 5060/UDP, для шифрования — 5061/TLS[2][1].  
* Asterisk ≥ 16 либо FreePBX ≥ 14; в составе должен быть загружен драйвер `res_pjsip` (chan_sip можно отключить)[3].  

## 2. Почему лучше PJSIP
PJSIP поддерживает SNI, SRTP, DNS-NAPTR/SRV и гибкое NAT-обходное поведение, тогда как chan_sip объявлен устаревшим[4][5]. На большинстве свежих дистрибутивов PJSIP включён по умолчанию; chan_sip стоит оставить лишь как fallback.

## 3. Настройка через PJSIP
### 3.1 Создаём транспорт
```ini
; /etc/asterisk/pjsip.conf
[udp-transport]
type=transport
protocol=udp
bind=0.0.0.0
local_net=192.168.0.0/24     ; ваша LAN
external_signaling_address=203.0.113.25 ; внешний IP, если NAT
```

Для TLS добавляется отдельный транспорт:  

```ini
[transport-tls]
type=transport
protocol=tls
bind=0.0.0.0:5061
cert_file=/etc/asterisk/keys/asterisk.crt
priv_key_file=/etc/asterisk/keys/asterisk.key
method=tlsv1_2           ; рекомендует Novofon[1]
```

### 3.2 Регистрация на стороне оператора
```ini
[1234567]                           ; логин = номер Novofon
type=registration
transport=udp-transport
outbound_auth=1234567_auth
server_uri=sip:sip.novofon.ru
client_uri=sip:1234567@sip.novofon.ru
contact_user=1234567
retry_interval=60
expiration=120
```


### 3.3 Auth, AOR, Endpoint, Identify
```ini
[1234567_auth]
type=auth
auth_type=userpass
username=1234567
password=SuperSecretPwd

[1234567]
type=aor
contact=sip:sip.novofon.ru

[1234567]
type=endpoint
context=novofon-in
disallow=all
allow=alaw,ulaw            ; поддерживаемые кодеки[6]
outbound_auth=1234567_auth
aors=1234567
from_user=1234567
from_domain=sip.novofon.ru
direct_media=no
rtp_symmetric=yes
force_rport=yes            ; эквивалент nat=force_rport,comedia[25]

[1234567]
type=identify
endpoint=1234567
match=sip.novofon.ru
```


### 3.4 Маршруты во `extensions.conf`
```ini
[novofon-in]
exten => 1234567,1,Dial(PJSIP/101)                ; входящие → внутр.101[6]

[novofon-out]
exten => _XXX,1,Dial(PJSIP/${EXTEN})              ; внутренние вызовы
exten => _X.,1,Dial(PJSIP/${EXTEN}@1234567)       ; внешние через Novofon
```


### 3.5 DNS SRV и NAT
Asterisk должен делать SRV-запросы к `sip.novofon.ru`; поэтому опция `srvlookup=yes` (для chan_sip) или штатная резольвер-логика PJSIP остаётся включённой[6][7].  
Для NAT установите `external_signaling_address` и `external_media_address`, а в роутере пробросьте:

* 5060/UDP (5061/TLS)  
* диапазон RTP 10000-20000/UDP[8].

## 4. Настройка TLS/SRTP
После выпуска сертификата (Let’s Encrypt или самоподписанный) активируйте транспорт TLS и измените в секции `registration` порт сервера на 5061, а в `endpoint` добавьте `media_encryption=srtp`[2][9].  
В FreePBX это делается в Settings → Asterisk SIP Settings → TLS/SRTP[2].

## 5. Настройка в FreePBX 14/15/16
1. Connectivity → Trunks → Add SIP (chan_pjsip).  
2. General: Trunk Name = Novofon, Username/Auth username = 1234567, Secret = пароль[2].  
3. PJSIP Settings → Advanced:  
   -  Contact User, From User, From Domain = данные аккаунта.  
   -  Client URI = `sip:1234567@sip.novofon.ru:5060`.  
4. Dial Patterns: в поле Match Pattern поставьте «.» для всех номеров[2].  
5. Connectivity → Inbound Routes: DID = 1234567, Destination = внутренний/IVR[10].  
6. Connectivity → Outbound Routes: Route CID = 1234567, Trunk Sequence = Novofon[2].

Для TLS установите Port 5061 и Transport TLS на вкладке Advanced того же транка[2].

## 6. Настройка chan_sip (если PJSIP недоступен)
```ini
[general]
srvlookup=yes

[1234567]
type=peer
host=sip.novofon.ru
insecure=invite,port
fromdomain=sip.novofon.ru
defaultuser=1234567
fromuser=1234567
secret=SuperSecretPwd
context=novofon-in
nat=force_rport,comedia
qualify=400
disallow=all
allow=alaw,ulaw
```
  

Далее используйте тот же диалплан, что и в п. 3.4, только команды `SIP/…` вместо `PJSIP/…`.

## 7. Топология сети и проброс портов
Ниже показана упрощённая схема размещения сервера Asterisk за NAT и обмена трафиком с Novofon.
* На роутере проброшены 5060/UDP и 10000-20000/UDP.  
* При включённом TLS дополнительно открывается 5061/TCP.  
* Все внутренние IP-телефоны регистрируются только на свой Asterisk, а не напрямую у оператора, что упрощает безопасность.

## 8. Тестирование и отладка
| Проверка | Команда | Ожидаемый результат |
|----------|---------|---------------------|
| Регистрация транка | `pjsip show registrations` | `Registration status: Registered` |
| Сигнальный статус | `pjsip show endpoint 1234567` | `Status: OK` |
| RTP-потоки | `rtp set debug on` | Пакеты идут к внешнему IP оператора |
| Ошибки регистрации | смотрите `res_pjsip_outbound_registration.c` сообщения об `Invalid client URI` — обычно лишний символ в URI[11]. |

## 9. Типичные ошибки и их решение  

* **401 Unauthorized** — неправильный пароль или `from_user`[12].  
* **Invalid URI** при PJSIP — двойной символ `@` в `client_uri`; оставьте вид `sip:логин@sip.novofon.ru`[11].  
* **Нет звука** — забыты `rtp_symmetric=yes` и `force_rport=yes` либо не проброшен диапазон RTP-портов[5].  
* **Периодические обрывы** — проверьте `qualify_frequency` (60 с) и DNS-резолвинг SRV[6][13].

## 10. Рекомендации по безопасности
1. Используйте длинные пароли и `fail2ban` для защиты от регистрации брут-форса[3].  
2. Отключите приём анонимных вызовов: `allowguest=no` для chan_sip, `anonymous_reject=yes` для PJSIP.  
3. Ограничьте доступ по ACL (`permit/deny`) или `transport=tls` и SRTP.  
4. Регулярно обновляйте Asterisk (патчи TLS/DTLS выходят часто)[9].

## Заключение
Правильно сконфигурированный PJSIP-транк обеспечивает стабильную и защищённую связь между офисной АТС и облачной платформой Novofon. Придерживайтесь официальных шаблонов конфигураций, контролируйте NAT-проброс и не забудьте включить SRV-резолвинг — это гарантирует, что ваш Asterisk всегда найдёт ближайший узел Novofon и восстановит регистрацию при смене IP-адресов провайдера. Благодаря встроенным средствам диагностики (`pjsip show …`, `rtp set debug`) вы сможете быстро локализовать любые проблемы и обеспечить бесперебойную телефонию в компании.