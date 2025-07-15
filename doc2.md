Based on the error logs and my research, I can see the core issue: the `res_pjproject` module is missing, which is causing a cascading failure of all PJSIP-related modules. The `features` module failure is also occurring, likely due to the same XML documentation issues we've been encountering.

Let me provide a comprehensive solution:

# Решение критического сбоя модулей PJSIP и Features в Asterisk 22 Docker

## Анализ проблемы

Логи показывают две основные проблемы:

1. **Отсутствие `res_pjproject.so`** - базовый модуль для всех PJSIP функций
2. **Сбой модуля `features`** - критический модуль для базовых функций PBX
3. **Символьные ошибки** типа `undefined symbol: pjsip_media_type_multipart_mixed` и `ast_sip_get_sorcery`

Все эти проблемы указывают на неправильную сборку или конфигурацию Asterisk в Docker контейнере.

## Пошаговое решение

### 1. Проверка и исправление `modules.conf`

Создайте правильную конфигурацию загрузки модулей:

```bash
docker-compose exec asterisk sh -c 'cat > /etc/asterisk/modules.conf  res_pjproject.so
load => res_sorcery_config.so
load => res_sorcery_memory.so
load => res_sorcery_astdb.so
load => res_sorcery_realtime.so

; PJSIP модули (в правильном порядке)
load => res_pjsip.so
load => res_pjsip_session.so
load => res_pjsip_authenticator_digest.so
load => res_pjsip_endpoint_identifier_ip.so
load => res_pjsip_endpoint_identifier_user.so
load => res_pjsip_registrar.so
load => res_pjsip_outbound_registration.so
load => res_pjsip_pubsub.so
load => res_pjsip_exten_state.so
load => res_pjsip_mwi.so
load => res_pjsip_notify.so
load => res_pjsip_dialog_info_body_generator.so
load => res_pjsip_pidf_body_generator.so
load => res_pjsip_xpidf_body_generator.so
load => res_pjsip_messaging.so
load => res_pjsip_nat.so
load => res_pjsip_history.so
load => res_pjsip_diversion.so
load => res_pjsip_refer.so
load => res_pjsip_path.so
load => res_pjsip_rfc3326.so
load => res_pjsip_empty_info.so
load => res_pjsip_acl.so
load => res_pjsip_dtmf_info.so
load => res_pjsip_one_touch_record_info.so
load => res_pjsip_caller_id.so
load => res_pjsip_header_funcs.so
load => res_pjsip_logger.so
load => res_pjsip_sips_contact.so
load => res_pjsip_rfc3329.so
load => res_pjsip_send_to_voicemail.so
load => res_pjsip_endpoint_identifier_anonymous.so
load => res_pjsip_config_wizard.so
load => res_pjsip_transport_websocket.so
load => res_pjsip_sdp_rtp.so
load => res_pjsip_t38.so

; Канальные драйверы
load => chan_pjsip.so

; Функции PJSIP
load => func_pjsip_aor.so
load => func_pjsip_contact.so
load => func_pjsip_endpoint.so

; Базовые ресурсы
load => res_rtp_asterisk.so
load => res_http_websocket.so
load => res_stasis.so
load => res_ari.so
load => res_stasis_answer.so
load => res_stasis_playback.so
load => res_stasis_recording.so
load => res_stasis_snoop.so
load => res_stasis_device_state.so

; ARI модули
load => res_ari_applications.so
load => res_ari_asterisk.so
load => res_ari_bridges.so
load => res_ari_channels.so
load => res_ari_device_states.so
load => res_ari_endpoints.so
load => res_ari_events.so
load => res_ari_playbacks.so
load => res_ari_recordings.so
load => res_ari_sounds.so

; Другие необходимые модули
load => pbx_config.so
load => chan_local.so
load => app_dial.so
load => app_echo.so
load => app_playback.so
load => app_voicemail.so
load => codec_alaw.so
load => codec_ulaw.so
load => codec_gsm.so
load => format_wav.so
load => format_gsm.so
load => format_pcm.so
load => res_musiconhold.so
load => res_timing_timerfd.so
load => bridge_simple.so
load => bridge_native_rtp.so
load => bridge_holding.so
load => bridge_softmix.so
EOF'
```

### 2. Проверка наличия модулей в контейнере

