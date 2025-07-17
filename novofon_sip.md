# Подробный мануал по настройке Asterisk для связи с NovoFon

Настройка Asterisk для работы с сервисом NovoFon требует тщательной подготовки системы и правильной конфигурации файлов. Данный мануал содержит пошаговые инструкции по установке, настройке и отладке соединения между Asterisk и NovoFon.

## Подготовка системы

### Требования к системе

Для успешной работы Asterisk с NovoFon необходимо обеспечить следующие условия:

- **Операционная система**: CentOS 7/8, Ubuntu 18.04/20.04 или аналогичная
- **Минимальные ресурсы**: 2GB RAM, 20GB дискового пространства
- **Сетевое соединение**: стабильный интернет-канал с минимальной задержкой
- **Порты**: UDP 5060 (SIP), UDP 10000-20000 (RTP), TCP 5038 (AMI)

### Настройка сетевого окружения

Перед установкой Asterisk необходимо правильно настроить сетевое окружение[1][2]:

```bash
# Проверка текущих настроек сети
ip addr show
netstat -tulpn | grep :5060

# Настройка firewall для CentOS/RHEL
firewall-cmd --permanent --add-port=5060/udp
firewall-cmd --permanent --add-port=10000-20000/udp
firewall-cmd --reload

# Для Ubuntu/Debian
ufw allow 5060/udp
ufw allow 10000:20000/udp
```

## Установка Asterisk

### Установка зависимостей

Сначала установим все необходимые пакеты для компиляции и работы Asterisk[3][4]:

```bash
# Для CentOS/RHEL
yum -y install gcc gcc-c++ make ncurses-devel libxml2-devel sqlite-devel bison kernel-headers kernel-devel openssl openssl-devel newt newt-devel flex curl sox binutils libuuid-devel jansson-devel

# Для Ubuntu/Debian
apt-get update
apt-get install build-essential libssl-dev libncurses5-dev libnewt-dev uuid-dev zlib1g-dev libsqlite3-dev libxml2-dev libjansson-dev
```

### Компиляция и установка Asterisk

Скачиваем и компилируем Asterisk из исходных кодов[5][3]:

```bash
# Создаем рабочую директорию
mkdir -p /usr/src/asterisk
cd /usr/src/asterisk

# Скачиваем исходники
wget http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-16-current.tar.gz
tar xfz asterisk-16-current.tar.gz
cd asterisk-16*/

# Устанавливаем зависимости
contrib/scripts/install_prereq install
contrib/scripts/get_mp3_source.sh

# Конфигурируем сборку
./configure --libdir=/usr/lib64

# Выбираем модули
make menuselect

# Компилируем и устанавливаем
make
make install
make samples
make config
```

### Первоначальная настройка

После установки необходимо выполнить базовую настройку системы[6][7]:

```bash
# Создаем пользователя asterisk
useradd -r -d /var/lib/asterisk -s /bin/false asterisk

# Устанавливаем права доступа
chown -R asterisk:asterisk /etc/asterisk
chown -R asterisk:asterisk /var/lib/asterisk
chown -R asterisk:asterisk /var/log/asterisk
chown -R asterisk:asterisk /var/spool/asterisk
chown -R asterisk:asterisk /var/run/asterisk

# Запускаем сервис
systemctl enable asterisk
systemctl start asterisk
```

## Получение данных от NovoFon

Для настройки соединения с NovoFon необходимо получить следующие данные из личного кабинета[8][9]:

1. **Логин**: находится в разделе "Телефония → Пользователи АТС → Имя пользователя → Вкладка «ВАТС»"
2. **Пароль**: указан на той же странице
3. **SIP-сервер**: `sip.novofon.ru`
4. **Виртуальный номер**: если используется

## Настройка подключения через SIP (chan_sip)

### Конфигурация файла sip.conf

Основная настройка подключения к NovoFon выполняется в файле `/etc/asterisk/sip.conf`[8]:

