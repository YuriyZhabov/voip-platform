FROM ubuntu:22.04

# Устанавливаем переменные окружения
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Moscow

# Устанавливаем зависимости для сборки Asterisk 22
RUN apt-get update && apt-get install -y \
    build-essential \
    wget \
    curl \
    git \
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
    libgsm1-dev \
    libspeex-dev \
    libspeexdsp-dev \
    libopus-dev \
    libcurl4-openssl-dev \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Настраиваем timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Создание пользователя asterisk
RUN groupadd -r asterisk && useradd -r -g asterisk asterisk

# Сборка Asterisk 22 без xmldoc
WORKDIR /usr/src
RUN wget https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-22-current.tar.gz \
    && tar -xzf asterisk-22-current.tar.gz \
    && cd asterisk-22.* \
    && ./configure \
        --disable-xmldoc \
        --with-pjproject-bundled \
        --with-jansson-bundled \
        --prefix=/usr \
        --sysconfdir=/etc \
        --localstatedir=/var \
    && make -j$(nproc) \
    && make install \
    && make samples \
    && ldconfig \
    && cd .. \
    && rm -rf asterisk-22*

# Создаем необходимые директории и устанавливаем права
RUN mkdir -p \
    /var/lib/asterisk/sounds \
    /var/log/asterisk \
    /var/spool/asterisk \
    /var/run/asterisk \
    /etc/asterisk \
    && chown -R asterisk:asterisk \
        /var/lib/asterisk \
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