#!/bin/bash
set -e

echo "Starting FreePBX 17 with custom configuration..."

# Настройка переменных окружения для Novofon
export NOVOFON_USERNAME=${NOVOFON_USERNAME:-""}
export NOVOFON_PASSWORD=${NOVOFON_PASSWORD:-""}
export NOVOFON_NUMBER=${NOVOFON_NUMBER:-""}

# Настройка внешнего IP
export EXTERNAL_IP=${LIVEKIT_PUBLIC_IP:-$(curl -s ifconfig.me)}

echo "External IP: $EXTERNAL_IP"
echo "Novofon Username: $NOVOFON_USERNAME"
echo "RTP Range: $RTP_START-$RTP_FINISH"

# Запуск оригинального entrypoint tiredofit/freepbx
exec /init