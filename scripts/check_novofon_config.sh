#!/bin/bash
# Скрипт для проверки настроек Novofon
# Автор: Kiro AI
# Дата: 2025-07-17

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Функция для проверки статуса
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[OK]${NC} $1"
    else
        echo -e "${RED}[FAIL]${NC} $1"
    fi
}

# Функция для вывода заголовка
print_header() {
    echo -e "\n${YELLOW}=== $1 ===${NC}"
}

# Проверка конфигурационных файлов
print_header "Проверка конфигурационных файлов"

echo -n "Проверка novofon_pjsip.conf: "
if [ -f "/etc/asterisk/novofon_pjsip.conf" ]; then
    echo -e "${GREEN}[OK]${NC} Файл существует"
else
    echo -e "${RED}[FAIL]${NC} Файл не найден"
fi

echo -n "Проверка novofon_extensions.conf: "
if [ -f "/etc/asterisk/novofon_extensions.conf" ]; then
    echo -e "${GREEN}[OK]${NC} Файл существует"
else
    echo -e "${RED}[FAIL]${NC} Файл не найден"
fi

echo -n "Проверка include_custom.conf: "
if grep -q "novofon_pjsip.conf" "/etc/asterisk/include_custom.conf" && \
   grep -q "novofon_extensions.conf" "/etc/asterisk/include_custom.conf"; then
    echo -e "${GREEN}[OK]${NC} Файлы включены в конфигурацию"
else
    echo -e "${RED}[FAIL]${NC} Файлы не включены в конфигурацию"
fi

# Проверка регистрации
print_header "Проверка регистрации на Novofon"

echo "Статус регистрации:"
asterisk -rx "pjsip show registrations" | grep "0053248"
check_status "Проверка статуса регистрации"

# Проверка транспорта
print_header "Проверка настроек транспорта"

echo "Настройки транспорта:"
asterisk -rx "pjsip show transports" | grep -A 10 "transport-udp"
check_status "Проверка настроек транспорта"

# Проверка endpoint
print_header "Проверка настроек endpoint"

echo "Настройки endpoint:"
asterisk -rx "pjsip show endpoint 0053248" | head -20
check_status "Проверка настроек endpoint"

# Проверка identify
print_header "Проверка настроек identify"

echo "Настройки identify:"
asterisk -rx "pjsip show identifies" | grep "0053248"
check_status "Проверка настроек identify"

# Проверка сетевых настроек
print_header "Проверка сетевых настроек"

echo -n "Проверка доступности SIP-сервера Novofon: "
if ping -c 3 sip.novofon.ru > /dev/null 2>&1; then
    echo -e "${GREEN}[OK]${NC} SIP-сервер доступен"
else
    echo -e "${RED}[FAIL]${NC} SIP-сервер недоступен"
fi

echo -n "Проверка открытых портов: "
if netstat -tulpn | grep -q ":5060"; then
    echo -e "${GREEN}[OK]${NC} Порт 5060 открыт"
else
    echo -e "${RED}[FAIL]${NC} Порт 5060 не открыт"
fi

# Проверка диалплана
print_header "Проверка диалплана"

echo "Проверка контекста novofon-in:"
asterisk -rx "dialplan show novofon-in" | head -20
check_status "Проверка контекста novofon-in"

echo "Проверка контекста novofon-out:"
asterisk -rx "dialplan show novofon-out" | head -20
check_status "Проверка контекста novofon-out"

# Проверка логов
print_header "Проверка логов"

echo "Последние записи в логах, связанные с Novofon:"
grep -a "novofon\|0053248" /var/log/asterisk/full | tail -20
check_status "Проверка логов"

# Итоги
print_header "Итоги проверки"

echo "Для тестирования входящих звонков:"
echo "1. Позвоните на номер 79952227978"
echo "2. Проверьте логи: tail -f /var/log/asterisk/full"

echo -e "\nДля тестирования исходящих звонков:"
echo "1. Выполните команду: asterisk -rx \"channel originate PJSIP/79XXXXXXXXX@0053248 application Wait 10\""
echo "2. Замените 79XXXXXXXXX на реальный номер для тестирования"
echo "3. Проверьте логи: tail -f /var/log/asterisk/full"

echo -e "\nДля проверки регистрации:"
echo "asterisk -rx \"pjsip show registrations\""

echo -e "\nДля перезагрузки конфигурации:"
echo "asterisk -rx \"module reload\""

exit 0