```ini
[general]
srvlookup=yes
context=default
allowoverlap=no
udpbindaddr=0.0.0.0
tcpenable=no
tcpbindaddr=0.0.0.0
transport=udp
srvlookup=yes
useragent=Asterisk PBX
register => 1234567:password@sip.novofon.ru/1234567

# Настройки для работы с NAT
localnet=192.168.1.0/255.255.255.0
externip=YOUR_EXTERNAL_IP
nat=force_rport,comedia
directmedia=no

# Транк NovoFon
[1234567]
host=sip.novofon.ru
insecure=invite,port
type=peer
fromdomain=sip.novofon.ru
disallow=all
allow=alaw
allow=ulaw
dtmfmode=auto
secret=password
defaultuser=1234567
trunkname=1234567
fromuser=1234567
callbackextension=1234567
context=novofon-in
qualify=400
directmedia=no
nat=force_rport,comedia

# Внутренний номер
[101]
secret=password
host=dynamic
type=friend
context=novofon-out
disallow=all
allow=alaw
allow=ulaw
dtmfmode=auto
mailbox=101@default
```

### Настройка маршрутизации в extensions.conf

Файл `/etc/asterisk/extensions.conf` определяет логику обработки входящих и исходящих звонков[8]:

```ini
[general]
static=yes
writeprotect=no
clearglobalvars=no

[globals]
; Глобальные переменные

[novofon-in]
; Входящие звонки с NovoFon
exten => 1234567,1,Answer()
exten => 1234567,n,Wait(1)
exten => 1234567,n,Dial(SIP/101,30,tr)
exten => 1234567,n,Voicemail(101@default,u)
exten => 1234567,n,Hangup()

[novofon-out]
; Исходящие звонки
; Внутренние номера (трехзначные)
exten => _XXX,1,Dial(SIP/${EXTEN},30,tr)
exten => _XXX,n,Voicemail(${EXTEN}@default,u)
exten => _XXX,n,Hangup()

; Внешние номера (четыре и более цифр)
exten => _XXXX.,1,Set(CALLERID(num)=1234567)
exten => _XXXX.,n,Dial(SIP/${EXTEN}@1234567,60,tr)
exten => _XXXX.,n,Congestion()
exten => _XXXX.,n,Hangup()

; Экстренные номера
exten => _XXX,1,Dial(SIP/${EXTEN}@1234567,60,tr)

[default]
include => novofon-out
```

## Настройка подключения через PJSIP

### Конфигурация файла pjsip.conf

Для более современной настройки рекомендуется использовать PJSIP[9][10]:

```ini
; Транспорт
[udp-transport]
type=transport
protocol=udp
bind=0.0.0.0:5060

; Регистрация на NovoFon
[1234567]
type=registration
transport=udp-transport
outbound_auth=1234567_auth
server_uri=sip:sip.novofon.ru
client_uri=sip:1234567@sip.novofon.ru
retry_interval=60
expiration=120
contact_user=1234567

; Аутентификация
[1234567_auth]
type=auth
auth_type=userpass
password=password
username=1234567

; AOR для транка
[1234567]
type=aor
contact=sip:sip.novofon.ru

; Endpoint для транка
[1234567]
type=endpoint
transport=udp-transport
context=novofon-in
disallow=all
allow=alaw
allow=ulaw
outbound_auth=1234567_auth
aors=1234567
from_user=1234567
from_domain=sip.novofon.ru
direct_media=no

; Идентификация входящих соединений
[1234567]
type=identify
endpoint=1234567
match=sip.novofon.ru

; Внутренний номер
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

### Настройка маршрутизации для PJSIP

Файл extensions.conf для PJSIP имеет незначительные отличия[9]:

```ini
[novofon-in]
; Входящие звонки с NovoFon
exten => 1234567,1,Answer()
exten => 1234567,n,Wait(1)
exten => 1234567,n,Dial(PJSIP/101,30,tr)
exten => 1234567,n,Voicemail(101@default,u)
exten => 1234567,n,Hangup()

[novofon-out]
; Исходящие звонки
; Внутренние номера
exten => _XXX,1,Dial(PJSIP/${EXTEN},30,tr)
exten => _XXX,n,Voicemail(${EXTEN}@default,u)
exten => _XXX,n,Hangup()

