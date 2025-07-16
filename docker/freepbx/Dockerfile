FROM tiredofit/freepbx:latest

# Копирование кастомных конфигураций
COPY entrypoint.sh /usr/local/bin/custom-entrypoint.sh
RUN chmod +x /usr/local/bin/custom-entrypoint.sh

# Настройка переменных окружения для FreePBX
ENV ENABLE_CRON=TRUE
ENV ENABLE_SMTP=FALSE
ENV RTP_START=18000
ENV RTP_FINISH=18100
ENV WEBROOT=/admin
ENV DB_EMBEDDED=FALSE

EXPOSE 80 443 5060/udp 5061 18000-18100/udp

ENTRYPOINT ["/usr/local/bin/custom-entrypoint.sh"]