```bash
# Проверить, есть ли модуль res_pjproject
docker-compose exec asterisk ls -la /usr/lib/asterisk/modules/res_pjproject.so

# Проверить все PJSIP модули
docker-compose exec asterisk ls -la /usr/lib/asterisk/modules/res_pj*
```

### 3. Если модулей нет - пересборка Asterisk

Если модули отсутствуют, проблема в сборке. Обновите Dockerfile:

```dockerfile
FROM ubuntu:22.04

# Установка зависимостей
RUN apt-get update && apt-get install -y \
    build-essential \
    libssl-dev \
    libjansson-dev \
    libxml2-dev \
    libsqlite3-dev \
    uuid-dev \
    libncurses5-dev \
    libedit-dev \
    libsrtp2-dev \
    libspeex-dev \
    libspeexdsp-dev \
    libcurl4-openssl-dev \
    libneon27-dev \
    libgmime-3.0-dev \
    liblua5.2-dev \
    liburiparser-dev \
    libxslt1-dev \
    curl \
    wget \
    pkg-config

# Загрузка и сборка Asterisk
WORKDIR /usr/src
RUN wget https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-22-current.tar.gz
RUN tar -xzf asterisk-22-current.tar.gz
WORKDIR /usr/src/asterisk-22.*

# Установка зависимостей Asterisk
RUN contrib/scripts/install_prereq install

# Конфигурация с включенным PJSIP
RUN ./configure \
    --with-pjproject-bundled \
    --with-jansson-bundled \
    --with-crypto \
    --with-ssl \
    --prefix=/usr \
    --sysconfdir=/etc \
    --localstatedir=/var

# Компиляция и установка
RUN make && make install && make samples && make install-core-docs

# Создание пользователя asterisk
RUN useradd -r -s /bin/false asterisk
RUN chown -R asterisk:asterisk /etc/asterisk /var/lib/asterisk /var/log/asterisk /var/spool/asterisk

USER asterisk
CMD ["/usr/sbin/asterisk", "-f", "-vvv"]
```

### 4. Создание базовых конфигурационных файлов

```bash
# Создать базовый features.conf
docker-compose exec asterisk sh -c 'cat > /etc/asterisk/features.conf  /etc/asterisk/pjsip.conf << EOF
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060

[transport-ws]
type=transport
protocol=ws
bind=0.0.0.0:8088

[transport-wss]
type=transport
protocol=wss
bind=0.0.0.0:8089
EOF'
```

### 5. Альтернативное решение: использование готового образа

Если пересборка не помогает, используйте проверенный образ:

```yaml
# docker-compose.yml
version: '3.8'
services:
  asterisk:
    image: mlan/asterisk:22-base
    container_name: asterisk-pbx
    restart: unless-stopped
    ports:
      - "5060:5060/udp"
      - "8088:8088/tcp"
      - "8089:8089/tcp"
      - "10000-10100:10000-10100/udp"
    volumes:
      - ./asterisk/config:/etc/asterisk
      - ./asterisk/logs:/var/log/asterisk
      - ./asterisk/sounds:/var/lib/asterisk/sounds
    environment:
      - ASTERISK_UID=1000
      - ASTERISK_GID=1000
```

### 6. Перезапуск и проверка

```bash
# Перезапустить контейнер
docker-compose restart asterisk

# Проверить загрузку модулей
docker-compose exec asterisk asterisk -rx "module show like pjproject"
docker-compose exec asterisk asterisk -rx "module show like features"
docker-compose exec asterisk asterisk -rx "pjsip show version"

# Проверить отсутствие критических ошибок
docker-compose logs asterisk | grep -i "error\|failed\|exiting"
```

## Диагностика проблем

Если проблемы продолжаются:

1. **Проверьте архитектуру**: убедитесь, что модули собраны для правильной архитектуры
2. **Проверьте зависимости**: `ldd /usr/lib/asterisk/modules/res_pjproject.so`
3. **Проверьте права доступа**: все файлы должны принадлежать пользователю `asterisk`
4. **Включите отладку**: запустите с флагом `-vvv` для детального лога

## Заключение

Проблема связана с неправильной сборкой или конфигурацией PJSIP модулей в Docker контейнере. Отсутствие `res_pjproject.so` вызывает каскадный сбой всех зависимых модулей. Решение требует либо пересборки Asterisk с правильными опциями, либо использования готового образа с корректной конфигурацией модулей.