; Внешние номера
exten => _XXXX.,1,Set(CALLERID(num)=1234567)
exten => _XXXX.,n,Dial(PJSIP/${EXTEN}@1234567,60,tr)
exten => _XXXX.,n,Congestion()
exten => _XXXX.,n,Hangup()
```

## Настройка через SIP URI

Для серверов с белым IP-адресом можно использовать упрощенную настройку через SIP URI[8][9]:

### Настройка в личном кабинете NovoFon

1. Перейти в раздел "Настройки → Виртуальный номер"
2. Указать адрес в формате: `711111111111@YOUR_IP_ADDRESS`

### Конфигурация sip.conf для SIP URI

```ini
[novofon]
host=sip.novofon.ru
type=peer
insecure=port,invite
context=novofon-in
disallow=all
allow=alaw
allow=ulaw
dtmfmode=auto
directmedia=no
nat=force_rport,comedia
```

### Конфигурация extensions.conf для SIP URI

```ini
[novofon-in]
exten => 711111111111,1,Answer()
exten => 711111111111,n,Wait(1)
exten => 711111111111,n,Dial(SIP/101,30,tr)
exten => 711111111111,n,Hangup()
```

## Дополнительные настройки

### Настройка голосовой почты

Конфигурация файла `/etc/asterisk/voicemail.conf`[11][12]:

```ini
[general]
format=wav49|gsm|wav
serveremail=asterisk@yourserver.com
attach=yes
maxmsg=100
maxsecs=180
minsecs=3
maxsilence=10
silencethreshold=128
maxlogins=3
emaildateformat=%A, %B %d, %Y at %r
pagerdateformat=%A, %B %d, %Y at %r
sendvoicemail=yes

[default]
101 => 1234,User Name,user@company.com
102 => 1234,User Name,user2@company.com
```

### Настройка записи разговоров

Добавление записи в dialplan[5]:

```ini
[novofon-out]
exten => _XXXX.,1,Set(CALLERID(num)=1234567)
exten => _XXXX.,n,MixMonitor(/var/spool/asterisk/monitor/${CALLERID(num)}-${EXTEN}-${STRFTIME(${EPOCH},,%Y%m%d-%H%M%S)}.wav)
exten => _XXXX.,n,Dial(SIP/${EXTEN}@1234567,60,tr)
exten => _XXXX.,n,Hangup()
```

### Настройка автоответчика (IVR)

Базовая настройка IVR[5]:

```ini
[ivr-main]
exten => s,1,Answer()
exten => s,n,Wait(1)
exten => s,n,Background(welcome-message)
exten => s,n,WaitExten(5)

; Обработка нажатий клавиш
exten => 1,1,Dial(SIP/101,30,tr)
exten => 1,n,Voicemail(101@default,u)
exten => 1,n,Hangup()

exten => 2,1,Dial(SIP/102,30,tr)
exten => 2,n,Voicemail(102@default,u)
exten => 2,n,Hangup()

; Если ничего не нажато
exten => t,1,Dial(SIP/101,30,tr)
exten => t,n,Voicemail(101@default,u)
exten => t,n,Hangup()

; Неверный ввод
exten => i,1,Playback(invalid-option)
exten => i,n,Goto(s,1)
```

## Работа с NAT

### Проблемы с NAT и их решение

При работе за NAT могут возникнуть следующие проблемы[1][2]:

1. **Односторонняя слышимость**
2. **Проблемы с регистрацией**
3. **Потеря RTP-пакетов**

### Настройка для клиента за NAT

```ini
[general]
localnet=192.168.1.0/255.255.255.0
externip=YOUR_EXTERNAL_IP
nat=force_rport,comedia
directmedia=no

[client]
nat=yes
qualify=300
canreinvite=no
```

### Настройка для сервера за NAT

```ini
[general]
localnet=192.168.1.0/255.255.255.0
externip=YOUR_EXTERNAL_IP
nat=force_rport,comedia

[client]
nat=yes
canreinvite=no
directmedia=no
```

### Проброс портов на маршрутизаторе

```bash
# Для UDP порта SIP
iptables -t nat -A PREROUTING -p udp --dport 5060 -j DNAT --to-destination 192.168.1.10:5060

