#!/bin/bash

# Генерация пароля для Traefik Dashboard
# Использование: ./generate-traefik-password.sh <username> <password>

if [ $# -ne 2 ]; then
    echo "Usage: $0 <username> <password>"
    echo "Example: $0 admin mySecurePassword123"
    exit 1
fi

USERNAME=$1
PASSWORD=$2

# Генерируем хеш пароля
HASH=$(htpasswd -nbB "$USERNAME" "$PASSWORD" | cut -d: -f2)

echo "Generated hash for user '$USERNAME':"
echo "$USERNAME:$HASH"
echo ""
echo "Add this line to docker/traefik/dynamic.yml in the basicAuth users section:"
echo "  - \"$USERNAME:$HASH\""