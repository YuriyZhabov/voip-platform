## Конфигурация Novofon с PJSIP в Asterisk

## Настройка транка с вашими данными

**Файл pjsip.conf:**

``` text
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0

[0053248_reg]
type=registration
transport=udp-transport
outbound_auth=0053248_auth
server_uri=sip:sip.novofon.ru:5060
client_uri=sip:0053248@sip.novofon.ru:5060
retry_interval=20
forbidden_retry_interval=600
expiration=120
contact_user=0053248

[0053248_auth]
type=auth
auth_type=userpass
password=P5Nt8yKbey
username=0053248

[0053248]
type=aor
contact=sip:sip.novofon.ru:5060

[0053248]
type=endpoint
transport=udp-transport
context=novofon-in
disallow=all
allow=alaw
allow=ulaw
outbound_auth=0053248_auth
aors=0053248
from_user=0053248
from_domain=sip.novofon.ru
direct_media=no

[0053248]
type=identify
endpoint=0053248
match=sip.novofon.ru
```

## Настройка внутренних номеров

**Конфигурация внутреннего номера 101:**

``` text
[101]
type=endpoint
transport=udp-transport
context=novofon-out
disallow=all
allow=alaw
allow=ulaw
auth=101
aors=101

[101]
type=auth
auth_type=userpass
password=101
username=101

[101]
type=aor
max_contacts=10
```

## Маршрутизация в extensions.conf

``` text
[novofon-in]
exten => 79952227978,1,Dial(PJSIP/101)
exten => +79952227978,1,Dial(PJSIP/101)

[novofon-out]
exten => _XXX,1,Dial(PJSIP/${EXTEN})
exten => _XXX.,1,Dial(PJSIP/${EXTEN}@0053248)
```

## Настройка в FreePBX с вашими данными

### Создание транка

1. **Connectivity → Trunks** → добавить SIP(chan_pjsip) Trunk
    
2. **PJSIP Settings → General:**
    
    - Username: `0053248`
        
    - Auth username: `0053248`
        
    - Secret: `P5Nt8yKbey`
        
3. **PJSIP Settings → Advanced:**
    
    - Contact User: `0053248`
        
    - From Domain: `sip.novofon.ru`
        
    - From User: `0053248`
        
    - Client URI: `sip:0053248@sip.novofon.ru:5060`
        
    - Server URI: `sip:sip.novofon.ru:5060`
        
    - AOR Contact: `sip:sip.novofon.ru:5060`
        

### Маршрутизация

- **Inbound Routes:** DID Number = `79952227978` или `+79952227978`
    
- **Outbound Routes:** Match pattern = `.` (точка)
## Интеграция с LiveKit

## Конфигурация транка для LiveKit

``` json
{
  "trunk": {
    "name": "Asterisk inbound trunk",
    "numbers": ["+79952227978"],
    "auth_username": "0053248",
    "auth_password": "P5Nt8yKbey",
    "allowed_addresses": ["94.131.122.253/32"]
  }
}
```

## Конфигурация диалплана для LiveKit

```text
[novofon-in]
exten => 79952227978,1,Answer()
same => n,Dial(SIP/${EXTEN}@d2pr2lt70el.sip.livekit.cloud)

[novofon-out]
exten => _XXX,1,Dial(PJSIP/${EXTEN})
exten => _XXX.,1,Dial(PJSIP/${EXTEN}@0053248)
```

## Переменные окружения для LiveKit

``` bash
# Основные настройки LiveKit
LIVEKIT_DOMAIN=stellaragents.ru
LIVEKIT_PUBLIC_IP=94.131.122.253
LIVEKIT_URL=wss://voice-mz90cpgw.livekit.cloud
LIVEKIT_API_KEY=APIZAbDDuE6LsLZ
LIVEKIT_API_SECRET=1clDNVYu7feEdRuYMaU6jt2fVlTILVRu9IeeGhecaqxN

# Настройки Novofon
NOVOFON_NUMBER=+79952227978
NOVOFON_SIP_SERVER=sip.novofon.ru
NOVOFON_SIP_PORT=5060
NOVOFON_USERNAME=0053248
NOVOFON_PASSWORD=P5Nt8yKbey

# Cloud API
CLOUD_API_KEY=your_cloud_api_key_here
CLOUD_API_SECRET=your_cloud_api_secret_here

# AI сервисы
CARTESIA_API_KEY=your_cartesia_api_key_here
DEEPGRAM_API_KEY=your_deepgram_api_key_here
OPENAI_API_KEY=your_openai_api_key_here
```

## Конфигурация для специфичного IP-адреса

## Настройка NAT для вашего IP

``` text
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0
external_media_address=94.131.122.253
external_signaling_address=94.131.122.253
```

## Firewall правила

``` bash
# Разрешить входящие соединения для SIP
iptables -A INPUT -p udp --dport 5060 -s sip.novofon.ru -j ACCEPT
iptables -A INPUT -p udp --dport 5060 -s d2pr2lt70el.sip.livekit.cloud -j ACCEPT

# Разрешить RTP трафик
iptables -A INPUT -p udp --dport 10000:20000 -j ACCEPT
```

## Проверка конфигурации

## Тестирование подключения к Novofon

```bash
# Проверка регистрации
asterisk -rx "pjsip show registrations"

# Проверка статуса endpoint
asterisk -rx "pjsip show endpoint 0053248"

# Проверка аутентификации
asterisk -rx "pjsip show auth 0053248_auth"
```

## Проверка подключения к LiveKit

``` bash
# Тест SIP URI
sip-test d2pr2lt70el.sip.livekit.cloud

# Проверка портов
telnet d2pr2lt70el.sip.livekit.cloud 5060
```

## Важные моменты для вашей конфигурации

1. **Номер телефона** `+79952227978` настроен как основной DID для входящих звонков
    
2. **IP-адрес** `94.131.122.253` используется для NAT-настроек
    
3. **SIP URI** `d2pr2lt70el.sip.livekit.cloud` - точка входа для LiveKit
    
4. **Домен** `stellaragents.ru` настроен как основной домен для LiveKit
    

Эта конфигурация готова к использованию с вашими конкретными данными и обеспечивает полную интеграцию между Novofon, Asterisk и LiveKit для создания AI-агентов.