# Для RTP портов
iptables -t nat -A PREROUTING -p udp --dport 10000:20000 -j DNAT --to-destination 192.168.1.10
```

## Отладка и диагностика

### Проверка статуса соединения

Основные команды для проверки состояния системы[13][14]:

```bash
# Подключение к консоли Asterisk
asterisk -rvvv

# Проверка SIP-пиров
sip show peers
sip show registry

# Для PJSIP
pjsip show endpoints
pjsip show registrations
```

### Включение отладки SIP

Для диагностики проблем с SIP-соединением[13][14]:

```bash
# Включение отладки для конкретного пира
sip set debug peer 1234567

# Включение отладки для IP-адреса
sip set debug ip 192.168.1.100

# Включение общей отладки
sip set debug on

# Отключение отладки
sip set debug off
```

### Анализ логов

Просмотр логов для выявления проблем[15]:

```bash
# Основной лог
tail -f /var/log/asterisk/full

# Поиск ошибок
grep -i error /var/log/asterisk/full
grep -i warning /var/log/asterisk/full

# Анализ SIP-сообщений
grep -i "sip" /var/log/asterisk/full
```

### Типичные проблемы и их решение

#### Проблема: Нет регистрации

**Симптомы**: Пир показывает статус UNREACHABLE

**Решение**:
1. Проверить правильность логина и пароля
2. Убедиться в доступности sip.novofon.ru
3. Проверить настройки firewall
4. Убедиться в правильности настроек NAT

#### Проблема: Односторонняя слышимость

**Симптомы**: Слышно только одну сторону разговора

**Решение**:
1. Проверить настройки NAT
2. Убедиться в правильности настроек RTP
3. Проверить проброс портов 10000-20000

#### Проблема: Входящие звонки не проходят

**Симптомы**: Внешние звонки не доходят до внутренних номеров

**Решение**:
1. Проверить настройки контекста в sip.conf
2. Убедиться в правильности dialplan в extensions.conf
3. Проверить регистрацию транка

### Утилиты для диагностики

#### Использование tcpdump

```bash
# Мониторинг SIP-трафика
tcpdump -i any -s0 host sip.novofon.ru and port 5060 -nn

# Мониторинг RTP-трафика
tcpdump -i any -s0 portrange 10000-20000 -nn
```

#### Использование sngrep

Установка и использование sngrep для анализа SIP-трафика[16]:

```bash
# Установка sngrep
yum install sngrep

# Запуск анализа
sngrep

# Сохранение дампа
sngrep -O /tmp/sip_dump.pcap
```

## Безопасность

### Базовые меры безопасности

#### Настройка fail2ban

Установка и настройка fail2ban для защиты от атак[17]:

```bash
# Установка fail2ban
yum install fail2ban

# Настройка jail.conf
cat > /etc/fail2ban/jail.d/asterisk.conf  /dev/null; then
    echo "Asterisk не запущен, запускаем..."
    systemctl start asterisk
    sleep 10
fi

# Проверка регистрации
REGISTRATION_STATUS=$(asterisk -rx "sip show registry" | grep "novofon")
if [[ $REGISTRATION_STATUS == *"Unregistered"* ]]; then
    echo "Проблемы с регистрацией, перезапускаем..."
    systemctl restart asterisk
fi
```

### Мониторинг с помощью cron

```bash
# Добавление в crontab
*/5 * * * * /usr/local/bin/asterisk_monitor.sh
```

## Заключение

Настройка Asterisk для работы с NovoFon требует внимательного подхода к каждому этапу конфигурации. Основные моменты, которые необходимо учесть:

1. **Правильная подготовка системы** - установка всех необходимых зависимостей и настройка сетевого окружения
2. **Корректная настройка конфигурационных файлов** - особое внимание к параметрам NAT, кодекам и безопасности
3. **Тщательная отладка** - использование встроенных инструментов Asterisk для диагностики проблем
4. **Постоянный мониторинг** - регулярная проверка работоспособности системы и анализ логов

При возникновении проблем рекомендуется начинать диагностику с проверки сетевой связности, затем переходить к анализу SIP-сообщений и настроек конфигурационных файлов. Правильно настроенная система обеспечит стабильную работу IP-телефонии с высоким качеством связи.