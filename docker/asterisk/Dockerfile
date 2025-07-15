FROM ubuntu:22.04

# Устанавливаем переменные окружения
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Moscow

# Устанавливаем зависимости для сборки Asterisk 22 из исходников
RUN apt-get update && apt-get install -y \
    build-essential \
    wget \
    curl \
    git \
    subversion \
    autoconf \
    automake \
    libtool \
    pkg-config \
    libssl-dev \
    libncurses5-dev \
    libnewt-dev \
    libxml2-dev \
    libsqlite3-dev \
    uuid-dev \
    libjansson-dev \
    libedit-dev \
    libsrtp2-dev \
    libspandsp-dev \
    libgsm1-dev \
    libspeex-dev \
    libspeexdsp-dev \
    libopus-dev \
    libvorbis-dev \
    libasound2-dev \
    portaudio19-dev \
    libcurl4-openssl-dev \
    xmlstarlet \
    doxygen \
    graphviz \
    tzdata \
    netcat \
    libneon27-dev \
    libgmime-3.0-dev \
    liblua5.2-dev \
    liburiparser-dev \
    libxslt1-dev \
    && rm -rf /var/lib/apt/lists/*

# Настраиваем timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Создание пользователя asterisk
RUN groupadd -r asterisk && useradd -r -g asterisk asterisk

# Скачивание и сборка Asterisk 22 с правильными опциями
WORKDIR /usr/src
RUN wget https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-22-current.tar.gz \
    && tar -xzf asterisk-22-current.tar.gz \
    && cd asterisk-22.* \
    && contrib/scripts/install_prereq install-unpackaged \
    && ./configure \
        --with-pjproject-bundled \
        --with-jansson-bundled \
        --with-crypto \
        --with-ssl \
        --enable-dev-mode \
        --enable-xmldoc \
        --prefix=/usr \
        --sysconfdir=/etc \
        --localstatedir=/var \
    && make menuselect.makeopts \
    && menuselect/menuselect \
        --enable app_stasis \
        --enable res_stasis \
        --enable res_ari \
        --enable res_http_websocket \
        --enable res_pjproject \
        --enable res_pjsip \
        --enable chan_pjsip \
        --enable CORE-SOUNDS-EN-GSM \
        --enable MOH-OPSOUND-GSM \
        menuselect.makeopts \
    && make -j$(nproc) \
    && make install \
    && make samples \
    && make config \
    && make progdocs \
    && ldconfig \
    && cd .. \
    && rm -rf asterisk-22*

# Создаем необходимые директории и устанавливаем права
RUN mkdir -p /var/lib/asterisk/sounds/ru \
    /var/lib/asterisk/documentation \
    /var/log/asterisk \
    /var/spool/asterisk \
    /var/run/asterisk \
    /etc/asterisk \
    && if [ -d /usr/share/asterisk/documentation ]; then \
        cp -r /usr/share/asterisk/documentation/* /var/lib/asterisk/documentation/ || true; \
    fi \
    && chown -R asterisk:asterisk /var/lib/asterisk \
        /var/log/asterisk \
        /var/spool/asterisk \
        /var/run/asterisk \
        /etc/asterisk

# Копируем скрипт запуска
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Экспонируем порты
EXPOSE 5060/udp 5061/udp 10000-20000/udp 5038

# Запускаем Asterisk
ENTRYPOINT ["/entrypoint.sh"]
CMD ["asterisk", "-f", "-vvv"]